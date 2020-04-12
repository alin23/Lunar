//
//  BrightnessAdapter.swift
//  Lunar
//
//  Created by Alin on 02/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Alamofire
import Cocoa
import CoreLocation
import Foundation
import Sentry
import Solar
import Surge
import SwiftDate
import SwiftyJSON

enum AdaptiveMode: Int {
    case location = 1
    case sync = -1
    case manual = 0
}

class BrightnessAdapter {
    var lidClosed: Bool = IsLidClosed()
    var clamshellMode: Bool = false

    var appObserver: NSKeyValueObservation?
    var runningAppExceptions: [AppException]!
    var geolocation: Geolocation? {
        didSet {
            fetchMoments()
        }
    }

    var _moment: Moment?
    var moment: Moment? {
        get {
            if let m = _moment, !m.solarNoon.isToday {
                fetchMoments()
            }
            return _moment
        }
        set {
            _moment = newValue
            _moment?.store()
        }
    }

    var displays: [CGDirectDisplayID: Display] = BrightnessAdapter.getDisplays()
    var builtinDisplay = DDC.getBuiltinDisplay() {
        didSet {
            BrightnessAdapter.lastKnownBuiltinDisplayID = builtinDisplay ?? GENERIC_DISPLAY_ID
        }
    }

    var activeDisplays: [CGDirectDisplayID: Display] {
        displays.filter { $1.active }
    }

    var mode: AdaptiveMode = AdaptiveMode(rawValue: datastore.defaults.adaptiveBrightnessMode) ?? .sync {
        didSet {
            if oldValue != .manual {
                lastMode = oldValue
            }
        }
    }

    var lastMode: AdaptiveMode = AdaptiveMode(rawValue: datastore.defaults.adaptiveBrightnessMode) ?? .sync

    var builtinBrightnessHistory: UInt64 = 0
    var lastBuiltinBrightness = 0.0
    static var lastKnownBuiltinDisplayID: CGDirectDisplayID = GENERIC_DISPLAY_ID

    var brightnessClipMin: Double = Double(datastore.defaults.brightnessClipMin)
    var brightnessClipMax: Double = Double(datastore.defaults.brightnessClipMax)
    var brightnessClipMinObserver: NSKeyValueObservation?
    var brightnessClipMaxObserver: NSKeyValueObservation?

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

    static func isBuiltinDisplay(_ id: CGDirectDisplayID) -> Bool {
        return id != GENERIC_DISPLAY_ID && id != TEST_DISPLAY_ID && (CGDisplayIsBuiltin(id) == 1 || id == BrightnessAdapter.lastKnownBuiltinDisplayID)
    }

    func removeDisplay(id: CGDirectDisplayID) {
        if let display = displays.removeValue(forKey: id) {
            display.removeObservers()
        }
        let nsDisplays = displays.values.map {
            $0.dictionaryRepresentation()
        } as NSArray
        datastore.defaults.set(nsDisplays, forKey: "displays")
    }

    func toggle() {
        switch mode {
        case .location:
            if builtinDisplay != nil, !IsLidClosed() {
                datastore.defaults.set(AdaptiveMode.sync.rawValue, forKey: "adaptiveBrightnessMode")
            } else {
                datastore.defaults.set(AdaptiveMode.manual.rawValue, forKey: "adaptiveBrightnessMode")
            }
        case .sync:
            datastore.defaults.set(AdaptiveMode.manual.rawValue, forKey: "adaptiveBrightnessMode")
        case .manual:
            datastore.defaults.set(AdaptiveMode.location.rawValue, forKey: "adaptiveBrightnessMode")
        }
    }

    func disable() {
        if mode != .manual {
            lastMode = mode
            mode = .manual
        }
        datastore.defaults.set(AdaptiveMode.manual.rawValue, forKey: "adaptiveBrightnessMode")
    }

    func enable(mode: AdaptiveMode? = nil) {
        if let newMode = mode {
            self.mode = newMode
            datastore.defaults.set(newMode.rawValue, forKey: "adaptiveBrightnessMode")
        } else {
            if IsLidClosed(), self.mode == .manual {
                self.mode = .location
            } else {
                self.mode = lastMode
            }

            datastore.defaults.set(self.mode.rawValue, forKey: "adaptiveBrightnessMode")
        }
    }

    func resetDisplayList() {
        DDC.reset()
        for display in displays.values {
            display.removeObservers()
        }
        displays = BrightnessAdapter.getDisplays()
        addSentryData()
    }

    private static func getDisplays() -> [CGDirectDisplayID: Display] {
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
                    display.name = newName
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
        if let client = Client.shared {
            log.info("Creating Sentry extra context")
            client.extra = [
                "settings": datastore.settingsDictionary(),
                "displays": datastore.defaults.displays ?? [:],
                "apps": datastore.defaults.appExceptions ?? [:],
            ]
            for display in displays.values {
                if display.isUltraFine() {
                    client.tags?["ultrafine"] = "true"
                    continue
                }
                if display.isThunderbolt() {
                    client.tags?["thunderbolt"] = "true"
                    continue
                }
                if display.isLEDCinema() {
                    client.tags?["ledcinema"] = "true"
                    continue
                }
            }
        }
    }

    func adaptiveModeString(last: Bool = false) -> String {
        let mode: AdaptiveMode
        if last {
            mode = lastMode
        } else {
            mode = self.mode
        }

        switch mode {
        case .manual:
            return "Manual"
        case .location:
            return "Location"
        case .sync:
            return "Sync"
        }
    }

    func activateClamshellMode() {
        if mode != .manual {
            clamshellMode = true
            disable()
        }
    }

    func deactivateClamshellMode() {
        if mode == .manual {
            clamshellMode = false
            enable()
        }
    }

    func manageClamshellMode() {
        lidClosed = IsLidClosed()
        log.info("Lid closed: \(lidClosed)")
        Client.shared?.tags?["clamshellMode"] = String(lidClosed)

        if datastore.defaults.clamshellModeDetection {
            if lidClosed {
                activateClamshellMode()
            } else if clamshellMode {
                deactivateClamshellMode()
            }
        }
    }

    func fetchMoments() {
        let now = DateInRegion().convertTo(region: Region.local)
        var date = now.date
        date += TimeInterval(Region.local.timeZone.secondsFromGMT())
        log.debug("Getting moments for \(date)")
        if let geolocation = geolocation, let solar = Solar(for: date, coordinate: geolocation.coordinate) {
            moment = Moment(solar)
            log.debug("Computed moment from Solar")
            return
        }
        if let moment = Moment() {
            if moment.solarNoon.isToday {
                self.moment = moment
                log.debug("Computed moment is today, storing it")
                return
            }
            log.debug("Computed moment is not today, not storing it")
        }

        if let geolocation = geolocation {
            AF.request("https://api.sunrise-sunset.org/json?lat=\(geolocation.latitude)&lng=\(geolocation.longitude)&date=today&formatted=0").validate().responseJSON { [weak self] response in
                switch response.result {
                case let .success(value):
                    let json = JSON(value)
                    if json["status"].string == "OK" {
                        self?.moment = Moment(result: json["results"].dictionaryValue)
                    } else {
                        log.error("Sunrise API status: \(json["status"].string ?? "null")")
                    }
                case let .failure(error):
                    log.error("Sunrise API error: \(error)")
                }
            }
        }
    }

    func fetchGeolocation() {
        if let geolocation = Geolocation() {
            self.geolocation = geolocation
            return
        }

        AF.request("http://api.ipstack.com/check?access_key=4ce42ebf00e768aad70140eab4a95c75").validate().responseJSON { response in
            switch response.result {
            case let .success(value):
                let json = JSON(value)
                let geolocation = Geolocation(result: json)
                self.geolocation = geolocation
            case let .failure(error):
                log.error("IP Geolocation error: \(error)")
            }
        }
    }

    func listenForBrightnessClipChange() {
        brightnessClipMaxObserver = datastore.defaults.observe(\.brightnessClipMax, changeHandler: { [unowned self] _, change in
            self.brightnessClipMax = Double(change.newValue ?? datastore.defaults.brightnessClipMax)
        })
        brightnessClipMinObserver = datastore.defaults.observe(\.brightnessClipMin, changeHandler: { [unowned self] _, change in
            self.brightnessClipMin = Double(change.newValue ?? datastore.defaults.brightnessClipMin)
        })
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
        }
    }

    func adaptBrightness(for displays: [Display]? = nil, percent: Double? = nil) {
        if mode == .manual {
            return
        }

        var adapt: (Display) -> Void

        switch mode {
        case .sync:
            let builtinBrightness = percent ?? getBuiltinDisplayBrightness()
            if builtinBrightness == nil {
                log.warning("There's no builtin display to sync with")
                return
            }
            adapt = { display in display.adapt(moment: nil, app: self.runningAppExceptions?.last, percent: builtinBrightness, brightnessClipMin: self.brightnessClipMin, brightnessClipMax: self.brightnessClipMax) }
        case .location:
            if moment == nil {
                log.warning("Day moments aren't fetched yet")
                return
            }
            adapt = { display in display.adapt(moment: self.moment, app: self.runningAppExceptions?.last, percent: nil) }
        default:
            adapt = { _ in () }
        }

        if let displays = displays {
            displays.forEach(adapt)
        } else {
            activeDisplays.values.forEach(adapt)
        }
    }

    func lastValidBuiltinBrightness(_ condition: (UInt8) -> Bool) -> UInt8? {
        var brightnessHistory: UInt64 = builtinBrightnessHistory
        var result: UInt8 = 0
        while brightnessHistory > 0 {
            result = UInt8(brightnessHistory & 0xFF)
            if condition(result) {
                return result
            }
            brightnessHistory >>= 8
        }
        return nil
    }

    func getBuiltinDisplayBrightness() -> Double? {
        if builtinDisplay != nil, !IsLidClosed(), let brightness = DDC.getBrightness() {
            if brightness >= 0.0, brightness <= 1.0 {
                let percentBrightness = brightness * 100.0
                builtinBrightnessHistory = (builtinBrightnessHistory << 8) | UInt64(UInt8(round(percentBrightness)))
                return percentBrightness
            }
        }
        return nil
    }

    func getBrightnessContrast(
        for display: Display,
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
        if moment == nil {
            log.warning("Day moments aren't fetched yet")
            return (0, 0)
        }
        return display.getBrightnessContrast(
            moment: moment,
            hour: hour,
            minute: minute,
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
        if moment == nil {
            log.warning("Day moments aren't fetched yet")
            return [(NSNumber, NSNumber)](repeating: (0, 0), count: count * minutesBetween)
        }
        return display.getBrightnessContrastBatch(
            moment: moment,
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
        let minVal = minVal ?? datastore.defaults.integer(forKey: "\(key)LimitMin")
        let maxVal = maxVal ?? datastore.defaults.integer(forKey: "\(key)LimitMax")
        let value = Int(round(percent * Double(maxVal - minVal))) + minVal
        return NSNumber(value: cap(value, minVal: minVal, maxVal: maxVal))
    }

    func computeSIMDManualValueFromPercent(from percent: [Double], key: String, minVal: Int? = nil, maxVal: Int? = nil) -> [Double] {
        let minVal = minVal ?? datastore.defaults.integer(forKey: "\(key)LimitMin")
        let maxVal = maxVal ?? datastore.defaults.integer(forKey: "\(key)LimitMax")
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
            let value = cap(display.brightness.intValue + offset, minVal: datastore.defaults.brightnessLimitMin, maxVal: datastore.defaults.brightnessLimitMax)
            display.brightness = NSNumber(value: value)
        }
    }

    func adjustContrast(by offset: Int, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        adjustValue(for: displays, currentDisplay: currentDisplay) { (display: Display) in
            let value = cap(display.contrast.intValue + offset, minVal: datastore.defaults.contrastLimitMin, maxVal: datastore.defaults.contrastLimitMax)
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

    init() {
        BrightnessAdapter.lastKnownBuiltinDisplayID = builtinDisplay ?? GENERIC_DISPLAY_ID
    }
}
