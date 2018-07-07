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
import SwiftDate
import SwiftyJSON

class BrightnessAdapter {
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
    var running: Bool = datastore.defaults.adaptiveBrightnessEnabled
    var firstDisplay: Display {
        if displays.count > 0 {
            return displays.values.first(where: { d in d.active }) ?? displays.values.first!
        } else {
            return GENERIC_DISPLAY
        }
    }

    func toggle() {
        datastore.defaults.set(!running, forKey: "adaptiveBrightnessEnabled")
    }

    func disable() {
        datastore.defaults.set(false, forKey: "adaptiveBrightnessEnabled")
    }

    func enable() {
        datastore.defaults.set(true, forKey: "adaptiveBrightnessEnabled")
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
            }
            Answers.logCustomEvent(withName: "Found Display", customAttributes: ["serial": display.serial, "name": display.name])
        }
    }

    private static func getDisplays() -> [CGDirectDisplayID: Display] {
        var displays: [CGDirectDisplayID: Display]
        let displayIDs = Set(DDC.findExternalDisplays())
        var serialsAndNames = displayIDs.enumerated().map({ i, id in (DDC.getDisplaySerial(for: id), lunarDisplayNames[i % lunarDisplayNames.count]) })
        var serials = serialsAndNames.map({ d in d.0 })
        if serials.count != Set(serials).count {
            serials = zip(serials, displayIDs).map({ serial, id in "\(serial)-\(id)" })
            serialsAndNames = zip(serialsAndNames, serials).map({ d, serial in (serial, d.1) })
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
            BrightnessAdapter.logDisplays(displays.values.map({ d in d }))
            return displays
        } catch {
            log.error("Error on fetching displays: \(error)")
            displays = Dictionary(uniqueKeysWithValues: displayIDs.map { id in (id, Display(id: id, active: true)) })
            displays.values.forEach({ $0.addObservers() })
        }

        datastore.save()
        BrightnessAdapter.logDisplays(displays.values.map({ d in d }))
        return displays
    }

    func fetchMoments() {
        let now = DateInRegion()
        var date = now.absoluteDate
        date += TimeInterval(now.region.timeZone.secondsFromGMT())
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

    func adaptBrightness(for displays: [Display]? = nil, app: AppException? = nil) {
        if moment == nil {
            log.warning("Day moments aren't fetched yet")
            return
        }
        if let displays = displays {
            displays.forEach({ display in display.adapt(moment: moment, app: app) })
        } else {
            self.displays.values.forEach({ display in display.adapt(moment: moment, app: app) })
        }
    }

    func getBrightnessContrast(
        for display: Display,
        hour: Int? = nil,
        minute: Int = 0,
        minBrightness: UInt8? = nil,
        maxBrightness: UInt8? = nil,
        minContrast: UInt8? = nil,
        maxContrast: UInt8? = nil,
        daylightExtension: Int? = nil,
        noonDuration: Int? = nil,
        brightnessOffset: Int = 0,
        contrastOffset: Int = 0
    ) -> (NSNumber, NSNumber) {
        if moment == nil {
            log.warning("Day moments aren't fetched yet")
            return (0, 0)
        }
        return display.getBrightnessContrast(
            moment: moment,
            hour: hour,
            minute: minute,
            minBrightness: minBrightness,
            maxBrightness: maxBrightness,
            minContrast: minContrast,
            maxContrast: maxContrast,
            daylightExtension: daylightExtension,
            noonDuration: noonDuration,
            brightnessOffset: brightnessOffset,
            contrastOffset: contrastOffset
        )
    }

    func computeBrightnessFromPercent(percent: Int8, for display: Display) -> NSNumber {
        let percent = min(max(percent, 0), 100)
        return display.interpolate(
            value: Double(percent),
            span: 100.0,
            minVal: display.minBrightness.uint8Value,
            maxVal: display.maxBrightness.uint8Value,
            factor: datastore.defaults.interpolationFactor
        )
    }

    func setBrightnessPercent(value: Int8, for displays: [Display]? = nil) {
        if let displays = displays {
            displays.forEach({ display in
                display.brightness = computeBrightnessFromPercent(percent: value, for: display)
            })
        } else {
            self.displays.values.forEach({ display in
                display.brightness = computeBrightnessFromPercent(percent: value, for: display)
            })
        }
    }

    func computeContrastFromPercent(percent: Int8, for display: Display) -> NSNumber {
        let percent = min(max(percent, 0), 100)
        return display.interpolate(
            value: Double(percent),
            span: 100.0,
            minVal: display.minContrast.uint8Value,
            maxVal: display.maxContrast.uint8Value,
            factor: datastore.defaults.interpolationFactor
        )
    }

    func setContrastPercent(value: Int8, for displays: [Display]? = nil) {
        if let displays = displays {
            displays.forEach({ display in
                display.contrast = computeContrastFromPercent(percent: value, for: display)
            })
        } else {
            self.displays.values.forEach({ display in
                display.contrast = computeContrastFromPercent(percent: value, for: display)
            })
        }
    }

    func setBrightness(brightness: NSNumber, for displays: [Display]? = nil) {
        if let displays = displays {
            displays.forEach({ display in display.brightness = brightness })
        } else {
            self.displays.values.forEach({ display in display.brightness = brightness })
        }
    }

    func setContrast(contrast: NSNumber, for displays: [Display]? = nil) {
        if let displays = displays {
            displays.forEach({ display in display.contrast = contrast })
        } else {
            self.displays.values.forEach({ display in display.contrast = contrast })
        }
    }
}
