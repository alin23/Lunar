//
//  LunarBrightness.swift
//  Lunar
//
//  Created by Alin on 02/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Foundation
import Alamofire
import SwiftyJSON
import CoreLocation
import SwiftDate
import Solar

class BrightnessAdapter  {
    var geolocation: Geolocation! {
        didSet {
            geolocation.store()
            fetchMoments()
        }
    }
    var _moment: Moment!
    var moment: Moment! {
        get {
            if !_moment.solarNoon.isToday {
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
    var running: Bool = datastore.defaults.bool(forKey: "adaptiveBrightnessEnabled") {
        didSet {
            datastore.defaults.set(running, forKey: "adaptiveBrightnessEnabled")
            if running {
                log.debug("Started BrightnessAdapter")
                brightnessAdapter.adaptBrightness()
                activity.schedule { (completion) in
                    brightnessAdapter.adaptBrightness()
                    completion(NSBackgroundActivityScheduler.Result.finished)
                }
            } else {
                log.debug("Paused BrightnessAdapter")
                activity.invalidate()
            }
        }
    }
    
    func toggle() -> Bool {
        running = !running
        return running
    }
    
    func resetDisplayList() {
        for display in displays.values {
            display.removeObservers()
        }
        displays = BrightnessAdapter.getDisplays()
    }
    
    private static func getDisplays() -> [CGDirectDisplayID: Display] {
        var displays: [CGDirectDisplayID: Display]
        let displayIDs = Set(DDC.findExternalDisplays())
        
        do {
            let fetchRequest = NSFetchRequest<Display>(entityName: "Display")
            fetchRequest.predicate = NSPredicate(format: "id IN %@", displayIDs)
            let displayList = try datastore.context.fetch(fetchRequest)
            displays = Dictionary(uniqueKeysWithValues: displayList.map {
                (d) -> (CGDirectDisplayID, Display) in (d.id, d)
            })
            let loadedDisplayIDs = Set(displays.keys)
            for id in loadedDisplayIDs.intersection(displayIDs) {
                if let display = displays[id] {
                    display.active = true
                    display.resetName()
                    display.addObservers()
                }
            }
            for id in displayIDs.subtracting(loadedDisplayIDs) {
                displays[id] = Display(id: id)
            }
            datastore.save()
            return displays
        } catch {
            log.error("Error on fetching displays: \(error)")
            displays = Dictionary(uniqueKeysWithValues: displayIDs.map { (id) in (id, Display(id: id, active: true)) })
        }
        datastore.save()
        return displays
    }
    
    func fetchMoments() {
        if let solar = Solar(coordinate: self.geolocation.coordinate) {
            self.moment = Moment(solar)
            return
        }
        if let moment = Moment() {
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
        if let geolocation = Geolocation() {
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
    
    func adaptBrightness(for displays: [Display]? = nil) {
        if moment == nil {
            log.warning("Day moments aren't fetched yet")
            return
        }
        if let displays = displays {
            displays.forEach({ (display) in display.adapt(moment: moment) })
        } else {
            self.displays.values.forEach({(display) in display.adapt(moment: moment)})
        }
    }
}

