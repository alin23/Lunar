import Cocoa
import Combine
import Defaults
import Sentry
import SimplyCoreAudio

private let APP_HANG_DETECTION_INTERVAL: TimeInterval = 40.0
private let APP_HANG_CHECK_INTERVAL: TimeInterval = 1.0

private final class RepeatingHang {
    init(cause: String, expectedStackFrame: String) {
        self.cause = cause
        self.expectedStackFrame = expectedStackFrame
    }

    let cause: String
    let expectedStackFrame: String

    lazy var exceedsThreshold: Bool = {
        let exceeds = appHangStateQueue.sync {
            if count >= RepeatingHangState.threshold {
                log.warning("Detected repeating hangs due to \(cause) (\(count) in last \(RepeatingHangState.window) seconds)")
                return true
            }
            return false
        }

        if exceeds {
            clearTimestamps()
        }
        return exceeds
    }()

    lazy var count: Int = RepeatingHangState.count(cause: cause, now: Date().timeIntervalSince1970)

    func isCulprit(mainThreadStack: String) -> Bool {
        guard mainThreadStack.contains(expectedStackFrame) else {
            return false
        }
        log.warning("Hang detected with expected stack frame '\(expectedStackFrame)' in main thread sample")
        return true
    }

    func clearTimestamps() {
        appHangStateQueue.sync {
            var all = RepeatingHangState.loadTimestamps()
            all[cause] = []
            RepeatingHangState.saveTimestamps(all)
        }
    }

}

private enum RepeatingHangState {
    static let window: TimeInterval = 5 * 60
    static let threshold = 3
    static let fileName = "lunar_hang_causes.json"
    static let defaultAudioOutput = RepeatingHang(cause: "audio-device", expectedStackFrame: "Audio")
    static let coreLocation = RepeatingHang(cause: "core-location", expectedStackFrame: "CLConnectionServer")
    static let hangs: [String: RepeatingHang] = [
        "audio-device": defaultAudioOutput,
        "core-location": coreLocation,
    ]

    static func fileURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    static func loadTimestamps() -> [String: [TimeInterval]] {
        let url = fileURL()
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [TimeInterval]].self, from: data)) ?? [:]
    }

    static func saveTimestamps(_ timestamps: [String: [TimeInterval]]) {
        let url = fileURL()
        guard let data = try? JSONEncoder().encode(timestamps) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func record(cause: String, at timestamp: TimeInterval) {
        var all = loadTimestamps()
        var timestamps = all[cause, default: []]
        timestamps.append(timestamp)
        timestamps.removeAll { timestamp - $0 > window }
        all[cause] = timestamps
        saveTimestamps(all)
    }

    static func count(cause: String, now: TimeInterval) -> Int {
        let all = loadTimestamps()
        let timestamps = all[cause, default: []]
        return timestamps.filter { now - $0 <= window }.count
    }
}

private let appHangStateQueue = DispatchQueue(label: "fyi.lunar.appHangDetection.state")
@MainActor private var appHangTimer: DispatchSourceTimer?
private var lastMainThreadCheckin: TimeInterval = 0
private var appHangTriggered = false
private var sleeping = false

@MainActor var enableSentryObserver: Cancellable?

@MainActor func configureSentry() {
    enableSentryObserver = enableSentryObserver ?? enableSentryPublisher
        .debounce(for: .seconds(1), scheduler: RunLoop.main)
        .sink { change in
            AppDelegate.enableSentry = change.newValue
            if change.newValue {
                configureSentry()
            } else {
                SentrySDK.close()
            }
        }
    guard AppDelegate.enableSentry else { return }
    UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])

    let release = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    SentrySDK.start { options in
        options.enableCaptureFailedRequests = false
        options.dsn = SENTRY_DSN
        options.releaseName = "v\(release)"
        options.dist = release
        #if DEBUG
            options.environment = "dev"
            options.appHangTimeoutInterval = 10
        #else
            options.environment = "production"
            options.appHangTimeoutInterval = APP_HANG_DETECTION_INTERVAL
        #endif
        options.enableNetworkTracking = false
    }

    let user = User(userId: SERIAL_NUMBER_HASH)

    if CachedDefaults[.paddleConsent] {
        user.email = producct?.activationEmail
    }

    user.username = producct?.activationID
    SentrySDK.configureScope { scope in
        scope.setUser(user)
        scope.setTag(value: DC.adaptiveModeString(), key: "adaptiveMode")
        scope.setTag(value: DC.adaptiveModeString(last: true), key: "lastAdaptiveMode")
        scope.setTag(value: CachedDefaults[.overrideAdaptiveMode] ? "false" : "true", key: "autoMode")
    }
}

@MainActor func configureAppHangDetection() {
    guard appHangTimer == nil else {
        return
    }

    if RepeatingHangState.coreLocation.exceedsThreshold {
        log.warning("Disabling CoreLocation usage due to repeated hangs.")
        Defaults[.manualLocation] = true
    }

    appHangStateQueue.sync {
        lastMainThreadCheckin = Date().timeIntervalSince1970
        appHangTriggered = false
    }

    let timer = DispatchSource.makeTimerSource(queue: concurrentQueue)
    timer.schedule(
        deadline: .now() + APP_HANG_CHECK_INTERVAL,
        repeating: APP_HANG_CHECK_INTERVAL,
        leeway: .milliseconds(250)
    )
    timer.setEventHandler {
        let now = Date().timeIntervalSince1970
        var shouldTrigger = false

        appHangStateQueue.sync {
            if !appHangTriggered, !sleeping, now - lastMainThreadCheckin > APP_HANG_DETECTION_INTERVAL {
                appHangTriggered = true
                shouldTrigger = true
            }
        }

        if shouldTrigger {
            onAppHangDetected()
        }

        DispatchQueue.main.async {
            appHangStateQueue.async {
                lastMainThreadCheckin = Date().timeIntervalSince1970
            }
        }
    }
    appHangTimer = timer
    timer.resume()

    let nc = NSWorkspace.shared.notificationCenter
    nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in
        appHangStateQueue.sync {
            lastMainThreadCheckin = Date().timeIntervalSince1970
            sleeping = true
            appHangTriggered = false
        }
    }
    nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { _ in
        let now = Date().timeIntervalSince1970
        appHangStateQueue.sync {
            lastMainThreadCheckin = now
            sleeping = false
            appHangTriggered = false
        }
    }
}

private func sampleMainThread() -> String? {
    let result = shell("/usr/bin/sample", args: ["\(getpid())", "0.001"], timeout: 5.seconds)
    guard let output = result.o, result.success else { return nil }

    var mainThreadLines: [String] = []
    var inMainThread = false

    for line in output.components(separatedBy: "\n") {
        if line.contains("com.apple.main-thread") {
            inMainThread = true
            mainThreadLines.append(line)
            continue
        }

        guard inMainThread else { continue }

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || line.contains("Thread_") || trimmed.hasPrefix("Total number") || trimmed.hasPrefix("Sort by") {
            break
        }
        mainThreadLines.append(line)
    }

    return mainThreadLines.isEmpty ? nil : mainThreadLines.joined(separator: "\n")
}

func onAppHangDetected() {
    log.warning("App Hanging!")

    let mainThreadStack = sampleMainThread()
    if let mainThreadStack {
        log.warning("Main thread sample:\n\(mainThreadStack)")
    } else {
        log.warning("Failed to sample main thread")
    }

    if Defaults[.autoRestartOnHang] {
        let now = Date().timeIntervalSince1970
        if let mainThreadStack {
            appHangStateQueue.async {
                if let hang = RepeatingHangState.hangs.values.first(where: { $0.isCulprit(mainThreadStack: mainThreadStack) }) {
                    RepeatingHangState.record(cause: hang.cause, at: now)
                }
            }
        }
        log.warning("Auto-restarting app due to hang detection.")
        concurrentQueue.asyncAfter(ms: 5000) { restart(hang: true) }
    }
}

var defaultAudioOutputDevice: AudioDevice? {
    if RepeatingHangState.defaultAudioOutput.exceedsThreshold {
        return nil
    }

    return simplyCA?.defaultOutputDevice
}
