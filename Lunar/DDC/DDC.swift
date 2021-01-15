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

let DDC_MIN_REPLY_DELAY_AMD = 30_000_000
let DDC_MIN_REPLY_DELAY_INTEL = 1
let DDC_MIN_REPLY_DELAY_NVIDIA = 1

struct DDCReadResult {
    var controlID: ControlID
    var maxValue: UInt8
    var currentValue: UInt8
}

enum EDIDTextType: UInt8 {
    case name = 0xFC
    case serial = 0xFF
}

enum InputSource: UInt8, CaseIterable {
    case vga1 = 1
    case vga2 = 2
    case dvi1 = 3
    case dvi2 = 4
    case compositeVideo1 = 5
    case compositeVideo2 = 6
    case sVideo1 = 7
    case sVideo2 = 8
    case tuner1 = 9
    case tuner2 = 10
    case tuner3 = 11
    case componentVideoYPrPbYCrCb1 = 12
    case componentVideoYPrPbYCrCb2 = 13
    case componentVideoYPrPbYCrCb3 = 14
    case displayPort1 = 15
    case displayPort2 = 16
    case hdmi1 = 17
    case hdmi2 = 18
    case usbC = 27
    case unknown = 246

    func displayName() -> String {
        switch self {
        case .vga1: return "VGA 1"
        case .vga2: return "VGA 2"
        case .dvi1: return "DVI 1"
        case .dvi2: return "DVI 2"
        case .compositeVideo1: return "Composite video 1"
        case .compositeVideo2: return "Composite video 2"
        case .sVideo1: return "S-Video 1"
        case .sVideo2: return "S-Video 2"
        case .tuner1: return "Tuner 1"
        case .tuner2: return "Tuner 2"
        case .tuner3: return "Tuner 3"
        case .componentVideoYPrPbYCrCb1: return "Component video (YPrPb/YCrCb) 1"
        case .componentVideoYPrPbYCrCb2: return "Component video (YPrPb/YCrCb) 2"
        case .componentVideoYPrPbYCrCb3: return "Component video (YPrPb/YCrCb) 3"
        case .displayPort1: return "DisplayPort 1"
        case .displayPort2: return "DisplayPort 2"
        case .hdmi1: return "HDMI 1"
        case .hdmi2: return "HDMI 2"
        case .usbC: return "USB-C"
        case .unknown: return "Unknown"
        }
    }
}

let inputSourceMapping: [String: InputSource] = Dictionary(uniqueKeysWithValues: InputSource.allCases.map { input in
    (input.displayName(), input)
})

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

enum DDC {
    static let queue = DispatchQueue(label: "DDC", qos: .userInteractive, autoreleaseFrequency: .workItem)
    static var apply = true
    static let requestDelay: useconds_t = 20000
    static let recoveryDelay: useconds_t = 40000
    static var displayPortByUUID = [CFUUID: io_service_t]()
    static var displayUUIDByEDID = [Data: CFUUID]()
    static var skipReadingPropertyById = [CGDirectDisplayID: Set<ControlID>]()
    static var skipWritingPropertyById = [CGDirectDisplayID: Set<ControlID>]()
    static var readFaults = [CGDirectDisplayID: [ControlID: Int]]()
    static var writeFaults = [CGDirectDisplayID: [ControlID: Int]]()
    static let semaphore = DispatchSemaphore(value: 1)

    static func reset() {
        _ = semaphore.wait(timeout: .now() + .seconds(10))
        defer {
            semaphore.signal()
        }

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
            if let isScreen = screen.deviceDescription[NSDeviceDescriptionKey.isScreen], let isScreenStr = isScreen as? String,
               isScreenStr == "YES"
            {
                if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                    let screenID = CGDirectDisplayID(truncating: screenNumber)
                    if SyncMode.isBuiltinDisplay(screenID) {
                        continue
                    }
                    displayIDs.append(screenID)
                }
            }
        }
        return displayIDs
    }

    static func write(displayID: CGDirectDisplayID, controlID: ControlID, newValue: UInt8) -> Bool {
        guard apply else { return true }

        return queue.sync {
            _ = semaphore.wait(timeout: .now() + .seconds(10))
            defer {
                semaphore.signal()
            }

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
        if controlID == ControlID.BRIGHTNESS || controlID == ControlID.CONTRAST {
            runInMainThread {
                displayController.displays[displayID]?.responsive = false
            }
        }
    }

    static func read(displayID: CGDirectDisplayID, controlID: ControlID) -> DDCReadResult? {
        _ = semaphore.wait(timeout: .now() + .seconds(10))
        defer {
            semaphore.signal()
        }

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

        let metalDevice = CGDirectDisplayCopyCurrentMetalDevice(displayID)
        var ddcDelay = DDC_MIN_REPLY_DELAY_INTEL
        if let gpu = metalDevice {
            if gpu.name.lowercased().contains("amd") {
                ddcDelay = DDC_MIN_REPLY_DELAY_AMD
            } else if gpu.name.lowercased().contains("nvidia") {
                ddcDelay = DDC_MIN_REPLY_DELAY_NVIDIA
            }
        }

        let readStartedAt = DispatchTime.now()
        DDCRead(displayID, &command, nsDisplayUUIDByEDID as CFMutableDictionary, ddcDelay)
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
        _ = semaphore.wait(timeout: .now() + .seconds(10))
        defer {
            semaphore.signal()
        }

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

    static func getDisplayIdentificationData(displayID: CGDirectDisplayID) -> String {
        guard let edid = DDC.getEdid(displayID: displayID) else {
            return ""
        }
        return "\(edid.eisaid.str())-\(edid.productcode.str())-\(edid.serial.str()) \(edid.week.str())/\(edid.year.str()) \(edid.versionmajor.str()).\(edid.versionminor.str())"
    }

    static func getTextData(_ descriptor: descriptor, hex: Bool = false) -> String? {
        let tmp = descriptor.text.data
        let nameChars = [
            tmp.0, tmp.1, tmp.2, tmp.3,
            tmp.4, tmp.5, tmp.6, tmp.7,
            tmp.8, tmp.9, tmp.10, tmp.11,
            tmp.12,
        ]
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

    static func setInput(for displayID: CGDirectDisplayID, input: InputSource) -> Bool {
        if input == .unknown {
            return false
        }
        return write(displayID: displayID, controlID: ControlID.INPUT_SOURCE, newValue: input.rawValue)
    }

    static func readInput(for displayID: CGDirectDisplayID) -> DDCReadResult? {
        return read(displayID: displayID, controlID: ControlID.INPUT_SOURCE)
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
        log.debug("DDC reading \(controlID) for \(displayID)")

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
        return DDC.getValue(for: displayID, controlID: ControlID.CONTRAST)
    }

    static func getInput(for displayID: CGDirectDisplayID) -> UInt8? {
        return DDC.readInput(for: displayID)?.currentValue
    }

    static func getBrightness(for id: CGDirectDisplayID) -> Double? {
        log.debug("DDC reading brightness for \(id)")
        return DDC.getValue(for: id, controlID: ControlID.BRIGHTNESS)
    }
}
