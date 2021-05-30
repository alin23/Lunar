import Accelerate
import Alamofire
import Cocoa
import CryptorECC
import Foundation
import Surge
import SwiftDate

class RequestTimeoutError: Error {}
struct ResponseError: Error {
    var statusCode: Int
}

func query(url: URL, timeout: TimeInterval = 0.seconds.timeInterval, wait: Bool = true) throws -> String {
    let semaphore = DispatchSemaphore(value: 0)

    var result: String = ""
    var responseError: Error?

    let task = URLSession.shared.dataTask(with: url) { data, resp, error in
        guard let data = data else {
            responseError = error
            semaphore.signal()
            return
        }
        guard let response = resp as? HTTPURLResponse, (200 ..< 300).contains(response.statusCode) else {
            responseError = ResponseError(statusCode: (resp as? HTTPURLResponse)?.statusCode ?? 400)
            semaphore.signal()
            return
        }
        result = String(data: data, encoding: String.Encoding.utf8)!
        semaphore.signal()
    }

    task.resume()
    guard wait else { return "" }

    switch semaphore.wait(timeout: DispatchTime.now() + timeout) {
    case .timedOut:
        throw RequestTimeoutError()
    case .success:
        if let error = responseError {
            throw error
        }
        return result
    }
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
    for tryNum in 0 ... retries {
        do {
            let resp = try query(url: url, timeout: timeoutPerTry.timeInterval)
            return resp
        } catch {
            log.debug("Could not reach URL '\(url)': \(error)", context: ["try": tryNum])
        }
        if sleepBetweenTries > 0 {
            Thread.sleep(forTimeInterval: sleepBetweenTries)
            sleepBetweenTries = min(sleepBetweenTries * backoff, maxSleepBetweenTries)
        }
    }

    return nil
}

func buildAlamofireSession(requestTimeout: DateComponents = 30.seconds, resourceTimeout: DateComponents = 60.seconds) -> Alamofire.Session {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = requestTimeout.timeInterval
    configuration.timeoutIntervalForResource = resourceTimeout.timeInterval
    return Alamofire.Session(configuration: configuration)
}

extension String {
    subscript(index: Int) -> Character {
        self[self.index(startIndex, offsetBy: index)]
    }
}

public extension String {
    func levenshtein(_ other: String) -> Int {
        let sCount = count
        let oCount = other.count

        guard sCount != 0 else {
            return oCount
        }

        guard oCount != 0 else {
            return sCount
        }

        let line: [Int] = Array(repeating: 0, count: oCount + 1)
        var mat: [[Int]] = Array(repeating: line, count: sCount + 1)

        for i in 0 ... sCount {
            mat[i][0] = i
        }

        for j in 0 ... oCount {
            mat[0][j] = j
        }

        for j in 1 ... oCount {
            for i in 1 ... sCount {
                if self[i - 1] == other[j - 1] {
                    mat[i][j] = mat[i - 1][j - 1] // no operation
                } else {
                    let del = mat[i - 1][j] + 1 // deletion
                    let ins = mat[i][j - 1] + 1 // insertion
                    let sub = mat[i - 1][j - 1] + 1 // substitution
                    mat[i][j] = min(min(del, ins), sub)
                }
            }
        }

        return mat[sCount][oCount]
    }
}

let publicKey =
    """
    -----BEGIN PUBLIC KEY-----
    MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEKGs3ARma5DHHnBb/vvTQmRV6sS3Y
    KtuJCVywyiA6TqoFEuQWDVmVwScqPbm5zmdRIUK31iZvxGjFjggMutstEA==
    -----END PUBLIC KEY-----
    """

func appDelegate() -> AppDelegate {
    NSApplication.shared.delegate as! AppDelegate
}

func refreshScreen(refocus: Bool = true) {
    mainThread {
        let focusedApp = NSWorkspace.shared.runningApplications.first(where: { app in app.isActive })
        if refocus {
            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
        }

        if let w = appDelegate().windowController?.window?.contentViewController?.view {
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
    screen: NSScreen? = nil
) {
    mainThread {
        guard let mainStoryboard = NSStoryboard.main else { return }

        if controller == nil {
            controller = mainStoryboard
                .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(identifier)) as? ModernWindowController
        }

        if show, let wc = controller {
            wc.initPopovers()

            if let screen = screen, let w = wc.window {
                let size = w.frame.size
                w.setFrameOrigin(CGPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.midY - size.height / 2))
            }

            wc.showWindow(nil)

            if let window = wc.window as? ModernWindow {
                log.debug("Showing window '\(window.title)'")
                window.orderFrontRegardless()
            }
            if focus {
                NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }
}

func encrypt(message: Data, key: String? = nil) -> Data? {
    do {
        let eccPublicKey = try ECPublicKey(key: key ?? publicKey)
        let encrypted = try message.encrypt(with: eccPublicKey)

        return encrypted
    } catch {
        log.error("Error when encrypting message: \(error)")
        return nil
    }
}

func sha256(data: Data) -> Data {
    var hash = [UInt8](repeating: 0, count: CC_SHA256_DIGEST_LENGTH.i)
    data.withUnsafeBytes {
        _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
    }
    return Data(hash)
}

func sha512(data: Data) -> Data {
    var hash = [UInt8](repeating: 0, count: CC_SHA512_DIGEST_LENGTH.i)
    data.withUnsafeBytes {
        _ = CC_SHA512($0.baseAddress, CC_LONG(data.count), &hash)
    }
    return Data(hash)
}

func shortHash(string: String, length: Int = 8) -> String {
    guard let data = string.data(using: .utf8, allowLossyConversion: true) else { return string }
    return String(sha256(data: data).str(hex: true, separator: "").prefix(length))
}

func getSerialNumberHash() -> String? {
    let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))

    guard platformExpert > 0 else {
        return nil
    }

    if let serialNumberProp = IORegistryEntryCreateCFProperty(
        platformExpert,
        kIOPlatformSerialNumberKey as CFString,
        kCFAllocatorDefault,
        0
    ) {
        guard let serialNumber = (serialNumberProp.takeRetainedValue() as? String)?
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        else {
            serialNumberProp.release()
            return nil
        }

        IOObjectRelease(platformExpert)
        guard let serialNumberData = serialNumber.data(using: .utf8, allowLossyConversion: true) else {
            return nil
        }
        let hash = sha256(data: serialNumberData).prefix(20).str(base64: true, separator: "").map { (c: Character) -> Character in
            switch c {
            case "/": return Character(".")
            case "+": return Character(".")
            default: return c
            }
        }.str()
        log.info(hash)
        return hash
    }
    return nil
}

func mainThread(_ action: () -> Void) {
    if Thread.isMainThread {
        action()
    } else {
        DispatchQueue.main.sync {
            action()
        }
    }
}

func mainThread<T>(_ action: () -> T) -> T {
    if Thread.isMainThread {
        return action()
    } else {
        return DispatchQueue.main.sync {
            return action()
        }
    }
}

func serialAsyncAfter(ms: Int, _ action: @escaping () -> Void) {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    serialQueue.asyncAfter(deadline: deadline) {
        action()
    }
}

func serialAsyncAfter(ms: Int, _ action: DispatchWorkItem) {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    serialQueue.asyncAfter(deadline: deadline, execute: action)
}

var asyncUniqueTasksSemaphore = DispatchSemaphore(value: 1)
var asyncUniqueTasks = [String: DispatchWorkItem]()

var asyncUniqueRecurringTasksSemaphore = DispatchSemaphore(value: 1)
var asyncUniqueRecurringTasks = [String: Timer]()

@discardableResult func asyncAfter(ms: Int, uniqueTaskKey: String? = nil, _ action: @escaping () -> Void) -> DispatchWorkItem {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    let task: DispatchWorkItem
    if let key = uniqueTaskKey {
        task = DispatchWorkItem {
            action()
            asyncUniqueTasksSemaphore.wait()
            asyncUniqueTasks[key] = nil
            asyncUniqueTasksSemaphore.signal()
        }

        asyncUniqueTasksSemaphore.wait()
        asyncUniqueTasks[key]?.cancel()
        asyncUniqueTasks[key] = task
        asyncUniqueTasksSemaphore.signal()
    } else {
        task = DispatchWorkItem {
            action()
        }
    }

    concurrentQueue.asyncAfter(deadline: deadline, execute: task)

    return task
}

@discardableResult func asyncEvery(_ interval: DateComponents, uniqueTaskKey: String? = nil, _ action: @escaping () -> Void) -> Timer {
    let timer = concurrentQueue.sync {
        Timer.scheduledTimer(withTimeInterval: interval.timeInterval, repeats: true) { _ in
            action()
        }
    }

    if let key = uniqueTaskKey {
        asyncUniqueRecurringTasksSemaphore.wait()
        asyncUniqueRecurringTasks[key]?.invalidate()
        asyncUniqueRecurringTasks[key] = timer
        asyncUniqueRecurringTasksSemaphore.signal()
    }

    return timer
}

func cancelAsyncTask(_ key: String) {
    if asyncUniqueTasks[key] == nil { return }
    asyncUniqueTasksSemaphore.wait()
    asyncUniqueTasks[key]?.cancel()
    asyncUniqueTasks.removeValue(forKey: key)
    asyncUniqueTasksSemaphore.signal()
}

func cancelAsyncRecurringTask(_ key: String) {
    asyncUniqueRecurringTasksSemaphore.wait()
    asyncUniqueRecurringTasks[key]?.invalidate()
    asyncUniqueRecurringTasks.removeValue(forKey: key)
    asyncUniqueRecurringTasksSemaphore.signal()
}

@discardableResult func async(
    timeout: DateComponents? = nil,
    queue: DispatchQueue? = nil,
    runLoopQueue: RunloopQueue? = nil,
    threaded: Bool = false,
    _ action: @escaping () -> Void
) -> DispatchTimeoutResult {
    if threaded {
        guard let timeout = timeout else {
            let thread = Thread { action() }
            thread.start()
            return .success
        }

        let semaphore = DispatchSemaphore(value: 0)

        let thread = Thread {
            action()
            semaphore.signal()
        }
        thread.start()

        let result = semaphore.wait(timeout: DispatchTime.now() + timeout.timeInterval)
        if result == .timedOut {
            thread.cancel()
        }

        return result
    }

    if let queue = runLoopQueue {
        guard let timeout = timeout else {
            queue.async { action() }
            return .success
        }

        let semaphore = DispatchSemaphore(value: 0)

        queue.async {
            action()
            semaphore.signal()
        }

        let result = semaphore.wait(timeout: DispatchTime.now() + timeout.timeInterval)

        return result
    }

    let queue = queue ?? concurrentQueue
    guard let timeout = timeout else {
        queue.async { action() }
        return .success
    }

    let task = DispatchWorkItem {
        action()
    }
    queue.async(execute: task)

    let result = task.wait(timeout: DispatchTime.now() + timeout.timeInterval)
    if result == .timedOut {
        task.cancel()
    }

    return result
}

func asyncEvery(_ interval: DateComponents, queue: RunloopQueue, _ action: @escaping (CFRunLoopTimer?) -> Void) -> CFRunLoopTimer? {
    queue.async(every: interval, action)
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

    if let qos = qos {
        thread.qualityOfService = qos
    }

    thread.start()
    return thread
}

func asyncAfter(ms: Int, _ action: DispatchWorkItem) {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    concurrentQueue.asyncAfter(deadline: deadline, execute: action)
}

func mainAsyncAfter(ms: Int, _ action: @escaping () -> Void) {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    DispatchQueue.main.asyncAfter(deadline: deadline) {
        action()
    }
}

func mainAsyncAfter(ms: Int, _ action: DispatchWorkItem) {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    DispatchQueue.main.asyncAfter(deadline: deadline, execute: action)
}

func getScreenWithMouse() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    let screens = NSScreen.screens
    let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })

    return screenWithMouse
}

func mapNumber<T: Numeric & Comparable & FloatingPoint>(_ number: T, fromLow: T, fromHigh: T, toLow: T, toHigh: T) -> T {
    if fromLow == fromHigh {
        log.warning("fromLow and fromHigh are both equal to \(fromLow)")
        return number
    }

    if number >= fromHigh {
        return toHigh
    } else if number <= fromLow {
        return toLow
    } else if toLow < toHigh {
        let diff = toHigh - toLow
        let fromDiff = fromHigh - fromLow
        return (number - fromLow) * diff / fromDiff + toLow
    } else {
        let diff = toHigh - toLow
        let fromDiff = fromHigh - fromLow
        return (number - fromLow) * diff / fromDiff + toLow
    }
}

func mapNumberSIMD(_ number: [Double], fromLow: Double, fromHigh: Double, toLow: Double, toHigh: Double) -> [Double] {
    if fromLow == fromHigh {
        log.warning("fromLow and fromHigh are both equal to \(fromLow)")
        return number
    }

    let resultLow = number.firstIndex(where: { $0 > fromLow }) ?? 0
    let resultHigh = number.lastIndex(where: { $0 < fromHigh }) ?? (number.count - 1)

    if resultLow >= resultHigh {
        var result = [Double](repeating: toLow, count: number.count)
        if resultHigh != (number.count - 1) {
            result.replaceSubrange((resultHigh + 1) ..< number.count, with: repeatElement(toHigh, count: number.count - resultHigh))
        }
        return result
    }

    let numbers = Array(number[resultLow ... resultHigh])

    var value: [Double]
    if toLow == 0.0, fromLow == 0.0, toHigh == 1.0 {
        value = numbers / fromHigh
    } else {
        let diff = toHigh - toLow
        let fromDiff = fromHigh - fromLow
        value = numbers - fromLow
        value = value * diff
        value = value / fromDiff
        value = value + toLow
    }

    var result = [Double](repeating: toLow, count: number.count)
    result.replaceSubrange(resultLow ... resultHigh, with: value)
    if resultHigh != (number.count - 1) {
        result.replaceSubrange((resultHigh + 1) ..< number.count, with: repeatElement(toHigh, count: number.count - (resultHigh + 1)))
    }
    return result
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

struct Zip3Sequence<E1, E2, E3>: Sequence, IteratorProtocol {
    private let _next: () -> (E1, E2, E3)?

    init<S1: Sequence, S2: Sequence, S3: Sequence>(_ s1: S1, _ s2: S2, _ s3: S3) where S1.Element == E1, S2.Element == E2,
        S3.Element == E3
    {
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
}

func zip3<S1: Sequence, S2: Sequence, S3: Sequence>(_ s1: S1, _ s2: S2, _ s3: S3) -> Zip3Sequence<S1.Element, S2.Element, S3.Element> {
    Zip3Sequence(s1, s2, s3)
}

struct Zip4Sequence<E1, E2, E3, E4>: Sequence, IteratorProtocol {
    private let _next: () -> (E1, E2, E3, E4)?

    init<S1: Sequence, S2: Sequence, S3: Sequence, S4: Sequence>(_ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4) where S1.Element == E1,
        S2.Element == E2, S3.Element == E3, S4.Element == E4
    {
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
}

func zip4<S1: Sequence, S2: Sequence, S3: Sequence, S4: Sequence>(
    _ s1: S1,
    _ s2: S2,
    _ s3: S3,
    _ s4: S4
) -> Zip4Sequence<S1.Element, S2.Element, S3.Element, S4.Element> {
    Zip4Sequence(s1, s2, s3, s4)
}

var gammaWindowController: NSWindowController?
var faceLightWindowController: NSWindowController?

func createWindow(
    _ identifier: String,
    controller: inout NSWindowController?,
    screen: NSScreen? = nil,
    show: Bool = true,
    backgroundColor: NSColor? = .clear,
    level: NSWindow.Level = .normal,
    fillScreen: Bool = false
) {
    mainThread {
        guard let mainStoryboard = NSStoryboard.main else { return }

        if controller == nil {
            controller = mainStoryboard
                .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(identifier)) as? NSWindowController
        }

        if let wc = controller {
            if let screen = screen, let w = wc.window {
                w.setFrameOrigin(CGPoint(x: screen.frame.minX, y: screen.frame.minY))
                if fillScreen {
                    w.setFrame(screen.frame, display: false)
                }
            }

            if let window = wc.window {
                window.level = level
                window.isOpaque = false
                window.backgroundColor = backgroundColor
                if show {
                    log.debug("Showing window '\(window.title)'")
                    wc.showWindow(nil)
                    window.orderFrontRegardless()
                }
            }
        }
    }
}

func showOperationInProgress(screen: NSScreen? = nil) {
    let c = mainThread { () -> GammaViewController? in
        createWindow(
            "gammaWindowController",
            controller: &gammaWindowController,
            screen: screen,
            show: true,
            backgroundColor: .clear,
            level: .popUpMenu
        )

        guard let w = gammaWindowController?.window, let c = w.contentViewController as? GammaViewController else { return nil }
        w.ignoresMouseEvents = true
        return c
    }
    if let c = c {
        c.highlight()
    }
}

func hideOperationInProgress() {
    let c = mainThread { () -> GammaViewController? in
        guard let c = gammaWindowController?.window?.contentViewController as? GammaViewController else { return nil }
        return c
    }
    if let c = c {
        c.stopHighlighting()
    }
}

// MARK: Dialogs

var alertsByMessageSemaphore = DispatchSemaphore(value: 1)
var alertsByMessage = [String: Bool]()

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
    ultrawide: Bool = false
) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = info
    alert.alertStyle = .warning

    if ultrawide {
        alert.accessoryView = NSView(frame: NSRect(origin: .zero, size: NSSize(width: 500, height: 0)))
    } else if wide {
        alert.accessoryView = NSView(frame: NSRect(origin: .zero, size: NSSize(width: 650, height: 0)))
    }

    if let okButton = okButton {
        alert.addButton(withTitle: okButton)
    }
    if let cancelButton = cancelButton {
        alert.addButton(withTitle: cancelButton)
    }
    if let thirdButton = thirdButton {
        alert.addButton(withTitle: thirdButton)
    }

    if let suppressionText = suppressionText {
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = suppressionText
    }

    if let screen = screen {
        let w = window ?? alert.window

        let alertSize = w.frame.size
        w.setFrameOrigin(CGPoint(x: screen.visibleFrame.midX - alertSize.width / 2, y: screen.visibleFrame.midY - alertSize.height / 2))
        w.makeKeyAndOrderFront(nil)
        if window != nil {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    return alert
}

func ask(
    message: String,
    info: String,
    okButton: String = "OK",
    cancelButton: String = "Cancel",
    thirdButton: String? = nil,
    screen: NSScreen? = nil,
    window: NSWindow? = nil,
    suppressionText: String? = nil,
    onSuppression: ((Bool) -> Void)? = nil,
    onCompletion: ((Bool) -> Void)? = nil,
    unique: Bool = false,
    waitTimeout: DateComponents = 5.seconds,
    wide: Bool = false,
    ultrawide: Bool = false
) -> Bool {
    ask(
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
        ultrawide: ultrawide
    ) == .alertFirstButtonReturn
}

func ask(
    message: String,
    info: String,
    okButton: String = "OK",
    cancelButton: String = "Cancel",
    thirdButton: String? = nil,
    screen: NSScreen? = nil,
    window: NSWindow? = nil,
    suppressionText: String? = nil,
    onSuppression: ((Bool) -> Void)? = nil,
    onCompletion: ((NSApplication.ModalResponse) -> Void)? = nil,
    unique: Bool = false,
    waitTimeout: DateComponents = 5.seconds,
    wide: Bool = false,
    ultrawide: Bool = false
) -> NSApplication.ModalResponse {
    if unique {
        switch alertsByMessageSemaphore.wait(timeout: DispatchTime.now() + waitTimeout.timeInterval) {
        case .success:
            if alertsByMessage[message] != nil {
                return .cancel
            }
            alertsByMessage[message] = true
        case .timedOut:
            log.warning("Timeout in waiting for alertsForMessage")
            return .cancel
        }
        alertsByMessageSemaphore.signal()
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
            ultrawide: ultrawide
        )

        if let window = window {
            alert.beginSheetModal(for: window, completionHandler: { resp in
                onCompletion?(resp)
                onSuppression?((alert.suppressionButton?.state ?? .off) == .on)

                if unique {
                    switch alertsByMessageSemaphore.wait(timeout: DispatchTime.now() + 5) {
                    case .success:
                        alertsByMessage.removeValue(forKey: message)
                    case .timedOut:
                        log.warning("Timeout in waiting for alertsForMessage")
                    }
                    alertsByMessageSemaphore.signal()
                }
            })
            return .cancel
        }

        let resp = alert.runModal()

        if let onSuppression = onSuppression {
            onSuppression((alert.suppressionButton?.state ?? .off) == .on)
        }

        if unique {
            switch alertsByMessageSemaphore.wait(timeout: DispatchTime.now() + 5) {
            case .success:
                alertsByMessage.removeValue(forKey: message)
            case .timedOut:
                log.warning("Timeout in waiting for alertsForMessage")
            }
            alertsByMessageSemaphore.signal()
        }
        return resp
    }
    return response
}

// MARK: Property Wrappers

func localNow() -> DateInRegion {
    DateInRegion().convertTo(region: .local)
}

func monospace(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    NSFont.monospacedSystemFont(ofSize: size, weight: weight)
}

func displayInfoDictionary(_ id: CGDirectDisplayID) -> NSDictionary? {
    let unmanagedDict = CoreDisplay_DisplayCreateInfoDictionary(id)
    let retainedDict = unmanagedDict?.takeRetainedValue()
    guard let dict = retainedDict as NSDictionary? else {
        return nil
    }

    return dict
}

class PlainTextPasteView: NSTextView, NSTextViewDelegate {
    override func paste(_ sender: Any?) {
        super.pasteAsPlainText(sender)
    }
}

class PlainTextFieldCell: NSTextFieldCell {
    static var plainTextView: PlainTextPasteView?

    override func fieldEditor(for _: NSView) -> NSTextView? {
        if Self.plainTextView == nil {
            Self.plainTextView = PlainTextPasteView()
        }
        return Self.plainTextView
    }
}

func cap<T: Comparable>(_ number: T, minVal: T, maxVal: T) -> T {
    max(min(number, maxVal), minVal)
}
