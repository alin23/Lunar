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

// MARK: - Logger

class Logger: SwiftyBeaver {
    // MARK: Open

    override open class func verbose(
        _ message: @autoclosure () -> Any,
        _ file: String = #file,

        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        guard initialized else { return }
        super.verbose(message(), file, function, line: line, context: context)
    }

    override open class func debug(
        _ message: @autoclosure () -> Any,
        _ file: String = #file,

        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        super.debug(message(), file, function, line: line, context: context)
    }

    override open class func info(
        _ message: @autoclosure () -> Any,
        _ file: String = #file,

        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        guard initialized else { return }
        super.info(message(), file, function, line: line, context: context)
    }

    override open class func warning(
        _ message: @autoclosure () -> Any,
        _ file: String = #file,

        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        guard initialized else { return }
        super.warning(message(), file, function, line: line, context: context)
    }

    override open class func error(
        _ message: @autoclosure () -> Any,
        _ file: String = #file,

        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        guard initialized else { return }
        super.error(message(), file, function, line: line, context: context)
    }

    // MARK: Internal

    static let console = ConsoleDestination()
    static let file = FileDestination()
    static let cloud = SBPlatformDestination(appID: "WxjbvQ", appSecret: secrets.appSecret, encryptionKey: secrets.encryptionKey)
    static var debugModeObserver: Cancellable?
    @Atomic static var initialized = false

    class func initLogger(cli: Bool = false, debug: Bool = false, verbose: Bool = false) {
        defer { initialized = true }
        console.format = "$DHH:mm:ss.SSS$d $C$L$c $N.$F:$l - $M \t$X"
        file.format = "$DHH:mm:ss.SSS$d $L $N.$F:$l - $M \t$X"
        Logger.addDestination(console)

        let debugMode = { (enabled: Bool) in
            enabled || TEST_MODE || AppSettings.beta
        }

        setMinLevel(
            debug: !cli && debugMode(cli ? debug : Defaults[.debug]),
            verbose: !cli && (verbose || TEST_MODE || Defaults[.debug]),
            cloud: !cli && AppSettings.beta,
            cli: cli
        )
        debugModeObserver = debugPublisher.sink { change in
            guard !cli else { return }
            self.setMinLevel(
                debug: debugMode(change.newValue),
                verbose: verbose || TEST_MODE || change.newValue,
                cloud: !cli && AppSettings.beta
            )
        }

        #if !DEBUG
            Logger.addDestination(file)
            if !cli, AppSettings.beta {
                cloud.format = "$DHH:mm:ss.SSS$d $L $N.$F:$l - $M \n\t$X"
                Logger.addDestination(cloud)
            }
        #endif

        if lunarProActive, let email = lunarProProduct?.activationEmail {
            Logger.cloud.analyticsUserName = email
        }
    }

    class func disable() {
        Logger.removeAllDestinations()
    }

    class func setMinLevel(debug: Bool, verbose: Bool = false, cloud: Bool = false, cli: Bool = false) {
        if verbose {
            console.minLevel = .verbose
            file.minLevel = .verbose
            if cloud { self.cloud.minLevel = .verbose }
        } else if debug {
            console.minLevel = .debug
            file.minLevel = .debug
            if cloud { self.cloud.minLevel = .debug }
        } else {
            console.minLevel = cli ? .warning : .info
            file.minLevel = cli ? .warning : .info
            if cloud { self.cloud.minLevel = cli ? .warning : .info }
        }
    }
}

let log = Logger.self

import Sentry

func crumb(_ msg: String, level: SentryLevel = .info, category: String) {
    log.info("\(category): \(msg)")

    let crumb = Breadcrumb(level: level, category: category)
    crumb.message = msg
    SentrySDK.addBreadcrumb(crumb: crumb)
}

func adaptiveCrumb(_ msg: String) {
    crumb(msg, category: "Adaptive")
}

func uiCrumb(_ msg: String) {
    crumb(msg, category: "UI")
}
