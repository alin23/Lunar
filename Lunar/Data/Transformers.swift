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

extension NSValueTransformerName {
    static let appExceptionTransformerName = NSValueTransformerName(rawValue: "AppExceptionTransformer")
    static let displayTransformerName = NSValueTransformerName(rawValue: "DisplayTransformer")
}
