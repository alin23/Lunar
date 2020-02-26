//
//  Display.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
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

let GENERIC_DISPLAY: Display = Display(id: GENERIC_DISPLAY_ID, serial: "GENERIC_SERIAL", name: "No Display", minBrightness: 0, maxBrightness: 100, minContrast: 0, maxContrast: 100)
let TEST_DISPLAY = { Display(id: TEST_DISPLAY_ID, serial: "TEST_SERIAL", name: "Test Display", active: true, minBrightness: 0, maxBrightness: 100, minContrast: 0, maxContrast: 100, adaptive: true) }

let MAX_SMOOTH_STEP_TIME_NS: UInt64 = 10 * 1_000_000 // 10ms

let ULTRAFINE_NAME = "LG UltraFine"
let THUNDERBOLT_NAME = "Thunderbolt"
let LED_CINEMA_NAME = "LED Cinema"

enum ValueType {
    case brightness
    case contrast
}

@objc class Display: NSObject {
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
        }
    }

    @objc dynamic var responsive: Bool = true {
        didSet {
            runBoolObservers(property: "responsive", newValue: responsive, oldValue: oldValue)
        }
    }

    @objc dynamic var activeAndResponsive: Bool = false {
        didSet {
            runBoolObservers(property: "activeAndResponsive", newValue: activeAndResponsive, oldValue: oldValue)
        }
    }

    var boolObservers: [String: [String: (Bool, Bool) -> Void]] = [
        "adaptive": [:],
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
    ]
    var datastoreObservers: [NSKeyValueObservation] = []
    var onReadapt: (() -> Void)?
    var smoothStep = 1

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
            lockedBrightness: (config["lockedBrightness"] as? Bool) ?? false,
            lockedContrast: (config["lockedContrast"] as? Bool) ?? false,
            volume: (config["contrast"] as? UInt8) ?? 10,
            audioMuted: (config["audioMuted"] as? Bool) ?? false
        )
    }

    func save() {
        DataStore.storeDisplay(display: self)
    }

    func runNumberObservers(property: String, newValue: NSNumber, oldValue: NSNumber) {
        guard let obs = numberObservers[property] else { return }

        for (_, observer) in obs {
            observer(newValue, oldValue)
        }
    }

    func runBoolObservers(property: String, newValue: Bool, oldValue: Bool) {
        guard let obs = boolObservers[property] else { return }

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
        return lunarDisplayNames[Int(CGDisplayUnitNumber(id)) % lunarDisplayNames.count]
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

    func dictionaryRepresentation() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "serial": serial,
            "adaptive": adaptive,
            "lockedBrightness": lockedBrightness,
            "lockedContrast": lockedContrast,
            "minContrast": minContrast.uint8Value,
            "minBrightness": minBrightness.uint8Value,
            "maxContrast": maxContrast.uint8Value,
            "maxBrightness": maxBrightness.uint8Value,
            "contrast": contrast.uint8Value,
            "brightness": brightness.uint8Value,
            "volume": volume.uint8Value,
            "audioMuted": audioMuted,
            "active": active,
            "responsive": responsive,
        ]
    }

    func addSentryData() {
        if let client = Client.shared {
            if client.extra == nil {
                brightnessAdapter.addSentryData()
                return
            }
            if var displayExtra = client.extra?["displays"] as? [String: Any] {
                displayExtra["\(serial)"] = dictionaryRepresentation()
                client.extra!["displays"] = displayExtra
            }
        }
    }

    func isUltraFine() -> Bool {
        return name.contains(ULTRAFINE_NAME)
    }

    func isThunderbolt() -> Bool {
        return name.contains(THUNDERBOLT_NAME)
    }

    func isLEDCinema() -> Bool {
        return name.contains(LED_CINEMA_NAME)
    }

    func isAppleDisplay() -> Bool {
        return isUltraFine() || isThunderbolt() || isLEDCinema()
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
        lockedBrightness: Bool = false,
        lockedContrast: Bool = false,
        volume: UInt8 = 10,
        audioMuted: Bool = false
    ) {
        self.id = id
        self.active = active
        activeAndResponsive = active || id == GENERIC_DISPLAY_ID
        self.adaptive = adaptive
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

        if let n = name, !n.isEmpty {
            self.name = n
        } else {
            self.name = Display.printableName(id: id)
        }
        self.serial = (serial ?? Display.uuid(id: id))
        super.init()

        if id != GENERIC_DISPLAY_ID {
            fgQueue.async {
                self.refreshBrightness()
                self.refreshContrast()
                self.refreshVolume()
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
                        adapt(percent: Double(brightness))
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
        fgQueue.asyncAfter(deadline: DispatchTime.now(), flags: .barrier) {
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

    func addObservers() {
        datastoreObservers = [
            datastore.defaults.observe(\.brightnessLimitMin, options: [.new, .old], changeHandler: { _, change in
                self.readapt(newValue: change.newValue, oldValue: change.oldValue)
            }),
            datastore.defaults.observe(\.brightnessLimitMax, options: [.new, .old], changeHandler: { _, change in
                self.readapt(newValue: change.newValue, oldValue: change.oldValue)
            }),
            datastore.defaults.observe(\.contrastLimitMin, options: [.new, .old], changeHandler: { _, change in
                self.readapt(newValue: change.newValue, oldValue: change.oldValue)
            }),
            datastore.defaults.observe(\.contrastLimitMax, options: [.new, .old], changeHandler: { _, change in
                self.readapt(newValue: change.newValue, oldValue: change.oldValue)
            }),
        ]
        numberObservers["minBrightness"]!["self.minBrightness"] = { newValue, oldValue in
            if var extraData = Client.shared?.extra?["\(self.id)"] as? [String: Any] {
                extraData["minBrightness"] = newValue
                Client.shared?.extra?["\(self.id)"] = extraData
            }
            self.readapt(newValue: newValue, oldValue: oldValue)
        }
        numberObservers["maxBrightness"]!["self.maxBrightness"] = { newValue, oldValue in
            if var extraData = Client.shared?.extra?["\(self.id)"] as? [String: Any] {
                extraData["maxBrightness"] = newValue
                Client.shared?.extra?["\(self.id)"] = extraData
            }
            self.readapt(newValue: newValue, oldValue: oldValue)
        }
        numberObservers["minContrast"]!["self.minContrast"] = { newValue, oldValue in
            if var extraData = Client.shared?.extra?["\(self.id)"] as? [String: Any] {
                extraData["minContrast"] = newValue
                Client.shared?.extra?["\(self.id)"] = extraData
            }
            self.readapt(newValue: newValue, oldValue: oldValue)
        }
        numberObservers["maxContrast"]!["self.maxContrast"] = { newValue, oldValue in
            if var extraData = Client.shared?.extra?["\(self.id)"] as? [String: Any] {
                extraData["maxContrast"] = newValue
                Client.shared?.extra?["\(self.id)"] = extraData
            }
            self.readapt(newValue: newValue, oldValue: oldValue)
        }
        numberObservers["volume"]!["self.volume"] = { newVolume, _ in
            if !DDC.setAudioSpeakerVolume(for: self.id, audioSpeakerVolume: newVolume.uint8Value) {
                log.warning("Error writing volume using DDC", context: ["name": self.name, "id": self.id, "serial": self.serial])
            }
        }
        boolObservers["audioMuted"]!["self.audioMuted"] = { newAudioMuted, _ in
            if !DDC.setAudioMuted(for: self.id, audioMuted: newAudioMuted) {
                log.warning("Error writing muted audio using DDC", context: ["name": self.name, "id": self.id, "serial": self.serial])
            }
        }
        boolObservers["active"]!["self.active"] = { newActive, _ in
            runInMainThread {
                self.activeAndResponsive = newActive && self.responsive
            }
        }
        boolObservers["responsive"]!["self.responsive"] = { newResponsive, _ in
            runInMainThread {
                self.activeAndResponsive = newResponsive && self.active
            }
        }
        numberObservers["brightness"]!["self.brightness"] = { newBrightness, oldValue in
            let appleDisplay = self.isAppleDisplay()
            let id = self.id
            if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
                var brightness: UInt8
                if brightnessAdapter.mode == AdaptiveMode.manual {
                    brightness = cap(newBrightness.uint8Value, minVal: 0, maxVal: 100)
                } else {
                    brightness = cap(newBrightness.uint8Value, minVal: self.minBrightness.uint8Value, maxVal: self.maxBrightness.uint8Value)
                }

                if var extraData = Client.shared?.extra?["\(id)"] as? [String: Any] {
                    extraData["brightness"] = brightness
                    Client.shared?.extra?["\(id)"] = extraData
                }
                if datastore.defaults.smoothTransition || appleDisplay {
                    var faults = 0
                    self.smoothTransition(from: oldValue.uint8Value, to: brightness) { newValue in
                        if faults > 5 {
                            return
                        }

                        if !appleDisplay {
                            if !DDC.setBrightness(for: id, brightness: newValue) {
                                faults += 1
                                log.warning("Error writing brightness using DDC", context: ["name": self.name, "id": self.id, "serial": self.serial, "faults": faults])
                            }
                        } else {
                            log.debug("Writing brightness using CoreDisplay", context: ["name": self.name, "id": self.id, "serial": self.serial])
                            CoreDisplay_Display_SetUserBrightness(id, Double(newValue) / 100.0)
                        }
                    }
                } else {
                    if !appleDisplay {
                        if !DDC.setBrightness(for: id, brightness: brightness) {
                            log.warning("Error writing brightness using DDC", context: ["name": self.name, "id": self.id, "serial": self.serial])
                        }
                    } else {
                        log.debug("Writing brightness using CoreDisplay", context: ["name": self.name, "id": self.id, "serial": self.serial])
                        CoreDisplay_Display_SetUserBrightness(id, Double(brightness) / 100.0)
                    }
                }

                log.debug("\(self.name): Set brightness to \(brightness) for \(self.serial):\(id)")
            }
        }
        numberObservers["contrast"]!["self.contrast"] = { newContrast, oldValue in
            let id = self.id
            if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
                var contrast: UInt8
                if brightnessAdapter.mode == AdaptiveMode.manual {
                    contrast = cap(newContrast.uint8Value, minVal: 0, maxVal: 100)
                } else {
                    contrast = cap(newContrast.uint8Value, minVal: self.minContrast.uint8Value, maxVal: self.maxContrast.uint8Value)
                }
                if var extraData = Client.shared?.extra?["\(id)"] as? [String: Any] {
                    extraData["contrast"] = contrast
                    Client.shared?.extra?["\(id)"] = extraData
                }
                if datastore.defaults.smoothTransition {
                    var faults = 0
                    self.smoothTransition(from: oldValue.uint8Value, to: contrast) { newValue in
                        if faults > 5 {
                            return
                        }

                        if !DDC.setContrast(for: id, contrast: newValue) {
                            faults += 1
                            log.warning("Error writing contrast using DDC", context: ["name": self.name, "id": self.id, "serial": self.serial, "faults": faults])
                        }
                    }
                } else {
                    if !DDC.setContrast(for: id, contrast: contrast) {
                        log.warning("Error writing contrast using DDC", context: ["name": self.name, "id": self.id, "serial": self.serial])
                    }
                }

                log.debug("\(self.name): Set contrast to \(contrast)")
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
        if !datastore.defaults.refreshValues, !isAppleDisplay() {
            return
        }

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
        if !datastore.defaults.refreshValues {
            return
        }

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

    func refreshVolume() {
        if !datastore.defaults.refreshValues {
            return
        }

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
        if !datastore.defaults.smoothTransition {
            block()
            return
        }

        datastore.defaults.set(false, forKey: "smoothTransition")
        block()
        datastore.defaults.set(true, forKey: "smoothTransition")
    }

    func removeObservers() {
        boolObservers.removeAll(keepingCapacity: true)
        numberObservers.removeAll(keepingCapacity: true)
        datastoreObservers.removeAll(keepingCapacity: true)
    }

    func getMinMaxFactor(type: ValueType, offset: Int? = nil, factor: Double? = nil, minVal: Double? = nil, maxVal: Double? = nil) -> (Double, Double, Double) {
        let minValue: Double
        let maxValue: Double
        let offsetValue: Int
        if type == .brightness {
            maxValue = maxVal ?? maxBrightness.doubleValue
            minValue = minVal ?? minBrightness.doubleValue
            offsetValue = offset ?? datastore.defaults.brightnessOffset
        } else {
            maxValue = maxVal ?? maxContrast.doubleValue
            minValue = minVal ?? minContrast.doubleValue
            offsetValue = offset ?? datastore.defaults.contrastOffset
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

    func computeValue(from percent: Double, type: ValueType, offset: Int? = nil, factor: Double? = nil, appOffset: Int = 0, minVal: Double? = nil, maxVal: Double? = nil) -> NSNumber {
        let (minValue, maxValue, factor) = getMinMaxFactor(type: type, offset: offset, factor: factor, minVal: minVal, maxVal: maxVal)

        var value = pow((percent * (maxValue - minValue) + minValue) / 100.0, factor) * 100.0
        value = cap(value, minVal: minValue, maxVal: maxValue)

        if appOffset > 0 {
            value = cap(value + Double(appOffset), minVal: minValue, maxVal: maxValue)
        }
        return NSNumber(value: value.rounded())
    }

    func computeSIMDValue(from percent: [Double], type: ValueType, offset: Int? = nil, factor: Double? = nil, appOffset: Int = 0, minVal: Double? = nil, maxVal: Double? = nil) -> [NSNumber] {
        let (minValue, maxValue, factor) = getMinMaxFactor(type: type, offset: offset, factor: factor, minVal: minVal, maxVal: maxVal)

        var value = (percent * (maxValue - minValue) + minValue)
        value /= 100.0
        value = pow(value, factor)

        value = (value * 100.0 + Double(appOffset))
        return value.map {
            b in NSNumber(value: cap(b, minVal: minValue, maxVal: maxValue))
        }
    }

    func getBrightnessContrast(
        moment: Moment,
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
        var now = DateInRegion().convertTo(region: Region.local)
        if let hour = hour {
            now = (now.dateBySet(hour: hour, min: minute, secs: 0) ??
                DateInRegion(year: now.year, month: now.month, day: now.day, hour: hour, minute: minute, second: 0, nanosecond: 0, region: now.region))
        }
        let seconds = 60.0
        let minBrightness = minBrightness ?? self.minBrightness.uint8Value
        let maxBrightness = maxBrightness ?? self.maxBrightness.uint8Value
        let minContrast = minContrast ?? self.minContrast.uint8Value
        let maxContrast = maxContrast ?? self.maxContrast.uint8Value
        var newBrightness = NSNumber(value: minBrightness)
        var newContrast = NSNumber(value: minContrast)
        let daylightExtension = daylightExtension ?? datastore.defaults.daylightExtensionMinutes
        let noonDuration = noonDuration ?? datastore.defaults.noonDurationMinutes

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
                factor: factor ?? datastore.defaults.curveFactor, appOffset: appBrightnessOffset,
                minVal: Double(minBrightness), maxVal: Double(maxBrightness)
            )
            newContrast = computeValue(
                from: percent, type: .contrast,
                factor: factor ?? datastore.defaults.curveFactor, appOffset: appContrastOffset,
                minVal: Double(minContrast), maxVal: Double(maxContrast)
            )
        case noonEnd ... daylightEnd:
            let secondHalfDayMinutes = ((daylightEnd - noonEnd) / seconds)
            let minutesSinceNoon = ((now - noonEnd) / seconds)
            let percent = ((secondHalfDayMinutes - minutesSinceNoon) / secondHalfDayMinutes)
            newBrightness = computeValue(
                from: percent, type: .brightness,
                factor: factor ?? datastore.defaults.curveFactor, appOffset: appBrightnessOffset,
                minVal: Double(minBrightness), maxVal: Double(maxBrightness)
            )
            newContrast = computeValue(
                from: percent, type: .contrast,
                factor: factor ?? datastore.defaults.curveFactor, appOffset: appContrastOffset,
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
        moment: Moment,
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
        let step = 60 / minutesBetween
        var times = [Double]()
        times.reserveCapacity(24 * minutesBetween)

        let now = DateInRegion().convertTo(region: Region.local)
        for hour in 0 ..< 24 {
            times.append(contentsOf: stride(from: 0, through: 59, by: step).map { minute in
                let newNow = (now.dateBySet(hour: hour, min: minute, secs: 0) ??
                    DateInRegion(year: now.year, month: now.month, day: now.day, hour: hour, minute: minute, second: 0, nanosecond: 0, region: now.region))

                return newNow.timeIntervalSince1970
            })
        }

        let seconds = 60.0

        let minBrightness = minBrightness ?? self.minBrightness.uint8Value
        let maxBrightness = maxBrightness ?? self.maxBrightness.uint8Value
        let minContrast = minContrast ?? self.minContrast.uint8Value
        let maxContrast = maxContrast ?? self.maxContrast.uint8Value
        let daylightExtension = daylightExtension ?? datastore.defaults.daylightExtensionMinutes
        let noonDuration = noonDuration ?? datastore.defaults.noonDurationMinutes

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
                    from: percent, type: .brightness, factor: factor ?? datastore.defaults.curveFactor,
                    appOffset: appBrightnessOffset, minVal: minBrightnessDouble, maxVal: maxBrightnessDouble
                ),
                computeSIMDValue(
                    from: percent, type: .contrast, factor: factor ?? datastore.defaults.curveFactor,
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
                    from: percent, type: .brightness, factor: factor ?? datastore.defaults.curveFactor,
                    appOffset: appBrightnessOffset, minVal: minBrightnessDouble, maxVal: maxBrightnessDouble
                ),
                computeSIMDValue(
                    from: percent, type: .contrast, factor: factor ?? datastore.defaults.curveFactor,
                    appOffset: appContrastOffset, minVal: minContrastDouble, maxVal: maxContrastDouble
                )
            ).map { ($0, $1) }
        )

        return brightnessContrast
    }

    func adapt(moment: Moment? = nil, app: AppException? = nil, percent: Double? = nil) {
        if !adaptive {
            return
        }

        var newBrightness: NSNumber = 0
        var newContrast: NSNumber = 0
        if let moment = moment {
            (newBrightness, newContrast) = getBrightnessContrast(moment: moment, appBrightnessOffset: app?.brightness.intValue ?? 0, appContrastOffset: app?.contrast.intValue ?? 0)
        } else if let percent = percent {
            let percent = percent / 100.0
            newBrightness = computeValue(from: percent, type: .brightness, appOffset: app?.brightness.intValue ?? 0)
            newContrast = computeValue(from: percent, type: .contrast, appOffset: app?.contrast.intValue ?? 0)
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
