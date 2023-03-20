import Darwin
import Foundation

// http://www.gnu.org/software/libc/manual/html_node/Defining-Handlers.html#Defining-Handlers

// OS Signals
enum Signal {
    case hangup
    case interrupt
    case illegal
    case trap
    case abort
    case alarm
    case termination

    /// All posible signals.
    static let all = [
        hangup,
        interrupt,
        illegal,
        trap,
        abort,
        alarm,
        termination,
    ]

    /// Return the OS values
    var osValue: Int32 {
        switch self {
        case .hangup:
            return SIGHUP
        case .interrupt:
            return SIGINT
        case .illegal:
            return SIGILL
        case .trap:
            return SIGTRAP
        case .abort:
            return SIGABRT
        case .alarm:
            return SIGALRM
        case .termination:
            return SIGTERM
        }
    }
}

/// Handle OS Signals
enum Trap {
    typealias SignalHandler = @convention(c) (Int32) -> Void

}

extension Trap {
    /**
     Establishes the signal handler.

     - parameter signal: The signal to handle.
     - parameter action: Code to execute when the signal is fired.

     - SeeAlso: [Advanced Signal Handling](http://www.gnu.org/software/libc/manual/html_node/Advanced-Signal-Handling.html#Advanced-Signal-Handling)
     */
    static func handle(signal: Signal, action: SignalHandler) {
        typealias SignalAction = sigaction

        // Instead of using just `signal` we can use the more powerful `sigaction`
        var signalAction = SignalAction(__sigaction_u: unsafeBitCast(action, to: __sigaction_u.self), sa_mask: 0, sa_flags: 0)
        withUnsafePointer(to: &signalAction) { actionPointer in
            sigaction(signal.osValue, actionPointer, nil)
        }
    }

    /**
     Establishes multiple `signals` to be handled by the `action`

     - parameter signals: The multiple signal to handle.
     - parameter action:  Code to execute when any of the signals is fired.
     */
    static func handle(signals: [Signal], action: SignalHandler) {
        signals.forEach {
            handle(signal: $0, action: action)
        }
    }
}
