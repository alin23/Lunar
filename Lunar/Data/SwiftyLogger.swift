//
//  SwiftyLogger.swift
//  Lunar
//
//  Created by Alin on 07/07/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Foundation
import os

#if DEBUG
    @inline(__always) @inlinable func debug(_ message: @autoclosure @escaping () -> String) {
        log.oslog.debug("\(message())")
    }

    @inline(__always) @inlinable func trace(_ message: @autoclosure @escaping () -> String) {
        log.oslog.trace("\(message())")
    }

    @inline(__always) @inlinable func err(_ message: @autoclosure @escaping () -> String) {
        log.oslog.critical("\(message())")
    }
#else
    @inline(__always) @inlinable func trace(_: @autoclosure () -> String) {}
    @inline(__always) @inlinable func debug(_: @autoclosure () -> String) {}
    @inline(__always) @inlinable func err(_: @autoclosure () -> String) {}
#endif

// MARK: - Logger

@usableFromInline final class SwiftyLogger {
    @usableFromInline static let oslog = Logger(subsystem: "fyi.lunar.Lunar", category: "default")
    @usableFromInline static let traceLog = Logger(subsystem: "fyi.lunar.Lunar", category: "trace")

    @inline(__always) @inlinable class func verbose(_ message: String, context: Any? = "") {
        #if DEBUG
            oslog.trace("🫥 \(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #else
            oslog.trace("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #endif
    }

    @inline(__always) @inlinable class func debug(_ message: String, context: Any? = "") {
        #if DEBUG
            oslog.debug("🌲 \(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #else
            oslog.debug("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #endif
    }

    @inline(__always) @inlinable class func info(_ message: String, context: Any? = "") {
        #if DEBUG
            oslog.info("💠 \(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #else
            oslog.info("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #endif
    }

    @inline(__always) @inlinable class func warning(_ message: String, context: Any? = "") {
        #if DEBUG
            oslog.warning("🦧 \(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #else
            oslog.warning("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #endif
    }

    @inline(__always) @inlinable class func error(_ message: String, context: Any? = "") {
        #if DEBUG
            oslog.fault("👹 \(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #else
            oslog.fault("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #endif
    }

    @inline(__always) @inlinable class func traceCalls() {
        #if !DEBUG
            traceLog.trace("\(Thread.callStackSymbols.joined(separator: "\n"), privacy: .public)")
        #endif
    }

    @inline(__always) @inlinable class func traceCallsDebug() {
        #if DEBUG
            traceLog.trace("\(Thread.callStackSymbols.joined(separator: "\n"), privacy: .public)")
        #endif
    }
}

@usableFromInline let log = SwiftyLogger.self

import Sentry

func crumb(_ msg: String, level: SentryLevel = .info, category: String) {
    guard AppDelegate.enableSentry else { return }
    let crumb = Breadcrumb(level: level, category: category)
    crumb.message = msg
    SentrySDK.addBreadcrumb(crumb)
}

func adaptiveCrumb(_ msg: String) {
    crumb(msg, category: "Adaptive")
}

func uiCrumb(_ msg: String) {
    crumb(msg, category: "UI")
}
