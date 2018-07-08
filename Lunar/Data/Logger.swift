//
//  Logger.swift
//  Lunar
//
//  Created by Alin on 07/07/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Crashlytics
import Foundation
import SwiftyBeaver

class Logger: SwiftyBeaver {
    class func initLogger() {
        let console = ConsoleDestination()
        let file = FileDestination()
        let platform = SBPlatformDestination(appID: "lRPGE2", appSecret: "***REMOVED***", encryptionKey: "***REMOVED***")

        Logger.addDestination(console)
        Logger.addDestination(file)
        Logger.addDestination(platform)
    }

    open override class func verbose(
        _ message: @autoclosure () -> Any,
        _
        file: String = #file,
        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        super.verbose(message, file, function, line: line, context: context)
        crashlog(String(describing: message()))
    }

    open override class func debug(
        _ message: @autoclosure () -> Any,
        _
        file: String = #file,
        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        super.debug(message, file, function, line: line, context: context)
        crashlog(String(describing: message()))
    }

    open override class func info(
        _ message: @autoclosure () -> Any,
        _
        file: String = #file,
        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        super.info(message, file, function, line: line, context: context)
        crashlog(String(describing: message()))
    }

    open override class func warning(
        _ message: @autoclosure () -> Any,
        _
        file: String = #file,
        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        super.warning(message, file, function, line: line, context: context)
        crashlog(String(describing: message()))
    }

    open override class func error(
        _ message: @autoclosure () -> Any,
        _
        file: String = #file,
        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        super.error(message, file, function, line: line, context: context)
        crashlog(String(describing: message()))
    }

    class func crashlog(_ message: String) {
        CLSLogv("%@", getVaList([message]))
    }
}
