//
//  Logger.swift
//  Lunar
//
//  Created by Alin on 07/07/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Defaults
import Foundation
import SwiftyBeaver

class Logger: SwiftyBeaver {
    static let console = ConsoleDestination()
    static let file = FileDestination()
    static var debugModeObserver: DefaultsObservation?

    class func initLogger() {
        console.format = "$DHH:mm:ss.SSS$d $C$L$c $N.$F:$l - $M \n$X"
        file.format = "$DHH:mm:ss.SSS$d $L $N.$F:$l - $M \n$X"

        setMinLevel(debug: Defaults[.debug])
        debugModeObserver = Defaults.observe(.debug) { change in
            self.setMinLevel(debug: change.newValue)
        }

        Logger.addDestination(console)
        Logger.addDestination(file)
    }

    class func setMinLevel(debug _: Bool) {
        if !Defaults[.debug] {
            console.minLevel = .info
            file.minLevel = .info
        } else {
            console.minLevel = .verbose
            file.minLevel = .verbose
        }
    }

    override open class func verbose(
        _ message: @autoclosure () -> Any,
        _ file: String = #file,

        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
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
        super.info(message(), file, function, line: line, context: context)
    }

    override open class func warning(
        _ message: @autoclosure () -> Any,
        _ file: String = #file,

        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        super.warning(message(), file, function, line: line, context: context)
    }

    override open class func error(
        _ message: @autoclosure () -> Any,
        _ file: String = #file,

        _ function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        super.error(message(), file, function, line: line, context: context)
    }
}

let log = Logger.self
