//
//  Sysctl.swift
//  Utils
//
//  Created by Matt Gallagher on 2016/02/03.
//  Copyright © 2016 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//
//  Permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
//  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
//  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//
import Foundation
import IOKit.ps

let NATIVE_EXECUTION = Int32(0)
let EMULATED_EXECUTION = Int32(1)
let UNKNOWN_EXECUTION = -Int32(1)

// MARK: - Sysctl

/// A "static"-only namespace around a series of functions that operate on buffers returned from the `Darwin.sysctl` function
public enum Sysctl {
    /// Possible errors.
    public enum Error: Swift.Error {
        case unknown
        case malformedUTF8
        case invalidSize
        case posixError(POSIXErrorCode)
    }

    public static var processIsTranslated: Int32 = {
        var ret = Int32(0)
        var size = ret.bitWidth
        let result = sysctlbyname("sysctl.proc_translated", &ret, &size, nil, 0)
        if result == -1 {
            if errno == ENOENT {
                return 0
            }
            return -1
        }
        return ret
    }()

    /// e.g. "MacPro4,1" or "iPhone8,1"
    /// NOTE: this is *corrected* on iOS devices to fetch hw.machine
    public static var model: String = {
        #if os(iOS) && !arch(x86_64) && !arch(i386)
            return (try? Sysctl.string(for: [CTL_HW, HW_MACHINE])) ?? "Unknown"
        #else
            return (try? Sysctl.string(for: [CTL_HW, HW_MODEL])) ?? "Unknown"
        #endif
    }()

    public static var modelLowercased: String = model.lowercased()

    public static var isMacMini = modelLowercased.hasPrefix("macmini")
    public static var isiMac = modelLowercased.hasPrefix("imac")
    public static var isMacBook = modelLowercased.hasPrefix("macbook") || ["Mac14,2", "Mac14,7"].contains(model)

    /// e.g. "MyComputer.local" (from System Preferences -> Sharing -> Computer Name) or
    /// "My-Name-iPhone" (from Settings -> General -> About -> Name)
    public static var hostName: String { try! Sysctl.string(for: [CTL_KERN, KERN_HOSTNAME]) }

    /// e.g. "x86_64" or "N71mAP"
    /// NOTE: this is *corrected* on iOS devices to fetch hw.model
    public static var machine: String {
        #if os(iOS) && !arch(x86_64) && !arch(i386)
            return try! Sysctl.string(for: [CTL_HW, HW_MODEL])
        #else
            return try! Sysctl.string(for: [CTL_HW, HW_MACHINE])
        #endif
    }

    public static var device: String {
        let model = modelLowercased
        if model.hasPrefix("macpro") {
            return "Mac Pro"
        } else if model.hasPrefix("imac") {
            return "iMac"
        } else if model.hasPrefix("macbookpro") {
            return "MacBook Pro"
        } else if model.hasPrefix("macbookair") {
            return "MacBook Air"
        } else if model.hasPrefix("macbook") {
            return "MacBook"
        } else if model.hasPrefix("macmini") {
            return "Mac Mini"
        } else if model.hasPrefix("xserve") {
            return "Xserve"
        }
        return model
    }

    /// e.g. "8" or "2"
    public static var activeCPUs: Int32 { try! Sysctl.value(ofType: Int32.self, forKeys: [CTL_HW, HW_AVAILCPU]) }

    /// e.g. "15.3.0" or "15.0.0"
    public static var osRelease: String { try! Sysctl.string(for: [CTL_KERN, KERN_OSRELEASE]) }

    /// e.g. "Darwin" or "Darwin"
    public static var osType: String { try! Sysctl.string(for: [CTL_KERN, KERN_OSTYPE]) }

    /// e.g. "15D21" or "13D20"
    public static var osVersion: String { try! Sysctl.string(for: [CTL_KERN, KERN_OSVERSION]) }

    /// e.g. "Darwin Kernel Version 15.3.0: Thu Dec 10 18:40:58 PST 2015; root:xnu-3248.30.4~1/RELEASE_X86_64" or
    /// "Darwin Kernel Version 15.0.0: Wed Dec  9 22:19:38 PST 2015; root:xnu-3248.31.3~2/RELEASE_ARM64_S8000"
    public static var version: String { try! Sysctl.string(for: [CTL_KERN, KERN_VERSION]) }

    public static func batteryLevel() -> Double? {
        guard isMacBook, let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources: NSArray = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue()
        else { return nil }

        for ps in sources {
            guard let info: NSDictionary = IOPSGetPowerSourceDescription(snapshot, ps as CFTypeRef)?.takeUnretainedValue(),
                  let capacity = info[kIOPSCurrentCapacityKey] as? Int,
                  let max = info[kIOPSMaxCapacityKey] as? Int
            else { continue }

            return (max > 0) ? (Double(capacity) / Double(max)) : Double(capacity)
        }

        return nil
    }

    /// Access the raw data for an array of sysctl identifiers.
    public static func data(for keys: [Int32]) throws -> [Int8] {
        try keys.withUnsafeBufferPointer { keysPointer throws -> [Int8] in
            // Preflight the request to get the required data size
            var requiredSize = 0
            let preFlightResult = Darwin.sysctl(
                UnsafeMutablePointer<Int32>(mutating: keysPointer.baseAddress),
                keys.count.u32,
                nil,
                &requiredSize,
                nil,
                0
            )
            if preFlightResult != 0 {
                throw POSIXErrorCode(rawValue: errno).map {
                    print($0.rawValue)
                    return Error.posixError($0)
                } ?? Error.unknown
            }

            // Run the actual request with an appropriately sized array buffer
            let data = [Int8](repeating: 0, count: requiredSize)
            let result = data.withUnsafeBufferPointer { dataBuffer -> Int32 in
                Darwin.sysctl(
                    UnsafeMutablePointer<Int32>(mutating: keysPointer.baseAddress),
                    keys.count.u32,
                    UnsafeMutableRawPointer(mutating: dataBuffer.baseAddress),
                    &requiredSize,
                    nil,
                    0
                )
            }
            if result != 0 {
                throw POSIXErrorCode(rawValue: errno).map { Error.posixError($0) } ?? Error.unknown
            }

            return data
        }
    }

    /// Convert a sysctl name string like "hw.memsize" to the array of `sysctl` identifiers (e.g. [CTL_HW, HW_MEMSIZE])
    public static func keys(for name: String) throws -> [Int32] {
        var keysBufferSize = CTL_MAXNAME.i
        var keysBuffer = [Int32](repeating: 0, count: keysBufferSize)
        try keysBuffer.withUnsafeMutableBufferPointer { (lbp: inout UnsafeMutableBufferPointer<Int32>) throws in
            try name.withCString { (nbp: UnsafePointer<Int8>) throws in
                guard sysctlnametomib(nbp, lbp.baseAddress, &keysBufferSize) == 0 else {
                    throw POSIXErrorCode(rawValue: errno).map { Error.posixError($0) } ?? Error.unknown
                }
            }
        }
        if keysBuffer.count > keysBufferSize {
            keysBuffer.removeSubrange(keysBufferSize ..< keysBuffer.count)
        }
        return keysBuffer
    }

    /// Invoke `sysctl` with an array of identifers, interpreting the returned buffer as the specified type. This function will throw
    /// `Error.invalidSize` if the size of buffer returned from `sysctl` fails to match the size of `T`.
    public static func value<T>(ofType _: T.Type, forKeys keys: [Int32]) throws -> T {
        let buffer = try data(for: keys)
        if buffer.count != MemoryLayout<T>.size {
            throw Error.invalidSize
        }
        return try buffer.withUnsafeBufferPointer { bufferPtr throws -> T in
            guard let baseAddress = bufferPtr.baseAddress else { throw Error.unknown }
            return baseAddress.withMemoryRebound(to: T.self, capacity: 1) { $0.pointee }
        }
    }

    /// Invoke `sysctl` with an array of identifers, interpreting the returned buffer as the specified type. This function will throw
    /// `Error.invalidSize` if the size of buffer returned from `sysctl` fails to match the size of `T`.
    public static func value<T>(ofType type: T.Type, forKeys keys: Int32...) throws -> T {
        try value(ofType: type, forKeys: keys)
    }

    /// Invoke `sysctl` with the specified name, interpreting the returned buffer as the specified type. This function will throw
    /// `Error.invalidSize` if the size of buffer returned from `sysctl` fails to match the size of `T`.
    public static func value<T>(ofType type: T.Type, forName name: String) throws -> T {
        try value(ofType: type, forKeys: keys(for: name))
    }

    /// Invoke `sysctl` with an array of identifers, interpreting the returned buffer as a `String`. This function will throw
    /// `Error.malformedUTF8` if the buffer returned from `sysctl` cannot be interpreted as a UTF8 buffer.
    public static func string(for keys: [Int32]) throws -> String {
        let optionalString = try data(for: keys).withUnsafeBufferPointer { dataPointer -> String? in
            dataPointer.baseAddress.flatMap { String(validatingUTF8: $0) }
        }
        guard let s = optionalString else {
            throw Error.malformedUTF8
        }
        return s
    }

    /// Invoke `sysctl` with an array of identifers, interpreting the returned buffer as a `String`. This function will throw
    /// `Error.malformedUTF8` if the buffer returned from `sysctl` cannot be interpreted as a UTF8 buffer.
    public static func string(for keys: Int32...) throws -> String {
        try string(for: keys)
    }

    /// Invoke `sysctl` with the specified name, interpreting the returned buffer as a `String`. This function will throw
    /// `Error.malformedUTF8` if the buffer returned from `sysctl` cannot be interpreted as a UTF8 buffer.
    public static func string(for name: String) throws -> String {
        try string(for: keys(for: name))
    }

    #if os(macOS)
        /// e.g. 199506 (not available on iOS)
        public static var osRev: Int32 { try! Sysctl.value(ofType: Int32.self, forKeys: [CTL_KERN, KERN_OSREV]) }

        /// e.g. 2659000000 (not available on iOS)
        public static var cpuFreq: Int64 { try! Sysctl.value(ofType: Int64.self, forName: "hw.cpufrequency") }

        /// e.g. 25769803776 (not available on iOS)
        public static var memSize: UInt64 { try! Sysctl.value(ofType: UInt64.self, forKeys: [CTL_HW, HW_MEMSIZE]) }
    #endif

    public static var rosetta: Bool = processIsTranslated == EMULATED_EXECUTION
    public static var processIsTranslatedStr: String = {
        switch processIsTranslated {
        case NATIVE_EXECUTION:
            return "native"
        case EMULATED_EXECUTION:
            return "rosetta"
        default:
            return "unkown"
        }
    }()
}
