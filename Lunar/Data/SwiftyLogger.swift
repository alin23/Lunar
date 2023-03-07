//
//  Logger.swift
//  Lunar
//
//  Created by Alin on 07/07/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Combine
import Defaults
import Foundation
import SwiftyBeaver
#if DEBUG
    import os
#endif

#if DEBUG
    func debug(
        _ message: @autoclosure () -> Any,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        if let m = message() as? String {
            SwiftyLogger.oslog(file).debug("\(m)")
        }
        log.debug(message(), file: file, function: function, line: line, context: context)
    }

    func err(
        _ message: @autoclosure () -> Any,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        log.error(message(), file: file, function: function, line: line, context: context)
    }
#else
    @inline(__always) func debug(_: @autoclosure () -> Any) {}
    @inline(__always) func err(_: @autoclosure () -> Any) {}
#endif

// MARK: - Logger

final class SwiftyLogger: SwiftyBeaver {
    override class func verbose(
        _ message: @autoclosure () -> Any,
        file: String = #file,

        function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        guard initialized, console.minLevel.rawValue < Level.info.rawValue else { return }
        #if DEBUG
            if let m = message() as? String {
                oslog(file).trace("\(m)")
            }
        #endif
        super.verbose(message(), file: file, function: function, line: line, context: context)
    }

    override class func debug(
        _ message: @autoclosure () -> Any,
        file: String = #file,

        function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        guard initialized, console.minLevel.rawValue < Level.info.rawValue else { return }
        #if DEBUG
            if let m = message() as? String {
                oslog(file).debug("\(m)")
            }
        #endif
        super.debug(message(), file: file, function: function, line: line, context: context)
    }

    override class func info(
        _ message: @autoclosure () -> Any,
        file: String = #file,

        function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        guard initialized, console.minLevel.rawValue < Level.info.rawValue else { return }
        #if DEBUG
            if let m = message() as? String {
                oslog(file).info("\(m)")
            }
        #endif
        super.info(message(), file: file, function: function, line: line, context: context)
    }

    override class func warning(
        _ message: @autoclosure () -> Any,
        file: String = #file,

        function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        guard initialized else { return }
        super.warning(message(), file: file, function: function, line: line, context: context)
    }

    override class func error(
        _ message: @autoclosure () -> Any,
        file: String = #file,

        function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        guard initialized else { return }
        super.error(message(), file: file, function: function, line: line, context: context)
    }

    #if DEBUG
        static var osLoggers: [String: Logger] = [:]
        class func oslog(_ category: String) -> Logger {
            let category = category.split(separator: "/").last!.split(separator: ".").first!.s
            guard let logger = osLoggers[category] else {
                let logger = Logger(subsystem: "fyi.lunar.Lunar", category: category)
                osLoggers[category] = logger
                return logger
            }
            return logger
        }
    #endif
    static var observers: Set<AnyCancellable> = []

    @Atomic static var trace: Bool = Defaults[.trace] && Defaults[.debug]

    static let console = ConsoleDestination()
    static let file = FileDestination()
    static let cloud = SBPlatformDestination(appID: "WxjbvQ", appSecret: secrets.appSecret, encryptionKey: secrets.encryptionKey)
    @Atomic static var initialized = false

    @inline(__always)
    class func traceCalls() {
        Thread.callStackSymbols.forEach {
            info($0)
        }
    }

    class func initLogger(cli: Bool = false, debug: Bool = false, verbose: Bool = false) {
        defer { initialized = true }
        console.format = "$DHH:mm:ss.SSS$d $C$L$c $N.$F:$l - $M \t$X"
        file.format = "$DHH:mm:ss.SSS$d $L $N.$F:$l - $M \t$X"
        file.logFileMaxSize = (15 * 1024 * 1024)
        file.logFileAmount = 3
        SwiftyLogger.addDestination(console)

        #if DEBUG
            setMinLevel(debug: !cli, verbose: !cli, cloud: false, cli: cli)
        #else
            setMinLevel(
                debug: !cli && (debug || Defaults[.debug]),
                verbose: !cli && (verbose || Defaults[.debug]),
                cloud: false,
                cli: cli
            )
        #endif

        debugPublisher.sink { change in
            guard !cli else { return }
            SwiftyLogger.trace = Defaults[.trace] && change.newValue
            self.setMinLevel(
                debug: change.newValue,
                verbose: change.newValue,
                cloud: false
            )
        }
        .store(in: &observers)

        tracePublisher
            .sink { SwiftyLogger.trace = $0.newValue && Defaults[.debug] }
            .store(in: &observers)

        #if !DEBUG
            if debug || verbose {
                SwiftyLogger.addDestination(file)
            }
        #endif

        if lunarProActive, let email = lunarProProduct?.activationEmail {
            SwiftyLogger.cloud.analyticsUserName = email
        }
    }

    class func disable() {
        SwiftyLogger.removeAllDestinations()
    }

    class func setMinLevel(debug: Bool, verbose: Bool = false, cloud: Bool = false, cli: Bool = false) {
        if verbose {
            console.minLevel = .verbose
            file.minLevel = .verbose
            if cloud { self.cloud.minLevel = .verbose }

            #if !DEBUG
                SwiftyLogger.addDestination(file)
            #endif
        } else if debug {
            console.minLevel = .debug
            file.minLevel = .debug
            if cloud { self.cloud.minLevel = .debug }

            #if !DEBUG
                SwiftyLogger.addDestination(file)
            #endif
        } else {
            #if !DEBUG
                SwiftyLogger.removeDestination(file)
            #endif

            console.minLevel = cli ? .warning : .info
            file.minLevel = cli ? .warning : .info
            if cloud { self.cloud.minLevel = cli ? .warning : .info }
        }
    }
}

let log = SwiftyLogger.self

import Sentry

func crumb(_ msg: String, level: SentryLevel = .info, category: String) {
//    log.info("\(category): \(msg)")

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
