//
//  Logger.swift
//  EDIDReader
//
//  Created by Alin on 10/04/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Foundation

class Logger {
    class func verbose(_ message: Any, context: Any? = nil) {
        print("VERBOSE: \(message) (context \(String(describing: context)))")
    }

    class func debug(_ message: Any, context: Any? = nil) {
        print("DEBUG: \(message) (context \(String(describing: context)))")
    }

    class func info(_ message: Any, context: Any? = nil) {
        print("INFO: \(message) (context \(String(describing: context)))")
    }

    class func warning(_ message: Any, context: Any? = nil) {
        print("WARNING: \(message) (context \(String(describing: context)))")
    }

    class func error(_ message: Any, context: Any? = nil) {
        print("ERROR: \(message) (context \(String(describing: context)))")
    }
}
