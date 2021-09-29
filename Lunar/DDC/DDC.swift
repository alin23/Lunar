//
//  DDC.swift
//  Lunar
//
//  Created by Alin on 02/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import ArgumentParser
import Cocoa
import CoreGraphics
import Foundation
import Regex

let MAX_REQUESTS = 10
let MAX_READ_DURATION_MS = 1500
let MAX_WRITE_DURATION_MS = 2000
let MAX_READ_FAULTS = 10
let MAX_WRITE_FAULTS = 20

let DDC_MIN_REPLY_DELAY_AMD = 30_000_000
let DDC_MIN_REPLY_DELAY_INTEL = 1
let DDC_MIN_REPLY_DELAY_NVIDIA = 1

// MARK: - DDCReadResult

struct DDCReadResult {
    var controlID: ControlID
    var maxValue: UInt8
    var currentValue: UInt8
}

// MARK: - EDIDTextType

enum EDIDTextType: UInt8 {
    case name = 0xFC
    case serial = 0xFF
}

// MARK: - InputSource

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
    case thunderbolt1 = 25
    case thunderbolt2 = 27
    case unknown = 246

    // MARK: Lifecycle

    init?(stringValue: String) {
        switch #"[^\w\s]+"#.r!.replaceAll(in: stringValue.lowercased().stripped, with: "") {
        case "vga": self = .vga1
        case "vga1": self = .vga1
        case "vga2": self = .vga2
        case "dvi": self = .dvi1
        case "dvi1": self = .dvi1
        case "dvi2": self = .dvi2
        case "composite": self = .compositeVideo1
        case "compositevideo": self = .compositeVideo1
        case "compositevideo1": self = .compositeVideo1
        case "compositevideo2": self = .compositeVideo2
        case "svideo": self = .sVideo1
        case "svideo1": self = .sVideo1
        case "svideo2": self = .sVideo2
        case "tuner": self = .tuner1
        case "tuner1": self = .tuner1
        case "tuner2": self = .tuner2
        case "tuner3": self = .tuner3
        case "component": self = .componentVideoYPrPbYCrCb1
        case "componentvideo": self = .componentVideoYPrPbYCrCb1
        case "componentvideoyprpbycrcb": self = .componentVideoYPrPbYCrCb1
        case "componentvideoyprpbycrcb1": self = .componentVideoYPrPbYCrCb1
        case "componentvideoyprpbycrcb2": self = .componentVideoYPrPbYCrCb2
        case "componentvideoyprpbycrcb3": self = .componentVideoYPrPbYCrCb3
        case "dp": self = .displayPort1
        case "minidp": self = .displayPort1
        case "minidisplayport": self = .displayPort1
        case "displayport": self = .displayPort1
        case "displayport1": self = .displayPort1
        case "displayport2": self = .displayPort2
        case "hdmi": self = .hdmi1
        case "hdmi1": self = .hdmi1
        case "hdmi2": self = .hdmi2
        case "thunderbolt": self = .thunderbolt2
        case "thunderbolt1": self = .thunderbolt1
        case "thunderbolt2": self = .thunderbolt2
        case "thunderbolt3": self = .thunderbolt2
        case "usbc": self = .thunderbolt2
        case "unknown": self = .unknown
        default:
            return nil
        }
    }

    // MARK: Internal

    static var mostUsed: [InputSource] {
        [.thunderbolt1, .thunderbolt2, .displayPort1, .displayPort2, .hdmi1, .hdmi2]
    }

    static var leastUsed: [InputSource] {
        [
            .vga1,
            .vga2,
            .dvi1,
            .dvi2,
            .compositeVideo1,
            .compositeVideo2,
            .sVideo1,
            .sVideo2,
            .tuner1,
            .tuner2,
            .tuner3,
            .componentVideoYPrPbYCrCb1,
            .componentVideoYPrPbYCrCb2,
            .componentVideoYPrPbYCrCb3,
        ]
    }

    var str: String {
        displayName()
    }

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
        case .thunderbolt1: return "Thunderbolt (DDC 25)"
        case .thunderbolt2: return "Thunderbolt (DDC 27)"
        case .unknown: return "Unknown"
        }
    }
}

let inputSourceMapping: [String: InputSource] = Dictionary(uniqueKeysWithValues: InputSource.allCases.map { input in
    (input.displayName(), input)
})

// MARK: - ControlID

enum ControlID: UInt8, ExpressibleByArgument, CaseIterable {
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

    // MARK: Lifecycle

    init?(argument: String) {
        var arg = argument
        if arg.starts(with: "0x") {
            arg = String(arg.suffix(from: arg.index(arg.startIndex, offsetBy: 2)))
        }
        if arg.starts(with: "x") {
            arg = String(arg.suffix(from: arg.index(after: arg.startIndex)))
        }
        if arg.count <= 2 {
            guard let value = Int(arg, radix: 16),
                  let control = ControlID(rawValue: value.u8)
            else { return nil }
            self = control
        }

        switch arg.lowercased().stripped.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ") {
        case "reset": self = ControlID.RESET
        case "reset brightness and contrast": self = ControlID.RESET_BRIGHTNESS_AND_CONTRAST
        case "reset geometry": self = ControlID.RESET_GEOMETRY
        case "reset color": self = ControlID.RESET_COLOR
        case "brightness": self = ControlID.BRIGHTNESS
        case "contrast": self = ControlID.CONTRAST
        case "color preset a": self = ControlID.COLOR_PRESET_A
        case "red gain": self = ControlID.RED_GAIN
        case "green gain": self = ControlID.GREEN_GAIN
        case "blue gain": self = ControlID.BLUE_GAIN
        case "auto size center": self = ControlID.AUTO_SIZE_CENTER
        case "width": self = ControlID.WIDTH
        case "height": self = ControlID.HEIGHT
        case "vertical pos": self = ControlID.VERTICAL_POS
        case "horizontal pos": self = ControlID.HORIZONTAL_POS
        case "pincushion amp": self = ControlID.PINCUSHION_AMP
        case "pincushion phase": self = ControlID.PINCUSHION_PHASE
        case "keystone balance": self = ControlID.KEYSTONE_BALANCE
        case "pincushion balance": self = ControlID.PINCUSHION_BALANCE
        case "top pincushion amp": self = ControlID.TOP_PINCUSHION_AMP
        case "top pincushion balance": self = ControlID.TOP_PINCUSHION_BALANCE
        case "bottom pincushion amp": self = ControlID.BOTTOM_PINCUSHION_AMP
        case "bottom pincushion balance": self = ControlID.BOTTOM_PINCUSHION_BALANCE
        case "vertical linearity": self = ControlID.VERTICAL_LINEARITY
        case "vertical linearity balance": self = ControlID.VERTICAL_LINEARITY_BALANCE
        case "horizontal static convergence": self = ControlID.HORIZONTAL_STATIC_CONVERGENCE
        case "vertical static convergence": self = ControlID.VERTICAL_STATIC_CONVERGENCE
        case "moire cancel": self = ControlID.MOIRE_CANCEL
        case "input source": self = ControlID.INPUT_SOURCE
        case "audio speaker volume": self = ControlID.AUDIO_SPEAKER_VOLUME
        case "red black level": self = ControlID.RED_BLACK_LEVEL
        case "green black level": self = ControlID.GREEN_BLACK_LEVEL
        case "blue black level": self = ControlID.BLUE_BLACK_LEVEL
        case "orientation": self = ControlID.ORIENTATION
        case "audio mute": self = ControlID.AUDIO_MUTE
        case "settings": self = ControlID.SETTINGS
        case "on screen display": self = ControlID.ON_SCREEN_DISPLAY
        case "osd language": self = ControlID.OSD_LANGUAGE
        case "dpms": self = ControlID.DPMS
        case "color preset b": self = ControlID.COLOR_PRESET_B
        case "vcp version": self = ControlID.VCP_VERSION
        case "color preset c": self = ControlID.COLOR_PRESET_C
        case "power control": self = ControlID.POWER_CONTROL
        case "top left screen purity": self = ControlID.TOP_LEFT_SCREEN_PURITY
        case "top right screen purity": self = ControlID.TOP_RIGHT_SCREEN_PURITY
        case "bottom left screen purity": self = ControlID.BOTTOM_LEFT_SCREEN_PURITY
        case "bottom right screen purity": self = ControlID.BOTTOM_RIGHT_SCREEN_PURITY
        default:
            return nil
        }
    }
}

func IORegistryTreeChanged(_: UnsafeMutableRawPointer?, _: io_iterator_t) {
    DDC.sync(barrier: true) {
        #if arch(arm64)
            DDC.avServiceCache.removeAll()
            displayController.clcd2Mapping.removeAll()
        #else
            DDC.i2cControllerCache.removeAll()
        #endif

        displayController.activeDisplays.values.forEach { display in
            display.detectI2C()
            display.startI2CDetection()
        }
    }
}

// MARK: - DDC

enum DDC {
    static let queue = DispatchQueue(label: "DDC", qos: .userInteractive, autoreleaseFrequency: .workItem)
    @Atomic static var apply = true
    @Atomic static var applyLimits = true
    static let requestDelay: useconds_t = 20000
    static let recoveryDelay: useconds_t = 40000
    static var displayPortByUUID = [CFUUID: io_service_t]()
    static var displayUUIDByEDID = [Data: CFUUID]()
    static var skipReadingPropertyById = [CGDirectDisplayID: Set<ControlID>]()
    static var skipWritingPropertyById = [CGDirectDisplayID: Set<ControlID>]()
    static var readFaults: ThreadSafeDictionary<CGDirectDisplayID, ThreadSafeDictionary<ControlID, Int>> = ThreadSafeDictionary()
    static var writeFaults: ThreadSafeDictionary<CGDirectDisplayID, ThreadSafeDictionary<ControlID, Int>> = ThreadSafeDictionary()
    static let lock = NSRecursiveLock()

    static var notifyPort: IONotificationPortRef?
    static var addedIter: io_iterator_t = 0
    static var runLoop: CFRunLoop?

    static var lastKnownBuiltinDisplayID: CGDirectDisplayID = GENERIC_DISPLAY_ID

    static func extractSerialNumber(from edid: EDID, hex: Bool = false) -> String? {
        extractDescriptorText(from: edid, desType: EDIDTextType.serial, hex: hex)
    }

    static func sync<T>(barrier: Bool = false, _ action: () -> T) -> T {
        guard !Thread.isMainThread else {
            return action()
        }

        if let q = DispatchQueue.current, q == queue {
            return action()
        }
        return queue.sync(flags: barrier ? [.barrier] : [], execute: action)
    }

    #if arch(arm64)
        static var avServiceCache: ThreadSafeDictionary<CGDirectDisplayID, IOAVService?> = ThreadSafeDictionary()

        static func hasAVService(displayID: CGDirectDisplayID, display: Display? = nil, ignoreCache: Bool = false) -> Bool {
            guard !isTestID(displayID) else { return false }
            return AVService(displayID: displayID, display: display, ignoreCache: ignoreCache) != nil
        }

        static func AVService(displayID: CGDirectDisplayID, display: Display? = nil, ignoreCache: Bool = false) -> IOAVService? {
            guard !isTestID(displayID) else { return nil }

            return sync(barrier: true) {
                if !ignoreCache, let serviceTemp = avServiceCache[displayID], let service = serviceTemp {
                    return service
                }
                let service = (
                    displayController.avService(displayID: displayID, display: display, match: .byEDIDUUID) ??
                        displayController.avService(displayID: displayID, display: display, match: .byProductAttributes)
                )
                avServiceCache[displayID] = service
                return service
            }
        }
    #endif

    static var i2cControllerCache: ThreadSafeDictionary<CGDirectDisplayID, io_service_t?> = ThreadSafeDictionary()

    static func setup() {
        notifyPort = IONotificationPortCreate(kIOMasterPortDefault)
        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()

        runLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(runLoop, runLoopSource, CFRunLoopMode.defaultMode)

        #if arch(arm64)
            _ = IOServiceAddMatchingNotification(
                notifyPort,
                kIOPublishNotification,
                IOServiceMatching("AppleCLCD2"),
                IORegistryTreeChanged,
                nil,
                &addedIter
            )
            _ = IOServiceAddMatchingNotification(
                notifyPort,
                kIOPublishNotification,
                IOServiceMatching("DCPAVServiceProxy"),
                IORegistryTreeChanged,
                nil,
                &addedIter
            )
            _ = IOServiceAddMatchingNotification(
                notifyPort,
                kIOTerminatedNotification,
                IOServiceMatching("AppleCLCD2"),
                IORegistryTreeChanged,
                nil,
                &addedIter
            )
            _ = IOServiceAddMatchingNotification(
                notifyPort,
                kIOTerminatedNotification,
                IOServiceMatching("DCPAVServiceProxy"),
                IORegistryTreeChanged,
                nil,
                &addedIter
            )
        #else
            _ = IOServiceAddMatchingNotification(
                notifyPort,
                kIOPublishNotification,
                IOServiceMatching(IOFRAMEBUFFER_CONFORMSTO),
                IORegistryTreeChanged,
                nil,
                &addedIter
            )
            _ = IOServiceAddMatchingNotification(
                notifyPort,
                kIOTerminatedNotification,
                IOServiceMatching(IOFRAMEBUFFER_CONFORMSTO),
                IORegistryTreeChanged,
                nil,
                &addedIter
            )
        #endif
    }

    static func reset() {
        sync(barrier: true) {
            DDC.displayPortByUUID.removeAll()
            DDC.displayUUIDByEDID.removeAll()
            DDC.skipReadingPropertyById.removeAll()
            DDC.skipWritingPropertyById.removeAll()
            DDC.readFaults.removeAll()
            DDC.writeFaults.removeAll()
            #if arch(arm64)
                DDC.avServiceCache.removeAll()
            #else
                DDC.i2cControllerCache.removeAll()
            #endif
        }
    }

    static func findExternalDisplays(
        includeVirtual: Bool = true,
        includeAirplay: Bool = false,
        includeProjector: Bool = false
    ) -> [CGDirectDisplayID] {
        var displayIDs = NSScreen.onlineDisplayIDs.filter { id in
            let name = Display.printableName(id)
            return !isBuiltinDisplay(id) &&
                (includeVirtual || !isVirtualDisplay(id, name: name)) &&
                (includeProjector || !isProjectorDisplay(id, name: name)) &&
                (includeAirplay || !(isSidecarDisplay(id, name: name) || isAirplayDisplay(id, name: name)))
        }

        #if DEBUG
//            return displayIDs
            if !displayIDs.isEmpty {
                // displayIDs.append(TEST_DISPLAY_PERSISTENT_ID)
                return displayIDs
            }
            return [
                // TEST_DISPLAY_ID,
                TEST_DISPLAY_PERSISTENT_ID,
                // TEST_DISPLAY_PERSISTENT2_ID,
                // TEST_DISPLAY_PERSISTENT3_ID,
                // TEST_DISPLAY_PERSISTENT4_ID,
            ]
        #else
            return displayIDs
        #endif
    }

    static func isProjectorDisplay(_ id: CGDirectDisplayID, name: String? = nil, checkName: Bool = true) -> Bool {
        guard !isGeneric(id) else {
            return false
        }

        if let panel = DisplayController.panel(with: id), panel.isProjector {
            return true
        }

        if checkName {
            let realName = (name ?? Display.printableName(id)).lowercased()
            return realName.contains("crestron") || realName.contains("optoma") || realName.contains("epson") || realName
                .contains("projector")
        }

        return false
    }

    static func isVirtualDisplay(_ id: CGDirectDisplayID, name: String? = nil, checkName: Bool = true) -> Bool {
        var result = false
        guard !isGeneric(id) else {
            return result
        }

        if checkName {
            let realName = (name ?? Display.printableName(id)).lowercased()
            result = realName.contains("virtual") || realName.contains("displaylink")
        }

        guard let infoDictionary = displayInfoDictionary(id) else {
            log.debug("No info dict for id \(id)")
            return result
        }

        let isVirtualDevice = infoDictionary["kCGDisplayIsVirtualDevice"] as? Bool

        return isVirtualDevice ?? result
    }

    static func isAirplayDisplay(_ id: CGDirectDisplayID, name: String? = nil, checkName: Bool = true) -> Bool {
        var result = false
        guard !isGeneric(id) else {
            return result
        }

        if let panel = DisplayController.panel(with: id), panel.isAirPlayDisplay {
            return true
        }

        if checkName {
            let realName = (name ?? Display.printableName(id)).lowercased()
            result = realName.contains("airplay")
        }

        guard !result else { return result }
        guard let infoDictionary = displayInfoDictionary(id) else {
            log.debug("No info dict for id \(id)")
            return result
        }

        return (infoDictionary["kCGDisplayIsAirPlay"] as? Bool) ?? false
    }

    static func isSidecarDisplay(_ id: CGDirectDisplayID, name: String? = nil, checkName: Bool = true) -> Bool {
        guard !isGeneric(id) else {
            return false
        }

        if let panel = DisplayController.panel(with: id), panel.isSidecarDisplay {
            return true
        }

        guard checkName else { return false }
        let realName = (name ?? Display.printableName(id)).lowercased()
        return realName.contains("sidecar") || realName.contains("ipad")
    }

    static func isSmartBuiltinDisplay(_ id: CGDirectDisplayID, checkName: Bool = true) -> Bool {
        isBuiltinDisplay(id, checkName: checkName) && DisplayServicesIsSmartDisplay(id)
    }

    static func isBuiltinDisplay(_ id: CGDirectDisplayID, checkName: Bool = true) -> Bool {
        guard !isGeneric(id) else { return false }
        if let panel = DisplayController.panel(with: id) {
            return panel.isBuiltIn || panel.isBuiltInRetina
        }
        return (
            CGDisplayIsBuiltin(id) == 1 ||
                id == lastKnownBuiltinDisplayID ||
                (
                    checkName && Display
                        .printableName(id).stripped
                        .lowercased().replacingOccurrences(of: "-", with: "")
                        .contains("builtin")
                )
        )
    }

    static func write(displayID: CGDirectDisplayID, controlID: ControlID, newValue: UInt8) -> Bool {
        #if DEBUG
            guard apply, !isTestID(displayID) else { return true }
        #else
            guard apply else { return true }
        #endif

        #if arch(arm64)
            guard let avService = AVService(displayID: displayID) else { return false }
        #else
            guard let fb = I2CController(displayID: displayID) else { return false }
        #endif

        return sync(barrier: true) {
            if let propertiesToSkip = DDC.skipWritingPropertyById[displayID], propertiesToSkip.contains(controlID) {
                log.debug("Skipping write for \(controlID)", context: displayID)
                return false
            }

            var command = DDCWriteCommand(
                control_id: controlID.rawValue,
                new_value: newValue
            )

            let writeStartedAt = DispatchTime.now()

            #if arch(arm64)
                let result = DDCWriteM1(avService, &command, CachedDefaults[.ddcSleepFactor].rawValue)
            #else
                let result = DDCWrite(fb, &command)
            #endif

            let writeMs = (DispatchTime.now().rawValue - writeStartedAt.rawValue) / 1_000_000
            if writeMs > MAX_WRITE_DURATION_MS {
                log.debug("Writing \(controlID) took too long: \(writeMs)ms", context: displayID)
                writeFault(severity: 4, displayID: displayID, controlID: controlID)
            }

            guard result else {
                log.debug("Error writing \(controlID)", context: displayID)
                writeFault(severity: 1, displayID: displayID, controlID: controlID)
                return false
            }

            if let display = displayController.displays[displayID], !display.responsiveDDC {
                display.responsiveDDC = true
            }

            if let propertyFaults = DDC.writeFaults[displayID], let faults = propertyFaults[controlID] {
                DDC.writeFaults[displayID]![controlID] = max(faults - 1, 0)
            }

            return result
        }
    }

    static func readFault(severity: Int, displayID: CGDirectDisplayID, controlID: ControlID) {
        guard let propertyFaults = DDC.readFaults[displayID] else {
            DDC.readFaults[displayID] = ThreadSafeDictionary(dict: [controlID: severity])
            return
        }
        guard var faults = propertyFaults[controlID] else {
            DDC.readFaults[displayID]![controlID] = severity
            return
        }
        faults = min(severity + faults, MAX_READ_FAULTS + 1)
        DDC.readFaults[displayID]![controlID] = faults

        if faults > MAX_READ_FAULTS {
            DDC.skipReadingProperty(displayID: displayID, controlID: controlID)
        }
    }

    static func writeFault(severity: Int, displayID: CGDirectDisplayID, controlID: ControlID) {
        guard let propertyFaults = DDC.writeFaults[displayID] else {
            DDC.writeFaults[displayID] = ThreadSafeDictionary(dict: [controlID: severity])
            return
        }
        guard var faults = propertyFaults[controlID] else {
            DDC.writeFaults[displayID]![controlID] = severity
            return
        }
        faults = min(severity + faults, MAX_WRITE_FAULTS + 1)
        DDC.writeFaults[displayID]![controlID] = faults

        if faults > MAX_WRITE_FAULTS {
            DDC.skipWritingProperty(displayID: displayID, controlID: controlID)
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
        if controlID == ControlID.BRIGHTNESS, CachedDefaults[.detectResponsiveness] {
            mainAsyncAfter(ms: 100) {
                #if DEBUG
                    displayController.displays[displayID]?.responsiveDDC = TEST_IDS.contains(displayID)
                #else
                    displayController.displays[displayID]?.responsiveDDC = false
                #endif
            }
        }
    }

    static func read(displayID: CGDirectDisplayID, controlID: ControlID) -> DDCReadResult? {
        guard !isTestID(displayID) else { return nil }

        #if arch(arm64)
            guard let avService = AVService(displayID: displayID) else { return nil }
        #else
            guard let fb = I2CController(displayID: displayID) else { return nil }
        #endif

        return sync(barrier: true) {
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

            let readStartedAt = DispatchTime.now()

            #if arch(arm64)
                DDCReadM1(avService, &command, CachedDefaults[.ddcSleepFactor].rawValue)
            #else
                DDCRead(fb, &command)
            #endif

            let readMs = (DispatchTime.now().rawValue - readStartedAt.rawValue) / 1_000_000
            if readMs > MAX_READ_DURATION_MS {
                log.debug("Reading \(controlID) took too long: \(readMs)ms", context: displayID)
                readFault(severity: 4, displayID: displayID, controlID: controlID)
            }

            guard command.success else {
                log.debug("Error reading \(controlID)", context: displayID)
                readFault(severity: 1, displayID: displayID, controlID: controlID)

                return nil
            }

            if let display = displayController.displays[displayID], !display.responsiveDDC {
                display.responsiveDDC = true
            }

            if let propertyFaults = DDC.readFaults[displayID], let faults = propertyFaults[controlID] {
                DDC.readFaults[displayID]![controlID] = max(faults - 1, 0)
            }

            return DDCReadResult(
                controlID: controlID,
                maxValue: command.max_value,
                currentValue: command.current_value
            )
        }
    }

    static func sendEdidRequest(displayID: CGDirectDisplayID) -> (EDID, Data)? {
        guard !isTestID(displayID) else { return nil }

        #if arch(arm64)
            guard let avService = AVService(displayID: displayID) else { return nil }
        #else
            guard let fb = I2CController(displayID: displayID) else { return nil }
        #endif

        return sync(barrier: true) {
            var edidData = [UInt8](repeating: 0, count: 256)
            var edid = EDID()

            #if arch(arm64)
                EDIDTestM1(avService, &edid, &edidData)
            #else
                EDIDTest(fb, &edid, &edidData)
            #endif

            return (edid, Data(bytes: &edidData, count: 256))
        }
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
                    object, kIODisplayOnlyPreferredName.u32
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
            let hexData = nameChars.map { String(format: "%02x", $0) }.joined(separator: " ")
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
        extractDescriptorText(from: edid, desType: EDIDTextType.name, hex: hex)
    }

    static func hasI2CController(displayID: CGDirectDisplayID, ignoreCache: Bool = false) -> Bool {
        guard !isTestID(displayID) else { return false }
        return I2CController(displayID: displayID, ignoreCache: ignoreCache) != nil
    }

    static func I2CController(displayID: CGDirectDisplayID, ignoreCache: Bool = false) -> io_service_t? {
        sync(barrier: true) {
            if !ignoreCache, let controllerTemp = i2cControllerCache[displayID], let controller = controllerTemp {
                return controller
            }
            let controller = I2CController(displayID)
            i2cControllerCache[displayID] = controller
            return controller
        }
    }

    static func I2CController(_ displayID: CGDirectDisplayID) -> io_service_t? {
        guard !isTestID(displayID) else { return nil }

        let activeIDs = NSScreen.onlineDisplayIDs

        #if !DEBUG
            guard activeIDs.contains(displayID) else { return nil }
        #endif

        var fb = IOFramebufferPortFromCGSServiceForDisplayNumber(displayID)
        if fb != 0 {
            log.verbose("Got framebuffer using private CGSServiceForDisplayNumber: \(fb)", context: ["id": displayID])
            return fb
        }
        log.verbose(
            "CGSServiceForDisplayNumber returned invalid framebuffer, trying CGDisplayIOServicePort",
            context: ["id": displayID]
        )

        fb = IOFramebufferPortFromCGDisplayIOServicePort(displayID)
        if fb != 0 {
            log.verbose("Got framebuffer using private CGDisplayIOServicePort: \(fb)", context: ["id": displayID])
            return fb
        }
        log.verbose(
            "CGDisplayIOServicePort returned invalid framebuffer, trying manual search in IOKit registry",
            context: ["id": displayID]
        )

        let displayUUIDByEDIDCopy = displayUUIDByEDID
        let nsDisplayUUIDByEDID = NSMutableDictionary(dictionary: displayUUIDByEDIDCopy)
        fb = IOFramebufferPortFromCGDisplayID(displayID, nsDisplayUUIDByEDID as CFMutableDictionary)

        guard fb != 0 else {
            log.verbose(
                "IOFramebufferPortFromCGDisplayID returned invalid framebuffer. This display can't be controlled through DDC.",
                context: ["id": displayID]
            )
            return nil
        }

        displayUUIDByEDID.removeAll()
        for (key, value) in nsDisplayUUIDByEDID {
            if CFGetTypeID(key as CFTypeRef) == CFDataGetTypeID(), CFGetTypeID(value as CFTypeRef) == CFUUIDGetTypeID() {
                displayUUIDByEDID[key as! CFData as NSData as Data] = (value as! CFUUID)
            }
        }

        log.verbose("Got framebuffer using IOFramebufferPortFromCGDisplayID: \(fb)", context: ["id": displayID])
        return fb
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
        read(displayID: displayID, controlID: ControlID.INPUT_SOURCE)
    }

    static func setBrightness(for displayID: CGDirectDisplayID, brightness: UInt8) -> Bool {
        write(displayID: displayID, controlID: ControlID.BRIGHTNESS, newValue: brightness)
    }

    static func readBrightness(for displayID: CGDirectDisplayID) -> DDCReadResult? {
        read(displayID: displayID, controlID: ControlID.BRIGHTNESS)
    }

    static func readContrast(for displayID: CGDirectDisplayID) -> DDCReadResult? {
        read(displayID: displayID, controlID: ControlID.CONTRAST)
    }

    static func setContrast(for displayID: CGDirectDisplayID, contrast: UInt8) -> Bool {
        write(displayID: displayID, controlID: ControlID.CONTRAST, newValue: contrast)
    }

    static func setRedGain(for displayID: CGDirectDisplayID, redGain: UInt8) -> Bool {
        write(displayID: displayID, controlID: ControlID.RED_GAIN, newValue: redGain)
    }

    static func setGreenGain(for displayID: CGDirectDisplayID, greenGain: UInt8) -> Bool {
        write(displayID: displayID, controlID: ControlID.GREEN_GAIN, newValue: greenGain)
    }

    static func setBlueGain(for displayID: CGDirectDisplayID, blueGain: UInt8) -> Bool {
        write(displayID: displayID, controlID: ControlID.BLUE_GAIN, newValue: blueGain)
    }

    static func setAudioSpeakerVolume(for displayID: CGDirectDisplayID, audioSpeakerVolume: UInt8) -> Bool {
        write(displayID: displayID, controlID: ControlID.AUDIO_SPEAKER_VOLUME, newValue: audioSpeakerVolume)
    }

    static func setAudioMuted(for displayID: CGDirectDisplayID, audioMuted: Bool) -> Bool {
        write(displayID: displayID, controlID: ControlID.AUDIO_MUTE, newValue: audioMuted ? 1 : 2)
    }

    static func setPower(for displayID: CGDirectDisplayID, power: Bool) -> Bool {
        write(displayID: displayID, controlID: ControlID.DPMS, newValue: power ? 1 : 5)
    }

    static func reset(displayID: CGDirectDisplayID) -> Bool {
        write(displayID: displayID, controlID: ControlID.RESET, newValue: 100)
    }

    static func getValue(for displayID: CGDirectDisplayID, controlID: ControlID) -> UInt8? {
        log.debug("DDC reading \(controlID) for \(displayID)")

        guard let result = DDC.read(displayID: displayID, controlID: controlID) else {
            #if DEBUG
                log.debug("DDC read \(controlID) nil for \(displayID)")
            #endif
            return nil
        }
        #if DEBUG
            log.debug("DDC read \(controlID) \(result.currentValue) for \(displayID)")
        #endif
        return result.currentValue
    }

    static func getMaxValue(for displayID: CGDirectDisplayID, controlID: ControlID) -> UInt8? {
        guard let result = DDC.read(displayID: displayID, controlID: controlID) else {
            return nil
        }
        return result.maxValue
    }

    static func getRedGain(for displayID: CGDirectDisplayID) -> UInt8? {
        DDC.getValue(for: displayID, controlID: ControlID.RED_GAIN)
    }

    static func getGreenGain(for displayID: CGDirectDisplayID) -> UInt8? {
        DDC.getValue(for: displayID, controlID: ControlID.GREEN_GAIN)
    }

    static func getBlueGain(for displayID: CGDirectDisplayID) -> UInt8? {
        DDC.getValue(for: displayID, controlID: ControlID.BLUE_GAIN)
    }

    static func getAudioSpeakerVolume(for displayID: CGDirectDisplayID) -> UInt8? {
        DDC.getValue(for: displayID, controlID: ControlID.AUDIO_SPEAKER_VOLUME)
    }

    static func isAudioMuted(for displayID: CGDirectDisplayID) -> Bool? {
        guard let mute = DDC.getValue(for: displayID, controlID: ControlID.AUDIO_MUTE) else {
            return nil
        }
        return mute != 2
    }

    static func getContrast(for displayID: CGDirectDisplayID) -> UInt8? {
        DDC.getValue(for: displayID, controlID: ControlID.CONTRAST)
    }

    static func getInput(for displayID: CGDirectDisplayID) -> UInt8? {
        DDC.readInput(for: displayID)?.currentValue
    }

    static func getBrightness(for id: CGDirectDisplayID) -> UInt8? {
        log.debug("DDC reading brightness for \(id)")
        return DDC.getValue(for: id, controlID: ControlID.BRIGHTNESS)
    }

    static func resetBrightnessAndContrast(for displayID: CGDirectDisplayID) -> Bool {
        DDC.write(displayID: displayID, controlID: .RESET_BRIGHTNESS_AND_CONTRAST, newValue: 1)
    }

    static func resetColors(for displayID: CGDirectDisplayID) -> Bool {
        DDC.write(displayID: displayID, controlID: .RESET_COLOR, newValue: 1)
    }
}
