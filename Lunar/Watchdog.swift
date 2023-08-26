let LUNAR_PID_FILE = "/tmp/lunar.pid"
let LUNAR_RESTART_LOG = "/tmp/lunar-restart.log"
var WATCHDOG: Process?

func writePID() {
    fm.createFile(
        atPath: LUNAR_PID_FILE,
        contents: "\(ProcessInfo.processInfo.processIdentifier)".data(using: .utf8)
    )
}

func deletePID() {
    WATCHDOG?.terminate()
    try? fm.removeItem(atPath: LUNAR_PID_FILE)
}

func restartedTooOften() -> Bool {
    guard let restartLog = fm.contents(atPath: LUNAR_RESTART_LOG)?.s else {
        return false
    }
    let lines = restartLog.trimmed.split(separator: "\n")
    guard lines.count > 1, let threeRestartsAgo = Int(lines[back: 1]) else {
        return false
    }

    return (Date().timeIntervalSince1970.intround - threeRestartsAgo) < 180
}

func watchdog() {
    writePID()
    _ = shell(command: "/usr/bin/pkill -f -l LUNAR_FYI_WATCHDOG", wait: false)
    guard !restartedTooOften() else {
        try? fm.removeItem(atPath: LUNAR_RESTART_LOG)
        return
    }

    mainAsyncAfter(ms: 5000) {
        WATCHDOG = shellProc(
            args: [
                "-c",
                "/bin/echo LUNAR_FYI_WATCHDOG; while /bin/ps -o pid -p \(ProcessInfo.processInfo.processIdentifier) >/dev/null 2>/dev/null; do /bin/sleep 5; done; /bin/sleep 3; test -f \(LUNAR_PID_FILE) && /usr/bin/open '\(Bundle.main.path.string)' && date -u +%s >> \(LUNAR_RESTART_LOG)",
            ],
            devnull: true
        )
    }
}
