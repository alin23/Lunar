//
//  DisplayController.swift
//  Lunar
//
//  Created by Alin on 02/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Alamofire
import AMCoreAudio
import Cocoa
import CoreLocation
import Defaults
import Foundation
import Sentry
import Solar
import Surge
import SwiftDate
import SwiftyJSON

class DisplayController {
    var lidClosed: Bool = IsLidClosed()
    var clamshellMode: Bool = false

    var appObserver: NSKeyValueObservation?
    var runningAppExceptions: [AppException]!

    var displays: [CGDirectDisplayID: Display] = [:] {
        didSet {
            activeDisplays = displays.filter { $1.active }
            activeDisplaysByReadableID = [String: Display](
                uniqueKeysWithValues: activeDisplays.map { _, display in
                    (display.readableID, display)
                }
            )
        }
    }

    var activeDisplays: [CGDirectDisplayID: Display] = [:]
    var activeDisplaysByReadableID: [String: Display] = [:]

    var adaptiveMode: AdaptiveMode = DisplayController.getAdaptiveMode() {
        didSet {
            if oldValue.key != .manual {
                oldValue.stopWatching()
                lastNonManualAdaptiveMode = oldValue
            }
            _ = adaptiveMode.watch()
        }
    }

    var adaptiveModeKey: AdaptiveModeKey {
        adaptiveMode.key
    }

    var lastNonManualAdaptiveMode: AdaptiveMode = DisplayController.getAdaptiveMode()

    var brightnessClipMin = Double(Defaults[.brightnessClipMin])
    var brightnessClipMax = Double(Defaults[.brightnessClipMax])
    var brightnessClipMinObserver: DefaultsObservation?
    var brightnessClipMaxObserver: DefaultsObservation?

    var appBrightnessOffset: Int {
        Int(runningAppExceptions?.last?.brightness ?? 0)
    }

    var appContrastOffset: Int {
        Int(runningAppExceptions?.last?.contrast ?? 0)
    }

    var firstDisplay: Display {
        if !displays.isEmpty {
            return displays.values.first(where: { d in d.active }) ?? displays.values.first!
        } else if TEST_MODE {
            return TEST_DISPLAY()
        } else {
            return GENERIC_DISPLAY
        }
    }

    var mainDisplay: Display? {
        guard let screen = getScreenWithMouse(),
              let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { return nil }

        return activeDisplays[id]
    }

    var currentAudioDisplay: Display? {
        guard let audioDevice = AudioDevice.defaultOutputDevice(), !audioDevice.canSetVirtualMasterVolume(direction: .playback) else {
            return nil
        }
        return activeDisplays.values.map { $0 }.sorted(by: { d1, d2 in
            d1.name.levenshtein(audioDevice.name) < d2.name.levenshtein(audioDevice.name)
        }).first ?? currentDisplay
    }

    var currentDisplay: Display? {
        if let display = mainDisplay {
            return display
        }

        let displays = activeDisplays.values.map { $0 }
        if displays.count == 1 {
            return displays[0]
        } else {
            for display in displays {
                if CGDisplayIsMain(display.id) == 1 {
                    return display
                }
            }
        }
        return nil
    }

    var onAdapt: ((Any) -> Void)?

    func removeDisplay(id: CGDirectDisplayID) {
        if let display = displays.removeValue(forKey: id) {
            display.removeObservers()
        }
        let nsDisplays = displays.values.map { $0 }
        Defaults[.displays] = nsDisplays
    }

    static func getAdaptiveMode() -> AdaptiveMode {
        return Defaults[.overrideAdaptiveMode] ? Defaults[.adaptiveBrightnessMode].mode : autoMode()
    }

    static func autoMode() -> AdaptiveMode {
        if let mode = SensorMode().ifAvailable() {
            return mode
        } else if let mode = SyncMode().ifAvailable() {
            return mode
        } else if let mode = LocationMode().ifAvailable() {
            return mode
        } else {
            return ManualMode()
        }
    }

    func toggle() {
        if adaptiveModeKey == .manual {
            enable()
        } else {
            disable()
        }
    }

    func disable() {
        if adaptiveModeKey != .manual {
            adaptiveMode = ManualMode()
        }
        Defaults[.adaptiveBrightnessMode] = AdaptiveModeKey.manual
    }

    func enable(mode: AdaptiveModeKey? = nil) {
        if let newMode = mode {
            adaptiveMode = newMode.mode
        } else if lastNonManualAdaptiveMode.available {
            adaptiveMode = lastNonManualAdaptiveMode
        } else {
            adaptiveMode = DisplayController.getAdaptiveMode()
        }
        Defaults[.adaptiveBrightnessMode] = adaptiveMode.key
    }

    func resetDisplayList() {
        DDC.reset()
        for display in displays.values {
            display.removeObservers()
        }
        displays = DisplayController.getDisplays()
        addSentryData()
    }

    static func getDisplays() -> [CGDirectDisplayID: Display] {
        var displays: [CGDirectDisplayID: Display]
        let displayIDs = Set(DDC.findExternalDisplays())

        var serials = displayIDs.map { Display.uuid(id: $0) }
        let names = displayIDs.map { Display.printableName(id: $0) }
        var serialsAndNames = zip(serials, names).map { ($0, $1) }

        // Make sure serials are unique
        if serials.count != Set(serials).count {
            serials = zip(serials, displayIDs).map { serial, id in Display.edid(id: id) ?? "\(serial)-\(id)" }
            serialsAndNames = zip(serialsAndNames, serials).map { d, serial in (serial, d.1) }
        }

        let displaySerialIDMapping = Dictionary(zip(serials, displayIDs), uniquingKeysWith: { first, _ in first })
        let displaySerialNameMapping = Dictionary(serialsAndNames, uniquingKeysWith: { first, _ in first })
        let displayIDSerialNameMapping = Dictionary(zip(displayIDs, serialsAndNames), uniquingKeysWith: { first, _ in first })

        if let displayList = datastore.displays(serials: serials) {
            for display in displayList {
                if let newID = displaySerialIDMapping[display.serial] {
                    display.id = newID
                }
                if let newName = displaySerialNameMapping[display.serial] {
                    display.edidName = newName
                    if display.name.isEmpty {
                        display.name = newName
                    }
                }
                display.active = true
                display.addObservers()
            }

            displays = Dictionary(displayList.map {
                (d) -> (CGDirectDisplayID, Display) in (d.id, d)
            }, uniquingKeysWith: { first, _ in first })

            let loadedDisplayIDs = Set(displays.keys)
            for id in displayIDs.subtracting(loadedDisplayIDs) {
                if let (serial, name) = displayIDSerialNameMapping[id] {
                    displays[id] = Display(id: id, serial: serial, name: name, active: true)
                } else {
                    displays[id] = Display(id: id, active: true)
                }
                displays[id]?.addObservers()
            }

            let storedDisplays = datastore.storeDisplays(displays.values.map { $0 })
            return Dictionary(storedDisplays.map { d in (d.id, d) }, uniquingKeysWith: { first, _ in first })
        }
        displays = Dictionary(displayIDs.map { id in (id, Display(id: id, active: true)) }, uniquingKeysWith: { first, _ in first })
        displays.values.forEach { $0.addObservers() }

        let storedDisplays = datastore.storeDisplays(displays.values.map { $0 })
        return Dictionary(storedDisplays.map { d in (d.id, d) }, uniquingKeysWith: { first, _ in first })
    }

    func addSentryData() {
        SentrySDK.configureScope { [weak self] scope in
            log.info("Creating Sentry extra context")
            scope.setExtra(value: datastore.settingsDictionary() ?? [:], key: "settings")
            guard let self = self else { return }
            for display in self.displays.values {
                if display.isUltraFine() {
                    scope.setTag(value: "true", key: "ultrafine")
                    continue
                }
                if display.isThunderbolt() {
                    scope.setTag(value: "true", key: "thunderbolt")
                    continue
                }
                if display.isLEDCinema() {
                    scope.setTag(value: "true", key: "ledcinema")
                    continue
                }
            }
        }
    }

    func adaptiveModeString(last: Bool = false) -> String {
        let mode: AdaptiveModeKey
        if last {
            mode = lastNonManualAdaptiveMode.key
        } else {
            mode = adaptiveModeKey
        }

        return mode.str
    }

    func activateClamshellMode() {
        if adaptiveModeKey == .sync {
            clamshellMode = true
            disable()
        }
    }

    func deactivateClamshellMode() {
        if adaptiveModeKey == .manual {
            clamshellMode = false
            enable()
        }
    }

    func manageClamshellMode() {
        lidClosed = IsLidClosed()
        log.info("Lid closed: \(lidClosed)")
        SentrySDK.configureScope { [weak self] scope in
            guard let self = self else { return }
            scope.setTag(value: String(describing: self.lidClosed), key: "clamshellMode")
        }

        if Defaults[.clamshellModeDetection] {
            if lidClosed {
                activateClamshellMode()
            } else if clamshellMode {
                deactivateClamshellMode()
            }
        }
    }

    func listenForBrightnessClipChange() {
        brightnessClipMaxObserver = Defaults.observe(.brightnessClipMax) { [unowned self] change in
            self.brightnessClipMax = Double(change.newValue)
        }
        brightnessClipMinObserver = Defaults.observe(.brightnessClipMin) { [unowned self] change in
            self.brightnessClipMin = Double(change.newValue)
        }
    }

    func listenForRunningApps() {
        let appIdentifiers = NSWorkspace.shared.runningApplications.map { app in app.bundleIdentifier }.compactMap { $0 }
        runningAppExceptions = datastore.appExceptions(identifiers: appIdentifiers) ?? []
        adaptBrightness()

        appObserver = NSWorkspace.shared.observe(\.runningApplications, options: [.old, .new], changeHandler: { [unowned self] _, change in
            let oldAppIdentifiers = change.oldValue?.map { app in app.bundleIdentifier }.compactMap { $0 }
            let newAppIdentifiers = change.newValue?.map { app in app.bundleIdentifier }.compactMap { $0 }
            if let identifiers = newAppIdentifiers, let newApps = datastore.appExceptions(identifiers: identifiers) {
                self.runningAppExceptions.append(contentsOf: newApps)
            }
            if let identifiers = oldAppIdentifiers, let exceptions = datastore.appExceptions(identifiers: identifiers) {
                for exception in exceptions {
                    if let idx = self.runningAppExceptions.firstIndex(where: { app in app.identifier == exception.identifier }) {
                        self.runningAppExceptions.remove(at: idx)
                    }
                }
            }
            self.adaptBrightness()
        })
    }

    func fetchValues(for displays: [Display]? = nil) {
        for display in displays ?? activeDisplays.values.map({ $0 }) {
            display.refreshBrightness()
            display.refreshContrast()
            display.refreshVolume()
            display.refreshInput()
        }
    }

    func adaptBrightness(for display: Display) {
        adaptiveMode.adapt(display)
    }

    func adaptBrightness(for displays: [Display]? = nil) {
        for display in displays ?? Array(activeDisplays.values) {
            adaptiveMode.adapt(display)
        }

//        if mode == .manual {
//            return
//        }
//
//        var adapt: (Display) -> Void
//
//        switch mode {
//        case .sync:
//            let builtinBrightness = percent ?? SyncMode.getBuiltinDisplayBrightness()
//            if builtinBrightness == nil {
//                log.warning("There's no builtin display to sync with")
//                return
//            }
//            adapt = { display in display.adapt(
//                moment: nil,
//                app: self.runningAppExceptions?.last,
//                percent: builtinBrightness,
//                brightnessClipMin: self.brightnessClipMin,
//                brightnessClipMax: self.brightnessClipMax
//            ) }
//        case .location:
//            if LocationMode.moment == nil {
//                log.warning("Day moments aren't fetched yet")
//                return
//            }
//            adapt = { display in display.adapt(moment: LocationMode.moment, app: self.runningAppExceptions?.last, percent: nil) }
//        default:
//            adapt = { _ in () }
//        }
//
//        if let displays = displays {
//            displays.forEach(adapt)
//        } else {
//            activeDisplays.values.forEach(adapt)
//        }
    }

//    func getBrightnessContrast(
//        for display: Display,
//        hour: Int? = nil,
//        minute: Int = 0,
//        factor: Double? = nil,
//        minBrightness: UInt8? = nil,
//        maxBrightness: UInt8? = nil,
//        minContrast: UInt8? = nil,
//        maxContrast: UInt8? = nil,
//        daylightExtension: Int? = nil,
//        noonDuration: Int? = nil,
//        appBrightnessOffset: Int = 0,
//        appContrastOffset: Int = 0
//    ) -> (NSNumber, NSNumber) {
//        if LocationMode.moment == nil {
//            log.warning("Day moments aren't fetched yet")
//            return (0, 0)
//        }
//        return display.getBrightnessContrast(
//            moment: LocationMode.moment,
//            hour: hour,
//            minute: minute,
//            factor: factor,
//            minBrightness: minBrightness,
//            maxBrightness: maxBrightness,
//            minContrast: minContrast,
//            maxContrast: maxContrast,
//            daylightExtension: daylightExtension,
//            noonDuration: noonDuration,
//            appBrightnessOffset: appBrightnessOffset,
//            appContrastOffset: appContrastOffset
//        )
//    }

    func getBrightnessContrastBatch(
        for display: Display,
        count: Int,
        minutesBetween: Int,
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
        if LocationMode.moment == nil {
            log.warning("Day moments aren't fetched yet")
            return [(NSNumber, NSNumber)](repeating: (0, 0), count: count * minutesBetween)
        }
        return display.getBrightnessContrastBatch(
            moment: LocationMode.moment,
            minutesBetween: minutesBetween,
            factor: factor,
            minBrightness: minBrightness,
            maxBrightness: maxBrightness,
            minContrast: minContrast,
            maxContrast: maxContrast,
            daylightExtension: daylightExtension,
            noonDuration: noonDuration,
            appBrightnessOffset: appBrightnessOffset,
            appContrastOffset: appContrastOffset
        )
    }

    func computeManualValueFromPercent(percent: Int8, key: String, minVal: Int? = nil, maxVal: Int? = nil) -> NSNumber {
        let percent = Double(cap(percent, minVal: 0, maxVal: 100)) / 100.0
        let minVal = minVal ?? Defaults[Defaults.Key<Int>("\(key)LimitMin", default: 0)]
        let maxVal = maxVal ?? Defaults[Defaults.Key<Int>("\(key)LimitMax", default: 100)]
        let value = Int(round(percent * Double(maxVal - minVal))) + minVal
        return NSNumber(value: cap(value, minVal: minVal, maxVal: maxVal))
    }

    func computeSIMDManualValueFromPercent(from percent: [Double], key: String, minVal: Int? = nil, maxVal: Int? = nil) -> [Double] {
        let minVal = minVal ?? Defaults[Defaults.Key<Int>("\(key)LimitMin", default: 0)]
        let maxVal = maxVal ?? Defaults[Defaults.Key<Int>("\(key)LimitMax", default: 100)]
        return percent * Double(maxVal - minVal) + Double(minVal)
    }

    func setBrightnessPercent(value: Int8, for displays: [Display]? = nil) {
        let brightness = computeManualValueFromPercent(percent: value, key: "brightness")
        if let displays = displays {
            displays.forEach { display in display.brightness = brightness }
        } else {
            activeDisplays.values.forEach { display in display.brightness = brightness }
        }
    }

    func setContrastPercent(value: Int8, for displays: [Display]? = nil) {
        let contrast = computeManualValueFromPercent(percent: value, key: "contrast")

        if let displays = displays {
            displays.forEach { display in display.contrast = contrast }
        } else {
            activeDisplays.values.forEach { display in display.contrast = contrast }
        }
    }

    func setBrightness(brightness: NSNumber, for displays: [Display]? = nil) {
        if let displays = displays {
            displays.forEach { display in display.brightness = brightness }
        } else {
            activeDisplays.values.forEach { display in display.brightness = brightness }
        }
    }

    func setContrast(contrast: NSNumber, for displays: [Display]? = nil) {
        if let displays = displays {
            displays.forEach { display in display.contrast = contrast }
        } else {
            activeDisplays.values.forEach { display in display.contrast = contrast }
        }
    }

    func toggleAudioMuted(for displays: [Display]? = nil, currentDisplay: Bool = false) {
        adjustValue(for: displays, currentDisplay: currentDisplay) { (display: Display) in
            display.audioMuted = !display.audioMuted
        }
    }

    func adjustVolume(by offset: Int, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        adjustValue(for: displays, currentDisplay: currentDisplay) { (display: Display) in
            let value = cap(display.volume.intValue + offset, minVal: MIN_VOLUME, maxVal: MAX_VOLUME)
            display.volume = NSNumber(value: value)
        }
    }

    func adjustBrightness(by offset: Int, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        adjustValue(for: displays, currentDisplay: currentDisplay) { (display: Display) in
            let value = cap(
                display.brightness.intValue + offset,
                minVal: Defaults[.brightnessLimitMin],
                maxVal: Defaults[.brightnessLimitMax]
            )
            display.brightness = NSNumber(value: value)
        }
    }

    func adjustContrast(by offset: Int, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        adjustValue(for: displays, currentDisplay: currentDisplay) { (display: Display) in
            let value = cap(display.contrast.intValue + offset, minVal: Defaults[.contrastLimitMin], maxVal: Defaults[.contrastLimitMax])
            display.contrast = NSNumber(value: value)
        }
    }

    func adjustValue(for displays: [Display]? = nil, currentDisplay: Bool = false, _ setValue: (Display) -> Void) {
        if currentDisplay {
            if let display = self.currentDisplay {
                setValue(display)
            }
        } else if let displays = displays {
            displays.forEach { display in
                setValue(display)
            }
        } else {
            activeDisplays.values.forEach { display in
                setValue(display)
            }
        }
    }
}

let displayController = DisplayController()
