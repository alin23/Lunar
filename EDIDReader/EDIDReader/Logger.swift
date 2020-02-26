//
//  Logger.swift
//  EDIDReader
//
//  Created by Alin on 10/04/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Foundation

class Logger {
    class func verbose(_ message: Any, context: Any? = nil, _ function: String = #function, line: Int = #line) {
        if let ctx = context {
            print("VERBOSE [\(function):\(line)]: \(message) (context \(String(describing: ctx)))")
        } else {
            print("VERBOSE [\(function):\(line)]: \(message)")
        }
    }

    class func debug(_ message: Any, context: Any? = nil, _ function: String = #function, line: Int = #line) {
        if let ctx = context {
            print("DEBUG [\(function):\(line)]: \(message) (context \(String(describing: ctx)))")
        } else {
            print("DEBUG [\(function):\(line)]: \(message)")
        }
    }

    class func info(_ message: Any, context: Any? = nil, _ function: String = #function, line: Int = #line) {
        if let ctx = context {
            print("INFO [\(function):\(line)]: \(message) (context \(String(describing: ctx)))")
        } else {
            print("INFO [\(function):\(line)]: \(message)")
        }
    }

    class func warning(_ message: Any, context: Any? = nil, _ function: String = #function, line: Int = #line) {
        if let ctx = context {
            print("WARNING [\(function):\(line)]: \(message) (context \(String(describing: ctx)))")
        } else {
            print("WARNING [\(function):\(line)]: \(message)")
        }
    }

    class func error(_ message: Any, context: Any? = nil, _ function: String = #function, line: Int = #line) {
        if let ctx = context {
            print("ERROR [\(function):\(line)]: \(message) (context \(String(describing: ctx)))")
        } else {
            print("ERROR [\(function):\(line)]: \(message)")
        }
    }
}
