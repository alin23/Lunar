import Accelerate
import Atomics
import AXSwift
import Cocoa
import Combine
import Defaults
import Foundation
import Path
import Surge
import SwiftDate
import SwiftyMarkdown
import UserNotifications

typealias DisplayUUID = String

typealias FilePath = Path
func p(_ string: String) -> FilePath? {
    FilePath(string)
}

func displayIsInMirrorSet(_ id: CGDirectDisplayID) -> Bool {
    CGDisplayIsInMirrorSet(id) != 0
}

func displayIsInHardwareMirrorSet(_ id: CGDirectDisplayID) -> Bool {
    guard let primary = Display.getPrimaryMirrorScreen(id) else { return displayIsInMirrorSet(id) }
    return !primary.isDummy
}

@inline(__always) func isGeneric(_ id: CGDirectDisplayID) -> Bool {
    #if DEBUG
        return id == GENERIC_DISPLAY_ID || id == TEST_DISPLAY_ID
    #else
        return id == GENERIC_DISPLAY_ID || id == ALL_DISPLAYS_ID
    #endif
}

@inline(__always) func isGeneric(serial: String) -> Bool {
    #if DEBUG
        return serial == GENERIC_DISPLAY.serial || serial == TEST_DISPLAY.serial
    #else
        return serial == GENERIC_DISPLAY.serial || serial == ALL_DISPLAYS.serial
    #endif
}

@inline(__always) func isTestID(_ id: CGDirectDisplayID) -> Bool {
    #if DEBUG
//        return id == GENERIC_DISPLAY_ID
        return TEST_IDS.contains(id)
    #else
        return id == GENERIC_DISPLAY_ID
    #endif
}

@inline(__always) func isTestSerial(_ serial: String) -> Bool {
    #if DEBUG
        return TEST_SERIALS.contains(serial)
    #else
        return serial == GENERIC_DISPLAY.serial || serial == ALL_DISPLAYS.serial
    #endif
}

// MARK: - RequestTimeoutError

final class RequestTimeoutError: Error {}

// MARK: - ResponseError

struct ResponseError: Error {
    var statusCode: Int
}

// MARK: - ProcessStatus

struct ProcessStatus {
    var output: Data?
    var error: Data?
    var success: Bool

    var o: String? {
        output?.s?.trimmed
    }

    var e: String? {
        error?.s?.trimmed
    }
}

func stdout(of process: Process) -> Data? {
    let stdout = process.standardOutput as! FileHandle
    try? stdout.close()

    guard let path = process.environment?["__swift_stdout"],
          let stdoutFile = FileHandle(forReadingAtPath: path) else { return nil }
    if #available(macOS 10.15.4, *) {
        return try! stdoutFile.readToEnd()
    } else {
        return stdoutFile.readDataToEndOfFile()
    }
}

func stderr(of process: Process) -> Data? {
    let stderr = process.standardOutput as! FileHandle
    try? stderr.close()

    guard let path = process.environment?["__swift_stderr"],
          let stderrFile = FileHandle(forReadingAtPath: path) else { return nil }
    if #available(macOS 10.15.4, *) {
        return try! stderrFile.readToEnd()
    } else {
        return stderrFile.readDataToEndOfFile()
    }
}

func shellProc(_ launchPath: String = "/bin/sh", args: [String], env: [String: String]? = nil, devnull: Bool = false) -> Process? {
    guard !devnull else {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = args
        task.environment = env ?? ProcessInfo.processInfo.environment
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            log.error("Error running \(launchPath) \(args): \(error)")
            return nil
        }
        return task
    }

    let outputDir = try! fm.url(
        for: .itemReplacementDirectory,
        in: .userDomainMask,
        appropriateFor: fm.homeDirectoryForCurrentUser,
        create: true
    )

    let stdoutFilePath = outputDir.appendingPathComponent("stdout").path
    fm.createFile(atPath: stdoutFilePath, contents: nil, attributes: nil)

    let stderrFilePath = outputDir.appendingPathComponent("stderr").path
    fm.createFile(atPath: stderrFilePath, contents: nil, attributes: nil)

    guard let stdoutFile = FileHandle(forWritingAtPath: stdoutFilePath),
          let stderrFile = FileHandle(forWritingAtPath: stderrFilePath)
    else {
        return nil
    }

    let task = Process()
    task.standardOutput = stdoutFile
    task.standardError = stderrFile
    task.launchPath = launchPath
    task.arguments = args

    var env = env ?? ProcessInfo.processInfo.environment
    env["__swift_stdout"] = stdoutFilePath
    env["__swift_stderr"] = stderrFilePath
    task.environment = env

    do {
        try task.run()
    } catch {
        log.error("Error running \(launchPath) \(args): \(error)")
        return nil
    }

    return task
}

func shell(
    _ launchPath: String = "/bin/sh",
    command: String,
    timeout: DateComponents? = nil,
    env: [String: String]? = nil,
    wait: Bool = true
) -> ProcessStatus {
    shell(launchPath, args: ["-c", command], timeout: timeout, env: env, wait: wait)
}

func shell(
    _ launchPath: String = "/bin/sh",
    args: [String],
    timeout: DateComponents? = nil,
    env: [String: String]? = nil,
    wait: Bool = true
) -> ProcessStatus {
    guard let task = shellProc(launchPath, args: args, env: env, devnull: !wait) else {
        return ProcessStatus(output: nil, error: nil, success: false)
    }

    guard wait else {
        return ProcessStatus(
            output: nil,
            error: nil,
            success: true
        )
    }

    guard let timeout else {
        task.waitUntilExit()
        return ProcessStatus(
            output: stdout(of: task),
            error: stderr(of: task),
            success: task.terminationStatus == 0
        )
    }

    let result = asyncNow(timeout: timeout) {
        task.waitUntilExit()
    }
    if result == .timedOut {
        task.terminate()
    }

    return ProcessStatus(
        output: stdout(of: task),
        error: stderr(of: task),
        success: task.terminationStatus == 0
    )
}

// MARK: - DispatchWorkItem

final class DispatchWorkItem {
    init(name: String, flags: DispatchWorkItemFlags = [], block: @escaping @convention(block) () -> Void) {
        workItem = Foundation.DispatchWorkItem(flags: flags, block: block)
        self.name = name
    }

    var name = ""
    var workItem: Foundation.DispatchWorkItem

    @inline(__always) var isCancelled: Bool {
        workItem.isCancelled
    }

    @discardableResult
    @inline(__always) func wait(for timeout: DateComponents?) -> DispatchTimeoutResult {
        guard let timeout else {
            return wait(for: 0)
        }
        return wait(for: timeout.timeInterval)
    }

    @inline(__always) func cancel() {
        workItem.cancel()
    }

    @discardableResult
    @inline(__always) func wait(for timeout: TimeInterval) -> DispatchTimeoutResult {
        #if DEBUG
            if timeout > 0 {
                log.verbose("Waiting for \(timeout) seconds on \(name)")
            } else {
                log.verbose("Waiting for \(name)")
            }
            defer { log.verbose("Done waiting for \(name)") }
        #endif

        if timeout > 0 {
            let result = workItem.wait(timeout: DispatchTime.now() + timeout)
            if result == .timedOut {
                workItem.cancel()
                #if DEBUG
                    log.verbose("Timed out after \(timeout) seconds on \(name)")
                #endif
            }
            return result
        } else {
            workItem.wait()
            return .success
        }
    }
}

// MARK: - DispatchSemaphore

final class DispatchSemaphore: CustomStringConvertible {
    init(value: Int, name: String) {
        sem = Foundation.DispatchSemaphore(value: value)
        self.name = name
    }

    var name = ""
    var sem: Foundation.DispatchSemaphore

    var description: String {
        "<DispatchSemaphore: \(name)>"
    }

    @discardableResult
    @inline(__always) func wait(for timeout: DateComponents?, context: Any? = nil) -> DispatchTimeoutResult {
        guard let timeout else {
            return wait(for: 0, context: context)
        }
        return wait(for: timeout.timeInterval, context: context)
    }

    @inline(__always) func signal() {
        sem.signal()
    }

    @discardableResult
    @inline(__always) func wait(for timeout: TimeInterval, context: Any? = nil) -> DispatchTimeoutResult {
        #if DEBUG
            if timeout > 0 {
                log.verbose("Waiting for \(timeout) seconds on \(name)", context: context)
            } else {
                log.verbose("Waiting for \(name)", context: context)
            }
            defer { log.verbose("Done waiting for \(name)", context: context) }
        #endif

        if timeout > 0 {
            return sem.wait(timeout: DispatchTime.now() + timeout)
        } else {
            sem.wait()
            return .success
        }
    }
}

#if DEBUG
    @inline(__always) func checkNaN(_ value: Double) {
        guard value.isNaN else { return }
        err("NaN!")
        kill(getpid(), SIGSTOP)
    }
    @inline(__always) func checkNaN(_ value: Float) {
        guard value.isNaN else { return }
        err("NaN!")
        kill(getpid(), SIGSTOP)
    }
#else
    @inline(__always) func checkNaN(_: Double) {}
    @inline(__always) func checkNaN(_: Float) {}
#endif

import SwiftyJSON

func queryJSON(url: URL, timeout: TimeInterval = 0, _ action: @escaping (JSON) -> Void) -> AnyCancellable {
    query(url: url, timeout: timeout)
        .map(\.data)
        .catch { error -> Just<Data> in
            log.error("Error requesting \(url.host ?? ""): \(error)")
            return Just(Data())
        }
        .sink { data in
            guard !data.isEmpty else { return }
            let json = JSON(data)
            guard json != JSON.null else { return }
            action(json)
        }
}

func session(timeout: TimeInterval = 0) -> URLSession {
    if timeout == 0 {
        return URLSession.shared
    }

    let key = "URLSession: timeout=\(timeout)"
    guard let session = Thread.current.threadDictionary[key] as? URLSession else {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: config)

        Thread.current.threadDictionary[key] = session
        return session
    }
    return session
}

typealias DataTaskOutput = URLSession.DataTaskPublisher.Output
typealias DataTaskResult = Result<DataTaskOutput, Error>

func query(url: URL, timeout: TimeInterval = 0) -> Publishers.TryMap<URLSession.DataTaskPublisher, DataTaskOutput> {
    let session = session(timeout: timeout)

    return session.dataTaskPublisher(for: url)
        .tryMap { (dataTaskOutput: DataTaskOutput) -> DataTaskOutput in
            guard let response = dataTaskOutput.response as? HTTPURLResponse, (200 ..< 300).contains(response.statusCode) else {
                throw ResponseError(statusCode: (dataTaskOutput.response as? HTTPURLResponse)?.statusCode ?? 400)
            }
            return dataTaskOutput
        }
}

func request(
    from url: URL,
    method: String = "GET",
    body: Data? = nil,
    headers: [String: String]? = nil,
    timeoutPerTry: TimeInterval = 10,
    retries: UInt = 1,
    backoff: Double = 1,
    sleepBetweenTries: TimeInterval = 0,
    maxSleepBetweenTries: TimeInterval = 300,
    _ onResponse: ((String?) -> Void)? = nil
) -> AnyCancellable {
    var sleepBetweenTries = sleepBetweenTries
    let session = session(timeout: timeoutPerTry)

    var urlRequest = URLRequest(url: url, timeoutInterval: timeoutPerTry)
    urlRequest.httpMethod = method
    urlRequest.httpBody = body
    urlRequest.allHTTPHeaderFields = headers

    let request = session.dataTaskPublisher(for: urlRequest)
        .tryMap { (dataTaskOutput: DataTaskOutput) -> DataTaskResult in
            guard let response = dataTaskOutput.response as? HTTPURLResponse, (200 ..< 300).contains(response.statusCode) else {
                throw ResponseError(statusCode: (dataTaskOutput.response as? HTTPURLResponse)?.statusCode ?? 400)
            }
            return .success(dataTaskOutput)
        }
        .catch { (error: Error) -> AnyPublisher<DataTaskResult, Error> in
            defer {
                if sleepBetweenTries > 0 {
                    sleepBetweenTries = min(sleepBetweenTries * backoff, maxSleepBetweenTries)
                }
            }
            return Fail(error: error)
                .delay(for: RunLoop.SchedulerTimeType.Stride(sleepBetweenTries), scheduler: RunLoop.current)
                .eraseToAnyPublisher()
        }
        .retry(retries.i)
        .map { (result: DataTaskResult) -> String? in
            guard let data = (try? result.get())?.data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        .replaceError(with: nil)
        .sink { resp in onResponse?(resp) }

    return request
}

func doRequest(url: URL, timeout: DateComponents = 10.seconds) -> (HTTPURLResponse, Data)? {
    let semaphore = DispatchSemaphore(value: 0, name: "waitForResponse \(url.absoluteString)")
    let session = session(timeout: timeout.timeInterval)
    var response: HTTPURLResponse?
    var respData: Data?

    let task = session.dataTask(with: url) { data, resp, error in
        response = resp as? HTTPURLResponse
        respData = data
        semaphore.signal()
    }
    task.resume()

    if semaphore.wait(for: timeout.timeInterval) == .timedOut {
        task.cancel()
    }

    guard let response, let respData else { return nil }
    return (response, respData)
}

func waitForResponse(
    from url: URL,
    timeoutPerTry: DateComponents = 10.seconds,
    retries: UInt = 1,
    backoff: Double = 1,
    sleepBetweenTries: TimeInterval = 0,
    maxSleepBetweenTries: TimeInterval = 300
) -> String? {
    var sleepBetweenTries = sleepBetweenTries
    let semaphore = DispatchSemaphore(value: 0, name: "waitForResponse \(url.absoluteString)")

    let session = session(timeout: timeoutPerTry.timeInterval)
    var responseString: String?
    let lock = NSRecursiveLock()

    let request = session.dataTaskPublisher(for: url)
        .tryMap { (dataTaskOutput: DataTaskOutput) -> DataTaskResult in
            guard let response = dataTaskOutput.response as? HTTPURLResponse, (200 ..< 300).contains(response.statusCode) else {
                throw ResponseError(statusCode: (dataTaskOutput.response as? HTTPURLResponse)?.statusCode ?? 400)
            }
            return .success(dataTaskOutput)
        }
        .catch { (error: Error) -> AnyPublisher<DataTaskResult, Error> in
            defer {
                if sleepBetweenTries > 0 {
                    sleepBetweenTries = min(sleepBetweenTries * backoff, maxSleepBetweenTries)
                }
            }
            return Fail(error: error)
                .delay(for: RunLoop.SchedulerTimeType.Stride(sleepBetweenTries), scheduler: RunLoop.current)
                .eraseToAnyPublisher()
        }
        .retry(retries.i)
        .map { (result: DataTaskResult) -> String? in
            guard let data = (try? result.get())?.data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        .replaceError(with: nil)
        .sink { resp in
            lock.around { responseString = resp }
            semaphore.signal()
        }

    log.verbose("Request: \(request)")
    log.debug("Waiting for request on \(url.absoluteString)")
    semaphore.wait(for: timeoutPerTry.timeInterval * retries.d)
    let result = lock.around { responseString }
    return result
}

extension String {
    subscript(index: Int) -> Character {
        self[self.index(startIndex, offsetBy: index)]
    }
}

let publicKey =
    """
    -----BEGIN PUBLIC KEY-----
    MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEKGs3ARma5DHHnBb/vvTQmRV6sS3Y
    KtuJCVywyiA6TqoFEuQWDVmVwScqPbm5zmdRIUK31iZvxGjFjggMutstEA==
    -----END PUBLIC KEY-----
    """

var appDelegate: AppDelegate? =
    NSApplication.shared.delegate as? AppDelegate

func refreshScreen(refocus: Bool = true) {
    mainAsync {
        let focusedApp = NSWorkspace.shared.runningApplications.first(where: { app in app.isActive })
        if refocus {
            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
        }

        if let w = appDelegate!.windowController?.window?.contentViewController?.view {
            w.setNeedsDisplay(w.frame)
        }

        if refocus {
            focusedApp?.activate(options: .activateIgnoringOtherApps)
        }
    }
}

func createAndShowWindow(
    _ identifier: String,
    controller: inout ModernWindowController?,
    show: Bool = true,
    focus: Bool = true,
    screen: NSScreen? = nil,
    position: NSPoint? = nil
) {
    mainThread {
        guard let mainStoryboard = NSStoryboard.main else { return }

        if identifier == "windowController" {
            appDelegate!.initPopovers()
        }
        if controller == nil {
            controller = mainStoryboard
                .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(identifier)) as? ModernWindowController
        }

        if show, let wc = controller {
            if let screen, let w = wc.window, w.screen != screen {
                let size = w.frame.size
                w.setFrameOrigin(CGPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.midY - size.height / 2))
            } else if let position, let w = wc.window {
                w.setFrameOrigin(position)
            }

            if wc.window == nil || wc.window!.canBecomeKey {
                wc.showWindow(nil)
            }

            if focus {
                if let window = wc.window as? ModernWindow {
                    log.debug("Focusing window '\(window.title)'")
                    window.orderFrontRegardless()
                }

                NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }
}

func shortHash(string: String, length: Int = 8) -> String {
    guard let data = string.data(using: .utf8, allowLossyConversion: true) else { return string }
    return data.sha256.prefix(length).s
}

func generateAPIKey() -> String {
    var r = SystemRandomNumberGenerator()
    let serialNumberData = Data(r.next().toUInt8Array() + r.next().toUInt8Array() + r.next().toUInt8Array() + r.next().toUInt8Array())
    let hash = serialNumberData.sha256Data.prefix(20).str(base64: true, separator: "").map { (c: Character) -> Character in
        switch c {
        case "/": Character(".")
        case "+": Character(".")
        default: c
        }
    }.str()
//    log.info("APIKey: \(hash)")
    return hash
}

func getSerialNumberHash() -> String? {
    let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))

    guard platformExpert > 0 else {
        return nil
    }

    defer { IOObjectRelease(platformExpert) }

    guard let serialNumber: String = IOServiceProperty(platformExpert, kIOPlatformSerialNumberKey) else {
        return nil
    }

    guard let serialNumberData = serialNumber.trimmed.data(using: .utf8, allowLossyConversion: true) else {
        return nil
    }
    let hash = serialNumberData.sha256Data.prefix(20).str(base64: true, separator: "").map { (c: Character) -> Character in
        switch c {
        case "/": Character(".")
        case "+": Character(".")
        default: c
        }
    }.str()
//    log.info("SerialNumberHash: \(hash)")

    return hash
}

let SERIAL_NUMBER_HASH = getSerialNumberHash() ?? generateAPIKey()

@discardableResult
@inline(__always) func mainThreadThrows<T>(_ action: () throws -> T) throws -> T {
    guard !Thread.isMainThread else {
        return try action()
    }
    return try DispatchQueue.main.sync { try action() }
}

@discardableResult
@inline(__always) func mainThread<T>(_ action: () -> T) -> T {
    guard !Thread.isMainThread else {
        return action()
    }
    return DispatchQueue.main.sync { action() }
}

@inline(__always) @discardableResult func mainAsync(_ action: @escaping () -> Void) -> DispatchWorkItem? {
    guard !Thread.isMainThread else {
        action()
        return nil
    }
    let workItem = DispatchWorkItem(name: "mainAsync") { action() }
    DispatchQueue.main.async(execute: workItem.workItem)
    return workItem
}

func stringRepresentation(forAddress address: Data) -> String? {
    address.withUnsafeBytes { pointer in
        var hostStr = [Int8](repeating: 0, count: Int(NI_MAXHOST))

        let result = getnameinfo(
            pointer.baseAddress?.assumingMemoryBound(to: sockaddr.self),
            socklen_t(address.count),
            &hostStr,
            socklen_t(hostStr.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return nil }
        return String(cString: hostStr)
    }
}

let IPV6_INTERFACE_REGEX = "%.+".r!

func resolve(hostname: String) -> String? {
    let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
    CFHostStartInfoResolution(host, .addresses, nil)
    var success: DarwinBoolean = false
    guard let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray? else {
        return nil
    }
    let ips: [String] = addresses.compactMap { addr in
        guard let data = (addr as? NSData) as? Data, let ip = stringRepresentation(forAddress: data) else {
            return nil
        }

        return ip.contains(":") ? IPV6_INTERFACE_REGEX.replaceAll(in: ip, with: "") : ip
    }
    return ips.first { !$0.contains(":") } ?? ips.first
}

@discardableResult
func serialAsyncAfter(ms: Int, name: String = "serialAsyncAfter", _ action: @escaping () -> Void) -> DispatchWorkItem {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    let workItem = DispatchWorkItem(name: name) {
        action()
    }
    serialQueue.asyncAfter(deadline: deadline, execute: workItem.workItem)

    return workItem
}

func serialAsyncAfter(ms: Int, _ action: DispatchWorkItem) {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    serialQueue.asyncAfter(deadline: deadline, execute: action.workItem)
}

func cancelScreenWakeAdapterTask() {
    appDelegate!.screenWakeAdapterTask = nil
}

@discardableResult func asyncNow(
    timeout: DateComponents? = nil,
    queue: DispatchQueue? = nil,
    threaded: Bool = false,
    barrier: Bool = false,
    _ action: @escaping () -> Void
) -> DispatchTimeoutResult {
    if threaded {
        guard let timeout else {
            let thread = Thread { action() }
            thread.start()
            return .success
        }

        let semaphore = DispatchSemaphore(value: 0, name: "Async Thread Timeout")

        let thread = Thread {
            action()
            semaphore.signal()
        }
        thread.start()

        let result = semaphore.wait(for: timeout)
        if result == .timedOut {
            thread.cancel()
        }

        return result
    }

    let queue = queue ?? concurrentQueue
    guard let timeout else {
        if barrier {
            queue.asyncAfter(deadline: DispatchTime.now(), flags: .barrier) { action() }
        } else {
            queue.async { action() }
        }
        return .success
    }

    let task = DispatchWorkItem(name: "async(\(queue.label))") {
        action()
    }
    queue.async(execute: task.workItem)

    let result = task.wait(for: timeout)
    if result == .timedOut {
        task.cancel()
    }

    return result
}

func asyncEvery(_ interval: DateComponents, qos: QualityOfService? = nil, _ action: @escaping (inout TimeInterval) -> Void) -> Thread {
    let thread = Thread {
        var pollingInterval = interval.timeInterval
        while true {
            action(&pollingInterval)
            if Thread.current.isCancelled { return }
            Thread.sleep(forTimeInterval: pollingInterval)
            if Thread.current.isCancelled { return }
        }
    }

    if let qos {
        thread.qualityOfService = qos
    }

    thread.start()
    return thread
}

var globalObservers: [String: AnyCancellable] = Dictionary(minimumCapacity: 100)

extension DispatchQueue {
    func syncSafe<T>(_ action: @escaping () -> T) -> T {
        if let q = DispatchQueue.current, self == q {
            action()
        } else {
            sync { action() }
        }
    }
    func syncSafe(execute task: DispatchWorkItem) {
        if let q = DispatchQueue.current, self == q {
            task.workItem.perform()
        } else {
            sync(execute: task.workItem)
        }
    }
}

extension DispatchQueue {
    @discardableResult
    func asyncAfter(ms: Int, name: String = "asyncAfter", _ action: @escaping () -> Void) -> DispatchWorkItem {
        let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

        let workItem = DispatchWorkItem(name: "\(label) \(name) \(ms)ms") {
            action()
        }
        asyncAfter(deadline: deadline, execute: workItem.workItem)

        return workItem
    }
}

func asyncAfter(ms: Int, _ action: DispatchWorkItem) {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    concurrentQueue.asyncAfter(deadline: deadline, execute: action.workItem)
}

@discardableResult
func mainAsyncAfter(ms: Int, name: String = "mainAsyncAfter", _ action: @escaping () -> Void) -> DispatchWorkItem {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    let workItem = DispatchWorkItem(name: name) {
        action()
    }
    DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem.workItem)

    return workItem
}

func listener<T>(in observers: inout Set<AnyCancellable>, throttle: RunLoop.SchedulerTimeType.Stride? = nil, debounce: RunLoop.SchedulerTimeType.Stride? = nil, _ action: @escaping (T) -> Void) -> PassthroughSubject<T, Never> {
    let subject = PassthroughSubject<T, Never>()

    if let debounce {
        subject
            .debounce(for: debounce, scheduler: RunLoop.main)
            .sink { action($0) }
            .store(in: &observers)
    } else if let throttle {
        subject
            .throttle(for: throttle, scheduler: RunLoop.main, latest: true)
            .sink { action($0) }
            .store(in: &observers)
    } else {
        subject
            .sink { action($0) }
            .store(in: &observers)
    }

    return subject
}

func mainAsyncAfter(ms: Int, _ action: DispatchWorkItem) {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    DispatchQueue.main.asyncAfter(deadline: deadline, execute: action.workItem)
}

extension Double {
    @inline(__always) @inlinable
    func map(from: (Double, Double), to: (Double, Double)) -> Double {
        lerp(invlerp(self, min: from.0, max: from.1), min: to.0, max: to.1)
    }
    @inline(__always) @inlinable
    func map(from: (Double, Double), to: (Double, Double), gamma: Double) -> Double {
        lerp(pow(invlerp(self, min: from.0, max: from.1), 1.0 / gamma), min: to.0, max: to.1)
    }
    @inline(__always)
    func capped(between minVal: Double, and maxVal: Double) -> Double {
        cap(self, minVal: minVal, maxVal: maxVal)
    }
    @inline(__always)
    func remainderDistance(_ x: Double) -> Double {
        abs(self / x - (self / x).rounded())
    }
}
extension Float {
    @inline(__always) @inlinable
    func map(from: (Float, Float), to: (Float, Float)) -> Float {
        lerp(invlerp(self, min: from.0, max: from.1), min: to.0, max: to.1)
    }
    @inline(__always) @inlinable
    func map(from: (Float, Float), to: (Float, Float), gamma: Float) -> Float {
        lerp(pow(invlerp(self, min: from.0, max: from.1), 1.0 / gamma), min: to.0, max: to.1)
    }
    @inline(__always) @inlinable
    func capped(between minVal: Float, and maxVal: Float) -> Float {
        cap(self, minVal: minVal, maxVal: maxVal)
    }
    @inline(__always)
    func remainderDistance(_ x: Float) -> Float {
        abs(self / x - (self / x).rounded())
    }
}
extension CGFloat {
    @inline(__always) @inlinable
    func map(from: (CGFloat, CGFloat), to: (CGFloat, CGFloat)) -> CGFloat {
        lerp(invlerp(self, min: from.0, max: from.1), min: to.0, max: to.1)
    }
    @inline(__always) @inlinable
    func map(from: (CGFloat, CGFloat), to: (CGFloat, CGFloat), gamma: CGFloat) -> CGFloat {
        lerp(pow(invlerp(self, min: from.0, max: from.1), 1.0 / gamma), min: to.0, max: to.1)
    }
    @inline(__always) @inlinable
    func capped(between minVal: CGFloat, and maxVal: CGFloat) -> CGFloat {
        cap(self, minVal: minVal, maxVal: maxVal)
    }
}

func ramp(targetValue: Float, lastTargetValue: inout Float, samples: Int, step _: Float = 1.0) -> [Float] {
    var control = [Float](repeating: 0, count: samples)

    var from = lastTargetValue
    var to = targetValue

    var reversed = false
    if from > to {
        swap(&from, &to)
        reversed = true
    }

    if from == to {
        return [Float](repeating: from, count: samples)
    }

    control = vDSP.ramp(in: from ... to, count: samples)

    return reversed ? control.reversed() : control
}

// MARK: - Zip3Sequence

struct Zip3Sequence<E1, E2, E3>: Sequence, IteratorProtocol {
    init(_ s1: some Sequence<E1>, _ s2: some Sequence<E2>, _ s3: some Sequence<E3>) {
        var it1 = s1.makeIterator()
        var it2 = s2.makeIterator()
        var it3 = s3.makeIterator()
        _next = {
            guard let e1 = it1.next(), let e2 = it2.next(), let e3 = it3.next() else { return nil }
            return (e1, e2, e3)
        }
    }

    mutating func next() -> (E1, E2, E3)? {
        _next()
    }

    private let _next: () -> (E1, E2, E3)?
}

func zip3<S1: Sequence, S2: Sequence, S3: Sequence>(_ s1: S1, _ s2: S2, _ s3: S3) -> Zip3Sequence<S1.Element, S2.Element, S3.Element> {
    Zip3Sequence(s1, s2, s3)
}

// MARK: - Zip4Sequence

struct Zip4Sequence<E1, E2, E3, E4>: Sequence, IteratorProtocol {
    init(_ s1: some Sequence<E1>, _ s2: some Sequence<E2>, _ s3: some Sequence<E3>, _ s4: some Sequence<E4>) {
        var it1 = s1.makeIterator()
        var it2 = s2.makeIterator()
        var it3 = s3.makeIterator()
        var it4 = s4.makeIterator()
        _next = {
            guard let e1 = it1.next(), let e2 = it2.next(), let e3 = it3.next(), let e4 = it4.next() else { return nil }
            return (e1, e2, e3, e4)
        }
    }

    mutating func next() -> (E1, E2, E3, E4)? {
        _next()
    }

    private let _next: () -> (E1, E2, E3, E4)?
}

func zip4<S1: Sequence, S2: Sequence, S3: Sequence, S4: Sequence>(
    _ s1: S1,
    _ s2: S2,
    _ s3: S3,
    _ s4: S4
) -> Zip4Sequence<S1.Element, S2.Element, S3.Element, S4.Element> {
    Zip4Sequence(s1, s2, s3, s4)
}

// MARK: - ScreenCorner

enum ScreenCorner {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

func createWindow(
    _ identifier: String,
    controller: inout NSWindowController?,
    screen: NSScreen? = nil,
    show: Bool = true,
    backgroundColor: NSColor? = .clear,
    level: NSWindow.Level = .normal,
    fillScreen: Bool = false,
    stationary: Bool = false,
    corner: ScreenCorner? = nil,
    size: NSSize? = nil
) {
    mainThread {
        guard let mainStoryboard = NSStoryboard.main else { return }

        if controller == nil {
            controller = mainStoryboard
                .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(identifier)) as? NSWindowController
        }

        if let wc = controller {
            if let screen, let w = wc.window {
                if let size {
                    w.contentMaxSize = size
                    w.contentMinSize = size
                }
                if let corner {
                    switch corner {
                    case .bottomLeft:
                        w.setFrame(
                            NSRect(origin: NSPoint(x: screen.frame.minX, y: screen.frame.minY), size: size ?? w.frame.size),
                            display: false
                        )
                    case .bottomRight:
                        w.setFrame(
                            NSRect(origin: NSPoint(x: screen.frame.maxX, y: screen.frame.minY), size: size ?? w.frame.size),
                            display: false
                        )
                    case .topLeft:
                        w.setFrame(
                            NSRect(origin: NSPoint(x: screen.frame.minX, y: screen.frame.maxY), size: size ?? w.frame.size),
                            display: false
                        )
                    case .topRight:
                        w.setFrame(
                            NSRect(origin: NSPoint(x: screen.frame.maxX, y: screen.frame.maxY), size: size ?? w.frame.size),
                            display: false
                        )
                    }
                } else {
                    w.setFrameOrigin(CGPoint(x: screen.frame.minX, y: screen.frame.minY))
                    if fillScreen {
                        w.setFrame(screen.frame, display: false)
                    }
                }
            }

            if let window = wc.window {
                if let size, corner == nil {
                    window.setContentSize(size)
                }
                window.level = level
                window.isOpaque = false
                window.backgroundColor = backgroundColor
                if stationary {
                    window.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle, .fullScreenDisallowsTiling]
                    window.sharingType = .none
                    window.ignoresMouseEvents = true
                    window.setAccessibilityRole(.popover)
                    window.setAccessibilitySubrole(.unknown)
                }
                if show {
//                    log.debug("Showing window '\(window.title)'")
                    if window.canBecomeKey {
                        wc.showWindow(nil)
                    }
                    window.orderFrontRegardless()
                }
            }
        }
    }
}

var alertsByMessageSemaphore = DispatchSemaphore(value: 1, name: "alertsByMessageSemaphore")
var alertsByMessage = [String: Bool]()
import Regex

let WHITESPACE_REGEX = "\\s+".r!

let LEFT_ALIGNED_ALERT_TAG = 18665
var NS_ALERT_SWIZZLED = false

func dialog(
    message: String,
    info: String,
    okButton: String? = "OK",
    cancelButton: String? = "Cancel",
    thirdButton: String? = nil,
    screen: NSScreen? = nil,
    window: NSWindow? = nil,
    suppressionText: String? = nil,
    wide: Bool = false,
    ultrawide: Bool = false,
    markdown: Bool = false
) -> NSAlert {
    mainThread {
        NS_ALERT_SWIZZLED = NSAlert.classMethod
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .warning

        if ultrawide || wide {
            let tf = NSTextField(frame: NSRect(origin: .zero, size: NSSize(width: ultrawide ? 650 : 500, height: 0)))
            tf.alignment = .left
            tf.tag = LEFT_ALIGNED_ALERT_TAG
            alert.accessoryView = tf
        }

        if let okButton {
            alert.addButton(withTitle: okButton)
        }
        if let cancelButton {
            alert.addButton(withTitle: cancelButton)
        }
        if let thirdButton {
            alert.addButton(withTitle: thirdButton)
        }

        if let suppressionText {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = suppressionText
        }

        if let screen, !screen.isVirtual {
            let w = window ?? alert.window

            let alertSize = w.frame.size
            w.setFrameOrigin(CGPoint(x: screen.visibleFrame.midX - alertSize.width / 2, y: screen.visibleFrame.midY - alertSize.height / 2))
            w.makeKeyAndOrderFront(nil)
            if window != nil {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            if w.occlusionState != .visible, let screen = NSScreen.main {
                w
                    .setFrameOrigin(CGPoint(
                        x: screen.visibleFrame.midX - alertSize.width / 2,
                        y: screen.visibleFrame.midY - alertSize.height / 2
                    ))
                w.makeKeyAndOrderFront(nil)
            }
        }

        if markdown, let infoTextField = textField(alert: alert, containing: info) {
            infoTextField.attributedStringValue = MARKDOWN.attributedString(from: info).withParagraphStyle(.leftAligned)
            infoTextField.tag = LEFT_ALIGNED_ALERT_TAG
        }
        return alert
    }
}

extension NSAlert {
    private typealias Layout = @convention(c) (NSAlert) -> Void
    static let oldLayout = class_getInstanceMethod(NSAlert.self, #selector(NSAlert.layout))!
    static let oldLayoutIMP = method_getImplementation(oldLayout)
    static let classMethod: Bool = {
        let swizzledMethod = class_getInstanceMethod(NSAlert.self, #selector(NSAlert.swizzledLayout))
        method_exchangeImplementations(oldLayout, swizzledMethod!)

        return true
    }()

    @objc func swizzledLayout() {
        swizzledLayout()

        for view in window.contentView!.subviews {
            if let textField = view as? NSTextField, textField.tag == LEFT_ALIGNED_ALERT_TAG {
                textField.alignment = .left
                let attrs = textField.attributedStringValue.attributes(at: 0, effectiveRange: nil)
                if attrs[.paragraphStyle] == nil {
                    textField.attributedStringValue = textField.attributedStringValue.withParagraphStyle(.leftAligned)
                    continue
                }

                if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle, paragraphStyle.alignment != .left {
                    textField.attributedStringValue = textField.attributedStringValue.withParagraphStyle(.leftAligned)
                    continue
                }
            }
        }
    }
}

func textField(alert: NSAlert, containing text: String) -> NSTextField? {
    alert.window.contentView?.subviews.first { view in
        guard let s = (view as? NSTextField)?.stringValue else { return false }
        return WHITESPACE_REGEX.replaceAll(in: s, with: "") == WHITESPACE_REGEX.replaceAll(in: text, with: "")
    } as? NSTextField
}

func ask(
    message: String,
    info: String,
    window: NSWindow,
    okButton: String = "OK",
    cancelButton: String = "Cancel",
    timeout: DateComponents = 15.seconds,
    onCompletion: @escaping (Bool) -> Void
) {
    mainAsync {
        let alert = dialog(
            message: message,
            info: info,
            okButton: okButton,
            cancelButton: cancelButton,
            window: window
        )

        let semaphore = DispatchSemaphore(value: 0, name: "Panel alert dismissed")

        if let wc = window.windowController {
            log.debug("Showing window '\(window.title)'")
            if window.canBecomeKey {
                wc.showWindow(nil)
            }
            window.orderFrontRegardless()
        }

        alert.beginSheetModal(for: window, completionHandler: { resp in
            onCompletion(resp == .alertFirstButtonReturn)
            semaphore.signal()
        })
        asyncNow {
            if semaphore.wait(for: timeout) == .timedOut {
                mainThread {
                    if alert.window.isVisible {
                        alert.window.close()
                    }
                }
                onCompletion(false)
            }
        }
    }
}

func askAndHandle(
    message: String,
    info: String,
    okButton: String = "OK",
    cancelButton: String? = "Cancel",
    thirdButton: String? = nil,
    screen: NSScreen? = nil,
    window: NSWindow? = nil,
    suppressionText: String? = nil,
    onSuppression: ((Bool) -> Void)? = nil,
    unique: Bool = false,
    waitTimeout: DateComponents = 5.seconds,
    wide: Bool = false,
    ultrawide: Bool = false,
    markdown: Bool = false,
    onCompletion: ((Bool) -> Void)? = nil
) {
    let resp = askMultiButton(
        message: message,
        info: info,
        okButton: okButton,
        cancelButton: cancelButton,
        thirdButton: thirdButton,
        screen: screen,
        window: window,
        suppressionText: suppressionText,
        onSuppression: onSuppression,
        onCompletion: { resp in onCompletion?(resp == .alertFirstButtonReturn) },
        unique: unique,
        waitTimeout: waitTimeout,
        wide: wide,
        ultrawide: ultrawide,
        markdown: markdown
    ) == .alertFirstButtonReturn

    if window == nil {
        onCompletion?(resp)
    }
}

func askBool(
    message: String,
    info: String,
    okButton: String = "OK",
    cancelButton: String? = "Cancel",
    thirdButton: String? = nil,
    screen: NSScreen? = nil,
    window: NSWindow? = nil,
    suppressionText: String? = nil,
    onSuppression: ((Bool) -> Void)? = nil,
    onCompletion: ((Bool) -> Void)? = nil,
    unique: Bool = false,
    waitTimeout: DateComponents = 5.seconds,
    wide: Bool = false,
    ultrawide: Bool = false,
    markdown: Bool = false
) -> Bool {
    askMultiButton(
        message: message,
        info: info,
        okButton: okButton,
        cancelButton: cancelButton,
        thirdButton: thirdButton,
        screen: screen,
        window: window,
        suppressionText: suppressionText,
        onSuppression: onSuppression,
        onCompletion: { resp in onCompletion?(resp == .alertFirstButtonReturn) },
        unique: unique,
        waitTimeout: waitTimeout,
        wide: wide,
        ultrawide: ultrawide,
        markdown: markdown
    ) == .alertFirstButtonReturn
}

func askMultiButton(
    message: String,
    info: String,
    okButton: String = "OK",
    cancelButton: String? = "Cancel",
    thirdButton: String? = nil,
    screen: NSScreen? = nil,
    window: NSWindow? = nil,
    suppressionText: String? = nil,
    onSuppression: ((Bool) -> Void)? = nil,
    onCompletion: ((NSApplication.ModalResponse) -> Void)? = nil,
    unique: Bool = false,
    waitTimeout: DateComponents = 5.seconds,
    wide: Bool = false,
    ultrawide: Bool = false,
    markdown: Bool = false
) -> NSApplication.ModalResponse {
    if unique {
        defer { alertsByMessageSemaphore.signal() }
        switch alertsByMessageSemaphore.wait(for: waitTimeout) {
        case .success:
            if alertsByMessage[message] != nil {
                return .cancel
            }
            alertsByMessage[message] = true
        case .timedOut:
            log.warning("Timeout in waiting for alertsForMessage")
            return .cancel
        }
    }

    let response: NSApplication.ModalResponse = mainThread {
        let alert = dialog(
            message: message,
            info: info,
            okButton: okButton,
            cancelButton: cancelButton,
            thirdButton: thirdButton,
            screen: screen,
            window: window,
            suppressionText: suppressionText,
            wide: wide,
            ultrawide: ultrawide,
            markdown: markdown
        )

        if let window {
            if let wc = window.windowController {
                log.debug("Showing window '\(window.title)'")
                if window.canBecomeKey {
                    wc.showWindow(nil)
                }
                window.orderFrontRegardless()
            }

            alert.beginSheetModal(for: window, completionHandler: { resp in
                onCompletion?(resp)
                onSuppression?((alert.suppressionButton?.state ?? .off) == .on)

                if unique {
                    defer { alertsByMessageSemaphore.signal() }
                    switch alertsByMessageSemaphore.wait(for: 5) {
                    case .success:
                        alertsByMessage.removeValue(forKey: message)
                    case .timedOut:
                        log.warning("Timeout in waiting for alertsForMessage")
                    }
                }
            })
            return .cancel
        }

        let resp = alert.runModal()

        if let onSuppression {
            onSuppression((alert.suppressionButton?.state ?? .off) == .on)
        }

        if unique {
            defer { alertsByMessageSemaphore.signal() }
            switch alertsByMessageSemaphore.wait(for: 5) {
            case .success:
                alertsByMessage.removeValue(forKey: message)
            case .timedOut:
                log.warning("Timeout in waiting for alertsForMessage")
            }
        }
        return resp
    }
    return response
}

// MARK: - UnfairLock

/// An `os_unfair_lock` wrapper.
final class UnfairLock {
    init() {
        unfairLock = .allocate(capacity: 1)
        unfairLock.initialize(to: os_unfair_lock())
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }

    @Atomic var lockedInThread: Int32 = 0

    func locked() -> Bool { !os_unfair_lock_trylock(unfairLock) }

    /// Executes a closure returning a value while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    ///
    /// - Returns:           The value the closure generated.
    @inline(__always) func around<T>(_ closure: () -> T) -> T {
        let locked = lock(); defer { if locked { unlock() } }
        return closure()
    }

    /// Execute a closure while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    @inline(__always) func around(_ closure: () -> Void) {
        let locked = lock(); defer { if locked { unlock() } }
        return closure()
    }

    private let unfairLock: os_unfair_lock_t

    @discardableResult
    private func trylock() -> Bool {
        os_unfair_lock_trylock(unfairLock)
    }

    private func lock() -> Bool {
        var id: Int32?

        if #available(macOS 12, *) {
            let exc = tryBlock {
                id = Thread.current.value(forKeyPath: "seqNum") as? Int32
            }
            if exc != nil {
                tryBlock {
                    id = Thread.current.value(forKeyPath: "private.seqNum") as? Int32
                }
            }
        } else {
            let exc = tryBlock {
                id = Thread.current.value(forKeyPath: "private.seqNum") as? Int32
            }
            if exc != nil {
                tryBlock {
                    id = Thread.current.value(forKeyPath: "seqNum") as? Int32
                }
            }
        }

        guard let threadID = id, lockedInThread != threadID else {
            return trylock()
        }
        os_unfair_lock_lock(unfairLock)
        lockedInThread = threadID
        return true
    }

    private func unlock() {
        os_unfair_lock_unlock(unfairLock)
        lockedInThread = 0
    }
}

var mainThreadLocked = ManagedAtomic<Bool>(false)

extension NSRecursiveLock {
    @inline(__always) func aroundThrows<T>(
        timeout: TimeInterval = 10,
        ignoreMainThread: Bool = false,
        _ closure: () throws -> T
    ) throws -> T {
        if ignoreMainThread, Thread.isMainThread {
            return try closure()
        }

        let locked = lock(before: Date().addingTimeInterval(timeout))
        defer { if locked { unlock() } }

        return try closure()
    }

    @inline(__always) func around<T>(timeout: TimeInterval = 10, ignoreMainThread: Bool = false, _ closure: () -> T) -> T {
        if ignoreMainThread, Thread.isMainThread {
            return closure()
        }

        let locked = lock(before: Date().addingTimeInterval(timeout))
        defer { if locked { unlock() } }

        return closure()
    }

    @inline(__always) func around(timeout: TimeInterval = 10, ignoreMainThread: Bool = false, _ closure: () -> Void) {
        if ignoreMainThread, Thread.isMainThread {
            return closure()
        }

        let locked = lock(before: Date().addingTimeInterval(timeout))
        defer { if locked { unlock() } }

        closure()
    }
}

class ExpiringBool: ExpressibleByBooleanLiteral, CustomStringConvertible, ObservableObject {
    required init(booleanLiteral value: BooleanLiteralType) {
        self.value = value
    }

    deinit {
        if let task, !task.isCancelled {
            task.cancel()
        }
    }

    @Published var value: Bool
    var expiresAt: Date = .distantFuture

    var description: String {
        if let task, !task.isCancelled {
            return "\(value) (expires at \(expiresAt))"
        }
        return "\(value)"
    }
    var task: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }

    func expire() {
        if let task, !task.isCancelled {
            DispatchQueue.main.syncSafe(execute: task)
            self.task = nil
        }
    }

    func `true`(for time: TimeInterval) {
        set(true, expireAfter: time)
    }
    func `false`(for time: TimeInterval) {
        set(false, expireAfter: time)
    }

    func set(_ value: Bool, expireAfter: TimeInterval) {
        self.value = value
        expiresAt = .init(timeIntervalSinceNow: expireAfter)
        task = mainAsyncAfter(ms: (expireAfter * 1000).intround) { [self] in
            self.value = !value
        }
    }

    func toggle(expireAfter: TimeInterval) {
        value.toggle()
        expiresAt = .init(timeIntervalSinceNow: expireAfter)
        task = mainAsyncAfter(ms: (expireAfter * 1000).intround) { [self] in
            value.toggle()
        }
    }
}

extension Optional {
    var s: String {
        guard let self else {
            return "nil"
        }
        return "\(self)"
    }
}

class ExpiringOptional<T>: ExpressibleByNilLiteral, CustomStringConvertible, ObservableObject {
    required init(nilLiteral value: ()) {
        self.value = nil
    }

    deinit {
        if let task, !task.isCancelled {
            task.cancel()
        }
    }

    @Published var value: T?
    var expiresAt: Date = .distantFuture

    var description: String {
        if let task, !task.isCancelled {
            return "\(value.s) (expires at \(expiresAt))"
        }
        return "\(value.s)"
    }
    var task: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }

    func expire() {
        if let task, !task.isCancelled {
            DispatchQueue.main.syncSafe(execute: task)
            self.task = nil
        }
    }

    func setOrRefresh(_ value: T?, expireAfter: TimeInterval) {
        guard let value else {
            return
        }

        if self.value == nil {
            set(value, expireAfter: 1)
        } else {
            refresh(expireAfter: 1)
        }
    }

    func set(_ value: T, expireAfter: TimeInterval) {
        self.value = value
        refresh(expireAfter: expireAfter)
    }

    func refresh(expireAfter: TimeInterval) {
        guard value != nil else { return }

        expiresAt = .init(timeIntervalSinceNow: expireAfter)
        task = mainAsyncAfter(ms: (expireAfter * 1000).intround) { [self] in
            value = nil
        }
    }
}

// MARK: - AtomicLock

@propertyWrapper
struct AtomicLock<Value> {
    init(wrappedValue: Value) {
        value = wrappedValue
    }

    var value: Value
    var lock = NSRecursiveLock()

    var wrappedValue: Value {
        get {
            lock.around { value }
        }
        set {
            lock.around { value = newValue }
        }
    }

}

// MARK: - Atomic

@propertyWrapper
struct Atomic<Value: AtomicValue> where Value.AtomicRepresentation.Value == Value {
    init(wrappedValue: Value) {
        value = ManagedAtomic<Value>(wrappedValue)
    }

    var value: ManagedAtomic<Value>

    var wrappedValue: Value {
        get {
            value.load(ordering: .relaxed)
        }
        set {
            value.store(newValue, ordering: .sequentiallyConsistent)
        }
    }

}

// MARK: - AtomicOptional

@propertyWrapper
struct AtomicOptional<Value: AtomicValue & Equatable> where Value.AtomicRepresentation.Value == Value {
    init(wrappedValue: Value?, nilValue: Value) {
        self.nilValue = nilValue
        value = ManagedAtomic<Value>(wrappedValue ?? nilValue)
    }

    var nilValue: Value
    var value: ManagedAtomic<Value>

    var wrappedValue: Value? {
        get {
            let v = value.load(ordering: .relaxed)
            return v == nilValue ? nil : v
        }
        set {
            value.store(newValue ?? nilValue, ordering: .sequentiallyConsistent)
        }
    }

}

// MARK: - LazyAtomic

@propertyWrapper
struct LazyAtomic<Value> {
    init(wrappedValue constructor: @autoclosure @escaping () -> Value) {
        self.constructor = constructor
    }

    var storage: Value?
    let constructor: () -> Value

    var wrappedValue: Value {
        mutating get {
            if storage == nil {
                storage = constructor()
            }
            return storage!
        }
        set {
            storage = newValue
        }
    }

}

func localNow() -> DateInRegion {
    Region.local.nowInThisRegion()
}

func monospace(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    NSFont.monospacedSystemFont(ofSize: size, weight: weight)
}

func displayInfoDictionary(_ id: CGDirectDisplayID) -> NSDictionary? {
    guard CGDisplayIsOnline(id) != 0 else {
        return nil
    }
    let unmanagedDict = CoreDisplay_DisplayCreateInfoDictionary(id)
    let retainedDict = unmanagedDict?.takeRetainedValue()
    guard let dict = retainedDict as NSDictionary? else {
        return nil
    }

    return dict
}

// MARK: - PlainTextPasteView

final class PlainTextPasteView: NSTextView, NSTextViewDelegate {
    override func paste(_ sender: Any?) {
        super.pasteAsPlainText(sender)
    }
}

// MARK: - PlainTextFieldCell

class PlainTextFieldCell: NSTextFieldCell {
    static var plainTextView: PlainTextPasteView?

    override func fieldEditor(for _: NSView) -> NSTextView? {
        if Self.plainTextView == nil {
            Self.plainTextView = PlainTextPasteView()
        }
        return Self.plainTextView
    }
}

@inline(__always) @inlinable
func cap<T: Comparable>(_ number: T, minVal: T, maxVal: T) -> T {
    max(min(number, maxVal), minVal)
}

import Defaults

func notify(identifier: String, title: String, body: String) {
    let sendNotification = { (nc: UNUserNotificationCenter) in
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        nc.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: nil),
            withCompletionHandler: nil
        )
    }

    let nc = UNUserNotificationCenter.current()
    nc.getNotificationSettings { settings in
        mainAsync {
            let enabled = settings.alertSetting == .enabled
            Defaults[.notificationsPermissionsGranted] = enabled
            guard enabled else {
                nc.requestAuthorization(options: [], completionHandler: { granted, _ in
                    guard granted else { return }
                    sendNotification(nc)
                })
                return
            }
            sendNotification(nc)
        }
    }
}

func removeNotifications(withIdentifiers ids: [String]) {
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
}

// MARK: - Window

struct Window {
    init(from dict: [String: AnyObject], appException: AppException? = nil, runningApp: NSRunningApplication? = nil) {
        storeType = (dict[kCGWindowStoreType as String] as? Int) ?? 0
        isOnScreen = (dict[kCGWindowIsOnscreen as String] as? Bool) ?? false
        layer = NSWindow.Level(rawValue: (dict[kCGWindowLayer as String] as? Int) ?? NSWindow.Level.normal.rawValue)
        title = (dict[kCGWindowName as String] as? String) ?? ""
        ownerName = (dict[kCGWindowOwnerName as String] as? String) ?? ""
        alpha = (dict[kCGWindowAlpha as String] as? Float) ?? 1

        if let rectDict = dict[kCGWindowBounds as String], let rect = CGRect(dictionaryRepresentation: rectDict as! CFDictionary) {
            bounds = rect as NSRect
            screen = NSScreen.screens.first { NSRect(
                x: $0.frame.origin.x,
                y: $0.frame.origin.y - $0.frame.height,
                width: $0.frame.width,
                height: $0.frame.height
            ).intersects(rect as NSRect) }
        } else {
            bounds = NSRect()
            screen = nil
        }

        id = (dict[kCGWindowNumber as String] as? Int) ?? 0
        ownerPID = (dict[kCGWindowOwnerPID as String] as? Int) ?? 0
        sharingState = (dict[kCGWindowSharingState as String] as? Int) ?? 0
        memoryUsage = (dict[kCGWindowMemoryUsage as String] as? Int) ?? 0
        self.appException = appException
        self.runningApp = runningApp
    }

    let storeType: Int
    let isOnScreen: Bool
    let layer: NSWindow.Level
    let title: String
    let ownerName: String
    let alpha: Float
    let bounds: NSRect
    let id: Int
    let ownerPID: Int
    let sharingState: Int
    let memoryUsage: Int
    let screen: NSScreen?
    let appException: AppException?
    let runningApp: NSRunningApplication?
}

extension NSRect {
    func intersectedArea(_ other: NSRect) -> CGFloat {
        let i = intersection(other)
        return i.height * i.width
    }
}

// MARK: - AXWindow

struct AXWindow {
    init?(from window: UIElement, runningApp: NSRunningApplication? = nil, appException: AppException? = nil) {
        guard let attrs = try? window.getMultipleAttributes(
            .frame,
            .fullScreen,
            .title,
            .position,
            .main,
            .minimized,
            .size,
            .identifier,
            .subrole,
            .role,
            .focused
        )
        else {
            return nil
        }

        let frame = attrs[.frame] as? NSRect ?? NSRect()

        self.frame = frame
        fullScreen = attrs[.fullScreen] as? Bool ?? false
        title = attrs[.title] as? String ?? ""
        position = attrs[.position] as? NSPoint ?? NSPoint()
        main = attrs[.main] as? Bool ?? false
        minimized = attrs[.minimized] as? Bool ?? false
        focused = attrs[.focused] as? Bool ?? false
        size = attrs[.size] as? NSSize ?? NSSize()
        identifier = attrs[.identifier] as? String ?? ""
        subrole = attrs[.subrole] as? String ?? ""
        role = attrs[.role] as? String ?? ""

        self.runningApp = runningApp
        self.appException = appException
        #if DEBUG
            log.debug("\(appException?.description ?? "") \(title) frame: \(frame)")
            for screen in NSScreen.screens {
                guard let id = screen.displayID else { continue }
                log.debug("Screen \(id) frame: \(screen.frame)")
                log.debug("Screen \(id) bounds: \(CGDisplayBounds(id))")
            }
        #endif
        screen = NSScreen.screens.filter {
            guard let bounds = $0.bounds else { return false }
            return bounds.intersects(frame)
        }.max(by: { s1, s2 in
            guard let bounds1 = s1.bounds, let bounds2 = s2.bounds else { return false }
            return bounds1.intersectedArea(frame) < bounds2.intersectedArea(frame)
        })
    }

    let frame: NSRect
    let fullScreen: Bool
    let title: String
    let position: NSPoint
    let main: Bool
    let minimized: Bool
    let focused: Bool
    let size: NSSize
    let identifier: String
    let subrole: String
    let role: String
    let runningApp: NSRunningApplication?
    let appException: AppException?
    let screen: NSScreen?
}

extension NSRunningApplication {
    func windows(appException: AppException? = nil) -> [AXWindow]? {
        guard let app = Application(self) else { return nil }
        do {
            let wins = try app.windows()
            return wins?.compactMap { AXWindow(from: $0, runningApp: self, appException: appException) }
        } catch {
            log.error("Can't get windows for app \(self): \(error)")
            return nil
        }
    }
}

func windowList(
    for app: NSRunningApplication,
    onscreen: Bool? = nil,
    opaque: Bool? = nil,
    withTitle: Bool? = nil,
    levels: Set<NSWindow.Level>? = nil,
    appException: AppException? = nil
) -> [Window]? {
    windowList(
        for: app.processIdentifier.i,
        onscreen: onscreen,
        opaque: opaque,
        withTitle: withTitle,
        levels: levels,
        appException: appException,
        runningApp: app
    )
}

func windowList(
    for pid: Int,
    onscreen: Bool? = nil,
    opaque: Bool? = nil,
    withTitle: Bool? = nil,
    levels: Set<NSWindow.Level>? = nil,
    appException: AppException? = nil,
    runningApp: NSRunningApplication? = nil
) -> [Window]? {
    let options: CGWindowListOption = (onscreen == true) ? [.excludeDesktopElements, .optionOnScreenOnly] : [.excludeDesktopElements]
    guard let cgWindowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as NSArray? as? [[String: AnyObject]] else {
        return nil
    }

    let windows = cgWindowListInfo.filter { windowDict in
        guard let ownerProcessID = windowDict[kCGWindowOwnerPID as String] as? Int else { return false }
        if let opaque, (((windowDict[kCGWindowAlpha as String] as? Float) ?? 0) > 0) != opaque { return false }
        if let withTitle, ((windowDict[kCGWindowName as String] as? String) ?? "").isEmpty != withTitle { return false }
        if let levels, !levels.contains(
            NSWindow.Level(rawValue: (windowDict[kCGWindowLayer as String] as? Int) ?? NSWindow.Level.normal.rawValue)
        ) {
            return false
        }

        return pid == ownerProcessID
    }.map {
        Window(from: $0, appException: appException, runningApp: runningApp)
    }

    return windows
}

func activeWindow(on screen: NSScreen? = nil) -> AXWindow? {
    guard let frontMostApp = NSWorkspace.shared.frontmostApplication else {
        return nil
    }

    let appException = DC.runningAppExceptions.first { $0.identifier == frontMostApp.bundleIdentifier }

    return frontMostApp.windows(appException: appException)?.first(where: { w in
        !w.minimized && w.size != .zero
            && w.screen?.displayID == screen?.displayID
    })

//    return windowList(for: frontMostApp, opaque: true, levels: [.normal, .modalPanel, .popUpMenu, .floating], appException: appException)?
//        .filter { screen == nil || $0.screen?.displayID == screen!.displayID }
//        .min { $0.layer < $1.layer && $0.isOnScreen.i >= $1.isOnScreen.i }
}

// MARK: - LineReader

final class LineReader {
    init?(path: String) {
        self.path = path
        guard let file = fopen(path, "r") else {
            return nil
        }
        self.file = file
    }

    deinit {
        fclose(file)
    }

    let path: String

    var nextLine: String? {
        var line: UnsafeMutablePointer<CChar>?
        var linecap = 0
        defer {
            if let line {
                free(line)
            }
        }
        let status = getline(&line, &linecap, file)
        guard status > 0, let unwrappedLine = line else {
            return nil
        }
        return String(cString: unwrappedLine)
    }

    private let file: UnsafeMutablePointer<FILE>
}

// MARK: Sequence

extension LineReader: Sequence {
    func makeIterator() -> AnyIterator<String> {
        AnyIterator<String> {
            self.nextLine
        }
    }
}

func getModeDetails(_ mode: MPDisplayMode?, prefix: String = "\t") -> String {
    guard let mode else { return "nil" }
    return """
        \(prefix)refreshString: \(mode.refreshStringSafe)
        \(prefix)resolutionString: \(mode.resolutionStringSafe)
        \(prefix)isSafeMode: \(mode.isSafeMode)
        \(prefix)tvModeEquiv: \(mode.tvModeEquiv)
        \(prefix)tvMode: \(mode.tvMode)
        \(prefix)isTVMode: \(mode.isTVMode)
        \(prefix)isSimulscan: \(mode.isSimulscan)
        \(prefix)isInterlaced: \(mode.isInterlaced)
        \(prefix)isNativeMode: \(mode.isNativeMode)
        \(prefix)isDefaultMode: \(mode.isDefaultMode)
        \(prefix)isStretched: \(mode.isStretched)
        \(prefix)isUserVisible: \(mode.isUserVisible)
        \(prefix)isHiDPI: \(mode.isHiDPI)
        \(prefix)isRetina: \(mode.isRetina)
        \(prefix)scanRate: \(mode.scanRate ?? 0)
        \(prefix)roundedScanRate: \(mode.roundedScanRate)
        \(prefix)scale: \(mode.scale)
        \(prefix)aspectRatio: \(mode.aspectRatio)
        \(prefix)fixPtRefreshRate: \(mode.fixPtRefreshRate)
        \(prefix)refreshRate: \(mode.refreshRate)
        \(prefix)dotsPerInch: \(mode.dotsPerInch)
        \(prefix)vertDPI: \(mode.vertDPI)
        \(prefix)horizDPI: \(mode.horizDPI)
        \(prefix)pixelsHigh: \(mode.pixelsHigh)
        \(prefix)pixelsWide: \(mode.pixelsWide)
        \(prefix)height: \(mode.height)
        \(prefix)width: \(mode.width)
        \(prefix)modeNumber: \(mode.modeNumber)
    """
}

import AnyCodable

func getModeDetailsJSON(_ mode: MPDisplayMode?) -> [String: Any]? {
    guard let mode else { return nil }
    return [
        "refreshString": mode.refreshStringSafe,
        "resolutionString": mode.resolutionStringSafe,
        "isSafeMode": mode.isSafeMode,
        "tvModeEquiv": mode.tvModeEquiv,
        "tvMode": mode.tvMode,
        "isTVMode": mode.isTVMode,
        "isSimulscan": mode.isSimulscan,
        "isInterlaced": mode.isInterlaced,
        "isNativeMode": mode.isNativeMode,
        "isDefaultMode": mode.isDefaultMode,
        "isStretched": mode.isStretched,
        "isUserVisible": mode.isUserVisible,
        "isHiDPI": mode.isHiDPI,
        "isRetina": mode.isRetina,
        "scanRate": mode.scanRate ?? 0,
        "roundedScanRate": mode.roundedScanRate,
        "scale": mode.scale,
        "aspectRatio": mode.aspectRatio,
        "fixPtRefreshRate": mode.fixPtRefreshRate,
        "refreshRate": mode.refreshRate,
        "dotsPerInch": mode.dotsPerInch,
        "vertDPI": mode.vertDPI,
        "horizDPI": mode.horizDPI,
        "pixelsHigh": mode.pixelsHigh,
        "pixelsWide": mode.pixelsWide,
        "height": mode.height,
        "width": mode.width,
        "modeNumber": mode.modeNumber,
    ]
}

func getMonitorPanelDataJSON(
    _ display: MPDisplay,
    includeModes: Bool = false,
    modeFilter: ((MPDisplayMode) -> Bool)? = nil
) -> [String: Any] {
    [
        "id": display.displayID,
        "aliasID": display.aliasID,
        "canChangeOrientation": display.canChangeOrientation(),
        "hasRotationSensor": display.hasRotationSensor,
        "hasZeroRate": display.hasZeroRate,
        "hasMultipleRates": display.hasMultipleRates,
        "isSidecarDisplay": display.isSidecarDisplay,
        "isAirPlayDisplay": display.isAirPlayDisplay,
        "isProjector": display.isProjector,
        "is4K": display.is4K,
        "isTV": display.isTV,
        "isMirrorMaster": display.isMirrorMaster,
        "isMirrored": display.isMirrored,
        "isBuiltIn": display.isBuiltIn,
        "isHiDPI": display.isHiDPI,
        "hasTVModes": display.hasTVModes,
        "hasSimulscan": display.hasSimulscan,
        "hasSafeMode": display.hasSafeMode,
        "isSmartDisplay": display.isSmartDisplay,
        "isAppleProDisplay": display.isAppleProDisplay,
        "uuid": (display.uuid?.uuidString ?? "") as Any,
        "isForcedToMirror": display.isForcedToMirror,
        "hasMenuBar": display.hasMenuBar,
        "isBuiltInRetina": display.isBuiltInRetina,
        "titleName": (display.titleName ?? "") as Any,
        "name": (display.displayName ?? "") as Any,
        "orientation": display.orientation,
        "modes": [String: Any](
            (includeModes ? (display.allModes() ?? []) : [])
                .filter(modeFilter ?? { _ in true })
                .compactMap { mode in
                    guard let modeJSON = getModeDetailsJSON(mode) else { return nil }
                    return (mode.description.replacingOccurrences(of: "\n", with: ", "), modeJSON)
                } + [
                    ("default", getModeDetailsJSON(display.defaultMode) as Any),
                    ("native", getModeDetailsJSON(display.nativeMode) as Any),
                    ("current", getModeDetailsJSON(display.currentMode) as Any),
                ],
            uniquingKeysWith: first(this:other:)
        ),
    ]
}

func getMonitorPanelData(_ display: MPDisplay) -> String {
    """
    ID: \(display.displayID)
    Alias ID: \(display.aliasID)
    canChangeOrientation: \(display.canChangeOrientation())
    hasRotationSensor: \(display.hasRotationSensor)
    hasZeroRate: \(display.hasZeroRate)
    hasMultipleRates: \(display.hasMultipleRates)
    isSidecarDisplay: \(display.isSidecarDisplay)
    isAirPlayDisplay: \(display.isAirPlayDisplay)
    isProjector: \(display.isProjector)
    is4K: \(display.is4K)
    isTV: \(display.isTV)
    isMirrorMaster: \(display.isMirrorMaster)
    isMirrored: \(display.isMirrored)
    isBuiltIn: \(display.isBuiltIn)
    isHiDPI: \(display.isHiDPI)
    hasTVModes: \(display.hasTVModes)
    hasSimulscan: \(display.hasSimulscan)
    hasSafeMode: \(display.hasSafeMode)
    isSmartDisplay: \(display.isSmartDisplay)
    orientation: \(display.orientation)

    Default mode:
    \(getModeDetails(display.defaultMode, prefix: "\t"))

    Native mode:
    \(getModeDetails(display.nativeMode, prefix: "\t"))

    Current mode:
    \(getModeDetails(display.currentMode, prefix: "\t"))

    All modes:
    \(
        display.allModes()?
            .map { "\t\($0.description.replacingOccurrences(of: "\n", with: ", ")):\n\(getModeDetails($0, prefix: "\t\t"))" }
            .joined(separator: "\n\n") ?? "nil"
    )
    """
}

func contactURL() -> URL {
    guard var urlBuilder = URLComponents(url: CONTACT_URL, resolvingAgainstBaseURL: false) else {
        return CONTACT_URL
    }
    urlBuilder.queryItems = [URLQueryItem(name: "userid", value: SERIAL_NUMBER_HASH)]

    if let licenseCode = producct?.licenseCode {
        urlBuilder.queryItems?.append(URLQueryItem(name: "code", value: licenseCode))
    }

    if let email = producct?.activationEmail {
        urlBuilder.queryItems?.append(URLQueryItem(name: "email", value: email))
    }

    return urlBuilder.url ?? CONTACT_URL
}

extension NSView {
    class func loadFromNib<T>(withName nibName: String, for owner: Any) -> T? {
        var nibObjects: NSArray?
        let bundle = Bundle(identifier: "fyi.lunar.Lunar")
        guard let nib = NSNib(nibNamed: nibName, bundle: bundle),
              nib.instantiate(withOwner: owner, topLevelObjects: &nibObjects),
              let view = nibObjects?.compactMap({ $0 as? T }).first
        else { return nil }

        return view
    }
}

func memoryFootprint() -> Double? {
    // The `TASK_VM_INFO_COUNT` and `TASK_VM_INFO_REV1_COUNT` macros are too
    // complex for the Swift C importer, so we have to define them ourselves.
    let TASK_VM_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(
        MemoryLayout
            .offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size
    )
    var info = task_vm_info_data_t()
    var count = TASK_VM_INFO_COUNT
    let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
        infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
        }
    }
    guard kr == KERN_SUCCESS,
          count >= TASK_VM_INFO_REV1_COUNT
    else { return nil }

    let usedBytes = Double(info.phys_footprint)
    return usedBytes
}

func memoryFootprintMB() -> Double? {
    guard let usedBytes = memoryFootprint() else { return nil }
    let usedMB = usedBytes / 1024 / 1024
    return usedMB
}

func formattedMemoryFootprint() -> String {
    let usedMBAsString = "Memory Used by App: \((memoryFootprintMB() ?? 0).str(decimals: 2)) MB"
    return usedMBAsString
}

import SystemConfiguration

// MARK: - Reachability

final class Reachability {
    final class func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)

        guard let defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else {
            log.error("ReachabilityError.failedToCreateWithAddress: \(SCError())")
            return true
        }

        var flags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) == false {
            return false
        }

        let isReachable = flags == .reachable
        let needsConnection = flags == .connectionRequired

        return isReachable && !needsConnection
    }
}

let DISPLAYLINK_IDENTIFIER = "com.displaylink.DisplayLinkUserAgent"

func displayLinkApp() -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: DISPLAYLINK_IDENTIFIER).first
}

func isDisplayLinkRunning() -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: DISPLAYLINK_IDENTIFIER).isEmpty
}

func getConnectedKeyboards() -> Int {
    var iterator: io_iterator_t = 0
    var service: io_registry_entry_t = 0
    var count = 0

    let matching = IOServiceMatching(kIOHIDDeviceKey)
    let result = IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &iterator)
    guard result == kIOReturnSuccess else {
        return count
    }

    service = IOIteratorNext(iterator)
    while service != 0 {
        if IOServiceProperty(service, kIOHIDTransportKey) == "USB" {
            count += 1
        }

        IOObjectRelease(service)
        service = IOIteratorNext(iterator)
    }

    IOObjectRelease(iterator)
    return count
}

import var Darwin.EINVAL
import var Darwin.ERANGE
import func Darwin.strerror_r

public func stringerror(_ code: Int32) -> String {
    var cap = 64
    while cap <= 16 * 1024 {
        var buf = [Int8](repeating: 0, count: cap)
        let err = strerror_r(code, &buf, buf.count)
        if err == EINVAL {
            return "unknown error \(code)"
        }
        if err == ERANGE {
            cap *= 2
            continue
        }
        if err != 0 {
            return "fatal: strerror_r: \(err)"
        }
        return "\(String(cString: buf)) (\(code))"
    }
    return "fatal: strerror_r: ERANGE"
}

public func exec(arg0: String, args: [String]) throws -> Never {
    let args = CStringArray([arg0] + args)

    guard execv(arg0, args.cArray) != -1 else {
        throw POSIXError.execv(executable: arg0, errno: errno)
    }

    fatalError("Impossible if execv succeeded")
}

// MARK: - POSIXError

public enum POSIXError: LocalizedError {
    case execv(executable: String, errno: Int32)

    public var errorDescription: String? {
        switch self {
        case let .execv(executablePath, errno):
            "execv failed: \(stringerror(errno)): \(executablePath)"
        }
    }
}

// MARK: - CStringArray

private final class CStringArray {
    /// Creates an instance from an array of strings.
    public init(_ array: [String]) {
        cArray = array.map { $0.withCString { strdup($0) } } + [nil]
    }

    deinit {
        for case let element? in cArray {
            free(element)
        }
    }

    /// The null-terminated array of C string pointers.
    public let cArray: [UnsafeMutablePointer<Int8>?]

}

func mainActor(_ action: @escaping @MainActor () -> Void) {
    Task.init { await MainActor.run { action() }}
}

let FLUX_IDENTIFIER = "org.herf.Flux"
let LUNAR_IDENTIFIER = "com.lowtechguys.GammaDimmer"
let MC_IDENTIFIER = "me.guillaumeb.MonitorControl"
let GAMMA_CONTROL_IDENTIFIER = #"ca.michelf.GammaControl.\d+"#
let BLACK_LIGHT_IDENTIFIER = #"ca.michelf.BlackLight.\d+"#
let LUNAR_LITE_IDENTIFIER = "fyi.lunar.LunarLite"
let MC_LITE_IDENTIFIER = "app.monitorcontrol.MonitorControlLite"
let BETTERDISPLAY_IDENTIFIER = "pro.betterdisplay.BetterDisplay"
let GAMMA_APPS_PATTERN =
    try! Regex(
        pattern: #"^(?:\#(GAMMA_CONTROL_IDENTIFIER)|\#(BLACK_LIGHT_IDENTIFIER)|\#(FLUX_IDENTIFIER)|\#(LUNAR_IDENTIFIER)|\#(MC_IDENTIFIER)|\#(GAMMA_CONTROL_IDENTIFIER)|\#(LUNAR_LITE_IDENTIFIER)|\#(MC_LITE_IDENTIFIER)|\#(BETTERDISPLAY_IDENTIFIER))$"#
    )

func runningGammaApp(_ apps: [NSRunningApplication]? = nil) -> NSRunningApplication? {
    (apps ?? NSWorkspace.shared.runningApplications).first { app in
        GAMMA_APPS_PATTERN.matches(app.bundleIdentifier ?? "")
    }
}
