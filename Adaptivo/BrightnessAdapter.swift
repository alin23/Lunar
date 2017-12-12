//
//  AdaptiveBrightness.swift
//  Adaptivo
//
//  Created by Alin on 02/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import CoreLocation
import SwiftDate
import Solar

class BrightnessAdapter  {
    var geolocation: Geolocation! {
        didSet {
            DataStore.saveGeolocation(geolocation: geolocation)
            fetchMoments()
        }
    }
    var moment: Moment! {
        didSet {
            DataStore.saveMoment(moment: moment)
            if running {
                adaptBrightness()
            }
        }
    }
    var displays: [CGDirectDisplayID: Display] = BrightnessAdapter.getDisplays() {
        didSet {
            DataStore.saveDisplays(displays: displays)
        }
    }
    var running: Bool = false {
        didSet {
            if running {
                activity.schedule { (completion) in
                    brightnessAdapter.adaptBrightness()
                    completion(NSBackgroundActivityScheduler.Result.finished)
                }
            } else {
                activity.invalidate()
            }
        }
    }
    
    private static func getDisplays() -> [CGDirectDisplayID: Display] {
        let displayIDs = Set(DDC.findExternalDisplays())
        if var displays = DataStore.loadDisplays() {
            let loadedDisplayIDs = Set(displays.keys)
            for id in loadedDisplayIDs.intersection(displayIDs) {
                displays[id]?.active = true
            }
            for id in displayIDs.subtracting(loadedDisplayIDs) {
                displays[id] = Display(id: id)
            }
            return displays
        }
        
        return Dictionary(uniqueKeysWithValues: displayIDs.map { (id) in (id, Display(id: id, active: true)) })
    }
    
    
    func interpolate(value: UInt, span: UInt, min: UInt, max: UInt) -> UInt8 {
        return UInt8(min + ((value * (max - min)) / span))
    }
    
    func getBrightnessContrast(minBrightness: UInt, maxBrightness: UInt, minContrast: UInt, maxContrast: UInt) -> (UInt8, UInt8) {
        let now = DateInRegion()
        
        if now >= moment.civilSunrise && now <= moment.solarNoon {
            let firstHalfDayMinutes = UInt((moment.solarNoon - moment.civilSunrise) / 60)
            let minutesSinceSunrise = UInt((now - moment.civilSunrise) / 60)
            let brightness = interpolate(value: minutesSinceSunrise, span: firstHalfDayMinutes, min: minBrightness, max: maxBrightness)
            let contrast = interpolate(value: minutesSinceSunrise, span: firstHalfDayMinutes, min: minContrast, max: maxContrast)
            return (brightness, contrast)
        }
        
        if now >= moment.solarNoon && now <= moment.civilSunset {
            let secondHalfDayMinutes = UInt((moment.civilSunset - moment.solarNoon) / 60)
            let minutesSinceNoon = UInt((now - moment.solarNoon) / 60)
            let brightness = UInt8(maxBrightness + minBrightness) - interpolate(value: minutesSinceNoon, span: secondHalfDayMinutes, min: minBrightness, max: maxBrightness)
            let contrast = UInt8(maxContrast + minContrast) - interpolate(value: minutesSinceNoon, span: secondHalfDayMinutes, min: minContrast, max: maxContrast)
            return (brightness, contrast)
        }
        
        return (UInt8(minBrightness), UInt8(minContrast))
    }
    
    func fetchMoments() {
        if let solar = Solar(coordinate: self.geolocation.coordinate) {
            self.moment = Moment(solar)
            return
        }
        if let moment = DataStore.loadMoment() {
            if moment.solarNoon.isToday {
                self.moment = moment
                return
            }
        }
        
        Alamofire.request("https://api.sunrise-sunset.org/json?lat=\(geolocation.latitude)&lng=\(geolocation.longitude)&date=today&formatted=0").validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                if json["status"].string == "OK" {
                    self.moment = Moment(result: json["results"].dictionaryValue)
                } else {
                    log.error("Sunrise API status: \(json["status"].string ?? "null")")
                }
            case .failure(let error):
                log.error("Sunrise API error: \(error)")
            }
        }
    }
    
    func fetchGeolocation() {
        if let geolocation = DataStore.loadGeolocation() {
            self.geolocation = geolocation
            return
        }
        
        Alamofire.request("https://freegeoip.net/json").validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                let geolocation = Geolocation(result: json)
                self.geolocation = geolocation
            case .failure(let error):
                log.error("IP Geolocation error: \(error)")
            }
        }
    }
    
    func adaptBrightness() {
        if moment == nil {
            log.warning("Day moments aren't fetched yet")
            return
        }
        for display in displays.values {
            let (brightness, contrast) = getBrightnessContrast(
                minBrightness: UInt(display.minBrightness),
                maxBrightness: UInt(display.maxBrightness),
                minContrast: UInt(display.minContrast),
                maxContrast: UInt(display.maxContrast)
            )
            
            display.brightness = brightness
            log.debug("Set brightness to \(brightness) for display \(display.name)")
            
            display.contrast = contrast
            log.debug("Set contrast to \(contrast) for display \(display.name)")
        }
    }
}

