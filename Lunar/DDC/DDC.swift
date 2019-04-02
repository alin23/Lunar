//
//  DDC.swift
//  Lunar
//
//  Created by Alin on 02/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import CoreGraphics
import Foundation

let MAX_REQUESTS = 10

struct DDCReadResult {
    var controlID: ControlID
    var maxValue: UInt8
    var currentValue: UInt8
}

enum EDIDTextType: UInt8 {
    case name = 0xFC
    case serial = 0xFF
}

enum ControlID: UInt8 {
    case RESET = 0x04
    case RESET_BRIGHTNESS_AND_CONTRAST = 0x05
    case RESET_GEOMETRY = 0x06
    case RESET_COLOR = 0x08
    case BRIGHTNESS = 0x10
    case CONTRAST = 0x12
    case COLOR_PRESET_A = 0x14
    case RED_GAIN = 0x16
    case GREEN_GAIN = 0x18
    case BLUE_GAIN = 0x1A
    case AUTO_SIZE_CENTER = 0x1E
    case WIDTH = 0x22
    case HEIGHT = 0x32
    case VERTICAL_POS = 0x30
    case HORIZONTAL_POS = 0x20
    case PINCUSHION_AMP = 0x24
    case PINCUSHION_PHASE = 0x42
    case KEYSTONE_BALANCE = 0x40
    case PINCUSHION_BALANCE = 0x26
    case TOP_PINCUSHION_AMP = 0x46
    case TOP_PINCUSHION_BALANCE = 0x48
    case BOTTOM_PINCUSHION_AMP = 0x4A
    case BOTTOM_PINCUSHION_BALANCE = 0x4C
    case VERTICAL_LINEARITY = 0x3A
    case VERTICAL_LINEARITY_BALANCE = 0x3C
    case HORIZONTAL_STATIC_CONVERGENCE = 0x28
    case VERTICAL_STATIC_CONVERGENCE = 0x38
    case MOIRE_CANCEL = 0x56
    case INPUT_SOURCE = 0x60
    case AUDIO_SPEAKER_VOLUME = 0x62
    case RED_BLACK_LEVEL = 0x6C
    case GREEN_BLACK_LEVEL = 0x6E
    case BLUE_BLACK_LEVEL = 0x70
    case ORIENTATION = 0xAA
    case AUDIO_MUTE = 0x8D
    case SETTINGS = 0xB0
    case ON_SCREEN_DISPLAY = 0xCA
    case OSD_LANGUAGE = 0xCC
    case DPMS = 0xD6
    case COLOR_PRESET_B = 0xDC
    case VCP_VERSION = 0xDF
    case COLOR_PRESET_C = 0xE0
    case POWER_CONTROL = 0xE1
    case TOP_LEFT_SCREEN_PURITY = 0xE8
    case TOP_RIGHT_SCREEN_PURITY = 0xE9
    case BOTTOM_LEFT_SCREEN_PURITY = 0xEA
    case BOTTOM_RIGHT_SCREEN_PURITY = 0xEB
}

extension Array where Element == UInt8 {
    func str(hex: Bool = false) -> String {
        if !hex, !contains(where: { n in !(0x20 ... 0x7E).contains(n) }),
            let value = NSString(bytes: self, length: count, encoding: String.Encoding.nonLossyASCII.rawValue) as String? {
            return value
        } else {
            return map { n in String(format: "%02X", n) }.joined(separator: " ")
        }
    }
}

extension UInt32 {
    func toUInt8Array() -> [UInt8] {
        return [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 24) & 0xFF)]
    }

    func str() -> String {
        return toUInt8Array().str()
    }
}

extension UInt16 {
    func toUInt8Array() -> [UInt8] {
        return [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF)]
    }

    func str() -> String {
        return toUInt8Array().str()
    }
}

extension UInt8 {
    func str() -> String {
        if (0x20 ... 0x7E).contains(self), let value = NSString(bytes: [self], length: 1, encoding: String.Encoding.nonLossyASCII.rawValue) as String? {
            return value
        } else {
            return String(format: "%02X", self)
        }
    }
}

class DDC {
    static let requestDelay: useconds_t = 20000
    static let recoveryDelay: useconds_t = 40000
    static var displayQueues = [CGDirectDisplayID: DispatchSemaphore]()

    static func findExternalDisplays() -> [CGDirectDisplayID] {
        var displayIDs = [CGDirectDisplayID]()
        for screen in NSScreen.screens {
            if screen.deviceDescription[NSDeviceDescriptionKey.isScreen]! as! String == "YES" {
                let screenNumber = CGDirectDisplayID(truncating: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber)
                if CGDisplayIsBuiltin(screenNumber) == 1 {
                    continue
                }
                displayIDs.append(screenNumber)
            }
        }
        return displayIDs
    }

    static func getBuiltinDisplay() -> CGDirectDisplayID? {
        for screen in NSScreen.screens {
            if screen.deviceDescription[NSDeviceDescriptionKey.isScreen]! as! String == "YES" {
                let screenNumber = CGDirectDisplayID(truncating: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber)
                if CGDisplayIsBuiltin(screenNumber) == 1 {
                    return screenNumber
                }
            }
        }
        return nil
    }

    static func getFramebufferPort(displayID: CGDirectDisplayID) -> io_service_t? {
        let displayUnitNumber = CGDisplayUnitNumber(displayID)
        var servicePort: io_service_t = 0
        var i2cServicePorts = [UInt32: [io_service_t]]()
        var fbServicePorts = [UInt32: io_service_t]()
        let matching = IOServiceMatching("IOFramebufferI2CInterface")

        var serialPortIterator = io_iterator_t()
        defer { IOObjectRelease(serialPortIterator) }

        let kernResult = IOServiceGetMatchingServices(
            kIOMasterPortDefault,
            matching,
            &serialPortIterator
        )
        if KERN_SUCCESS != kernResult || serialPortIterator == 0 {
            return nil
        }

        var unitNumber: UInt32 = 0
        var fbPort: io_service_t = 0
        while true {
            servicePort = IOIteratorNext(serialPortIterator)
            if servicePort == 0 {
                break
            }

            if IORegistryEntryGetParentEntry(servicePort, kIOServicePlane, &fbPort) != KERN_SUCCESS {
                continue
            }

            if let oldFbPort = fbServicePorts[unitNumber], oldFbPort != fbPort {
                unitNumber += 1
            }
            if fbServicePorts[unitNumber] == nil {
                fbServicePorts[unitNumber] = fbPort
            }

            if var ports = i2cServicePorts[unitNumber] {
                ports.append(servicePort)
            } else {
                i2cServicePorts[unitNumber] = [servicePort]
            }
        }

        return fbServicePorts[displayUnitNumber]
    }

    static func getDisplayQueue(displayID: CGDirectDisplayID) -> DispatchSemaphore {
        if let queue = DDC.displayQueues[displayID] {
            return queue
        } else {
            let sem = DispatchSemaphore(value: 1)
            DDC.displayQueues[displayID] = sem
            return sem
        }
    }

    static func sendDisplayRequest(displayID: CGDirectDisplayID, request: inout IOI2CRequest) -> Bool {
        var result = false
        let queue = DDC.getDisplayQueue(displayID: displayID)

        queue.wait()
        defer { queue.signal() }

        guard let fbPort = DDC.getFramebufferPort(displayID: displayID) else {
            return false
        }
        defer { IOObjectRelease(fbPort) }

        var busCount: IOItemCount = 0
        IOFBGetI2CInterfaceCount(fbPort, &busCount)

        for bus in 0 ..< busCount {
            var interface: io_service_t = 0
            if IOFBCopyI2CInterfaceForBus(fbPort, bus, &interface) != KERN_SUCCESS {
                continue
            }
            defer { IOObjectRelease(interface) }

            var connect: IOI2CConnectRef? = OpaquePointer(bitPattern: 0)
            if IOI2CInterfaceOpen(interface, .zero, &connect) == KERN_SUCCESS, let connect = connect {
                if IOI2CSendRequest(connect, .zero, &request) == KERN_SUCCESS {
                    result = true
                }
            }

            if result {
                break
            }
        }

        if request.replyTransactionType == kIOI2CNoTransactionType {
            usleep(DDC.requestDelay)
        }
        return result && request.result == KERN_SUCCESS
    }

    static func write(displayID: CGDirectDisplayID, controlID: ControlID, newValue: UInt8) -> Bool {
        var request: IOI2CRequest = IOI2CRequest()
        var data = Data(count: 7)

        request.commFlags = 0
        request.sendAddress = 0x6E
        request.sendTransactionType = .init(bitPattern: Int32(kIOI2CSimpleTransactionType))
        request.sendBytes = 7

        data[0] = 0x51
        data[1] = 0x84
        data[2] = 0x03
        data[3] = controlID.rawValue
        data[4] = newValue >> 8
        data[5] = newValue & 255
        data[6] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5]

        request.replyTransactionType = .init(bitPattern: Int32(kIOI2CNoTransactionType))
        request.replyBytes = 0

        let nsData = NSMutableData(data: data)
        request.sendBuffer = vm_address_t(bitPattern: OpaquePointer(nsData.mutableBytes))

        return DDC.sendDisplayRequest(displayID: displayID, request: &request)
    }

    static func read(displayID: CGDirectDisplayID, controlID: ControlID) -> DDCReadResult? {
        var request: IOI2CRequest
        var result = false

        guard let transactionType = DDC.getSupportedTransactionType() else { return nil }

        for _ in 1 ... MAX_REQUESTS {
            request = IOI2CRequest()
            request.commFlags = 0
            request.sendAddress = 0x6E
            request.sendTransactionType = .init(bitPattern: Int32(kIOI2CSimpleTransactionType))

            request.sendBytes = 5
            request.minReplyDelay = UInt64(30 * kMillisecondScale)

            var data = Data(count: 5)
            data[0] = 0x51
            data[1] = 0x82
            data[2] = 0x01
            data[3] = controlID.rawValue
            data[4] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3]

            let nsData = NSMutableData(data: data)
            request.sendBuffer = vm_address_t(bitPattern: OpaquePointer(nsData.mutableBytes))

            request.replyTransactionType = transactionType
            request.replyAddress = 0x6F
            request.replySubAddress = 0x51

            guard let nsReplyData = NSMutableData(length: 8) else { return nil }
            request.replyBuffer = vm_address_t(bitPattern: OpaquePointer(nsReplyData.mutableBytes))
            request.replyBytes = 8

            result = sendDisplayRequest(displayID: displayID, request: &request)
            result = (
                result &&
                    nsReplyData[0] == request.sendAddress &&
                    nsReplyData[2] == 0x2 &&
                    nsReplyData[4] == controlID.rawValue
            )
            if result {
                var checksum = UInt8(request.replyAddress & 0xFF) ^ request.replySubAddress
                checksum ^= nsReplyData[1] ^ nsReplyData[2] ^ nsReplyData[3]
                checksum ^= nsReplyData[4] ^ nsReplyData[5] ^ nsReplyData[6]
                checksum ^= nsReplyData[7] ^ nsReplyData[8] ^ nsReplyData[9]
                result = nsReplyData[10] == checksum
            }

            if result {
                return DDCReadResult(
                    controlID: controlID,
                    maxValue: nsReplyData[7],
                    currentValue: nsReplyData[9]
                )
            }

            if request.result == kIOReturnUnsupportedMode {
                print("Unsupported transaction type: \(request.replyTransactionType)")
            }
            usleep(DDC.recoveryDelay)
        }

        return nil
    }

    static func getSupportedTransactionType() -> IOOptionBits? {
        var object: io_service_t = 0
        var supportedType: IOOptionBits?
        var serialPortIterator = io_iterator_t()
        defer { IOObjectRelease(serialPortIterator) }

        let kernResult = IOServiceGetMatchingServices(
            kIOMasterPortDefault,
            IOServiceNameMatching("IOFramebufferI2CInterface"),
            &serialPortIterator
        )
        if KERN_SUCCESS != kernResult || serialPortIterator == 0 {
            print("No matching service!")
            return nil
        }
        repeat {
            object = IOIteratorNext(serialPortIterator)

            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(object, &props, kCFAllocatorDefault, .zero) != KERN_SUCCESS {
                continue
            }
            guard let propDict = props?.takeRetainedValue(),
                let properties = propDict as NSDictionary as? [String: AnyObject],
                let typesObject = properties[kIOI2CTransactionTypesKey] as? Int32 else {
                continue
            }
            let types = UInt64(typesObject)
            if (1 << kIOI2CNoTransactionType & types) != 0 {
                print("IOI2CNoTransactionType supported")
                supportedType = IOOptionBits(bitPattern: Int32(kIOI2CNoTransactionType))
            } else {
                print("IOI2CNoTransactionType not supported")
            }

            if (1 << kIOI2CSimpleTransactionType & types) != 0 {
                print("IOI2CSimpleTransactionType supported")
                supportedType = IOOptionBits(bitPattern: Int32(kIOI2CSimpleTransactionType))
            } else {
                print("IOI2CSimpleTransactionType not supported")
            }

            if (1 << kIOI2CDDCciReplyTransactionType & types) != 0 {
                print("IOI2CDDCciReplyTransactionType supported")
                supportedType = IOOptionBits(bitPattern: Int32(kIOI2CDDCciReplyTransactionType))
            } else {
                print("IOI2CDDCciReplyTransactionType not supported")
            }

            if let type = supportedType {
                return type
            }
        } while object != 0

        return nil
    }

    static func sendEdidRequest(displayID: CGDirectDisplayID) -> (EDID, Data)? {
        var request = IOI2CRequest()
        request.sendAddress = 0xA0
        request.sendTransactionType = .init(bitPattern: Int32(kIOI2CSimpleTransactionType))

        request.sendBytes = 0x01
        request.replyAddress = 0xA1
        request.replyTransactionType = .init(bitPattern: Int32(kIOI2CSimpleTransactionType))

        guard let nsData = NSMutableData(length: 128) else { return nil }
        let p = OpaquePointer(nsData.mutableBytes)
        request.sendBuffer = vm_address_t(bitPattern: p)
        request.replyBuffer = vm_address_t(bitPattern: p)
        request.replyBytes = 128

        if !DDC.sendDisplayRequest(displayID: displayID, request: &request) {
            return nil
        }

        var edid = EDID()
        nsData.getBytes(&edid, length: 128)

        return (edid, nsData as Data)
    }

    static func getEdid(displayID: CGDirectDisplayID) -> EDID? {
        guard let (edid, _) = DDC.sendEdidRequest(displayID: displayID) else {
            return nil
        }
        return edid
    }

    static func getEdidData(displayID: CGDirectDisplayID) -> Data? {
        guard let (_, data) = DDC.sendEdidRequest(displayID: displayID) else {
            return nil
        }
        return data
    }

    static func getEdidData() -> [Data] {
        var result = [Data]()
        var object: io_object_t
        var serialPortIterator = io_iterator_t()
        let matching = IOServiceMatching("IODisplayConnect")

        let kernResult = IOServiceGetMatchingServices(
            kIOMasterPortDefault,
            matching,
            &serialPortIterator
        )
        if KERN_SUCCESS == kernResult, serialPortIterator != 0 {
            repeat {
                object = IOIteratorNext(serialPortIterator)
                let infoDict = IODisplayCreateInfoDictionary(
                    object, UInt32(kIODisplayOnlyPreferredName)
                ).takeRetainedValue()
                let info = infoDict as NSDictionary as? [String: AnyObject]

                if let info = info, let displayEDID = info["IODisplayEDID"] as? Data {
                    result.append(displayEDID)
                }

            } while object != 0
        }
        IOObjectRelease(serialPortIterator)

        return result
    }

    static func printTextDescriptors(displayID: CGDirectDisplayID) {
        for str in DDC.getTextDescriptors(displayID: displayID) {
            print(str)
        }
    }

    static func getDisplayIdentificationData(displayID: CGDirectDisplayID) -> String {
        guard let edid = DDC.getEdid(displayID: displayID) else {
            return ""
        }
        return "\(edid.eisaid.str())-\(edid.productcode.str())-\(edid.serial.str()) \(edid.week.str())/\(edid.year.str()) \(edid.versionmajor.str()).\(edid.versionminor.str())"
    }

    static func getTextDescriptors(displayID: CGDirectDisplayID) -> [String] {
        guard let edid = DDC.getEdid(displayID: displayID) else {
            return []
        }
        var descriptorStrings: [String] = []
        var tmp = edid.descriptors
        let descriptors = [descriptor](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))

        for descriptor in descriptors {
            let type = descriptor.text.type
            var tmp = descriptor.text.data
            let chars = [Int8](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))
            if type == EDIDTextType.name.rawValue, let data = NSString(
                bytes: chars, length: 13, encoding: String.Encoding.nonLossyASCII.rawValue
            ) as String? {
                descriptorStrings.append("\(type) : \(data)")
            } else {
                let hexData = chars.map { String(format: "%02X", $0) }.joined(separator: " ")
                descriptorStrings.append("\(type) : \(hexData)")
            }
        }
        return descriptorStrings
    }

    static func getEdidTextData(displayID: CGDirectDisplayID) -> String {
        return DDC.getTextDescriptors(displayID: displayID).joined(separator: "-")
    }

    static func extractName(from edid: EDID, hex: Bool = false) -> String? {
        var tmp = edid.descriptors
        let descriptors = [descriptor](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))

        if let nameDescriptor = descriptors.first(where: { des in
            des.text.type == EDIDTextType.name.rawValue
        }) {
            var tmp = nameDescriptor.text.data
            let nameChars = [Int8](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))
            if let name = NSString(bytes: nameChars, length: 13, encoding: String.Encoding.nonLossyASCII.rawValue) as String? {
                return name.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if hex {
                let hexData = nameChars.map { String(format: "%02X", $0) }.joined(separator: " ")
                return hexData.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    static func extractSerialNumber(from edid: EDID, hex: Bool = false) -> String? {
        var tmp = edid.descriptors
        let descriptors = [descriptor](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))

        if let serialDescriptor = descriptors.first(where: { des in
            des.text.type == EDIDTextType.serial.rawValue
        }) {
            var tmp = serialDescriptor.text.data
            let serialChars = [Int8](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))
            if let serial = NSString(bytes: serialChars, length: 13, encoding: String.Encoding.nonLossyASCII.rawValue) as String? {
                return serial.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if hex {
                let hexData = serialChars.map { String(format: "%02X", $0) }.joined(separator: " ")
                return hexData.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    static func getDisplayName(for displayID: CGDirectDisplayID) -> String? {
        guard let edid = DDC.getEdid(displayID: displayID) else {
            return nil
        }
        return extractName(from: edid)
    }

    static func getDisplaySerial(for displayID: CGDirectDisplayID) -> String? {
        guard let edid = DDC.getEdid(displayID: displayID) else {
            return nil
        }

        let serialNumber = extractSerialNumber(from: edid) ?? "NO_SERIAL"
        let name = extractName(from: edid) ?? "NO_NAME"
        return "\(name)-\(serialNumber)-\(edid.serial)-\(edid.productcode)-\(edid.year)-\(edid.week)"
    }

    static func getDisplaySerialAndName(for displayID: CGDirectDisplayID) -> (String?, String?) {
        guard let edid = DDC.getEdid(displayID: displayID) else {
            return (nil, nil)
        }

        let serialNumber = extractSerialNumber(from: edid) ?? "NO_SERIAL"
        let name = extractName(from: edid) ?? "NO_NAME"
        return ("\(name)-\(serialNumber)-\(edid.serial)-\(edid.productcode)-\(edid.year)-\(edid.week)", name)
    }

    static func setBrightness(for displayID: CGDirectDisplayID, brightness: UInt8) -> Bool {
        return write(displayID: displayID, controlID: ControlID.BRIGHTNESS, newValue: brightness)
    }

    static func readBrightness(for displayID: CGDirectDisplayID) -> DDCReadResult? {
        return read(displayID: displayID, controlID: ControlID.BRIGHTNESS)
    }

    static func readContrast(for displayID: CGDirectDisplayID) -> DDCReadResult? {
        return read(displayID: displayID, controlID: ControlID.CONTRAST)
    }

    static func setContrast(for displayID: CGDirectDisplayID, contrast: UInt8) -> Bool {
        return write(displayID: displayID, controlID: ControlID.CONTRAST, newValue: contrast)
    }

    static func reset(displayID: CGDirectDisplayID) -> Bool {
        return write(displayID: displayID, controlID: ControlID.RESET, newValue: 100)
    }

    static func getBrightness(for _: CGDirectDisplayID) -> Double {
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"))
        var brightness: Float = 0.0
        IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &brightness)
        IOObjectRelease(service)
        return Double(brightness)
    }
}
