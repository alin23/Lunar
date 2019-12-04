import Foundation

class AppExceptionTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return AppException.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let config = value as? [String: Any] else { return nil }
        return AppException.fromDictionary(config)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        return (value as? AppException)?.dictionaryRepresentation()
    }
}

class DisplayTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return Display.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let config = value as? [String: Any] else { return nil }
        return Display.fromDictionary(config)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        return (value as? Display)?.dictionaryRepresentation()
    }
}

extension NSValueTransformerName {
    static let appExceptionTransformerName = NSValueTransformerName(rawValue: "AppExceptionTransformer")
    static let displayTransformerName = NSValueTransformerName(rawValue: "DisplayTransformer")
}
