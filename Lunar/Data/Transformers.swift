import Foundation

class AppExceptionTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        AppException.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let config = value as? [String: Any] else { return nil }
        return AppException.fromDictionary(config)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        (value as? AppException)?.dictionary
    }
}

class DisplayTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        Display.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let config = value as? [String: Any] else { return nil }
        return Display.fromDictionary(config)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        (value as? Display)?.dictionary
    }
}

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

extension NSValueTransformerName {
    static let appExceptionTransformerName = NSValueTransformerName(rawValue: "AppExceptionTransformer")
    static let displayTransformerName = NSValueTransformerName(rawValue: "DisplayTransformer")
    static let updateCheckIntervalTransformerName = NSValueTransformerName(rawValue: "UpdateCheckIntervalTransformer")
}
