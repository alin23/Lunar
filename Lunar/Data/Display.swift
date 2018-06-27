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
let GENERIC_DISPLAY_ID: CGDirectDisplayID = 0
let GENERIC_DISPLAY: Display = Display(id: GENERIC_DISPLAY_ID, serial: "GENERIC_SERIAL", name: "No Display", minBrightness: 0, maxBrightness: 100, minContrast: 0, maxContrast: 100, context: datastore.container.newBackgroundContext())

class Display: NSManagedObject {
    @NSManaged var id: CGDirectDisplayID
    @NSManaged var serial: String
    @NSManaged var name: String
    @NSManaged var adaptive: Bool

    @NSManaged var minBrightness: NSNumber
    @NSManaged var maxBrightness: NSNumber

    @NSManaged var minContrast: NSNumber
    @NSManaged var maxContrast: NSNumber

    @NSManaged var brightness: NSNumber
    @NSManaged var contrast: NSNumber

    var active: Bool = false
    var observers: [NSKeyValueObservation] = []
    var onReadapt: (() -> Void)?

    convenience init(id: CGDirectDisplayID, serial: String? = nil, name: String? = nil, active: Bool = false, minBrightness: UInt8 = MIN_BRIGHTNESS, maxBrightness: UInt8 = MAX_BRIGHTNESS, minContrast: UInt8 = MIN_CONTRAST, maxContrast: UInt8 = MAX_CONTRAST, context: NSManagedObjectContext? = nil) {
        let context = context ?? datastore.context
        let entity = NSEntityDescription.entity(forEntityName: "Display", in: context)!
        self.init(entity: entity, insertInto: context)

        self.id = id
        if let name = name, !name.isEmpty {
            self.name = name
        } else {
            self.name = DDC.getDisplayName(for: id)
        }
        self.serial = serial ?? DDC.getDisplaySerial(for: id)
        self.active = active
        if id != GENERIC_DISPLAY_ID {
            self.minBrightness = NSNumber(value: minBrightness)
            self.maxBrightness = NSNumber(value: maxBrightness)
            self.minContrast = NSNumber(value: minContrast)
            self.maxContrast = NSNumber(value: maxContrast)
        }
    }

    func resetName() {
        name = DDC.getDisplayName(for: id)
    }

    func readapt<T>(display: Display, change: NSKeyValueObservedChange<T>) {
        if let readaptListener = onReadapt {
            readaptListener()
        }
        if display.adaptive && change.newValue as! NSNumber != change.oldValue as! NSNumber {
            display.adapt(moment: brightnessAdapter.moment)
        }
    }

    func addObservers() {
        observers = [
            observe(\.minBrightness, options: [.new, .old], changeHandler: readapt),
            observe(\.maxBrightness, options: [.new, .old], changeHandler: readapt),
            observe(\.minContrast, options: [.new, .old], changeHandler: readapt),
            observe(\.maxContrast, options: [.new, .old], changeHandler: readapt),
            observe(\.brightness, options: [.new], changeHandler: { _, change in
                let newBrightness = min(max(change.newValue!.uint8Value, self.minBrightness.uint8Value), self.maxBrightness.uint8Value)
                _ = DDC.setBrightness(for: self.id, brightness: newBrightness)
                log.debug("\(self.name): Set brightness to \(newBrightness)")
            }),
            observe(\.contrast, options: [.new], changeHandler: { _, change in
                let newContrast = min(max(change.newValue!.uint8Value, self.minContrast.uint8Value), self.maxContrast.uint8Value)
                _ = DDC.setContrast(for: self.id, contrast: newContrast)
                log.debug("\(self.name): Set contrast to \(newContrast)")
            }),
        ]
    }

    func removeObservers() {
        observers.removeAll(keepingCapacity: true)
    }

    func interpolate(value: Double, span: Double, min: UInt8, max: UInt8, factor: Double) -> NSNumber {
        let maxValue = Double(max)
        let minValue = Double(min)
        let valueSpan = maxValue - minValue
        var interpolated = ((value * valueSpan) / span)
        let normalized = interpolated / valueSpan
        interpolated = minValue + pow(normalized, factor) * valueSpan
        return NSNumber(value: UInt8(interpolated))
    }

    func getBrightnessContrast(
        moment: Moment,
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
        var now = DateInRegion()
        if let hour = hour {
            now = now.atTime(hour: hour, minute: minute, second: 0)!
        }
        let seconds = 60.0
        let minBrightness = minBrightness ?? self.minBrightness.uint8Value
        let maxBrightness = maxBrightness ?? self.maxBrightness.uint8Value
        let minContrast = minContrast ?? self.minContrast.uint8Value
        let maxContrast = maxContrast ?? self.maxContrast.uint8Value
        var newBrightness = NSNumber(value: minBrightness)
        var newContrast = NSNumber(value: minContrast)
        let interpolationFactor = datastore.defaults.interpolationFactor
        let daylightExtension = daylightExtension ?? datastore.defaults.daylightExtensionMinutes
        let noonDuration = noonDuration ?? datastore.defaults.noonDurationMinutes

        let daylightStart = moment.civilSunrise - daylightExtension.minutes
        let daylightEnd = moment.civilSunset + daylightExtension.minutes

        let noonStart = moment.solarNoon - (noonDuration / 2).minutes
        let noonEnd = moment.solarNoon + (noonDuration / 2).minutes

        switch now {
        case daylightStart ... noonStart:
            let firstHalfDayMinutes = ((noonStart - daylightStart) / seconds)
            let minutesSinceSunrise = ((now - daylightStart) / seconds)
            newBrightness = interpolate(value: minutesSinceSunrise, span: firstHalfDayMinutes, min: minBrightness, max: maxBrightness, factor: 1 / interpolationFactor)
            newContrast = interpolate(value: minutesSinceSunrise, span: firstHalfDayMinutes, min: minContrast, max: maxContrast, factor: 1 / interpolationFactor)
        case noonEnd ... daylightEnd:
            let secondHalfDayMinutes = ((daylightEnd - noonEnd) / seconds)
            let minutesSinceNoon = ((now - noonEnd) / seconds)
            let interpolatedBrightness = interpolate(value: minutesSinceNoon, span: secondHalfDayMinutes, min: minBrightness, max: maxBrightness, factor: interpolationFactor)
            let interpolatedContrast = interpolate(value: minutesSinceNoon, span: secondHalfDayMinutes, min: minContrast, max: maxContrast, factor: interpolationFactor)
            newBrightness = NSNumber(value: maxBrightness + minBrightness - interpolatedBrightness.uint8Value)
            newContrast = NSNumber(value: maxContrast + minContrast - interpolatedContrast.uint8Value)
        case noonStart ... noonEnd:
            newBrightness = NSNumber(value: maxBrightness)
            newContrast = NSNumber(value: maxContrast)
        default:
            newBrightness = NSNumber(value: minBrightness)
            newContrast = NSNumber(value: minContrast)
        }

        if brightnessOffset > 0 {
            newBrightness = NSNumber(value: min(newBrightness.intValue + brightnessOffset, Int(MAX_BRIGHTNESS)))
        }
        if contrastOffset > 0 {
            newContrast = NSNumber(value: min(newContrast.intValue + contrastOffset, Int(MAX_CONTRAST)))
        }
        return (newBrightness, newContrast)
    }

    func adapt(moment: Moment, app: AppException? = nil) {
        let (newBrightness, newContrast) = getBrightnessContrast(moment: moment, brightnessOffset: app?.brightness.intValue ?? 0, contrastOffset: app?.contrast.intValue ?? 0)
        setValue(newBrightness, forKey: "brightness")
        setValue(newContrast, forKey: "contrast")
        log.info("\n\(name):\n\tBrightness: \(newBrightness)\n\tContrast: \(newContrast)")
        datastore.save(context: managedObjectContext!)
    }
}
