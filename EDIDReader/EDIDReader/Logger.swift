//
//  Logger.swift
//  EDIDReader
//
//  Created by Alin on 10/04/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Foundation

class Logger {
    class func verbose(_ message: Any) {
        print("VERBOSE: \(message)")
    }

    class func debug(_ message: Any) {
        print("DEBUG: \(message)")
    }

    class func info(_ message: Any) {
        print("INFO: \(message)")
    }

    class func warning(_ message: Any) {
        print("WARNING: \(message)")
    }

    class func error(_ message: Any) {
        print("ERROR: \(message)")
    }
}
