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
import Clamping
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

let DEFAULT_MIN_BRIGHTNESS: UInt16 = 0
let DEFAULT_MAX_BRIGHTNESS: UInt16 = 100
let DEFAULT_MIN_CONTRAST: UInt16 = 50
let DEFAULT_MAX_CONTRAST: UInt16 = 75
let DEFAULT_COLOR_GAIN: UInt16 = 50

let DEFAULT_SENSOR_BRIGHTNESS_CURVE_FACTOR = 0.5
let DEFAULT_SYNC_BRIGHTNESS_CURVE_FACTOR = 1.0
let DEFAULT_LOCATION_BRIGHTNESS_CURVE_FACTOR = 1.0
let DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR = 1.0

let DEFAULT_SENSOR_CONTRAST_CURVE_FACTOR = 0.2
let DEFAULT_SYNC_CONTRAST_CURVE_FACTOR = 0.26
let DEFAULT_LOCATION_CONTRAST_CURVE_FACTOR = 0.8
let DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR = 1.0

let GENERIC_DISPLAY_ID: CGDirectDisplayID = UINT32_MAX
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
#endif

let MAX_SMOOTH_STEP_TIME_NS: UInt64 = 90 * 1_000_000 // 90ms

let STUDIO_DISPLAY_NAME = "Studio Display"
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
        guard !displayController.gammaDisabledCompletely else {
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

        let result = gammaQueue.sync {
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
        guard !displayController.gammaDisabledCompletely else { return true }

        log.debug("Applying gamma table to ID \(id)")
        guard force || !isZero else {
            log.debug("Zero gamma table: samples=\(samples)")
            GammaTable.original.apply(to: id)
            return false
        }
        let result = gammaQueue.sync {
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
        let gammaBrightness: Float = mapNumber(br, fromLow: 0.00, fromHigh: max, toLow: 0.08, toHigh: max)

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
        let userBrightnessContainer = try container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .userBrightness)
        let userContrastContainer = try container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .userContrast)
        let enabledControlsContainer = try container.nestedContainer(keyedBy: DisplayControlKeys.self, forKey: .enabledControls)
        let brightnessCurveFactorsContainer = try container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .brightnessCurveFactors)
        let contrastCurveFactorsContainer = try container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .contrastCurveFactors)

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

        let brightness = isNative ? (AppleNativeControl.readBrightnessDisplayServices(id: id) * 100)
            .ns : (try container.decode(UInt16.self, forKey: .brightness)).ns
        self.brightness = brightness
        let contrast = (try container.decode(UInt16.self, forKey: .contrast)).ns
        self.contrast = contrast

        let allowBrightnessZero = ((try container.decodeIfPresent(Bool.self, forKey: .allowBrightnessZero)) ?? false)
        let minBrightness = (try container.decode(UInt16.self, forKey: .minBrightness)).ns
        let maxBrightness = (try container.decode(UInt16.self, forKey: .maxBrightness)).ns

        self.allowBrightnessZero = allowBrightnessZero
        self.minBrightness = (isSmartBuiltin && !allowBrightnessZero && minBrightness == 0) ? 1 : minBrightness
        self.maxBrightness = maxBrightness
        minContrast = isSmartBuiltin ? 0 : (try container.decode(UInt16.self, forKey: .minContrast)).ns
        maxContrast = isSmartBuiltin ? 100 : (try container.decode(UInt16.self, forKey: .maxContrast)).ns

        defaultGammaRedMin = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaRedMin)?.ns) ?? 0.ns
        defaultGammaRedMax = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaRedMax)?.ns) ?? 1.ns
        let defaultGammaRedValue = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaRedValue)?.ns) ?? 1.ns
        defaultGammaGreenMin = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaGreenMin)?.ns) ?? 0.ns
        defaultGammaGreenMax = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaGreenMax)?.ns) ?? 1.ns
        let defaultGammaGreenValue = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaGreenValue)?.ns) ?? 1.ns
        defaultGammaBlueMin = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaBlueMin)?.ns) ?? 0.ns
        defaultGammaBlueMax = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaBlueMax)?.ns) ?? 1.ns
        let defaultGammaBlueValue = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaBlueValue)?.ns) ?? 1.ns

        self.defaultGammaRedValue = defaultGammaRedValue
        red = Self.gammaValueToSliderValue(defaultGammaRedValue.doubleValue)
        self.defaultGammaGreenValue = defaultGammaGreenValue
        green = Self.gammaValueToSliderValue(defaultGammaGreenValue.doubleValue)
        self.defaultGammaBlueValue = defaultGammaBlueValue
        blue = Self.gammaValueToSliderValue(defaultGammaBlueValue.doubleValue)

        let _maxDDCBrightness = isSmartBuiltin ? 100 : (try container.decodeIfPresent(UInt16.self, forKey: .maxDDCBrightness)?.ns) ?? 100.ns
        let _maxDDCContrast = isSmartBuiltin ? 100 : (try container.decodeIfPresent(UInt16.self, forKey: .maxDDCContrast)?.ns) ?? 100.ns
        maxDDCVolume = isSmartBuiltin ? 100 : (try container.decodeIfPresent(UInt16.self, forKey: .maxDDCVolume)?.ns) ?? 100.ns
        maxDDCBrightness = _maxDDCBrightness
        maxDDCContrast = _maxDDCContrast

        minDDCBrightness = isSmartBuiltin ? 0 : (try container.decodeIfPresent(UInt16.self, forKey: .minDDCBrightness)?.ns) ?? 0.ns
        minDDCContrast = isSmartBuiltin ? 0 : (try container.decodeIfPresent(UInt16.self, forKey: .minDDCContrast)?.ns) ?? 0.ns
        minDDCVolume = isSmartBuiltin ? 0 : (try container.decodeIfPresent(UInt16.self, forKey: .minDDCVolume)?.ns) ?? 0.ns

        faceLightBrightness = (try container.decodeIfPresent(UInt16.self, forKey: .faceLightBrightness)?.ns) ?? _maxDDCBrightness
        faceLightContrast = (try container.decodeIfPresent(UInt16.self, forKey: .faceLightContrast)?.ns) ??
            (_maxDDCContrast.doubleValue * 0.9).intround.ns

        cornerRadius = (try container.decodeIfPresent(Int.self, forKey: .cornerRadius)?.ns) ?? 0

        reapplyColorGain = (try container.decodeIfPresent(Bool.self, forKey: .reapplyColorGain)) ?? false
        extendedColorGain = (try container.decodeIfPresent(Bool.self, forKey: .extendedColorGain)) ?? false
        redGain = (try container.decodeIfPresent(UInt16.self, forKey: .redGain)?.ns) ?? DEFAULT_COLOR_GAIN.ns
        greenGain = (try container.decodeIfPresent(UInt16.self, forKey: .greenGain)?.ns) ?? DEFAULT_COLOR_GAIN.ns
        blueGain = (try container.decodeIfPresent(UInt16.self, forKey: .blueGain)?.ns) ?? DEFAULT_COLOR_GAIN.ns

        lockedBrightness = (try container.decodeIfPresent(Bool.self, forKey: .lockedBrightness)) ?? false
        lockedContrast = (try container.decodeIfPresent(Bool.self, forKey: .lockedContrast)) ?? false

        lockedBrightnessCurve = (try container.decodeIfPresent(Bool.self, forKey: .lockedBrightnessCurve)) ?? false
        lockedContrastCurve = (try container.decodeIfPresent(Bool.self, forKey: .lockedContrastCurve)) ?? false

        alwaysUseNetworkControl = (try container.decodeIfPresent(Bool.self, forKey: .alwaysUseNetworkControl)) ?? false
        neverUseNetworkControl = (try container.decodeIfPresent(Bool.self, forKey: .neverUseNetworkControl)) ?? false
        alwaysFallbackControl = (try container.decodeIfPresent(Bool.self, forKey: .alwaysFallbackControl)) ?? false
        neverFallbackControl = (try container.decodeIfPresent(Bool.self, forKey: .neverFallbackControl)) ?? false

        let volume = ((try container.decodeIfPresent(UInt16.self, forKey: .volume))?.ns ?? 50.ns)
        self.volume = volume
        preciseVolume = volume.doubleValue / 100.0
        audioMuted = (try container.decodeIfPresent(Bool.self, forKey: .audioMuted)) ?? false
        canChangeVolume = (try container.decodeIfPresent(Bool.self, forKey: .canChangeVolume)) ?? true
        isSource = try container.decodeIfPresent(Bool.self, forKey: .isSource) ?? DDC.isSmartBuiltinDisplay(id)
        showVolumeOSD = try container.decodeIfPresent(Bool.self, forKey: .showVolumeOSD) ?? true
        muteByteValueOn = try container.decodeIfPresent(UInt16.self, forKey: .muteByteValueOn) ?? 1
        muteByteValueOff = try container.decodeIfPresent(UInt16.self, forKey: .muteByteValueOff) ?? 2
        volumeValueOnMute = try container.decodeIfPresent(UInt16.self, forKey: .volumeValueOnMute) ?? 0
        applyMuteValueOnMute = try container
            .decodeIfPresent(Bool.self, forKey: .applyMuteValueOnMute) ?? true
        applyVolumeValueOnMute = try container
            .decodeIfPresent(Bool.self, forKey: .applyVolumeValueOnMute) ?? CachedDefaults[.muteVolumeZero]

        applyGamma = try container.decodeIfPresent(Bool.self, forKey: .applyGamma) ?? false
        input = (try container.decodeIfPresent(UInt16.self, forKey: .input))?.ns ?? VideoInputSource.unknown.rawValue.ns
        forceDDC = (try container.decodeIfPresent(Bool.self, forKey: .forceDDC)) ?? false
        adaptiveSubzero = try container.decodeIfPresent(Bool.self, forKey: .adaptiveSubzero) ?? true

        hotkeyInput1 = try (
            (try container.decodeIfPresent(UInt16.self, forKey: .hotkeyInput1))?
                .ns ?? (try container.decodeIfPresent(UInt16.self, forKey: .hotkeyInput))?.ns ?? VideoInputSource.unknown.rawValue.ns
        )
        hotkeyInput2 = (try container.decodeIfPresent(UInt16.self, forKey: .hotkeyInput2))?.ns ?? VideoInputSource.unknown.rawValue.ns
        hotkeyInput3 = (try container.decodeIfPresent(UInt16.self, forKey: .hotkeyInput3))?.ns ?? VideoInputSource.unknown.rawValue.ns

        brightnessOnInputChange1 = (try container.decodeIfPresent(Double.self, forKey: .brightnessOnInputChange1)) ?? 100.0
        brightnessOnInputChange2 = (try container.decodeIfPresent(Double.self, forKey: .brightnessOnInputChange2)) ?? 100.0
        brightnessOnInputChange3 = (try container.decodeIfPresent(Double.self, forKey: .brightnessOnInputChange3)) ?? 100.0
        contrastOnInputChange1 = (try container.decodeIfPresent(Double.self, forKey: .contrastOnInputChange1)) ?? 75.0
        contrastOnInputChange2 = (try container.decodeIfPresent(Double.self, forKey: .contrastOnInputChange2)) ?? 75.0
        contrastOnInputChange3 = (try container.decodeIfPresent(Double.self, forKey: .contrastOnInputChange3)) ?? 75.0

        applyBrightnessOnInputChange1 = (try container.decodeIfPresent(Bool.self, forKey: .applyBrightnessOnInputChange1)) ?? false
        applyBrightnessOnInputChange2 = (try container.decodeIfPresent(Bool.self, forKey: .applyBrightnessOnInputChange2)) ?? true
        applyBrightnessOnInputChange3 = (try container.decodeIfPresent(Bool.self, forKey: .applyBrightnessOnInputChange3)) ?? false

        if let syncUserBrightness = (try? userBrightnessContainer.decodeIfPresent([UserValue].self, forKey: .sync)) ??
            (try? userBrightnessContainer.decodeIfPresent([Int: Int].self, forKey: .sync))?.userValues
        {
            userBrightness[.sync] = syncUserBrightness.threadSafeDictionary
        }
        if let sensorUserBrightness = (try? userBrightnessContainer.decodeIfPresent([UserValue].self, forKey: .sensor)) ??
            (try? userBrightnessContainer.decodeIfPresent([Int: Int].self, forKey: .sensor))?.userValues
        {
            userBrightness[.sensor] = sensorUserBrightness.threadSafeDictionary
        }
        if let locationUserBrightness = (try? userBrightnessContainer.decodeIfPresent([UserValue].self, forKey: .location)) ??
            (try? userBrightnessContainer.decodeIfPresent([Int: Int].self, forKey: .location))?.userValues
        {
            userBrightness[.location] = locationUserBrightness.threadSafeDictionary
        }
        if let manualUserBrightness = (try? userBrightnessContainer.decodeIfPresent([UserValue].self, forKey: .manual)) ??
            (try? userBrightnessContainer.decodeIfPresent([Int: Int].self, forKey: .manual))?.userValues
        {
            userBrightness[.manual] = manualUserBrightness.threadSafeDictionary
        }
        if let clockUserBrightness = (try? userBrightnessContainer.decodeIfPresent([UserValue].self, forKey: .clock)) ??
            (try? userBrightnessContainer.decodeIfPresent([Int: Int].self, forKey: .clock))?.userValues
        {
            userBrightness[.clock] = clockUserBrightness.threadSafeDictionary
        }

        if let syncUserContrast = (try? userContrastContainer.decodeIfPresent([UserValue].self, forKey: .sync)) ??
            (try? userContrastContainer.decodeIfPresent([Int: Int].self, forKey: .sync))?.userValues
        {
            userContrast[.sync] = syncUserContrast.threadSafeDictionary
        }
        if let sensorUserContrast = (try? userContrastContainer.decodeIfPresent([UserValue].self, forKey: .sensor)) ??
            (try? userContrastContainer.decodeIfPresent([Int: Int].self, forKey: .sensor))?.userValues
        {
            userContrast[.sensor] = sensorUserContrast.threadSafeDictionary
        }
        if let locationUserContrast = (try? userContrastContainer.decodeIfPresent([UserValue].self, forKey: .location)) ??
            (try? userContrastContainer.decodeIfPresent([Int: Int].self, forKey: .location))?.userValues
        {
            userContrast[.location] = locationUserContrast.threadSafeDictionary
        }
        if let manualUserContrast = (try? userContrastContainer.decodeIfPresent([UserValue].self, forKey: .manual)) ??
            (try? userContrastContainer.decodeIfPresent([Int: Int].self, forKey: .manual))?.userValues
        {
            userContrast[.manual] = manualUserContrast.threadSafeDictionary
        }
        if let clockUserContrast = (try? userContrastContainer.decodeIfPresent([UserValue].self, forKey: .clock)) ??
            (try? userContrastContainer.decodeIfPresent([Int: Int].self, forKey: .clock))?.userValues
        {
            userContrast[.clock] = clockUserContrast.threadSafeDictionary
        }

        for adaptiveModeKey in AdaptiveModeKey.allCases {
            if userBrightness[adaptiveModeKey] == nil || userBrightness[adaptiveModeKey]!.isEmpty {
                userBrightness[adaptiveModeKey] = ThreadSafeDictionary(dict: [0: 0])
            } else if let d = userBrightness[adaptiveModeKey]?.dictionary,
                      min(Array(d.keys)) > 0, min(Array(d.values)) > 0
            {
                userBrightness[adaptiveModeKey]![0] = 0
            }

            if userContrast[adaptiveModeKey] == nil || userContrast[adaptiveModeKey]!.isEmpty {
                userContrast[adaptiveModeKey] = ThreadSafeDictionary(dict: [0: 0])
            } else if let d = userContrast[adaptiveModeKey]?.dictionary,
                      min(Array(d.keys)) > 0, min(Array(d.values)) > 0
            {
                userContrast[adaptiveModeKey]![0] = 0
            }
        }

        if let sensorFactor = try brightnessCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .sensor) {
            brightnessCurveFactors[.sensor] = sensorFactor > 0 ? sensorFactor : DEFAULT_SENSOR_BRIGHTNESS_CURVE_FACTOR
        }
        if let syncFactor = try brightnessCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .sync) {
            brightnessCurveFactors[.sync] = syncFactor > 0 ? syncFactor : DEFAULT_SYNC_BRIGHTNESS_CURVE_FACTOR
        }
        if let locationFactor = try brightnessCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .location) {
            brightnessCurveFactors[.location] = locationFactor > 0 ? locationFactor : DEFAULT_LOCATION_BRIGHTNESS_CURVE_FACTOR
        }
        if let manualFactor = try brightnessCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .manual) {
            brightnessCurveFactors[.manual] = manualFactor > 0 ? manualFactor : DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR
        }
        if let clockFactor = try brightnessCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .clock) {
            brightnessCurveFactors[.clock] = clockFactor > 0 ? clockFactor : DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR
        }

        if let sensorFactor = try contrastCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .sensor) {
            contrastCurveFactors[.sensor] = sensorFactor > 0 ? sensorFactor : DEFAULT_SENSOR_CONTRAST_CURVE_FACTOR
        }
        if let syncFactor = try contrastCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .sync) {
            contrastCurveFactors[.sync] = syncFactor > 0 ? syncFactor : DEFAULT_SYNC_CONTRAST_CURVE_FACTOR
        }
        if let locationFactor = try contrastCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .location) {
            contrastCurveFactors[.location] = locationFactor > 0 ? locationFactor : DEFAULT_LOCATION_CONTRAST_CURVE_FACTOR
        }
        if let manualFactor = try contrastCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .manual) {
            contrastCurveFactors[.manual] = manualFactor > 0 ? manualFactor : DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR
        }
        if let clockFactor = try contrastCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .clock) {
            contrastCurveFactors[.clock] = clockFactor > 0 ? clockFactor : DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR
        }

        super.init()
        defer {
            initialised = true
            supportsEnhance = getSupportsEnhance()
            showVolumeSlider = canChangeVolume && CachedDefaults[.showVolumeSlider]
            noDDCOrMergedBrightnessContrast = !hasDDC || CachedDefaults[.mergeBrightnessContrast]
            showOrientation = canRotate && CachedDefaults[.showOrientationInQuickActions]
            withoutModeChangeAsk {
                withoutApply {
                    rotation = CGDisplayRotation(id).intround
                    enhanced = Self.getWindowController(id, type: "hdr") != nil
                }
            }
        }

        preciseBrightness = brightnessToSliderValue(brightness)
        preciseContrast = contrastToSliderValue(contrast, merged: CachedDefaults[.mergeBrightnessContrast])
        preciseBrightnessContrast = brightnessToSliderValue(brightness)

        if !supportsGammaByDefault {
            useOverlay = true
        } else {
            useOverlay = (try container.decodeIfPresent(Bool.self, forKey: .useOverlay)) ?? false
        }

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
            mirroredBeforeBlackOut = ((try container.decodeIfPresent(Bool.self, forKey: .mirroredBeforeBlackOut)) ?? false)
        }

        if isFakeDummy {
            blackOutMirroringAllowed = true
        } else {
            blackOutMirroringAllowed =
                ((try container.decodeIfPresent(Bool.self, forKey: .blackOutMirroringAllowed)) ?? supportsGammaByDefault) &&
                supportsGammaByDefault
        }
        blackOutEnabled = ((try container.decodeIfPresent(Bool.self, forKey: .blackOutEnabled)) ?? false) && !isIndependentDummy &&
            (isNative ? (brightness.uint16Value <= 1) : true)
        if blackOutEnabled, minBrightness == 1 {
            self.minBrightness = 0
        }

        if let value = (try container.decodeIfPresent(UInt16.self, forKey: .brightnessBeforeBlackout)?.ns) {
            brightnessBeforeBlackout = value
        }
        if let value = (try container.decodeIfPresent(UInt16.self, forKey: .contrastBeforeBlackout)?.ns) {
            contrastBeforeBlackout = value
        }
        if let value = (try container.decodeIfPresent(UInt16.self, forKey: .minBrightnessBeforeBlackout)?.ns) {
            minBrightnessBeforeBlackout = value
        }
        if let value = (try container.decodeIfPresent(UInt16.self, forKey: .minContrastBeforeBlackout)?.ns) {
            minContrastBeforeBlackout = value
        }

        faceLightEnabled = ((try container.decodeIfPresent(Bool.self, forKey: .faceLightEnabled)) ?? false)
        if let value = (try container.decodeIfPresent(UInt16.self, forKey: .brightnessBeforeFacelight)?.ns) {
            brightnessBeforeFacelight = value
        }
        if let value = (try container.decodeIfPresent(UInt16.self, forKey: .contrastBeforeFacelight)?.ns) {
            contrastBeforeFacelight = value
        }
        if let value = (try container.decodeIfPresent(UInt16.self, forKey: .maxBrightnessBeforeFacelight)?.ns) {
            maxBrightnessBeforeFacelight = value
        }
        if let value = (try container.decodeIfPresent(UInt16.self, forKey: .maxContrastBeforeFacelight)?.ns) {
            maxContrastBeforeFacelight = value
        }

        if let value = (try container.decodeIfPresent([BrightnessSchedule].self, forKey: .schedules)),
           value.count == Display.DEFAULT_SCHEDULES.count
        {
            schedules = value
        }
        setupHotkeys()
        guard active else { return }

        if let dict = displayInfoDictionary(id) {
            infoDictionary = dict
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

        self.minBrightness = isSmartBuiltin ? 0 : minBrightness.ns
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

        if isSmartBuiltin {
            preciseBrightness = AppleNativeControl.readBrightnessDisplayServices(id: id)
            brightness = (preciseBrightness * 100).ns
        } else {
            preciseBrightnessContrast = mapNumber(
                50,
                fromLow: minBrightness.d,
                fromHigh: maxBrightness.d,
                toLow: 0,
                toHigh: 100
            ) / 100.0
        }

        defer {
            initialised = true
            supportsEnhance = getSupportsEnhance()
            showVolumeSlider = canChangeVolume && CachedDefaults[.showVolumeSlider]
            noDDCOrMergedBrightnessContrast = !hasDDC || CachedDefaults[.mergeBrightnessContrast]
            showOrientation = canRotate && CachedDefaults[.showOrientationInQuickActions]
            withoutModeChangeAsk {
                withoutApply {
                    rotation = CGDisplayRotation(id).intround
                    enhanced = Self.getWindowController(id, type: "hdr") != nil
                }
            }
            blackOutMirroringAllowed = supportsGammaByDefault || isFakeDummy
        }

        if isLEDCinema() || isThunderbolt() {
            maxDDCBrightness = 255
        }
        if isLEDCinema() {
            maxDDCVolume = 255
        }

        useOverlay = !supportsGammaByDefault
        enabledControls[.ddc] = !isTV && !isStudioDisplay()
        enabledControls[.gamma] = !isSmartBuiltin
        guard active else { return }
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
        updateCornerWindow()
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
        case allowBrightnessZero

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
        case userBrightness
        case userContrast
        case useOverlay
        case alwaysUseNetworkControl
        case neverUseNetworkControl
        case alwaysFallbackControl
        case neverFallbackControl
        case enabledControls
        case schedules
        case brightnessCurveFactors
        case contrastCurveFactors
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
        case rotation
        case adaptiveController
        case subzero
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

        static var needsLunarPro: Set<CodingKeys> = [
            .faceLightEnabled,
            .blackOutEnabled,
            .facelight,
            .blackout,
            .xdr,
            .xdrBrightness,
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
            .lockedBrightness,
            .lockedContrast,
            .lockedBrightnessCurve,
            .lockedContrastCurve,
            .audioMuted,
            .mute,
            .canChangeVolume,
            .power,
            .useOverlay,
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
            .allowBrightnessZero,
            .mirroredBeforeBlackOut,
            .subzero,
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
        ]

        static var hidden: Set<CodingKeys> = [
            .hotkeyInput,
            .brightnessOnInputChange,
            .contrastOnInputChange,
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
        ]
        static var settable: Set<CodingKeys> = [
            .name,
            .adaptive,
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
            .rotation,
            .adaptiveController,
            .subzero,
            .xdr,
            .hdr,
            .softwareBrightness,
            .subzeroDimming,
            .xdrBrightness,
            .normalizedBrightness,
            .normalizedContrast,
            .normalizedBrightnessContrast,
            .systemAdaptiveBrightness,
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
    }

    static let DEFAULT_SCHEDULES = [
        BrightnessSchedule(type: .disabled, hour: 0, minute: 30, brightness: 70, contrast: 65, negative: true),
        BrightnessSchedule(type: .disabled, hour: 10, minute: 20, brightness: 80, contrast: 70, negative: false),
        BrightnessSchedule(type: .disabled, hour: 0, minute: 0, brightness: 100, contrast: 75, negative: false),
        BrightnessSchedule(type: .disabled, hour: 1, minute: 30, brightness: 60, contrast: 60, negative: false),
        BrightnessSchedule(type: .disabled, hour: 7, minute: 30, brightness: 20, contrast: 45, negative: false),
    ]

    @Atomic static var applySource = true

    static let dummyNamePattern = "dummy|[^u]28e850|^28e850".r!
    static let notDummyNamePattern = "not a dummy".r!

    static let numberNamePattern = #"\s*\(\d\)\s*"#.r!

    static var onFinishedUserAdjusting: (() -> Void)? = nil

    static let MIN_SOFTWARE_BRIGHTNESS: Float = 1.000001
    static let FILLED_CHICLET_OFFSET: Float = 1 / 16
    static let SUBZERO_FILLED_CHICLETS_THRESHOLDS: [Float] = (0 ... 16).map { FILLED_CHICLET_OFFSET * $0.f }

    static var DEFAULT_USER_VALUE_DICT: ThreadSafeDictionary<AdaptiveModeKey, ThreadSafeDictionary<Double, Double>> {
        ThreadSafeDictionary(dict: [
            .sync: ThreadSafeDictionary(dict: [0: 0]),
            .location: ThreadSafeDictionary(dict: [0: 0]),
            .sensor: ThreadSafeDictionary(dict: [0: 0]),
            .clock: ThreadSafeDictionary(dict: [0: 0]),
            .manual: ThreadSafeDictionary(dict: [0: 0]),
        ])
    }

    lazy var xdrFilledChicletOffset = 6 / (96 * (1 / (maxSoftwareBrightness - Self.MIN_SOFTWARE_BRIGHTNESS)))
    lazy var xdrFilledChicletsThresholds: [Float] = (0 ... 16).map { 1.0 + xdrFilledChicletOffset * $0.f }
    @Published @objc dynamic var appPreset: AppException? = nil

    @objc dynamic lazy var hasAmbientLightAdaptiveBrightness: Bool = DisplayServicesHasAmbientLightCompensation(id)
    @objc dynamic lazy var canBeSource: Bool = {
        allowAnySyncSourcePublisher.sink { [weak self] change in
            guard let self else { return }
            self.canBeSource = (self.hasAmbientLightAdaptiveBrightness && self.supportsGammaByDefault) || change.newValue
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
    lazy var canChangeBrightnessDS: Bool = DisplayServicesCanChangeBrightness(id)

    lazy var _hotkeyPopover: NSPopover? = INPUT_HOTKEY_POPOVERS[serial] ?? nil
    lazy var hotkeyPopoverController: HotkeyPopoverController? = initHotkeyPopoverController()

    var _idLock = NSRecursiveLock()
    var _id: CGDirectDisplayID

    var transport: Transport? = nil
    var edidName: String
    lazy var lastVolume: NSNumber = volume

    @Published @objc dynamic var activeAndResponsive = false

    var schedules: [BrightnessSchedule] = Display.DEFAULT_SCHEDULES
    @Published var enabledControls: [DisplayControl: Bool] = [
        .network: true,
        .appleNative: true,
        .ddc: true,
        .gamma: true,
    ]

    var brightnessCurveFactors: [AdaptiveModeKey: Double] = [
        .sensor: DEFAULT_SENSOR_BRIGHTNESS_CURVE_FACTOR,
        .sync: DEFAULT_SYNC_BRIGHTNESS_CURVE_FACTOR,
        .location: DEFAULT_LOCATION_BRIGHTNESS_CURVE_FACTOR,
        .manual: DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR,
        .clock: DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR,
    ]

    var contrastCurveFactors: [AdaptiveModeKey: Double] = [
        .sensor: DEFAULT_SENSOR_CONTRAST_CURVE_FACTOR,
        .sync: DEFAULT_SYNC_CONTRAST_CURVE_FACTOR,
        .location: DEFAULT_LOCATION_CONTRAST_CURVE_FACTOR,
        .manual: DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR,
        .clock: DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR,
    ]

    @objc dynamic var sentBrightnessCondition = NSCondition()
    @objc dynamic var sentContrastCondition = NSCondition()
    @objc dynamic var sentInputCondition = NSCondition()
    @objc dynamic var sentVolumeCondition = NSCondition()

    var userBrightness: ThreadSafeDictionary<AdaptiveModeKey, ThreadSafeDictionary<Double, Double>> = DEFAULT_USER_VALUE_DICT
    var userContrast: ThreadSafeDictionary<AdaptiveModeKey, ThreadSafeDictionary<Double, Double>> = DEFAULT_USER_VALUE_DICT

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

    lazy var armProps = DisplayController.armDisplayProperties(display: self)
    @Atomic var force = false

    @Atomic var faceLightEnabled = false

    lazy var brightnessBeforeFacelight = brightness
    lazy var contrastBeforeFacelight = contrast
    lazy var maxBrightnessBeforeFacelight = maxBrightness
    lazy var maxContrastBeforeFacelight = maxContrast

    @Atomic @objc dynamic var mirroredBeforeBlackOut = false
    @Published @objc dynamic var blackOutEnabled = false
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

    lazy var gammaLockPath = "/tmp/lunar-gamma-lock-\(serial)"
    lazy var gammaDistributedLock: NSDistributedLock? = NSDistributedLock(path: gammaLockPath)

    @Atomic var gammaChanged = false

    let VALID_ROTATION_VALUES: Set<Int> = [0, 90, 180, 270]
    @objc dynamic lazy var rotationTooltip: String? = canRotate ? nil : "This monitor doesn't support rotation"
    @objc dynamic lazy var inputTooltip: String? = hasDDC
        ? nil
        : "This monitor doesn't support input switching because DDC is not available"

    lazy var defaultGammaTable = AppDelegate.hdrWorkaround ? GammaTable(for: id) : GammaTable.original
    var lunarGammaTable: GammaTable? = nil
    var lastGammaTable: GammaTable? = nil

    let DEFAULT_GAMMA_PARAMETERS: (Float, Float, Float, Float, Float, Float, Float, Float, Float) = (0, 1, 1, 0, 1, 1, 0, 1, 1)

    @Atomic var settingGamma = false

    lazy var isSidecar: Bool = DDC.isSidecarDisplay(id, name: edidName)
    lazy var isAirplay: Bool = DDC.isAirplayDisplay(id, name: edidName)
    lazy var isVirtual: Bool = DDC.isVirtualDisplay(id, name: edidName)
    lazy var isProjector: Bool = DDC.isProjectorDisplay(id, name: edidName)

    @objc dynamic lazy var supportsGamma: Bool = supportsGammaByDefault && !useOverlay
    @objc dynamic lazy var supportsGammaByDefault: Bool = !isSidecar && !isAirplay && !isVirtual && !isProjector

    @objc dynamic lazy var panelModeTitles: [NSAttributedString] = panelModes.map(\.attributedString)

    @objc dynamic lazy var panelModes: [MPDisplayMode] = {
        let modes = ((panel?.allModes() as? [MPDisplayMode]) ?? []).filter {
            (panel?.isTV ?? false) || !($0.isTVMode && $0.tvMode != 0)
        }
        guard !modes.isEmpty else { return modes }

        let grouped = Dictionary(grouping: modes, by: \.refreshRate).sorted(by: { $0.key >= $1.key })
        return Array(grouped.map { $0.value.sorted(by: { $0.dotsPerInch <= $1.dotsPerInch }).reversed() }.joined())
    }()

    @Atomic var modeChangeAsk = true

    @objc dynamic lazy var isSmartDisplay = panel?.isSmartDisplay ?? DisplayServicesIsSmartDisplay(id)

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

    * The builtin `HDMI` port of the newer Mac devices
        * If possible, use only the `Thunderbolt` ports
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
    @Published var lastSoftwareBrightness: Float = 1.0

    @Atomic var hasSoftwareControl = false

    @Published @objc dynamic var noDDCOrMergedBrightnessContrast = false

    @objc dynamic lazy var hasNotch: Bool = {
        if #available(macOS 12.0, *), isMacBook {
            return self.isBuiltin && ((self.nsScreen?.safeAreaInsets.top ?? 0) > 0 || self.panelMode?.withNotch(modes: self.panelModes) != nil)
        } else {
            return false
        }
    }()

    var cornerRadiusBeforeNotchDisable: NSNumber?
    var cornerRadiusApplier: Repeater?

    lazy var blackoutDisablerPublisher: PassthroughSubject<Bool, Never> = {
        let p = PassthroughSubject<Bool, Never>()
        p.debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] shouldDisable in
                guard shouldDisable, let self, !self.isInMirrorSet else { return }
                lastBlackOutToggleDate = .distantPast
                self.disableBlackOut()
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

                if self.control is DDCControl {
                    self.control?.resetState()
                } else {
                    DDCControl(display: self).resetState()
                }

                self.resetControl()

                appDelegate?.screenWakeAdapterTask = appDelegate?.screenWakeAdapterTask ?? Repeater(every: 2, times: 3) {
                    displayController.adaptBrightness(force: true)
                }
            }.store(in: &observers)
        return p
    }()

    lazy var networkResetPublisher: PassthroughSubject<Bool, Never> = {
        let p = PassthroughSubject<Bool, Never>()
        p.debounce(for: .milliseconds(10), scheduler: RunLoop.main)
            .sink { [weak self] run in
                guard run, let self else { return }

                if self.control is NetworkControl {
                    self.control?.resetState()
                } else {
                    NetworkControl.resetState(serial: self.serial)
                }

                self.resetControl()

                appDelegate?.screenWakeAdapterTask = appDelegate?.screenWakeAdapterTask ?? Repeater(every: 2, times: 5) {
                    displayController.adaptBrightness(force: true)
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

                self.setValue(false, forKey: name)
                (self.value(forKey: conditionName) as? NSCondition)?.broadcast()
            }.store(in: &observers)
        return p
    }()

    var i2cDetectionTask: Repeater? = nil

    var fallbackPromptTime: Date?

    @Published var lastRawBrightness: Double?
    @Published var lastRawContrast: Double?
    @Published var lastRawVolume: Double?

    lazy var xdrDisablePublisher: PassthroughSubject<Bool, Never> = {
        let p = PassthroughSubject<Bool, Never>()
        p
            .debounce(for: .milliseconds(5000), scheduler: RunLoop.main)
            .sink { [weak self] shouldDisable in
                guard let self, shouldDisable else { return }
                self.handleEnhance(false, withoutSettingBrightness: true)
            }.store(in: &observers)

        return p
    }()

    var screenFetcher: Repeater?

    var nativeBrightnessRefresher: Repeater?
    var nativeContrastRefresher: Repeater?

    @Published @objc dynamic var brightnessU16: UInt16 = 50

    var connection: ConnectionType = .unknown

    @Atomic var lastGammaBrightness: Brightness = 100

    @Atomic var isNative = false

    lazy var isMacBook: Bool = isBuiltin && Sysctl.isMacBook

    lazy var usesDDCBrightnessControl: Bool = control is DDCControl || control is NetworkControl

    @Atomic @objc dynamic var adaptiveSubzero = true {
        didSet {
            readapt(newValue: adaptiveSubzero, oldValue: oldValue)
            if !adaptiveSubzero, displayController.adaptiveModeKey != .manual, softwareBrightness < 1 {
                softwareBrightness = 1
            }
        }
    }

    var primaryMirrorScreen: NSScreen? {
        getPrimaryMirrorScreen()
    }

    @available(iOS 16, macOS 13, *)
    @objc dynamic var panelPresets: [MPDisplayPreset] {
        (panel?.presets as? [MPDisplayPreset]) ?? []
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
            displayController.blackOut(
                display: id, state: newValue ? .on : .off,
                mirroringAllowed: displayController.activeDisplayCount == 1 ? false : blackOutMirroringAllowed
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
                adaptivePaused = true
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
            supportsGammaByDefault = !isSidecar && !isAirplay && !isVirtual && !isProjector
            supportsGamma = supportsGammaByDefault && !useOverlay
            guard initialised else { return }

            save()
            resetSoftwareControl()
            preciseBrightness = Double(preciseBrightness)

            displayController.adaptBrightness(for: self, force: true)
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

    #if arch(arm64)
        var dcpName = ""
    #endif

    @Published @objc dynamic var isSource: Bool {
        didSet {
            context = getContext()
            guard Self.applySource else { return }
            Self.applySource = false
            defer {
                Self.applySource = true
            }

            if isSource {
                let normalizedName = Self.numberNamePattern.replaceAll(in: edidName, with: "").trimmed
                displayController.activeDisplayList.filter { $0.id != id }.forEach { d in
                    d.isSource = false
                    if Self.numberNamePattern.replaceAll(in: d.edidName, with: "").trimmed == normalizedName {
                        d.brightnessCurveFactors[.sync] = 1
                        d.contrastCurveFactors[.sync] = 1
                    }
                }
            } else if let builtinDisplay = displayController.builtinDisplay, builtinDisplay.serial != serial {
                builtinDisplay.isSource = true
            } else if let smartDisplay = displayController.externalActiveDisplays.first(where: \.hasAmbientLightAdaptiveBrightness),
                      smartDisplay.serial != serial
            {
                smartDisplay.isSource = true
            }

            datastore.storeDisplays(displayController.displays.values.map { $0 })
            if displayController.adaptiveModeKey == .sync {
                displayController.adaptiveMode.stopWatching()
                displayController.adaptiveMode.watch()
            }
            SyncMode.refresh()
        }
    }

    @objc dynamic var sliderBrightnessCurveFactor: Double {
        get {
            let factor = brightnessCurveFactor
            return factor <= 1
                ? mapNumber(factor, fromLow: 0.01, fromHigh: 1, toLow: 1, toHigh: 0.5)
                : mapNumber(cap(factor, minVal: 1, maxVal: 9), fromLow: 1, fromHigh: 9, toLow: 0.5, toHigh: 0)
        }
        set {
            let factor = newValue <= 0.5
                ? mapNumber(newValue, fromLow: 0, fromHigh: 0.5, toLow: 9, toHigh: 1)
                : mapNumber(newValue, fromLow: 0.5, fromHigh: 1, toLow: 1, toHigh: 0.01)
            brightnessCurveFactor = factor
        }
    }

    @objc dynamic var sliderContrastCurveFactor: Double {
        get {
            let factor = contrastCurveFactor
            return factor <= 1
                ? mapNumber(factor, fromLow: 0.01, fromHigh: 1, toLow: 1, toHigh: 0.5)
                : mapNumber(cap(factor, minVal: 1, maxVal: 9), fromLow: 1, fromHigh: 9, toLow: 0.5, toHigh: 0)
        }
        set {
            let factor = newValue <= 0.5
                ? mapNumber(newValue, fromLow: 0, fromHigh: 0.5, toLow: 9, toHigh: 1)
                : mapNumber(newValue, fromLow: 0.5, fromHigh: 1, toLow: 1, toHigh: 0.01)
            contrastCurveFactor = factor
        }
    }

    @objc dynamic var brightnessCurveFactor: Double {
        get { brightnessCurveFactors[displayController.adaptiveModeKey] ?? 1.0 }
        set {
            let oldValue = brightnessCurveFactors[displayController.adaptiveModeKey]
            brightnessCurveFactors[displayController.adaptiveModeKey] = newValue
            readapt(newValue: newValue, oldValue: oldValue)
            onBrightnessCurveFactorChange?(newValue)
        }
    }

    @objc dynamic var contrastCurveFactor: Double {
        get { contrastCurveFactors[displayController.adaptiveModeKey] ?? 1.0 }
        set {
            let oldValue = contrastCurveFactors[displayController.adaptiveModeKey]
            contrastCurveFactors[displayController.adaptiveModeKey] = newValue
            readapt(newValue: newValue, oldValue: oldValue)
            onContrastCurveFactorChange?(newValue)
        }
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

            if xdrBrightness > 0, !enhanced {
                handleEnhance(true, withoutSettingBrightness: true)
            }
            if xdrBrightness == 0, enhanced {
                handleEnhance(false)
            }

            maxEDR = computeMaxEDR()

            softwareBrightness = mapNumber(
                xdrBrightness,
                fromLow: 0.0,
                fromHigh: 1.0,
                toLow: Self.MIN_SOFTWARE_BRIGHTNESS,
                toHigh: maxSoftwareBrightness
            )
        }
    }

    @objc dynamic var subzeroDimming: Float {
        get { min(softwareBrightness, 1.0) }
        set { softwareBrightness = cap(newValue, minVal: 0.0, maxVal: 1.0) }
    }
    @Published @objc dynamic var softwareBrightness: Float = 1.0 {
        didSet {
            lastSoftwareBrightness = oldValue
            guard apply else { return }
            log.info("Software brightness for \(self) (old: \(lastSoftwareBrightness): \(softwareBrightness))")

            let br = softwareBrightness
            mainAsync {
                self.withoutApply {
                    self
                        .subzero = br < 1.0 ||
                        (br == 1.0 && !self.hasSoftwareControl && self.brightness.uint16Value == self.minBrightness.uint16Value)
                    guard br > 1 else {
                        self.xdrBrightness = 0.0
                        return
                    }
                    self.xdrBrightness = mapNumber(
                        br,
                        fromLow: Self.MIN_SOFTWARE_BRIGHTNESS,
                        fromHigh: self.maxSoftwareBrightness,
                        toLow: 0.0,
                        toHigh: 1.0
                    )
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
        get { Self.ambientLightCompensationEnabled(id) }
        set {
            guard ambientLightCompensationEnabledByUser || force else {
                return
            }
            if !newValue, isBuiltin {
                log.warning("Disabling system adaptive brightness")
                if Logger.trace {
                    Thread.callStackSymbols.forEach {
                        log.info($0)
                    }
                }
            }
            DisplayServicesEnableAmbientLightCompensation(id, newValue)
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
        if enabled { return true }
        if systemAdaptiveBrightness {
            // User must have enabled this manually in the meantime, set it to true manually
            Self.setThreadDictValue(id, type: "ambientLightCompensationEnabledByUser", value: true)
            return true
        }
        return false
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

    var osdWindowController: NSWindowController? {
        get { Self.getWindowController(id, type: "osd") }
        set { Self.setWindowController(id, type: "osd", windowController: newValue) }
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
        guard Sysctl.isMacBook, hasNotch, let mode = panelMode else { return false }

        return mode.withoutNotch(modes: panelModes) != nil
    }() {
        didSet {
            guard apply, Sysctl.isMacBook, hasNotch, let mode = panelMode else { return }

            self.withoutModeChangeAsk {
                if notchEnabled, !oldValue, let modeWithNotch = mode.withNotch(modes: panelModes) {
                    panelMode = modeWithNotch
                    modeNumber = panelMode?.modeNumber ?? -1

                    if let cornerRadiusBeforeNotchDisable, cornerRadiusBeforeNotchDisable == 0 {
                        cornerRadius = 0
                        cornerRadiusApplier = Repeater(every: 0.1, times: 20) { [weak self] in
                            self?.updateCornerWindow()
                        }
                    }
                } else if !notchEnabled, oldValue, let modeWithoutNotch = mode.withoutNotch(modes: panelModes) {
                    if cornerRadiusBeforeNotchDisable == nil { cornerRadiusBeforeNotchDisable = cornerRadius }

                    panelMode = modeWithoutNotch
                    modeNumber = panelMode?.modeNumber ?? -1

                    if let cornerRadiusBeforeNotchDisable, cornerRadiusBeforeNotchDisable == 0 {
                        cornerRadius = 12
                        cornerRadiusApplier = Repeater(every: 0.1, times: 20) { [weak self] in
                            self?.updateCornerWindow()
                        }
                    }
                }
            }
        }
    }

    var averageDDCWriteNanoseconds: UInt64 { displayController.averageDDCWriteNanoseconds[id] ?? 0 }
    var averageDDCReadNanoseconds: UInt64 { displayController.averageDDCReadNanoseconds[id] ?? 0 }

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
                }
            }
        }
    }

    var ddcNotWorking: Bool {
        active && ddcEnabled && (control == nil || (control is GammaControl && !(enabledControls[.gamma] ?? false)))
    }

    @AtomicLock var control: Control? = nil {
        didSet {
            context = getContext()
            mainAsync {
                self.supportsEnhance = self.getSupportsEnhance()
                if self.control is DDCControl {
                    self.ddcWorkingCount = self.ddcWorkingCount + 1
                    self.ddcNotWorkingCount = 0
                }
            }

            if ddcNotWorking, !displayController.displays.isEmpty, isOnline {
                ddcNotWorkingCount = ddcNotWorkingCount + 1
            }

            if !(control is NetworkControl) {
                resetSendingValues()
            }

            guard let control else {
                usesDDCBrightnessControl = false
                hasSoftwareControl = false
                isNative = false

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

            log.debug(
                "Display got \(control.str)",
                context: context
            )
            mainAsync { [weak self] in
                guard let self else { return }
                self.activeAndResponsive = (self.active && self.responsiveDDC) || !(self.control is DDCControl)
                self.hasNetworkControl = self.control is NetworkControl || self.alternativeControlForAppleNative is NetworkControl
            }
            if let oldValue, !oldValue.isSoftware, control.isSoftware {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: FLUX_IDENTIFIER).first {
                    (control as! GammaControl).fluxChecker(flux: app)
                }
                setGamma()
            }
            if isNative {
                alternativeControlForAppleNative = getBestAlternativeControlForAppleNative()
            }
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
        guard let vendorID = infoDictionary[kDisplayVendorID] as? Int64, let v = Vendor(rawValue: vendorID) else {
            return .unknown
        }
        return v
    }

    var hasBrightnessChangeObserver: Bool { Self.isObservingBrightnessChangeDS(id) }

    var displaysInMirrorSet: [Display]? {
        guard isInMirrorSet else { return nil }
        return displayController.activeDisplayList.filter { d in
            d.id == id || d.primaryMirrorScreen?.displayID == id || d.secondaryMirrorScreenID == id
        }
    }

    var primaryMirror: Display? {
        guard let id = primaryMirrorScreen?.displayID else { return nil }
        return displayController.activeDisplays[id]
    }

    var secondaryMirror: Display? {
        guard let id = secondaryMirrorScreenID else { return nil }
        return displayController.activeDisplays[id]
    }

    var isInHardwareMirrorSet: Bool {
        guard isInMirrorSet else { return false }

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
        guard let control, !hasSoftwareControl else { return false }
        if isNative, let alternativeControl = alternativeControlForAppleNative {
            return alternativeControl is DDCControl || alternativeControl is NetworkControl
        }
        return control is DDCControl || control is NetworkControl
    }

    @Published @objc dynamic var enhanced = false {
        didSet {
            guard apply else { return }
            handleEnhance(enhanced)
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
        CGDisplayIsInMirrorSet(id) != 0
    }

    lazy var panel: MPDisplay? = DisplayController.panel(with: id) {
        didSet {
            #if DEBUG
                canRotate = isForTesting || panel?.canChangeOrientation() ?? false
            #else
                canRotate = panel?.canChangeOrientation() ?? false
            #endif
        }
    }

    override var description: String {
        "\(name) [ID \(id)]"
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(serial)
        return hasher.finalize()
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
                if apply(gamma: defaultGammaTable) {
                    lastGammaTable = defaultGammaTable
                }
                gammaChanged = false
            } else {
                reapplyGamma()
            }

            if hasSoftwareControl {
                displayController.adaptBrightness(for: self, force: true)
            } else {
                if applyGamma || gammaChanged {
                    resetSoftwareControl()
                }
                readapt(newValue: applyGamma, oldValue: oldValue)
            }
        }
    }

    @Published var adaptivePaused = false {
        didSet {
            readapt(newValue: adaptivePaused, oldValue: oldValue)
        }
    }

    var shouldAdapt: Bool { adaptive && !adaptivePaused && !systemAdaptiveBrightness }
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
        }
    }

    @objc dynamic var whites = 1.0 {
        didSet {
            defaultGammaRedMax = whites.ns
            defaultGammaGreenMax = whites.ns
            defaultGammaBlueMax = whites.ns
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

    @Published @objc dynamic var lockedContrast = false {
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
        guard maxDDCBrightness.uint16Value != 100 || minDDCBrightness.uint16Value != 0 else {
            return brightness.uint16Value
        }
        return mapNumber(
            brightness.doubleValue,
            fromLow: 0,
            fromHigh: 100,
            toLow: minDDCBrightness.doubleValue,
            toHigh: maxDDCBrightness.doubleValue
        ).rounded().u16
    }

    var limitedContrast: UInt16 {
        guard maxDDCContrast.uint16Value != 100 || minDDCContrast.uint16Value != 0 else {
            return contrast.uint16Value
        }
        return mapNumber(
            contrast.doubleValue,
            fromLow: 0,
            fromHigh: 100,
            toLow: minDDCContrast.doubleValue,
            toHigh: maxDDCContrast.doubleValue
        ).rounded().u16
    }

    var limitedVolume: UInt16 {
        guard maxDDCVolume.uint16Value != 100 || minDDCVolume.uint16Value != 0 else {
            return volume.uint16Value
        }
        return mapNumber(
            volume.doubleValue,
            fromLow: 0,
            fromHigh: 100,
            toLow: minDDCVolume.doubleValue,
            toHigh: maxDDCVolume.doubleValue
        ).rounded().u16
    }

    @Published @objc dynamic var allowBrightnessZero = false {
        didSet {
            guard isBuiltin, minBrightness.intValue <= 1 else { return }
            minBrightness = allowBrightnessZero ? 0 : 1
        }
    }

    @Published @objc dynamic var preciseBrightnessContrast = 0.5 {
        didSet {
            guard applyPreciseValue else {
                log.verbose("preciseBrightnessContrast=\(preciseBrightnessContrast) applyPreciseValue=false")
                return
            }

            let (brightness, contrast) = sliderValueToBrightnessContrast(preciseBrightnessContrast)

            var smallDiff = abs(brightness.i - self.brightness.intValue) < 5
            if !lockedBrightness || hasSoftwareControl {
                withBrightnessTransition(smallDiff ? .instant : brightnessTransition) {
                    mainThread {
                        withoutReapplyPreciseValue {
                            self.brightness = brightness.ns
                        }
                        self.insertBrightnessUserDataPoint(
                            displayController.adaptiveMode.brightnessDataPoint.last,
                            brightness.d, modeKey: displayController.adaptiveModeKey
                        )
                    }
                }
            }

            if !lockedContrast {
                smallDiff = abs(contrast.i - self.contrast.intValue) < 5
                withBrightnessTransition(smallDiff ? .instant : brightnessTransition) {
                    mainThread {
                        withoutReapplyPreciseValue {
                            self.contrast = contrast.ns
                        }
                        self.insertContrastUserDataPoint(
                            displayController.adaptiveMode.contrastDataPoint.last,
                            contrast.d, modeKey: displayController.adaptiveModeKey
                        )
                    }
                }
            }
        }
    }

    @Published @objc dynamic var preciseBrightness = 0.5 {
        didSet {
            guard applyPreciseValue else { return }

            var smallDiff = abs(preciseBrightness - oldValue) < 0.05
            var oldValue = oldValue

            let preciseBrightness = mapNumber(
                cap(preciseBrightness, minVal: 0.0, maxVal: 1.0),
                fromLow: 0.0,
                fromHigh: 1.0,
                toLow: minBrightness.doubleValue / 100.0,
                toHigh: maxBrightness.doubleValue / 100.0
            )
            let brightness = (preciseBrightness * 100).intround

            guard !hasSoftwareControl else {
                if !smallDiff {
                    oldValue = mapNumber(
                        cap(oldValue, minVal: 0.0, maxVal: 1.0),
                        fromLow: 0.0,
                        fromHigh: 1.0,
                        toLow: minBrightness.doubleValue / 100.0,
                        toHigh: maxBrightness.doubleValue / 100.0
                    )
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
                        displayController.adaptiveMode.brightnessDataPoint.last,
                        brightness.d, modeKey: displayController.adaptiveModeKey
                    )
                }
                return
            }

            guard !isNative else {
                withBrightnessTransition(smallDiff ? .instant : brightnessTransition) {
                    mainThread {
                        self.brightness = brightness.ns
                        self.insertBrightnessUserDataPoint(
                            displayController.adaptiveMode.brightnessDataPoint.last,
                            brightness.d, modeKey: displayController.adaptiveModeKey
                        )
                    }
                }
                return
            }

            smallDiff = abs(brightness - self.brightness.intValue) < 5
            withBrightnessTransition(smallDiff ? .instant : brightnessTransition) {
                mainThread {
                    self.brightness = brightness.ns
                    self.insertBrightnessUserDataPoint(
                        displayController.adaptiveMode.brightnessDataPoint.last,
                        brightness.d, modeKey: displayController.adaptiveModeKey
                    )
                }
            }
        }
    }

    @Published @objc dynamic var preciseContrast = 0.5 {
        didSet {
            guard applyPreciseValue else { return }

            let contrast = (mapNumber(
                cap(preciseContrast, minVal: 0.0, maxVal: 1.0),
                fromLow: 0.0,
                fromHigh: 1.0,
                toLow: minContrast.doubleValue / 100.0,
                toHigh: maxContrast.doubleValue / 100.0
            ) * 100).intround

            let smallDiff = abs(contrast - self.contrast.intValue) < 5
            withBrightnessTransition(smallDiff ? .instant : brightnessTransition) {
                mainThread {
                    self.contrast = contrast.ns
                    self.insertContrastUserDataPoint(
                        displayController.adaptiveMode.contrastDataPoint.last,
                        contrast.d, modeKey: displayController.adaptiveModeKey
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
            brightnessU16 = brightness.uint16Value
            save(later: true)
            guard timeSince(lastConnectionTime) > 1 else { return }

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
            }

            guard applyDisplayServices, DDC.apply, !lockedBrightness || hasSoftwareControl, force || brightness != oldValue else {
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

            if (brightness > minBrightness.uint16Value && brightness < maxBrightness.uint16Value) || softwareBrightness == Self
                .MIN_SOFTWARE_BRIGHTNESS
            {
                hideSoftwareOSD()
            }

            if brightness > minBrightness.uint16Value, softwareBrightness < 1 {
                softwareBrightness = 1
            } else if brightness < maxBrightness.uint16Value, softwareBrightness > 1 {
                softwareBrightness = 1
                if displayController.autoXdr { xdrDisablePublisher.send(true) }
                startXDRTimer()
            } else if brightness == minBrightness.uint16Value, !subzero, !hasSoftwareControl {
                withoutApply { subzero = true }
            } else if brightness > minBrightness.uint16Value, subzero {
                withoutApply { subzero = false }
            }

            if DDC.applyLimits, maxDDCBrightness.uint16Value != 100 || minDDCBrightness.uint16Value != 0, !hasSoftwareControl {
                oldBrightness = mapNumber(
                    oldBrightness.d,
                    fromLow: 0,
                    fromHigh: 100,
                    toLow: minDDCBrightness.doubleValue,
                    toHigh: maxDDCBrightness.doubleValue
                ).rounded().u16
                brightness = mapNumber(
                    brightness.d,
                    fromLow: 0,
                    fromHigh: 100,
                    toLow: minDDCBrightness.doubleValue,
                    toHigh: maxDDCBrightness.doubleValue
                ).rounded().u16
            }

            log.info("Set BRIGHTNESS to \(brightness) for \(description) (old: \(oldBrightness))", context: context)
            if Logger.trace {
                Thread.callStackSymbols.forEach {
                    log.info($0)
                }
            }

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
            save(later: true)
            guard timeSince(lastConnectionTime) > 1 else { return }

            userAdjusting = true
            defer {
                userAdjusting = false
            }

            mainThread {
                withoutApplyPreciseValue {
                    preciseContrast = contrastToSliderValue(self.contrast, merged: CachedDefaults[.mergeBrightnessContrast])
                    if reapplyPreciseValue, lockedBrightness, !lockedContrast {
                        preciseBrightnessContrast = contrastToSliderValue(self.contrast)
                    }
                }
            }

            guard !isBuiltin else { return }
            guard DDC.apply, !lockedContrast, force || contrast != oldValue else {
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
                oldContrast = mapNumber(
                    oldContrast.d,
                    fromLow: 0,
                    fromHigh: 100,
                    toLow: minDDCContrast.doubleValue,
                    toHigh: maxDDCContrast.doubleValue
                ).rounded().u16
                contrast = mapNumber(
                    contrast.d,
                    fromLow: 0,
                    fromHigh: 100,
                    toLow: minDDCContrast.doubleValue,
                    toHigh: maxDDCContrast.doubleValue
                ).rounded().u16
            }

            log.info("Set CONTRAST to \(contrast) for \(description) (old: \(oldContrast))", context: context)
            if Logger.trace {
                Thread.callStackSymbols.forEach {
                    log.info($0)
                }
            }

            if let control = control as? DDCControl {
                _ = control.setContrastDebounced(contrast, oldValue: oldContrast, transition: brightnessTransition)
            } else if let control, !control.setContrast(contrast, oldValue: oldContrast, transition: brightnessTransition, onChange: nil) {
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
                volume = mapNumber(volume.d, fromLow: 0, fromHigh: 100, toLow: minDDCVolume.doubleValue, toHigh: maxDDCVolume.doubleValue)
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
            if isForTesting { return true }
        #endif

        return panel?.canChangeOrientation() ?? false
    }

    @objc dynamic lazy var canRotate: Bool = canChangeOrientation {
        didSet {
            rotationTooltip = canRotate ? nil : "This monitor doesn't support rotation"
            #if DEBUG
                showOrientation = CachedDefaults[.showOrientationInQuickActions]
            #else
                showOrientation = canRotate && CachedDefaults[.showOrientationInQuickActions]
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
                                self.withoutModeChangeAsk {
                                    mainThread { self.rotation = oldValue }
                                }
                            }
                        }
                    )
                }
            }
            withoutDDC {
                panelMode = panel?.currentMode
                modeNumber = panelMode?.modeNumber ?? -1
            }
        }
    }

    @objc dynamic lazy var panelMode: MPDisplayMode? = panel?.currentMode {
        didSet {
            guard DDC.apply, modeChangeAsk, let window = appDelegate!.windowController?.window else { return }
            modeNumber = panelMode?.modeNumber ?? -1
            if modeNumber != -1 {
                ask(
                    message: "Resolution Change",
                    info: "Do you want to keep this resolution?\n\nLunar will revert to the last resolution if no option is selected in 15 seconds.",
                    window: window,
                    okButton: "Keep", cancelButton: "Revert",
                    onCompletion: { [weak self] keep in
                        if !keep, let self {
                            self.withoutModeChangeAsk {
                                mainThread {
                                    self.panelMode = oldValue
                                    self.modeNumber = oldValue?.modeNumber ?? -1
                                }
                            }
                        }
                    }
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
            }

            if !active, let controller = hotkeyPopoverController {
                #if DEBUG
                    log.info("Display \(description) is now inactive, disabling hotkeys")
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
            guard !displayController.screensSleeping else { return }
            guard CachedDefaults[.autoRestartOnFailedDDC] else {
                Self.ddcNotWorkingCount[serial] = newValue
                return
            }

            let avoidSafetyChecks = CachedDefaults[.autoRestartOnFailedDDCSooner]
            if newValue >= 2, ddcWorkingCount >= 3,
               avoidSafetyChecks || !displayController.activeDisplayList.contains(where: {
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

    @objc dynamic var copyFromDisplay: Display? = nil {
        didSet {
            guard let display = copyFromDisplay else { return }
            defer { mainAsyncAfter(ms: 200) { self.copyFromDisplay = nil }}

            brightnessCurveFactors = display.brightnessCurveFactors
            contrastCurveFactors = display.contrastCurveFactors
            sliderBrightnessCurveFactor = display.sliderBrightnessCurveFactor
            sliderContrastCurveFactor = display.sliderContrastCurveFactor
        }
    }

    lazy var nsScreen: NSScreen? = {
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification, object: nil)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if let infoDict = displayInfoDictionary(self.id) {
                    self.infoDictionary = infoDict
                }
                self.nsScreen = self.getScreen()
                self.screenFetcher = Repeater(every: 2, times: 5, name: "screen-\(self.serial)") { [weak self] in
                    guard let self else { return }
                    self.nsScreen = self.getScreen()
                }
            }
            .store(in: &observers)

        return getScreen()
    }() {
        didSet {
            self.setNotchState()
            mainAsync {
                self.supportsEnhance = self.getSupportsEnhance()
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
                displayController.currentAudioDisplay = displayController.getCurrentAudioDisplay()
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

    var userBrightnessCodable: [AdaptiveModeKey: [UserValue]] {
        Dictionary(
            userBrightness.map { key, value in
                (key, value.userValues)
            }, uniquingKeysWith: first(this:other:)
        )
    }

    var userContrastCodable: [AdaptiveModeKey: [UserValue]] {
        Dictionary(
            userContrast.map { key, value in
                (key, value.userValues)
            }, uniquingKeysWith: first(this:other:)
        )
    }

    var shouldDetectI2C: Bool { ddcEnabled && !isBuiltin && !isDummy && (forceDDC || supportsGammaByDefault) }

    var potentialEDR: CGFloat { nsScreen?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1.0 }
    var edr: CGFloat { NSScreen.forDisplayID(id)?.maximumExtendedDynamicRangeColorComponentValue ?? 1.0 }

    var brightnessRefresher: DispatchWorkItem? { didSet { oldValue?.cancel() }}
    var contrastRefresher: DispatchWorkItem? { didSet { oldValue?.cancel() }}
    var volumeRefresher: DispatchWorkItem? { didSet { oldValue?.cancel() }}
    var inputRefresher: DispatchWorkItem? { didSet { oldValue?.cancel() }}
    var colorRefresher: DispatchWorkItem? { didSet { oldValue?.cancel() }}

    var gammaSetterTask: DispatchWorkItem? {
        didSet { oldValue?.cancel() }
    }

    static func ambientLightCompensationEnabled(_ id: CGDirectDisplayID) -> Bool {
        guard DisplayServicesHasAmbientLightCompensation(id) else { return false }

        var enabled = false
        DisplayServicesAmbientLightCompensationEnabled(id, &enabled)
        return enabled
    }

    static func isObservingBrightnessChangeDS(_ id: CGDirectDisplayID) -> Bool {
        mainThread { Thread.current.threadDictionary["observingBrightnessChangeDS-\(id)"] as? Bool } ?? false
    }

    static func observeBrightnessChangeDS(_ id: CGDirectDisplayID) -> Bool {
        guard DisplayServicesCanChangeBrightness(id), !isObservingBrightnessChangeDS(id) else { return true }

        let result = DisplayServicesRegisterForBrightnessChangeNotifications(id, id) { _, observer, _, _, userInfo in
            guard !displayController.screensSleeping else { return }
            OperationQueue.main.addOperation {
                guard let value = (userInfo as NSDictionary?)?["value"] as? Double, let observer else { return }
                let id = CGDirectDisplayID(UInt(bitPattern: observer))
                guard !AppleNativeControl.sliderTracking, let display = displayController.activeDisplays[id],
                      !display.inSmoothTransition
                else {
                    return
                }
                let newBrightness = (value * 100).u16
                guard display.brightnessU16 != newBrightness else {
                    return
                }

                log.verbose("newBrightness: \(newBrightness) display.isUserAdjusting: \(display.isUserAdjusting())")
                display.withoutDisplayServices {
                    display.brightness = newBrightness.ns
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
        guard displayController.adaptiveModeKey != .manual else {
            return
        }

        let featureValue = featureValue.rounded(to: 4)
        for (x, y) in values.dictionary {
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
            return mapNumber(value, fromLow: 0.5, fromHigh: 1.0, toLow: 1.0, toHigh: 0.0)
        }

        return mapNumber(value, fromLow: 0.0, fromHigh: 0.5, toLow: 3.0, toHigh: 1.0)
    }

    static func gammaValueToSliderValue(_ value: Double) -> Double {
        if value == 1.0 {
            return 0.5
        }
        if value < 1.0 {
            return mapNumber(value, fromLow: 0.0, fromHigh: 1.0, toLow: 1.0, toHigh: 0.5)
        }

        return mapNumber(value, fromLow: 1.0, fromHigh: 3.0, toLow: 0.5, toHigh: 0.0)
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
            displayController.activeDisplays.count > 1 ||
                CachedDefaults[.allowBlackOutOnSingleScreen] ||
                (hasDDC ?? self.hasDDC)
        ) && !isDummy
    }

    func getPowerOffTooltip(hasDDC: Bool? = nil) -> String {
        guard !(hasDDC ?? self.hasDDC) else {
            return """
            BlackOut simulates a monitor power off by mirroring the contents of the other visible screen to this one and setting this monitor's brightness to absolute 0.

            Can also be toggled with the keyboard using Ctrl-Cmd-6.

            Hold the following keys while clicking the button (or while pressing the hotkey) to change BlackOut behaviour:
            - Shift: make the screen black without mirroring
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
        guard displayController.activeDisplays.count > 1 || CachedDefaults[.allowBlackOutOnSingleScreen] else {
            return """
            At least 2 screens need to be visible for this to work.

            The option can also be enabled for a single screen in Advanced settings.
            """
        }

        return """
        BlackOut simulates a monitor power off by mirroring the contents of the other visible screen to this one and setting this monitor's brightness to absolute 0.

        Can also be toggled with the keyboard using Ctrl-Cmd-6.

        Hold the following keys while clicking the button (or while pressing the hotkey) to change BlackOut behaviour:
        - Shift: make the screen black without mirroring
        - Option and Shift: BlackOut other monitors and keep this one visible

        Emergency Kill Switch: press the ⌘ Command key more than 8 times in a row to force disable BlackOut.
        """
    }

    func powerOff() {
        guard displayController.activeDisplays.count > 1 || CachedDefaults[.allowBlackOutOnSingleScreen] else { return }

        #if arch(arm64)
            if AppDelegate.commandKeyPressed {
                displayController.dis(id)
                return
            }
        #endif

        if hasDDC, AppDelegate.optionKeyPressed, !AppDelegate.shiftKeyPressed {
            _ = control?.setPower(.off)
            return
        }

        guard lunarProOnTrial || lunarProActive else {
            if let url = URL(string: "https://lunar.fyi/#blackout") {
                NSWorkspace.shared.open(url)
            }
            return
        }

        if AppDelegate.optionKeyPressed, AppDelegate.shiftKeyPressed {
            let blackOutEnabled = otherDisplays.contains(where: \.blackOutEnabled)
            otherDisplays.forEach {
                lastBlackOutToggleDate = .distantPast
                displayController.blackOut(
                    display: $0.id,
                    state: blackOutEnabled ? .off : .on,
                    mirroringAllowed: false
                )
            }
            return
        }

        displayController.blackOut(
            display: id,
            state: blackOutEnabled ? .off : .on,
            mirroringAllowed: !AppDelegate.shiftKeyPressed && blackOutMirroringAllowed
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
        mainThread {
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

    #if DEBUG
        @Published @objc dynamic var showOrientation = false
    #else
        @Published @objc dynamic var showOrientation = false
    #endif

    enum ConnectionType: String, DefaultsSerializable, Codable {
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
                return .displayport
            case 1:
                return .usbc
            case 2:
                return .dvi
            case 3:
                return .hdmi
            case 4:
                return .mipi
            case 5:
                return .vga
            default:
                return nil
            }
        }
    }

    static var ddcWorkingCount: [String: Int] = [:]
    static var ddcNotWorkingCount: [String: Int] = [:]

    // #if DEBUG
    //     @objc dynamic lazy var showVolumeSlider: Bool = CachedDefaults[.showVolumeSlider]
    // #else
    @Published @objc dynamic var showVolumeSlider = false
    lazy var preciseBrightnessKey = "setPreciseBrightness-\(serial)"
    lazy var preciseContrastKey = "setPreciseContrast-\(serial)"

    var onBrightnessCurveFactorChange: ((Double) -> Void)? = nil
    var onContrastCurveFactorChange: ((Double) -> Void)? = nil

    @Atomic var initialised = false

    var preciseContrastBeforeAppPreset = 0.5

    @objc dynamic lazy var isDummy: Bool = (
        (Self.dummyNamePattern.matches(name) || vendor == .dummy)
            && vendor != .samsung
            && !Self.notDummyNamePattern.matches(name)
    )
    @objc dynamic lazy var isFakeDummy: Bool = (Self.notDummyNamePattern.matches(name) && vendor == .dummy)

    @objc dynamic lazy var otherDisplays: [Display] = displayController.activeDisplayList.filter { $0.serial != serial }

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

    func setNotchState() {
        mainAsync {
            if #available(macOS 12.0, *), Sysctl.isMacBook {
                self.hasNotch = (self.nsScreen?.safeAreaInsets.top ?? 0) > 0 || self.panelMode?.withNotch(modes: self.panelModes) != nil
            } else {
                self.hasNotch = false
            }

            guard Sysctl.isMacBook, self.hasNotch, let mode = self.panelMode else { return }

            self.withoutApply {
                self.notchEnabled = mode.withoutNotch(modes: self.panelModes) != nil
            }
        }
    }

    func observeBrightnessChangeDS() -> Bool {
        Self.observeBrightnessChangeDS(id)
    }

    func sliderValueToBrightness(_ brightness: PreciseBrightness) -> NSNumber {
        (mapNumber(
            cap(brightness, minVal: 0.0, maxVal: 1.0),
            fromLow: 0.0,
            fromHigh: 1.0,
            toLow: minBrightness.doubleValue / 100.0,
            toHigh: maxBrightness.doubleValue / 100.0
        ) * 100).intround.ns
    }

    func sliderValueToContrast(_ contrast: PreciseContrast) -> NSNumber {
        (mapNumber(
            cap(contrast, minVal: 0.0, maxVal: 1.0),
            fromLow: 0.0,
            fromHigh: 1.0,
            toLow: minContrast.doubleValue / 100.0,
            toHigh: maxContrast.doubleValue / 100.0
        ) * 100).intround.ns
    }

    func brightnessToSliderValue(_ brightness: NSNumber) -> PreciseBrightness {
        mapNumber(
            cap(brightness.doubleValue, minVal: 0, maxVal: 100),
            fromLow: minBrightness.doubleValue,
            fromHigh: maxBrightness.doubleValue,
            toLow: 0,
            toHigh: 100
        ) / 100.0
    }

    func contrastToSliderValue(_ contrast: NSNumber, merged: Bool = true) -> PreciseContrast {
        let c = mapNumber(
            cap(contrast.doubleValue, minVal: 0, maxVal: 100),
            fromLow: minContrast.doubleValue,
            fromHigh: maxContrast.doubleValue,
            toLow: 0,
            toHigh: 100
        ) / 100.0

        return merged ? pow(c, 2) : c
    }

    func sliderValueToBrightnessContrast(_ value: Double) -> (Brightness, Contrast) {
        var brightness = brightness.uint16Value
        var contrast = contrast.uint16Value

        if !lockedBrightness || hasSoftwareControl {
            brightness = (mapNumber(
                cap(value, minVal: 0.0, maxVal: 1.0),
                fromLow: 0.0,
                fromHigh: 1.0,
                toLow: minBrightness.doubleValue / 100.0,
                toHigh: maxBrightness.doubleValue / 100.0
            ) * 100).intround.u16
        }
        if !lockedContrast {
            contrast = (mapNumber(
                pow(cap(value, minVal: 0.0, maxVal: 1.0), 0.5),
                fromLow: 0.0,
                fromHigh: 1.0,
                toLow: minContrast.doubleValue / 100.0,
                toHigh: maxContrast.doubleValue / 100.0
            ) * 100).intround.u16
        }

        return (brightness, contrast)
    }

    func updateCornerWindow() {
        mainThread {
            guard cornerRadius.intValue > 0, active, !isInHardwareMirrorSet,
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

    #if arch(arm64)
        var disconnected: Bool { displayController.possiblyDisconnectedDisplays[id]?.serial == serial }
    #endif

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
            withoutDDC {
                rotation = CGDisplayRotation(id).intround

                guard let mgr = DisplayController.panelManager else { return }
                panel = mgr.display(withID: id.i32) as? MPDisplay

                panelMode = panel?.currentMode
                modeNumber = panel?.currentMode?.modeNumber ?? -1
            }
        }
    }

    func reapplySoftwareControl() {
        guard hasSoftwareControl else {
            resetSoftwareControl()
            return
        }
        if supportsGamma {
            reapplyGamma()
        } else if !supportsGammaByDefault, hasSoftwareControl {
            shade(amount: 1.0 - preciseBrightness, transition: brightnessTransition)
        }
    }

    func shade(
        amount: Double,
        smooth: Bool = true,
        force: Bool = false,
        transition: BrightnessTransition? = nil,
        onChange _: ((Brightness) -> Void)? = nil
    ) {
        guard let screen = nsScreen ?? primaryMirrorScreen, force || (
            !isInHardwareMirrorSet && !isIndependentDummy &&
                timeSince(lastConnectionTime) >= 1 || onlySoftwareDimmingEnabled
        )
        else {
            shadeWindowController?.close()
            shadeWindowController = nil
            return
        }

        shadeTask = nil
        mainThread {
            let brightnessTransition = transition ?? brightnessTransition
            if shadeWindowController?.window == nil {
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
                    w.contentView?.bg = NSColor.black
                    w.contentView?.setNeedsDisplay(w.frame)
                }
            }
            guard let w = shadeWindowController?.window else { return }
            w.setFrameOrigin(CGPoint(x: screen.frame.minX, y: screen.frame.minY))
            w.setFrame(screen.frame, display: false)

            let delay = brightnessTransition == .slow ? 2.0 : 0.6
            if smooth { w.contentView?.transition(delay) }
            if amount == 2 {
                w.contentView?.alphaValue = 1
            } else {
                w.contentView?.alphaValue = mapNumber(
                    cap(amount, minVal: 0.0, maxVal: 1.0),
                    fromLow: 0.0,
                    fromHigh: 1.0,
                    toLow: 0.01,
                    toHigh: 0.85
                )
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
        resetGamma()
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
        if defaultGammaChanged, applyGamma {
            refreshGamma()
        } else {
            lunarGammaTable = nil
        }

        if hasSoftwareControl {
            setGamma(transition: .instant)
        } else if applyGamma, !blackOutEnabled {
            resetSoftwareControl()
        }
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Display else {
            return false
        }
        return serial == other.serial
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
            "isAppleDisplay": isAppleDisplay(),
            "isSource": isSource,
            "showVolumeOSD": showVolumeOSD,
            "forceDDC": forceDDC,
            "applyGamma": applyGamma,
        ]
    }

    func getBestControl(reapply: Bool = true) -> Control {
        let gammaControl = GammaControl(display: self)

        let networkControl = NetworkControl(display: self)
        let appleNativeControl = AppleNativeControl(display: self)
        let ddcControl = DDCControl(display: self)

        if appleNativeControl.isAvailable() {
            if reapply, softwareBrightness == 1.0, applyGamma || gammaChanged {
                if !blackOutEnabled { resetSoftwareControl() }
                appleNativeControl.reapply()
            }
            enabledControls[.gamma] = false
            return appleNativeControl
        }
        if ddcControl.isAvailable() {
            if reapply, softwareBrightness == 1.0, applyGamma || gammaChanged {
                if !blackOutEnabled { resetSoftwareControl() }
                ddcControl.reapply()
            }
            enabledControls[.gamma] = false
            return ddcControl
        }
        if networkControl.isAvailable() {
            if reapply, softwareBrightness == 1.0, applyGamma || gammaChanged {
                if !blackOutEnabled { resetSoftwareControl() }
                networkControl.reapply()
            }
            enabledControls[.gamma] = false
            return networkControl
        }

        return gammaControl
    }

    func getBestAlternativeControlForAppleNative() -> Control? {
        let networkControl = NetworkControl(display: self)
        let ddcControl = DDCControl(display: self)

        if ddcControl.isAvailable() {
            return ddcControl
        }
        if networkControl.isAvailable() {
            return networkControl
        }

        return nil
    }

    func values(_ monitorValue: MonitorValue, modeKey: AdaptiveModeKey) -> (Double, Double, Double, [Double: Double]) {
        var minValue, maxValue, value: Double
        var userValues: [Double: Double]

        switch monitorValue {
        case let .preciseBrightness(brightness):
            value = brightness
            minValue = minBrightness.doubleValue
            maxValue = maxBrightness.doubleValue
            userValues = userBrightness[modeKey]?.dictionary ?? [0: 0]
        case let .preciseContrast(contrast):
            value = contrast
            minValue = minContrast.doubleValue
            maxValue = maxContrast.doubleValue
            userValues = userContrast[modeKey]?.dictionary ?? [0: 0]
        case let .brightness(brightness):
            value = brightness.d
            minValue = minBrightness.doubleValue
            maxValue = maxBrightness.doubleValue
            userValues = userBrightness[modeKey]?.dictionary ?? [0: 0]
        case let .contrast(contrast):
            value = contrast.d
            minValue = minContrast.doubleValue
            maxValue = maxContrast.doubleValue
            userValues = userContrast[modeKey]?.dictionary ?? [0: 0]
        case let .nsBrightness(brightness):
            value = brightness.doubleValue
            minValue = minBrightness.doubleValue
            maxValue = maxBrightness.doubleValue
            userValues = userBrightness[modeKey]?.dictionary ?? [0: 0]
        case let .nsContrast(contrast):
            value = contrast.doubleValue
            minValue = minContrast.doubleValue
            maxValue = maxContrast.doubleValue
            userValues = userContrast[modeKey]?.dictionary ?? [0: 0]
        }

        return (value, minValue, maxValue, userValues)
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
        let refreshSeconds = listensForBrightnessChange ? 5.0 : 2.0
        nativeBrightnessRefresher = nativeBrightnessRefresher ?? Repeater(every: refreshSeconds, name: "\(name) Brightness Refresher") { [weak self] in
            guard let self, !displayController.screensSleeping, self.isNative else {
                return
            }
            self.refreshBrightness()
        }
        nativeContrastRefresher = nativeContrastRefresher ?? Repeater(every: 15, name: "\(name) Contrast Refresher") { [weak self] in
            guard let self, !displayController.screensSleeping, self.isNative else {
                return
            }

            self.refreshContrast()
        }
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
                guard id != TEST_DISPLAY_ID, id != TEST_DISPLAY_PERSISTENT_ID, id != TEST_DISPLAY_PERSISTENT2_ID
                else {
                    return true
                }
            #endif

            #if arch(arm64)
                return DDC.hasAVService(displayID: id, ignoreCache: true)
            #else
                return DDC.hasI2CController(displayID: id, ignoreCache: true)
            #endif
        }()

        mainAsync { self.hasI2C = i2c }
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

        if isLEDCinema() || isThunderbolt() {
            maxDDCBrightness = 255
        }
        if isLEDCinema() {
            maxDDCVolume = 255
        }

        maxDDCContrast = 100.ns
    }

    func resetControl() {
        control = getBestControl()
        if let control, let onControlChange {
            onControlChange(control)
        }

        if !gammaEnabled, applyGamma || gammaChanged || !supportsGamma {
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

    func resetBrightnessCurveFactor(mode: AdaptiveModeKey? = nil) {
        let mode = mode ?? displayController.adaptiveModeKey
        switch mode {
        case .sensor:
            brightnessCurveFactors[mode] = DEFAULT_SENSOR_BRIGHTNESS_CURVE_FACTOR
        case .sync:
            brightnessCurveFactors[mode] = DEFAULT_SYNC_BRIGHTNESS_CURVE_FACTOR
        case .location:
            brightnessCurveFactors[mode] = DEFAULT_LOCATION_BRIGHTNESS_CURVE_FACTOR
        case .manual, .clock, .auto:
            brightnessCurveFactors[mode] = DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR
        }
    }

    func resetContrastCurveFactor(mode: AdaptiveModeKey? = nil) {
        let mode = mode ?? displayController.adaptiveModeKey
        switch mode {
        case .sensor:
            contrastCurveFactors[mode] = DEFAULT_SENSOR_CONTRAST_CURVE_FACTOR
        case .sync:
            contrastCurveFactors[mode] = DEFAULT_SYNC_CONTRAST_CURVE_FACTOR
        case .location:
            contrastCurveFactors[mode] = DEFAULT_LOCATION_CONTRAST_CURVE_FACTOR
        case .manual, .clock, .auto:
            contrastCurveFactors[mode] = DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR
        }
    }

    func save(now: Bool = false, later: Bool = false) {
        if now {
            DataStore.storeDisplay(display: self, now: now)
            return
        }

        if later {
            savingLater.send(true)
            return
        }

        if isSmartBuiltin, !allowBrightnessZero, !blackOutEnabled, minBrightness == 0, softwareBrightness > 0 {
            minBrightness = 1
        }

        saving.send(true)
    }

    func resetName() {
        name = Display.printableName(id)
    }

    func encode(to encoder: Encoder) throws {
        try displayEncodingLock.aroundThrows(ignoreMainThread: true) {
            var container = encoder.container(keyedBy: CodingKeys.self)
            var userBrightnessContainer = container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .userBrightness)
            var userContrastContainer = container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .userContrast)
            var enabledControlsContainer = container.nestedContainer(keyedBy: DisplayControlKeys.self, forKey: .enabledControls)
            var brightnessCurveFactorsContainer = container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .brightnessCurveFactors)
            var contrastCurveFactorsContainer = container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .contrastCurveFactors)

            try container.encode(active, forKey: .active)
            try container.encode(adaptive, forKey: .adaptive)
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
            try container.encode(allowBrightnessZero, forKey: .allowBrightnessZero)
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

            try container.encode(rotation, forKey: .rotation)

            let userBrightness = userBrightnessCodable
            try userBrightnessContainer.encodeIfPresent(userBrightness[.sync], forKey: .sync)
            try userBrightnessContainer.encodeIfPresent(userBrightness[.sensor], forKey: .sensor)
            try userBrightnessContainer.encodeIfPresent(userBrightness[.location], forKey: .location)
            try userBrightnessContainer.encodeIfPresent(userBrightness[.manual], forKey: .manual)
            try userBrightnessContainer.encodeIfPresent(userBrightness[.clock], forKey: .clock)

            let userContrast = userContrastCodable
            try userContrastContainer.encodeIfPresent(userContrast[.sync], forKey: .sync)
            try userContrastContainer.encodeIfPresent(userContrast[.sensor], forKey: .sensor)
            try userContrastContainer.encodeIfPresent(userContrast[.location], forKey: .location)
            try userContrastContainer.encodeIfPresent(userContrast[.manual], forKey: .manual)
            try userContrastContainer.encodeIfPresent(userContrast[.clock], forKey: .clock)

            try enabledControlsContainer.encodeIfPresent(enabledControls[.network], forKey: .network)
            try enabledControlsContainer.encodeIfPresent(enabledControls[.appleNative], forKey: .appleNative)
            try enabledControlsContainer.encodeIfPresent(enabledControls[.ddc], forKey: .ddc)
            try enabledControlsContainer.encodeIfPresent(enabledControls[.gamma], forKey: .gamma)

            try brightnessCurveFactorsContainer.encodeIfPresent(brightnessCurveFactors[.sync], forKey: .sync)
            try brightnessCurveFactorsContainer.encodeIfPresent(brightnessCurveFactors[.sensor], forKey: .sensor)
            try brightnessCurveFactorsContainer.encodeIfPresent(brightnessCurveFactors[.location], forKey: .location)
            try brightnessCurveFactorsContainer.encodeIfPresent(brightnessCurveFactors[.manual], forKey: .manual)
            try brightnessCurveFactorsContainer.encodeIfPresent(brightnessCurveFactors[.clock], forKey: .clock)

            try contrastCurveFactorsContainer.encodeIfPresent(contrastCurveFactors[.sync], forKey: .sync)
            try contrastCurveFactorsContainer.encodeIfPresent(contrastCurveFactors[.sensor], forKey: .sensor)
            try contrastCurveFactorsContainer.encodeIfPresent(contrastCurveFactors[.location], forKey: .location)
            try contrastCurveFactorsContainer.encodeIfPresent(contrastCurveFactors[.manual], forKey: .manual)
            try contrastCurveFactorsContainer.encodeIfPresent(contrastCurveFactors[.clock], forKey: .clock)

            try container.encode(useOverlay, forKey: .useOverlay)
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

            try container.encode(subzero, forKey: .subzero)
            try container.encode(hdr, forKey: .hdr)
            try container.encode(xdr, forKey: .xdr)
            try container.encode(softwareBrightness, forKey: .softwareBrightness)
            try container.encode(subzeroDimming, forKey: .subzeroDimming)
            try container.encode(xdrBrightness, forKey: .xdrBrightness)
            try container.encode(averageDDCWriteNanoseconds, forKey: .averageDDCWriteNanoseconds)
            try container.encode(averageDDCReadNanoseconds, forKey: .averageDDCReadNanoseconds)
            try container.encode(connection, forKey: .connection)
            try container.encode(facelight, forKey: .facelight)
            try container.encode(blackout, forKey: .blackout)
            try container.encode(systemAdaptiveBrightness, forKey: .systemAdaptiveBrightness)
            try container.encode(adaptiveSubzero, forKey: .adaptiveSubzero)
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

            if var armProps = self.armProps {
                armProps.removeValue(forKey: "TimingElements")
                armProps.removeValue(forKey: "ColorElements")
                if let encoded = try? encoder.encode(ForgivingEncodable(armProps)),
                   let compressed = encoded.gzip()?.base64EncodedString()
                {
                    dict["armProps"] = compressed
                }
            }

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

            scope.setExtra(value: dict, key: "display-\(self.serial)")
        }
    }

    func isStudioDisplay() -> Bool {
        edidName.contains(STUDIO_DISPLAY_NAME)
    }

    func isUltraFine() -> Bool {
        edidName.contains(ULTRAFINE_NAME)
    }

    func isThunderbolt() -> Bool {
        edidName.contains(THUNDERBOLT_NAME)
    }

    func isLEDCinema() -> Bool {
        edidName.contains(LED_CINEMA_NAME)
    }

    func isCinema() -> Bool {
        edidName == CINEMA_NAME || edidName == CINEMA_HD_NAME
    }

    func isColorLCD() -> Bool {
        edidName.contains(COLOR_LCD_NAME)
    }

    func isAppleDisplay() -> Bool {
        isStudioDisplay() || isUltraFine() || isThunderbolt() || isLEDCinema() || isCinema() || isAppleVendorID()
    }

    func isAppleVendorID() -> Bool {
        guard let vendorID = infoDictionary["DisplayVendorID"] as? Int else { return false }
        return vendorID == APPLE_DISPLAY_VENDOR_ID
    }

    func checkSlowWrite(elapsedNS: UInt64) {
        if !slowWrite, elapsedNS > MAX_SMOOTH_STEP_TIME_NS * 2 {
            slowWrite = true
        }
        if slowWrite, elapsedNS < MAX_SMOOTH_STEP_TIME_NS * 2 {
            slowWrite = false
        }
    }

    func smoothTransition(
        from currentValue: UInt16,
        to value: UInt16,
        delay: TimeInterval? = nil,
        onStart: (() -> Void)? = nil,
        adjust: @escaping ((UInt16) -> Void)
    ) -> DispatchWorkItem {
        inSmoothTransition = true

        let task = DispatchWorkItem(name: "smoothTransitionDDC: \(self)", flags: .barrier) { [weak self] in
            guard let self else { return }

            var steps = abs(value.distance(to: currentValue))
            log.debug("Smooth transition STEPS=\(steps) for \(self.description) from \(currentValue) to \(value)")

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
            adjust((currentValue.i + step).u16)

            var elapsedTimeInterval = startTime.distance(to: DispatchTime.now())
            var elapsedSecondsStr = String(format: "%.3f", elapsedTimeInterval.s)
            log.debug("It took \(elapsedTimeInterval) (\(elapsedSecondsStr)s) to change brightness by \(step)")

            self.checkSlowWrite(elapsedNS: elapsedTimeInterval.absNS)

            steps = steps - abs(step)
            if steps <= 0 {
                adjust(value)
                return
            }

            self.smoothStep = cap((elapsedTimeInterval.absNS / MAX_SMOOTH_STEP_TIME_NS).i, minVal: 1, maxVal: 100)
            log.debug("Smooth step \(self.smoothStep) for \(self.description) from \(currentValue) to \(value)")
            if value < currentValue {
                step = cap(-self.smoothStep, minVal: -steps, maxVal: -1)
            } else {
                step = cap(self.smoothStep, minVal: 1, maxVal: steps)
            }

            for newValue in stride(from: currentValue.i, through: value.i, by: step) {
                adjust(cap(newValue.u16, minVal: minVal, maxVal: maxVal))
                if let delay {
                    print("Sleeping for \(delay * 1000)ms")
                    Thread.sleep(forTimeInterval: delay)
                }
            }
            adjust(value)

            elapsedTimeInterval = startTime.distance(to: DispatchTime.now())
            elapsedSecondsStr = String(format: "%.3f", elapsedTimeInterval.s)
            log
                .debug(
                    "It took \(elapsedTimeInterval.ns) (\(elapsedSecondsStr)s) to change brightness from \(currentValue) to \(value) by \(step)"
                )

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
            displayController.adaptBrightness(for: self, force: true)
        }
    }

    func possibleDDCBlockers() -> String {
        let specificBlockers: String
        switch vendor {
        case .dell:
            specificBlockers = """
            * Disable **Uniformity Compensation**
            * Set **Preset Mode** to `Custom` or `Standard`
            """
        case .acer:
            specificBlockers = DEFAULT_DDC_BLOCKERS
        case .lg:
            specificBlockers = """
            * Disable **Uniformity**
            * Disable **Auto Brightness**
            * Set **Picture Mode** to `Custom` or `Standard`
            """
        case .samsung:
            specificBlockers = """
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
            specificBlockers = """
            * Disable **Bright Intelligence**
            * Disable **Bright Intelligence Plus** or **B.I.+**
            * Set **Picture Mode** to `Standard`
            """
        case .prism:
            specificBlockers = """
            * Set **On-the-Fly Mode** to `Standard`
            """
        case .lenovo:
            specificBlockers = """
            * Disable **Local Dimming**
            * Disable **HDR**
            * Disable **Dynamic Contrast**
            * Set **Color Mode** to `Custom`
            * Set **Scenario Modes** to `Panel Native`
            """
        case .xiaomi:
            specificBlockers = """
            * Disable **Dynamic Brightness**
            * Set **Smart Mode** to `Standard`
            """
        case .eizo:
            specificBlockers = DEFAULT_DDC_BLOCKERS
        case .apple:
            specificBlockers = DEFAULT_DDC_BLOCKERS
        case .asus:
            specificBlockers = DEFAULT_DDC_BLOCKERS
        case .hp:
            specificBlockers = DEFAULT_DDC_BLOCKERS
        case .huawei:
            specificBlockers = DEFAULT_DDC_BLOCKERS
        case .philips:
            specificBlockers = DEFAULT_DDC_BLOCKERS
        case .sceptre:
            specificBlockers = DEFAULT_DDC_BLOCKERS
        case .proart:
            specificBlockers = DEFAULT_DDC_BLOCKERS
        default:
            specificBlockers = DEFAULT_DDC_BLOCKERS
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

    func readBrightness() -> UInt16? {
        control?.getBrightness()
    }

    func refreshColors(onComplete: ((Bool) -> Void)? = nil) {
        guard !isTestID(id), !isSmartBuiltin,
              !displayController.screensSleeping
        else { return }
        colorRefresher = asyncAfter(ms: 10) { [weak self] in
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
              !displayController.screensSleeping
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
              !SyncMode.possibleClamshellModeSoon, !hasSoftwareControl, !displayController.screensSleeping
        else { return }

        brightnessRefresher = asyncAfter(ms: 10) { [weak self] in
            guard let self else { return }
            guard let newBrightness = self.readBrightness() else {
                log.warning("Can't read brightness for \(self.name)")
                return
            }

            mainAsync {
                guard !self.inSmoothTransition, !self.isUserAdjusting(), !self.sendingBrightness else { return }
                if newBrightness != self.brightness.uint16Value {
                    log.info("Refreshing brightness: \(self.brightness.uint16Value) <> \(newBrightness)")

                    if displayController.adaptiveModeKey != .manual, displayController.adaptiveModeKey != .clock,
                       timeSince(self.lastConnectionTime) > 10
                    {
                        self.insertBrightnessUserDataPoint(
                            displayController.adaptiveMode.brightnessDataPoint.last,
                            newBrightness.d, modeKey: displayController.adaptiveModeKey
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
              !displayController.screensSleeping
        else { return }

        contrastRefresher = asyncAfter(ms: 10) { [weak self] in
            guard let self else { return }
            guard let newContrast = self.readContrast() else {
                log.warning("Can't read contrast for \(self.name)")
                return
            }

            mainAsync {
                guard !self.inSmoothTransition, !self.isUserAdjusting(), !self.sendingContrast else { return }
                if newContrast != self.contrast.uint16Value {
                    log.info("Refreshing contrast: \(self.contrast.uint16Value) <> \(newContrast)")

                    if displayController.adaptiveModeKey != .manual, displayController.adaptiveModeKey != .clock,
                       timeSince(self.lastConnectionTime) > 10
                    {
                        self.insertContrastUserDataPoint(
                            displayController.adaptiveMode.contrastDataPoint.last,
                            newContrast.d, modeKey: displayController.adaptiveModeKey
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
              !displayController.screensSleeping
        else { return }

        inputRefresher = asyncAfter(ms: 10) { [weak self] in
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
              !displayController.screensSleeping
        else { return }

        volumeRefresher = asyncAfter(ms: 10) { [weak self] in
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
              !displayController.screensSleeping
        else { return }

        guard !defaultGammaChanged || !applyGamma else {
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
        if AppDelegate.hdrWorkaround, restoreColorSyncSettings() {
            defaultGammaTable = GammaTable(for: id)
        } else {
            defaultGammaTable = GammaTable.original
        }
    }

    func resetGamma() {
        guard !isForTesting else { return }

        let gammaTable = (lunarGammaTable ?? defaultGammaTable)
        if apply(gamma: gammaTable) {
            lastGammaTable = gammaTable
        }
        gammaChanged = false
    }

    @discardableResult func gammaLock() -> Bool {
        log.verbose("Locking gamma", context: context)
        return gammaDistributedLock?.try() ?? false
    }

    func gammaUnlock() {
        log.verbose("Unlocking gamma", context: context)
        gammaDistributedLock?.unlock()
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

        guard force || (enabledControls[.gamma] ?? false && (timeSince(lastConnectionTime) >= 1 || onlySoftwareDimmingEnabled))
        else { return }
        gammaLock()
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

        gammaSetterTask = serialAsyncAfter(ms: 1, name: "gamma-setter") { [weak self] in
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
                Thread.sleep(forTimeInterval: brightnessTransition == .slow ? 0.025 : 0.002)
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
    }

    func resetBlackOut() {
        mainAsync { [weak self] in
            guard let self else { return }
            self.resetSoftwareControl()
            displayController.blackOut(display: self.id, state: .off)
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
        if isLEDCinema() || isThunderbolt() {
            maxDDCBrightness = 255.ns
        } else {
            maxDDCBrightness = 100.ns
        }
        if isLEDCinema() {
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

        userContrast[displayController.adaptiveModeKey] = ThreadSafeDictionary(dict: [0: 0])
        userBrightness[displayController.adaptiveModeKey] = ThreadSafeDictionary(dict: [0: 0])

        resetDefaultGamma()

        useOverlay = !supportsGammaByDefault
        alwaysFallbackControl = false
        neverFallbackControl = false
        alwaysUseNetworkControl = false
        neverUseNetworkControl = false
        enabledControls = [
            .network: true,
            .appleNative: true,
            .ddc: !isTV && !isStudioDisplay(),
            .gamma: !DDC.isSmartBuiltinDisplay(id),
        ]
        brightnessCurveFactors = [
            .sensor: DEFAULT_SENSOR_BRIGHTNESS_CURVE_FACTOR,
            .sync: DEFAULT_SYNC_BRIGHTNESS_CURVE_FACTOR,
            .location: DEFAULT_LOCATION_BRIGHTNESS_CURVE_FACTOR,
            .manual: DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR,
            .clock: DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR,
        ]

        contrastCurveFactors = [
            .sensor: DEFAULT_SENSOR_CONTRAST_CURVE_FACTOR,
            .sync: DEFAULT_SYNC_CONTRAST_CURVE_FACTOR,
            .location: DEFAULT_LOCATION_CONTRAST_CURVE_FACTOR,
            .manual: DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR,
            .clock: DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR,
        ]

        adaptive = !Self.ambientLightCompensationEnabled(id)
        adaptivePaused = false

        save()

        if resetControl {
            _ = control?.reset()
        }
        readapt(newValue: false, oldValue: true)
    }

    @inline(__always) func withoutDDCLimits(_ block: () -> Void) {
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

    @inline(__always) func withoutDDC(_ block: () -> Void) {
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

    func getMinMaxFactor(
        type: ValueType,
        factor: Double? = nil,
        minVal: Double? = nil,
        maxVal: Double? = nil
    ) -> (Double, Double, Double) {
        let minValue: Double
        let maxValue: Double
        if type == .brightness {
            maxValue = maxVal ?? maxBrightness.doubleValue
            minValue = minVal ?? minBrightness.doubleValue
        } else {
            maxValue = maxVal ?? maxContrast.doubleValue
            minValue = minVal ?? minContrast.doubleValue
        }

        return (minValue, maxValue, factor ?? 1.0)
    }

    func computeValue(
        from percent: Double,
        type: ValueType,
        factor: Double? = nil,
        appOffset: Int = 0,
        minVal: Double? = nil,
        maxVal: Double? = nil
    ) -> Double {
        let (minValue, maxValue, factor) = getMinMaxFactor(type: type, factor: factor, minVal: minVal, maxVal: maxVal)

        var value: Double
        if percent == 1.0 {
            value = maxValue
        } else if percent == 0.0 {
            value = minValue
        } else {
            value = pow((percent * (maxValue - minValue) + minValue) / 100.0, factor) * 100.0
            value = cap(value, minVal: minValue, maxVal: maxValue)
        }

        if appOffset > 0 {
            value = cap(value + appOffset.d, minVal: minValue, maxVal: maxValue)
        }
        return value.rounded()
    }

    func computeSIMDValue(
        from percent: [Double],
        type: ValueType,
        factor: Double? = nil,
        appOffset: Int = 0,
        minVal: Double? = nil,
        maxVal: Double? = nil
    ) -> [Double] {
        let (minValue, maxValue, factor) = getMinMaxFactor(type: type, factor: factor, minVal: minVal, maxVal: maxVal)

        var value = (percent * (maxValue - minValue) + minValue)
        value /= 100.0
        value = pow(value, factor)

        value = (value * 100.0 + appOffset.d)
        return value.map {
            b in cap(b, minVal: minValue, maxVal: maxValue)
        }
    }

    func insertBrightnessUserDataPoint(_ featureValue: Double, _ targetValue: Double, modeKey: AdaptiveModeKey) {
        guard !lockedBrightnessCurve, !adaptivePaused,
              displayController.adaptiveModeKey != .sync || !isSource,
              displayController.adaptiveModeKey != .location || featureValue != 0,
              timeSince(lastConnectionTime) > 5 else { return }

        brightnessDataPointInsertionTask?.cancel()
        if userBrightness[modeKey] == nil {
            userBrightness[modeKey] = ThreadSafeDictionary(dict: [0: 0])
        }
        var targetValue = mapNumber(
            targetValue,
            fromLow: minBrightness.doubleValue,
            fromHigh: maxBrightness.doubleValue,
            toLow: MIN_BRIGHTNESS.d,
            toHigh: MAX_BRIGHTNESS.d
        )
        if adaptiveSubzero, softwareBrightness < 1 {
            targetValue -= mapNumber(
                softwareBrightness.d,
                fromLow: 0.0,
                fromHigh: 1.0,
                toLow: MAX_BRIGHTNESS.d,
                toHigh: MIN_BRIGHTNESS.d
            )
        }

        brightnessDataPointInsertionTask = DispatchWorkItem(name: "brightnessDataPointInsertionTask") { [weak self] in
            while let self, self.sendingBrightness {
                self.sentBrightnessCondition.wait(until: Date().addingTimeInterval(5.seconds.timeInterval))
            }

            guard let self, var userValues = self.userBrightness[modeKey] else { return }
            Display.insertDataPoint(values: &userValues, featureValue: featureValue, targetValue: targetValue)
            self.save()
            self.brightnessDataPointInsertionTask = nil
        }
        serialAsyncAfter(ms: 2500, brightnessDataPointInsertionTask!)

        var userValues = userBrightness[modeKey]!
        Display.insertDataPoint(values: &userValues, featureValue: featureValue, targetValue: targetValue, logValue: false)
        NotificationCenter.default.post(name: brightnessDataPointInserted, object: self, userInfo: ["values": userValues.dictionary])
    }

    func insertContrastUserDataPoint(_ featureValue: Double, _ targetValue: Double, modeKey: AdaptiveModeKey) {
        guard !lockedContrastCurve, !adaptivePaused,
              displayController.adaptiveModeKey != .sync || !isSource,
              displayController.adaptiveModeKey != .location || featureValue != 0,
              timeSince(lastConnectionTime) > 5 else { return }

        contrastDataPointInsertionTask?.cancel()
        if userContrast[modeKey] == nil {
            userContrast[modeKey] = ThreadSafeDictionary(dict: [0: 0])
        }
        let targetValue = mapNumber(
            targetValue,
            fromLow: minContrast.doubleValue,
            fromHigh: maxContrast.doubleValue,
            toLow: MIN_CONTRAST.d,
            toHigh: MAX_CONTRAST.d
        )

        contrastDataPointInsertionTask = DispatchWorkItem(name: "contrastDataPointInsertionTask") { [weak self] in
            while let self, self.sendingContrast {
                self.sentContrastCondition.wait(until: Date().addingTimeInterval(5.seconds.timeInterval))
            }

            guard let self, var userValues = self.userContrast[modeKey] else { return }
            Display.insertDataPoint(values: &userValues, featureValue: featureValue, targetValue: targetValue)
            self.save()
            self.contrastDataPointInsertionTask = nil
        }
        serialAsyncAfter(ms: 2500, contrastDataPointInsertionTask!)

        var userValues = userContrast[modeKey]!
        Display.insertDataPoint(values: &userValues, featureValue: featureValue, targetValue: targetValue, logValue: false)
        NotificationCenter.default.post(name: contrastDataPointInserted, object: self, userInfo: ["values": userValues.dictionary])
    }

    func isUserAdjusting() -> Bool {
        userAdjusting || brightnessDataPointInsertionTask != nil || contrastDataPointInsertionTask != nil
    }

    func getAdaptiveController() -> AdaptiveController {
        guard adaptive || systemAdaptiveBrightness else {
            return .disabled
        }

        return adaptive ? .lunar : .system
    }
}
