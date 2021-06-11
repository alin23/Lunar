//
//  RunloopQueue.swift
//  RunloopQueue
//
//  Created by Daniel Kennett on 2017-02-14.
//  For license information, see LICENSE.md.
//

import Foundation

/// RunloopQueue is a serial queue based on CFRunLoop, running on the background thread.
@objc(CBLRunloopQueue)
public class RunloopQueue: NSObject {
    // MARK: - Code That Runs On The Main/Creating Thread

    private let thread: RunloopQueueThread

    /// Init a new queue with the given name.
    ///
    /// - Parameter name: The name of the queue.
    @objc(initWithName:) public init(named name: String?) {
        thread = RunloopQueueThread()
        thread.name = name
        super.init()
        startRunloop()
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        let runloop = self.runloop
        sync { CFRunLoopStop(runloop) }
    }

    /// Returns `true` if the queue is running, otherwise `false`. Once stopped, a queue cannot be restarted.
    @objc public var running: Bool { true }

    /// Execute a block of code in an asynchronous manner. Will return immediately.
    ///
    /// - Parameter block: The block of code to execute.
    @objc public func async(_ block: @escaping (() -> Void)) {
        CFRunLoopPerformBlock(runloop, CFRunLoopMode.defaultMode.rawValue, block)
        thread.awake()
    }

    /// Execute a block of code in an asynchronous manner periodically. Will return immediately.
    ///
    /// - Parameter block: The block of code to execute.
    @objc public func async(every interval: DateComponents, _ block: @escaping ((CFRunLoopTimer?) -> Void)) -> CFRunLoopTimer? {
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent(), interval.timeInterval, 0, 0, block)
        CFRunLoopAddTimer(runloop, timer, CFRunLoopMode.defaultMode)
        thread.awake()
        return timer
    }

    @objc public func cancel(timer: CFRunLoopTimer) {
        CFRunLoopRemoveTimer(runloop, timer, CFRunLoopMode.defaultMode)
    }

    @objc public func isValid(timer: CFRunLoopTimer) -> Bool {
        CFRunLoopContainsTimer(runloop, timer, CFRunLoopMode.defaultMode)
    }

    /// Execute a block of code in a synchronous manner. Will return when the code has executed.
    ///
    /// It's important to be careful with `sync()` to avoid deadlocks. In particular, calling `sync()` from inside
    /// a block previously passed to `sync()` will deadlock if the second call is made from a different thread.
    ///
    /// - Parameter block: The block of code to execute.
    @objc public func sync(_ block: @escaping (() -> Void)) {
        if isRunningOnQueue() {
            block()
            return
        }

        let conditionLock = NSConditionLock(condition: 0)

        CFRunLoopPerformBlock(runloop, CFRunLoopMode.defaultMode.rawValue) {
            conditionLock.lock()
            block()
            conditionLock.unlock(withCondition: 1)
        }

        thread.awake()
        conditionLock.lock(whenCondition: 1)
        conditionLock.unlock()
    }

    /// Query if the caller is running on this queue.
    ///
    /// - Returns: `true` if the caller is running on this queue, otherwise `false`.
    @objc public func isRunningOnQueue() -> Bool {
        CFEqual(CFRunLoopGetCurrent(), runloop)
    }

    // MARK: - Code That Runs On The Background Thread

    var runloop: CFRunLoop!
    private func startRunloop() {
        let conditionLock = NSConditionLock(condition: 0)

        thread.start {
            [weak self] runloop in
            // This is on the background thread.

            conditionLock.lock()
            defer { conditionLock.unlock(withCondition: 1) }

            guard let self = self else { return }
            self.runloop = runloop
        }

        conditionLock.lock(whenCondition: 1)
        conditionLock.unlock()
    }
}

private class RunloopQueueThread: Thread {
    // Required to keep the runloop running when nothing is going on.
    private let runloopSource: CFRunLoopSource
    private var currentRunloop: CFRunLoop?

    override init() {
        var sourceContext = CFRunLoopSourceContext()
        runloopSource = CFRunLoopSourceCreate(nil, 0, &sourceContext)
    }

    /// The callback to be called once the runloop has started executing. Will be called on the runloop's own thread.
    var whenReadyCallback: ((CFRunLoop) -> Void)?

    func start(whenReady call: @escaping ((CFRunLoop) -> Void)) {
        whenReadyCallback = call
        start()
    }

    func awake() {
        guard let runloop = currentRunloop else { return }
        if CFRunLoopIsWaiting(runloop) {
            CFRunLoopSourceSignal(runloopSource)
            CFRunLoopWakeUp(runloop)
        }
    }

    override func main() {
        let strongSelf = self
        let runloop = CFRunLoopGetCurrent()!
        currentRunloop = runloop

        CFRunLoopAddSource(runloop, runloopSource, CFRunLoopMode.commonModes)

        let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.entry.rawValue, false, 0) {
            _, _ in
            strongSelf.whenReadyCallback?(runloop)
        }

        CFRunLoopAddObserver(runloop, observer, CFRunLoopMode.commonModes)
        CFRunLoopRun()
        CFRunLoopRemoveObserver(runloop, observer, CFRunLoopMode.commonModes)
        CFRunLoopRemoveSource(runloop, runloopSource, CFRunLoopMode.commonModes)

        currentRunloop = nil
    }
}
