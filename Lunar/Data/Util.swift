import Foundation
// import ObjectivePGP
//
// func encrypt(message: Data) -> Data? {
//    let path = Bundle.main.bundlePath as NSString
//    var components = path.pathComponents
//    components.append("Contents")
//    components.append("Resources")
//    components.append("alin_public_key.asc")
//
//    let keyPath = NSString.path(withComponents: components)
//
//    do {
//        let keyring = ObjectivePGP.defaultKeyring
//        try keyring.import(keyIdentifier:"E3629673D6E15976", fromPath:keyPath)
////        let keys = try ObjectivePGP.readKeys(fromPath: newPath)
//        let encrypted = try ObjectivePGP.encrypt(message, addSignature: false, using: keyring.keys)
//
//        return encrypted
//    } catch {
//        log.error("Error when encrypting message: \(error)")
//        return nil
//    }
// }

func sha256(data: Data) -> Data {
    var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
        _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
    }
    return Data(hash)
}

func getSerialNumberHash() -> String? {
    let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))

    guard platformExpert > 0 else {
        return nil
    }

    guard let serialNumber = (IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) else {
        return nil
    }

    IOObjectRelease(platformExpert)

    guard let serialNumberData = serialNumber.data(using: .utf8, allowLossyConversion: true) else { return nil }
    return sha256(data: serialNumberData).str(hex: true, separator: "")
}
