//
//  Extensions.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Foundation

extension String {
    var stripped: String {
        let okayChars = Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890+-=().!_")
        return filter { okayChars.contains($0) }
    }
}

extension Data {
    func str(hex: Bool = false, separator: String = " ") -> String {
        if hex {
            return map { $0.hex }.joined(separator: separator)
        }
        if let string = String(data: self, encoding: .utf8) {
            return string
        }
        return compactMap { String(Character(Unicode.Scalar($0))) }.joined(separator: separator)
    }
}

extension Array where Element == UInt8 {
    func str(hex: Bool = false, separator: String = " ") -> String {
        if !hex, !contains(where: { n in !(0x20 ... 0x7E).contains(n) }),
           let value = NSString(bytes: self, length: count, encoding: String.Encoding.nonLossyASCII.rawValue) as String?
        {
            return value
        } else {
            return map { n in String(format: "%02X", n) }.joined(separator: separator)
        }
    }
}

extension UInt32 {
    var ns: NSNumber {
        NSNumber(value: self)
    }

    func toUInt8Array() -> [UInt8] {
        return [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 24) & 0xFF)]
    }

    func str() -> String {
        return toUInt8Array().str()
    }
}

extension UInt16 {
    var ns: NSNumber {
        NSNumber(value: self)
    }

    func toUInt8Array() -> [UInt8] {
        return [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF)]
    }

    func str() -> String {
        return toUInt8Array().str()
    }
}

extension UInt8 {
    var ns: NSNumber {
        NSNumber(value: self)
    }

    var hex: String {
        String(format: "%02X", self)
    }

    var percentStr: String {
        "\((self / UInt8.max) * 100)%"
    }

    func str() -> String {
        if (0x20 ... 0x7E).contains(self),
           let value = NSString(bytes: [self], length: 1, encoding: String.Encoding.nonLossyASCII.rawValue) as String?
        {
            return value
        } else {
            return String(format: "%02X", self)
        }
    }
}

extension Collection where Index: Comparable {
    subscript(back i: Int) -> Iterator.Element {
        let backBy = i + 1
        return self[index(endIndex, offsetBy: -backBy)]
    }
}

extension Encodable {
    var dictionary: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
    }
}

extension NSViewController {
    func listenForWindowClose(window: NSWindow) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(notification:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }

    @objc func windowWillClose(notification _: Notification) {}
}
