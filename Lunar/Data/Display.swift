//
//  Display.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import AnyCodable
import ArgumentParser
import Atomics
import Cocoa
import Combine
import CoreGraphics
import DataCompression
import Defaults
import Foundation
import Magnet
import OSLog
import Regex
import Sentry
import Surge
import SwiftDate

let MIN_VOLUME = 0
let MAX_VOLUME = 100
let MIN_BRIGHTNESS: UInt16 = 0
let MAX_BRIGHTNESS: UInt16 = 100
let MIN_CONTRAST: UInt16 = 0
let MAX_CONTRAST: UInt16 = 100

let MIN_BRIGHTNESS_D: Double = 0
let MAX_BRIGHTNESS_D: Double = 100
let MAX_NITS: Double = 2000

let DEFAULT_MIN_BRIGHTNESS: UInt16 = 0
let DEFAULT_MAX_BRIGHTNESS: UInt16 = 100
let DEFAULT_MIN_CONTRAST: UInt16 = 50
let DEFAULT_MAX_CONTRAST: UInt16 = 75
let DEFAULT_COLOR_GAIN: UInt16 = 50

let GENERIC_DISPLAY_ID: CGDirectDisplayID = UINT32_MAX
let ALL_DISPLAYS_ID: CGDirectDisplayID = UINT32_MAX / 7
#if DEBUG
    let TEST_DISPLAY_ID: CGDirectDisplayID = UINT32_MAX / 2
    let TEST_DISPLAY_PERSISTENT_ID: CGDirectDisplayID = UINT32_MAX / 3
    let TEST_DISPLAY_PERSISTENT2_ID: CGDirectDisplayID = UINT32_MAX / 4
    // let TEST_DISPLAY_PERSISTENT3_ID: CGDirectDisplayID = 1
    let TEST_DISPLAY_PERSISTENT3_ID: CGDirectDisplayID = UINT32_MAX / 5
    let TEST_DISPLAY_PERSISTENT4_ID: CGDirectDisplayID = UINT32_MAX / 6
    let TEST_IDS = Set(
        arrayLiteral: GENERIC_DISPLAY_ID,
        TEST_DISPLAY_ID,
        TEST_DISPLAY_PERSISTENT_ID,
        TEST_DISPLAY_PERSISTENT2_ID,
        TEST_DISPLAY_PERSISTENT3_ID,
        TEST_DISPLAY_PERSISTENT4_ID
    )
#endif

let GENERIC_DISPLAY = Display(
    id: GENERIC_DISPLAY_ID,
    serial: "GENERIC_SERIAL",
    name: "No Display",
    minBrightness: 0,
    maxBrightness: 100,
    minContrast: 0,
    maxContrast: 100
)

let ALL_DISPLAYS: Display = {
    let d = Display(
        id: ALL_DISPLAYS_ID,
        serial: "a115a115-18bb-4ef3-aa11-555555555555",
        name: "All Displays",
        minBrightness: 0,
        maxBrightness: 100,
        minContrast: 0,
        maxContrast: 100
    )
    d.isAllDisplays = true
    d.active = false
    d.canChangeContrast = true
    d.enabledControls = [
        .appleNative: false,
        .ddc: false,
        .gamma: false,
        .network: false,
    ]
    return d
}()

#if DEBUG
    var TEST_DISPLAY: Display = {
        let BWqRBb9WWpPF = Display(
            id: TEST_DISPLAY_ID,
            serial: "TEST_DISPLAY_SERIAL",
            name: "LG Ultra HD",
            active: true,
            minBrightness: 0,
            maxBrightness: 60,
            minContrast: 50,
            maxContrast: 75,
            adaptive: true
        )
        BWqRBb9WWpPF.hasI2C = true
        return BWqRBb9WWpPF
    }()

    var TEST_DISPLAY_PERSISTENT: Display = {
        let BWqRBb9WWpPF = datastore.displays(serials: ["TEST_DISPLAY_PERSISTENT_SERIAL"])?.first ?? Display(
            id: TEST_DISPLAY_PERSISTENT_ID,
            serial: "TEST_DISPLAY_PERSISTENT_SERIAL_PERSISTENT",
            name: "DELL U3419W",
            active: true,
            minBrightness: 0,
            maxBrightness: 100,
            minContrast: 0,
            maxContrast: 100,
            adaptive: true
        )
        BWqRBb9WWpPF.hasI2C = true
        return BWqRBb9WWpPF
    }()

    var TEST_DISPLAY_PERSISTENT2: Display = {
        let BWqRBb9WWpPF = datastore.displays(serials: ["TEST_DISPLAY_PERSISTENT2_SERIAL"])?.first ?? Display(
            id: TEST_DISPLAY_PERSISTENT2_ID,
            serial: "TEST_DISPLAY_PERSISTENT2_SERIAL_PERSISTENT_TWO",
            name: "LG Ultrafine",
            active: true,
            minBrightness: 0,
            maxBrightness: 100,
            minContrast: 0,
            maxContrast: 100,
            adaptive: true
        )
        BWqRBb9WWpPF.hasI2C = true
        return BWqRBb9WWpPF
    }()

    var TEST_DISPLAY_PERSISTENT3: Display = {
        let BWqRBb9WWpPF = datastore.displays(serials: ["TEST_DISPLAY_PERSISTENT3_SERIAL"])?.first ?? Display(
            id: TEST_DISPLAY_PERSISTENT3_ID,
            serial: "TEST_DISPLAY_PERSISTENT3_SERIAL_PERSISTENT_THREE",
            name: "Pro Display XDR",
            active: true,
            minBrightness: 0,
            maxBrightness: 100,
            minContrast: 0,
            maxContrast: 100,
            adaptive: true
        )
        BWqRBb9WWpPF.hasI2C = true
        return BWqRBb9WWpPF
    }()

    var TEST_DISPLAY_PERSISTENT4: Display = {
        let BWqRBb9WWpPF = datastore.displays(serials: ["TEST_DISPLAY_PERSISTENT4_SERIAL"])?.first ?? Display(
            id: TEST_DISPLAY_PERSISTENT4_ID,
            serial: "TEST_DISPLAY_PERSISTENT4_SERIAL_PERSISTENT_FOUR",
            name: "Thunderbolt",
            active: true,
            minBrightness: 0,
            maxBrightness: 100,
            minContrast: 0,
            maxContrast: 100,
            adaptive: true
        )
        BWqRBb9WWpPF.hasI2C = true
        return BWqRBb9WWpPF
    }()
    let TEST_SERIALS: Set<String> = [
        TEST_DISPLAY.serial,
        TEST_DISPLAY_PERSISTENT.serial,
        TEST_DISPLAY_PERSISTENT2.serial,
        TEST_DISPLAY_PERSISTENT3.serial,
        TEST_DISPLAY_PERSISTENT4.serial,
        GENERIC_DISPLAY.serial,
        ALL_DISPLAYS.serial,
    ]
#endif

let MAX_SMOOTH_STEP_TIME_NS: UInt64 = 90 * 1_000_000 // 90ms

let PRO_DISPLAY_XDR_NAME = "Pro Display XDR"
let STUDIO_DISPLAY_NAME = "Studio Display"
let LUNA_DISPLAY_NAME = "Luna Display"
let ULTRAFINE_NAME = "LG UltraFine"
let THUNDERBOLT_NAME = "Thunderbolt"
let LED_CINEMA_NAME = "LED Cinema"
let CINEMA_NAME = "Cinema"
let CINEMA_HD_NAME = "Cinema HD"
let COLOR_LCD_NAME = "Color LCD"
let APPLE_DISPLAY_VENDOR_ID = 0x610

// MARK: - AdaptiveController

@objc enum AdaptiveController: Int, Codable, Defaults.Serializable {
    case disabled = 0
    case system = 1
    case lunar = 2
}

// MARK: - DimmingMode

@objc enum DimmingMode: Int, Codable, Defaults.Serializable {
    case gamma = 0
    case overlay = 1
}

// MARK: - Transport

struct Transport: Equatable, CustomStringConvertible, Encodable {
    var upstream: String
    var downstream: String

    var description: String {
        "Transport(up: \(upstream), down: \(downstream))"
    }
}

// MARK: - Gamma

struct Gamma: Equatable {
    var red: CGGammaValue
    var green: CGGammaValue
    var blue: CGGammaValue
    var contrast: CGGammaValue

    func stride(to gamma: Gamma, samples: Int) -> [Gamma] {
        guard gamma != self, samples > 0 else { return [gamma] }

        var (red, green, blue, contrast) = (red, green, blue, contrast)
        let ramps = (
            ramp(targetValue: gamma.red, lastTargetValue: &red, samples: samples, step: 0.01),
            ramp(targetValue: gamma.green, lastTargetValue: &green, samples: samples, step: 0.01),
            ramp(targetValue: gamma.blue, lastTargetValue: &blue, samples: samples, step: 0.01),
            ramp(targetValue: gamma.contrast, lastTargetValue: &contrast, samples: samples, step: 0.01)
        )
        return zip4(ramps.0, ramps.1, ramps.2, ramps.3).map { Gamma(red: $0, green: $1, blue: $2, contrast: $3) }
    }
}

let STEP_256: Float = 1.0 / 256.0

// MARK: - GammaTable

struct GammaTable: Equatable {
    init(red: CGGammaValue = 1, green: CGGammaValue = 1, blue: CGGammaValue = 1, max: CGGammaValue = 1) {
        self.red = Swift.stride(from: 0.00, through: max, by: max / 256.0).map { index in
            powf(index, red)
        }
        self.green = Swift.stride(from: 0.00, through: max, by: max / 256.0).map { index in
            powf(index, green)
        }
        self.blue = Swift.stride(from: 0.00, through: max, by: max / 256.0).map { index in
            powf(index, blue)
        }
        samples = 256
    }

    init(
        redMin: CGGammaValue = 0,
        redMax: CGGammaValue = 1,
        redValue: CGGammaValue = 1,
        greenMin: CGGammaValue = 0,
        greenMax: CGGammaValue = 1,
        greenValue: CGGammaValue = 1,
        blueMin: CGGammaValue = 0,
        blueMax: CGGammaValue = 1,
        blueValue: CGGammaValue = 1
    ) {
        red = Swift.stride(from: 0.00, through: 1.00, by: STEP_256).map { index in
            redMin + ((redMax - redMin) * powf(index, redValue))
        }
        green = Swift.stride(from: 0.00, through: 1.00, by: STEP_256).map { index in
            greenMin + ((greenMax - greenMin) * powf(index, greenValue))
        }
        blue = Swift.stride(from: 0.00, through: 1.00, by: STEP_256).map { index in
            blueMin + ((blueMax - blueMin) * powf(index, blueValue))
        }
        samples = 256
    }

    init(red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue], samples: UInt32, brightness: Brightness? = nil) {
        self.red = red
        self.green = green
        self.blue = blue
        self.samples = samples
        self.brightness = brightness
    }

    init(for id: CGDirectDisplayID, allowZero: Bool = false) {
        guard !DC.gammaDisabledCompletely else {
            red = Self.original.red
            green = Self.original.green
            blue = Self.original.blue
            samples = Self.original.samples
            return
        }

        var redTable = [CGGammaValue](repeating: 0, count: 256)
        var greenTable = [CGGammaValue](repeating: 0, count: 256)
        var blueTable = [CGGammaValue](repeating: 0, count: 256)
        var sampleCount: UInt32 = 0

        mainAsync { DC.activeDisplays[id]?.gammaGetAPICalled = true }
        let result = gammaQueue.syncSafe {
            CGGetDisplayTransferByTable(id, 256, &redTable, &greenTable, &blueTable, &sampleCount)
        }

        guard result == .success, allowZero || sum(redTable) + sum(greenTable) + sum(blueTable) != 0 else {
            log.error("Error reading Gamma for \(id): \(result)")
            red = Self.original.red
            green = Self.original.green
            blue = Self.original.blue
            samples = Self.original.samples
            return
        }

        red = redTable
        green = greenTable
        blue = blueTable
        samples = sampleCount
    }

    static let original = GammaTable()
    static let zero = GammaTable(
        red: [CGGammaValue](repeating: 0, count: 256),
        green: [CGGammaValue](repeating: 0, count: 256),
        blue: [CGGammaValue](repeating: 0, count: 256),
        samples: 256
    )

    var red: [CGGammaValue]
    var green: [CGGammaValue]
    var blue: [CGGammaValue]
    var samples: UInt32
    var brightness: Brightness?

    var isZero: Bool {
        samples == 0 || (
            !red.contains(where: { $0 != 0 }) &&
                !green.contains(where: { $0 != 0 }) &&
                !blue.contains(where: { $0 != 0 })
        )
    }

    @discardableResult
    func apply(to id: CGDirectDisplayID, force: Bool = false) -> Bool {
        guard !DC.gammaDisabledCompletely else { return true }

//        log.debug("Applying gamma table to ID \(id)")
        guard force || !isZero else {
            log.debug("Zero gamma table: samples=\(samples)")
            GammaTable.original.apply(to: id)
            return false
        }

        mainAsync { DC.activeDisplays[id]?.gammaSetAPICalled = true }
        let result = gammaQueue.syncSafe {
            CGSetDisplayTransferByTable(id, samples, red, green, blue)
        }

        guard result == .success else {
            log.error("Error setting Gamma for \(id): \(result)")
            return false
        }
        return true
    }

    func adjust(brightness: UInt16, preciseBrightness: Double? = nil, maxValue: Float) -> GammaTable {
        let br: Float = preciseBrightness?.f ?? (brightness.f / 100)
        let max: Float = br <= 1.0 ? 1.0 : maxValue
        let gammaBrightness: Float = br.map(from: (0.00, max), to: (0.08, max))

        return GammaTable(
            red: red * gammaBrightness,
            green: green * gammaBrightness,
            blue: blue * gammaBrightness,
            samples: samples, brightness: brightness
        )
    }

    func stride(from brightness: Brightness, to newBrightness: Brightness, maxValue: Float) -> [GammaTable] {
        guard brightness != newBrightness else { return [] }

        return Swift.stride(from: brightness, through: newBrightness, by: newBrightness < brightness ? -1 : 1).compactMap { b in
            let table = adjust(brightness: b, maxValue: maxValue)
            return table.isZero ? nil : table
        }
    }
}

// MARK: - ValueType

enum ValueType {
    case brightness
    case contrast
}

let AUDIO_IDENTIFIER_UUID_PATTERN = "([0-9a-f]{2})([0-9a-f]{2})-([0-9a-f]{4})-[0-9a-f]+$".r!

// MARK: - Display

@objc final class Display: NSObject, Codable, Defaults.Serializable, ObservableObject, Identifiable {
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let enabledControlsContainer = try container.nestedContainer(keyedBy: DisplayControlKeys.self, forKey: .enabledControls)

        let id = try container.decode(CGDirectDisplayID.self, forKey: .id)
        _id = id
        let isSmartBuiltin = DDC.isSmartBuiltinDisplay(id)
        let appleNativeControlEnabled = try enabledControlsContainer.decodeIfPresent(Bool.self, forKey: .appleNative) ?? false
        let isNative = isSmartBuiltin && appleNativeControlEnabled
        serial = try container.decode(String.self, forKey: .serial)

        adaptive = try container.decode(Bool.self, forKey: .adaptive) && !Self.ambientLightCompensationEnabled(id)
        name = try container.decode(String.self, forKey: .name)
        edidName = try container.decode(String.self, forKey: .edidName)
        active = try container.decode(Bool.self, forKey: .active)

        let brightness = try isNative
            ? (AppleNativeControl.readBrightnessDisplayServices(id: id) * 100).ns
            : (container.decode(UInt16.self, forKey: .brightness)).ns
        self.brightness = brightness
        let contrast = try (container.decode(UInt16.self, forKey: .contrast)).ns
        self.contrast = contrast

        let minBrightness = try (container.decode(UInt16.self, forKey: .minBrightness)).ns
        let maxBrightness = try (container.decode(UInt16.self, forKey: .maxBrightness)).ns

        self.minBrightness = minBrightness
        self.maxBrightness = maxBrightness
        minContrast = try isSmartBuiltin ? 0 : (container.decode(UInt16.self, forKey: .minContrast)).ns
        let _maxContrast = try isSmartBuiltin ? 100 : (container.decode(UInt16.self, forKey: .maxContrast)).ns
        maxContrast = _maxContrast

        defaultGammaRedMin = try (container.decodeIfPresent(Float.self, forKey: .defaultGammaRedMin)?.ns) ?? 0.ns
        defaultGammaRedMax = try (container.decodeIfPresent(Float.self, forKey: .defaultGammaRedMax)?.ns) ?? 1.ns
        let defaultGammaRedValue = try (container.decodeIfPresent(Float.self, forKey: .defaultGammaRedValue)?.ns) ?? 1.ns
        defaultGammaGreenMin = try (container.decodeIfPresent(Float.self, forKey: .defaultGammaGreenMin)?.ns) ?? 0.ns
        defaultGammaGreenMax = try (container.decodeIfPresent(Float.self, forKey: .defaultGammaGreenMax)?.ns) ?? 1.ns
        let defaultGammaGreenValue = try (container.decodeIfPresent(Float.self, forKey: .defaultGammaGreenValue)?.ns) ?? 1.ns
        defaultGammaBlueMin = try (container.decodeIfPresent(Float.self, forKey: .defaultGammaBlueMin)?.ns) ?? 0.ns
        defaultGammaBlueMax = try (container.decodeIfPresent(Float.self, forKey: .defaultGammaBlueMax)?.ns) ?? 1.ns
        let defaultGammaBlueValue = try (container.decodeIfPresent(Float.self, forKey: .defaultGammaBlueValue)?.ns) ?? 1.ns

        self.defaultGammaRedValue = defaultGammaRedValue
        red = Self.gammaValueToSliderValue(defaultGammaRedValue.doubleValue)
        self.defaultGammaGreenValue = defaultGammaGreenValue
        green = Self.gammaValueToSliderValue(defaultGammaGreenValue.doubleValue)
        self.defaultGammaBlueValue = defaultGammaBlueValue
        blue = Self.gammaValueToSliderValue(defaultGammaBlueValue.doubleValue)

        maxDDCVolume = try isSmartBuiltin ? 100 : (container.decodeIfPresent(UInt16.self, forKey: .maxDDCVolume)?.ns) ?? 100.ns
        maxDDCBrightness = try isSmartBuiltin ? 100 : (container.decodeIfPresent(UInt16.self, forKey: .maxDDCBrightness)?.ns) ?? 100.ns
        maxDDCContrast = try isSmartBuiltin ? 100 : (container.decodeIfPresent(UInt16.self, forKey: .maxDDCContrast)?.ns) ?? 100.ns

        minDDCBrightness = try isSmartBuiltin ? 0 : (container.decodeIfPresent(UInt16.self, forKey: .minDDCBrightness)?.ns) ?? 0.ns
        minDDCContrast = try isSmartBuiltin ? 0 : (container.decodeIfPresent(UInt16.self, forKey: .minDDCContrast)?.ns) ?? 0.ns
        minDDCVolume = try isSmartBuiltin ? 0 : (container.decodeIfPresent(UInt16.self, forKey: .minDDCVolume)?.ns) ?? 0.ns

        faceLightBrightness = try (container.decodeIfPresent(UInt16.self, forKey: .faceLightBrightness)?.ns) ?? 100.ns
        faceLightContrast = try (container.decodeIfPresent(UInt16.self, forKey: .faceLightContrast)?.ns) ?? (_maxContrast.doubleValue * 0.9).intround.ns

        cornerRadius = try (container.decodeIfPresent(Int.self, forKey: .cornerRadius)?.ns) ?? 0

        reapplyColorGain = try (container.decodeIfPresent(Bool.self, forKey: .reapplyColorGain)) ?? false
        extendedColorGain = try (container.decodeIfPresent(Bool.self, forKey: .extendedColorGain)) ?? false
        redGain = try (container.decodeIfPresent(UInt16.self, forKey: .redGain)?.ns) ?? DEFAULT_COLOR_GAIN.ns
        greenGain = try (container.decodeIfPresent(UInt16.self, forKey: .greenGain)?.ns) ?? DEFAULT_COLOR_GAIN.ns
        blueGain = try (container.decodeIfPresent(UInt16.self, forKey: .blueGain)?.ns) ?? DEFAULT_COLOR_GAIN.ns

        lockedBrightness = try (container.decodeIfPresent(Bool.self, forKey: .lockedBrightness)) ?? false
        lockedContrast = try (container.decodeIfPresent(Bool.self, forKey: .lockedContrast)) ?? true

        lockedBrightnessCurve = try (container.decodeIfPresent(Bool.self, forKey: .lockedBrightnessCurve)) ?? false
        lockedContrastCurve = try (container.decodeIfPresent(Bool.self, forKey: .lockedContrastCurve)) ?? false

        alwaysUseNetworkControl = try (container.decodeIfPresent(Bool.self, forKey: .alwaysUseNetworkControl)) ?? false
        neverUseNetworkControl = try (container.decodeIfPresent(Bool.self, forKey: .neverUseNetworkControl)) ?? false
        alwaysFallbackControl = try (container.decodeIfPresent(Bool.self, forKey: .alwaysFallbackControl)) ?? false
        neverFallbackControl = try (container.decodeIfPresent(Bool.self, forKey: .neverFallbackControl)) ?? false

        let volume = try ((container.decodeIfPresent(UInt16.self, forKey: .volume))?.ns ?? 50.ns)
        self.volume = volume
        preciseVolume = volume.doubleValue / 100.0
        audioMuted = try (container.decodeIfPresent(Bool.self, forKey: .audioMuted)) ?? false
        canChangeVolume = try (container.decodeIfPresent(Bool.self, forKey: .canChangeVolume)) ?? true
        isSource = try container.decodeIfPresent(Bool.self, forKey: .isSource) ?? false
        showVolumeOSD = try container.decodeIfPresent(Bool.self, forKey: .showVolumeOSD) ?? true
        muteByteValueOn = try container.decodeIfPresent(UInt16.self, forKey: .muteByteValueOn) ?? 1
        muteByteValueOff = try container.decodeIfPresent(UInt16.self, forKey: .muteByteValueOff) ?? 2
        volumeValueOnMute = try container.decodeIfPresent(UInt16.self, forKey: .volumeValueOnMute) ?? 0
        applyMuteValueOnMute = try container
            .decodeIfPresent(Bool.self, forKey: .applyMuteValueOnMute) ?? true
        applyVolumeValueOnMute = try container
            .decodeIfPresent(Bool.self, forKey: .applyVolumeValueOnMute) ?? CachedDefaults[.muteVolumeZero]

        applyGamma = try container.decodeIfPresent(Bool.self, forKey: .applyGamma) ?? false
        input = try (container.decodeIfPresent(UInt16.self, forKey: .input))?.ns ?? VideoInputSource.unknown.rawValue.ns
        forceDDC = try (container.decodeIfPresent(Bool.self, forKey: .forceDDC)) ?? false
        adaptiveSubzero = try container.decodeIfPresent(Bool.self, forKey: .adaptiveSubzero) ?? true
        unmanaged = try container.decodeIfPresent(Bool.self, forKey: .unmanaged) ?? false
        keepDisconnected = try container.decodeIfPresent(Bool.self, forKey: .keepDisconnected) ?? false
        keepHDREnabled = try container.decodeIfPresent(Bool.self, forKey: .keepHDREnabled) ?? false
        fullRange = try container.decodeIfPresent(Bool.self, forKey: .fullRange) ?? false

        hotkeyInput1 = try (
            (container.decodeIfPresent(UInt16.self, forKey: .hotkeyInput1))?
                .ns ?? (container.decodeIfPresent(UInt16.self, forKey: .hotkeyInput))?.ns ?? VideoInputSource.unknown.rawValue.ns
        )
        hotkeyInput2 = try (container.decodeIfPresent(UInt16.self, forKey: .hotkeyInput2))?.ns ?? VideoInputSource.unknown.rawValue.ns
        hotkeyInput3 = try (container.decodeIfPresent(UInt16.self, forKey: .hotkeyInput3))?.ns ?? VideoInputSource.unknown.rawValue.ns

        brightnessOnInputChange1 = try (container.decodeIfPresent(Double.self, forKey: .brightnessOnInputChange1)) ?? 100.0
        brightnessOnInputChange2 = try (container.decodeIfPresent(Double.self, forKey: .brightnessOnInputChange2)) ?? 100.0
        brightnessOnInputChange3 = try (container.decodeIfPresent(Double.self, forKey: .brightnessOnInputChange3)) ?? 100.0
        contrastOnInputChange1 = try (container.decodeIfPresent(Double.self, forKey: .contrastOnInputChange1)) ?? 75.0
        contrastOnInputChange2 = try (container.decodeIfPresent(Double.self, forKey: .contrastOnInputChange2)) ?? 75.0
        contrastOnInputChange3 = try (container.decodeIfPresent(Double.self, forKey: .contrastOnInputChange3)) ?? 75.0

        applyBrightnessOnInputChange1 = try (container.decodeIfPresent(Bool.self, forKey: .applyBrightnessOnInputChange1)) ?? false
        applyBrightnessOnInputChange2 = try (container.decodeIfPresent(Bool.self, forKey: .applyBrightnessOnInputChange2)) ?? true
        applyBrightnessOnInputChange3 = try (container.decodeIfPresent(Bool.self, forKey: .applyBrightnessOnInputChange3)) ?? false

        syncBrightnessMapping = try (container.decodeIfPresent([DisplayUUID: [AutoLearnMapping]].self, forKey: .syncBrightnessMapping)) ?? [:]
        syncContrastMapping = try (container.decodeIfPresent([DisplayUUID: [AutoLearnMapping]].self, forKey: .syncContrastMapping)) ?? [:]

        sensorBrightnessMapping = try (container.decodeIfPresent([AutoLearnMapping].self, forKey: .sensorBrightnessMapping)) ?? []
        sensorContrastMapping = try (container.decodeIfPresent([AutoLearnMapping].self, forKey: .sensorContrastMapping)) ?? SensorMode.DEFAULT_CONTRAST_MAPPING

        locationBrightnessMapping = try (container.decodeIfPresent([AutoLearnMapping].self, forKey: .locationBrightnessMapping)) ?? LocationMode.DEFAULT_BRIGHTNESS_MAPPING
        locationContrastMapping = try (container.decodeIfPresent([AutoLearnMapping].self, forKey: .locationContrastMapping)) ?? LocationMode.DEFAULT_CONTRAST_MAPPING

        #if arch(arm64)
            nitsBrightnessMapping = try (container.decodeIfPresent([AutoLearnMapping].self, forKey: .nitsBrightnessMapping)) ?? []
            nitsContrastMapping = try (container.decodeIfPresent([AutoLearnMapping].self, forKey: .nitsContrastMapping)) ?? []
        #endif

        super.init()

        blacks = (defaultGammaRedMin.doubleValue + defaultGammaGreenMin.doubleValue + defaultGammaBlueMin.doubleValue) / 3
        whites = (defaultGammaRedMax.doubleValue + defaultGammaGreenMax.doubleValue + defaultGammaBlueMax.doubleValue) / 3

        maxDDCBrightness = try isSmartBuiltin ? 100 : (container.decodeIfPresent(UInt16.self, forKey: .maxDDCBrightness)?.ns) ?? defaultMaxDDCBrightness.ns
        #if arch(arm64)
            maxNits = try container.decodeIfPresent(Double.self, forKey: .maxNits) ?! getMaxNits()
            minNits = try container.decodeIfPresent(Double.self, forKey: .minNits) ?? getMinNits()
        #endif

        if sensorBrightnessMapping.isEmpty {
            #if arch(arm64)
                sensorBrightnessMapping = nitsToPercentageMapping
            #else
                sensorBrightnessMapping = SensorMode.DEFAULT_BRIGHTNESS_MAPPING
            #endif
        }
        adaptivePaused = try (container.decodeIfPresent(Bool.self, forKey: .adaptivePaused)) ?? false

        defer {
            initialised = true
            supportsEnhance = getSupportsEnhance()
            showVolumeSlider = canChangeVolume && CachedDefaults[.showVolumeSlider]
            noDDCOrMergedBrightnessContrast = !hasDDC || CachedDefaults[.mergeBrightnessContrast]
            showOrientation = canRotate && CachedDefaults[.showOrientationInQuickActions] && (!isBuiltin || CachedDefaults[.showOrientationForBuiltinInQuickActions])
            withoutModeChangeAsk {
                withoutApply {
                    withoutDDC { [weak self] in
                        self?.rotation = CGDisplayRotation(id).intround
                        self?.enhanced = Self.getWindowController(id, type: "hdr") != nil
                    }
                }
            }
        }

        preciseBrightness = brightnessToSliderValue(brightness)
        preciseContrast = contrastToSliderValue(contrast, merged: CachedDefaults[.mergeBrightnessContrast])
        preciseBrightnessContrast = brightnessToSliderValue(brightness)

        if !supportsGammaByDefault {
            useOverlay = true
        } else {
            useOverlay = try (container.decodeIfPresent(Bool.self, forKey: .useOverlay)) ?? false
        }
        useAlternateInputSwitching = try (container.decodeIfPresent(Bool.self, forKey: .useAlternateInputSwitching)) ?? false

        if let networkControlEnabled = try enabledControlsContainer.decodeIfPresent(Bool.self, forKey: .network) {
            enabledControls[.network] = networkControlEnabled
        }
        if let appleNativeControlEnabled = try enabledControlsContainer.decodeIfPresent(Bool.self, forKey: .appleNative) {
            enabledControls[.appleNative] = appleNativeControlEnabled
        }
        if let ddcControlEnabled = try enabledControlsContainer.decodeIfPresent(Bool.self, forKey: .ddc) {
            enabledControls[.ddc] = ddcControlEnabled
        }
        if let gammaControlEnabled = try enabledControlsContainer.decodeIfPresent(Bool.self, forKey: .gamma) {
            enabledControls[.gamma] = gammaControlEnabled
        } else {
            enabledControls[.gamma] = !DDC.isSmartBuiltinDisplay(_id)
        }

        if !isInMirrorSet {
            mirroredBeforeBlackOut = false
        } else {
            mirroredBeforeBlackOut = try ((container.decodeIfPresent(Bool.self, forKey: .mirroredBeforeBlackOut)) ?? false)
        }

        if isFakeDummy {
            blackOutMirroringAllowed = true
        } else {
            blackOutMirroringAllowed =
                try ((container.decodeIfPresent(Bool.self, forKey: .blackOutMirroringAllowed)) ?? supportsGammaByDefault) &&
                supportsGammaByDefault
        }
        blackOutEnabled = try ((container.decodeIfPresent(Bool.self, forKey: .blackOutEnabled)) ?? false) && !isIndependentDummy &&
            (isNative ? (brightness.uint16Value <= 1) : true)
        if blackOutEnabled, minBrightness == 1 {
            self.minBrightness = 0
        }

        if let value = try (container.decodeIfPresent(UInt16.self, forKey: .brightnessBeforeBlackout)?.ns) {
            brightnessBeforeBlackout = value
        }
        if let value = try (container.decodeIfPresent(UInt16.self, forKey: .contrastBeforeBlackout)?.ns) {
            contrastBeforeBlackout = value
        }
        if let value = try (container.decodeIfPresent(UInt16.self, forKey: .minBrightnessBeforeBlackout)?.ns) {
            minBrightnessBeforeBlackout = value
        }
        if let value = try (container.decodeIfPresent(UInt16.self, forKey: .minContrastBeforeBlackout)?.ns) {
            minContrastBeforeBlackout = value
        }

        faceLightEnabled = try ((container.decodeIfPresent(Bool.self, forKey: .faceLightEnabled)) ?? false)
        if let value = try (container.decodeIfPresent(UInt16.self, forKey: .brightnessBeforeFacelight)?.ns) {
            brightnessBeforeFacelight = value
        }
        if let value = try (container.decodeIfPresent(UInt16.self, forKey: .contrastBeforeFacelight)?.ns) {
            contrastBeforeFacelight = value
        }
        if let value = try (container.decodeIfPresent(UInt16.self, forKey: .maxBrightnessBeforeFacelight)?.ns) {
            maxBrightnessBeforeFacelight = value
        }
        if let value = try (container.decodeIfPresent(UInt16.self, forKey: .maxContrastBeforeFacelight)?.ns) {
            maxContrastBeforeFacelight = value
        }

        if let value = try (container.decodeIfPresent([BrightnessSchedule].self, forKey: .schedules)),
           value.count == Display.DEFAULT_SCHEDULES.count
        {
            schedules = value
        }
        setupHotkeys()
        guard active else { return }
        setup()

        if let dict = displayInfoDictionary(id) {
            infoDictionary = dict
        }
        cornerRadiusApplier = Repeater(every: 0.5, times: 5, name: "cornerRadiusApplier") { [weak self] in
            self?.updateCornerWindow()
        }

        refetchPanelProps()
        if let possibleMaxNits, possibleMaxNits > 0, let control = control as? AppleNativeControl {
            control.updateNits()
        }
    }

    init(
        id: CGDirectDisplayID,
        serial: String? = nil,
        name: String? = nil,
        active: Bool = false,
        minBrightness: UInt16 = DEFAULT_MIN_BRIGHTNESS,
        maxBrightness: UInt16 = DEFAULT_MAX_BRIGHTNESS,
        minContrast: UInt16 = DEFAULT_MIN_CONTRAST,
        maxContrast: UInt16 = DEFAULT_MAX_CONTRAST,
        adaptive: Bool = true
    ) {
        _id = id
        self.active = active
        activeAndResponsive = active || id != GENERIC_DISPLAY_ID
        let isSmartBuiltin = DDC.isSmartBuiltinDisplay(id)
        self.adaptive = adaptive && !Self.ambientLightCompensationEnabled(id) && !isSmartBuiltin

        isSource = isSmartBuiltin

        self.minBrightness = isSmartBuiltin ? (Sysctl.isMacBook ? 1 : 0) : minBrightness.ns
        self.maxBrightness = isSmartBuiltin ? 100 : maxBrightness.ns
        self.minContrast = isSmartBuiltin || DisplayServicesCanChangeBrightness(id) ? 0 : minContrast.ns
        self.maxContrast = isSmartBuiltin || DisplayServicesCanChangeBrightness(id) ? 100 : maxContrast.ns

        edidName = Self.printableName(id)
        if let n = name, !n.isEmpty {
            self.name = n
        } else {
            self.name = edidName
        }
        self.serial = (serial ?? Display.uuid(id: id))

        super.init()
        #if arch(arm64)
            maxNits = getMaxNits()
            minNits = getMinNits()
        #endif

        if isSmartBuiltin {
            preciseBrightness = AppleNativeControl.readBrightnessDisplayServices(id: id)
            brightness = (preciseBrightness * 100).ns
        } else {
            preciseBrightnessContrast = 50.map(from: (minBrightness.d, maxBrightness.d), to: (0, 100)) / 100.0
        }

        defer {
            initialised = true
            supportsEnhance = getSupportsEnhance()
            showVolumeSlider = canChangeVolume && CachedDefaults[.showVolumeSlider]
            noDDCOrMergedBrightnessContrast = !hasDDC || CachedDefaults[.mergeBrightnessContrast]
            showOrientation = canRotate && CachedDefaults[.showOrientationInQuickActions] && (!isBuiltin || CachedDefaults[.showOrientationForBuiltinInQuickActions])
            withoutModeChangeAsk {
                withoutApply {
                    withoutDDC { [weak self] in
                        self?.rotation = CGDisplayRotation(id).intround
                        self?.enhanced = Self.getWindowController(id, type: "hdr") != nil
                    }
                }
            }
            blackOutMirroringAllowed = supportsGammaByDefault || isFakeDummy
        }

        maxDDCBrightness = defaultMaxDDCBrightness.ns
        if isLEDCinema {
            maxDDCVolume = 255
        }

        useOverlay = !supportsGammaByDefault
        enabledControls[.ddc] = !isTV && !isStudioDisplay
        enabledControls[.gamma] = !isSmartBuiltin

        guard active else { return }

        setup()

        if let dict = displayInfoDictionary(id) {
            infoDictionary = dict
        }

        startControls()
        setupHotkeys()
        refreshGamma()
        if supportsGamma {
            reapplyGamma()
        } else if !supportsGammaByDefault, hasSoftwareControl {
            shade(amount: 1.0 - preciseBrightness)
        }
        cornerRadiusApplier = Repeater(every: 0.5, times: 5, name: "cornerRadiusApplier") { [weak self] in
            self?.updateCornerWindow()
        }

        refetchPanelProps()
        if let possibleMaxNits, possibleMaxNits > 0, let control = control as? AppleNativeControl {
            control.updateNits()
        }
    }

    deinit {
        gammaWindowController?.close()
        gammaWindowController = nil

        cornerWindowControllerTopLeft?.close()
        cornerWindowControllerTopRight?.close()
        cornerWindowControllerBottomLeft?.close()
        cornerWindowControllerBottomRight?.close()
        cornerWindowControllerTopLeft = nil
        cornerWindowControllerTopRight = nil
        cornerWindowControllerBottomLeft = nil
        cornerWindowControllerBottomRight = nil

        shadeWindowController?.close()
        shadeWindowController = nil
        faceLightWindowController?.close()
        faceLightWindowController = nil
        osdWindowController?.close()
        osdWindowController = nil
        arrangementOsdWindowController?.close()
        arrangementOsdWindowController = nil
        hdrWindowController?.close()
        hdrWindowController = nil
        testWindowController?.close()
        testWindowController = nil

        xdrTimer = nil
    }

    enum CodingKeys: String, CodingKey, CaseIterable, ExpressibleByArgument {
        case id
        case name
        case edidName
        case serial
        case adaptive
        case defaultGammaRedMin
        case defaultGammaRedMax
        case defaultGammaRedValue
        case defaultGammaGreenMin
        case defaultGammaGreenMax
        case defaultGammaGreenValue
        case defaultGammaBlueMin
        case defaultGammaBlueMax
        case defaultGammaBlueValue
        case maxDDCBrightness
        case maxDDCContrast
        case maxDDCVolume
        case minDDCBrightness
        case minDDCContrast
        case minDDCVolume

        case faceLightBrightness
        case faceLightContrast

        case mirroredBeforeBlackOut
        case blackOutEnabled
        case blackOutMirroringAllowed
        case brightnessBeforeBlackout
        case contrastBeforeBlackout
        case minBrightnessBeforeBlackout
        case minContrastBeforeBlackout

        case facelight
        case blackout
        case systemAdaptiveBrightness
        case adaptiveSubzero
        case unmanaged
        case keepDisconnected
        case keepHDREnabled
        case maxNits
        case minNits
        case nits
        case lux

        case faceLightEnabled
        case brightnessBeforeFacelight
        case contrastBeforeFacelight
        case maxBrightnessBeforeFacelight
        case maxContrastBeforeFacelight

        case cornerRadius

        case reapplyColorGain
        case extendedColorGain
        case redGain
        case greenGain
        case blueGain
        case lockedBrightness
        case lockedContrast
        case lockedBrightnessCurve
        case lockedContrastCurve
        case minContrast
        case minBrightness
        case maxContrast
        case maxBrightness
        case contrast
        case brightness
        case volume
        case audioMuted
        case mute
        case canChangeVolume
        case power
        case active
        case responsiveDDC
        case input
        case hotkeyInput
        case hotkeyInput1
        case hotkeyInput2
        case hotkeyInput3
        case useOverlay
        case useAlternateInputSwitching
        case alwaysUseNetworkControl
        case neverUseNetworkControl
        case alwaysFallbackControl
        case neverFallbackControl
        case enabledControls
        case schedules
        case activeAndResponsive
        case hasDDC
        case hasI2C
        case hasNetworkControl
        case sendingBrightness
        case sendingContrast
        case sendingInput
        case sendingVolume
        case isSource
        case showVolumeOSD
        case muteByteValueOn
        case muteByteValueOff
        case volumeValueOnMute
        case applyVolumeValueOnMute
        case applyMuteValueOnMute
        case forceDDC
        case applyGamma
        case brightnessOnInputChange
        case brightnessOnInputChange1
        case brightnessOnInputChange2
        case brightnessOnInputChange3
        case contrastOnInputChange
        case contrastOnInputChange1
        case contrastOnInputChange2
        case contrastOnInputChange3
        case applyBrightnessOnInputChange1
        case applyBrightnessOnInputChange2
        case applyBrightnessOnInputChange3

        case syncBrightnessMapping
        case syncContrastMapping
        case sensorBrightnessMapping
        case sensorContrastMapping
        case locationBrightnessMapping
        case locationContrastMapping
        case nitsBrightnessMapping
        case nitsContrastMapping

        case main
        case rotation
        case adaptiveController
        case subzero
        case fullRange
        case xdr
        case hdr
        case softwareBrightness
        case subzeroDimming
        case xdrBrightness
        case averageDDCWriteNanoseconds
        case averageDDCReadNanoseconds
        case connection

        case normalizedBrightness
        case normalizedContrast
        case normalizedBrightnessContrast

        case ddcEnabled
        case networkEnabled
        case appleNativeEnabled
        case gammaEnabled
        case adaptivePaused

        static var needsLunarPro: Set<CodingKeys> = [
            .faceLightEnabled,
            .blackOutEnabled,
            .facelight,
            .blackout,
            .xdr,
            .xdrBrightness,
            .fullRange,
        ]

        static var double: Set<CodingKeys> = [
            .defaultGammaRedMin,
            .defaultGammaRedMax,
            .defaultGammaRedValue,
            .defaultGammaGreenMin,
            .defaultGammaGreenMax,
            .defaultGammaGreenValue,
            .defaultGammaBlueMin,
            .defaultGammaBlueMax,
            .defaultGammaBlueValue,

            .softwareBrightness,
            .xdrBrightness,
            .subzeroDimming,

            .normalizedBrightness,
            .normalizedContrast,
            .normalizedBrightnessContrast,
        ]
        static var bool: Set<CodingKeys> = [
            .active,
            .adaptive,
            .adaptivePaused,
            .lockedBrightness,
            .lockedContrast,
            .lockedBrightnessCurve,
            .lockedContrastCurve,
            .audioMuted,
            .mute,
            .canChangeVolume,
            .power,
            .main,
            .useOverlay,
            .useAlternateInputSwitching,
            .alwaysUseNetworkControl,
            .neverUseNetworkControl,
            .alwaysFallbackControl,
            .neverFallbackControl,
            .isSource,
            .showVolumeOSD,
            .forceDDC,
            .applyGamma,
            .faceLightEnabled,
            .blackOutEnabled,
            .facelight,
            .blackout,
            .blackOutMirroringAllowed,
            .mirroredBeforeBlackOut,
            .subzero,
            .fullRange,
            .xdr,
            .hdr,
            .applyBrightnessOnInputChange1,
            .applyBrightnessOnInputChange2,
            .applyBrightnessOnInputChange3,
            .extendedColorGain,
            .reapplyColorGain,
            .applyVolumeValueOnMute,
            .applyMuteValueOnMute,
            .systemAdaptiveBrightness,
            .adaptiveSubzero,
            .unmanaged,
            .keepHDREnabled,
            // .keepDisconnected,

            .ddcEnabled,
            .networkEnabled,
            .appleNativeEnabled,
            .gammaEnabled,
        ]

        static var hidden: Set<CodingKeys> = [
            .hotkeyInput,
            .brightnessOnInputChange,
            .contrastOnInputChange,
            .syncBrightnessMapping,
            .syncContrastMapping,
            .sensorBrightnessMapping,
            .sensorContrastMapping,
            .locationBrightnessMapping,
            .locationContrastMapping,
            .nitsBrightnessMapping,
            .nitsContrastMapping,
        ]

        static var settableWithControl: Set<CodingKeys> = [
            .contrast,
            .brightness,
            .volume,
            .audioMuted,
            .mute,
            .power,
            .input,
            .redGain,
            .greenGain,
            .blueGain,

            .normalizedBrightness,
            .normalizedContrast,
            .normalizedBrightnessContrast,
        ]

        static var settableCommon: [CodingKeys] = [
            .brightness,
            .contrast,
            .volume,

            .mute,
            .power,
            .input,
            .rotation,

            .xdrBrightness,
            .subzeroDimming,
            .facelight,
            .blackout,
            .main,
        ]
        static var settable: Set<CodingKeys> = [
            .name,
            .adaptive,
            .adaptivePaused,
            .defaultGammaRedMin,
            .defaultGammaRedMax,
            .defaultGammaRedValue,
            .defaultGammaGreenMin,
            .defaultGammaGreenMax,
            .defaultGammaGreenValue,
            .defaultGammaBlueMin,
            .defaultGammaBlueMax,
            .defaultGammaBlueValue,
            .maxDDCBrightness,
            .maxDDCContrast,
            .maxDDCVolume,
            .minDDCBrightness,
            .minDDCContrast,
            .minDDCVolume,
            .facelight,
            .blackout,
            .faceLightBrightness,
            .faceLightContrast,
            .cornerRadius,
            .reapplyColorGain,
            .extendedColorGain,
            .redGain,
            .greenGain,
            .blueGain,
            .lockedBrightness,
            .lockedContrast,
            .lockedBrightnessCurve,
            .lockedContrastCurve,
            .minContrast,
            .minBrightness,
            .maxContrast,
            .maxBrightness,
            .contrast,
            .brightness,
            .volume,
            .audioMuted,
            .mute,
            .canChangeVolume,
            .power,
            .input,
            .hotkeyInput1,
            .hotkeyInput2,
            .hotkeyInput3,
            .useOverlay,
            .useAlternateInputSwitching,
            .alwaysUseNetworkControl,
            .neverUseNetworkControl,
            .alwaysFallbackControl,
            .neverFallbackControl,
            .isSource,
            .showVolumeOSD,
            .muteByteValueOn,
            .muteByteValueOff,
            .volumeValueOnMute,
            .applyVolumeValueOnMute,
            .applyMuteValueOnMute,
            .forceDDC,
            .applyGamma,
            .brightnessOnInputChange1,
            .brightnessOnInputChange2,
            .brightnessOnInputChange3,
            .contrastOnInputChange1,
            .contrastOnInputChange2,
            .contrastOnInputChange3,
            .main,
            .rotation,
            .adaptiveController,
            .subzero,
            .fullRange,
            .xdr,
            .hdr,
            .softwareBrightness,
            .subzeroDimming,
            .xdrBrightness,
            .normalizedBrightness,
            .normalizedContrast,
            .normalizedBrightnessContrast,
            .systemAdaptiveBrightness,
            .ddcEnabled,
            .networkEnabled,
            .appleNativeEnabled,
            .gammaEnabled,
        ]

        var isHidden: Bool {
            Self.hidden.contains(self)
        }
    }

    enum AdaptiveModeKeys: String, CodingKey {
        case sensor
        case sync
        case location
        case manual
        case clock
    }

    enum DisplayControlKeys: String, CodingKey {
        case network
        case appleNative
        case ddc
        case gamma
    }

    enum Vendor: Int64 {
        case dell = 4268
        case lg = 7789
        case samsung = 19501
        case benq = 2513
        case prism = -2
        case lenovo = 12462
        case xiaomi = 10007
        case xiaomi2 = 25001
        case philips = 16652
        case sceptre = 19988
        case huawei = 8950
        case eizo = 5571
        case apple = 0x610
        case asus = 1129
        case proart = 1715
        case acer = 1138
        case hp = 8718
        case portable = 19700
        case dummy = 0xF0F0
        case dummyNew = 0x896
        case innocn = 12547
        case tcl = 20588
        case aoc = 1507
        case gigabyte = 7252
        case eve = 5829
        case aosiman = 1645
        case iiyama = 9933
        case ktc = 19815
        case iodata = 9700
        case innoview = 25716
        case cforce = 12434
        case horizon = 8387
        case msi = 13929
        case viewsonic = 23139
        case ic = 9316
        case unknown = -1

        var isDummy: Bool {
            self == .dummy || self == .dummyNew
        }
    }

    enum ConnectionType: String, Defaults.Serializable, Codable {
        case displayport
        case usbc
        case dvi
        case hdmi
        case vga
        case mipi
        case unknown

        static func fromTransport(_ transport: Transport?) -> ConnectionType? {
            guard let transport else {
                return nil
            }

            switch transport.downstream {
            case "HDMI":
                return .hdmi
            case "DVI":
                return .dvi
            case "DP":
                return .displayport
            case "VGA":
                return .vga
            case "MIPI":
                return .mipi
            default:
                return nil
            }
        }

        static func fromTransportType(_ transportType: Int) -> ConnectionType? {
            switch transportType {
            case 0:
                .displayport
            case 1:
                .usbc
            case 2:
                .dvi
            case 3:
                .hdmi
            case 4:
                .mipi
            case 5:
                .vga
            default:
                nil
            }
        }
    }

    static let DEFAULT_SCHEDULES = [
        BrightnessSchedule(type: .disabled, hour: 0, minute: 30, brightness: 0.7, contrast: 0.65, negative: true),
        BrightnessSchedule(type: .disabled, hour: 10, minute: 20, brightness: 0.8, contrast: 0.70, negative: false),
        BrightnessSchedule(type: .disabled, hour: 0, minute: 0, brightness: 1.0, contrast: 0.75, negative: false),
        BrightnessSchedule(type: .disabled, hour: 1, minute: 30, brightness: 0.6, contrast: 0.60, negative: false),
        BrightnessSchedule(type: .disabled, hour: 7, minute: 30, brightness: 0.2, contrast: 0.45, negative: false),
    ]

    @Atomic static var applySource = true

    static let dummyNamePattern = "dummy|[^u]28e850|^28e850".r!
    static let notDummyNamePattern = "not a dummy".r!

    static let numberNamePattern = #"\s*\(\d\)\s*"#.r!

    static var onFinishedUserAdjusting: (() -> Void)? = nil

    static let MIN_SOFTWARE_BRIGHTNESS: Float = 1.000001
    static let FILLED_CHICLET_OFFSET: Float = 1 / 16
    static let SUBZERO_FILLED_CHICLETS_THRESHOLDS: [Float] = (0 ... 16).map { FILLED_CHICLET_OFFSET * $0.f }

    static var lastNativeBrightnessMapping: [String: Double] = [:]
    static var ddcWorkingCount: [String: Int] = [:]
    static var ddcNotWorkingCount: [String: Int] = [:]

    static let LUX_TO_NITS: [Double: Double] = [
        0: 40,
        13: 54,
        23: 61,
        39: 76,
        71: 87,
        80: 100,
        100: 105,
        135: 120,
        160: 134,
        190: 147,
        224: 160,
        313: 193,
        565: 289,
        702: 340,
        800: 400,
        1000: 500,
    ]

    override var description: String {
        "\(name) [ID \(id)]"
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(serial)
        return hasher.finalize()
    }

    let osdState = OSDState()

    lazy var xdrFilledChicletOffset = 6 / (96 * (1 / (maxSoftwareBrightness - Self.MIN_SOFTWARE_BRIGHTNESS)))
    lazy var xdrFilledChicletsThresholds: [Float] = (0 ... 16).map { 1.0 + xdrFilledChicletOffset * $0.f }
    @Published @objc dynamic var appPreset: AppException? = nil

    @objc dynamic lazy var hasAmbientLightAdaptiveBrightness: Bool = isAllDisplays ? false : DisplayServicesHasAmbientLightCompensation(id)
    @objc dynamic lazy var canBeSource: Bool = {
        allowAnySyncSourcePublisher.sink { [weak self] change in
            guard let self else { return }
            canBeSource = (hasAmbientLightAdaptiveBrightness && supportsGammaByDefault) || change.newValue
        }.store(in: &observers)
        return (hasAmbientLightAdaptiveBrightness && supportsGammaByDefault) || CachedDefaults[.allowAnySyncSource]
    }()

    dynamic lazy var controlResult = isBuiltin ? ControlResult.onlyBrightnessWorked : ControlResult.allWorked
    @objc dynamic lazy var brightnessReadWorks = controlResult.read.brightness
    @objc dynamic lazy var contrastReadWorks = controlResult.read.contrast
    @objc dynamic lazy var volumeReadWorks = controlResult.read.volume

    @objc dynamic lazy var brightnessWriteWorks = controlResult.write.brightness
    @objc dynamic lazy var contrastWriteWorks = controlResult.write.contrast
    @objc dynamic lazy var volumeWriteWorks = controlResult.write.volume

    @objc dynamic lazy var isBuiltin: Bool = DDC.isBuiltinDisplay(id)
    @objc dynamic lazy var isExternal: Bool = !isBuiltin
    lazy var isSmartBuiltin: Bool = isBuiltin && isSmartDisplay
    lazy var canChangeBrightnessDS: Bool = isAllDisplays ? false : DisplayServicesCanChangeBrightness(id)

    lazy var _hotkeyPopover: NSPopover? = INPUT_HOTKEY_POPOVERS[serial] ?? nil
    lazy var hotkeyPopoverController: HotkeyPopoverController? = initHotkeyPopoverController()

    var _idLock = NSRecursiveLock()
    var _id: CGDirectDisplayID

    var transport: Transport? = nil
    var normalizedName = ""
    lazy var lastVolume: NSNumber = volume

    @Published @objc dynamic var activeAndResponsive = false

    @Published var enabledControls: [DisplayControl: Bool] = [
        .network: true,
        .appleNative: true,
        .ddc: true,
        .gamma: true,
    ]

    @objc dynamic var sentBrightnessCondition = NSCondition()
    @objc dynamic var sentContrastCondition = NSCondition()
    @objc dynamic var sentInputCondition = NSCondition()
    @objc dynamic var sentVolumeCondition = NSCondition()

    var redMin: CGGammaValue = 0.0
    var redMax: CGGammaValue = 1.0
    var redGamma: CGGammaValue = 1.0

    var greenMin: CGGammaValue = 0.0
    var greenMax: CGGammaValue = 1.0
    var greenGamma: CGGammaValue = 1.0

    var blueMin: CGGammaValue = 0.0
    var blueMax: CGGammaValue = 1.0
    var blueGamma: CGGammaValue = 1.0

    var onReadapt: (() -> Void)?
    var smoothStep = 1
    var slowRead = false
    var slowWrite = false
    var mcdp = false
    var onControlChange: ((Control) -> Void)? = nil
    @AtomicLock var context: [String: Any]? = nil

    lazy var isForTesting = isTestID(id)

    var observers: Set<AnyCancellable> = []

    var primaryMirrorScreenFetcher: Repeater?

    @Atomic var force = false

    @Atomic var faceLightEnabled = false

    lazy var brightnessBeforeFacelight = brightness
    lazy var contrastBeforeFacelight = contrast
    lazy var maxBrightnessBeforeFacelight = maxBrightness
    lazy var maxContrastBeforeFacelight = maxContrast

    @Atomic @objc dynamic var mirroredBeforeBlackOut = false
    @Atomic @objc dynamic var blackOutEnabledWithoutMirroring = false
    @Atomic @objc dynamic var blackOutMirroringAllowed = true
    lazy var brightnessBeforeBlackout = brightness
    lazy var contrastBeforeBlackout = contrast
    lazy var minBrightnessBeforeBlackout = minBrightness
    lazy var minContrastBeforeBlackout = minContrast

    @Atomic var inSmoothTransition = false

    lazy var hotkeyIdentifiers = [
        "toggle-last-input-\(serial)",
        "toggle-last-input2-\(serial)",
        "toggle-last-input3-\(serial)",
    ]

    @Atomic var gammaChanged = false
    let VALID_ROTATION_VALUES: Set<Int> = [0, 90, 180, 270]
    @objc dynamic lazy var rotationTooltip: String? = canRotate ? nil : "This monitor doesn't support rotation"
    @objc dynamic lazy var inputTooltip: String? = hasDDC
        ? nil
        : "This monitor doesn't support input switching because DDC is not available"

    var defaultGammaTable = GammaTable.original
    var lunarGammaTable: GammaTable? = nil
    var lastGammaTable: GammaTable? = nil

    let DEFAULT_GAMMA_PARAMETERS: (Float, Float, Float, Float, Float, Float, Float, Float, Float) = (0, 1, 1, 0, 1, 1, 0, 1, 1)

    @Atomic var settingGamma = false
    lazy var isSidecar: Bool = DDC.isSidecarDisplay(id, name: edidName)
    lazy var isAirplay: Bool = DDC.isAirplayDisplay(id, name: edidName)
    lazy var isVirtual: Bool = DDC.isVirtualDisplay(id, name: edidName)
    lazy var isProjector: Bool = DDC.isProjectorDisplay(id, name: edidName)

    @objc dynamic lazy var supportsGamma: Bool = supportsGammaByDefault && !useOverlay && !NSWorkspace.shared.accessibilityDisplayShouldInvertColors
    @objc dynamic lazy var supportsGammaByDefault: Bool = !isSidecar && !isAirplay && !isVirtual && !isProjector && !isLunaDisplay

    @objc dynamic lazy var panelModeTitles: [NSAttributedString] = panelModes.map(\.attributedString)
    @objc dynamic lazy var panelModes: [MPDisplayMode] = getPanelModes()

    @Atomic var modeChangeAsk = true

    @objc dynamic lazy var isSmartDisplay = isAllDisplays ? false : (panel?.isSmartDisplay ?? DisplayServicesIsSmartDisplay(id))

    @Atomic var shouldStopBrightnessTransition = true
    @Atomic var shouldStopContrastTransition = true
    @Atomic var lastWrittenBrightness: UInt16 = 50
    @Atomic var lastWrittenContrast: UInt16 = 50

    let DEFAULT_DDC_BLOCKERS = """
    * Disable any **Ambient Light Sensing** feature
    * Disable any **Automatic Brightness** or **Dynamic Brightness** feature
    * Set **Picture Mode** or **Preset** to `Custom`, `Standard` or `User`
    """
    let DDC_BLOCKERS_TRAILER = """
    #### Other possible blockers

    * Some `HDMI-to-USB-C` Cables
        * If possible, try a `DisplayPort to USB-C` cable
    * Smart monitors
        * Samsung M7/M9
        * Samsung G7/G9
    * Non-compliant hub/dock/adapter

    For more information, [click here](https://lunar.fyi/faq#brightness-not-changing).
    """

    @Atomic var applyPreciseValue = true
    @Atomic var reapplyPreciseValue = true

    @objc dynamic lazy var preciseMaxBrightness: Double = maxBrightness.doubleValue / 100.0
    @objc dynamic lazy var preciseMinBrightness: Double = minBrightness.doubleValue / 100.0
    @objc dynamic lazy var preciseMaxContrast: Double = maxContrast.doubleValue / 100.0
    @objc dynamic lazy var preciseMinContrast: Double = minContrast.doubleValue / 100.0

    var lastConnectionTime = Date()

    @Published @objc dynamic var supportsEnhance = false
    lazy var supportsFullRangeXDR = getSupportsFullRangeXDR()

    @Published var lastSoftwareBrightness: Float = 1.0

    @Atomic var hasSoftwareControl = false

    @Published @objc dynamic var noDDCOrMergedBrightnessContrast = false

    var cornerRadiusBeforeNotchDisable: NSNumber?
    var cornerRadiusApplier: Repeater?

    lazy var blackoutDisablerPublisher: PassthroughSubject<Bool, Never> = {
        let p = PassthroughSubject<Bool, Never>()
        p.debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] shouldDisable in
                guard shouldDisable, let self, !self.isInMirrorSet else { return }
                lastBlackOutToggleDate = .distantPast
                disableBlackOut()
            }
            .store(in: &observers)

        return p
    }()

    var hdrWindowOpenedAt = Date()

    @Atomic var forceShowSoftwareOSD = false
    @Atomic var forceHideSoftwareOSD = false

    @Published @objc dynamic var muteByteValueOn: UInt16 = 1
    @Published @objc dynamic var muteByteValueOff: UInt16 = 2
    @Published @objc dynamic var volumeValueOnMute: UInt16 = 0
    @Published @objc dynamic var applyVolumeValueOnMute = false
    @Published @objc dynamic var applyMuteValueOnMute = true

    @objc dynamic var reapplyColorGain = false
    @objc dynamic lazy var maxColorGain = extendedColorGain ? 255 : 100

    @Atomic var applyDisplayServices = true
    @Atomic var apply = true

    lazy var saving: PassthroughSubject<Bool, Never> = {
        let p = PassthroughSubject<Bool, Never>()
        p
            .debounce(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                DataStore.storeDisplay(display: self)
            }.store(in: &observers)

        return p
    }()

    lazy var savingLater: PassthroughSubject<Bool, Never> = {
        let p = PassthroughSubject<Bool, Never>()
        p
            .debounce(for: .seconds(30), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                DataStore.storeDisplay(display: self)
            }.store(in: &observers)

        return p
    }()

    var xdrEnforceTask: Repeater? = nil
    var xdrResetTask: Repeater? = nil

    lazy var ddcResetPublisher: PassthroughSubject<Bool, Never> = {
        let p = PassthroughSubject<Bool, Never>()
        p.debounce(for: .milliseconds(10), scheduler: RunLoop.main)
            .sink { [weak self] run in
                guard run, let self else { return }

                if control is DDCControl {
                    control?.resetState()
                } else {
                    DDCControl(display: self).resetState()
                }

                resetControl()

                appDelegate?.screenWakeAdapterTask = appDelegate?.screenWakeAdapterTask ?? Repeater(every: 2, times: 3, name: "DDCResetAdapter") {
                    DC.adaptBrightness(force: true)
                }
            }.store(in: &observers)
        return p
    }()

    lazy var networkResetPublisher: PassthroughSubject<Bool, Never> = {
        let p = PassthroughSubject<Bool, Never>()
        p.debounce(for: .milliseconds(10), scheduler: RunLoop.main)
            .sink { [weak self] run in
                guard run, let self else { return }

                if control is NetworkControl {
                    control?.resetState()
                } else {
                    NetworkControl.resetState(serial: serial)
                }

                resetControl()

                appDelegate?.screenWakeAdapterTask = appDelegate?.screenWakeAdapterTask ?? Repeater(every: 2, times: 5, name: "NetworkResetAdapter") {
                    DC.adaptBrightness(force: true)
                }
            }.store(in: &observers)
        return p
    }()

    lazy var sendingValuePublisher: PassthroughSubject<String, Never> = {
        let p = PassthroughSubject<String, Never>()
        p.debounce(for: .seconds(5), scheduler: RunLoop.main)
            .sink { [weak self] name in
                guard let self else { return }
                let conditionName = name.replacingOccurrences(of: "sending", with: "sent") + "Condition"

                setValue(false, forKey: name)
                (value(forKey: conditionName) as? NSCondition)?.broadcast()
            }.store(in: &observers)
        return p
    }()

    var i2cDetectionTask: Repeater? = nil

    var fallbackPromptTime: Date?

    @Published var lastRawBrightness: Double? = 78
    @Published var lastRawContrast: Double? = 100
    @Published var lastRawVolume: Double? = 12

    lazy var xdrDisablePublisher: PassthroughSubject<Bool, Never> = {
        let p = PassthroughSubject<Bool, Never>()
        p
            .debounce(for: .milliseconds(5000), scheduler: RunLoop.main)
            .sink { [weak self] shouldDisable in
                guard let self, shouldDisable else { return }
                handleEnhance(false, withoutSettingBrightness: true)
            }.store(in: &observers)

        return p
    }()

    var screenFetcher: Repeater?
    var nativeBrightnessRefresher: Repeater?
    // var nativeContrastRefresher: Repeater?

    @Published @objc dynamic var brightnessU16: UInt16 = 50

    var connection: ConnectionType = .unknown

    @Atomic var lastGammaBrightness: Brightness = 100
    @Atomic var isNative = false

    lazy var isMacBook: Bool = isBuiltin && Sysctl.isMacBook
    lazy var usesDDCBrightnessControl: Bool = control is DDCControl || control is NetworkControl

    @Published @objc dynamic var keepDisconnected = false
    @objc dynamic lazy var canChangeContrast: Bool = usesDDCBrightnessControl || (isNative && (alternativeControlForAppleNative?.isDDC ?? false))

    var isAllDisplays = false

    var syncBrightnessMapping: [DisplayUUID: [AutoLearnMapping]] = [:]
    var syncContrastMapping: [DisplayUUID: [AutoLearnMapping]] = [:]
    var sensorBrightnessMapping: [AutoLearnMapping] = SensorMode.DEFAULT_BRIGHTNESS_MAPPING
    var sensorContrastMapping: [AutoLearnMapping] = SensorMode.DEFAULT_CONTRAST_MAPPING
    var locationBrightnessMapping: [AutoLearnMapping] = LocationMode.DEFAULT_BRIGHTNESS_MAPPING
    var locationContrastMapping: [AutoLearnMapping] = LocationMode.DEFAULT_CONTRAST_MAPPING
    var scheduledBrightnessTask: Repeater? = nil
    @Published var userMute: Double = 0

    @Published @objc dynamic var keepHDREnabled = false
    @objc dynamic lazy var supportsHDR: Bool = panel?.hasHDRModes ?? false
    lazy var cachedSystemAdaptiveBrightness: Bool = Self.ambientLightCompensationEnabled(id)
    var lastReferenceEDR: CGFloat?
    var lastPotentialEDR: CGFloat?
    var panelPropsRefetcher: Repeater?

    @Published var referencePreset: MPDisplayPreset?

    #if arch(arm64)
        var nitsBrightnessMapping: [AutoLearnMapping] = []
        var nitsBrightnessMappingSaver: DispatchWorkItem? { didSet { oldValue?.cancel() } }

        var nitsContrastMapping: [AutoLearnMapping] = []
        var nitsContrastMappingSaver: DispatchWorkItem? { didSet { oldValue?.cancel() } }

        lazy var brightnessSpline: ((Double) -> Double)? = computeBrightnessSpline(nitsMapping: nitsBrightnessMapping)
        lazy var contrastSpline: ((Double) -> Double)? = computeContrastSpline(nitsMapping: nitsContrastMapping)

        func saveNitsBrightnessMapping() {
            nitsBrightnessMappingSaver = mainAsyncAfter(ms: 200) { [weak self] in
                guard let self else { return }

                save()
                brightnessSpline = computeBrightnessSpline(nitsMapping: nitsBrightnessMapping)
                nitsBrightnessMappingSaver = nil
            }
        }

        func saveNitsContrastMapping() {
            nitsContrastMappingSaver = mainAsyncAfter(ms: 200) { [weak self] in
                guard let self else { return }

                save()
                contrastSpline = computeContrastSpline(nitsMapping: nitsContrastMapping)
                nitsContrastMappingSaver = nil
            }
        }
    #endif

    #if arch(arm64)
        var dispName = ""
        var dcpName = ""
        var displayProps: [String: Any]? {
            didSet {
                checkNitsObserver()
            }
        }

        var ioObserver: IOServicePropertyObserver?

        @Published var contrastEnhancer: Double? = nil
        @Published var lux: Double? = nil

        @Published @objc var minNits: Double = 0 {
            didSet {
                guard initialised else { return }
                guard minNits < maxNits, minNits >= 0 else {
                    minNits = minNits < 0 ? 0 : maxNits - 1
                    return
                }

                if minNits != oldValue, !isActiveSyncSource {
                    nitsRecomputePublisher.send(true)
                }
                save()
            }
        }

        func recomputeNitsMapping() {
            nitsToPercentageMapping = Self.LUX_TO_NITS.sorted(by: { $0.key < $1.key }).map { k, v in
                AutoLearnMapping(source: k, target: nitsToPercentage(v, minNits: minNits, maxNits: userMaxNits ?? maxNits) * 100)
            }
        }

        lazy var userMaxNits: Double? = getUserMaxNits() {
            didSet {
                let name = name
                let maxNits = maxNits
                let userMaxNits = userMaxNits
                debug("\(name) Max Nits: \((userMaxNits ?? maxNits).str(decimals: 2))")
                recomputeNitsMapping()
            }
        }

        lazy var userMinNits: Double? = getUserMinNits() {
            didSet {
                let name = name
                let minNits = minNits
                let userMinNits = userMinNits
                debug("\(name) Min Nits: \((userMinNits ?? minNits).str(decimals: 2))")
                recomputeNitsMapping()
            }
        }

        @Published @objc var maxNits: Double = 500 {
            didSet {
                guard initialised else { return }
                guard maxNits > minNits, maxNits > 0, maxNits <= 3000 else {
                    maxNits = maxNits > 3000 ? 3000 : oldValue
                    return
                }

                if let panel, !panel.hasPresets {
                    possibleMaxNits = maxNits
                }

//                if !hdrOn {
//                    possibleMaxNits = maxNits
//                }
                if let possibleMaxNits, possibleMaxNits > 0, let control = control as? AppleNativeControl {
                    control.updateNits()
//                    var br = Float(0); DisplayServicesGetLinearBrightness(1, &br); print("DisplayServicesGetLinearBrightness: \(br)\nMax Nits: \(maxNits)\nPossible Max Nits: \(possibleMaxNits)\nNits: \(nits ?? 0)\n")
                }

                if maxNits != oldValue, !isActiveSyncSource {
                    nitsRecomputePublisher.send(true)
                }
                save()
            }
        }

        lazy var nitsRecomputePublisher = listener(in: &observers, throttle: .milliseconds(500)) { [weak self] (_: Bool) in
            DC.computeBrightnessSplines()
            DC.computeContrastSplines()
            self?.recomputeNitsMapping()
        }

        lazy var nitsEditPublisher = listener(in: &observers, debounce: .milliseconds(500)) { [weak self] (_: Bool) in
            guard let self else { return }

            nitsBrightnessMapping = []
            nitsContrastMapping = []
            DC.computeBrightnessSplines()
            DC.computeContrastSplines()
            recomputeNitsMapping()
            readapt(newValue: false, oldValue: true)
        }

        @Published var userNits: Double? = nil
        @Published var nits: Double? = nil {
            didSet {
                if let nits, nits.isNaN || nits.isInfinite {
                    self.nits = nil
                }
                guard isActiveSyncSource else { return }
                Task.init {
                    await MainActor.run { AMI.nits = nits }
                }
            }
        }
        lazy var nitsToPercentageMapping: [AutoLearnMapping] = Self.LUX_TO_NITS.sorted(by: { $0.key < $1.key }).map { k, v in
            AutoLearnMapping(source: k, target: nitsToPercentage(v, minNits: minNits, maxNits: userMaxNits ?? maxNits) * 100)
        }
    #endif

    @Published @objc dynamic var showOrientation = false

    @Published @objc dynamic var showVolumeSlider = false
    lazy var preciseBrightnessKey = "setPreciseBrightness-\(serial)"
    lazy var preciseContrastKey = "setPreciseContrast-\(serial)"

    @Atomic var initialised = false

    var preciseContrastBeforeAppPreset = 0.5

    @objc dynamic lazy var isDummy: Bool = (
        (Self.dummyNamePattern.matches(name) || vendor.isDummy)
            && vendor != .samsung
            && !Self.notDummyNamePattern.matches(name)
    )
    @objc dynamic lazy var subzeroDimmingDisabled = isBuiltin && ((minBrightness.intValue == 0 && softwareBrightness > 0) || !presetSupportsBrightnessControl)

    var scheduledContrastTask: Repeater? = nil

    @Atomic var inSchedule = false

    @objc dynamic lazy var otherDisplays: [Display] = DC.activeDisplayList.filter { $0.serial != serial }

    @Published var userVolume = 0.5

    @objc dynamic var useAlternateInputSwitching = false

    lazy var syncSourcePriority: Int = {
        if isBuiltin {
            return 1
        }
        if panel?.isAppleProDisplay ?? false {
            return 2
        }
        if isProDisplayXDR {
            return 3
        }
        if isStudioDisplay {
            return 4
        }
        if isUltraFine {
            return 5
        }
        if isThunderbolt {
            return 6
        }
        if isLEDCinema {
            return 7
        }
        return 100
    }()

    @Published var percentage: Double? = 0.5

    var previousBrightnessMapping: ExpiringOptional<[AutoLearnMapping]> = nil
    var previousContrastMapping: ExpiringOptional<[AutoLearnMapping]> = nil
    var previousNitsBrightnessMapping: ExpiringOptional<[AutoLearnMapping]> = nil
    var previousNitsContrastMapping: ExpiringOptional<[AutoLearnMapping]> = nil

    @Published var fullRangeBrightness = 0.5
    @Published var fullRangeUserBrightness = 0.5
    @Published var userContrast = 0.5

    @objc dynamic var whitesLimit = 0.05
    @objc dynamic var blacksLimit = 0.95

    @Published @objc dynamic var applyTemporaryGamma = false

    @Atomic var gammaGetAPICalled = false
    @Atomic var gammaSetAPICalled = false

    @Published @objc dynamic var panelPresets: [MPDisplayPreset] = []

    lazy var isProDisplayXDR: Bool =
        edidName.contains(PRO_DISPLAY_XDR_NAME)

    lazy var isLunaDisplay: Bool =
        edidName.contains(LUNA_DISPLAY_NAME)

    lazy var isStudioDisplay: Bool =
        edidName.contains(STUDIO_DISPLAY_NAME)

    lazy var isUltraFine: Bool =
        edidName.contains(ULTRAFINE_NAME) && canChangeBrightnessDS

    lazy var isThunderbolt: Bool =
        edidName.contains(THUNDERBOLT_NAME)

    lazy var isLEDCinema: Bool =
        edidName.contains(LED_CINEMA_NAME)

    lazy var isCinema: Bool =
        edidName == CINEMA_NAME || edidName == CINEMA_HD_NAME

    lazy var isCinemaHD: Bool =
        edidName == CINEMA_HD_NAME

    lazy var isColorLCD: Bool =
        edidName.contains(COLOR_LCD_NAME)

    lazy var isAppleDisplay: Bool =
        isStudioDisplay || isUltraFine || isThunderbolt || isLEDCinema || isCinema || isAppleVendorID

    lazy var isAppleVendorID: Bool = ((infoDictionary["DisplayVendorID"] as? Int) ?? CGDisplayVendorNumber(id).i) == APPLE_DISPLAY_VENDOR_ID

    var lastNativeBrightness: Double? {
        get {
            mainThread { Self.lastNativeBrightnessMapping[serial] }
        }
        set {
            mainAsync { Self.lastNativeBrightnessMapping[self.serial] = newValue }
        }
    }

    @Published var presetSupportsBrightnessControl = true {
        didSet {
            subzeroDimmingDisabled = isBuiltin && ((minBrightness.intValue == 0 && softwareBrightness > 0) || !presetSupportsBrightnessControl)
        }
    }
    var gammaFeatureInUse: Bool {
        subzero || enhanced || blackOutEnabled || applyGamma || settingGamma || applyTemporaryGamma
    }

    @objc dynamic lazy var hasNotch: Bool = if #available(macOS 12.0, *), isMacBook {
        self.isBuiltin && ((self.nsScreen?.safeAreaInsets.top ?? 0) > 0 || self.panelMode?.withNotch(modes: self.panelModes) != nil)
    } else {
        false
    }

    @Published @objc dynamic var blackOutEnabled = false {
        didSet {
            guard blackOutEnabled != oldValue, isMacBook, CachedDefaults[.keyboardBacklightOffBlackout], DC.keyboardBrightnessAtStart > 0 else {
                return
            }
            if DC.keyboardAutoBrightnessEnabledByUser {
                log.debug("\(!blackOutEnabled ? "Enabling" : "Disabling") keyboard backlight auto-brightness")
                DC.kbc.enableAutoBrightness(!blackOutEnabled, forKeyboard: 1)
            }
            log.debug("Setting keyboard backlight to \(blackOutEnabled ? 0.0 : 0.5)")
            DC.kbc.setBrightness(blackOutEnabled ? 0.0 : 0.5, forKeyboard: 1)
        }
    }
    var settingShade: Bool {
        shadeWindowController?.window?.contentView?.layer?.animation(forKey: kCATransition) != nil
    }

    var schedules: [BrightnessSchedule] = Display.DEFAULT_SCHEDULES {
        didSet {
            resetScheduledTransition()
            save()
        }
    }
    var syncMappingSaver: DispatchWorkItem? { didSet { oldValue?.cancel() } }

    var sensorMappingSaver: DispatchWorkItem? { didSet { oldValue?.cancel() } }

    var locationMappingSaver: DispatchWorkItem? { didSet { oldValue?.cancel() } }

    @Published @objc dynamic var preciseBrightness = 0.5 {
        didSet {
            checkNaN(preciseBrightness)

            defer {
                fullRangeBrightness = computeFullRangeBrightness()
            }

            percentage = preciseBrightness
            guard initialised, applyPreciseValue else {
                return
            }
            resetScheduledTransition()

            if subzero, preciseBrightness > 0 {
                withoutApply {
                    if subzero { subzero = false }
                    if adaptivePaused { adaptivePaused = false }
                }
                if softwareBrightness != 1, softwareBrightness != -1 { softwareBrightness = 1 }
            } else if !subzero, preciseBrightness == 0, isAllDisplays || (!hasSoftwareControl && !noControls) {
                withoutApply { subzero = true }
            }

            var smallDiff = abs(preciseBrightness - oldValue) < 0.05
            var oldValue = oldValue

            let preciseBrightness = cap(preciseBrightness, minVal: 0.0, maxVal: 1.0).map(from: (0.0, 1.0), to: (minBrightness.doubleValue / 100.0, maxBrightness.doubleValue / 100.0))
            let brightness = (preciseBrightness * 100).intround
            guard !isAllDisplays else {
                mainThread {
                    withoutReapplyPreciseValue {
                        self.brightness = brightness.ns
                    }
                }
                return
            }

            guard !hasSoftwareControl else {
                if !smallDiff {
                    oldValue = cap(oldValue, minVal: 0.0, maxVal: 1.0).map(from: (0.0, 1.0), to: (minBrightness.doubleValue / 100.0, maxBrightness.doubleValue / 100.0))
                }
                if supportsGamma {
                    setGamma(
                        brightness: brightness.u16,
                        preciseBrightness: preciseBrightness,
                        transition: brightnessTransition
                    )
                } else {
                    shade(amount: 1.0 - preciseBrightness, smooth: !smallDiff, transition: brightnessTransition)
                }
                withoutDDC {
                    self.brightness = brightness.ns
                    self.insertBrightnessUserDataPoint(
                        DC.adaptiveMode.brightnessDataPoint.last,
                        brightness.d, modeKey: DC.adaptiveModeKey
                    )
                }
                return
            }

            guard !isNative else {
                withBrightnessTransition(smallDiff && !inSmoothTransition ? .instant : brightnessTransition) {
                    mainThread {
                        self.brightness = brightness.ns
                        self.insertBrightnessUserDataPoint(
                            DC.adaptiveMode.brightnessDataPoint.last,
                            brightness.d, modeKey: DC.adaptiveModeKey
                        )
                    }
                }
                return
            }

            smallDiff = abs(brightness - self.brightness.doubleValue.intround) < 5
            withBrightnessTransition(smallDiff && !inSmoothTransition ? .instant : brightnessTransition) {
                mainThread {
                    self.brightness = brightness.ns
                    self.insertBrightnessUserDataPoint(
                        DC.adaptiveMode.brightnessDataPoint.last,
                        brightness.d, modeKey: DC.adaptiveModeKey
                    )
                }
            }
        }
    }

    @Published @objc dynamic var preciseContrast = 0.5 {
        didSet {
//            debug("Setting precise contrast to \(preciseContrast)")
            checkNaN(preciseContrast)

            guard initialised, applyPreciseValue else { return }
            resetScheduledTransition()

            let contrast = (pow(cap(preciseContrast, minVal: 0.0, maxVal: 1.0), 0.5).map(from: (0.0, 1.0), to: (minContrast.doubleValue / 100.0, maxContrast.doubleValue / 100.0)) * 100).intround

            guard !isAllDisplays else {
                mainThread {
                    withoutReapplyPreciseValue {
                        self.contrast = contrast.ns
                    }
                }
                return
            }

            let smallDiff = abs(contrast - self.contrast.doubleValue.intround) < 5
            withBrightnessTransition(smallDiff && !inSmoothTransition ? .instant : brightnessTransition) {
                mainThread {
                    withoutReapplyPreciseValue {
                        self.contrast = contrast.ns
                    }
                    self.insertContrastUserDataPoint(
                        DC.adaptiveMode.contrastDataPoint.last,
                        contrast.d, modeKey: DC.adaptiveModeKey
                    )
                }
            }
        }
    }

    @Published @objc dynamic var preciseVolume = 0.5 {
        didSet {
            guard applyPreciseValue else { return }
            volume = (preciseVolume * 100).ns
        }
    }

    var xdrTimer: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }

    var isMacBookXDR: Bool { isMacBook && supportsEnhance }

    @Published @objc dynamic var brightness: NSNumber = 50 {
        didSet {
            checkNaN(brightness.doubleValue)

            brightnessU16 = brightness.uint16Value
            save(later: true)
            guard timeSince(lastConnectionTime) > 1 else { return }
            resetScheduledTransition()

            if applyDisplayServices { userAdjusting = true }
            defer {
                if applyDisplayServices { userAdjusting = false }
            }

            mainThread {
                withoutApplyPreciseValue {
                    preciseBrightness = brightnessToSliderValue(self.brightness)
                    if reapplyPreciseValue, !lockedBrightness || lockedContrast {
                        preciseBrightnessContrast = brightnessToSliderValue(self.brightness)
                    }
                }
                if subzero, preciseBrightness > 0 {
                    withoutApply {
                        if subzero { subzero = false }
                        if adaptivePaused { adaptivePaused = false }
                    }
                    if softwareBrightness != 1, softwareBrightness != -1 { softwareBrightness = 1 }
                } else if !subzero, preciseBrightness == 0, isAllDisplays || (!hasSoftwareControl && !noControls) {
                    withoutApply { subzero = true }
                }
            }

            guard applyDisplayServices, DDC.apply, !lockedBrightness || hasSoftwareControl, force || brightness.uint16Value != oldValue.uint16Value else {
                log.verbose(
                    "Won't apply brightness to \(description)",
                    context: [
                        "applyDisplayServices": applyDisplayServices,
                        "DDC.apply": DDC.apply,
                        "lockedBrightness": lockedBrightness,
                        "brightness != oldValue": brightness != oldValue,
                        "brightness": brightness,
                        "oldValue": oldValue,
                    ]
                )
                return
            }
            if hasSoftwareControl, !(enabledControls[.gamma] ?? false) { return }

            if !force {
                guard checkRemainingAdjustments() else { return }
            }

            guard !isForTesting else { return }

            var brightness = cap(brightness.uint16Value, minVal: minBrightness.uint16Value, maxVal: maxBrightness.uint16Value)
            var oldBrightness = cap(oldValue.uint16Value, minVal: minBrightness.uint16Value, maxVal: maxBrightness.uint16Value)

            if brightness > minBrightness.uint16Value, softwareBrightness < 1, softwareBrightness != -1 {
                softwareBrightness = 1
            } else if brightness < maxBrightness.uint16Value, softwareBrightness > 1 {
                softwareBrightness = 1
                if DC.autoXdr { xdrDisablePublisher.send(true) }
                startXDRTimer()
            } else if brightness == minBrightness.uint16Value, !subzero, !hasSoftwareControl, !noControls {
                withoutApply { subzero = true }
            } else if brightness > minBrightness.uint16Value, subzero {
                withoutApply { subzero = false }
            }

            if DDC.applyLimits, maxDDCBrightness.uint16Value != 100 || minDDCBrightness.uint16Value != 0, control is DDCControl || control is NetworkControl {
                oldBrightness = oldBrightness.d.map(from: (0, 100), to: (minDDCBrightness.doubleValue, maxDDCBrightness.doubleValue)).rounded().u16
                brightness = brightness.d.map(from: (0, 100), to: (minDDCBrightness.doubleValue, maxDDCBrightness.doubleValue)).rounded().u16
            }

            // log.info("\(name) OLD BRIGHTNESS: \(oldBrightness)")
            log.info("\(name) BRIGHTNESS: \(brightness)")
            log.traceCalls()

            if let control = control as? DDCControl {
                _ = control.setBrightnessDebounced(brightness, oldValue: oldBrightness, transition: brightnessTransition)
            } else if let control, !control.setBrightness(
                brightness,
                oldValue: oldBrightness,
                force: false,
                transition: brightnessTransition,
                onChange: nil
            ) {
                log.warning(
                    "Error writing brightness using \(control.str)",
                    context: context
                )
            }

            mainAsync { NotificationCenter.default.post(name: currentDataPointChanged, object: nil) }
        }
    }

    @Published @objc dynamic var contrast: NSNumber = 50 {
        didSet {
            checkNaN(contrast.doubleValue)

            save(later: true)
            guard timeSince(lastConnectionTime) > 1 else { return }
            resetScheduledTransition()

            userAdjusting = true
            defer {
                userAdjusting = false
            }

            if reapplyPreciseValue, contrast.uint16Value != oldValue.uint16Value {
                mainThread {
                    withoutApplyPreciseValue {
                        preciseContrast = contrastToSliderValue(self.contrast, merged: CachedDefaults[.mergeBrightnessContrast])
                        if reapplyPreciseValue, lockedBrightness, !lockedContrast {
                            preciseBrightnessContrast = contrastToSliderValue(self.contrast)
                        }
                    }
                }
            }

            guard !isBuiltin else { return }
            guard DDC.apply, !lockedContrast || DC.calibrating, force || contrast.uint16Value != oldValue.uint16Value else {
                log.verbose(
                    "Won't apply contrast to \(description)",
                    context: [
                        "DDC.apply": DDC.apply,
                        "lockedContrast": lockedContrast,
                        "contrast != oldValue": contrast != oldValue,
                        "contrast": contrast,
                        "oldValue": oldValue,
                    ]
                )
                return
            }
            if hasSoftwareControl, !(enabledControls[.gamma] ?? false) { return }

            if !force {
                guard checkRemainingAdjustments() else { return }
            }

            guard !isForTesting else { return }

            var contrast = cap(contrast.uint16Value, minVal: minContrast.uint16Value, maxVal: maxContrast.uint16Value)
            var oldContrast = cap(oldValue.uint16Value, minVal: minContrast.uint16Value, maxVal: maxContrast.uint16Value)

            if DDC.applyLimits, maxDDCContrast.uint16Value != 100 || minDDCContrast.uint16Value != 0, !hasSoftwareControl {
                oldContrast = oldContrast.d.map(from: (0, 100), to: (minDDCContrast.doubleValue, maxDDCContrast.doubleValue)).rounded().u16
                contrast = contrast.d.map(from: (0, 100), to: (minDDCContrast.doubleValue, maxDDCContrast.doubleValue)).rounded().u16
            }

            // log.info("\(name) OLD CONTRAST: \(oldContrast)")
            log.info("\(name) CONTRAST: \(contrast)")
            log.traceCalls()

            if let control = control as? DDCControl {
                _ = control.setContrastDebounced(contrast, oldValue: oldContrast, transition: brightnessTransition)
            } else if canChangeContrast, let control, !control.setContrast(contrast, oldValue: oldContrast, transition: brightnessTransition, onChange: nil) {
                log.warning(
                    "Error writing contrast using \(control.str)",
                    context: context
                )
            }

            NotificationCenter.default.post(name: currentDataPointChanged, object: nil)
        }
    }

    @Published @objc dynamic var volume: NSNumber = 10 {
        didSet {
            if oldValue.uint16Value > 0 {
                lastVolume = oldValue
            }

            save(later: true)

            applyPreciseValue = false
            preciseVolume = volume.doubleValue / 100
            applyPreciseValue = true

            guard !isForTesting else { return }

            var volume = volume.uint16Value
            if DDC.applyLimits, maxDDCVolume.uint16Value != 100 || minDDCVolume.uint16Value != 0, !hasSoftwareControl {
                volume = volume.d.map(from: (0, 100), to: (minDDCVolume.doubleValue, maxDDCVolume.doubleValue))
                    .rounded().u16
            }

            if let control, !control.setVolume(volume) {
                log.warning(
                    "Error writing volume using \(control.str)",
                    context: context
                )
            }
        }
    }

    var canChangeOrientation: Bool {
        #if DEBUG
            if isForTesting || isFakeDummy { return true }
        #endif

        return panel?.canChangeOrientation() ?? false
    }

    @objc dynamic lazy var canRotate: Bool = canChangeOrientation {
        didSet {
            rotationTooltip = canRotate ? nil : "This monitor doesn't support rotation"
            #if DEBUG
                showOrientation = CachedDefaults[.showOrientationInQuickActions] && (!isBuiltin || CachedDefaults[.showOrientationForBuiltinInQuickActions])
            #else
                showOrientation = canRotate && CachedDefaults[.showOrientationInQuickActions] && (!isBuiltin || CachedDefaults[.showOrientationForBuiltinInQuickActions])
            #endif
        }
    }

    @Published @objc dynamic var rotation = 0 {
        didSet {
            guard DDC.apply, canRotate, VALID_ROTATION_VALUES.contains(rotation) else { return }

            mainAsync { [weak self] in
                self?.reconfigure { panel in
                    guard let self else { return }

                    panel.orientation = self.rotation.i32
                    guard self.modeChangeAsk, self.rotation != oldValue,
                          let window = appDelegate!.windowController?.window ?? menuWindow
                    else { return }
                    ask(
                        message: "Orientation Change",
                        info: "Do you want to keep this orientation?\n\nLunar will revert to the last orientation if no option is selected in 15 seconds.",
                        window: window,
                        okButton: "Keep", cancelButton: "Revert",
                        onCompletion: { [weak self] keep in
                            if !keep, let self {
                                withoutModeChangeAsk {
                                    mainThread { self.rotation = oldValue }
                                }
                            }
                        }
                    )
                }
            }
            withoutDDC { [weak self] in
                self?.panelMode = self?.panel?.currentMode
                self?.modeNumber = self?.panelMode?.modeNumber ?? -1
            }
        }
    }

    // @Published var observableResolution: MPDisplayMode? = nil {
    //     didSet {
    //         guard apply else { return }
    //         panelMode = observableResolution
    //     }
    // }

    @objc dynamic lazy var panelMode: MPDisplayMode? = panel?.currentMode {
        didSet {
            guard DDC.apply, modeChangeAsk, let window = appDelegate!.windowController?.window else { return }

//            withoutApply {
//                observableResolution = panelMode
//            }

            modeNumber = panelMode?.modeNumber ?? -1
            if modeNumber != -1 {
                let onCompletion: (Bool) -> Void = { [weak self] keep in
                    guard !keep, let self else { return }

                    modeChangeAsk = false
                    setMode(oldValue)
                    modeChangeAsk = true
                }

                ask(
                    message: "Resolution Change",
                    info: "Do you want to keep this resolution?\n\nLunar will revert to the last resolution if no option is selected in 15 seconds.",
                    window: window,
                    okButton: "Keep", cancelButton: "Revert",
                    onCompletion: onCompletion
                )
            }

            setNotchState()
        }
    }

    @objc dynamic lazy var modeNumber: Int32 = panel?.currentMode?.modeNumber ?? -1 {
        didSet {
            guard modeNumber != -1, DDC.apply else { return }
            reconfigure { panel in
                panel.setModeNumber(modeNumber)
            }
        }
    }

    @Published var inputSource: VideoInputSource = .unknown {
        didSet {
            guard apply else { return }
            input = inputSource.rawValue.ns
        }
    }

    @Published @objc dynamic var input: NSNumber = VideoInputSource.unknown.rawValue.ns {
        didSet {
            save()

            guard let input = VideoInputSource(rawValue: input.uint16Value) else { return }
            withoutApply {
                inputSource = input
            }

            guard !isForTesting, input != .unknown else { return }

            if let control, !control.setInput(input) {
                log.warning(
                    "Error writing input using \(control.str)",
                    context: context
                )
            }
        }
    }

    @Published @objc dynamic var hotkeyInput1: NSNumber = VideoInputSource.unknown.rawValue.ns { didSet { save() } }
    @Published @objc dynamic var hotkeyInput2: NSNumber = VideoInputSource.unknown.rawValue.ns { didSet { save() } }
    @Published @objc dynamic var hotkeyInput3: NSNumber = VideoInputSource.unknown.rawValue.ns { didSet { save() } }

    @Published @objc dynamic var brightnessOnInputChange1 = 100.0 { didSet { save() } }
    @Published @objc dynamic var brightnessOnInputChange2 = 100.0 { didSet { save() } }
    @Published @objc dynamic var brightnessOnInputChange3 = 100.0 { didSet { save() } }
    @Published @objc dynamic var contrastOnInputChange1 = 75.0 { didSet { save() } }
    @Published @objc dynamic var contrastOnInputChange2 = 75.0 { didSet { save() } }
    @Published @objc dynamic var contrastOnInputChange3 = 75.0 { didSet { save() } }

    @Published @objc dynamic var applyBrightnessOnInputChange1 = true { didSet { save() } }
    @Published @objc dynamic var applyBrightnessOnInputChange2 = false { didSet { save() } }
    @Published @objc dynamic var applyBrightnessOnInputChange3 = false { didSet { save() } }

    @Published @objc dynamic var audioMuted = false {
        didSet {
            userMute = audioMuted ? 1 : 0
            save()

            guard !isForTesting, let control else { return }

            if applyMuteValueOnMute {
                log.info("Sending mute value \(audioMuted ? muteByteValueOn : muteByteValueOff) to \(audioMuted ? "mute" : "unmute") audio")

                if !control.setMute(audioMuted) {
                    log.warning(
                        "Error writing muted audio using \(control.str)",
                        context: context
                    )
                }
            }

            guard applyVolumeValueOnMute else { return }

            if volume != volumeValueOnMute.ns {
                lastVolume = volume
            }
            if audioMuted {
                log.info("Sending volume \(volumeValueOnMute) to mute audio")
                if !control.setVolume(volumeValueOnMute) {
                    log.warning(
                        "Error writing volume value \(volumeValueOnMute) for muted audio using \(control.str)",
                        context: context
                    )
                }
            } else {
                log.info("Setting last volume \(lastVolume) to unmute audio")
                volume = lastVolume
            }
        }
    }

    @Published @objc dynamic var power = true {
        didSet {
            save()
        }
    }

    @Published @objc dynamic var active = false {
        didSet {
            if active {
                #if arch(arm64)
                    if !oldValue {
                        DDC.rebuildDCPList()
                    }
                #endif

                startControls()
                refreshGamma()
                if supportsGamma {
                    reapplyGamma()
                } else if !supportsGammaByDefault, hasSoftwareControl {
                    shade(amount: 1.0 - preciseBrightness, transition: brightnessTransition)
                }

                if let controller = hotkeyPopoverController {
                    #if DEBUG
                        log.info("Display \(description) is now active, enabling hotkeys")
                    #endif
                    // if controller.display == nil || controller.display!.serial != serial {
                    controller.setup(from: self)
                    // }
                    if let h = controller.hotkey1, h.isEnabled { h.register() }
                    if let h = controller.hotkey2, h.isEnabled { h.register() }
                    if let h = controller.hotkey3, h.isEnabled { h.register() }
                }

                refetchPanelProps()
                if let possibleMaxNits, possibleMaxNits > 0, let control = control as? AppleNativeControl {
                    control.updateNits()
                }
            }

            if !active, let controller = hotkeyPopoverController {
                #if DEBUG
                    if !isForTesting, !isAllDisplays {
                        log.info("Display \(description) is now inactive, disabling hotkeys")
                    }
                #endif

                controller.hotkey1?.unregister()
                controller.hotkey2?.unregister()
                controller.hotkey3?.unregister()
            }

            updateCornerWindow()

            save()
            mainThread {
                activeAndResponsive = (active && responsiveDDC) || !(control is DDCControl)
                hasDDC = active && (hasI2C || hasNetworkControl)
            }
        }
    }

    var ddcWorkingCount: Int {
        get { Self.ddcWorkingCount[serial] ?? 0 }
        set { Self.ddcWorkingCount[serial] = newValue }
    }

    var ddcNotWorkingCount: Int {
        get { Self.ddcNotWorkingCount[serial] ?? 0 }
        set {
            guard !DC.screensSleeping, !DC.locked, timeSince(lastConnectionTime) >= 3 else { return }
            guard CachedDefaults[.autoRestartOnFailedDDC] else {
                Self.ddcNotWorkingCount[serial] = newValue
                return
            }

            let avoidSafetyChecks = CachedDefaults[.autoRestartOnFailedDDCSooner]
            if newValue >= 2, ddcWorkingCount >= 3,
               avoidSafetyChecks || !DC.activeDisplayList.contains(where: {
                   $0.blackOutEnabled || $0.faceLightEnabled || $0.enhanced || $0.subzero
               })
            {
                log.warning("Restarting because DDC failed")
                #if !DEBUG
                    restart()
                #endif
            }

            Self.ddcNotWorkingCount[serial] = newValue
        }
    }

    @Published @objc dynamic var responsiveDDC = true {
        didSet {
            context = getContext()
            mainThread {
                activeAndResponsive = (active && responsiveDDC) || !(control is DDCControl)
            }
        }
    }

    @Published @objc dynamic var hasI2C = false {
        didSet {
            context = getContext()
            mainThread {
                hasDDC = active && (hasI2C || hasNetworkControl)
            }
            if hasI2C != oldValue {
                control = getBestControl()
            }
        }
    }

    @Published @objc dynamic var hasNetworkControl = false {
        didSet {
            context = getContext()
            mainThread {
                hasDDC = active && (hasI2C || hasNetworkControl)
            }
            if hasNetworkControl != oldValue {
                control = getBestControl()
            }
        }
    }

    lazy var nsScreen: NSScreen? = getScreen() {
        didSet {
            setNotchState()
            let shouldShowOSD = nsScreen?.visibleFrame != oldValue?.visibleFrame && (osdWindowController?.window as? OSDWindow)?.contentView?.superview?.alphaValue == 1
            let screen = nsScreen
            mainAsync {
                self.supportsEnhance = self.getSupportsEnhance()
                if shouldShowOSD, let osd = self.osdWindowController?.window as? OSDWindow {
                    if #available(macOS 26, *) {
                        osd.show(at: macOS26OSDPoint(screen: screen), possibleWidth: MAC26_OSD_WIDTH)
                    } else {
                        osd.show(verticalOffset: 100, possibleWidth: NATIVE_OSD_WIDTH * 2)
                    }
                }
            }
        }
    }

    var secondaryMirrorScreenID: CGDirectDisplayID? {
        getSecondaryMirrorScreenID()
    }

    var audioIdentifier: String? = nil {
        didSet {
            guard audioIdentifier != nil else { return }
            mainAsync {
                DC.currentAudioDisplay = DC.getCurrentAudioDisplay()
            }
        }
    }

    var infoDictionary: NSDictionary = [:] {
        didSet {
            setAudioIdentifier(from: infoDictionary)
            if let transportType = infoDictionary["kDisplayTransportType"] as? Int {
                connection = ConnectionType.fromTransportType(transportType) ?? ConnectionType.fromTransport(transport) ?? .unknown
                log.info("\(description) connected through \(connection) connection")
            }
        }
    }

    var shadeTask: DispatchWorkItem? { didSet { oldValue?.cancel() }}
    var shouldDetectI2C: Bool { ddcEnabled && !isBuiltin && !isDummy && (forceDDC || supportsGammaByDefault) }

    var referenceEDR: CGFloat { NSScreen.forDisplayID(id)?.maximumReferenceExtendedDynamicRangeColorComponentValue ?? 1.0 }
    var potentialEDR: CGFloat { NSScreen.forDisplayID(id)?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1.0 }
    var edr: CGFloat { NSScreen.forDisplayID(id)?.maximumExtendedDynamicRangeColorComponentValue ?? 1.0 }

    lazy var hdrOn: Bool = potentialEDR > 2 && edr > 1 {
        didSet {
            guard hdrOn != oldValue else { return }
            log.debug("\(name) HDR: \(hdrOn)")
        }
    }

    var brightnessRefresher: DispatchWorkItem? { didSet { oldValue?.cancel() }}
    var contrastRefresher: DispatchWorkItem? { didSet { oldValue?.cancel() }}
    var volumeRefresher: DispatchWorkItem? { didSet { oldValue?.cancel() }}
    var inputRefresher: DispatchWorkItem? { didSet { oldValue?.cancel() }}
    var colorRefresher: DispatchWorkItem? { didSet { oldValue?.cancel() }}

    var gammaSetterTask: DispatchWorkItem? {
        didSet { oldValue?.cancel() }
    }

    @Published @objc dynamic var sendingBrightness = false {
        didSet {
            manageSendingValue(.sendingBrightness, oldValue: oldValue)
            guard sendingBrightness else {
                sendingBrightnessResetter = nil
                return
            }
            sendingBrightnessResetter = mainAsyncAfter(ms: 3000) { [weak self] in
                self?.sendingBrightness = false
            }
        }
    }

    var sendingBrightnessResetter: DispatchWorkItem? = nil {
        didSet { oldValue?.cancel() }
    }

    @Published @objc dynamic var sendingContrast = false {
        didSet {
            manageSendingValue(.sendingContrast, oldValue: oldValue)
            guard sendingContrast else {
                sendingContrastResetter = nil
                return
            }
            sendingContrastResetter = mainAsyncAfter(ms: 3000) { [weak self] in
                self?.sendingContrast = false
            }
        }
    }

    var sendingContrastResetter: DispatchWorkItem? = nil {
        didSet { oldValue?.cancel() }
    }

    @Published @objc dynamic var sendingInput = false {
        didSet {
            manageSendingValue(.sendingInput, oldValue: oldValue)
            guard sendingInput else {
                sendingInputResetter = nil
                return
            }
            sendingInputResetter = mainAsyncAfter(ms: 3000) { [weak self] in
                self?.sendingInput = false
            }
        }
    }

    var sendingInputResetter: DispatchWorkItem? = nil {
        didSet { oldValue?.cancel() }
    }

    @Published @objc dynamic var sendingVolume = false {
        didSet {
            manageSendingValue(.sendingVolume, oldValue: oldValue)
            guard sendingVolume else {
                sendingVolumeResetter = nil
                return
            }
            sendingVolumeResetter = mainAsyncAfter(ms: 3000) { [weak self] in
                self?.sendingVolume = false
            }
        }
    }

    var sendingVolumeResetter: DispatchWorkItem? = nil {
        didSet { oldValue?.cancel() }
    }

    var readableID: String {
        if name.isEmpty || name == "Unknown" {
            return shortHash(string: serial)
        }
        let safeName = "[^\\w\\d]+".r!.replaceAll(in: name.lowercased(), with: "")
        return "\(safeName)-\(shortHash(string: serial))"
    }

    @Published @objc dynamic var xdrBrightness: Float = 0.0 {
        didSet {
            guard apply else { return }
            defer {
                fullRangeBrightness = computeFullRangeBrightness()
            }

            if xdrBrightness > 0, !enhanced {
                handleEnhance(true, withoutSettingBrightness: true)
            }
            if xdrBrightness == 0, enhanced, !sliderTracking {
                handleEnhance(false)
            }

            maxEDR = computeMaxEDR()

            softwareBrightness = xdrBrightness.map(from: (0.0, 1.0), to: (Self.MIN_SOFTWARE_BRIGHTNESS, maxSoftwareBrightness))
        }
    }

    @objc dynamic var subzeroDimming: Float {
        get { min(softwareBrightness, 1.0) }
        set { softwareBrightness = cap(newValue, minVal: 0.0, maxVal: 1.0) }
    }

    @objc dynamic lazy var softwareBrightnessSlider: Float = softwareBrightness {
        didSet {
            guard apply else { return }
            forceHideSoftwareOSD = true
            softwareBrightness = softwareBrightnessSlider

            guard adaptiveSubzero else { return }

            let lastDataPoint = datapointLock.around { DC.adaptiveMode.brightnessDataPoint.last }
            insertBrightnessUserDataPoint(lastDataPoint, brightness.doubleValue, modeKey: DC.adaptiveModeKey)
        }
    }

    @Published @objc dynamic var softwareBrightness: Float = 1.0 {
        didSet {
            checkNaN(softwareBrightness)
            defer {
                fullRangeBrightness = computeFullRangeBrightness()
            }

            guard softwareBrightness <= 1.0 || (supportsGammaByDefault && supportsEnhance && enhanced) else { return }

            lastSoftwareBrightness = oldValue
            guard apply else { return }
            resetScheduledTransition()

            if softwareBrightness < 1.0, oldValue == 1.0, softwareBrightness >= 0 {
                systemAdaptiveBrightness = false
                if isMacBook, DC.kbc.brightness(forKeyboard: 1) > 0 {
                    log.debug("Setting keyboard backlight to \(0.01)")
                    DC.kbc.setBrightness(0.01, forKeyboard: 1)
                }
            } else if softwareBrightness == 1.0, oldValue < 1.0, oldValue >= 0 {
                if ambientLightCompensationEnabledByUser {
                    systemAdaptiveBrightness = true
                }
            }

            log.info("\(name) SOFT BRIGHTNESS: \(softwareBrightness.str(decimals: 2))")

            let br = softwareBrightness
            mainAsync {
                self.withoutApply {
                    self.softwareBrightnessSlider = br
                    self.subzero = br < 1.0 || (
                        br == 1.0 && !self.hasSoftwareControl &&
                            self.brightness.uint16Value == self.minBrightness.uint16Value
                    )
                    guard br > 1 else {
                        self.xdrBrightness = 0.0
                        return
                    }
                    self.xdrBrightness = br.map(from: (Self.MIN_SOFTWARE_BRIGHTNESS, self.maxSoftwareBrightness), to: (0.0, 1.0))
                }
            }

            setIndependentSoftwareBrightness(softwareBrightness, oldValue: oldValue)
        }
    }

    var preciseBrightnessContrastBeforeAppPreset = 0.5 {
        didSet {
            guard CachedDefaults[.mergeBrightnessContrast] else { return }
            preciseBrightnessBeforeAppPreset = preciseBrightnessContrastBeforeAppPreset
            preciseContrastBeforeAppPreset = preciseBrightnessContrastBeforeAppPreset
        }
    }

    var preciseBrightnessBeforeAppPreset = 0.5 {
        didSet {
            guard !CachedDefaults[.mergeBrightnessContrast] else { return }
            preciseBrightnessContrastBeforeAppPreset = preciseBrightnessBeforeAppPreset
        }
    }

    // #endif

    @Published @objc dynamic var canChangeVolume = true {
        didSet {
            showVolumeSlider = canChangeVolume && CachedDefaults[.showVolumeSlider]
            save()
        }
    }

    var noControls: Bool {
        guard let control else { return true }
        return control.isSoftware && !gammaEnabled
    }

    @objc dynamic var systemAdaptiveBrightness: Bool {
        get {
            let alc = Self.ambientLightCompensationEnabled(id)
            if alc != cachedSystemAdaptiveBrightness {
                cachedSystemAdaptiveBrightness = alc
            }
            return alc
        }
        set {
            guard ambientLightCompensationEnabledByUser || force else {
                return
            }
            if !newValue, isBuiltin {
                log.warning("Disabling system adaptive brightness")
                log.traceCalls()
            }
            DisplayServicesEnableAmbientLightCompensation(id, newValue)
            cachedSystemAdaptiveBrightness = newValue
        }
    }

    var ambientLightCompensationEnabledByUser: Bool {
        guard let enabled = Self.getThreadDictValue(id, type: "ambientLightCompensationEnabledByUser") as? Bool
        else {
            // First time checking out this flag, set it manually
            let value = systemAdaptiveBrightness
            Self.setThreadDictValue(id, type: "ambientLightCompensationEnabledByUser", value: value)
            return value
        }
        if enabled { return !adaptive }
        if systemAdaptiveBrightness {
            // User must have enabled this manually in the meantime, set it to true manually
            Self.setThreadDictValue(id, type: "ambientLightCompensationEnabledByUser", value: true)
            return true
        }
        return false
    }

    var softwareOSDTask: DispatchWorkItem? {
        didSet { oldValue?.cancel() }
    }
    var adaptiveBrightnessEnablerTask: DispatchWorkItem? {
        didSet { oldValue?.cancel() }
    }
    var zeroGammaTask: Repeater? {
        get { Self.getThreadDictValue(id, type: "zero-gamma") as? Repeater }
        set { Self.setThreadDictValue(id, type: "zero-gamma", value: newValue) }
    }

    var zeroGammaWarmupTask: Repeater? {
        get { Self.getThreadDictValue(id, type: "zero-gamma-warmup") as? Repeater }
        set { Self.setThreadDictValue(id, type: "zero-gamma-warmup", value: newValue) }
    }

    var blackOutEnforceTask: Repeater? {
        get { Self.getThreadDictValue(id, type: "blackout-enforce") as? Repeater }
        set { Self.setThreadDictValue(id, type: "blackout-enforce", value: newValue) }
    }

    var resolutionBlackoutResetterTask: Repeater? {
        get { Self.getThreadDictValue(id, type: "resolution-blackout-resetter") as? Repeater }
        set { Self.setThreadDictValue(id, type: "resolution-blackout-resetter", value: newValue) }
    }

    var testWindowController: NSWindowController? {
        get { Self.getWindowController(id, type: "test") }
        set { Self.setWindowController(id, type: "test", windowController: newValue) }
    }

    var cornerWindowControllerTopLeft: NSWindowController? {
        get { Self.getWindowController(id, type: "corner-topLeft") }
        set { Self.setWindowController(id, type: "corner-topLeft", windowController: newValue) }
    }

    var cornerWindowControllerTopRight: NSWindowController? {
        get { Self.getWindowController(id, type: "corner-topRight") }
        set { Self.setWindowController(id, type: "corner-topRight", windowController: newValue) }
    }

    var cornerWindowControllerBottomLeft: NSWindowController? {
        get { Self.getWindowController(id, type: "corner-bottomLeft") }
        set { Self.setWindowController(id, type: "corner-bottomLeft", windowController: newValue) }
    }

    @AtomicLock var brightnessDataPointInsertionTask: DispatchWorkItem? = nil {
        didSet {
            mainAsync { [weak self] in
                oldValue?.cancel()
                if let self, !self.isUserAdjusting(), let onFinishedUserAdjusting = Self.onFinishedUserAdjusting {
                    Self.onFinishedUserAdjusting = nil
                    onFinishedUserAdjusting()
                }
            }
        }
    }

    @AtomicLock var contrastDataPointInsertionTask: DispatchWorkItem? = nil {
        didSet {
            mainAsync { [weak self] in
                oldValue?.cancel()
                if let self, !self.isUserAdjusting(), let onFinishedUserAdjusting = Self.onFinishedUserAdjusting {
                    Self.onFinishedUserAdjusting = nil
                    onFinishedUserAdjusting()
                }
            }
        }
    }

    @objc dynamic var forceDDC = false {
        didSet {
            guard initialised else { return }
            context = getContext()
            resetDDC()
            save()
        }
    }

    var maxSoftwareBrightness: Float { max(maxEDR, 1.02) }
    @Published @objc dynamic var subzero = false {
        didSet {
            guard apply else { return }
            if subzero, !oldValue {
                adaptivePaused = !adaptiveSubzero
                brightnessBeforeBlackout = brightness
                contrastBeforeBlackout = contrast
                brightness = minBrightness
                contrast = minContrast
                softwareBrightness = 0.4
            }
            if !subzero, oldValue {
                if minBrightness == brightness {
                    brightness = brightnessBeforeBlackout
                }
                if minContrast == contrast {
                    contrast = contrastBeforeBlackout
                }
                softwareBrightness = 1
                adaptivePaused = false
            }
        }
    }

    @Published @objc dynamic var hasDDC = false {
        didSet {
            inputTooltip = hasDDC ? nil : "This monitor doesn't support input switching because DDC is not available"
            noDDCOrMergedBrightnessContrast = !hasDDC || CachedDefaults[.mergeBrightnessContrast]
        }
    }

    @Published @objc dynamic var useOverlay = false {
        didSet {
            if apply {
                withoutApply { dimmingMode = useOverlay ? .overlay : .gamma }
            }
            supportsGammaByDefault = !isSidecar && !isAirplay && !isVirtual && !isProjector && !isLunaDisplay
            supportsGamma = supportsGammaByDefault && !useOverlay && !NSWorkspace.shared.accessibilityDisplayShouldInvertColors
            guard initialised else { return }

            save()
            resetSoftwareControl()
            preciseBrightness = Double(preciseBrightness)

            DC.adaptBrightness(for: self, force: true)
        }
    }

    @objc dynamic var ddcEnabled: Bool {
        get { enabledControls[.ddc] ?? true }
        set {
            enabledControls[.ddc] = newValue
            guard initialised else { return }
            resetDDC()
        }
    }

    @objc dynamic var networkEnabled: Bool {
        get { enabledControls[.network] ?? true }
        set {
            enabledControls[.network] = newValue
            guard initialised else { return }
            resetNetworkController()
        }
    }

    @objc dynamic var appleNativeEnabled: Bool {
        get { enabledControls[.appleNative] ?? true }
        set {
            enabledControls[.appleNative] = newValue
            guard initialised else { return }
            resetControl()
        }
    }

    @objc dynamic var gammaEnabled: Bool {
        get { enabledControls[.gamma] ?? true }
        set {
            enabledControls[.gamma] = newValue
            guard initialised else { return }
            resetControl()
        }
    }

    @Published @objc dynamic var alwaysUseNetworkControl = false {
        didSet {
            context = getContext()
        }
    }

    @Published @objc dynamic var neverUseNetworkControl = false {
        didSet {
            context = getContext()
        }
    }

    @Published @objc dynamic var alwaysFallbackControl = false {
        didSet {
            context = getContext()
        }
    }

    @Published @objc dynamic var neverFallbackControl = false {
        didSet {
            context = getContext()
        }
    }

    @Published @objc dynamic var showVolumeOSD = true {
        didSet {
            context = getContext()
            save()
        }
    }

    var cornerWindowControllerBottomRight: NSWindowController? {
        get { Self.getWindowController(id, type: "corner-bottomRight") }
        set { Self.setWindowController(id, type: "corner-bottomRight", windowController: newValue) }
    }

    var gammaWindowController: NSWindowController? {
        get { Self.getWindowController(id, type: "gamma") }
        set { Self.setWindowController(id, type: "gamma", windowController: newValue) }
    }

    var shadeWindowController: NSWindowController? {
        get { Self.getWindowController(id, type: "shade") }
        set { Self.setWindowController(id, type: "shade", windowController: newValue) }
    }

    var hdrWindowController: NSWindowController? {
        get { Self.getWindowController(id, type: "hdr") }
        set { Self.setWindowController(id, type: "hdr", windowController: newValue) }
    }

    var xdrSetter: DispatchWorkItem? {
        didSet { oldValue?.cancel() }
    }

    var calibrationWindowController: NSWindowController? {
        get { Self.getWindowController(id, type: "calibration") }
        set { Self.setWindowController(id, type: "calibration", windowController: newValue) }
    }

    var osdWindowController: NSWindowController? {
        get { Self.getWindowController(id, type: "osd") }
        set { Self.setWindowController(id, type: "osd", windowController: newValue) }
    }

    var arrangementOsdWindowController: NSWindowController? {
        get { Self.getWindowController(id, type: "arrangementOsd") }
        set { Self.setWindowController(id, type: "arrangementOsd", windowController: newValue) }
    }

    var autoOsdWindowController: NSWindowController? {
        get { Self.getWindowController(id, type: "autoBlackoutOsd") }
        set { Self.setWindowController(id, type: "autoBlackoutOsd", windowController: newValue) }
    }

    var faceLightWindowController: NSWindowController? {
        get { Self.getWindowController(id, type: "faceLight") }
        set { Self.setWindowController(id, type: "faceLight", windowController: newValue) }
    }

    var prevSchedule: BrightnessSchedule? {
        let now = DateInRegion().convertTo(region: Region.local)
        return schedules.prefix(schedulesToConsider).filter(\.enabled).sorted().reversed().first { sch in
            guard let date = sch.dateInRegion else { return false }
            return date <= now
        }
    }

    @objc dynamic lazy var dimmingMode: DimmingMode = useOverlay ? .overlay : .gamma {
        didSet {
            guard apply else { return }

            withoutApply {
                useOverlay = dimmingMode == .overlay
            }
            if softwareBrightness < 1 {
                setIndependentSoftwareBrightness(softwareBrightness)
            }
        }
    }

    @objc dynamic lazy var adaptiveController: AdaptiveController = getAdaptiveController() {
        didSet {
            guard apply else { return }

            switch adaptiveController {
            case .disabled:
                adaptive = false
                systemAdaptiveBrightness = false
            case .lunar:
                adaptive = true
                systemAdaptiveBrightness = false
            case .system:
                adaptive = false
                withForce {
                    systemAdaptiveBrightness = true
                }
            }
        }
    }

    @objc dynamic lazy var notchEnabled: Bool = {
        guard isMacBook, hasNotch, let mode = panelMode else { return false }

        return mode.withoutNotch(modes: panelModes) != nil
    }() {
        didSet {
            guard apply, isMacBook, hasNotch, let mode = panelMode else { return }

            self.withoutModeChangeAsk {
                if notchEnabled, !oldValue, let modeWithNotch = mode.withNotch(modes: panelModes) {
                    panelMode = modeWithNotch
                    modeNumber = panelMode?.modeNumber ?? -1

                    if let cornerRadiusBeforeNotchDisable, cornerRadiusBeforeNotchDisable == 0 {
                        cornerRadius = 0
                        cornerRadiusApplier = Repeater(every: 0.1, times: 20, name: "cornerRadiusApplier") { [weak self] in
                            self?.updateCornerWindow()
                        }
                    }
                } else if !notchEnabled, oldValue, let modeWithoutNotch = mode.withoutNotch(modes: panelModes) {
                    if cornerRadiusBeforeNotchDisable == nil { cornerRadiusBeforeNotchDisable = cornerRadius }

                    panelMode = modeWithoutNotch
                    modeNumber = panelMode?.modeNumber ?? -1

                    if let cornerRadiusBeforeNotchDisable, cornerRadiusBeforeNotchDisable == 0 {
                        cornerRadius = 12
                        cornerRadiusApplier = Repeater(every: 0.1, times: 20, name: "cornerRadiusApplier") { [weak self] in
                            self?.updateCornerWindow()
                        }
                    }
                }
            }
        }
    }

    var averageDDCWriteNanoseconds: UInt64 { DC.averageDDCWriteNanoseconds[id] ?? 0 }
    var averageDDCReadNanoseconds: UInt64 { DC.averageDDCReadNanoseconds[id] ?? 0 }

    var alternativeControlForAppleNative: Control? = nil {
        didSet {
            context = getContext()
            if let control = alternativeControlForAppleNative {
                log.debug(
                    "Display got alternativeControlForAppleNative \(control.str)",
                    context: context
                )
                mainAsyncAfter(ms: 1) { [weak self] in
                    guard let self else { return }
                    self.hasNetworkControl = control is NetworkControl || self.alternativeControlForAppleNative is NetworkControl
                    self.canChangeContrast = self.usesDDCBrightnessControl || (self.isNative && (self.alternativeControlForAppleNative?.isDDC ?? false))
                }
            }
        }
    }

    var ddcNotWorking: Bool {
        active && ddcEnabled && (control == nil || (control is GammaControl && !(enabledControls[.gamma] ?? false)))
    }

    var autoRestartOnNoControlsTask: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }

    @AtomicLock var control: Control? = nil {
        didSet {
            guard !isAllDisplays else { return }

            if !unmanaged, control == nil, Defaults[.autoRestartOnNoControls], !isForTesting, enabledControls.contains(where: \.value) {
                let name = self.name
                autoRestartOnNoControlsTask = mainAsyncAfter(ms: 3000) {
                    log.warning("No control found for display \(name), restarting")
                    #if !DEBUG
                        restart()
                    #endif
                }
            } else {
                autoRestartOnNoControlsTask = nil
            }

            context = getContext()
            mainAsync {
                self.supportsEnhance = self.getSupportsEnhance()
                if self.control is DDCControl {
                    self.ddcWorkingCount = self.ddcWorkingCount + 1
                    self.ddcNotWorkingCount = 0
                }
            }

            if ddcNotWorking, !DC.displays.isEmpty, isOnline {
                ddcNotWorkingCount = ddcNotWorkingCount + 1
            }

            if !(control is NetworkControl) {
                resetSendingValues()
            }

            guard let control, !control.isSoftware || gammaEnabled else {
                usesDDCBrightnessControl = false
                hasSoftwareControl = false
                hasNetworkControl = false
                isNative = false
                canChangeContrast = false

                return
            }
            usesDDCBrightnessControl = control is DDCControl || control is NetworkControl
            hasSoftwareControl = control.isSoftware
            isNative = control is AppleNativeControl

            if isNative {
                mainAsync { [weak self] in
                    self?.startBrightnessContrastRefreshers()
                }
            }

            log.debug("Display got \(control.str)", context: context)
            mainAsync { [weak self] in
                guard let self else { return }
                self.activeAndResponsive = (self.active && self.responsiveDDC) || !(self.control is DDCControl)
                self.hasNetworkControl = self.control is NetworkControl || self.alternativeControlForAppleNative is NetworkControl
            }

            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: FLUX_IDENTIFIER).first {
                GammaControl.fluxChecker(flux: app)
            }
            if let oldValue, !oldValue.isSoftware, control.isSoftware {
                setGamma()
            }

            if isNative {
                alternativeControlForAppleNative = getBestAlternativeControlForAppleNative()
            }
            canChangeContrast = usesDDCBrightnessControl || (isNative && (alternativeControlForAppleNative?.isDDC ?? false))
            onControlChange?(control)
        }
    }

    var defaultGammaChanged: Bool {
        defaultGammaRedMin.floatValue != 0 ||
            defaultGammaRedMax.floatValue != 1 ||
            defaultGammaRedValue.floatValue != 1 ||
            defaultGammaGreenMin.floatValue != 0 ||
            defaultGammaGreenMax.floatValue != 1 ||
            defaultGammaGreenValue.floatValue != 1 ||
            defaultGammaBlueMin.floatValue != 0 ||
            defaultGammaBlueMax.floatValue != 1 ||
            defaultGammaBlueValue.floatValue != 1
    }

    var vendor: Vendor {
        #if DEBUG
            if id == TEST_DISPLAY_PERSISTENT2_ID { return .lg }
        #endif
        let vendorID = (infoDictionary[kDisplayVendorID] as? Int64) ?? (CGDisplayVendorNumber(id).i64)
        guard let v = Vendor(rawValue: vendorID) else {
            return .unknown
        }
        return v
    }

    var hasBrightnessChangeObserver: Bool { Self.isObservingBrightnessChangeDS(id) }

    var displaysInMirrorSet: [Display]? {
        guard isInMirrorSet else { return nil }
        return DC.activeDisplayList.filter { d in
            d.id == id || d.primaryMirrorScreen?.displayID == id || d.secondaryMirrorScreenID == id
        }
    }

    var primaryMirror: Display? {
        guard let id = primaryMirrorScreen?.displayID else { return nil }
        return DC.activeDisplays[id]
    }

    var secondaryMirror: Display? {
        guard let id = secondaryMirrorScreenID else { return nil }
        return DC.activeDisplays[id]
    }

    var isWiredInWirelessSet: Bool {
        guard DC.connectedDisplayCount == 2, let other = otherDisplays.first else { return false }

        return !self.isDummy && self.supportsGammaByDefault && !other.supportsGammaByDefault
    }

    var isInHardwareMirrorSet: Bool {
        guard isInMirrorSet else { return false }

        if let primary = getPrimaryMirrorScreen() {
            return !primary.isDummy
        }
        return true
    }

    var isInNonWirelessHardwareMirrorSet: Bool {
        guard isInMirrorSet else { return false }
        if DC.connectedDisplayCount == 2, let other = secondaryMirror,
           other.supportsGammaByDefault, !self.supportsGammaByDefault, other.blackOutEnabled
        {
            return false
        }

        if let primary = getPrimaryMirrorScreen() {
            return !primary.isDummy
        }
        return true
    }

    var isInDummyMirrorSet: Bool {
        guard isInMirrorSet else { return false }

        if isDummy { return true }
        if let primary = primaryMirrorScreen {
            return primary.isDummy
        }
        if let secondary = secondaryMirrorScreenID {
            return DDC.isDummyDisplay(secondary)
        }
        return false
    }

    var isIndependentDummy: Bool {
        isDummy && !isInMirrorSet
    }

    @objc dynamic var extendedColorGain = false {
        didSet {
            maxColorGain = extendedColorGain ? 255 : 100
        }
    }

    var onlySoftwareDimmingEnabled: Bool { !ddcEnabled && !networkEnabled && !appleNativeEnabled }

    var supportsVolumeControl: Bool {
        #if DEBUG
            if isForTesting || isFakeDummy { return true }
        #endif

        guard let control, !hasSoftwareControl else { return false }
        if isNative, let alternativeControl = alternativeControlForAppleNative {
            return alternativeControl is DDCControl || alternativeControl is NetworkControl
        }
        return control is DDCControl || control is NetworkControl
    }

    @objc dynamic lazy var main: Bool = CGDisplayIsMain(id) != 0 {
        didSet {
            guard main, apply, let mainDisplay = DC.mainDisplay, mainDisplay.id != id else {
                return
            }

            let success = Display.configure { config in
                if let mainDisplayBounds = mainDisplay.nsScreen?.bounds, mainDisplayBounds.origin == .zero, let displayBounds = nsScreen?.bounds {
                    CGConfigureDisplayOrigin(config, mainDisplay.id, -displayBounds.origin.x.intround.i32, -displayBounds.origin.y.intround.i32)
                }
                return CGConfigureDisplayOrigin(config, id, 0, 0) == .success
            }

            if success {
                for display in otherDisplays {
                    display.main = false
                }
            } else {
                for display in DC.activeDisplayList {
                    display.withoutApply {
                        display.main = CGDisplayIsMain(id) != 0
                    }
                }
            }
        }
    }

    @Published @objc dynamic var enhanced = false {
        didSet {
            guard apply else { return }
            handleEnhance(enhanced)
        }
    }

    @Published @objc dynamic var fullRange = false {
        didSet {
            guard apply, supportsFullRangeXDR else { return }

            if !fullRange, oldValue, (brightness.uint16Value > minBrightness.uint16Value && brightness.uint16Value < maxBrightness.uint16Value) || softwareBrightness == Self
                .MIN_SOFTWARE_BRIGHTNESS
            {
                hideSoftwareOSD()
            }

            if handleFullRange(fullRange) {
                save()
            }
        }
    }

    var schedulesToConsider: Int {
        if CachedDefaults[.showFiveSchedules] { return 5 }
        if CachedDefaults[.showFourSchedules] { return 4 }
        if CachedDefaults[.showThreeSchedules] { return 3 }
        if CachedDefaults[.showTwoSchedules] { return 2 }
        return 1
    }

    var currentSchedule: BrightnessSchedule? {
        let now = DateInRegion().convertTo(region: Region.local)
        return schedules.prefix(schedulesToConsider).filter(\.enabled).sorted().first { sch in
            guard let (hour, minute) = sch.getHourMinute() else { return false }
            return hour == now.hour && minute == now.minute
        }
    }

    var nextSchedule: BrightnessSchedule? {
        let now = DateInRegion().convertTo(region: Region.local)
        return schedules.prefix(schedulesToConsider).filter(\.enabled).sorted().first { sch in
            guard let date = sch.dateInRegion else { return false }
            return date >= now
        }
    }

//    deinit {
//        #if DEBUG
//            log.verbose("START DEINIT: \(description)")
//            log.verbose("popover: \(_hotkeyPopover)")
//            log.verbose("INPUT_HOTKEY_POPOVERS: \(INPUT_HOTKEY_POPOVERS.map { "\($0.key): \($0.value)" })")
//            do { log.verbose("END DEINIT: \(description)") }
//        #endif
//    }

    var isInMirrorSet: Bool {
        CGDisplayIsInMirrorSet(id) != 0 && (DisplayController.initialized ? DC.cachedOnlineDisplayIDs : Set(NSScreen.onlineDisplayIDs)).count > 1
    }

    lazy var panel: MPDisplay? = DisplayController.panel(with: id) {
        didSet {
            refetchPanelProps()
        }
    }

    var id: CGDirectDisplayID {
        get { _idLock.around { _id } }
        set { _idLock.around { _id = newValue } }
    }

    @objc dynamic var serial: String {
        didSet {
            save()
        }
    }

    @Published @objc dynamic var name: String {
        didSet {
            context = getContext()
            save()
        }
    }

    @Published @objc dynamic var applyGamma = false {
        didSet {
            save()
            if !applyGamma {
                lunarGammaTable = nil
                if gammaSetAPICalled {
                    restoreColorSyncSettings(reapplyGammaFor: otherDisplays.filter(\.gammaSetAPICalled))
                    lastGammaTable = nil
                }
                gammaChanged = false
            } else {
                reapplyGamma()
            }

            if hasSoftwareControl {
                DC.adaptBrightness(for: self, force: true)
            } else {
                if applyGamma || gammaChanged {
                    resetSoftwareControl()
                }
                readapt(newValue: applyGamma, oldValue: oldValue)
            }
        }
    }

    @Published @objc dynamic var adaptivePaused = false {
        didSet {
            readapt(newValue: adaptivePaused, oldValue: oldValue)
        }
    }

    var shouldAdapt: Bool { adaptive && !adaptivePaused && !cachedSystemAdaptiveBrightness && !noControls && !DC.screensSleeping && (!DC.locked || DC.allowAdjustmentsWhileLocked) }
    @Published @objc dynamic var adaptive: Bool {
        didSet {
            save()
            readapt(newValue: adaptive, oldValue: oldValue)
            guard hasAmbientLightAdaptiveBrightness || (systemAdaptiveBrightness && adaptive) else { return }
            systemAdaptiveBrightness = !adaptive
        }
    }

    @Published @objc dynamic var defaultGammaRedMin: NSNumber = 0.0 {
        didSet {
            save()
            reapplyGamma()
        }
    }

    @Published @objc dynamic var defaultGammaRedMax: NSNumber = 1.0 {
        didSet {
            save()
            reapplyGamma()
        }
    }

    @Published @objc dynamic var defaultGammaRedValue: NSNumber = 1.0 {
        didSet {
            save()
            reapplyGamma()
        }
    }

    @Published @objc dynamic var defaultGammaGreenMin: NSNumber = 0.0 {
        didSet {
            save()
            reapplyGamma()
        }
    }

    @Published @objc dynamic var defaultGammaGreenMax: NSNumber = 1.0 {
        didSet {
            save()
            reapplyGamma()
        }
    }

    @Published @objc dynamic var defaultGammaGreenValue: NSNumber = 1.0 {
        didSet {
            save()
            reapplyGamma()
        }
    }

    @Published @objc dynamic var defaultGammaBlueMin: NSNumber = 0.0 {
        didSet {
            save()
            reapplyGamma()
        }
    }

    @Published @objc dynamic var defaultGammaBlueMax: NSNumber = 1.0 {
        didSet {
            save()
            reapplyGamma()
        }
    }

    @Published @objc dynamic var defaultGammaBlueValue: NSNumber = 1.0 {
        didSet {
            save()
            reapplyGamma()
        }
    }

    @Published @objc dynamic var cornerRadius: NSNumber = 0 {
        didSet {
            save()
            updateCornerWindow()
        }
    }

    @objc dynamic var blacks = 0.0 {
        didSet {
            defaultGammaRedMin = blacks.ns
            defaultGammaGreenMin = blacks.ns
            defaultGammaBlueMin = blacks.ns
            whitesLimit = 1.0 - ((1.0 - blacks) * 0.95)
        }
    }

    @objc dynamic var whites = 1.0 {
        didSet {
            defaultGammaRedMax = whites.ns
            defaultGammaGreenMax = whites.ns
            defaultGammaBlueMax = whites.ns
            blacksLimit = whites * 0.95
        }
    }

    @objc dynamic var red = 0.5 {
        didSet {
            defaultGammaRedValue = Self.sliderValueToGammaValue(red).ns
        }
    }

    @objc dynamic var green = 0.5 {
        didSet {
            defaultGammaGreenValue = Self.sliderValueToGammaValue(green).ns
        }
    }

    @objc dynamic var blue = 0.5 {
        didSet {
            defaultGammaBlueValue = Self.sliderValueToGammaValue(blue).ns
        }
    }

    @Published @objc dynamic var redGain: NSNumber = DEFAULT_COLOR_GAIN.ns {
        didSet {
            save()
            guard DDC.apply else { return }
            if let control, !control.setRedGain(redGain.uint16Value) {
                log.warning(
                    "Error writing RedGain using \(control.str)",
                    context: context
                )
            }
        }
    }

    @Published @objc dynamic var greenGain: NSNumber = DEFAULT_COLOR_GAIN.ns {
        didSet {
            save()
            guard DDC.apply else { return }
            if let control, !control.setGreenGain(greenGain.uint16Value) {
                log.warning(
                    "Error writing GreenGain using \(control.str)",
                    context: context
                )
            }
        }
    }

    @Published @objc dynamic var blueGain: NSNumber = DEFAULT_COLOR_GAIN.ns {
        didSet {
            save()
            guard DDC.apply else { return }
            if let control, !control.setBlueGain(blueGain.uint16Value) {
                log.warning(
                    "Error writing BlueGain using \(control.str)",
                    context: context
                )
            }
        }
    }

    @Published @objc dynamic var maxDDCBrightness: NSNumber = 100 {
        didSet {
            save()
            readapt(newValue: maxDDCBrightness, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var maxDDCContrast: NSNumber = 100 {
        didSet {
            save()
            readapt(newValue: maxDDCContrast, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var maxDDCVolume: NSNumber = 100 {
        didSet {
            save()
            readapt(newValue: maxDDCVolume, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var minDDCBrightness: NSNumber = 0 {
        didSet {
            save()
            readapt(newValue: minDDCBrightness, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var minDDCContrast: NSNumber = 0 {
        didSet {
            save()
            readapt(newValue: minDDCContrast, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var minDDCVolume: NSNumber = 0 {
        didSet {
            save()
            readapt(newValue: minDDCVolume, oldValue: oldValue)
        }
    }

    @objc dynamic var faceLightBrightness: NSNumber = 100 {
        didSet {
            save()
            readapt(newValue: faceLightBrightness, oldValue: oldValue)
        }
    }

    @objc dynamic var faceLightContrast: NSNumber = 90 {
        didSet {
            save()
            readapt(newValue: faceLightContrast, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var lockedBrightness = false {
        didSet {
            log.debug("Locked brightness for \(description)")
            save()
        }
    }

    @Published @objc dynamic var lockedContrast = true {
        didSet {
            log.debug("Locked contrast for \(description)")
            save()
        }
    }

    @Published @objc dynamic var lockedBrightnessCurve = false {
        didSet {
            save()
        }
    }

    @Published @objc dynamic var lockedContrastCurve = false {
        didSet {
            save()
        }
    }

    @Published @objc dynamic var minBrightness: NSNumber = DEFAULT_MIN_BRIGHTNESS.ns {
        didSet {
            subzeroDimmingDisabled = isBuiltin && minBrightness.intValue == 0 && softwareBrightness > 0
            save()
            preciseMinBrightness = minBrightness.doubleValue / 100
            readapt(newValue: minBrightness, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var maxBrightness: NSNumber = DEFAULT_MAX_BRIGHTNESS.ns {
        didSet {
            save()
            preciseMaxBrightness = maxBrightness.doubleValue / 100
            readapt(newValue: maxBrightness, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var minContrast: NSNumber = DEFAULT_MIN_CONTRAST.ns {
        didSet {
            save()
            preciseMinContrast = minContrast.doubleValue / 100
            readapt(newValue: minContrast, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var maxContrast: NSNumber = DEFAULT_MAX_CONTRAST.ns {
        didSet {
            save()
            preciseMaxContrast = maxContrast.doubleValue / 100
            readapt(newValue: maxContrast, oldValue: oldValue)
        }
    }

    var limitedBrightness: UInt16 {
        guard control is DDCControl || control is NetworkControl, maxDDCBrightness.uint16Value != 100 || minDDCBrightness.uint16Value != 0 else {
            return brightness.uint16Value
        }
        return brightness.doubleValue.map(from: (0, 100), to: (minDDCBrightness.doubleValue, maxDDCBrightness.doubleValue)).rounded().u16
    }

    var limitedContrast: UInt16 {
        guard maxDDCContrast.uint16Value != 100 || minDDCContrast.uint16Value != 0 else {
            return contrast.uint16Value
        }
        return contrast.doubleValue.map(from: (0, 100), to: (minDDCContrast.doubleValue, maxDDCContrast.doubleValue)).rounded().u16
    }

    var limitedVolume: UInt16 {
        guard maxDDCVolume.uint16Value != 100 || minDDCVolume.uint16Value != 0 else {
            return volume.uint16Value
        }
        return volume.doubleValue.map(from: (0, 100), to: (minDDCVolume.doubleValue, maxDDCVolume.doubleValue)).rounded().u16
    }

    var isActiveSyncSource: Bool { DC.sourceDisplay.serial == serial }

    var gammaDelayerTask: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }

    lazy var possibleMaxNits: Double? = ISCLI ? nil : panel?.activePreset?.maxSDRNits ?? panel?.activePreset?.maxHDRNits {
        didSet {
            if possibleMaxNits == nil || possibleMaxNits == 0 || possibleMaxNits == 1600, apply {
                mainAsyncAfter(ms: 1000) { [weak self] in
                    guard let self else { return }
                    self.withoutApply {
                        self.possibleMaxNits = self.panel?.activePreset?.maxSDRNits ?? self.panel?.activePreset?.maxHDRNits
                    }
                }
            }
            guard let possibleMaxNits, possibleMaxNits > 0, let control = control as? AppleNativeControl else {
                return
            }
            control.updateNits()
        }
    }
    #if DEBUG
        @objc dynamic var isFakeDummy: Bool { Self.notDummyNamePattern.matches(name) && vendor.isDummy }
    #else
        @objc dynamic lazy var isFakeDummy: Bool = (Self.notDummyNamePattern.matches(name) && vendor.isDummy)
    #endif
    #if arch(arm64)
        var disconnected: Bool { DisplayController.possiblyDisconnectedDisplays[id]?.serial == serial }
    #else
        var disconnected = false
    #endif

    @Published @objc dynamic var isSource: Bool {
        didSet {
            context = getContext()
            DC.sourceDisplay = DC.getSourceDisplay()
            guard Self.applySource else { return }
            Self.applySource = false
            defer {
                Self.applySource = true
            }

            if isSource {
                DC.activeDisplayList.filter { $0.id != id }.forEach { d in
                    d.isSource = false
                }
            } else if let builtinDisplay = DC.builtinDisplay, builtinDisplay.serial != serial {
                builtinDisplay.isSource = true
            } else if let smartDisplay = DC.externalActiveDisplays.first(where: { $0.hasAmbientLightAdaptiveBrightness && $0.serial != serial }) {
                smartDisplay.isSource = true
            }

            datastore.storeDisplays(DC.displayList)
            SyncMode.refresh()
            if DC.adaptiveModeKey == .sync {
                DC.adaptiveMode.stopWatching()
                DC.adaptiveMode.watch()
            }
        }
    }

    var softwareAdjustedBrightness: Int {
        if !hasSoftwareControl, softwareBrightness < 1 {
            return softwareBrightness.map(from: (0, 1), to: (-100, 0)).intround
        }
        return (preciseBrightness * 100).intround
    }

    var softwareAdjustedBrightnessIfAdaptive: Double {
        if !hasSoftwareControl, adaptiveSubzero, softwareBrightness < 1 {
            return softwareBrightness.map(from: (0, 1), to: (-100, 0)).d
        }
        return preciseBrightness * 100
    }

    var smoothGammaQueue: DispatchQueue {
        switch control {
        case is DDCControl:
            smoothDDCQueue
        case is AppleNativeControl:
            smoothDisplayServicesQueue
        default:
            serialQueue
        }
    }

    @Published @objc dynamic var preciseBrightnessContrast = 0.5 {
        didSet {
            checkNaN(preciseBrightnessContrast)

            guard initialised, applyPreciseValue else {
                return
            }
            resetScheduledTransition()

            if subzero, preciseBrightnessContrast > 0 {
                withoutApply {
                    if subzero { subzero = false }
                    if adaptivePaused { adaptivePaused = false }
                }
                if softwareBrightness != 1, softwareBrightness != -1 { softwareBrightness = 1 }
            } else if !subzero, preciseBrightnessContrast == 0, isAllDisplays || (!hasSoftwareControl && !noControls) {
                withoutApply { subzero = true }
            }

            let (brightness, contrast) = sliderValueToBrightnessContrast(preciseBrightnessContrast)
            guard !isAllDisplays else {
                mainThread {
                    withoutReapplyPreciseValue {
                        self.brightness = brightness.ns
                        self.contrast = contrast.ns
                    }
                }
                return
            }

            var smallDiff = abs(brightness.i - self.brightness.doubleValue.intround) < 5
            if !lockedBrightness || hasSoftwareControl {
                withBrightnessTransition(smallDiff && !inSmoothTransition ? .instant : brightnessTransition) {
                    mainThread {
                        withoutReapplyPreciseValue {
                            self.brightness = brightness.ns
                        }
                        self.insertBrightnessUserDataPoint(
                            DC.adaptiveMode.brightnessDataPoint.last,
                            brightness.d, modeKey: DC.adaptiveModeKey
                        )
                    }
                }
            }

            if !lockedContrast || DC.calibrating {
                smallDiff = abs(contrast.i - self.contrast.doubleValue.intround) < 5
                withBrightnessTransition(smallDiff && !inSmoothTransition ? .instant : brightnessTransition) {
                    mainThread {
                        withoutReapplyPreciseValue {
                            self.contrast = contrast.ns
                        }
                        self.insertContrastUserDataPoint(
                            DC.adaptiveMode.contrastDataPoint.last,
                            contrast.d, modeKey: DC.adaptiveModeKey
                        )
                    }
                }
            }
        }
    }

    @Atomic var userAdjusting = false {
        didSet {
            mainAsync { [weak self] in
                if let self, !self.isUserAdjusting(), let onFinishedUserAdjusting = Self.onFinishedUserAdjusting {
                    Self.onFinishedUserAdjusting = nil
                    onFinishedUserAdjusting()
                }
            }
        }
    }

    @objc dynamic var isTV: Bool {
        (panel?.isTV ?? false) && edidName.contains("TV")
    }

    @objc dynamic var isLG: Bool { vendor == .lg }

    var edidName: String {
        didSet {
            normalizedName = Self.numberNamePattern.replaceAll(in: edidName, with: "").trimmed
        }
    }

    @Published @objc dynamic var unmanaged = false {
        didSet {
            guard unmanaged else {
                DC.displays = DC.displays
                readapt(newValue: unmanaged, oldValue: oldValue)
                return
            }

            if xdr {
                xdr = false
            }
            if subzero {
                subzero = false
            }
            if facelight {
                facelight = false
            }
            if blackOutEnabled {
                resetBlackOut()
            }

            DC.displays = DC.displays

            if gammaSetAPICalled {
                resetGamma()
            }
            shadeWindowController?.close()
            shadeWindowController = nil
        }
    }

    @Published @objc dynamic var adaptiveSubzero = true {
        didSet {
            #if arch(arm64)
                DC.computeBrightnessSplines()
            #endif

            resetScheduledTransition()
            readapt(newValue: adaptiveSubzero, oldValue: oldValue)
            if !adaptiveSubzero, DC.adaptiveModeKey != .manual, softwareBrightness < 1, softwareBrightness != -1 {
                softwareBrightness = 1
            }
        }
    }

    var primaryMirrorScreen: NSScreen? {
        getPrimaryMirrorScreen()
    }

    @objc dynamic var facelight: Bool {
        get { faceLightEnabled }
        set {
            if newValue {
                appDelegate?.enableFaceLight(display: self)
            } else {
                appDelegate?.disableFaceLight(displays: [self])
                disableFaceLight()
            }

            faceLightEnabled = newValue
        }
    }

    @objc dynamic var blackout: Bool {
        get { blackOutEnabled }
        set {
            DC.blackOut(
                display: id, state: newValue ? .on : .off,
                mirroringAllowed: DC.connectedDisplayCount == 1 ? false : blackOutMirroringAllowed
            )
            blackOutEnabled = newValue
        }
    }

    var isOnline: Bool { NSScreen.isOnline(id) }

    lazy var maxEDR = computeMaxEDR() {
        didSet {
            xdrFilledChicletOffset = 6 / (96 * (1 / (maxSoftwareBrightness - Self.MIN_SOFTWARE_BRIGHTNESS)))
            xdrFilledChicletsThresholds = (0 ... 16).map { Self.MIN_SOFTWARE_BRIGHTNESS + xdrFilledChicletOffset * $0.f }
        }
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Display else {
            return false
        }
        return serial == other.serial
    }

    static func ambientLightCompensationEnabled(_ id: CGDirectDisplayID) -> Bool {
        guard !isGeneric(id), DisplayServicesHasAmbientLightCompensation(id) else { return false }

        var enabled = false
        DisplayServicesAmbientLightCompensationEnabled(id, &enabled)
        return enabled
    }

    static func isObservingBrightnessChangeDS(_ id: CGDirectDisplayID) -> Bool {
        mainThread { Thread.current.threadDictionary["observingBrightnessChangeDS-\(id)"] as? Bool } ?? false
    }

    static func observeBrightnessChangeDS(_ id: CGDirectDisplayID) -> Bool {
        guard !isGeneric(id), DisplayServicesCanChangeBrightness(id), !isObservingBrightnessChangeDS(id), !CachedDefaults[.disableBrightnessObservers] else {
            let reason = if isGeneric(id) {
                "generic"
            } else if !DisplayServicesCanChangeBrightness(id) {
                "cannot change brightness"
            } else if isObservingBrightnessChangeDS(id) {
                "already observing"
            } else {
                "brightness observers disabled"
            }
            DS_LOGGER.debug("Ignoring brightness change observer for \(id, privacy: .public). Reason: \(reason, privacy: .public)")
            return true
        }

        let result = DisplayServicesRegisterForBrightnessChangeNotifications(id, id) { _, observer, _, _, userInfo in
            guard !DC.screensSleeping, !DC.locked || DC.allowAdjustmentsWhileLocked, !AppleNativeControl.sliderTracking else {
                let reason = DC.screensSleeping ? "screens sleeping" : DC.locked ? "locked" : "dragging slider"
                DS_LOGGER.debug("Ignoring brightness change notification. Reason: \(reason, privacy: .public)")
                return
            }

            let obs = String(describing: observer)
            let id = CGDirectDisplayID(UInt(bitPattern: observer))

            OperationQueue.main.addOperation {
                guard let value = (userInfo as NSDictionary?)?["value"] as? Double else {
                    DS_LOGGER.debug("Invalid brightness change notification: \(userInfo as NSDictionary?, privacy: .public) observer: \(obs, privacy: .public)")
                    return
                }

                guard let display = DC.activeDisplays[id] else {
                    let reason = "display not found"
                    DS_LOGGER.debug("Ignoring brightness change notification. Reason: \(reason, privacy: .public)")
                    return
                }
                display.lastNativeBrightness = value

                guard !display.inSmoothTransition, !display.isBuiltin || !DC.lidClosed else {
                    let reason = if DC.activeDisplays[id]?.inSmoothTransition ?? false {
                        "in smooth transition"
                    } else if DC.activeDisplays[id]?.isBuiltin ?? false {
                        "lid closed"
                    } else {
                        "not builtin"
                    }
                    DS_LOGGER.debug("Ignoring brightness change notification. Reason: \(reason, privacy: .public)")
                    return
                }

                let newBrightness = (value * 100).u16
                guard display.brightnessU16 != newBrightness else {
                    DS_LOGGER.debug("Ignoring brightness change notification. Reason: same brightness (\(newBrightness, privacy: .public))")
                    return
                }

                DS_LOGGER.debug("newBrightness: \(newBrightness, privacy: .public) display.isUserAdjusting: \(display.isUserAdjusting(), privacy: .public)")

                display.withoutDisplayServices {
                    display.brightness = newBrightness.ns
                }
                if display.subzero, newBrightness > 0 {
                    display.withoutApply {
                        display.subzero = false
                        if display.adaptivePaused { display.adaptivePaused = false }
                    }
                    if display.softwareBrightness != 1, display.softwareBrightness != -1 { display.softwareBrightness = 1 }
                }

                if let control = display.control as? AppleNativeControl {
                    control.updateNits()
                }
            }
        }
        mainThread { Thread.current.threadDictionary["observingBrightnessChangeDS-\(id)"] = (result == KERN_SUCCESS) }

        return result == KERN_SUCCESS
    }

    static func getThreadDictValue(_ id: CGDirectDisplayID, type: String) -> Any? {
        windowControllerQueue.sync { Thread.current.threadDictionary["\(type)-\(id)"] }
    }

    static func setThreadDictValue(_ id: CGDirectDisplayID, type: String, value: Any?) {
        windowControllerQueue.sync { Thread.current.threadDictionary["\(type)-\(id)"] = value }
    }

    static func getWindowController(_ id: CGDirectDisplayID, type: String) -> NSWindowController? {
        windowControllerQueue.sync { Thread.current.threadDictionary["window-\(type)-\(id)"] as? NSWindowController }
    }

    static func setWindowController(_ id: CGDirectDisplayID, type: String, windowController: NSWindowController?) {
        windowControllerQueue.sync { Thread.current.threadDictionary["window-\(type)-\(id)"] = windowController }
    }

    static func printableName(_ id: CGDirectDisplayID) -> String {
        #if DEBUG
            switch id {
            case TEST_DISPLAY_ID:
                return "LG Ultra HD"
            case TEST_DISPLAY_PERSISTENT_ID:
                return "DELL U3419W"
            case TEST_DISPLAY_PERSISTENT2_ID:
                return "LG Ultrafine"
            case TEST_DISPLAY_PERSISTENT3_ID:
                return "Pro Display XDR"
            case TEST_DISPLAY_PERSISTENT4_ID:
                return "Thunderbolt"
            default:
                break
            }
        #endif

        if DDC.isBuiltinDisplay(id, checkName: false) {
            return "Built-in"
        }

        if DDC.isSidecarDisplay(id, checkName: false) {
            return "Sidecar"
        }

        if let screen = NSScreen.forDisplayID(id) {
            return screen.localizedName
        }

        if let infoDict = displayInfoDictionary(id), let names = infoDict["DisplayProductName"] as? [String: String],
           let name = names[Locale.current.identifier] ?? names["en_US"] ?? names.first?.value
        {
            return name
        }

        return "Unknown"
    }

    static func uuid(id: CGDirectDisplayID) -> String {
        #if DEBUG
            switch id {
            case TEST_DISPLAY_ID:
                return "TEST_DISPLAY_SERIAL"
            case TEST_DISPLAY_PERSISTENT_ID:
                return "TEST_DISPLAY_PERSISTENT_SERIAL"
            case TEST_DISPLAY_PERSISTENT2_ID:
                return "TEST_DISPLAY_PERSISTENT2_SERIAL"
            case TEST_DISPLAY_PERSISTENT3_ID:
                return "TEST_DISPLAY_PERSISTENT3_SERIAL"
            case TEST_DISPLAY_PERSISTENT4_ID:
                return "TEST_DISPLAY_PERSISTENT4_SERIAL"
            default:
                break
            }
        #endif

        if let uuid = CGDisplayCreateUUIDFromDisplayID(id) {
            let uuidValue = uuid.takeRetainedValue()
            let uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuidValue) as String
            return uuidString
        }
        if let edid = Display.edid(id: id) {
            return edid
        }
        return String(describing: id)
    }

    static func edid(id: CGDirectDisplayID) -> String? {
        DDC.getEdidData(displayID: id)?.map { $0 }.str(hex: true)
    }

    static func insertDataPoint(
        values: inout ThreadSafeDictionary<Double, Double>,
        featureValue: Double,
        targetValue: Double,
        logValue: Bool = true
    ) {
        guard DC.adaptiveModeKey != .manual else {
            return
        }

        let featureValue = featureValue.rounded(to: 4)
        for (x, y) in values.snapshot() {
            if (x < featureValue && y >= targetValue) || (x > featureValue && y <= targetValue) {
                if logValue {
                    log.debug("Removing data point \(x) => \(y)")
                }
                values.removeValue(forKey: x)
            }
        }
        if logValue {
            log.debug("Adding data point \(featureValue) => \(targetValue)")
        }
        values[featureValue] = targetValue
    }

    static func getSecondaryMirrorScreenID(_ id: CGDirectDisplayID) -> CGDirectDisplayID? {
        guard displayIsInMirrorSet(id),
              let secondaryID = NSScreen.onlineDisplayIDs.first(where: { CGDisplayMirrorsDisplay($0) == id })
        else { return nil }
        return secondaryID
    }

    static func getPrimaryMirrorScreen(_ id: CGDirectDisplayID) -> NSScreen? {
        guard displayIsInMirrorSet(id),
              let primaryID = NSScreen.onlineDisplayIDs.first(where: { CGDisplayMirrorsDisplay(id) == $0 })
        else { return nil }
        return NSScreen.screens.first(where: { screen in screen.hasDisplayID(primaryID) })
    }

    static func sliderValueToGammaValue(_ value: Double) -> Double {
        if value == 0.5 {
            return 1.0
        }
        if value > 0.5 {
            return value.map(from: (0.5, 1.0), to: (1.0, 0.0))
        }

        return value.map(from: (0.0, 0.5), to: (3.0, 1.0))
    }

    static func gammaValueToSliderValue(_ value: Double) -> Double {
        if value == 1.0 {
            return 0.5
        }
        if value < 1.0 {
            return value.map(from: (0.0, 1.0), to: (1.0, 0.5))
        }

        return value.map(from: (1.0, 3.0), to: (0.5, 0.0))
    }

    static func reconfigure(tries: Int = 20, _ action: (MPDisplayMgr) -> Void) {
        guard let manager = DisplayController.panelManager, DisplayController.tryLockManager(tries: tries) else {
            return
        }

        manager.notifyWillReconfigure()
        action(manager)
        manager.notifyReconfigure()
        manager.unlockAccess()
    }

    static func reconfigure(panel: MPDisplay, tries: Int = 20, _ action: (MPDisplay) -> Void) {
        guard let manager = DisplayController.panelManager, DisplayController.tryLockManager(tries: tries) else {
            return
        }

        manager.notifyWillReconfigure()
        action(panel)
        manager.notifyReconfigure()
        manager.unlockAccess()
    }

    @discardableResult
    static func configure(_ action: (CGDisplayConfigRef) -> Bool) -> Bool {
        var configRef: CGDisplayConfigRef?
        var err = CGBeginDisplayConfiguration(&configRef)
        guard err == .success, let config = configRef else {
            log.error("Error with CGBeginDisplayConfiguration: \(err)")
            return false
        }

        guard action(config) else {
            _ = CGCancelDisplayConfiguration(config)
            return false
        }

        err = CGCompleteDisplayConfiguration(config, .permanently)
        guard err == .success else {
            log.error("Error with CGCompleteDisplayConfiguration")
            _ = CGCancelDisplayConfiguration(config)
            return false
        }

        return true
    }

    static func insertElevationDataPoint(_ mapping: AutoLearnMapping, in values: [AutoLearnMapping]) -> [AutoLearnMapping]? {
        guard let solar = LocationMode.specific.geolocation?.solar,
              let noon = solar.solarNoonPosition?.elevation,
              mapping.source < 0 || mapping.source > noon
        else {
            return nil
        }

        var values = values
        if mapping.source < 0, mapping.target > -100 {
            values = Display.insertDataPoint([-18: mapping.target - 0.01], in: values, cliffRatio: 3, cliffSourceDiff: 5)
        }

        if mapping.source > noon {
            values = Display.insertDataPoint([noon: mapping.target], in: values, cliffRatio: 3, cliffSourceDiff: 5)
        }

        return values
    }

    func getPanelModes() -> [MPDisplayMode] {
        guard let modes = panel?.allModes(), !modes.isEmpty else {
            return []
        }

        let grouped = Dictionary(grouping: modes, by: \.refreshRate).sorted(by: { $0.key >= $1.key })
        return Array(grouped.map { $0.value.sorted(by: { $0.dotsPerInch <= $1.dotsPerInch }).reversed() }.joined())

    }

    func refetchPanelPresetProps() {
        guard let panel, panel.hasPresets else { return }

        DDC.skipNextIORegistryChange = true
        panel.buildPresetsList()
        panelPresets = panel.presets
        referencePreset = panel.activePreset

        if !supportsFullRangeXDR {
            supportsFullRangeXDR = getSupportsFullRangeXDR()
        } else if isBuiltin, !DC.builtinSupportsFullRangeXDR {
            DC.builtinSupportsFullRangeXDR = true
        }

        if supportsFullRangeXDR, getSupportsFullRangeXDR() {
            withoutApply {
                fullRange = panel.xdrEnabled
            }
        }

        presetSupportsBrightnessControl = panel.supportsBrightnessControl
        if let preset = panel.activePreset {
            setMaxNits(from: preset)
        }
    }

    func refetchPanelProps() {
        panelPropsRefetcher = Repeater(every: 1, times: 5, name: "Panel Props Refetcher") { [weak self] in
            guard let self else { return }
            #if DEBUG
                canRotate = isForTesting || panel?.canChangeOrientation() ?? false
            #else
                canRotate = panel?.canChangeOrientation() ?? false
            #endif

            isSidecar = DDC.isSidecarDisplay(id, name: edidName)
            isAirplay = DDC.isAirplayDisplay(id, name: edidName)
            isVirtual = DDC.isVirtualDisplay(id, name: edidName)
            isProjector = DDC.isProjectorDisplay(id, name: edidName)
            supportsGamma = supportsGammaByDefault && !useOverlay && !NSWorkspace.shared.accessibilityDisplayShouldInvertColors
            supportsGammaByDefault = !isSidecar && !isAirplay && !isVirtual && !isProjector && !isLunaDisplay
            refetchPanelPresetProps()
        }
    }

    func setMode(_ mode: MPDisplayMode?) {
        mainThread {
            self.panelMode = mode
            self.modeNumber = mode?.modeNumber ?? -1
        }
    }

    func brightnessCurveMapping(_ modeKey: AdaptiveModeKey? = nil) -> [AutoLearnMapping] {
        switch modeKey ?? DC.adaptiveModeKey {
        case .sync:
            syncBrightnessMapping[DC.sourceDisplay.serial] ?? []
        case .sensor:
            sensorBrightnessMapping
        case .location:
            locationBrightnessMapping
        default:
            []
        }
    }

    func contrastCurveMapping(_ modeKey: AdaptiveModeKey? = nil) -> [AutoLearnMapping] {
        switch modeKey ?? DC.adaptiveModeKey {
        case .sync:
            syncContrastMapping[DC.sourceDisplay.serial] ?? []
        case .sensor:
            sensorContrastMapping
        case .location:
            locationContrastMapping
        default:
            []
        }
    }

    func updateCornerWindow() {
        mainThread {
            guard cornerRadius.intValue > 0, active, !isInNonWirelessHardwareMirrorSet,
                  !isIndependentDummy, let screen = nsScreen ?? primaryMirrorScreen
            else {
                cornerWindowControllerTopLeft?.close()
                cornerWindowControllerTopRight?.close()
                cornerWindowControllerBottomLeft?.close()
                cornerWindowControllerBottomRight?.close()
                cornerWindowControllerTopLeft = nil
                cornerWindowControllerTopRight = nil
                cornerWindowControllerBottomLeft = nil
                cornerWindowControllerBottomRight = nil
                return
            }

            let create: (inout NSWindowController?, ScreenCorner) -> Void = { wc, corner in
                createWindow(
                    "cornerWindowController",
                    controller: &wc,
                    screen: screen,
                    show: true,
                    backgroundColor: .clear,
                    level: .hud,
                    stationary: true,
                    corner: corner,
                    size: NSSize(width: 50, height: 50)
                )
                if let wc = wc as? CornerWindowController {
                    wc.corner = corner
                    wc.display = self
                }
            }

            create(&cornerWindowControllerTopLeft, .topLeft)
            create(&cornerWindowControllerTopRight, .topRight)
            create(&cornerWindowControllerBottomLeft, .bottomLeft)
            create(&cornerWindowControllerBottomRight, .bottomRight)
        }
    }

    func setNotchState() {
        mainAsync {
            if #available(macOS 12.0, *), self.isMacBook {
                self.hasNotch = (self.nsScreen?.safeAreaInsets.top ?? 0) > 0 || self.panelMode?.withNotch(modes: self.panelModes) != nil
            } else {
                self.hasNotch = false
            }

            guard self.isMacBook, self.hasNotch, let mode = self.panelMode else { return }

            self.withoutApply {
                self.notchEnabled = mode.withoutNotch(modes: self.panelModes) != nil
            }
        }
    }

    func observeBrightnessChangeDS() -> Bool {
        Self.observeBrightnessChangeDS(id)
    }

    func sliderValueToBrightness(_ brightness: PreciseBrightness) -> NSNumber {
        (cap(brightness, minVal: 0.0, maxVal: 1.0).map(from: (0.0, 1.0), to: (minBrightness.doubleValue / 100.0, maxBrightness.doubleValue / 100.0)) * 100).intround.ns
    }

    func sliderValueToContrast(_ contrast: PreciseContrast) -> NSNumber {
        (cap(contrast, minVal: 0.0, maxVal: 1.0).map(from: (0.0, 1.0), to: (minContrast.doubleValue / 100.0, maxContrast.doubleValue / 100.0)) * 100).intround.ns
    }

    func brightnessToSliderValue(_ brightness: NSNumber) -> PreciseBrightness {
        cap(brightness.doubleValue, minVal: 0, maxVal: 100).map(from: (minBrightness.doubleValue, maxBrightness.doubleValue), to: (0, 100)) / 100.0
    }

    func contrastToSliderValue(_ contrast: NSNumber, merged: Bool = true) -> PreciseContrast {
        let c = cap(contrast.doubleValue, minVal: 0, maxVal: 100).map(from: (minContrast.doubleValue, maxContrast.doubleValue), to: (0, 100)) / 100.0

        return merged ? pow(c, 2) : c
    }

    func sliderValueToBrightnessContrast(_ value: Double) -> (Brightness, Contrast) {
        var br = brightness.uint16Value
        var cr = contrast.uint16Value

        if !lockedBrightness || hasSoftwareControl {
            let brd = (cap(value, minVal: 0.0, maxVal: 1.0).map(from: (0.0, 1.0), to: (minBrightness.doubleValue / 100.0, maxBrightness.doubleValue / 100.0)) * 100)
            br = brd.isNaN ? br : brd.intround.u16
        }
        if !lockedContrast {
            let crd = (pow(cap(value, minVal: 0.0, maxVal: 1.0), 0.5).map(from: (0.0, 1.0), to: (minContrast.doubleValue / 100.0, maxContrast.doubleValue / 100.0)) * 100)
            cr = crd.isNaN ? cr : crd.intround.u16
        }

        return (br, cr)
    }

    func saveSyncMapping() {
        syncMappingSaver = mainAsyncAfter(ms: 200) { [weak self] in
            self?.save()
            self?.syncMappingSaver = nil
        }
    }

    func saveSensorMapping() {
        sensorMappingSaver = mainAsyncAfter(ms: 1000) { [weak self] in
            self?.save()
            self?.sensorMappingSaver = nil
        }
    }

    func saveLocationMapping() {
        locationMappingSaver = mainAsyncAfter(ms: 2000) { [weak self] in
            self?.save()
            self?.locationMappingSaver = nil
        }
    }

    func resetSendingValues() {
        mainAsync { [weak self] in
            self?.sendingBrightness = false
            self?.sendingContrast = false
            self?.sendingInput = false
            self?.sendingVolume = false
        }
    }

    func refetchScreens() {
        nsScreen = getScreen()
    }

    func getPowerOffEnabled(hasDDC: Bool? = nil) -> Bool {
        guard active else { return false }
        if blackOutEnabled { return true }

        return (
            DC.activeDisplays.count > 1 ||
                CachedDefaults[.allowBlackOutOnSingleScreen] ||
                (hasDDC ?? self.hasDDC)
        ) && !isDummy
    }

    func getPowerOffTooltip(hasDDC: Bool? = nil) -> String {
        #if arch(arm64)
            let disconnect: Bool = if #available(macOS 13, *) {
                CachedDefaults[.newBlackOutDisconnect] && !DC.displayLinkRunning
            } else {
                false
            }
        #else
            let disconnect = false
        #endif

        guard !(hasDDC ?? self.hasDDC) else {
            return """
            \(
                disconnect
                    ? "BlackOut disconnects a monitor in software, freeing up GPU resources and removing it from the screen arrangement."
                    : "BlackOut simulates a monitor power off by mirroring the contents of the other visible screen to this one and setting this monitor's brightness to absolute 0."
            )

            Can also be toggled with the keyboard using Ctrl-Cmd-6.

            Hold the following keys while clicking the button (or while pressing the hotkey) to change BlackOut behaviour:
            - Shift: make the screen black without \(disconnect ? "disconnecting" : "mirroring")
            - Option: turn off monitor completely using DDC
            - Option and Shift: BlackOut other monitors and keep this one visible

            Caveats for DDC power off:
              • works only if the monitor can be controlled through DDC
              • can't be used to power on the monitor
              • when a monitor is turned off or in standby, it does not accept commands from a connected device
              • remember to keep holding the Option key for 2 seconds after you pressed the button to account for possible DDC delays

            Emergency Kill Switch: press the ⌘ Command key more than 8 times in a row to force disable BlackOut.
            """
        }
        guard DC.activeDisplays.count > 1 || CachedDefaults[.allowBlackOutOnSingleScreen] else {
            return """
            At least 2 screens need to be visible for this to work.

            The option can also be enabled for a single screen in Advanced settings.
            """
        }

        return """
        \(
            disconnect
                ? "BlackOut disconnects a monitor in software, freeing up GPU resources and removing it from the screen arrangement."
                : "BlackOut simulates a monitor power off by mirroring the contents of the other visible screen to this one and setting this monitor's brightness to absolute 0."
        )

        Can also be toggled with the keyboard using Ctrl-Cmd-6.

        Hold the following keys while clicking the button (or while pressing the hotkey) to change BlackOut behaviour:
        - Shift: make the screen black without \(disconnect ? "disconnecting" : "mirroring")
        - Option and Shift: BlackOut other monitors and keep this one visible

        Emergency Kill Switch: press the ⌘ Command key more than 8 times in a row to force disable BlackOut.
        """
    }

    func powerOn() {
        DC.blackOut(
            display: id,
            state: .off,
            mirroringAllowed: blackOutMirroringAllowed
        )
    }

    func powerOff() {
        guard DC.activeDisplays.count > 1 || CachedDefaults[.allowBlackOutOnSingleScreen] else { return }

        if hasDDC, KM.optionKeyPressed, !KM.shiftKeyPressed {
            _ = control?.setPower(.off)
            return
        }

        guard proactive else {
            if let url = URL(string: "https://lunar.fyi/#blackout") {
                NSWorkspace.shared.open(url)
            }
            return
        }

        if KM.optionKeyPressed, KM.shiftKeyPressed, DC.activeDisplayCount > 1 {
            let blackOutEnabled = otherDisplays.contains(where: \.blackOutEnabled)
            for otherDisplay in otherDisplays {
                lastBlackOutToggleDate = .distantPast
                DC.blackOut(
                    display: otherDisplay.id,
                    state: blackOutEnabled ? .off : .on,
                    mirroringAllowed: false
                )
            }
            return
        }

        #if arch(arm64)
            if DC.connectedDisplayCount > 1 {
                let shouldDisconnect: Bool = if CachedDefaults[.newBlackOutDisconnect], !DC.displayLinkRunning, !isWiredInWirelessSet {
                    !KM.commandKeyPressed
                } else {
                    KM.commandKeyPressed
                }

                if #available(macOS 13, *), !KM.shiftKeyPressed, !blackOutEnabled, DC.connectedDisplayCount > 1, shouldDisconnect {
                    DC.dis(id)
                    return
                }
            }
        #endif

        DC.blackOut(
            display: id,
            state: blackOutEnabled ? .off : .on,
            mirroringAllowed: !KM.shiftKeyPressed && blackOutMirroringAllowed && DC.connectedDisplayCount > 1
        )
    }

    func setAudioIdentifier(from dict: NSDictionary) {
        #if !arch(arm64)
            guard let prefsKey = dict["IODisplayPrefsKey"] as? String,
                  let match = AUDIO_IDENTIFIER_UUID_PATTERN.findFirst(in: prefsKey),
                  let g1 = match.group(at: 1), let g2 = match.group(at: 2), let g3 = match.group(at: 3)
            else { return }
            audioIdentifier = "\(g2)\(g1)-\(g3)".uppercased()
        #endif
    }

    func initHotkeyPopoverController() -> HotkeyPopoverController? {
        guard !ISCLI else { return nil }
        return mainThread {
            guard let popover = _hotkeyPopover else {
                _hotkeyPopover = NSPopover()
                if let popover = _hotkeyPopover, popover.contentViewController == nil, let stb = NSStoryboard.main,
                   let controller = stb.instantiateController(
                       withIdentifier: NSStoryboard.SceneIdentifier("HotkeyPopoverController")
                   ) as? HotkeyPopoverController
                {
                    INPUT_HOTKEY_POPOVERS[serial] = _hotkeyPopover
                    popover.contentViewController = controller
                    popover.contentViewController!.loadView()
                }

                return _hotkeyPopover?.contentViewController as? HotkeyPopoverController
            }
            return popover.contentViewController as? HotkeyPopoverController
        }
    }

    func computeFullRangeBrightness() -> Double {
        if softwareBrightness < 1 {
            return softwareBrightness.d.map(from: (0, 1), to: (-1, 0))
        }
        if xdrBrightness > 0 {
            return xdrBrightness.d.map(from: (0, 1), to: (1, 2))
        }
        return preciseBrightness
    }

    func resetScheduledTransition() {
        guard !inSchedule else { return }
        if scheduledBrightnessTask != nil { scheduledBrightnessTask = nil }
        if scheduledContrastTask != nil { scheduledContrastTask = nil }
    }

    func resetSubZero() {
        if softwareBrightness < 1, softwareBrightness != -1 {
            forceHideSoftwareOSD = true
            softwareBrightness = 1
        }
        if subzero {
            withoutApply { subzero = false }
        }
    }

    func getScreen() -> NSScreen? {
        guard !isForTesting else { return nil }
        return NSScreen.screens.first(where: { screen in screen.hasDisplayID(id) })
    }

    func getSecondaryMirrorScreenID() -> CGDirectDisplayID? {
        guard !isForTesting else { return nil }
        return Self.getSecondaryMirrorScreenID(id)
    }

    func getPrimaryMirrorScreen() -> NSScreen? {
        guard !isForTesting else { return nil }
        return Self.getPrimaryMirrorScreen(id)
    }

    func refreshPanel() {
        withoutModeChangeAsk {
            withoutDDC { [weak self] in
                guard let self else { return }

                rotation = CGDisplayRotation(id).intround

                guard let mgr = DisplayController.panelManager else { return }
                panel = mgr.display(withID: id.i32)

                panelMode = panel?.currentMode
                modeNumber = panel?.currentMode?.modeNumber ?? -1
                panelModes = getPanelModes()
                panelModeTitles = panelModes.map(\.attributedString)
                if let preset = panel?.activePreset {
                    setMaxNits(from: preset)
                }
            }
        }
    }

    func reapplySoftwareControl() {
        guard hasSoftwareControl || softwareBrightness < 1 else {
            resetSoftwareControl()
            return
        }

        if supportsGamma {
            reapplyGamma()
        } else if !supportsGammaByDefault || softwareBrightness < 1 {
            shade(amount: 1.0 - preciseBrightness, transition: brightnessTransition)
        }
    }

    func shade(amount: Double, smooth: Bool = true, force: Bool = false, transition: BrightnessTransition? = nil) {
        log.debug("Shading \(description) by \(amount)")
        guard let screen = nsScreen ?? primaryMirrorScreen, force || (
            !isInNonWirelessHardwareMirrorSet && !isIndependentDummy &&
                timeSince(lastConnectionTime) >= 1 || onlySoftwareDimmingEnabled
        )
        else {
            var reasons: [String] = []
            if nsScreen == nil {
                reasons.append("nsScreen == nil")
            }
            if primaryMirrorScreen == nil {
                reasons.append("primaryMirrorScreen == nil")
            }
            if isInNonWirelessHardwareMirrorSet {
                reasons.append("isInNonWirelessHardwareMirrorSet")
            }
            if isIndependentDummy {
                reasons.append("isIndependentDummy")
            }
            if timeSince(lastConnectionTime) < 1, !onlySoftwareDimmingEnabled {
                reasons.append("timeSince(lastConnectionTime) < 1")
            }
            log.debug("Ignoring shade for \(description), reasons: \(reasons.joined(separator: ", "))")
            shadeWindowController?.close()
            shadeWindowController = nil
            return
        }

        shadeTask = nil
        mainThread {
            let brightnessTransition = transition ?? brightnessTransition
            let windowAlreadyOpen = shadeWindowController?.window != nil

            if !windowAlreadyOpen {
                createWindow(
                    "shadeWindowController",
                    controller: &shadeWindowController,
                    screen: screen,
                    show: true,
                    backgroundColor: .clear,
                    level: .hud,
                    fillScreen: true,
                    stationary: true
                )

                if let w = shadeWindowController?.window {
                    w.ignoresMouseEvents = true
                    w.contentView?.wantsLayer = true

                    w.contentView?.alphaValue = 0.0
                    w.contentView?.bg = NSWorkspace.shared.accessibilityDisplayShouldInvertColors ? NSColor.white : NSColor.black
                    w.contentView?.setNeedsDisplay(w.frame)
                }
            }
            guard let w = shadeWindowController?.window else { return }

            let frame = screen.frame
            w.setFrameOrigin(CGPoint(x: frame.minX, y: frame.minY))
            w.setFrame(frame, display: false)

            let delay = brightnessTransition == .slow ? 2.0 : 0.6
            if smooth { w.contentView?.transition(delay) }
            if amount == 2 {
                w.contentView?.alphaValue = 1
            } else if windowAlreadyOpen {
                w.contentView?.alphaValue = cap(amount, minVal: 0.0, maxVal: 1.0).map(from: (0.0, 1.0), to: (0.01, 0.85))
            } else {
                shadeTask = mainAsyncAfter(ms: 10) {
                    w.contentView?.alphaValue = cap(amount, minVal: 0.0, maxVal: 1.0).map(from: (0.0, 1.0), to: (0.01, 0.85))
                }
            }

            if amount <= 0.01, smooth {
                shadeTask = mainAsyncAfter(ms: (delay * 1000).intround + 100) { [weak self] in
                    guard let self else { return }
                    log.verbose("Removing shade for \(self.description)")
                    self.shadeWindowController?.close()
                    self.shadeWindowController = nil
                }
            }
        }
    }

    func resetSoftwareControl() {
        guard active else { return }
        log.verbose("Resetting software dimming")
        log.traceCalls()
        if gammaSetAPICalled || applyGamma || applyTemporaryGamma {
            resetGamma()
        }
        shadeWindowController?.close()
        shadeWindowController = nil
        mainAsync { [weak self] in
            guard let self else { return }
            self.withoutApply {
                self.softwareBrightness = self.softwareBrightness
            }
        }
    }

    func reconfigure(_ action: (MPDisplay) -> Void) {
        guard let panel else { return }
        Self.reconfigure(panel: panel, action)
    }

    func reapplyGamma() {
        if defaultGammaChanged, applyGamma || applyTemporaryGamma {
            refreshGamma()
        } else {
            lunarGammaTable = nil
        }

        if hasSoftwareControl {
            setGamma(transition: inSmoothTransition ? brightnessTransition : .instant)
        } else if applyGamma || applyTemporaryGamma, !blackOutEnabled {
            resetSoftwareControl()
        }
    }

    func manageSendingValue(_ key: CodingKeys, oldValue _: Bool) {
        let name = key.rawValue
        let conditionName = name.replacingOccurrences(of: "sending", with: "sent") + "Condition"
        guard let value = value(forKey: name) as? Bool,
              let condition = self.value(forKey: conditionName) as? NSCondition
        else {
            log.error("No condition property found for \(name)")
            return
        }

        if !value {
            condition.broadcast()
        } else {
            sendingValuePublisher.send(name)
        }
    }

    func getContext() -> [String: Any] {
        [
            "connected": active,
            "name": name,
            "id": id,
            "serial": serial,
            "control": control?.str ?? "Unknown",
            "alternativeControlForAppleNative": alternativeControlForAppleNative?.str ?? "Unknown",
            "hasI2C": hasI2C,
            "hasNetworkControl": hasNetworkControl,
            "alwaysFallbackControl": alwaysFallbackControl,
            "neverFallbackControl": neverFallbackControl,
            "alwaysUseNetworkControl": alwaysUseNetworkControl,
            "neverUseNetworkControl": neverUseNetworkControl,
            "isAppleDisplay": isAppleDisplay,
            "isSource": isSource,
            "showVolumeOSD": showVolumeOSD,
            "forceDDC": forceDDC,
            "applyGamma": applyGamma,
        ]
    }

    func getBestControl(reapply: Bool = true) -> Control {
        guard !DC.screensSleeping, timeSince(wakeTime) > 1 else {
            return self.control ?? GammaControl(display: self)
        }
        if appleNativeEnabled {
            let appleNativeControl = AppleNativeControl(display: self)
            if appleNativeControl.isAvailable() {
                if reapply, softwareBrightness == 1.0, applyGamma || applyTemporaryGamma || gammaChanged, gammaEnabled {
                    if !blackOutEnabled, !faceLightEnabled, !settingGamma, !settingShade, !inSmoothTransition {
                        resetSoftwareControl()
                    }
                    appleNativeControl.reapply()
                }
                enabledControls[.gamma] = false
                return appleNativeControl
            }
        }

        if !isBuiltin, supportsGammaByDefault || isFakeDummy, ddcEnabled {
            let ddcControl = DDCControl(display: self)
            if ddcControl.isAvailable() {
                if reapply, softwareBrightness == 1.0, applyGamma || gammaChanged, gammaEnabled {
                    if !blackOutEnabled, !faceLightEnabled, !settingGamma, !settingShade, !inSmoothTransition {
                        resetSoftwareControl()
                    }
                    ddcControl.reapply()
                }
                enabledControls[.gamma] = false
                return ddcControl
            }
        }

        if !isBuiltin, networkEnabled {
            let networkControl = NetworkControl(display: self)
            if networkControl.isAvailable() {
                if reapply, softwareBrightness == 1.0, applyGamma || applyTemporaryGamma || gammaChanged, gammaEnabled {
                    if !blackOutEnabled, !faceLightEnabled, !settingGamma, !settingShade, !inSmoothTransition {
                        resetSoftwareControl()
                    }
                    networkControl.reapply()
                }
                enabledControls[.gamma] = false
                return networkControl
            }
        }

        return GammaControl(display: self)
    }

    func getBestAlternativeControlForAppleNative() -> Control? {
        if !isBuiltin, supportsGammaByDefault, ddcEnabled {
            let ddcControl = DDCControl(display: self)
            if ddcControl.isAvailable() {
                return ddcControl
            }
        }

        if !isBuiltin, networkEnabled {
            let networkControl = NetworkControl(display: self)
            if networkControl.isAvailable() {
                return networkControl
            }
        }

        return nil
    }

    func startControls() {
        guard !isGeneric(id) else { return }
        ensureAudioIdentifier()

        if CachedDefaults[.refreshValues] {
            mainAsync { [weak self] in
                guard let self else { return }
                self.refreshBrightness()
                self.refreshContrast()
                self.refreshVolume()
                // self.refreshInput()
                self.refreshColors()
            }
        }
        refreshGamma()

        detectI2C()
        startI2CDetection()

        control = getBestControl()
        if let control, control.isSoftware {
            mainAsyncAfter(ms: 5001) { [weak self] in
                guard let self, self.hasSoftwareControl,
                      self.enabledControls[.gamma] ?? false, self.preciseBrightness > 0 else { return }
                self.preciseBrightness = Double(self.preciseBrightness)
            }
        }

        startBrightnessContrastRefreshers()
    }

    func startBrightnessContrastRefreshers() {
        guard isNative else { return }

        let listensForBrightnessChange = observeBrightnessChangeDS() && hasBrightnessChangeObserver
        if listensForBrightnessChange {
            nativeBrightnessRefresher = nil
        } else if !CachedDefaults[.disableBrightnessObservers] {
            nativeBrightnessRefresher = nativeBrightnessRefresher ?? Repeater(every: 2, name: "\(name) Brightness Refresher") { [weak self] in
                guard let self, !DC.screensSleeping, !DC.locked, self.isNative else {
                    return
                }
                self.refreshBrightness()
            }
        }
        // nativeContrastRefresher = nativeContrastRefresher ?? Repeater(every: 15, name: "\(name) Contrast Refresher") { [weak self] in
        //     guard let self, !DC.screensSleeping, self.isNative else {
        //         return
        //     }

        //     self.refreshContrast()
        // }
        #if arch(arm64)
            if isBuiltin, ioObserver == nil {
                dispName = "disp0"
                observeIO(dispName: "disp0")
            }
        #endif
    }

    func matchesEDIDUUID(_ edidUUID: String) -> Bool {
        let uuids = possibleEDIDUUIDs()
        guard !uuids.isEmpty else {
            log.info("No EDID UUID pattern to test with \(edidUUID) for display \(self)")
            return false
        }

        return uuids.contains { uuid in
            guard let uuidPattern = uuid.r else { return false }
            log.info("Testing EDID UUID pattern \(uuid) with \(edidUUID) for display \(self)")

            let matched = uuidPattern.matches(edidUUID)
            if matched {
                log.info("Matched EDID UUID pattern \(uuid) with \(edidUUID) for display \(self)")
            }
            return matched
        }
    }

    func possibleEDIDUUIDs() -> [String] {
        guard !isSidecar, !isAirplay, !isVirtual, !isDummy, !isProjector, !isForTesting else { return [] }

        let infoDict = (displayInfoDictionary(id) ?? infoDictionary).dictionaryWithValues(forKeys: [
            kDisplaySerialNumber,
            kDisplayProductID,
            kDisplayWeekOfManufacture,
            kDisplayYearOfManufacture,
            kDisplayHorizontalImageSize,
            kDisplayVerticalImageSize,
            kDisplayVendorID,
        ])
        guard let productID = infoDict[kDisplayProductID] as? Int64,
              let vendorID = infoDict[kDisplayVendorID] as? Int64,
              let verticalPixels = infoDict[kDisplayVerticalImageSize] as? Int64,
              let horizontalPixels = infoDict[kDisplayHorizontalImageSize] as? Int64
        else { return [] }

        let manufactureYear = (infoDict[kDisplayYearOfManufacture] as? Int64) ?? 0
        let manufactureWeek = (infoDict[kDisplayWeekOfManufacture] as? Int64) ?? 0
        let yearByte = cap(manufactureYear >= 1990 ? manufactureYear - 1990 : manufactureYear, minVal: 0, maxVal: 255).u8.hex.uppercased()
        let weekByte = cap(manufactureWeek, minVal: 0, maxVal: 255).u8.hex.uppercased()
        let vendorBytes = (vendorID & UINT16_MAX.i64).u16.str(reversed: true, separator: "").uppercased()
        let productBytes = (productID & UINT16_MAX.i64).u16.str(reversed: false, separator: "").uppercased()
        // let serialBytes = serialNumber.u32.str(reversed: false, separator: "").uppercased()
        let verticalBytes = (verticalPixels / 10).u8.hex.uppercased()
        let horizontalBytes = (horizontalPixels / 10).u8.hex.uppercased()

        let transportType = (infoDict["kDisplayTransportType"] as? Int64) ?? 0
        let transportByte = (transportType == 3 ? "03" : "04")

        return [
            "\(vendorBytes)\(productBytes)-0000-0000-\(weekByte)\(yearByte)-01\(transportByte)[\\dA-F]{2}\(horizontalBytes)\(verticalBytes)[\\dA-F]{2}",
            "\(vendorBytes)\(productBytes)-0000-0000-\(weekByte)\(yearByte)-[\\dA-F]{6}\(horizontalBytes)\(verticalBytes)[\\dA-F]{2}",
            "\(vendorBytes)\(productBytes)-0000-0000-[\\dA-F]{4}-[\\dA-F]{6}\(horizontalBytes)\(verticalBytes)[\\dA-F]{2}",
        ]
    }

    func ensureAudioIdentifier() {
        #if !arch(arm64)
            if (infoDictionary["IODisplayPrefsKey"] as? String) == nil, let dict = displayInfoDictionary(id) {
                infoDictionary = dict
            }
        #endif
    }

    func detectI2C() {
        ensureAudioIdentifier()
        guard shouldDetectI2C else {
            if isSmartBuiltin {
                log.debug("Built-in smart displays don't support DDC, ignoring for display \(description)")
            }
            if !supportsGammaByDefault {
                log.debug("Virtual/Airplay displays don't support DDC, ignoring for display \(description)")
            }
            if isDummy {
                log.debug("Dummy displays don't support DDC, ignoring for display \(description)")
            }
            mainThread { hasI2C = false }
            return
        }

        if panel?.isTV ?? false {
            log.warning("This could be a TV, and TVs don't support DDC: \(description)")
        }

        let i2c = {
            #if DEBUG
                if id == TEST_DISPLAY_ID || id == TEST_DISPLAY_PERSISTENT_ID || id == TEST_DISPLAY_PERSISTENT2_ID || isFakeDummy {
                    return true
                }
            #endif

            #if arch(arm64)
                return DDC.hasAVService(displayID: id, ignoreCache: true)
            #else
                return DDC.hasI2CController(displayID: id, ignoreCache: true)
            #endif
        }()

        mainAsync {
            self.hasI2C = i2c
            if i2c, let mode = DC.adaptiveMode as? ClockMode {
                log.debug("Clock mode adapting all screens after DDC port matching")
                mode.readapt()
            }
        }
    }

    func startI2CDetection() {
        i2cDetectionTask = Repeater(every: 1, times: 15, name: "i2c-detector-\(serial)") { [weak self] in
            guard let self, self.shouldDetectI2C else {
                mainAsync { self?.hasI2C = false }
                return
            }
            #if arch(arm64)
                DDC.rebuildDCPList()
            #endif
            self.updateCornerWindow()
            self.detectI2C()
            if self.hasI2C {
                self.i2cDetectionTask = nil
            }
        }
    }

    func setup() {
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification, object: nil)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if let infoDict = displayInfoDictionary(id) {
                    infoDictionary = infoDict
                }
                nsScreen = getScreen()
                screenFetcher = Repeater(every: 2, times: 5, name: "screen-\(serial)") { [weak self] in
                    guard let self else { return }
                    nsScreen = getScreen()
                }
            }
            .store(in: &observers)

        #if DEBUG
            if isTestID(id), name.contains("DELL") {
                audioIdentifier = "~:AMS2_Aggregate:0"
            }
        #endif
    }

    func setupHotkeys() {
        #if DEBUG
            log.info("Trying to setup hotkeys for \(description)")
        #endif
        guard active else { return }

        if let controller = hotkeyPopoverController {
            controller.setup(from: self)
            log.info("Initialized hotkeyPopoverController for \(description)")
        } else {
            log.info("Error initializing hotkeyPopoverController for \(description)")
        }
    }

    func redraw() {
        guard let screen = nsScreen ?? primaryMirrorScreen else { return }
        mainThread {
            createWindow(
                "gammaWindowController",
                controller: &gammaWindowController,
                screen: screen,
                show: true,
                backgroundColor: .clear,
                level: .screenSaver,
                stationary: true
            )

            guard let w = gammaWindowController?.window,
                  let c = w.contentViewController as? GammaViewController else { return }
            c.change()
        }
    }

    func hideGammaDot() {
        mainThread {
            guard let w = gammaWindowController?.window,
                  let c = w.contentViewController as? GammaViewController else { return }
            c.hide()
        }
    }

    @objc func resetColors() {
        _ = control?.resetColors()
        refreshColors { [weak self] success in
            guard !success, let self else { return }
            self.redGain = DEFAULT_COLOR_GAIN.ns
            self.greenGain = DEFAULT_COLOR_GAIN.ns
            self.blueGain = DEFAULT_COLOR_GAIN.ns
        }
    }

    @objc func resetMuteWorkarounds() {
        muteByteValueOn = 1
        muteByteValueOff = 2
        applyVolumeValueOnMute = false
        applyMuteValueOnMute = true
        volumeValueOnMute = 0
    }

    @objc func resetLimits() {
        minDDCBrightness = 0.ns
        minDDCContrast = 0.ns
        minDDCVolume = 0.ns
        maxDDCBrightness = defaultMaxDDCBrightness.ns

        if isLEDCinema {
            maxDDCVolume = 255
        }

        maxDDCContrast = 100.ns
    }

    func resetControl() {
        control = getBestControl()
        if let control, let onControlChange {
            onControlChange(control)
        }

        if !gammaEnabled, applyGamma || applyTemporaryGamma || gammaChanged || !supportsGamma {
            resetSoftwareControl()
        }

        mainAsync { [weak self] in
            guard let self else { return }
            self.withForce {
                #if DEBUG
                    log.debug("Setting brightness to \(self.brightness) for \(self.description)")
                #endif
                self.brightness = self.brightness.uint16Value.ns

                #if DEBUG
                    log.debug("Setting contrast to \(self.contrast) for \(self.description)")
                #endif
                self.contrast = self.contrast.uint16Value.ns
            }
        }
    }

    func resetDDC() {
        #if arch(arm64)
            DDC.sync(barrier: true) { DDC.dcpList = buildDCPList() }
        #endif
        detectI2C()

        ddcResetPublisher.send(true)
    }

    func resetNetworkController() {
        networkResetPublisher.send(true)
    }

    @objc func resetDefaultGamma() {
        red = 0.5
        green = 0.5
        blue = 0.5
        blacks = 0
        whites = 1

        lunarGammaTable = nil
    }

    func save(now: Bool = false, later: Bool = false) {
        guard !isAllDisplays else { return }

        if now {
            DataStore.storeDisplay(display: self, now: now)
            return
        }

        if later {
            savingLater.send(true)
            return
        }

        saving.send(true)
    }

    func resetName() {
        name = Display.printableName(id)
    }

    func encode(to encoder: Encoder) throws {
        try displayEncodingLock.aroundThrows(ignoreMainThread: true) {
            var container = encoder.container(keyedBy: CodingKeys.self)
            var enabledControlsContainer = container.nestedContainer(keyedBy: DisplayControlKeys.self, forKey: .enabledControls)

            try container.encode(active, forKey: .active)
            try container.encode(adaptive, forKey: .adaptive)
            try container.encode(adaptivePaused, forKey: .adaptivePaused)
            try container.encode(audioMuted, forKey: .audioMuted)
            try container.encode(canChangeVolume, forKey: .canChangeVolume)
            try container.encode(brightness.uint16Value, forKey: .brightness)
            try container.encode(contrast.uint16Value, forKey: .contrast)
            try container.encode(edidName, forKey: .edidName)

            try container.encode(defaultGammaRedMin.floatValue, forKey: .defaultGammaRedMin)
            try container.encode(defaultGammaRedMax.floatValue, forKey: .defaultGammaRedMax)
            try container.encode(defaultGammaRedValue.floatValue, forKey: .defaultGammaRedValue)
            try container.encode(defaultGammaGreenMin.floatValue, forKey: .defaultGammaGreenMin)
            try container.encode(defaultGammaGreenMax.floatValue, forKey: .defaultGammaGreenMax)
            try container.encode(defaultGammaGreenValue.floatValue, forKey: .defaultGammaGreenValue)
            try container.encode(defaultGammaBlueMin.floatValue, forKey: .defaultGammaBlueMin)
            try container.encode(defaultGammaBlueMax.floatValue, forKey: .defaultGammaBlueMax)
            try container.encode(defaultGammaBlueValue.floatValue, forKey: .defaultGammaBlueValue)

            try container.encode(maxDDCBrightness.uint16Value, forKey: .maxDDCBrightness)
            try container.encode(maxDDCContrast.uint16Value, forKey: .maxDDCContrast)
            try container.encode(maxDDCVolume.uint16Value, forKey: .maxDDCVolume)

            try container.encode(minDDCBrightness.uint16Value, forKey: .minDDCBrightness)
            try container.encode(minDDCContrast.uint16Value, forKey: .minDDCContrast)
            try container.encode(minDDCVolume.uint16Value, forKey: .minDDCVolume)

            try container.encode(faceLightBrightness.uint16Value, forKey: .faceLightBrightness)
            try container.encode(faceLightContrast.uint16Value, forKey: .faceLightContrast)

            try container.encode(mirroredBeforeBlackOut, forKey: .mirroredBeforeBlackOut)
            try container.encode(blackOutEnabled, forKey: .blackOutEnabled)
            try container.encode(blackOutMirroringAllowed, forKey: .blackOutMirroringAllowed)
            try container.encode(brightnessBeforeBlackout.uint16Value, forKey: .brightnessBeforeBlackout)
            try container.encode(contrastBeforeBlackout.uint16Value, forKey: .contrastBeforeBlackout)
            try container.encode(minBrightnessBeforeBlackout.uint16Value, forKey: .minBrightnessBeforeBlackout)
            try container.encode(minContrastBeforeBlackout.uint16Value, forKey: .minContrastBeforeBlackout)

            try container.encode(faceLightEnabled, forKey: .faceLightEnabled)
            try container.encode(brightnessBeforeFacelight.uint16Value, forKey: .brightnessBeforeFacelight)
            try container.encode(contrastBeforeFacelight.uint16Value, forKey: .contrastBeforeFacelight)
            try container.encode(maxBrightnessBeforeFacelight.uint16Value, forKey: .maxBrightnessBeforeFacelight)
            try container.encode(maxContrastBeforeFacelight.uint16Value, forKey: .maxContrastBeforeFacelight)

            try container.encode(cornerRadius.intValue, forKey: .cornerRadius)

            try container.encode(reapplyColorGain, forKey: .reapplyColorGain)
            try container.encode(extendedColorGain, forKey: .extendedColorGain)
            try container.encode(redGain.uint16Value, forKey: .redGain)
            try container.encode(greenGain.uint16Value, forKey: .greenGain)
            try container.encode(blueGain.uint16Value, forKey: .blueGain)

            try container.encode(preciseBrightness, forKey: .normalizedBrightness)
            try container.encode(preciseContrast, forKey: .normalizedContrast)
            try container.encode(preciseBrightnessContrast, forKey: .normalizedBrightnessContrast)

            try container.encode(id, forKey: .id)
            try container.encode(lockedBrightness, forKey: .lockedBrightness)
            try container.encode(lockedContrast, forKey: .lockedContrast)
            try container.encode(lockedBrightnessCurve, forKey: .lockedBrightnessCurve)
            try container.encode(lockedContrastCurve, forKey: .lockedContrastCurve)
            try container.encode(maxBrightness.uint16Value, forKey: .maxBrightness)
            try container.encode(maxContrast.uint16Value, forKey: .maxContrast)
            try container.encode(minBrightness.uint16Value, forKey: .minBrightness)
            try container.encode(minContrast.uint16Value, forKey: .minContrast)
            try container.encode(name, forKey: .name)
            try container.encode(responsiveDDC, forKey: .responsiveDDC)
            try container.encode(serial, forKey: .serial)
            try container.encode(volume.uint16Value, forKey: .volume)
            try container.encode(input.uint16Value, forKey: .input)

            try container.encode(hotkeyInput1.uint16Value, forKey: .hotkeyInput1)
            try container.encode(hotkeyInput2.uint16Value, forKey: .hotkeyInput2)
            try container.encode(hotkeyInput3.uint16Value, forKey: .hotkeyInput3)

            try container.encode(brightnessOnInputChange1, forKey: .brightnessOnInputChange1)
            try container.encode(brightnessOnInputChange2, forKey: .brightnessOnInputChange2)
            try container.encode(brightnessOnInputChange3, forKey: .brightnessOnInputChange3)

            try container.encode(contrastOnInputChange1, forKey: .contrastOnInputChange1)
            try container.encode(contrastOnInputChange2, forKey: .contrastOnInputChange2)
            try container.encode(contrastOnInputChange3, forKey: .contrastOnInputChange3)

            try container.encode(applyBrightnessOnInputChange1, forKey: .applyBrightnessOnInputChange1)
            try container.encode(applyBrightnessOnInputChange2, forKey: .applyBrightnessOnInputChange2)
            try container.encode(applyBrightnessOnInputChange3, forKey: .applyBrightnessOnInputChange3)

            try container.encode(syncBrightnessMapping, forKey: .syncBrightnessMapping)
            try container.encode(syncContrastMapping, forKey: .syncContrastMapping)
            try container.encode(sensorBrightnessMapping, forKey: .sensorBrightnessMapping)
            try container.encode(sensorContrastMapping, forKey: .sensorContrastMapping)
            try container.encode(locationBrightnessMapping, forKey: .locationBrightnessMapping)
            try container.encode(locationContrastMapping, forKey: .locationContrastMapping)
            #if arch(arm64)
                try container.encode(nitsBrightnessMapping, forKey: .nitsBrightnessMapping)
                try container.encode(nitsContrastMapping, forKey: .nitsContrastMapping)
            #endif

            try container.encode(rotation, forKey: .rotation)

            try enabledControlsContainer.encodeIfPresent(enabledControls[.network], forKey: .network)
            try enabledControlsContainer.encodeIfPresent(enabledControls[.appleNative], forKey: .appleNative)
            try enabledControlsContainer.encodeIfPresent(enabledControls[.ddc], forKey: .ddc)
            try enabledControlsContainer.encodeIfPresent(enabledControls[.gamma], forKey: .gamma)

            try container.encode(useOverlay, forKey: .useOverlay)
            try container.encode(useAlternateInputSwitching, forKey: .useAlternateInputSwitching)
            try container.encode(alwaysUseNetworkControl, forKey: .alwaysUseNetworkControl)
            try container.encode(neverUseNetworkControl, forKey: .neverUseNetworkControl)
            try container.encode(alwaysFallbackControl, forKey: .alwaysFallbackControl)
            try container.encode(neverFallbackControl, forKey: .neverFallbackControl)
            try container.encode(power, forKey: .power)
            try container.encode(isSource, forKey: .isSource)
            try container.encode(showVolumeOSD, forKey: .showVolumeOSD)
            try container.encode(muteByteValueOn, forKey: .muteByteValueOn)
            try container.encode(muteByteValueOff, forKey: .muteByteValueOff)
            try container.encode(volumeValueOnMute, forKey: .volumeValueOnMute)
            try container.encode(applyVolumeValueOnMute, forKey: .applyVolumeValueOnMute)
            try container.encode(applyMuteValueOnMute, forKey: .applyMuteValueOnMute)
            try container.encode(forceDDC, forKey: .forceDDC)
            try container.encode(applyGamma, forKey: .applyGamma)
            try container.encode(schedules, forKey: .schedules)
            try container.encode(main, forKey: .main)

            try container.encode(subzero, forKey: .subzero)
            try container.encode(hdr, forKey: .hdr)
            try container.encode(xdr, forKey: .xdr)
            try container.encode(fullRange, forKey: .fullRange)
            try container.encode(softwareBrightness, forKey: .softwareBrightness)
            try container.encode(subzeroDimming, forKey: .subzeroDimming)
            try container.encode(xdrBrightness, forKey: .xdrBrightness)
            try container.encode(averageDDCWriteNanoseconds, forKey: .averageDDCWriteNanoseconds)
            try container.encode(averageDDCReadNanoseconds, forKey: .averageDDCReadNanoseconds)
            try container.encode(connection, forKey: .connection)
            try container.encode(facelight, forKey: .facelight)
            try container.encode(blackout, forKey: .blackout)
            try container.encode(cachedSystemAdaptiveBrightness, forKey: .systemAdaptiveBrightness)
            try container.encode(adaptiveSubzero, forKey: .adaptiveSubzero)
            try container.encode(unmanaged, forKey: .unmanaged)
            try container.encode(keepDisconnected, forKey: .keepDisconnected)
            try container.encode(keepHDREnabled, forKey: .keepHDREnabled)

            try container.encode(ddcEnabled, forKey: .ddcEnabled)
            try container.encode(networkEnabled, forKey: .networkEnabled)
            try container.encode(appleNativeEnabled, forKey: .appleNativeEnabled)
            try container.encode(gammaEnabled, forKey: .gammaEnabled)

            #if arch(arm64)
                try container.encode(maxNits, forKey: .maxNits)
                try container.encode(minNits, forKey: .minNits)
                try container.encode(nits ?? 0, forKey: .nits)
                try container.encode(lux ?? 0, forKey: .lux)
            #endif
        }
    }

    func addSentryData() {
        guard CachedDefaults[.enableSentry] else { return }
        SentrySDK.configureScope { [weak self] scope in
            guard let self, var dict = self.dictionary else { return }
            if let panel = self.panel,
               let encoded = try? encoder.encode(
                   ForgivingEncodable(
                       getMonitorPanelDataJSON(
                           panel,
                           modeFilter: {
                               mode in mode.width > 1200 && mode.height > 1200 && mode.roundedScanRate > 50
                           }
                       )
                   )
               ),
               let compressed = encoded.gzip()?.base64EncodedString()
            {
                dict["panelData"] = compressed
            }

            if let encoded = try? encoder.encode(ForgivingEncodable(self.infoDictionary)),
               let compressed = encoded.gzip()?.base64EncodedString()
            {
                dict["infoDictionary"] = compressed
            }

            #if arch(arm64)
                if let displayProps = self.displayProps {
                    if let encoded = try? encoder.encode(ForgivingEncodable(displayProps)),
                       let compressed = encoded.gzip()?.base64EncodedString()
                    {
                        dict["armProps"] = compressed
                    }
                }
            #endif

            if let screen = NSScreen.forDisplayID(self.id) {
                if let encoded = try? encoder.encode(ForgivingEncodable(screen.deviceDescription)),
                   let compressed = encoded.gzip()?.base64EncodedString()
                {
                    dict["deviceDescription"] = compressed
                }
                if #available(macOS 12.0, *) {
                    dict["minHZ"] = screen.minimumRefreshInterval
                    dict["maxHZ"] = screen.maximumRefreshInterval
                    dict["maxFPS"] = screen.maximumFramesPerSecond
                }
                dict["maxEDR"] = screen.maximumExtendedDynamicRangeColorComponentValue
                dict["potentialEDR"] = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
                dict["referenceEDR"] = screen.maximumReferenceExtendedDynamicRangeColorComponentValue
            }

            #if arch(arm64)
                let dcp = DDC.DCP(displayID: self.id)
                if let dcp {
                    dict["avService"] = "YES"
                    dict["dcp"] = dcp.description
                } else {
                    dict["avService"] = "NO"
                }
            #else
                dict["i2cController"] = DDC.I2CController(displayID: self.id)
            #endif

            dict["hasNetworkControl"] = self.hasNetworkControl
            dict["hasI2C"] = self.hasI2C
            dict["hasDDC"] = self.hasDDC
            dict["activeAndResponsive"] = self.activeAndResponsive
            dict["responsiveDDC"] = self.responsiveDDC
            dict["systemAdaptiveBrightness"] = self.systemAdaptiveBrightness
            dict["hasAmbientLightAdaptiveBrightness"] = self.hasAmbientLightAdaptiveBrightness
            dict["control"] = self.control?.displayControl.str ?? "NONE"
            dict["gamma"] = [
                "redMin": self.redMin,
                "redMax": self.redMax,
                "redGamma": self.redGamma,
                "greenMin": self.greenMin,
                "greenMax": self.greenMax,
                "greenGamma": self.greenGamma,
                "blueMin": self.blueMin,
                "blueMax": self.blueMax,
                "blueGamma": self.blueGamma,
            ]

            // #if arch(arm64)
            //     self.addDDCStats(&dict)
            // #endif

            scope.setExtra(value: dict, key: "display-\(self.serial)")
        }
    }

    func addDDCStats(_ dict: inout [String: Any]) {
        guard self.hasDDC, self.control is DDCControl else {
            return
        }

        guard let maxBR = DDC.getMaxValue(for: self.id, controlID: .BRIGHTNESS) else {
            return
        }

        dict["possibleMaxDDCBrightness"] = maxBR

        guard DDC.setBrightness(for: id, brightness: lastWrittenBrightness) else {
            return
        }

        guard let maxCR = DDC.getMaxValue(for: self.id, controlID: .CONTRAST) else {
            return
        }

        dict["possibleMaxDDCContrast"] = maxCR
    }

    func checkSlowWrite(elapsedNS: UInt64) {
        if !slowWrite, elapsedNS > MAX_SMOOTH_STEP_TIME_NS * 2 {
            slowWrite = true
        }
        if slowWrite, elapsedNS < MAX_SMOOTH_STEP_TIME_NS * 2 {
            slowWrite = false
        }
    }

    // values between [-1, 1]
    func slowBrightnessTransition(from currentValue: Double, to value: Double, over period: DateComponents, adjust: @escaping ((Display, Double) -> Void)) {
        guard currentValue != value else { return }

        var steps = stride(from: currentValue, through: value, by: currentValue < value ? 0.005 : -0.005).map { $0 }

        log.debug("Starting slow brightness transition until \(period.fromNow): \(currentValue) -> \(value)")
        scheduledBrightnessTask = Repeater(every: period.timeInterval / steps.count.d, times: steps.count, name: "scheduledBrightnessSlowTransition", onFinish: { [weak self] in self?.scheduledBrightnessTask = nil }) { [weak self] in
            guard !DC.screensSleeping, !DC.locked || DC.allowAdjustmentsWhileLocked, let self, !steps.isEmpty else { return }

            self.inSchedule = true
            adjust(self, steps.removeFirst())
            self.inSchedule = false
        }
    }
    // values between [0, 1]
    func slowContrastTransition(from currentValue: Double, to value: Double, over period: DateComponents, adjust: @escaping ((Display, Double) -> Void)) {
        guard currentValue != value, !lockedContrast, canChangeContrast else { return }

        var steps = stride(from: currentValue, through: value, by: currentValue < value ? 0.01 : -0.01).map { $0 }

        log.debug("Starting slow contrast transition until \(period.fromNow): \(currentValue) -> \(value)")
        scheduledContrastTask = Repeater(every: period.timeInterval / steps.count.d, times: steps.count, name: "scheduledContrastSlowTransition", onFinish: { [weak self] in self?.scheduledContrastTask = nil }) { [weak self] in
            guard !DC.screensSleeping, !DC.locked || DC.allowAdjustmentsWhileLocked, let self, !steps.isEmpty else { return }

            self.inSchedule = true
            adjust(self, steps.removeFirst())
            self.inSchedule = false
        }
    }

    func smoothTransition(
        from currentValue: UInt16,
        to value: UInt16,
        delay: TimeInterval? = nil,
        onStart: (() -> Void)? = nil,
        adjust: @escaping ((UInt16) throws -> Void)
    ) -> DispatchWorkItem {
        inSmoothTransition = true

        let task = DispatchWorkItem(name: "smoothTransitionDDC: \(self)", flags: .barrier) { [weak self] in
            guard let self else { return }

            var steps = abs(value.distance(to: currentValue))
            #if DEBUG
                log.debug("Smooth transition STEPS=\(steps) for \(self.description) from \(currentValue) to \(value)")
            #endif

            var step: Int
            let minVal: UInt16
            let maxVal: UInt16
            if value < currentValue {
                step = cap(-self.smoothStep, minVal: -steps, maxVal: -1)
                minVal = value
                maxVal = currentValue
            } else {
                step = cap(self.smoothStep, minVal: 1, maxVal: steps)
                minVal = currentValue
                maxVal = value
            }

            let startTime = DispatchTime.now()

            onStart?()
            var elapsedTimeInterval: DispatchTimeInterval = .never
            do {
                try adjust((currentValue.i + step).u16)

                elapsedTimeInterval = startTime.distance(to: DispatchTime.now())
                #if DEBUG
                    log.debug("It took \(elapsedTimeInterval.ns) to change brightness by \(step)")
                #endif

                self.checkSlowWrite(elapsedNS: elapsedTimeInterval.absNS)

                steps = steps - abs(step)
                if steps <= 0 {
                    try adjust(value)
                    return
                }

                self.smoothStep = cap((elapsedTimeInterval.absNS / MAX_SMOOTH_STEP_TIME_NS).i, minVal: 1, maxVal: 100)
                #if DEBUG
                    log.debug("Smooth step \(self.smoothStep) for \(self.description) from \(currentValue) to \(value)")
                #endif
                if value < currentValue {
                    step = cap(-self.smoothStep, minVal: -steps, maxVal: -1)
                } else {
                    step = cap(self.smoothStep, minVal: 1, maxVal: steps)
                }

                for newValue in stride(from: currentValue.i, through: value.i, by: step) {
                    try adjust(cap(newValue.u16, minVal: minVal, maxVal: maxVal))
                    if let delay {
                        Thread.sleep(forTimeInterval: delay)
                    }
                }
                try adjust(value)
            } catch DDCTransitionError.shouldStop {
                return
            } catch {
                self.inSmoothTransition = false
                return
            }

            elapsedTimeInterval = startTime.distance(to: DispatchTime.now())
            #if DEBUG
                log.debug("It took \(elapsedTimeInterval.ns) to change brightness from \(currentValue) to \(value) by \(step)")
            #endif
            self.checkSlowWrite(elapsedNS: elapsedTimeInterval.absNS / steps.u64)

            self.inSmoothTransition = false
        }
        smoothDDCQueue.asyncAfter(deadline: DispatchTime.now(), execute: task.workItem)
        return task
    }

    func readapt<T: Equatable>(newValue: T?, oldValue: T?) {
        if let readaptListener = onReadapt {
            readaptListener()
        }
        if adaptive, let newVal = newValue, let oldVal = oldValue, newVal != oldVal {
            DC.adaptBrightness(for: self, force: true)
        }
    }

    func possibleDDCBlockers() -> String {
        let specificBlockers: String = switch vendor {
        case .dell:
            """
            * Disable **Uniformity Compensation**
            * Set **Preset Mode** to `Custom` or `Standard`
            """
        case .acer:
            DEFAULT_DDC_BLOCKERS
        case .lg:
            """
            * Disable **Uniformity**
            * Disable **Auto Brightness**
            * Set **Picture Mode** to `Custom` or `Standard`
            """
        case .samsung:
            """
            * Disable **Input Signal Plus**
            * Disable **Magic Bright**
            * Disable **Eye Saver Mode**
            * Disable **Eco Saving Plus**
            * Disable **Smart ECO Saving**
            * Disable **Game Mode**
            * Disable **PIP/PBP Mode**
            * Disable **Dynamic Brightness**
            """
        case .benq:
            """
            * Disable **Bright Intelligence**
            * Disable **Bright Intelligence Plus** or **B.I.+**
            * Set **Picture Mode** to `Standard`
            """
        case .prism:
            """
            * Set **On-the-Fly Mode** to `Standard`
            """
        case .lenovo:
            """
            * Disable **Local Dimming**
            * Disable **HDR**
            * Disable **Dynamic Contrast**
            * Set **Color Mode** to `Custom`
            * Set **Scenario Modes** to `Panel Native`
            """
        case .xiaomi:
            """
            * Disable **Dynamic Brightness**
            * Set **Smart Mode** to `Standard`
            """
        case .eizo:
            DEFAULT_DDC_BLOCKERS
        case .apple:
            DEFAULT_DDC_BLOCKERS
        case .asus:
            DEFAULT_DDC_BLOCKERS
        case .hp:
            DEFAULT_DDC_BLOCKERS
        case .huawei:
            DEFAULT_DDC_BLOCKERS
        case .philips:
            DEFAULT_DDC_BLOCKERS
        case .sceptre:
            DEFAULT_DDC_BLOCKERS
        case .proart:
            DEFAULT_DDC_BLOCKERS
        default:
            DEFAULT_DDC_BLOCKERS
        }

        return """
        #### DDC Blocking Settings

        *Note: some settings might not exist in your monitor OSD depending on the monitor model*

        Use the physical buttons of your monitor to change the following settings and try to unlock DDC controls for this monitor:

        \(specificBlockers)

        \(DDC_BLOCKERS_TRAILER)
        """
    }

    func readRedGain() -> UInt16? {
        control?.getRedGain()
    }

    func readGreenGain() -> UInt16? {
        control?.getGreenGain()
    }

    func readBlueGain() -> UInt16? {
        control?.getBlueGain()
    }

    func readAudioMuted() -> Bool? {
        control?.getMute()
    }

    func readVolume() -> UInt16? {
        control?.getVolume()
    }

    func readContrast() -> UInt16? {
        guard !isBuiltin else {
            return brightness.uint16Value
//            guard let contrast = SyncMode.readBuiltinContrast() else {
//                return nil
//            }
//            return (contrast * 100).u16
        }
        return control?.getContrast()
    }

    func readInput() -> UInt16? {
        control?.getInput()?.rawValue
    }

    func softwareAdjusted(brightness: UInt16) -> Int {
        guard !hasSoftwareControl, softwareBrightness < 1 else {
            return brightness.i
        }
        return brightness.i - softwareBrightness.map(from: (0, 1), to: (100, 0)).intround
    }

    func readBrightness() -> UInt16? {
        control?.getBrightness()
    }

    func refreshColors(onComplete: ((Bool) -> Void)? = nil) {
        guard !isTestID(id), !isSmartBuiltin,
              !DC.screensSleeping, !DC.locked
        else { return }
        colorRefresher = concurrentQueue.asyncAfter(ms: 10) { [weak self] in
            guard let self else { return }
            let newRedGain = self.readRedGain()
            let newGreenGain = self.readGreenGain()
            let newBlueGain = self.readBlueGain()
            mainAsync {
                guard newRedGain != nil || newGreenGain != nil || newBlueGain != nil else {
                    log.warning("Can't read color gain for \(self.description)")
                    onComplete?(false)
                    return
                }

                if let newRedGain, newRedGain != self.redGain.uint16Value {
                    log.info("Refreshing red gain value: \(self.redGain.uint16Value) <> \(newRedGain)")
                    self.withoutSmoothTransition { self.withoutDDC { self.redGain = newRedGain.ns } }
                }
                if let newGreenGain, newGreenGain != self.greenGain.uint16Value {
                    log.info("Refreshing green gain value: \(self.greenGain.uint16Value) <> \(newGreenGain)")
                    self.withoutSmoothTransition { self.withoutDDC { self.greenGain = newGreenGain.ns } }
                }
                if let newBlueGain, newBlueGain != self.blueGain.uint16Value {
                    log.info("Refreshing blue gain value: \(self.blueGain.uint16Value) <> \(newBlueGain)")
                    self.withoutSmoothTransition { self.withoutDDC { self.blueGain = newBlueGain.ns } }
                }
            }
            onComplete?(true)
        }
    }

    func refreshColors() async -> Bool {
        guard !isTestID(id), !isSmartBuiltin,
              !DC.screensSleeping, !DC.locked
        else { return false }

        let newRedGain = self.readRedGain()
        let newGreenGain = self.readGreenGain()
        let newBlueGain = self.readBlueGain()
        guard newRedGain != nil || newGreenGain != nil || newBlueGain != nil else {
            log.warning("Can't read color gain for \(self.description)")
            return false
        }

        await MainActor.run {
            if let newRedGain, newRedGain != self.redGain.uint16Value {
                log.info("Refreshing red gain value: \(self.redGain.uint16Value) <> \(newRedGain)")
                self.withoutSmoothTransition { self.withoutDDC { self.redGain = newRedGain.ns } }
            }
            if let newGreenGain, newGreenGain != self.greenGain.uint16Value {
                log.info("Refreshing green gain value: \(self.greenGain.uint16Value) <> \(newGreenGain)")
                self.withoutSmoothTransition { self.withoutDDC { self.greenGain = newGreenGain.ns } }
            }
            if let newBlueGain, newBlueGain != self.blueGain.uint16Value {
                log.info("Refreshing blue gain value: \(self.blueGain.uint16Value) <> \(newBlueGain)")
                self.withoutSmoothTransition { self.withoutDDC { self.blueGain = newBlueGain.ns } }
            }
        }

        return true
    }

    func refreshBrightness() {
        guard !isTestID(id), !inSmoothTransition, !isUserAdjusting(), !sendingBrightness,
              !SyncMode.possibleClamshellModeSoon, !hasSoftwareControl, !DC.screensSleeping, !DC.locked
        else { return }

        brightnessRefresher = concurrentQueue.asyncAfter(ms: 10) { [weak self] in
            guard let self else { return }
            guard let newBrightness = self.readBrightness() else {
                log.warning("Can't read brightness for \(self.name)")
                return
            }

            mainAsync {
                guard !self.inSmoothTransition, !self.isUserAdjusting(), !self.sendingBrightness else { return }
                if newBrightness != self.brightness.uint16Value {
                    log.info("Refreshing brightness: \(self.brightness.uint16Value) <> \(newBrightness)")

                    if DC.adaptiveModeKey != .manual, DC.adaptiveModeKey != .clock,
                       timeSince(self.lastConnectionTime) > 10
                    {
                        self.insertBrightnessUserDataPoint(
                            DC.adaptiveMode.brightnessDataPoint.last,
                            newBrightness.d, modeKey: DC.adaptiveModeKey
                        )
                    }

                    self.withoutSmoothTransition {
                        self.withoutDDC {
                            mainThread { self.brightness = newBrightness.ns }
                        }
                    }
                }
            }
        }
    }

    func refreshContrast() {
        guard !isTestID(id), !inSmoothTransition, !isUserAdjusting(), !sendingContrast,
              !DC.screensSleeping, !DC.locked
        else { return }

        contrastRefresher = concurrentQueue.asyncAfter(ms: 10) { [weak self] in
            guard let self else { return }
            guard let newContrast = self.readContrast() else {
                log.warning("Can't read contrast for \(self.name)")
                return
            }

            mainAsync {
                guard !self.inSmoothTransition, !self.isUserAdjusting(), !self.sendingContrast else { return }
                if newContrast != self.contrast.uint16Value {
                    log.info("Refreshing contrast: \(self.contrast.uint16Value) <> \(newContrast)")

                    if DC.adaptiveModeKey != .manual, DC.adaptiveModeKey != .clock,
                       timeSince(self.lastConnectionTime) > 10
                    {
                        self.insertContrastUserDataPoint(
                            DC.adaptiveMode.contrastDataPoint.last,
                            newContrast.d, modeKey: DC.adaptiveModeKey
                        )
                    }

                    self.withoutSmoothTransition {
                        self.withoutDDC {
                            self.contrast = newContrast.ns
                        }
                    }
                }
            }
        }
    }

    func refreshInput() {
        let hotkeys = CachedDefaults[.hotkeys]
        let hotkeyInputEnabled = hotkeyIdentifiers.compactMap { identifier in
            hotkeys.first { $0.identifier == identifier }
        }.first { $0.isEnabled }?.isEnabled ?? false

        guard !isTestID(id), !hotkeyInputEnabled, !isSmartBuiltin,
              !DC.screensSleeping, !DC.locked
        else { return }

        inputRefresher = concurrentQueue.asyncAfter(ms: 10) { [weak self] in
            guard let self else { return }
            guard let newInput = self.readInput() else {
                log.warning("Can't read input for \(self.name)")
                return
            }
            mainAsync {
                if newInput != self.input.uint16Value {
                    log.info("Refreshing input: \(self.input.uint16Value) <> \(newInput)")

                    self.withoutSmoothTransition {
                        self.withoutDDC {
                            self.input = newInput.ns
                        }
                    }
                }
            }
        }
    }

    func refreshVolume() {
        guard !isTestID(id), !isSmartBuiltin,
              !DC.screensSleeping, !DC.locked
        else { return }

        volumeRefresher = concurrentQueue.asyncAfter(ms: 10) { [weak self] in
            guard let self else { return }
            guard let newVolume = self.readVolume(), let newAudioMuted = self.readAudioMuted() else {
                log.warning("Can't read volume for \(self.name)")
                return
            }
            mainAsync {
                if newAudioMuted != self.audioMuted {
                    log.info("Refreshing mute value: \(self.audioMuted) <> \(newAudioMuted)")
                    self.audioMuted = newAudioMuted
                }
                if newVolume != self.volume.uint16Value {
                    log.info("Refreshing volume: \(self.volume.uint16Value) <> \(newVolume)")

                    self.withoutSmoothTransition {
                        self.withoutDDC {
                            self.volume = newVolume.ns
                        }
                    }
                }
            }
        }
    }

    func refreshGamma() {
        guard !isForTesting, isOnline,
              !DC.screensSleeping, !DC.locked
        else { return }

        if defaultGammaChanged, applyGamma || applyTemporaryGamma {
            lunarGammaTable = GammaTable(
                redMin: defaultGammaRedMin.floatValue,
                redMax: defaultGammaRedMax.floatValue,
                redValue: defaultGammaRedValue.floatValue,
                greenMin: defaultGammaGreenMin.floatValue,
                greenMax: defaultGammaGreenMax.floatValue,
                greenValue: defaultGammaGreenValue.floatValue,
                blueMin: defaultGammaBlueMin.floatValue,
                blueMax: defaultGammaBlueMax.floatValue,
                blueValue: defaultGammaBlueValue.floatValue
            )
            return
        }

        lunarGammaTable = nil
        // defaultGammaTable = GammaTable.original
//        if AppDelegate.hdrWorkaround, restoreColorSyncSettings() {
//            defaultGammaTable = GammaTable(for: id)
//        } else {
//            defaultGammaTable = GammaTable.original
//        }
    }

    func resetGamma() {
        guard !isForTesting else { return }

        // let gammaTable = (lunarGammaTable ?? defaultGammaTable)
        if let lunarGammaTable, apply(gamma: lunarGammaTable) {
            lastGammaTable = lunarGammaTable
        } else if gammaSetAPICalled {
            restoreColorSyncSettings(reapplyGammaFor: otherDisplays.filter(\.gammaSetAPICalled))
            lastGammaTable = nil
        }
        gammaChanged = false
    }

    @discardableResult
    func apply(gamma: GammaTable, force: Bool = false) -> Bool {
        let result = gamma.apply(to: id, force: force)
        redraw()

        return result
    }
    func setGamma(
        brightness: UInt16? = nil,
        preciseBrightness: Double? = nil,
        force: Bool = false,
        transition: BrightnessTransition? = nil,
        onChange: ((Brightness) -> Void)? = nil
    ) {
        #if DEBUG
            guard !isForTesting else { return }
        #endif

        gammaDelayerTask = nil
        guard force || (enabledControls[.gamma] ?? false && (timeSince(lastConnectionTime) >= 1 || onlySoftwareDimmingEnabled))
        else {
            if enabledControls[.gamma] ?? false, timeSince(lastConnectionTime) < 1 {
                gammaDelayerTask = mainAsyncAfter(ms: 1000) { [weak self] in
                    self?.setGamma(brightness: brightness, preciseBrightness: preciseBrightness, force: force, transition: transition, onChange: onChange)
                }
            }
            return
        }

        if gammaSetterTask != nil {
            gammaSetterTask = nil
        }
        settingGamma = true

        let brightness = brightness ?? limitedBrightness
        let gammaTable = lunarGammaTable ?? defaultGammaTable
        let newGammaTable = gammaTable.adjust(brightness: brightness, preciseBrightness: preciseBrightness, maxValue: maxEDR)
        let brightnessTransition = transition ?? brightnessTransition

        guard !GammaControl.sliderTracking, lastGammaBrightness != brightness else {
            defer {
                settingGamma = false
                lastColorSyncReset = Date()
            }
            guard !newGammaTable.isZero else { return }

            gammaChanged = true
            if apply(gamma: newGammaTable) {
                lastGammaTable = newGammaTable
                lastGammaBrightness = newGammaTable.brightness ?? brightness
            }
            onChange?(brightness)
            return
        }

        let delay = brightnessTransition == .slow ? 0.025 : 0.002
        gammaSetterTask = DispatchWorkItem(name: "gammaSetter: \(description)", flags: .barrier) { [weak self] in
            // gammaSetterTask = serialAsyncAfter(ms: 1, name: "gamma-setter") { [weak self] in
            guard let self else { return }

            self.settingGamma = true
            self.gammaChanged = true
            var lastGammaTable = self.lastGammaTable
            var lastGammaBrightness = self.lastGammaBrightness
            defer {
                self.settingGamma = false
                lastColorSyncReset = Date()
                self.lastGammaTable = lastGammaTable
                self.lastGammaBrightness = lastGammaBrightness
            }

            for gammaTable in gammaTable.stride(from: self.lastGammaBrightness, to: brightness, maxValue: self.maxEDR) {
                guard let gammaSetterTask = self.gammaSetterTask, !gammaSetterTask.isCancelled else {
                    return
                }

                if self.apply(gamma: gammaTable) {
                    lastGammaTable = gammaTable
                }

                if let brightness = gammaTable.brightness {
                    lastGammaBrightness = brightness
                    onChange?(brightness)
                }
                Thread.sleep(forTimeInterval: delay)
            }

            guard !newGammaTable.isZero else {
                return
            }

            if self.apply(gamma: newGammaTable) {
                lastGammaTable = newGammaTable
                lastGammaBrightness = newGammaTable.brightness ?? brightness
            }
            onChange?(brightness)
        }
        smoothGammaQueue.asyncAfter(deadline: DispatchTime.now(), execute: gammaSetterTask!.workItem)
    }

    func resetBlackOut() {
        mainAsync { [weak self] in
            guard let self else { return }
            self.resetSoftwareControl()
            DC.blackOut(display: self.id, state: .off)
        }

        mainAsyncAfter(ms: 1000) { [weak self] in
            guard let self else { return }
            self.blackOutEnabled = false
            self.blackOutMirroringAllowed = self.supportsGammaByDefault || self.isFakeDummy
            self.mirroredBeforeBlackOut = false

            self.preciseBrightnessContrast = 0.7
        }
    }

    func reset(resetControl: Bool = true) {
        maxDDCBrightness = defaultMaxDDCBrightness.ns
        if isLEDCinema {
            maxDDCVolume = 255.ns
        } else {
            maxDDCVolume = 100.ns
        }

        maxDDCContrast = 100.ns

        minDDCBrightness = 0.ns
        minDDCContrast = 0.ns
        minDDCVolume = 0.ns

        faceLightBrightness = 100.ns
        faceLightContrast = 90.ns

        blackOutEnabled = false
        blackOutMirroringAllowed = supportsGammaByDefault || isFakeDummy
        mirroredBeforeBlackOut = false

        resetCurveMappings()
        resetDefaultGamma()

        useOverlay = !supportsGammaByDefault
        alwaysFallbackControl = false
        neverFallbackControl = false
        alwaysUseNetworkControl = false
        neverUseNetworkControl = false
        enabledControls = [
            .network: true,
            .appleNative: true,
            .ddc: !isTV && !isStudioDisplay,
            .gamma: !DDC.isSmartBuiltinDisplay(id),
        ]

        adaptive = !Self.ambientLightCompensationEnabled(id)
        adaptivePaused = false

        save()

        if resetControl {
            _ = control?.reset()
        }
        readapt(newValue: false, oldValue: true)
    }

    func resetCurveMappings() {
        syncBrightnessMapping = [:]
        #if arch(arm64)
            sensorBrightnessMapping = nitsToPercentageMapping
        #else
            sensorBrightnessMapping = SensorMode.DEFAULT_BRIGHTNESS_MAPPING
        #endif
        locationBrightnessMapping = LocationMode.DEFAULT_BRIGHTNESS_MAPPING

        syncContrastMapping = [:]
        sensorContrastMapping = SensorMode.DEFAULT_CONTRAST_MAPPING
        locationContrastMapping = LocationMode.DEFAULT_CONTRAST_MAPPING

        #if arch(arm64)
            nitsBrightnessMapping = []
            nitsContrastMapping = []
            saveNitsBrightnessMapping()
            saveNitsContrastMapping()
        #endif
    }

    @inline(__always) func withoutDDCLimits(_ block: @escaping () -> Void) {
        DDC.sync {
            DDC.applyLimits = false
            block()
            DDC.applyLimits = true
        }
    }

    @inline(__always) func withoutApply(_ block: () -> Void) {
        apply = false
        block()
        apply = true
    }

    @inline(__always) func withoutModeChangeAsk(_ block: () -> Void) {
        modeChangeAsk = false
        block()
        modeChangeAsk = true
    }

    @inline(__always) func withoutApplyPreciseValue(_ block: () -> Void) {
        applyPreciseValue = false
        block()
        applyPreciseValue = true
    }

    @inline(__always) func withoutReapplyPreciseValue(_ block: () -> Void) {
        reapplyPreciseValue = false
        block()
        reapplyPreciseValue = true
    }

    @inline(__always) func withoutDDC(_ block: @escaping () -> Void) {
        DDC.sync {
            DDC.apply = false
            block()
            DDC.apply = true
        }
    }

    @inline(__always) func withoutDisplayServices(_ block: () -> Void) {
        guard isNative else {
            block()
            return
        }

        mainThread {
            applyDisplayServices = false
            block()
            applyDisplayServices = true
        }
    }

    @inline(__always) func withForce(_ force: Bool = true, _ block: () -> Void) {
        self.force = force
        block()
        self.force = false
    }

    @inline(__always) func withoutLockedBrightness(_ block: () -> Void) {
        guard lockedBrightness else {
            block()
            return
        }

        lockedBrightness = false
        block()
        lockedBrightness = true
    }

    @inline(__always) func withoutLockedContrast(_ block: () -> Void) {
        guard lockedContrast else {
            block()
            return
        }

        lockedContrast = false
        block()
        lockedContrast = true
    }

    @inline(__always) func withoutSmoothTransition(_ block: () -> Void) {
        withBrightnessTransition(.instant, block)
    }

    @inline(__always) func withBrightnessTransition(_ transition: BrightnessTransition = .smooth, _ block: () -> Void) {
        if brightnessTransition == transition {
            block()
            return
        }

        let oldTransition = brightnessTransition
        brightnessTransition = transition
        block()
        brightnessTransition = oldTransition
    }

    func insertBrightnessUserDataPoint(_ featureValue: Double, _ targetValue: Double, modeKey: AdaptiveModeKey? = nil) {
        let modeKey = modeKey ?? DC.adaptiveModeKey

        guard !lockedBrightnessCurve, !adaptivePaused,
              modeKey != .sync || !isActiveSyncSource,
              modeKey != .location || featureValue != 0,
              !noControls, timeSince(lastConnectionTime) > 5
        else { return }

        var targetValue = targetValue.map(from: (minBrightness.doubleValue, maxBrightness.doubleValue), to: (0, 100))
        if adaptiveSubzero, softwareBrightness < 1 {
            targetValue -= softwareBrightness.d.map(from: (0, 1), to: (100, 0))
        }

        insertBrightnessUserDataPoint([featureValue: targetValue], modeKey: modeKey)
    }

    func insertBrightnessUserDataPoint(_ mapping: AutoLearnMapping, modeKey: AdaptiveModeKey? = nil) {
        switch modeKey ?? DC.adaptiveModeKey {
        case .sync:
            #if arch(arm64)
                insertNitsBrightnessUserDataPoint(mapping.target)
            #endif

            if let values = previousBrightnessMapping.value ?? syncBrightnessMapping[DC.sourceDisplay.serial] {
                previousBrightnessMapping.setOrRefresh(values, expireAfter: 1)
                syncBrightnessMapping[DC.sourceDisplay.serial] = Self.insertDataPoint(mapping, in: values, cliffRatio: 1.5, cliffSourceDiff: 10)
            } else {
                syncBrightnessMapping[DC.sourceDisplay.serial] = [mapping]
            }
            NotificationCenter.default.post(name: brightnessDataPointInserted, object: self, userInfo: ["values": syncBrightnessMapping[DC.sourceDisplay.serial]!])
            saveSyncMapping()
        case .sensor:
            previousBrightnessMapping.setOrRefresh(sensorBrightnessMapping, expireAfter: 1)

            sensorBrightnessMapping = Self.insertDataPoint(mapping, in: previousBrightnessMapping.value ?? sensorBrightnessMapping, cliffRatio: 2, cliffSourceDiff: 30, stopCliffDetectionBelow: 35)
            saveSensorMapping()
            NotificationCenter.default.post(name: brightnessDataPointInserted, object: self, userInfo: ["values": sensorBrightnessMapping])
        case .location:
            previousBrightnessMapping.setOrRefresh(locationBrightnessMapping, expireAfter: 1)

            locationBrightnessMapping = Self.insertDataPoint(mapping, in: previousBrightnessMapping.value ?? locationBrightnessMapping, cliffRatio: 3, cliffSourceDiff: 5)
            if let map = Self.insertElevationDataPoint(mapping, in: locationBrightnessMapping) {
                locationBrightnessMapping = map
            }
            saveLocationMapping()
            NotificationCenter.default.post(name: brightnessDataPointInserted, object: self, userInfo: ["values": locationBrightnessMapping])
        default:
            break
        }
    }

    func insertContrastUserDataPoint(_ featureValue: Double, _ targetValue: Double, modeKey: AdaptiveModeKey? = nil) {
        let modeKey = modeKey ?? DC.adaptiveModeKey

        guard !lockedContrastCurve, !adaptivePaused,
              modeKey != .sync || !isActiveSyncSource,
              modeKey != .location || featureValue != 0,
              canChangeContrast, !noControls, timeSince(lastConnectionTime) > 5
        else { return }

        let targetValue = targetValue.map(from: (minContrast.doubleValue, maxContrast.doubleValue), to: (0, 100))
        insertContrastUserDataPoint([featureValue: targetValue], modeKey: modeKey)
    }

    func insertContrastUserDataPoint(_ mapping: AutoLearnMapping, modeKey: AdaptiveModeKey? = nil) {
        switch modeKey ?? DC.adaptiveModeKey {
        case .sync:
            #if arch(arm64)
                insertNitsContrastUserDataPoint(mapping.target)
            #endif

            if let values = previousContrastMapping.value ?? syncContrastMapping[DC.sourceDisplay.serial] {
                previousContrastMapping.setOrRefresh(values, expireAfter: 1)
                syncContrastMapping[DC.sourceDisplay.serial] = Self.insertDataPoint(mapping, in: values, cliffRatio: 1.5, cliffSourceDiff: 10)
            } else {
                syncContrastMapping[DC.sourceDisplay.serial] = [mapping]
            }
            saveSyncMapping()
            NotificationCenter.default.post(name: contrastDataPointInserted, object: self, userInfo: ["values": syncContrastMapping[DC.sourceDisplay.serial]!])
        case .sensor:
            previousContrastMapping.setOrRefresh(sensorContrastMapping, expireAfter: 1)

            sensorContrastMapping = Self.insertDataPoint(mapping, in: previousContrastMapping.value ?? sensorContrastMapping, cliffRatio: 2, cliffSourceDiff: 30, stopCliffDetectionBelow: 35)
            saveSensorMapping()
            NotificationCenter.default.post(name: contrastDataPointInserted, object: self, userInfo: ["values": sensorContrastMapping])
        case .location:
            previousContrastMapping.setOrRefresh(locationContrastMapping, expireAfter: 1)

            locationContrastMapping = Self.insertDataPoint(mapping, in: previousContrastMapping.value ?? locationContrastMapping, cliffRatio: 3, cliffSourceDiff: 5)
            if let map = Self.insertElevationDataPoint(mapping, in: locationContrastMapping) {
                locationContrastMapping = map
            }
            saveLocationMapping()
            NotificationCenter.default.post(name: contrastDataPointInserted, object: self, userInfo: ["values": locationContrastMapping])
        default:
            break
        }
    }

    func isUserAdjusting() -> Bool {
        if userAdjusting {
            return true
        }

        switch DC.adaptiveModeKey {
        case .sync:
            #if arch(arm64)
                if SyncMode.isUsingNits() {
                    return nitsBrightnessMappingSaver != nil || nitsContrastMappingSaver != nil
                }
            #endif

            return syncMappingSaver != nil
        case .sensor:
            return sensorMappingSaver != nil
        case .location:
            return locationMappingSaver != nil
        default:
            return false
        }
    }

    func getAdaptiveController() -> AdaptiveController {
        guard adaptive || systemAdaptiveBrightness else {
            return .disabled
        }

        return adaptive ? .lunar : .system
    }
}

let DS_LOGGER = Logger(subsystem: "fyi.lunar.Lunar.DisplayServices", category: "default")
