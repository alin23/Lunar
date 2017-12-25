//
//  Display.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import SwiftDate

let MIN_BRIGHTNESS: UInt8 = 0
let MAX_BRIGHTNESS: UInt8 = 100
let MIN_CONTRAST: UInt8 = 0
let MAX_CONTRAST: UInt8 = 100
let GENERIC_DISPLAY: Display = Display(id: 0, name: "No display")


class Display: NSManagedObject {
    @NSManaged var id: CGDirectDisplayID
    @NSManaged var name: String
    @NSManaged var minBrightness: NSNumber
    @NSManaged var maxBrightness: NSNumber
    @NSManaged var minContrast: NSNumber
    @NSManaged var maxContrast: NSNumber
    @NSManaged var adaptive: Bool
    
    var active: Bool = false
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let key = keyPath {
            switch key {
            case "minBrightness", "maxBrightness", "minContrast", "maxContrast":
                if adaptive && change![.newKey] as! NSNumber != change![.oldKey] as! NSNumber {
                    adapt(moment: brightnessAdapter.moment)
                }
            default:
                return
            }
        }
    }
    
    var brightness: UInt8 = MIN_BRIGHTNESS {
        didSet {
            let _ = DDC.setBrightness(for: self.id, brightness: min(max(brightness, minBrightness.uint8Value), maxBrightness.uint8Value))
        }
    }
    var contrast: UInt8 = MIN_CONTRAST{
        didSet {
            let _ = DDC.setContrast(for: self.id, contrast: min(max(contrast, minContrast.uint8Value), maxContrast.uint8Value))
        }
    }
    
    init(id: CGDirectDisplayID, name: String? = nil, active: Bool = false, minBrightness: UInt8 = MIN_BRIGHTNESS, maxBrightness: UInt8 = MAX_BRIGHTNESS, minContrast: UInt8 = MIN_CONTRAST, maxContrast: UInt8 = MAX_CONTRAST, context: NSManagedObjectContext? = nil) {
        let context = context ?? datastore.context
        let entity = NSEntityDescription.entity(forEntityName: "Display", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.id = id
        self.name = name ?? DDC.getDisplayName(for: id)
        self.active = active
        
        self.minBrightness = NSNumber(value: minBrightness)
        self.maxBrightness = NSNumber(value: maxBrightness)
        self.minContrast = NSNumber(value: minContrast)
        self.maxContrast = NSNumber(value: maxContrast)
        
        addObserver(self, forKeyPath: "minBrightness", options: [.new, .old], context: nil)
        addObserver(self, forKeyPath: "maxBrightness", options: [.new, .old], context: nil)
        addObserver(self, forKeyPath: "minContrast", options: [.new, .old], context: nil)
        addObserver(self, forKeyPath: "maxContrast", options: [.new, .old], context: nil)
    }
    
    func interpolate(value: UInt8, span: UInt8, min: UInt8, max: UInt8) -> UInt8 {
        return UInt8(min + ((value * (max - min)) / span))
    }
    
    func adapt(moment: Moment) {
        let now = DateInRegion()
        let minBrightness = self.minBrightness.uint8Value
        let maxBrightness = self.maxBrightness.uint8Value
        let minContrast = self.minContrast.uint8Value
        let maxContrast = self.maxContrast.uint8Value
        
        switch now {
        case moment.civilSunrise...moment.solarNoon:
            let firstHalfDayMinutes = UInt8((moment.solarNoon - moment.civilSunrise) / 60)
            let minutesSinceSunrise = UInt8((now - moment.civilSunrise) / 60)
            brightness = interpolate(value: minutesSinceSunrise, span: firstHalfDayMinutes, min: minBrightness, max: maxBrightness)
            contrast = interpolate(value: minutesSinceSunrise, span: firstHalfDayMinutes, min: minContrast, max: maxContrast)
        case moment.solarNoon...moment.civilSunset:
            let secondHalfDayMinutes = UInt8((moment.civilSunset - moment.solarNoon) / 60)
            let minutesSinceNoon = UInt8((now - moment.solarNoon) / 60)
            brightness = maxBrightness + minBrightness - interpolate(value: minutesSinceNoon, span: secondHalfDayMinutes, min: minBrightness, max: maxBrightness)
            contrast = maxContrast + minContrast - interpolate(value: minutesSinceNoon, span: secondHalfDayMinutes, min: minContrast, max: maxContrast)
        default:
            brightness = minBrightness
            contrast = minContrast
        }
    }
}
