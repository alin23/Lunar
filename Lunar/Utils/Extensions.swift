//
//  Extensions.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Combine
import Foundation
import Surge

// MARK: private functionality

extension DispatchQueue {
    private struct QueueReference { weak var queue: DispatchQueue? }

    private static let key: DispatchSpecificKey<QueueReference> = {
        let key = DispatchSpecificKey<QueueReference>()
        setupSystemQueuesDetection(key: key)
        return key
    }()

    private static func _registerDetection(of queues: [DispatchQueue], key: DispatchSpecificKey<QueueReference>) {
        queues.forEach { $0.setSpecific(key: key, value: QueueReference(queue: $0)) }
    }

    private static func setupSystemQueuesDetection(key: DispatchSpecificKey<QueueReference>) {
        let queues: [DispatchQueue] = [
            .main,
            .global(qos: .background),
            .global(qos: .default),
            .global(qos: .unspecified),
            .global(qos: .userInitiated),
            .global(qos: .userInteractive),
            .global(qos: .utility),
            concurrentQueue,
            serialQueue,
            mainSerialQueue,
            dataSerialQueue,
            DDC.queue,
            CachedDefaults.cache.accessQueue,
        ]
        _registerDetection(of: queues, key: key)
    }
}

// MARK: public functionality

extension DispatchQueue {
    static func registerDetection(of queue: DispatchQueue) {
        _registerDetection(of: [queue], key: key)
    }

    static var currentQueueLabel: String? { current?.label }
    static var current: DispatchQueue? { getSpecific(key: key)?.queue }
}

extension BinaryInteger {
    @inline(__always) var ns: NSNumber {
        NSNumber(value: d)
    }

    @inline(__always) var d: Double {
        Double(self)
    }

    @inline(__always) var f: Float {
        Float(self)
    }

    @inline(__always) var u: UInt {
        UInt(self)
    }

    @inline(__always) var u8: UInt8 {
        UInt8(cap(self, minVal: 0, maxVal: 255))
    }

    @inline(__always) var u16: UInt16 {
        UInt16(self)
    }

    @inline(__always) var u32: UInt32 {
        UInt32(self)
    }

    @inline(__always) var u64: UInt64 {
        UInt64(self)
    }

    @inline(__always) var i: Int {
        Int(self)
    }

    @inline(__always) var i8: Int8 {
        Int8(self)
    }

    @inline(__always) var i16: Int16 {
        Int16(self)
    }

    @inline(__always) var i32: Int32 {
        Int32(self)
    }

    @inline(__always) var i64: Int64 {
        Int64(self)
    }

    @inline(__always) var s: String {
        String(self)
    }

    func asPercentage(of value: Self, decimals: UInt8 = 2) -> String {
        "\(((d / value.d) * 100.0).str(decimals: decimals))%"
    }
}

extension Bool {
    @inline(__always) var i: Int {
        self ? 1 : 0
    }

    @inline(__always) var state: NSControl.StateValue {
        self ? .on : .off
    }
}

extension NSColor {
    func with(hue: CGFloat? = nil, saturation: CGFloat? = nil, brightness: CGFloat? = nil, alpha: CGFloat? = nil) -> NSColor {
        NSColor(
            hue: cap(hueComponent + (hue ?? 0), minVal: 0, maxVal: 1),
            saturation: cap(saturationComponent + (saturation ?? 0), minVal: 0, maxVal: 1),
            brightness: cap(brightnessComponent + (brightness ?? 0), minVal: 0, maxVal: 1),
            alpha: cap(alphaComponent + (alpha ?? 0), minVal: 0, maxVal: 1)
        )
    }
}

let CHARS_NOT_STRIPPED = Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890+-=().!_")
extension String {
    @inline(__always) var stripped: String {
        filter { CHARS_NOT_STRIPPED.contains($0) }
    }

    @inline(__always) var d: Double? {
        Double(replacingOccurrences(of: ",", with: "."))
        // NumberFormatter.shared.number(from: self)?.doubleValue
    }

    @inline(__always) var f: Float? {
        Float(replacingOccurrences(of: ",", with: "."))
        // NumberFormatter.shared.number(from: self)?.floatValue
    }

    @inline(__always) var u: UInt? {
        UInt(self)
    }

    @inline(__always) var u8: UInt8? {
        UInt8(self)
    }

    @inline(__always) var u16: UInt16? {
        UInt16(self)
    }

    @inline(__always) var u32: UInt32? {
        UInt32(self)
    }

    @inline(__always) var u64: UInt64? {
        UInt64(self)
    }

    @inline(__always) var i: Int? {
        Int(self)
    }

    @inline(__always) var i8: Int8? {
        Int8(self)
    }

    @inline(__always) var i16: Int16? {
        Int16(self)
    }

    @inline(__always) var i32: Int32? {
        Int32(self)
    }

    @inline(__always) var i64: Int64? {
        Int64(self)
    }

    func replacingFirstOccurrence(of target: String, with replacement: String) -> String {
        guard let range = self.range(of: target) else { return self }
        return replacingCharacters(in: range, with: replacement)
    }

    func titleCase() -> String {
        replacingOccurrences(
            of: "([A-Z])",
            with: " $1",
            options: .regularExpression,
            range: range(of: self)
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .capitalized
    }
}

extension String.SubSequence {
    @inline(__always) var u32: UInt32? {
        UInt32(self)
    }

    @inline(__always) var i32: Int32? {
        Int32(self)
    }

    @inline(__always) var d: Double? {
        Double(self)
    }
}

extension Data {
    func str(hex: Bool = false, base64: Bool = false, urlSafe: Bool = false, separator: String = " ") -> String {
        if base64 {
            let b64str = base64EncodedString(options: [])
            return urlSafe ? b64str.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? b64str : b64str
        }

        if hex {
            let hexstr = map(\.hex).joined(separator: separator)
            return urlSafe ? hexstr.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? hexstr : hexstr
        }

        if let string = String(data: self, encoding: .utf8) {
            return urlSafe ? string.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? string : string
        }

        let rawstr = compactMap { String(Character(Unicode.Scalar($0))) }.joined(separator: separator)
        return urlSafe ? rawstr.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? rawstr : rawstr
    }
}

extension Array where Element == Character {
    func str() -> String {
        String(self)
    }
}

extension Array where Element == UInt8 {
    func str(hex: Bool = false, base64: Bool = false, urlSafe: Bool = false, separator: String = " ") -> String {
        if base64 {
            return Data(bytes: self, count: count).str(hex: hex, base64: base64, urlSafe: urlSafe, separator: separator)
        }

        if !hex, !contains(where: { n in !(0x20 ... 0x7E).contains(n) }),
           let value = NSString(bytes: self, length: count, encoding: String.Encoding.nonLossyASCII.rawValue) as String?
        {
            return urlSafe ? value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value : value
        }

        let hexstr = map { n in String(format: "%02x", n) }.joined(separator: separator)
        return urlSafe ? hexstr.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? hexstr : hexstr
    }
}

extension Double {
    @inline(__always) func rounded(to scale: Int) -> Double {
        let behavior = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: scale.i16,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: true
        )

        let roundedValue = NSDecimalNumber(value: self).rounding(accordingToBehavior: behavior)

        return roundedValue.doubleValue
    }

    @inline(__always) var ns: NSNumber {
        NSNumber(value: self)
    }

    @inline(__always) var f: Float {
        Float(self)
    }

    @inline(__always) var i: Int {
        Int(self)
    }

    @inline(__always) var u8: UInt8 {
        UInt8(cap(intround, minVal: 0, maxVal: 255))
    }

    @inline(__always) var u16: UInt16 {
        UInt16(self)
    }

    @inline(__always) var u32: UInt32 {
        UInt32(self)
    }

    @inline(__always) var intround: Int {
        rounded().i
    }

    func str(decimals: UInt8, localized: Bool = false) -> String {
        guard decimals > 0 else { return "\(intround)" }
        guard localized else { return String(format: "%.\(decimals)f", self) }

        return NumberFormatter.shared(decimals: decimals.i).string(from: ns) ?? String(format: "%.\(decimals)f", self)
    }

    func asPercentage(of value: Self, decimals: UInt8 = 2) -> String {
        "\(((self / value) * 100.0).str(decimals: decimals))%"
    }
}

extension NumberFormatter {
    static let shared = NumberFormatter()
    static let oneDecimalPoint = formatter(with: 1)
    static let twoDecimalPoints = formatter(with: 2)
    static let threeDecimalPoints = formatter(with: 3)

    static func formatter(with _: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.alwaysShowsDecimalSeparator = true
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2

        return f
    }

    static func shared(decimals: Int) -> NumberFormatter {
        switch decimals {
        case 1:
            return NumberFormatter.oneDecimalPoint
        case 2:
            return NumberFormatter.twoDecimalPoints
        case 3:
            return NumberFormatter.threeDecimalPoints
        default:
            return NumberFormatter.formatter(with: decimals)
        }
    }
}

extension NSAttributedString {
    func appending(_ other: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)
        mutable.append(other)
        return mutable
    }
}

extension Dictionary {
    var threadSafe: ThreadSafeDictionary<Key, Value> {
        ThreadSafeDictionary(dict: self)
    }
}

extension Float {
    @inline(__always) func rounded(to scale: Int) -> Float {
        let behavior = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: scale.i16,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: true
        )

        let roundedValue = NSDecimalNumber(value: self).rounding(accordingToBehavior: behavior)

        return roundedValue.floatValue
    }

    @inline(__always) var ns: NSNumber {
        NSNumber(value: self)
    }

    @inline(__always) var d: Double {
        Double(self)
    }

    @inline(__always) var i: Int {
        Int(self)
    }

    @inline(__always) var u8: UInt8 {
        UInt8(cap(intround, minVal: 0, maxVal: 255))
    }

    @inline(__always) var u16: UInt16 {
        UInt16(self)
    }

    @inline(__always) var u32: UInt32 {
        UInt32(self)
    }

    @inline(__always) var intround: Int {
        rounded().i
    }

    func str(decimals: UInt8, localized: Bool = false) -> String {
        guard decimals > 0 else { return "\(intround)" }
        guard localized else { return String(format: "%.\(decimals)f", self) }

        return NumberFormatter.shared(decimals: decimals.i).string(from: ns) ?? String(format: "%.\(decimals)f", self)
    }

    func asPercentage(of value: Self, decimals: UInt8 = 2) -> String {
        "\(((self / value) * 100.0).str(decimals: decimals))%"
    }
}

extension CGFloat {
    @inline(__always) var ns: NSNumber {
        NSNumber(value: Float(self))
    }

    @inline(__always) var d: Double {
        Double(self)
    }

    @inline(__always) var i: Int {
        Int(self)
    }

    @inline(__always) var u8: UInt8 {
        UInt8(self)
    }

    @inline(__always) var u16: UInt16 {
        UInt16(self)
    }

    @inline(__always) var u32: UInt32 {
        UInt32(self)
    }

    @inline(__always) var intround: Int {
        rounded().i
    }

    func str(decimals: UInt8, localized: Bool = false) -> String {
        guard decimals > 0 else { return "\(intround)" }
        guard localized else { return String(format: "%.\(decimals)f", self) }

        return NumberFormatter.shared(decimals: decimals.i).string(from: ns) ?? String(format: "%.\(decimals)f", self)
    }

    func asPercentage(of value: Self, decimals: UInt8 = 2) -> String {
        "\(((self / value) * 100.0).str(decimals: decimals))%"
    }
}

extension Int {
    func toUInt8Array() -> [UInt8] {
        [
            UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 24) & 0xFF),
            UInt8((self >> 32) & 0xFF), UInt8((self >> 40) & 0xFF), UInt8((self >> 48) & 0xFF), UInt8((self >> 56) & 0xFF),
        ]
    }

    func str(reversed: Bool = false, separator: String = " ", hex: Bool = true) -> String {
        var arr = toUInt8Array()
        if reversed {
            arr = arr.reversed()
        }
        return arr.str(hex: hex, separator: separator)
    }
}

extension Int64 {
    func toUInt8Array() -> [UInt8] {
        [
            UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 24) & 0xFF),
            UInt8((self >> 32) & 0xFF), UInt8((self >> 40) & 0xFF), UInt8((self >> 48) & 0xFF), UInt8((self >> 56) & 0xFF),
        ]
    }

    func str(reversed: Bool = false, separator: String = " ", hex: Bool = true) -> String {
        var arr = toUInt8Array()
        if reversed {
            arr = arr.reversed()
        }
        return arr.str(hex: hex, separator: separator)
    }
}

extension UInt64 {
    func toUInt8Array() -> [UInt8] {
        [
            UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 24) & 0xFF),
            UInt8((self >> 32) & 0xFF), UInt8((self >> 40) & 0xFF), UInt8((self >> 48) & 0xFF), UInt8((self >> 56) & 0xFF),
        ]
    }

    func str(reversed: Bool = false, separator: String = " ", hex: Bool = true) -> String {
        var arr = toUInt8Array()
        if reversed {
            arr = arr.reversed()
        }
        return arr.str(hex: hex, separator: separator)
    }
}

extension UInt32 {
    func toUInt8Array() -> [UInt8] {
        [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 24) & 0xFF)]
    }

    func str(reversed: Bool = false, separator: String = " ", hex: Bool = true) -> String {
        var arr = toUInt8Array()
        if reversed {
            arr = arr.reversed()
        }
        return arr.str(hex: hex, separator: separator)
    }
}

extension UInt16 {
    func toUInt8Array() -> [UInt8] {
        [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF)]
    }

    func str(reversed: Bool = false, separator: String = " ", hex: Bool = true) -> String {
        var arr = toUInt8Array()
        if reversed {
            arr = arr.reversed()
        }
        return arr.str(hex: hex, separator: separator)
    }
}

extension UInt8 {
    var hex: String {
        String(format: "%02x", self)
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
            return String(format: "%02x", self)
        }
    }
}

extension Int32 {
    func toUInt8Array() -> [UInt8] {
        [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 24) & 0xFF)]
    }

    func str(reversed: Bool = false, separator: String = " ", hex: Bool = true) -> String {
        var arr = toUInt8Array()
        if reversed {
            arr = arr.reversed()
        }
        return arr.str(hex: hex, separator: separator)
    }
}

extension Int16 {
    func toUInt8Array() -> [UInt8] {
        [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF)]
    }

    func str(reversed: Bool = false, separator: String = " ", hex: Bool = true) -> String {
        var arr = toUInt8Array()
        if reversed {
            arr = arr.reversed()
        }
        return arr.str(hex: hex, separator: separator)
    }
}

extension Int8 {
    var hex: String {
        String(format: "%02x", self)
    }

    var percentStr: String {
        "\((self / Int8.max) * 100)%"
    }

    func str() -> String {
        if (0x20 ... 0x7E).contains(self),
           let value = NSString(bytes: [self], length: 1, encoding: String.Encoding.nonLossyASCII.rawValue) as String?
        {
            return value
        } else {
            return String(format: "%02x", self)
        }
    }
}

extension ArraySlice {
    var arr: [Element] {
        Array(self)
    }
}

extension NSScreen {
    override open var description: String {
        "NSScreen \(localizedName)(id: \(displayID ?? 0), builtin: \(isBuiltin), virtual: \(isVirtual), screen: \(isScreen), hasMouse: \(hasMouse))"
    }

    static func isOnline(_ id: CGDirectDisplayID) -> Bool {
        onlineDisplayIDs.contains(id)
    }

    static var onlineDisplayIDs: [CGDirectDisplayID] {
        let maxDisplays: UInt32 = 16
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: maxDisplays.i)
        var displayCount: UInt32 = 0

        let err = CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount)
        if err != .success {
            log.error("Error on getting online displays: \(err)")
        }

        return onlineDisplays.prefix(displayCount.i).arr
    }

    static var onlyExternalScreen: NSScreen? {
        let screens = externalScreens
        guard screens.count == 1, let screen = screens.first else {
            return nil
        }

        return screen
    }

    static var externalScreens: [NSScreen] {
        screens.filter { !$0.isBuiltin }
    }

    static var withMouse: NSScreen? {
        screens.first { $0.hasMouse }
    }

    static var externalWithMouse: NSScreen? {
        screens.first { !$0.isBuiltin && $0.hasMouse }
    }

    var hasMouse: Bool {
        let mouseLocation = NSEvent.mouseLocation
        if NSMouseInRect(mouseLocation, frame, false) {
            return true
        }

        guard let event = CGEvent(source: nil) else {
            return false
        }

        let maxDisplays: UInt32 = 1
        var displaysWithCursor = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        let err = CGGetDisplaysWithPoint(event.location, maxDisplays, &displaysWithCursor, &displayCount)
        if err != .success {
            log.error("Error on getting displays with mouse location: \(err)")
        }
        guard let id = displaysWithCursor.first else {
            return false
        }
        return id == displayID
    }

    var displayID: CGDirectDisplayID? {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        return CGDirectDisplayID(id.uint32Value)
    }

    var isBuiltin: Bool {
        displayID != nil && DDC.isBuiltinDisplay(displayID!)
    }

    var isVirtual: Bool {
        displayID != nil && DDC.isVirtualDisplay(displayID!)
    }

    var isScreen: Bool {
        guard let isScreenStr = deviceDescription[NSDeviceDescriptionKey.isScreen] as? String else {
            return false
        }
        return isScreenStr == "YES"
    }

    static func forDisplayID(_ id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.hasDisplayID(id) }
    }

    func hasDisplayID(_ id: CGDirectDisplayID) -> Bool {
        guard let screenNumber = displayID else { return false }
        return id == screenNumber
    }
}

extension AnyBidirectionalCollection where Element: BinaryInteger {
    var commaSeparatedString: String {
        map(\.s).joined(separator: ", ")
    }
}

extension Set where Element: BinaryInteger {
    var commaSeparatedString: String {
        map(\.s).joined(separator: ", ")
    }
}

extension Collection {
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

extension NSWindow {
    func shake(with intensity: CGFloat = 0.01, duration: Double = 0.3) {
        let numberOfShakes = 3
        let frame: CGRect = self.frame
        let shakeAnimation = CAKeyframeAnimation()

        let shakePath = CGMutablePath()
        shakePath.move(to: CGPoint(x: NSMinX(frame), y: NSMinY(frame)))

        for _ in 0 ... numberOfShakes - 1 {
            shakePath.addLine(to: CGPoint(x: NSMinX(frame) - frame.size.width * intensity, y: NSMinY(frame)))
            shakePath.addLine(to: CGPoint(x: NSMinX(frame) + frame.size.width * intensity, y: NSMinY(frame)))
        }

        shakePath.closeSubpath()
        shakeAnimation.path = shakePath
        shakeAnimation.duration = duration

        animations = [NSAnimatablePropertyKey("frameOrigin"): shakeAnimation]
        animator().setFrameOrigin(self.frame.origin)
    }
}

extension NSView {
    @inline(__always) func transition(_ duration: TimeInterval = 0.2) {
        layer?.add(fadeTransition(duration: duration), forKey: "transition")
    }

    func center(within rect: NSRect, horizontally: Bool = true, vertically: Bool = true) {
        setFrameOrigin(CGPoint(
            x: horizontally ? rect.midX - frame.width / 2 : frame.origin.x,
            y: vertically ? rect.midY - frame.height / 2 : frame.origin.y
        ))
    }

    func center(within view: NSView, horizontally: Bool = true, vertically: Bool = true) {
        center(within: view.visibleRect, horizontally: horizontally, vertically: vertically)
    }

    var bg: NSColor? {
        get {
            guard let layer = layer, let backgroundColor = layer.backgroundColor else { return nil }
            return NSColor(cgColor: backgroundColor)
        }
        set {
            wantsLayer = true
            layer?.backgroundColor = newValue?.cgColor
        }
    }

    var radius: NSNumber? {
        get {
            guard let layer = layer else { return nil }
            return NSNumber(value: Float(layer.cornerRadius))
        }
        set {
            wantsLayer = true
            layer?.cornerRadius = CGFloat(newValue?.floatValue ?? 0.0)
        }
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

extension Matrix {
    var elements: [Scalar] {
        Array(map { $0 }.joined())
    }
}

typealias NSBrightness = NSNumber
typealias NSContrast = NSNumber

typealias Brightness = UInt8
typealias Contrast = UInt8

typealias PreciseBrightness = Double
typealias PreciseContrast = Double

// MARK: - MonitorValue

enum MonitorValue {
    case nsBrightness(NSBrightness)
    case nsContrast(NSContrast)
    case brightness(Brightness)
    case contrast(Contrast)
    case preciseBrightness(PreciseBrightness)
    case preciseContrast(PreciseContrast)
}

extension URL {
    static func / (_ url: URL, _ component: String) -> URL {
        url.appendingPathComponent(component)
    }

    static func / (_ url: URL, _ component: ControlID) -> URL {
        url.appendingPathComponent(String(describing: component).lowercased())
    }

    static func / <T: BinaryInteger>(_ url: URL, _ component: T) -> URL {
        url.appendingPathComponent(String(component))
    }
}

func address(from bytes: UnsafeRawBufferPointer) -> String? {
    let sock = bytes.bindMemory(to: sockaddr.self)
    let sock_in = bytes.bindMemory(to: sockaddr_in.self)
    let sock_in6 = bytes.bindMemory(to: sockaddr_in6.self)

    guard let pointer = sock.baseAddress, let pointer_in = sock_in.baseAddress,
          let pointer_in6 = sock_in6.baseAddress else { return nil }
    switch Int32(pointer.pointee.sa_family) {
    case AF_INET:
        var addr = pointer_in.pointee.sin_addr
        let size = Int(INET_ADDRSTRLEN)
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: size)
        if let cString = inet_ntop(AF_INET, &addr, buffer, socklen_t(size)) {
            return String(cString: cString)
        } else {
            print("inet_ntop errno \(errno) from \(bytes)")
        }
        buffer.deallocate()
    case AF_INET6:
        var addr = pointer_in6.pointee.sin6_addr
        let size = Int(INET6_ADDRSTRLEN)
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: size)
        if let cString = inet_ntop(AF_INET6, &addr, buffer, socklen_t(size)) {
            return String(cString: cString)
        } else {
            print("inet_ntop errno \(errno) from \(bytes)")
        }
        buffer.deallocate()
    default:
        print("Unknown family \(pointer.pointee.sa_family)")
    }
    return nil
}

let brightnessDataPointInserted = NSNotification.Name("brightnessDataPointInserted")
let contrastDataPointInserted = NSNotification.Name("contrastDataPointInserted")
let currentDataPointChanged = NSNotification.Name("currentDataPointChanged")
let dataPointBoundsChanged = NSNotification.Name("dataPointBoundsChanged")
let lunarProStateChanged = NSNotification.Name("lunarProStateChanged")

func first<T>(this: T, other _: T) -> T {
    this
}

extension Dictionary {
    func with(_ dict: [Key: Value]) -> Self {
        merging(dict, uniquingKeysWith: first(this:other:))
    }
}

extension Int {
    var microseconds: DateComponents {
        (self * 1000).nanoseconds
    }

    var milliseconds: DateComponents {
        (self * 1_000_000).nanoseconds
    }
}

extension NSFont.Weight {
    var str: String {
        switch self {
        case .ultraLight:
            return "Ultralight"
        case .thin:
            return "Thin"
        case .light:
            return "Light"
        case .regular:
            return "Regular"
        case .medium:
            return "Medium"
        case .semibold:
            return "Semibold"
        case .bold:
            return "Bold"
        case .heavy:
            return "Heavy"
        case .black:
            return "Black"
        default:
            return ""
        }
    }
}

extension NSAttributedString {
    static func + (_ this: NSAttributedString, _ other: NSAttributedString) -> NSAttributedString {
        let m = (this.mutableCopy() as! NSMutableAttributedString)
        m.append(other)
        return m.copy() as! NSAttributedString
    }

    static func += (_ this: inout NSAttributedString, _ other: NSAttributedString) {
        let m = (this.mutableCopy() as! NSMutableAttributedString)
        m.append(other)
        this = m.copy() as! NSAttributedString
    }
}

let storeLock = NSRecursiveLock()

extension AnyCancellable {
    func store(
        in dictionary: inout [String: AnyCancellable],
        for key: String
    ) {
        storeLock.around {
            dictionary[key] = self
        }
    }
}

extension NSPopUpButton {
    /// Publishes index of selected Item
    var selectionPublisher: AnyPublisher<Int, Never> {
        NotificationCenter.default
            .publisher(for: NSMenu.didSendActionNotification, object: menu)
            .map { _ in self.indexOfSelectedItem }
            .eraseToAnyPublisher()
    }
}
