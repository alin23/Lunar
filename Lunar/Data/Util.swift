import Cocoa
import CryptorECC
import Foundation

let publicKey =
    """
    -----BEGIN PUBLIC KEY-----
    MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEKGs3ARma5DHHnBb/vvTQmRV6sS3Y
    KtuJCVywyiA6TqoFEuQWDVmVwScqPbm5zmdRIUK31iZvxGjFjggMutstEA==
    -----END PUBLIC KEY-----
    """

func appDelegate() -> AppDelegate {
    return NSApplication.shared.delegate as! AppDelegate
}

@available(OSX 10.13, *)
func encrypt(message: Data) -> Data? {
    do {
        let eccPublicKey = try ECPublicKey(key: publicKey)
        let encrypted = try message.encrypt(with: eccPublicKey)

        return encrypted
    } catch {
        log.error("Error when encrypting message: \(error)")
        return nil
    }
}

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

    if let serialNumberProp = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0) {
        guard let serialNumber = (serialNumberProp.takeRetainedValue() as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) else {
            serialNumberProp.release()
            return nil
        }

        IOObjectRelease(platformExpert)
        guard let serialNumberData = serialNumber.data(using: .utf8, allowLossyConversion: true) else {
//            serialNumberProp.release()
            return nil
        }
//        serialNumberProp.release()
        return sha256(data: serialNumberData).str(hex: true, separator: "")
    }
    return nil
}

func runInMainThread(_ action: () -> Void) {
    if Thread.isMainThread {
        action()
    } else {
        DispatchQueue.main.sync {
            action()
        }
    }
}

func runInMainThreadAsyncAfter(ms: Int, _ action: @escaping () -> Void) {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    DispatchQueue.main.asyncAfter(deadline: deadline) {
        action()
    }
}

func runInMainThreadAsyncAfter(ms: Int, _ action: DispatchWorkItem) {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    DispatchQueue.main.asyncAfter(deadline: deadline, execute: action)
}

func getScreenWithMouse() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    let screens = NSScreen.screens
    let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })

    return screenWithMouse
}

func mapNumber<T: Numeric & Comparable & FloatingPoint>(_ number: T, fromLow: T, fromHigh: T, toLow: T, toHigh: T) -> T {
    if number == fromHigh {
        return toHigh
    } else if toLow < toHigh {
        let diff = (toHigh - toLow + 1)
        let fromDiff = (fromHigh - fromLow)
        return (number - fromLow) * diff / fromDiff + toLow
    } else {
        let diff = (toHigh - toLow - 1)
        let fromDiff = (fromHigh - fromLow)
        return (number - fromLow) * diff / fromDiff + toLow
    }
}
