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

struct DDCReadResult {
    var controlID: UInt8
    var maxValue: UInt8
    var currentValue: UInt8
}

enum EDIDTextType: UInt8 {
    case name = 0xFC
    case serial = 0xFF
}

extension Array where Element == UInt8 {
    func str(length: Int) -> String {
        if !contains(where: { n in !(0x20 ... 0x7F).contains(n) }), let value = NSString(bytes: self, length: length, encoding: String.Encoding.nonLossyASCII.rawValue) as String? {
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
        return toUInt8Array().str(length: 4)
    }
}

extension UInt16 {
    func toUInt8Array() -> [UInt8] {
        return [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF)]
    }

    func str() -> String {
        return toUInt8Array().str(length: 2)
    }
}

extension UInt8 {
    func str() -> String {
        if (0x20 ... 0x7F).contains(self), let value = NSString(bytes: [self], length: 1, encoding: String.Encoding.nonLossyASCII.rawValue) as String? {
            return value
        } else {
            return String(format: "%02X", self)
        }
    }
}

class DDC {
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

    static func write(displayID: CGDirectDisplayID, controlID: UInt8, newValue: UInt8) -> Bool {
        var command = DDCWriteCommand(
            control_id: controlID,
            new_value: newValue
        )

        let result = DDCWrite(displayID, &command)
//        print("Command \(String(command.new_value)): \(String(result))")

        return result
    }

    static func read(displayID: CGDirectDisplayID, controlID: UInt8) -> DDCReadResult {
        var command = DDCReadCommand(
            control_id: controlID,
            success: false,
            max_value: 0,
            current_value: 0
        )
        DDCRead(displayID, &command)
//        print("Current Value: \(String(command.current_value))")
        return DDCReadResult(
            controlID: controlID,
            maxValue: command.max_value,
            currentValue: command.current_value
        )
    }

    static func getEdidData(displayID: CGDirectDisplayID) -> Data? {
        var result: Data?
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
                let info = IODisplayCreateInfoDictionary(
                    object, UInt32(kIODisplayOnlyPreferredName)
                ).takeRetainedValue() as NSDictionary as? [String: AnyObject]

                guard let data = info, let displayEDID = data["IODisplayEDID"] as? Data else {
                    continue
                }

                let vendorID = UInt32(truncating: (data["DisplayVendorID"] as? NSNumber) ?? 0)
                let productID = UInt32(truncating: (data["DisplayProductID"] as? NSNumber) ?? 0)
                let serialNumber = UInt32(truncating: (data["DisplaySerialNumber"] as? NSNumber) ?? 0)

                if CGDisplayVendorNumber(displayID) == vendorID,
                    CGDisplayModelNumber(displayID) == productID,
                    CGDisplaySerialNumber(displayID) == serialNumber {
                    result = displayEDID
                    break
                }

            } while object != 0
        }
        IOObjectRelease(serialPortIterator)

        return result
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
                let info = IODisplayCreateInfoDictionary(
                    object, UInt32(kIODisplayOnlyPreferredName)
                ).takeRetainedValue() as NSDictionary as? [String: AnyObject]

                if let info = info, let displayEDID = info["IODisplayEDID"] as? Data {
                    result.append(displayEDID)
                }

            } while object != 0
        }
        IOObjectRelease(serialPortIterator)

        return result
    }

    static func test(displayID: CGDirectDisplayID) throws -> (Bool, EDID) {
        var edid = EDID()
        let result = EDIDTest(displayID, &edid)
//        print("EDID Test for Display \(String(displayID)) - \(String(result))")
        return (result, edid)
    }

    static func printTextDescriptors(displayID: CGDirectDisplayID) {
        for str in DDC.getTextDescriptors(displayID: displayID) {
            print(str)
        }
    }

    static func getDisplayIdentificationData(displayID: CGDirectDisplayID) -> String {
        guard let (_, edid) = try? test(displayID: displayID) else {
            return ""
        }
        return "\(edid.eisaid.str())-\(edid.productcode.str())-\(edid.serial.str()) \(edid.week.str())/\(edid.year.str()) \(edid.versionmajor.str()).\(edid.versionminor.str())"
    }

    static func getTextDescriptors(displayID: CGDirectDisplayID) -> [String] {
        guard let (_, edid) = try? test(displayID: displayID) else {
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

    static func extractName(from edid: EDID) -> String {
        var tmp = edid.descriptors
        let descriptors = [descriptor](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))

        if let nameDescriptor = descriptors.first(where: { des in
            des.text.type == EDIDTextType.name.rawValue
        }) {
            var tmp = nameDescriptor.text.data
            let nameChars = [Int8](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))
            if let name = NSString(bytes: nameChars, length: 13, encoding: String.Encoding.nonLossyASCII.rawValue) as String? {
//                print("Descriptor: \(name)")
                return name.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                let hexData = nameChars.map { String(format: "%02X", $0) }.joined(separator: " ")
                return hexData.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    static func extractSerialNumber(from edid: EDID) -> String {
        var tmp = edid.descriptors
        let descriptors = [descriptor](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))

        if let serialDescriptor = descriptors.first(where: { des in
            des.text.type == EDIDTextType.serial.rawValue
        }) {
            var tmp = serialDescriptor.text.data
            let serialChars = [Int8](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))
            if let serial = NSString(bytes: serialChars, length: 13, encoding: String.Encoding.nonLossyASCII.rawValue) as String? {
//                print("Descriptor: \(serial)")
                return serial.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                let hexData = serialChars.map { String(format: "%02X", $0) }.joined(separator: " ")
                return hexData.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    static func getDisplayName(for displayID: CGDirectDisplayID) -> String {
        guard let (_, edid) = try? test(displayID: displayID) else {
            return ""
        }
        return extractName(from: edid)
    }

    static func getDisplaySerial(for displayID: CGDirectDisplayID) -> String {
        guard let (_, edid) = try? test(displayID: displayID) else {
            return ""
        }

        let serialNumber = extractSerialNumber(from: edid)
        let name = extractName(from: edid)
        return "\(name)-\(serialNumber)-\(edid.serial)-\(edid.productcode)-\(edid.year)-\(edid.week)"
    }

    static func getDisplaySerialAndName(for displayID: CGDirectDisplayID) -> (String, String) {
        guard let (_, edid) = try? test(displayID: displayID) else {
            return ("", "")
        }

        let serialNumber = extractSerialNumber(from: edid)
        let name = extractName(from: edid)
        return ("\(name)-\(serialNumber)-\(edid.serial)-\(edid.productcode)-\(edid.year)-\(edid.week)", name)
    }

    static func setBrightness(for displayID: CGDirectDisplayID, brightness: UInt8) -> Bool {
        return write(displayID: displayID, controlID: UInt8(BRIGHTNESS), newValue: brightness)
    }

    static func readBrightness(for displayID: CGDirectDisplayID) -> DDCReadResult {
        return read(displayID: displayID, controlID: UInt8(BRIGHTNESS))
    }

    static func readContrast(for displayID: CGDirectDisplayID) -> DDCReadResult {
        return read(displayID: displayID, controlID: UInt8(CONTRAST))
    }

    static func setContrast(for displayID: CGDirectDisplayID, contrast: UInt8) -> Bool {
        return write(displayID: displayID, controlID: UInt8(CONTRAST), newValue: contrast)
    }

    static func reset(displayID: CGDirectDisplayID) -> Bool {
        return write(displayID: displayID, controlID: UInt8(RESET), newValue: 100)
    }

    static func getBrightness(for _: CGDirectDisplayID) -> Double {
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"))
        var brightness: Float = 0.0
        IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &brightness)
        IOObjectRelease(service)
        return Double(brightness)
    }
}
