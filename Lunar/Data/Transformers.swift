import Cocoa
import Defaults
import Foundation

// MARK: - UpdateCheckIntervalTransformer

class UpdateCheckIntervalTransformer: ValueTransformer {
    static let WEEKLY = 604_800
    static let DAILY = 86400
    static let HOURLY = 3600

    override class func transformedValueClass() -> AnyClass {
        NSNumber.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let segmentIndex = value as? Int, segmentIndex == 0 || segmentIndex == 1 || segmentIndex == 2 else { return Self.DAILY }
        switch segmentIndex {
        case 0: return Self.HOURLY.ns
        case 1: return Self.DAILY.ns
        case 2: return Self.WEEKLY.ns
        default: return Self.DAILY.ns
        }
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let checkInterval = value as? Int else { return 1 }
        switch checkInterval {
        case 0 ... Self.HOURLY: return 0
        case (Self.HOURLY + 1) ... Self.DAILY: return 1
        case (Self.DAILY + 1) ... Self.WEEKLY: return 2
        default: return 2
        }
    }
}

// MARK: - IntBoolTransformer

class IntBoolTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        NSNumber.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let segmentIndex = value as? Int else { return false }

        return segmentIndex == 1
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let condition = value as? Bool else { return 0 }

        return condition ? 1 : 0
    }
}

// MARK: - ColorScheme

public enum ColorScheme: Int, DefaultsSerializable {
    case system
    case light
    case dark
}

// MARK: - ColorSchemeTransformer

class ColorSchemeTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        NSNumber.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let segmentIndex = value as? Int,
              segmentIndex == 0 || segmentIndex == 1 || segmentIndex == 2 else { return ColorScheme.system.rawValue }
        switch segmentIndex {
        case 0: return ColorScheme.system.rawValue
        case 1: return ColorScheme.light.rawValue
        case 2: return ColorScheme.dark.rawValue
        default: return ColorScheme.system.rawValue
        }
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let colorScheme = value as? Int else { return 0 }
        return colorScheme.ns
    }
}

// MARK: - SignedIntTransformer

class SignedIntTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        NSString.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let intValue = value as? Int else { return String(describing: value) }
        return "\(intValue > 0 ? "+" : "")\(intValue)"
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let value = value as? String else { return 0 }
        return value.i ?? 0
    }
}

// MARK: - StringNumberTransformer

class StringNumberTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        NSString.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let number = value as? NSNumber else { return String(describing: value) }
        return number.intValue.s
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let value = value as? String else { return 0 }
        return value.i?.ns ?? 0
    }
}

extension NSValueTransformerName {
    static let displayTransformerName = NSValueTransformerName(rawValue: "DisplayTransformer")
    static let updateCheckIntervalTransformerName = NSValueTransformerName(rawValue: "UpdateCheckIntervalTransformer")
    static let intBoolTransformerName = NSValueTransformerName(rawValue: "IntBoolTransformer")
    static let signedIntTransformerName = NSValueTransformerName(rawValue: "SignedIntTransformer")
    static let colorSchemeTransformerName = NSValueTransformerName(rawValue: "ColorSchemeTransformer")
    static let stringNumberTransformerName = NSValueTransformerName(rawValue: "StringNumberTransformer")
}
