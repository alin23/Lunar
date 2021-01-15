//
//  LocationMode.swift
//  Lunar
//
//  Created by Alin Panaitiu on 30.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Alamofire
import Defaults
import Foundation
import Solar
import SwiftDate
import SwiftyJSON

class LocationMode: AdaptiveMode {
    var key = AdaptiveModeKey.location

    var available: Bool { LocationMode.moment != nil }

    static var geolocation: Geolocation? {
        didSet {
            fetchMoments()
        }
    }

    static var _moment: Moment?
    static var moment: Moment? {
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

    var timer: Timer?

    static func fetchMoments() {
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
            AF
                .request(
                    "https://api.sunrise-sunset.org/json?lat=\(geolocation.latitude)&lng=\(geolocation.longitude)&date=today&formatted=0"
                )
                .validate().responseJSON { response in
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
    }

    static func fetchGeolocation() {
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

    func getBrightnessContrast(
        display: Display,
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
        guard let moment = LocationMode.moment else { return (NSNumber(value: minBrightness ?? 0), NSNumber(value: minContrast ?? 0)) }

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
        let minBrightness = minBrightness ?? display.minBrightness.uint8Value
        let maxBrightness = maxBrightness ?? display.maxBrightness.uint8Value
        let minContrast = minContrast ?? display.minContrast.uint8Value
        let maxContrast = maxContrast ?? display.maxContrast.uint8Value
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
            newBrightness = display.computeValue(
                from: percent, type: .brightness,
                factor: factor ?? Defaults[.curveFactor], appOffset: appBrightnessOffset,
                minVal: Double(minBrightness), maxVal: Double(maxBrightness)
            )
            newContrast = display.computeValue(
                from: percent, type: .contrast,
                factor: factor ?? Defaults[.curveFactor], appOffset: appContrastOffset,
                minVal: Double(minContrast), maxVal: Double(maxContrast)
            )
        case noonEnd ... daylightEnd:
            let secondHalfDayMinutes = ((daylightEnd - noonEnd) / seconds)
            let minutesSinceNoon = ((now - noonEnd) / seconds)
            let percent = ((secondHalfDayMinutes - minutesSinceNoon) / secondHalfDayMinutes)
            newBrightness = display.computeValue(
                from: percent, type: .brightness,
                factor: factor ?? Defaults[.curveFactor], appOffset: appBrightnessOffset,
                minVal: Double(minBrightness), maxVal: Double(maxBrightness)
            )
            newContrast = display.computeValue(
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

    func stopWatching() {
        timer?.invalidate()
    }

    func watch() -> Bool {
        guard !(timer?.isValid ?? false) else {
            return true
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.minutes.timeInterval, repeats: true, block: {
            _ in
            displayController.onAdapt?(LocationMode.moment as Any)
            displayController.activeDisplays.values.forEach(self.adapt)
        })
        return true
    }

    func computeBrightnessContrast(display: Display) -> (UInt8, UInt8) {
        let (brightness, contrast) = getBrightnessContrast(
            display: display,
            appBrightnessOffset: displayController.appBrightnessOffset,
            appContrastOffset: displayController.appContrastOffset
        )

        return (brightness.uint8Value, contrast.uint8Value)
    }

    func adapt(_ display: Display) {
        if LocationMode.moment == nil || !display.adaptive {
            return
        }

        let (brightness, contrast) = computeBrightnessContrast(display: display)

        display.brightness = brightness.ns
        display.contrast = contrast.ns
    }
}
