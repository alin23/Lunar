//
//  Display.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import AnyCodable
import Cocoa
import Defaults
import Sentry
import Surge
import SwiftDate

let MIN_VOLUME: Int = 0
let MAX_VOLUME: Int = 100
let MIN_BRIGHTNESS: UInt8 = 0
let MAX_BRIGHTNESS: UInt8 = 100
let MIN_CONTRAST: UInt8 = 0
let MAX_CONTRAST: UInt8 = 100

let DEFAULT_MIN_BRIGHTNESS: UInt8 = 5
let DEFAULT_MAX_BRIGHTNESS: UInt8 = 90
let DEFAULT_MIN_CONTRAST: UInt8 = 20
let DEFAULT_MAX_CONTRAST: UInt8 = 70

let GENERIC_DISPLAY_ID: CGDirectDisplayID = 0
let TEST_DISPLAY_ID: CGDirectDisplayID = 2

let GENERIC_DISPLAY = Display(
    id: GENERIC_DISPLAY_ID,
    serial: "GENERIC_SERIAL",
    name: "No Display",
    minBrightness: 0,
    maxBrightness: 100,
    minContrast: 0,
    maxContrast: 100
)
let TEST_DISPLAY = { Display(
    id: TEST_DISPLAY_ID,
    serial: "TEST_SERIAL",
    name: "Test Display",
    active: true,
    minBrightness: 0,
    maxBrightness: 100,
    minContrast: 0,
    maxContrast: 100,
    adaptive: true
) }

let MAX_SMOOTH_STEP_TIME_NS: UInt64 = 10 * 1_000_000 // 10ms

let ULTRAFINE_NAME = "LG UltraFine"
let THUNDERBOLT_NAME = "Thunderbolt"
let LED_CINEMA_NAME = "LED Cinema"
let COLOR_LCD_NAME = "Color LCD"
let APPLE_DISPLAY_VENDOR_ID = 0x05AC

enum ValueType {
    case brightness
    case contrast
}

@objc class Display: NSObject, Codable {
    @objc dynamic var id: CGDirectDisplayID {
        didSet {
            save()
        }
    }

    @objc dynamic var serial: String {
        didSet {
            save()
        }
    }

    var edidName: String
    @objc dynamic var name: String {
        didSet {
            save()
        }
    }

    @objc dynamic var adaptive: Bool {
        didSet {
            save()
            runBoolObservers(property: "adaptive", newValue: adaptive, oldValue: oldValue)
        }
    }

    @objc dynamic var extendedBrightnessRange: Bool {
        didSet {
            save()

            if brightnessAdapter.mode != .manual {
                brightnessAdapter.adaptBrightness()
            }

            runBoolObservers(property: "extendedBrightnessRange", newValue: extendedBrightnessRange, oldValue: oldValue)
        }
    }

    @objc dynamic var lockedBrightness: Bool {
        didSet {
            save()
            runBoolObservers(property: "lockedBrightness", newValue: lockedBrightness, oldValue: oldValue)
        }
    }

    @objc dynamic var lockedContrast: Bool {
        didSet {
            save()
            runBoolObservers(property: "lockedContrast", newValue: lockedContrast, oldValue: oldValue)
        }
    }

    @objc dynamic var minBrightness: NSNumber {
        didSet {
            save()
            runNumberObservers(property: "minBrightness", newValue: minBrightness, oldValue: oldValue)
        }
    }

    @objc dynamic var maxBrightness: NSNumber {
        didSet {
            save()
            runNumberObservers(property: "maxBrightness", newValue: maxBrightness, oldValue: oldValue)
        }
    }

    @objc dynamic var minContrast: NSNumber {
        didSet {
            save()
            runNumberObservers(property: "minContrast", newValue: minContrast, oldValue: oldValue)
        }
    }

    @objc dynamic var maxContrast: NSNumber {
        didSet {
            save()
            runNumberObservers(property: "maxContrast", newValue: maxContrast, oldValue: oldValue)
        }
    }

    @objc dynamic var brightness: NSNumber {
        didSet {
            save()
            runNumberObservers(property: "brightness", newValue: brightness, oldValue: oldValue)
        }
    }

    @objc dynamic var contrast: NSNumber {
        didSet {
            save()
            runNumberObservers(property: "contrast", newValue: contrast, oldValue: oldValue)
        }
    }

    @objc dynamic var volume: NSNumber {
        didSet {
            save()
            runNumberObservers(property: "volume", newValue: volume, oldValue: oldValue)
        }
    }

    @objc dynamic var input: NSNumber {
        didSet {
            save()
            runNumberObservers(property: "input", newValue: input, oldValue: oldValue)
        }
    }

    @objc dynamic var hotkeyInput: NSNumber {
        didSet {
            save()
            runNumberObservers(property: "hotkeyInput", newValue: hotkeyInput, oldValue: oldValue)
        }
    }

    @objc dynamic var audioMuted: Bool {
        didSet {
            save()
            runBoolObservers(property: "audioMuted", newValue: audioMuted, oldValue: oldValue)
        }
    }

    @objc dynamic var active: Bool = false {
        didSet {
            save()
            runBoolObservers(property: "active", newValue: active, oldValue: oldValue)
            runInMainThread {
                activeAndResponsive = active && responsive
            }
        }
    }

    @objc dynamic var responsive: Bool = true {
        didSet {
            runBoolObservers(property: "responsive", newValue: responsive, oldValue: oldValue)
            runInMainThread {
                activeAndResponsive = active && responsive
            }
        }
    }

    @objc dynamic var activeAndResponsive: Bool = false {
        didSet {
            runBoolObservers(property: "activeAndResponsive", newValue: activeAndResponsive, oldValue: oldValue)
        }
    }

    let semaphore = DispatchSemaphore(value: 1)

    var boolObservers: [String: [String: (Bool, Bool) -> Void]] = [
        "adaptive": [:],
        "extendedBrightnessRange": [:],
        "lockedBrightness": [:],
        "lockedContrast": [:],
        "active": [:],
        "responsive": [:],
        "activeAndResponsive": [:],
        "audioMuted": [:],
    ]
    var numberObservers: [String: [String: (NSNumber, NSNumber) -> Void]] = [
        "minBrightness": [:],
        "maxBrightness": [:],
        "minContrast": [:],
        "maxContrast": [:],
        "brightness": [:],
        "contrast": [:],
        "volume": [:],
        "input": [:],
        "hotkeyInput": [:],
    ]
    var datastoreObservers: [DefaultsObservation] = []
    var onReadapt: (() -> Void)?
    var smoothStep = 1

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(CGDirectDisplayID.self, forKey: .id)
        serial = try values.decode(String.self, forKey: .serial)

        brightness = NSNumber(value: try values.decode(UInt8.self, forKey: .brightness))
        contrast = NSNumber(value: try values.decode(UInt8.self, forKey: .contrast))
        name = try values.decode(String.self, forKey: .name)
        edidName = try values.decode(String.self, forKey: .edidName)
        active = try values.decode(Bool.self, forKey: .active)
        minBrightness = NSNumber(value: try values.decode(UInt8.self, forKey: .minBrightness))
        maxBrightness = NSNumber(value: try values.decode(UInt8.self, forKey: .maxBrightness))
        minContrast = NSNumber(value: try values.decode(UInt8.self, forKey: .minContrast))
        maxContrast = NSNumber(value: try values.decode(UInt8.self, forKey: .maxContrast))
        adaptive = try values.decode(Bool.self, forKey: .adaptive)
        extendedBrightnessRange = try values.decode(Bool.self, forKey: .extendedBrightnessRange)
        lockedBrightness = try values.decode(Bool.self, forKey: .lockedBrightness)
        lockedContrast = try values.decode(Bool.self, forKey: .lockedContrast)
        volume = NSNumber(value: try values.decode(UInt8.self, forKey: .volume))
        audioMuted = try values.decode(Bool.self, forKey: .audioMuted)
        input = NSNumber(value: try values.decode(UInt8.self, forKey: .input))
        hotkeyInput = NSNumber(value: try values.decode(UInt8.self, forKey: .hotkeyInput))
    }

    static func fromDictionary(_ config: [String: Any]) -> Display? {
        guard let id = config["id"] as? CGDirectDisplayID,
              let serial = config["serial"] as? String else { return nil }

        return Display(
            id: id,
            brightness: (config["brightness"] as? UInt8) ?? 50,
            contrast: (config["contrast"] as? UInt8) ?? 50,
            serial: serial,
            name: config["name"] as? String,
            active: (config["active"] as? Bool) ?? false,
            minBrightness: (config["minBrightness"] as? UInt8) ?? DEFAULT_MIN_BRIGHTNESS,
            maxBrightness: (config["maxBrightness"] as? UInt8) ?? DEFAULT_MAX_BRIGHTNESS,
            minContrast: (config["minContrast"] as? UInt8) ?? DEFAULT_MIN_CONTRAST,
            maxContrast: (config["maxContrast"] as? UInt8) ?? DEFAULT_MAX_CONTRAST,
            adaptive: (config["adaptive"] as? Bool) ?? true,
            extendedBrightnessRange: (config["extendedBrightnessRange"] as? Bool) ?? false,
            lockedBrightness: (config["lockedBrightness"] as? Bool) ?? false,
            lockedContrast: (config["lockedContrast"] as? Bool) ?? false,
            volume: (config["volume"] as? UInt8) ?? 10,
            audioMuted: (config["audioMuted"] as? Bool) ?? false,
            input: (config["input"] as? UInt8) ?? InputSource.unknown.rawValue,
            hotkeyInput: (config["hotkeyInput"] as? UInt8) ?? InputSource.unknown.rawValue
        )
    }

    func save() {
        DataStore.storeDisplay(display: self)
    }

    func runNumberObservers(property: String, newValue: NSNumber, oldValue: NSNumber) {
        semaphore.wait()
        guard let obs = numberObservers[property] else {
            semaphore.signal()
            return
        }
        semaphore.signal()

        for (_, observer) in obs {
            observer(newValue, oldValue)
        }
    }

    func runBoolObservers(property: String, newValue: Bool, oldValue: Bool) {
        semaphore.wait()
        guard let obs = boolObservers[property] else {
            semaphore.signal()
            return
        }
        semaphore.signal()

        for (_, observer) in obs {
            observer(newValue, oldValue)
        }
    }

    static func printableName(id: CGDirectDisplayID) -> String {
        if var name = DDC.getDisplayName(for: id) {
            name = name.stripped
            let minChars = floor(Double(name.count) * 0.8)
            if name.utf8.map({ c in (0x21 ... 0x7E).contains(c) ? 1 : 0 }).reduce(0, { $0 + $1 }) >= minChars {
                return name
            }
        }
        return "Unknown"
    }

    static func uuid(id: CGDirectDisplayID) -> String {
        if let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() {
            return CFUUIDCreateString(kCFAllocatorDefault, uuid) as String
        }
        if let edid = Display.edid(id: id) {
            return edid
        }
        return String(describing: id)
    }

    static func edid(id: CGDirectDisplayID) -> String? {
        return DDC.getEdidData(displayID: id)?.map { $0 }.str(hex: true)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case edidName
        case serial
        case adaptive
        case extendedBrightnessRange
        case lockedBrightness
        case lockedContrast
        case minContrast
        case minBrightness
        case maxContrast
        case maxBrightness
        case contrast
        case brightness
        case volume
        case audioMuted
        case active
        case responsive
        case input
        case hotkeyInput
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(active, forKey: .active)
        try container.encode(adaptive, forKey: .adaptive)
        try container.encode(audioMuted, forKey: .audioMuted)
        try container.encode(brightness.uint8Value, forKey: .brightness)
        try container.encode(contrast.uint8Value, forKey: .contrast)
        try container.encode(edidName, forKey: .edidName)
        try container.encode(extendedBrightnessRange, forKey: .extendedBrightnessRange)
        try container.encode(id, forKey: .id)
        try container.encode(lockedBrightness, forKey: .lockedBrightness)
        try container.encode(lockedContrast, forKey: .lockedContrast)
        try container.encode(maxBrightness.uint8Value, forKey: .maxBrightness)
        try container.encode(maxContrast.uint8Value, forKey: .maxContrast)
        try container.encode(minBrightness.uint8Value, forKey: .minBrightness)
        try container.encode(minContrast.uint8Value, forKey: .minContrast)
        try container.encode(name, forKey: .name)
        try container.encode(responsive, forKey: .responsive)
        try container.encode(serial, forKey: .serial)
        try container.encode(volume.uint8Value, forKey: .volume)
        try container.encode(input.uint8Value, forKey: .input)
        try container.encode(hotkeyInput.uint8Value, forKey: .hotkeyInput)
    }

    func addSentryData() {
        SentrySDK.configureScope { [weak self] scope in
            guard let self = self, let dict = self.dictionary else { return }
            scope.setExtra(value: dict, key: "display-\(self.serial)")
        }
    }

    func isUltraFine() -> Bool {
        return name.contains(ULTRAFINE_NAME) || edidName.contains(ULTRAFINE_NAME)
    }

    func isThunderbolt() -> Bool {
        return name.contains(THUNDERBOLT_NAME) || edidName.contains(THUNDERBOLT_NAME)
    }

    func isLEDCinema() -> Bool {
        return name.contains(LED_CINEMA_NAME) || edidName.contains(LED_CINEMA_NAME)
    }

    func isColorLCD() -> Bool {
        return name.contains(COLOR_LCD_NAME) || edidName.contains(COLOR_LCD_NAME)
    }

    func isAppleDisplay() -> Bool {
        return Defaults[.useCoreDisplay] && (isUltraFine() || isThunderbolt() || isLEDCinema())
    }

    func isAppleVendorID() -> Bool {
        return CGDisplayVendorNumber(id) == APPLE_DISPLAY_VENDOR_ID
    }

    init(
        id: CGDirectDisplayID,
        brightness: UInt8 = 50,
        contrast: UInt8 = 50,
        serial: String? = nil,
        name: String? = nil,
        active: Bool = false,
        minBrightness: UInt8 = DEFAULT_MIN_BRIGHTNESS,
        maxBrightness: UInt8 = DEFAULT_MAX_BRIGHTNESS,
        minContrast: UInt8 = DEFAULT_MIN_CONTRAST,
        maxContrast: UInt8 = DEFAULT_MAX_CONTRAST,
        adaptive: Bool = true,
        extendedBrightnessRange: Bool = false,
        lockedBrightness: Bool = false,
        lockedContrast: Bool = false,
        volume: UInt8 = 10,
        audioMuted: Bool = false,
        input: UInt8 = InputSource.unknown.rawValue,
        hotkeyInput: UInt8 = InputSource.unknown.rawValue
    ) {
        self.id = id
        self.active = active
        activeAndResponsive = active || id != GENERIC_DISPLAY_ID
        self.adaptive = adaptive
        self.extendedBrightnessRange = extendedBrightnessRange
        self.lockedBrightness = lockedBrightness
        self.lockedContrast = lockedContrast
        self.audioMuted = audioMuted

        self.brightness = NSNumber(value: brightness)
        self.contrast = NSNumber(value: contrast)
        self.volume = NSNumber(value: volume)
        self.minBrightness = NSNumber(value: minBrightness)
        self.maxBrightness = NSNumber(value: maxBrightness)
        self.minContrast = NSNumber(value: minContrast)
        self.maxContrast = NSNumber(value: maxContrast)
        self.input = NSNumber(value: input)
        self.hotkeyInput = NSNumber(value: hotkeyInput)

        edidName = Display.printableName(id: id)
        if let n = name, !n.isEmpty {
            self.name = n
        } else {
            self.name = edidName
        }
        self.serial = (serial ?? Display.uuid(id: id))
        super.init()

        if id != GENERIC_DISPLAY_ID, Defaults[.refreshValues] {
            serialQueue.async {
                self.refreshBrightness()
                self.refreshContrast()
                self.refreshVolume()
                self.refreshInput()
            }
        }
    }

    func resetName() {
        name = Display.printableName(id: id)
    }

    func readapt<T: Equatable>(newValue: T?, oldValue: T?) {
        if let readaptListener = onReadapt {
            readaptListener()
        }
        if let newVal = newValue, let oldVal = oldValue {
            if adaptive, newVal != oldVal {
                switch brightnessAdapter.mode {
                case .location:
                    adapt(moment: brightnessAdapter.moment)
                case .sync:
                    if let brightness = brightnessAdapter.getBuiltinDisplayBrightness() {
                        log.verbose("Builtin Display Brightness: \(brightness)")
                        let clipMin = brightnessAdapter.brightnessClipMin
                        let clipMax = brightnessAdapter.brightnessClipMax
                        adapt(percent: Double(brightness), brightnessClipMin: clipMin, brightnessClipMax: clipMax)
                    } else {
                        log.verbose("Can't get Builtin Display Brightness")
                    }
                default:
                    return
                }
            }
        }
    }

    func smoothTransition(from currentValue: UInt8, to value: UInt8, adjust: @escaping ((UInt8) -> Void)) {
        var steps = abs(value.distance(to: currentValue))

        var step: Int
        let minVal: UInt8
        let maxVal: UInt8
        if value < currentValue {
            step = cap(-smoothStep, minVal: -steps, maxVal: -1)
            minVal = value
            maxVal = currentValue
        } else {
            step = cap(smoothStep, minVal: 1, maxVal: steps)
            minVal = currentValue
            maxVal = value
        }
        concurrentQueue.asyncAfter(deadline: DispatchTime.now(), flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let startTime = DispatchTime.now()
            var elapsedTime: UInt64
            var elapsedSeconds: String

            adjust(UInt8(Int(currentValue) + step))

            elapsedTime = DispatchTime.now().rawValue - startTime.rawValue
            elapsedSeconds = String(format: "%.3f", Double(elapsedTime) / 1_000_000_000.0)
            log.debug("It took \(elapsedTime)ns (\(elapsedSeconds)s) to change brightness by \(step)")

            steps = steps - abs(step)
            if steps <= 0 {
                adjust(value)
                return
            }

            self.smoothStep = cap(Int(elapsedTime / MAX_SMOOTH_STEP_TIME_NS), minVal: 1, maxVal: 100)
            if value < currentValue {
                step = cap(-self.smoothStep, minVal: -steps, maxVal: -1)
            } else {
                step = cap(self.smoothStep, minVal: 1, maxVal: steps)
            }

            for newValue in stride(from: Int(currentValue), through: Int(value), by: step) {
                adjust(cap(UInt8(newValue), minVal: minVal, maxVal: maxVal))
            }
            adjust(value)

            elapsedTime = DispatchTime.now().rawValue - startTime.rawValue
            elapsedSeconds = String(format: "%.3f", Double(elapsedTime) / 1_000_000_000.0)
            log.debug("It took \(elapsedTime)ns (\(elapsedSeconds)s) to change brightness from \(currentValue) to \(value) by \(step)")
        }
    }

    func setSentryExtra(value: Any, key: String) {
        SentrySDK.configureScope { [weak self] scope in
            guard let self = self else { return }
            scope.setExtra(value: value, key: "display-\(self.id)-\(key)")
        }
    }

    func addObservers() {
        datastoreObservers = [
            Defaults.observe(.brightnessClipMin) { [weak self] change in
                self?.readapt(newValue: change.newValue, oldValue: change.oldValue)
            },
            Defaults.observe(.brightnessClipMax) { [weak self] change in
                self?.readapt(newValue: change.newValue, oldValue: change.oldValue)
            },
            Defaults.observe(.brightnessLimitMin) { [weak self] change in
                self?.readapt(newValue: change.newValue, oldValue: change.oldValue)
            },
            Defaults.observe(.brightnessLimitMax) { [weak self] change in
                self?.readapt(newValue: change.newValue, oldValue: change.oldValue)
            },
            Defaults.observe(.contrastLimitMin) { [weak self] change in
                self?.readapt(newValue: change.newValue, oldValue: change.oldValue)
            },
            Defaults.observe(.contrastLimitMax) { [weak self] change in
                self?.readapt(newValue: change.newValue, oldValue: change.oldValue)
            },
        ]

        semaphore.wait()
        defer {
            semaphore.signal()
        }

        numberObservers["minBrightness"]!["self.minBrightness"] = { [weak self] newValue, oldValue in
            guard let self = self else { return }
            self.setSentryExtra(value: newValue, key: "minBrightness")
            self.readapt(newValue: newValue, oldValue: oldValue)
        }
        numberObservers["maxBrightness"]!["self.maxBrightness"] = { [weak self] newValue, oldValue in
            guard let self = self else { return }
            self.setSentryExtra(value: newValue, key: "maxBrightness")
            self.readapt(newValue: newValue, oldValue: oldValue)
        }
        numberObservers["minContrast"]!["self.minContrast"] = { [weak self] newValue, oldValue in
            guard let self = self else { return }
            self.setSentryExtra(value: newValue, key: "minContrast")
            self.readapt(newValue: newValue, oldValue: oldValue)
        }
        numberObservers["maxContrast"]!["self.maxContrast"] = { [weak self] newValue, oldValue in
            guard let self = self else { return }
            self.setSentryExtra(value: newValue, key: "maxContrast")
            self.readapt(newValue: newValue, oldValue: oldValue)
        }
        numberObservers["input"]!["self.input"] = { [weak self] newInput, _ in
            guard let self = self, let input = InputSource(rawValue: newInput.uint8Value), input != .unknown else { return }
            if !DDC.setInput(for: self.id, input: input) {
                log.warning("Error writing input using DDC", context: ["name": self.name, "id": self.id, "serial": self.serial])
            }
        }
        numberObservers["volume"]!["self.volume"] = { [weak self] newVolume, _ in
            guard let self = self else { return }
            if !DDC.setAudioSpeakerVolume(for: self.id, audioSpeakerVolume: newVolume.uint8Value) {
                log.warning("Error writing volume using DDC", context: ["name": self.name, "id": self.id, "serial": self.serial])
            }
        }
        boolObservers["audioMuted"]!["self.audioMuted"] = { [weak self] newAudioMuted, _ in
            guard let self = self else { return }
            if !DDC.setAudioMuted(for: self.id, audioMuted: newAudioMuted) {
                log.warning("Error writing muted audio using DDC", context: ["name": self.name, "id": self.id, "serial": self.serial])
            }
        }
        numberObservers["brightness"]!["self.brightness"] = { [weak self] newBrightness, oldValue in
            guard let self = self else { return }
            let appleDisplay = self.isAppleDisplay()
            let id = self.id
            if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
                var brightness: UInt8
                if brightnessAdapter.mode == AdaptiveMode.manual {
                    brightness = cap(newBrightness.uint8Value, minVal: 0, maxVal: 100)
                } else {
                    brightness = cap(newBrightness.uint8Value, minVal: self.minBrightness.uint8Value, maxVal: self.maxBrightness.uint8Value)
                }

                var oldBrightness: UInt8 = oldValue.uint8Value
                let maxBrightness: Double = 100.0
                if self.extendedBrightnessRange {
                    oldBrightness = UInt8(mapNumber(Double(oldBrightness), fromLow: 0, fromHigh: 100, toLow: 0, toHigh: 255).rounded())
                    brightness = UInt8(mapNumber(Double(brightness), fromLow: 0, fromHigh: 100, toLow: 0, toHigh: 255).rounded())
                }

                self.setSentryExtra(value: brightness, key: "brightness")
                if Defaults[.smoothTransition] || appleDisplay {
                    var faults = 0
                    self.smoothTransition(from: oldBrightness, to: brightness) { [weak self] newValue in
                        guard let self = self else { return }
                        if faults > 5 {
                            return
                        }

                        if !appleDisplay {
                            if !DDC.setBrightness(for: id, brightness: newValue) {
                                faults += 1
                                log.warning(
                                    "Error writing brightness using DDC",
                                    context: ["name": self.name, "id": self.id, "serial": self.serial, "faults": faults]
                                )
                            }
                        } else {
                            log.debug(
                                "Writing brightness using CoreDisplay",
                                context: ["name": self.name, "id": self.id, "serial": self.serial]
                            )
                            CoreDisplay_Display_SetUserBrightness(id, Double(newValue) / maxBrightness)
                        }
                    }
                } else {
                    if !appleDisplay {
                        if !DDC.setBrightness(for: id, brightness: brightness) {
                            log.warning(
                                "Error writing brightness using DDC",
                                context: ["name": self.name, "id": self.id, "serial": self.serial]
                            )
                        }
                    } else {
                        log.debug(
                            "Writing brightness using CoreDisplay",
                            context: ["name": self.name, "id": self.id, "serial": self.serial]
                        )
                        CoreDisplay_Display_SetUserBrightness(id, Double(brightness) / maxBrightness)
                    }
                }

                log.verbose("Set BRIGHTNESS to \(brightness)", context: ["name": self.name, "id": self.id, "serial": self.serial])
            }
        }
        numberObservers["contrast"]!["self.contrast"] = { [weak self] newContrast, oldValue in
            guard let self = self else { return }
            let id = self.id
            if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
                var contrast: UInt8
                if brightnessAdapter.mode == AdaptiveMode.manual {
                    contrast = cap(newContrast.uint8Value, minVal: 0, maxVal: 100)
                } else {
                    contrast = cap(newContrast.uint8Value, minVal: self.minContrast.uint8Value, maxVal: self.maxContrast.uint8Value)
                }

                self.setSentryExtra(value: contrast, key: "contrast")

                if Defaults[.smoothTransition] {
                    var faults = 0
                    self.smoothTransition(from: oldValue.uint8Value, to: contrast) { [weak self] newValue in
                        guard let self = self else { return }
                        if faults > 5 {
                            return
                        }

                        if !DDC.setContrast(for: id, contrast: newValue) {
                            faults += 1
                            log.warning(
                                "Error writing contrast using DDC",
                                context: ["name": self.name, "id": self.id, "serial": self.serial, "faults": faults]
                            )
                        }
                    }
                } else {
                    if !DDC.setContrast(for: id, contrast: contrast) {
                        log.warning("Error writing contrast using DDC", context: ["name": self.name, "id": self.id, "serial": self.serial])
                    }
                }
                log.verbose("Set CONTRAST to \(contrast)", context: ["name": self.name, "id": self.id, "serial": self.serial])
            }
        }
    }

    func readAudioMuted() -> Bool? {
        return DDC.isAudioMuted(for: id)
    }

    func readVolume() -> UInt8? {
        if let c = DDC.getAudioSpeakerVolume(for: id) {
            return UInt8(c)
        }
        return nil
    }

    func readContrast() -> UInt8? {
        if let c = DDC.getContrast(for: id) {
            return UInt8(c)
        }
        return nil
    }

    func readInput() -> UInt8? {
        if let c = DDC.getInput(for: id) {
            return UInt8(c)
        }
        return nil
    }

    func readBrightness() -> UInt8? {
        if !isAppleDisplay() {
            if let b = DDC.getBrightness(for: id) {
                return UInt8(b)
            }
        } else {
            log.debug("Reading brightness using CoreDisplay")
            return UInt8(round(CoreDisplay_Display_GetUserBrightness(id) * 100.0))
        }

        return nil
    }

    func refreshBrightness() {
        guard let newBrightness = readBrightness() else {
            log.warning("Can't read brightness for \(name)")
            return
        }
        if newBrightness != brightness.uint8Value {
            log.info("Refreshing brightness: \(brightness.uint8Value) <> \(newBrightness)")

            withoutSmoothTransition {
                brightness = NSNumber(value: newBrightness)
            }
        }
    }

    func refreshContrast() {
        guard let newContrast = readContrast() else {
            log.warning("Can't read contrast for \(name)")
            return
        }
        if newContrast != contrast.uint8Value {
            log.info("Refreshing contrast: \(contrast.uint8Value) <> \(newContrast)")

            withoutSmoothTransition {
                contrast = NSNumber(value: newContrast)
            }
        }
    }

    func refreshInput() {
        guard let newInput = readInput() else {
            log.warning("Can't read input for \(name)")
            return
        }
        if newInput != input.uint8Value {
            log.info("Refreshing input: \(input.uint8Value) <> \(newInput)")

            withoutSmoothTransition {
                input = NSNumber(value: newInput)
            }
        }
    }

    func refreshVolume() {
        guard let newVolume = readVolume(), let newAudioMuted = readAudioMuted() else {
            log.warning("Can't read volume for \(name)")
            return
        }

        if newAudioMuted != audioMuted {
            log.info("Refreshing mute value: \(audioMuted) <> \(newAudioMuted)")
            audioMuted = newAudioMuted
        }
        if newVolume != volume.uint8Value {
            log.info("Refreshing volume: \(volume.uint8Value) <> \(newVolume)")

            withoutSmoothTransition {
                volume = NSNumber(value: newVolume)
            }
        }
    }

    func withoutSmoothTransition(_ block: () -> Void) {
        if !Defaults[.smoothTransition] {
            block()
            return
        }

        Defaults[.smoothTransition] = false
        block()
        Defaults[.smoothTransition] = true
    }

    func setObserver<T>(prop: String, key: String, action: @escaping ((T, T) -> Void)) {
        semaphore.wait()
        defer {
            semaphore.signal()
        }

        switch T.self {
        case is NSNumber.Type:
            if numberObservers[prop] != nil {
                numberObservers[prop]![key] = (action as! ((NSNumber, NSNumber) -> Void))
            }
        case is Bool.Type:
            if boolObservers[prop] != nil {
                boolObservers[prop]![key] = (action as! ((Bool, Bool) -> Void))
            }
        default:
            log.warning("Unknown observer type: \(T.self)")
        }
    }

    func resetObserver<T>(prop: String, key: String, type: T.Type) {
        semaphore.wait()
        defer {
            semaphore.signal()
        }

        switch type {
        case is NSNumber.Type:
            if numberObservers[prop] != nil {
                numberObservers[prop]!.removeValue(forKey: key)
            }
        case is Bool.Type:
            if boolObservers[prop] != nil {
                boolObservers[prop]!.removeValue(forKey: key)
            }
        default:
            log.warning("Unknown observer type: \(T.self)")
        }
    }

    func removeObservers() {
        semaphore.wait()
        defer {
            semaphore.signal()
        }

        boolObservers.removeAll(keepingCapacity: true)
        numberObservers.removeAll(keepingCapacity: true)
        datastoreObservers.removeAll(keepingCapacity: true)
    }

    func getMinMaxFactor(
        type: ValueType,
        offset: Int? = nil,
        factor: Double? = nil,
        minVal: Double? = nil,
        maxVal: Double? = nil
    ) -> (Double, Double, Double) {
        let minValue: Double
        let maxValue: Double
        let offsetValue: Int
        if type == .brightness {
            maxValue = maxVal ?? maxBrightness.doubleValue
            minValue = minVal ?? minBrightness.doubleValue
            offsetValue = offset ?? Defaults[.brightnessOffset]
        } else {
            maxValue = maxVal ?? maxContrast.doubleValue
            minValue = minVal ?? minContrast.doubleValue

            offsetValue = offset ?? Defaults[.contrastOffset]
        }

        guard let factor = factor else {
            var factor = 1.0
            if offsetValue > 0 {
                factor = 1.0 - (Double(offsetValue) / 100.0)
            } else if offsetValue < 0 {
                factor = 1.0 - (Double(offsetValue) / 10.0)
            }
            return (minValue, maxValue, factor)
        }
        return (minValue, maxValue, factor)
    }

    func computeValue(
        from percent: Double,
        type: ValueType,
        offset: Int? = nil,
        factor: Double? = nil,
        appOffset: Int = 0,
        minVal: Double? = nil,
        maxVal: Double? = nil,
        brightnessClipMin: Double? = nil,
        brightnessClipMax: Double? = nil
    ) -> NSNumber {
        let (minValue, maxValue, factor) = getMinMaxFactor(type: type, offset: offset, factor: factor, minVal: minVal, maxVal: maxVal)

        var percent = percent
        if let clipMin = brightnessClipMin, let clipMax = brightnessClipMax {
            percent = mapNumber(percent, fromLow: clipMin / 100.0, fromHigh: clipMax / 100.0, toLow: 0.0, toHigh: 1.0)
        }

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
            value = cap(value + Double(appOffset), minVal: minValue, maxVal: maxValue)
        }
        return NSNumber(value: value.rounded())
    }

    func computeSIMDValue(
        from percent: [Double],
        type: ValueType,
        offset: Int? = nil,
        factor: Double? = nil,
        appOffset: Int = 0,
        minVal: Double? = nil,
        maxVal: Double? = nil,
        brightnessClipMin: Double? = nil,
        brightnessClipMax: Double? = nil
    ) -> [NSNumber] {
        let (minValue, maxValue, factor) = getMinMaxFactor(type: type, offset: offset, factor: factor, minVal: minVal, maxVal: maxVal)

        var percent = percent
        if let clipMin = brightnessClipMin, let clipMax = brightnessClipMax {
            percent = mapNumberSIMD(percent, fromLow: clipMin / 100.0, fromHigh: clipMax / 100.0, toLow: 0.0, toHigh: 1.0)
        }

        var value = (percent * (maxValue - minValue) + minValue)
        value /= 100.0
        value = pow(value, factor)

        value = (value * 100.0 + Double(appOffset))
        return value.map {
            b in NSNumber(value: cap(b, minVal: minValue, maxVal: maxValue))
        }
    }

    func getBrightnessContrast(
        moment: Moment?,
        hour: Int? = nil,
        minute: Int = 0,
        factor: Double? = nil,
        minBrightness: UInt8? = nil,
        maxBrightness: UInt8? = nil,
        minContrast: UInt8? = nil,
        maxContrast: UInt8? = nil,
        daylightExtension: Int? = nil,
        noonDuration: Int? = nil,
        appBrightnessOffset: Int = 0,
        appContrastOffset: Int = 0
    ) -> (NSNumber, NSNumber) {
        guard let moment = moment else { return (NSNumber(value: minBrightness ?? 0), NSNumber(value: minContrast ?? 0)) }
        var now = DateInRegion().convertTo(region: Region.local)
        if let hour = hour {
            now = (
                now.dateBySet(hour: hour, min: minute, secs: 0) ??
                    DateInRegion(
                        year: now.year,
                        month: now.month,
                        day: now.day,
                        hour: hour,
                        minute: minute,
                        second: 0,
                        nanosecond: 0,
                        region: now.region
                    )
            )
        }
        let seconds = 60.0
        let minBrightness = minBrightness ?? self.minBrightness.uint8Value
        let maxBrightness = maxBrightness ?? self.maxBrightness.uint8Value
        let minContrast = minContrast ?? self.minContrast.uint8Value
        let maxContrast = maxContrast ?? self.maxContrast.uint8Value
        var newBrightness = NSNumber(value: minBrightness)
        var newContrast = NSNumber(value: minContrast)
        let daylightExtension = daylightExtension ?? Defaults[.daylightExtensionMinutes]
        let noonDuration = noonDuration ?? Defaults[.noonDurationMinutes]

        let daylightStart = moment.sunrise - daylightExtension.minutes
        let daylightEnd = moment.sunset + daylightExtension.minutes

        let noonStart = moment.solarNoon - (noonDuration / 2).minutes
        let noonEnd = moment.solarNoon + (noonDuration / 2).minutes

        switch now {
        case daylightStart ... noonStart:
            let firstHalfDayMinutes = ((noonStart - daylightStart) / seconds)
            let minutesSinceSunrise = ((now - daylightStart) / seconds)
            let percent = (minutesSinceSunrise / firstHalfDayMinutes)
            newBrightness = computeValue(
                from: percent, type: .brightness,
                factor: factor ?? Defaults[.curveFactor], appOffset: appBrightnessOffset,
                minVal: Double(minBrightness), maxVal: Double(maxBrightness)
            )
            newContrast = computeValue(
                from: percent, type: .contrast,
                factor: factor ?? Defaults[.curveFactor], appOffset: appContrastOffset,
                minVal: Double(minContrast), maxVal: Double(maxContrast)
            )
        case noonEnd ... daylightEnd:
            let secondHalfDayMinutes = ((daylightEnd - noonEnd) / seconds)
            let minutesSinceNoon = ((now - noonEnd) / seconds)
            let percent = ((secondHalfDayMinutes - minutesSinceNoon) / secondHalfDayMinutes)
            newBrightness = computeValue(
                from: percent, type: .brightness,
                factor: factor ?? Defaults[.curveFactor], appOffset: appBrightnessOffset,
                minVal: Double(minBrightness), maxVal: Double(maxBrightness)
            )
            newContrast = computeValue(
                from: percent, type: .contrast,
                factor: factor ?? Defaults[.curveFactor], appOffset: appContrastOffset,
                minVal: Double(minContrast), maxVal: Double(maxContrast)
            )
        case noonStart ... noonEnd:
            newBrightness = NSNumber(value: maxBrightness)
            newContrast = NSNumber(value: maxContrast)
        default:
            newBrightness = NSNumber(value: minBrightness)
            newContrast = NSNumber(value: minContrast)
        }

        if appBrightnessOffset > 0 {
            newBrightness = NSNumber(value: min(newBrightness.doubleValue + Double(appBrightnessOffset), Double(MAX_BRIGHTNESS)).rounded())
        }
        if appContrastOffset > 0 {
            newContrast = NSNumber(value: min(newContrast.doubleValue + Double(appContrastOffset), Double(MAX_CONTRAST)).rounded())
        }
        return (newBrightness, newContrast)
    }

    func getBrightnessContrastBatch(
        moment: Moment?,
        minutesBetween: Int = 0,
        factor: Double? = nil,
        minBrightness: UInt8? = nil,
        maxBrightness: UInt8? = nil,
        minContrast: UInt8? = nil,
        maxContrast: UInt8? = nil,
        daylightExtension: Int? = nil,
        noonDuration: Int? = nil,
        appBrightnessOffset: Int = 0,
        appContrastOffset: Int = 0
    ) -> [(NSNumber, NSNumber)] {
        guard let moment = moment else { return [(NSNumber(value: minBrightness ?? 0), NSNumber(value: minContrast ?? 0))] }
        let step = 60 / minutesBetween
        var times = [Double]()
        times.reserveCapacity(24 * minutesBetween)

        let now = DateInRegion().convertTo(region: Region.local)
        for hour in 0 ..< 24 {
            times.append(contentsOf: stride(from: 0, through: 59, by: step).map { minute in
                let newNow = (
                    now.dateBySet(hour: hour, min: minute, secs: 0) ??
                        DateInRegion(
                            year: now.year,
                            month: now.month,
                            day: now.day,
                            hour: hour,
                            minute: minute,
                            second: 0,
                            nanosecond: 0,
                            region: now.region
                        )
                )

                return newNow.timeIntervalSince1970
            })
        }

        let seconds = 60.0

        let minBrightness = minBrightness ?? self.minBrightness.uint8Value
        let maxBrightness = maxBrightness ?? self.maxBrightness.uint8Value
        let minContrast = minContrast ?? self.minContrast.uint8Value
        let maxContrast = maxContrast ?? self.maxContrast.uint8Value
        let daylightExtension = daylightExtension ?? Defaults[.daylightExtensionMinutes]
        let noonDuration = noonDuration ?? Defaults[.noonDurationMinutes]

        let daylightStart = moment.sunrise - daylightExtension.minutes
        let daylightEnd = moment.sunset + daylightExtension.minutes
        let daylightStartSeconds = daylightStart.timeIntervalSince1970
        let daylightEndSeconds = daylightEnd.timeIntervalSince1970

        let noonStart = moment.solarNoon - (noonDuration / 2).minutes
        let noonEnd = moment.solarNoon + (noonDuration / 2).minutes
        let noonStartSeconds = noonStart.timeIntervalSince1970
        let noonEndSeconds = noonEnd.timeIntervalSince1970

        let firstHalfDayMinutes = ((noonStartSeconds - daylightStartSeconds) / seconds)
        let secondHalfDayMinutes = ((daylightEndSeconds - noonEndSeconds) / seconds)

        let maxNSBrightness = NSNumber(value: maxBrightness)
        let maxNSContrast = NSNumber(value: maxContrast)
        let minNSBrightness = NSNumber(value: min(minBrightness + UInt8(appBrightnessOffset), MAX_BRIGHTNESS))
        let minNSContrast = NSNumber(value: min(minContrast + UInt8(appContrastOffset), MAX_CONTRAST))

        let maxBrightnessDouble = Double(maxBrightness)
        let maxContrastDouble = Double(maxContrast)
        let minBrightnessDouble = Double(minBrightness)
        let minContrastDouble = Double(minContrast)

        var brightnessContrast = [(NSNumber, NSNumber)](repeating: (minNSBrightness, minNSContrast), count: 25 * minutesBetween)
        let noonStartIndex = times.firstIndex { s in s >= noonStartSeconds }
        let noonEndIndex = times.lastIndex { s in s <= noonEndSeconds }
        if let start = noonStartIndex, let end = noonEndIndex, start < end {
            let noonValues = [(NSNumber, NSNumber)](repeating: (maxNSBrightness, maxNSContrast), count: (end - start) + 1)
            brightnessContrast.replaceSubrange(
                start ... end, with: noonValues
            )
        }

        let daylightStartIndex = times.firstIndex { s in s >= daylightStartSeconds } ?? 0
        let daylightEndIndex = times.lastIndex { s in s <= daylightEndSeconds } ?? (brightnessContrast.count - 1)

        let firstHalf = (daylightStartIndex ..< (noonStartIndex ?? daylightStartIndex))
        var values = Array(times[firstHalf])
        let minutesSinceSunrise = ((values - Double(daylightStartSeconds)) / seconds)
        var percent = (minutesSinceSunrise / firstHalfDayMinutes)

        brightnessContrast.replaceSubrange(
            firstHalf,
            with: zip(
                computeSIMDValue(
                    from: percent, type: .brightness, factor: factor ?? Defaults[.curveFactor],
                    appOffset: appBrightnessOffset, minVal: minBrightnessDouble, maxVal: maxBrightnessDouble
                ),
                computeSIMDValue(
                    from: percent, type: .contrast, factor: factor ?? Defaults[.curveFactor],
                    appOffset: appContrastOffset, minVal: minContrastDouble, maxVal: maxContrastDouble
                )
            ).map { ($0, $1) }
        )

        let secondHalf = ((noonEndIndex ?? daylightEndIndex) - 1) ..< daylightEndIndex + 1
        values = Array(times[secondHalf])
        let minutesSinceNoon = ((values - noonEndSeconds) / seconds)
        percent = (abs(minutesSinceNoon - secondHalfDayMinutes) / secondHalfDayMinutes)

        brightnessContrast.replaceSubrange(
            secondHalf,
            with: zip(
                computeSIMDValue(
                    from: percent, type: .brightness, factor: factor ?? Defaults[.curveFactor],
                    appOffset: appBrightnessOffset, minVal: minBrightnessDouble, maxVal: maxBrightnessDouble
                ),
                computeSIMDValue(
                    from: percent, type: .contrast, factor: factor ?? Defaults[.curveFactor],
                    appOffset: appContrastOffset, minVal: minContrastDouble, maxVal: maxContrastDouble
                )
            ).map { ($0, $1) }
        )

        return brightnessContrast
    }

    func adapt(
        moment: Moment? = nil,
        app: AppException? = nil,
        percent: Double? = nil,
        brightnessClipMin: Double? = nil,
        brightnessClipMax: Double? = nil
    ) {
        if !adaptive {
            return
        }

        var newBrightness: NSNumber = 0
        var newContrast: NSNumber = 0
        if let moment = moment {
            (newBrightness, newContrast) = getBrightnessContrast(
                moment: moment,
                appBrightnessOffset: Int(app?.brightness ?? 0),
                appContrastOffset: Int(app?.contrast ?? 0)
            )
        } else if let percent = percent {
            let percent = percent / 100.0
            newBrightness = computeValue(
                from: percent,
                type: .brightness,
                appOffset: Int(app?.brightness ?? 0),
                brightnessClipMin: brightnessClipMin,
                brightnessClipMax: brightnessClipMax
            )
            newContrast = computeValue(
                from: percent,
                type: .contrast,
                appOffset: Int(app?.contrast ?? 0),
                brightnessClipMin: brightnessClipMin,
                brightnessClipMax: brightnessClipMax
            )
        }

        var changed = false
        if !lockedBrightness, brightness != newBrightness {
            brightness = newBrightness
            changed = true
        }

        if !lockedContrast, contrast != newContrast {
            contrast = newContrast
            changed = true
        }
        if changed {
            log.info("\n\(name):\n\tBrightness: \(newBrightness.uint8Value)\n\tContrast: \(newContrast.uint8Value)")
        }
    }
}
