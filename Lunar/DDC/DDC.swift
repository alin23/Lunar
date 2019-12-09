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
let MAX_READ_DURATION_MS = 1500
let MAX_WRITE_DURATION_MS = 2000
let MAX_READ_FAULTS = 10
let MAX_WRITE_FAULTS = 20

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

extension Data {
    func str(hex: Bool = false, separator: String = " ") -> String {
        return map { $0 }.str(hex: hex, separator: separator)
    }
}

extension Array where Element == UInt8 {
    func str(hex: Bool = false, separator: String = " ") -> String {
        if !hex, !contains(where: { n in !(0x20 ... 0x7E).contains(n) }),
            let value = NSString(bytes: self, length: count, encoding: String.Encoding.nonLossyASCII.rawValue) as String? {
            return value
        } else {
            return map { n in String(format: "%02X", n) }.joined(separator: separator)
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
    static var displayPortByUUID = [CFUUID: io_service_t]()
    static var displayUUIDByEDID = [Data: CFUUID]()
    static var skipReadingPropertyById = [CGDirectDisplayID: Set<ControlID>]()
    static var skipWritingPropertyById = [CGDirectDisplayID: Set<ControlID>]()
    static var readFaults = [CGDirectDisplayID: [ControlID: Int]]()
    static var writeFaults = [CGDirectDisplayID: [ControlID: Int]]()

    static func reset() {
        DDC.displayPortByUUID.removeAll()
        DDC.displayUUIDByEDID.removeAll()
        DDC.skipReadingPropertyById.removeAll()
        DDC.skipWritingPropertyById.removeAll()
        DDC.readFaults.removeAll()
        DDC.writeFaults.removeAll()
    }

    static func findExternalDisplays() -> [CGDirectDisplayID] {
        var displayIDs = [CGDirectDisplayID]()
        for screen in NSScreen.screens {
            if let isScreen = screen.deviceDescription[NSDeviceDescriptionKey.isScreen], let isScreenStr = isScreen as? String, isScreenStr == "YES" {
                if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                    let screenID = CGDirectDisplayID(truncating: screenNumber)
                    if BrightnessAdapter.isBuiltinDisplay(screenID) {
                        continue
                    }
                    displayIDs.append(screenID)
                }
            }
        }
        return displayIDs
    }

    static func getBuiltinDisplay() -> CGDirectDisplayID? {
        for screen in NSScreen.screens {
            if let isScreen = screen.deviceDescription[NSDeviceDescriptionKey.isScreen] as? String, isScreen == "YES",
                let nsScreenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                let screenNumber = CGDirectDisplayID(truncating: nsScreenNumber)
                if BrightnessAdapter.isBuiltinDisplay(screenNumber) {
                    return screenNumber
                }
            }
        }
        return nil
    }

    static func write(displayID: CGDirectDisplayID, controlID: ControlID, newValue: UInt8) -> Bool {
        if let propertiesToSkip = DDC.skipWritingPropertyById[displayID], propertiesToSkip.contains(controlID) {
            log.debug("Skipping write for \(controlID)", context: displayID)
            return false
        }

        var command = DDCWriteCommand(
            control_id: controlID.rawValue,
            new_value: newValue
        )
        let displayUUIDByEDIDCopy = displayUUIDByEDID
        let nsDisplayUUIDByEDID = NSMutableDictionary(dictionary: displayUUIDByEDIDCopy)

        let writeStartedAt = DispatchTime.now()
        let result = DDCWrite(displayID, &command, nsDisplayUUIDByEDID as CFMutableDictionary)
        let writeMs = (DispatchTime.now().rawValue - writeStartedAt.rawValue) / 1_000_000
        if writeMs > MAX_WRITE_DURATION_MS {
            log.debug("Writing \(controlID) took too long: \(writeMs)ms", context: displayID)
            DDC.skipWritingProperty(displayID: displayID, controlID: controlID)
        }

        displayUUIDByEDID.removeAll()
        for (key, value) in nsDisplayUUIDByEDID {
            if CFGetTypeID(key as CFTypeRef) == CFDataGetTypeID(), CFGetTypeID(value as CFTypeRef) == CFUUIDGetTypeID() {
                displayUUIDByEDID[key as! CFData as NSData as Data] = (value as! CFUUID)
            }
        }

        if !result {
            log.debug("Error writing \(controlID)", context: displayID)
            guard let propertyFaults = DDC.writeFaults[displayID] else {
                DDC.writeFaults[displayID] = [controlID: 1]
                return false
            }
            guard var faults = propertyFaults[controlID] else {
                DDC.writeFaults[displayID]![controlID] = 1
                return false
            }
            faults += 1
            DDC.writeFaults[displayID]![controlID] = faults

            if faults > MAX_WRITE_FAULTS {
                DDC.skipWritingProperty(displayID: displayID, controlID: controlID)
            }

            return false
        }

        return result
    }

    static func skipReadingProperty(displayID: CGDirectDisplayID, controlID: ControlID) {
        if var propertiesToSkip = DDC.skipReadingPropertyById[displayID] {
            propertiesToSkip.insert(controlID)
            DDC.skipReadingPropertyById[displayID] = propertiesToSkip
        } else {
            DDC.skipReadingPropertyById[displayID] = Set([controlID])
        }
    }

    static func skipWritingProperty(displayID: CGDirectDisplayID, controlID: ControlID) {
        if var propertiesToSkip = DDC.skipWritingPropertyById[displayID] {
            propertiesToSkip.insert(controlID)
            DDC.skipWritingPropertyById[displayID] = propertiesToSkip
        } else {
            DDC.skipWritingPropertyById[displayID] = Set([controlID])
        }
    }

    static func read(displayID: CGDirectDisplayID, controlID: ControlID) -> DDCReadResult? {
        if let propertiesToSkip = DDC.skipReadingPropertyById[displayID], propertiesToSkip.contains(controlID) {
            log.debug("Skipping read for \(controlID)", context: displayID)
            return nil
        }

        var command = DDCReadCommand(
            control_id: controlID.rawValue,
            success: false,
            max_value: 0,
            current_value: 0
        )
        let displayUUIDByEDIDCopy = displayUUIDByEDID
        let nsDisplayUUIDByEDID = NSMutableDictionary(dictionary: displayUUIDByEDIDCopy)

        let readStartedAt = DispatchTime.now()
        DDCRead(displayID, &command, nsDisplayUUIDByEDID as CFMutableDictionary)
        let readMs = (DispatchTime.now().rawValue - readStartedAt.rawValue) / 1_000_000
        if readMs > MAX_READ_DURATION_MS {
            log.debug("Reading \(controlID) took too long: \(readMs)ms", context: displayID)
            DDC.skipReadingProperty(displayID: displayID, controlID: controlID)
        }

        displayUUIDByEDID.removeAll()
        for (key, value) in nsDisplayUUIDByEDID {
            if CFGetTypeID(key as CFTypeRef) == CFDataGetTypeID(), CFGetTypeID(value as CFTypeRef) == CFUUIDGetTypeID() {
                displayUUIDByEDID[key as! CFData as NSData as Data] = (value as! CFUUID)
            }
        }

        if !command.success {
            log.debug("Error reading \(controlID)", context: displayID)
            guard let propertyFaults = DDC.readFaults[displayID] else {
                DDC.readFaults[displayID] = [controlID: 1]
                return nil
            }
            guard var faults = propertyFaults[controlID] else {
                DDC.readFaults[displayID]![controlID] = 1
                return nil
            }
            faults += 1
            DDC.readFaults[displayID]![controlID] = faults

            if faults > MAX_READ_FAULTS {
                DDC.skipReadingProperty(displayID: displayID, controlID: controlID)
            }

            return nil
        }

        return DDCReadResult(
            controlID: controlID,
            maxValue: command.max_value,
            currentValue: command.current_value
        )
    }

    static func sendEdidRequest(displayID: CGDirectDisplayID) -> (EDID, Data)? {
        var edidData = [UInt8](repeating: 0, count: 256)
        var edid = EDID()

        let displayUUIDByEDIDCopy = displayUUIDByEDID
        let nsDisplayUUIDByEDID = NSMutableDictionary(dictionary: displayUUIDByEDIDCopy)
        EDIDTest(displayID, &edid, &edidData, nsDisplayUUIDByEDID as CFMutableDictionary)
        displayUUIDByEDID.removeAll()
        for (key, value) in nsDisplayUUIDByEDID {
            if CFGetTypeID(key as CFTypeRef) == CFDataGetTypeID(), CFGetTypeID(value as CFTypeRef) == CFUUIDGetTypeID() {
                displayUUIDByEDID[key as! CFData as NSData as Data] = (value as! CFUUID)
            }
        }

        return (edid, Data(bytes: &edidData, count: 256))
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

                if let info = info, let displayEDID = info[kIODisplayEDIDKey] as? Data {
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

    static func getTextData(_ descriptor: descriptor, hex: Bool = false) -> String? {
        var tmp = descriptor.text.data
        let nameChars = [Int8](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))
        if let name = NSString(bytes: nameChars, length: 13, encoding: String.Encoding.nonLossyASCII.rawValue) as String? {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if hex {
            let hexData = nameChars.map { String(format: "%02X", $0) }.joined(separator: " ")
            return hexData.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    static func extractDescriptorText(from edid: EDID, desType: EDIDTextType, hex: Bool = false) -> String? {
        switch desType.rawValue {
        case edid.descriptors.0.text.type:
            return DDC.getTextData(edid.descriptors.0, hex: hex)
        case edid.descriptors.1.text.type:
            return DDC.getTextData(edid.descriptors.1, hex: hex)
        case edid.descriptors.2.text.type:
            return DDC.getTextData(edid.descriptors.2, hex: hex)
        case edid.descriptors.3.text.type:
            return DDC.getTextData(edid.descriptors.3, hex: hex)
        default:
            return nil
        }
    }

    static func extractName(from edid: EDID, hex: Bool = false) -> String? {
        return extractDescriptorText(from: edid, desType: EDIDTextType.name, hex: hex)
    }

    static func extractSerialNumber(from edid: EDID, hex: Bool = false) -> String? {
        return extractDescriptorText(from: edid, desType: EDIDTextType.serial, hex: hex)
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

    static func setRedGain(for displayID: CGDirectDisplayID, redGain: UInt8) -> Bool {
        return write(displayID: displayID, controlID: ControlID.RED_GAIN, newValue: redGain)
    }

    static func setGreenGain(for displayID: CGDirectDisplayID, greenGain: UInt8) -> Bool {
        return write(displayID: displayID, controlID: ControlID.GREEN_GAIN, newValue: greenGain)
    }

    static func setBlueGain(for displayID: CGDirectDisplayID, blueGain: UInt8) -> Bool {
        return write(displayID: displayID, controlID: ControlID.BLUE_GAIN, newValue: blueGain)
    }

    static func setAudioSpeakerVolume(for displayID: CGDirectDisplayID, audioSpeakerVolume: UInt8) -> Bool {
        return write(displayID: displayID, controlID: ControlID.AUDIO_SPEAKER_VOLUME, newValue: audioSpeakerVolume)
    }

    static func setAudioMuted(for displayID: CGDirectDisplayID, audioMuted: Bool) -> Bool {
        if audioMuted {
            return write(displayID: displayID, controlID: ControlID.AUDIO_MUTE, newValue: 1)
        } else {
            return write(displayID: displayID, controlID: ControlID.AUDIO_MUTE, newValue: 2)
        }
    }

    static func reset(displayID: CGDirectDisplayID) -> Bool {
        return write(displayID: displayID, controlID: ControlID.RESET, newValue: 100)
    }

    static func getValue(for displayID: CGDirectDisplayID, controlID: ControlID) -> Double? {
        guard let result = DDC.read(displayID: displayID, controlID: controlID) else {
            return nil
        }
        return Double(result.currentValue)
    }

    static func getMaxValue(for displayID: CGDirectDisplayID, controlID: ControlID) -> Double? {
        guard let result = DDC.read(displayID: displayID, controlID: controlID) else {
            return nil
        }
        return Double(result.maxValue)
    }

    static func getRedGain(for displayID: CGDirectDisplayID) -> Double? {
        return DDC.getValue(for: displayID, controlID: ControlID.RED_GAIN)
    }

    static func getGreenGain(for displayID: CGDirectDisplayID) -> Double? {
        return DDC.getValue(for: displayID, controlID: ControlID.GREEN_GAIN)
    }

    static func getBlueGain(for displayID: CGDirectDisplayID) -> Double? {
        return DDC.getValue(for: displayID, controlID: ControlID.BLUE_GAIN)
    }

    static func getAudioSpeakerVolume(for displayID: CGDirectDisplayID) -> Double? {
        return DDC.getValue(for: displayID, controlID: ControlID.AUDIO_SPEAKER_VOLUME)
    }

    static func isAudioMuted(for displayID: CGDirectDisplayID) -> Bool? {
        guard let mute = DDC.getValue(for: displayID, controlID: ControlID.AUDIO_MUTE) else {
            return nil
        }
        return mute == 1.0
    }

    static func getContrast(for displayID: CGDirectDisplayID) -> Double? {
        log.debug("DDC reading contrast for \(displayID)")
        return DDC.getValue(for: displayID, controlID: ControlID.CONTRAST)
    }

    static func getBrightness(for displayID: CGDirectDisplayID? = nil) -> Double? {
        if let id = displayID {
            log.debug("DDC reading brightness for \(id)")
            return DDC.getValue(for: id, controlID: ControlID.BRIGHTNESS)
        }
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"))
        var brightness: Float = 0.0
        IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &brightness)
        IOObjectRelease(service)
        return Double(brightness)
    }
}
