//
//  LunarBrightness.swift
//  Lunar
//
//  Created by Alin on 02/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Alamofire
import Cocoa
import CoreLocation
import Crashlytics
import Foundation
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
    var appObserver: NSKeyValueObservation?
    var runningAppExceptions: [AppException]!
    var geolocation: Geolocation! {
        didSet {
            geolocation.store()
            fetchMoments()
        }
    }

    var _moment: Moment!
    var moment: Moment! {
        get {
            if let m = _moment, !m.solarNoon.isToday {
                fetchMoments()
            }
            return _moment
        }
        set {
            _moment = newValue
            if _moment != nil {
                _moment.store()
            }
        }
    }

    var displays: [CGDirectDisplayID: Display] = BrightnessAdapter.getDisplays()
    var builtinDisplay = DDC.getBuiltinDisplay()

    var mode: AdaptiveMode = AdaptiveMode(rawValue: datastore.defaults.adaptiveBrightnessMode) ?? .location
    var lastMode: AdaptiveMode = AdaptiveMode(rawValue: datastore.defaults.adaptiveBrightnessMode) ?? .location

    var lastBuiltinBrightness = 0.0

    var firstDisplay: Display {
        if !displays.isEmpty {
            return displays.values.first(where: { d in d.active }) ?? displays.values.first!
        } else if TEST_MODE {
            return TEST_DISPLAY
        } else {
            return GENERIC_DISPLAY
        }
    }

    func toggle() {
        switch mode {
        case .location:
            if builtinDisplay != nil {
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
        lastMode = mode
        mode = .manual
        datastore.defaults.set(AdaptiveMode.manual.rawValue, forKey: "adaptiveBrightnessMode")
    }

    func enable(mode: AdaptiveMode? = nil) {
        if let newMode = mode {
            self.mode = newMode
            datastore.defaults.set(newMode.rawValue, forKey: "adaptiveBrightnessMode")
        } else {
            self.mode = lastMode
            datastore.defaults.set(lastMode.rawValue, forKey: "adaptiveBrightnessMode")
        }
    }

    func resetDisplayList() {
        for display in displays.values {
            display.removeObservers()
        }
        displays = BrightnessAdapter.getDisplays()
    }

    static func logDisplays(_ displays: [Display]) {
        for (i, display) in displays.enumerated() {
            Crashlytics.sharedInstance().setObjectValue(display.serial, forKey: "display\(i)")
            for (j, str) in DDC.getTextDescriptors(displayID: display.id).enumerated() {
                Crashlytics.sharedInstance().setObjectValue(str, forKey: "display\(i)-descriptor\(j)")
                log.debug("display\(i)-descriptor\(j): \(str)")
            }
            Answers.logCustomEvent(withName: "Found Display", customAttributes: ["serial": display.serial])
        }
    }

    private static func getDisplays() -> [CGDirectDisplayID: Display] {
        var displays: [CGDirectDisplayID: Display]
        let displayIDs = Set(DDC.findExternalDisplays())
        var serialsAndNames = displayIDs.enumerated().map { i, id in
            (
                DDC.getEdidTextData(displayID: id).stripped,
                lunarDisplayNames[i % lunarDisplayNames.count]
            )
        }
        var serials = serialsAndNames.map { d in d.0 }
        if serials.count != Set(serials).count {
            serials = zip(serials, displayIDs).map { serial, id in "\(serial)-\(id)" }
            serialsAndNames = zip(serialsAndNames, serials).map { d, serial in (serial, d.1) }
        }
        let displaySerialIDMapping = Dictionary(uniqueKeysWithValues: zip(serials, displayIDs))
        let displaySerialNameMapping = Dictionary(uniqueKeysWithValues: serialsAndNames)
        let displayIDSerialNameMapping = Dictionary(uniqueKeysWithValues: zip(displayIDs, serialsAndNames))

        do {
            let displayList = try datastore.fetchDisplays(by: serials)
            for display in displayList {
                display.id = displaySerialIDMapping[display.serial]!
                display.name = displaySerialNameMapping[display.serial]!
                display.active = true
                display.addObservers()
            }

            displays = Dictionary(uniqueKeysWithValues: displayList.map {
                (d) -> (CGDirectDisplayID, Display) in (d.id, d)
            })

            let loadedDisplayIDs = Set(displays.keys)
            for id in displayIDs.subtracting(loadedDisplayIDs) {
                if let (serial, name) = displayIDSerialNameMapping[id] {
                    displays[id] = Display(id: id, serial: serial, name: name)
                } else {
                    displays[id] = Display(id: id)
                }
                displays[id]?.addObservers()
            }

            datastore.save()
            BrightnessAdapter.logDisplays(displays.values.map { d in d })
            return displays
        } catch {
            log.error("Error on fetching displays: \(error)")
            displays = Dictionary(uniqueKeysWithValues: displayIDs.map { id in (id, Display(id: id, active: true)) })
            displays.values.forEach { $0.addObservers() }
        }

        datastore.save()
        BrightnessAdapter.logDisplays(displays.values.map { d in d })
        return displays
    }

    func fetchMoments() {
        let now = DateInRegion().convertTo(region: Region.local)
        var date = now.date
        date += TimeInterval(Region.local.timeZone.secondsFromGMT())
        log.debug("Getting moments for \(date)")
        if let solar = Solar(for: date, coordinate: self.geolocation.coordinate) {
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

        Alamofire.request("https://api.sunrise-sunset.org/json?lat=\(geolocation.latitude)&lng=\(geolocation.longitude)&date=today&formatted=0").validate().responseJSON { response in
            switch response.result {
            case let .success(value):
                let json = JSON(value)
                if json["status"].string == "OK" {
                    self.moment = Moment(result: json["results"].dictionaryValue)
                } else {
                    log.error("Sunrise API status: \(json["status"].string ?? "null")")
                }
            case let .failure(error):
                log.error("Sunrise API error: \(error)")
            }
        }
    }

    func fetchGeolocation() {
        if let geolocation = Geolocation() {
            self.geolocation = geolocation
            return
        }

        Alamofire.request("http://api.ipstack.com/check?access_key=***REMOVED***").validate().responseJSON { response in
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

    func listenForRunningApps() {
        let appNames = NSWorkspace.shared.runningApplications.map { app in app.bundleIdentifier ?? "" }
        runningAppExceptions = (try? datastore.fetchAppExceptions(by: appNames)) ?? []
        for app in runningAppExceptions {
            app.addObservers()
        }

        adaptBrightness()

        appObserver = NSWorkspace.shared.observe(\.runningApplications, options: [.old, .new], changeHandler: { _, change in
            let oldAppNames = change.oldValue?.map { app in app.bundleIdentifier ?? "" }
            let newAppNames = change.newValue?.map { app in app.bundleIdentifier ?? "" }
            do {
                if let names = newAppNames {
                    self.runningAppExceptions.append(contentsOf: try datastore.fetchAppExceptions(by: names))
                }
                if let names = oldAppNames {
                    let exceptions = try datastore.fetchAppExceptions(by: names)
                    for exception in exceptions {
                        if let idx = self.runningAppExceptions.index(where: { app in app.name == exception.name }) {
                            self.runningAppExceptions.remove(at: idx)
                        }
                    }
                }
                self.adaptBrightness()
            } catch {
                log.error("Error on fetching app exceptions for app names: \(newAppNames ?? [""])")
            }
        })
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
            adapt = { display in display.adapt(moment: nil, app: self.runningAppExceptions?.last, percent: builtinBrightness) }
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
            self.displays.values.forEach(adapt)
        }
    }

    func getBuiltinDisplayBrightness() -> Double? {
        if let displayID = builtinDisplay {
            let brightness = DDC.getBrightness(for: displayID)
            if brightness >= 0.0, brightness <= 1.0 {
                return brightness * 100
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
            self.displays.values.forEach { display in display.brightness = brightness }
        }
    }

    func setContrastPercent(value: Int8, for displays: [Display]? = nil) {
        let contrast = computeManualValueFromPercent(percent: value, key: "contrast")

        if let displays = displays {
            displays.forEach { display in display.contrast = contrast }
        } else {
            self.displays.values.forEach { display in display.contrast = contrast }
        }
    }

    func setBrightness(brightness: NSNumber, for displays: [Display]? = nil) {
        if let displays = displays {
            displays.forEach { display in display.brightness = brightness }
        } else {
            self.displays.values.forEach { display in display.brightness = brightness }
        }
    }

    func setContrast(contrast: NSNumber, for displays: [Display]? = nil) {
        if let displays = displays {
            displays.forEach { display in display.contrast = contrast }
        } else {
            self.displays.values.forEach { display in display.contrast = contrast }
        }
    }

    func adjustBrightness(by offset: Int8, for displays: [Display]? = nil) {
        if let displays = displays {
            displays.forEach { display in
                let value = cap(display.brightness.int8Value + offset, minVal: 0, maxVal: 100)
                display.brightness = NSNumber(value: value)
            }
        } else {
            self.displays.values.forEach { display in
                let value = cap(display.brightness.int8Value + offset, minVal: 0, maxVal: 100)
                display.brightness = NSNumber(value: value)
            }
        }
    }

    func adjustContrast(by offset: Int8, for displays: [Display]? = nil) {
        if let displays = displays {
            displays.forEach { display in
                let value = cap(display.contrast.int8Value + offset, minVal: 0, maxVal: 100)
                display.contrast = NSNumber(value: value)
            }
        } else {
            self.displays.values.forEach { display in
                let value = cap(display.contrast.int8Value + offset, minVal: 0, maxVal: 100)
                display.contrast = NSNumber(value: value)
            }
        }
    }
}
