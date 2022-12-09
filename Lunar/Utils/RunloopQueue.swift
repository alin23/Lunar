//
//  RunloopQueue.swift
//  RunloopQueue
//
//  Created by Daniel Kennett on 2017-02-14.
//  For license information, see LICENSE.md.
//

import Foundation

// MARK: - RunloopQueue

/// RunloopQueue is a serial queue based on CFRunLoop, running on the background thread.
@objc(CBLRunloopQueue)
public class RunloopQueue: NSObject {
    /// Init a new queue with the given name.
    ///
    /// - Parameter name: The name of the queue.
    @objc(initWithName:main:) public init(named name: String?, main: Bool = false) {
        thread = RunloopQueueThread()
        thread.name = name
        self.main = main
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
        if main {
            DispatchQueue.main.async(execute: block)
            return
        }
        CFRunLoopPerformBlock(runloop, CFRunLoopMode.defaultMode.rawValue, block)
        thread.awake()
    }

    /// Execute a block of code in an asynchronous manner periodically. Will return immediately.
    ///
    /// - Parameter block: The block of code to execute.
    @objc public func async(
        every interval: DateComponents,
        existingTimer: CFRunLoopTimer? = nil,
        _ block: @escaping ((CFRunLoopTimer?) -> Void)
    ) -> CFRunLoopTimer? {
        guard let timer = existingTimer ?? CFRunLoopTimerCreateWithHandler(
            kCFAllocatorDefault,
            CFAbsoluteTimeGetCurrent(),
            interval.timeInterval,
            0,
            0,
            block
        )
        else { return nil }
        if !isValid(timer: timer) {
            CFRunLoopAddTimer(runloop, timer, CFRunLoopMode.defaultMode)
        }
        thread.awake()
        return timer
    }

    @objc public func cancel(timer: CFRunLoopTimer) {
        guard isValid(timer: timer) else { return }
        CFRunLoopRemoveTimer(runloop, timer, CFRunLoopMode.defaultMode)
    }

    @objc public func isValid(timer: CFRunLoopTimer) -> Bool {
        CFRunLoopContainsTimer(runloop, timer, CFRunLoopMode.defaultMode)
    }

    public func sync<T>(_ block: @escaping (() -> T)) -> T {
        runSync(block)
    }

    public func sync(_ block: @escaping (() -> Void)) {
        runSync(block)
    }

    /// Query if the caller is running on this queue.
    ///
    /// - Returns: `true` if the caller is running on this queue, otherwise `false`.
    @objc public func isRunningOnQueue() -> Bool {
        CFEqual(CFRunLoopGetCurrent(), runloop)
    }

    var runloop: CFRunLoop!

    /// Execute a block of code in a synchronous manner. Will return when the code has executed.
    ///
    /// It's important to be careful with `sync()` to avoid deadlocks. In particular, calling `sync()` from inside
    /// a block previously passed to `sync()` will deadlock if the second call is made from a different thread.
    ///
    /// - Parameter block: The block of code to execute.
    ///

    func runSync<T>(_ block: @escaping (() -> T)) -> T {
        if main {
            return mainThread(block)
        }

        if isRunningOnQueue() {
            return block()
        }

        let conditionLock = NSConditionLock(condition: 0)
        var result: T!
        CFRunLoopPerformBlock(runloop, CFRunLoopMode.defaultMode.rawValue) {
            conditionLock.lock()
            result = block()
            conditionLock.unlock(withCondition: 1)
        }

        thread.awake()
        conditionLock.lock(whenCondition: 1)
        conditionLock.unlock()

        return result
    }

    private let thread: RunloopQueueThread
    private var main: Bool

    private func startRunloop() {
        let conditionLock = NSConditionLock(condition: 0)

        thread.start {
            [weak self] runloop in
            // This is on the background thread.

            conditionLock.lock()
            defer { conditionLock.unlock(withCondition: 1) }

            guard let self else { return }
            self.runloop = runloop
        }

        conditionLock.lock(whenCondition: 1)
        conditionLock.unlock()
    }
}

// MARK: - RunloopQueueThread

private class RunloopQueueThread: Thread {
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

    // Required to keep the runloop running when nothing is going on.
    private let runloopSource: CFRunLoopSource
    private var currentRunloop: CFRunLoop?
}
