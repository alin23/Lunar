//
//  Moment.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Solar
import SwiftDate
import SwiftyJSON

class Moment: NSObject, NSCoding {
    let sunrise: DateInRegion
    let sunset: DateInRegion
    let solarNoon: DateInRegion
    let dayLength: UInt64
    let civilSunrise: DateInRegion
    let civilSunset: DateInRegion
    let nauticalSunrise: DateInRegion
    let nauticalSunset: DateInRegion
    let astronomicalSunrise: DateInRegion
    let astronomicalSunset: DateInRegion

    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("moments")

    init(_ solar: Solar) {
        let sevenAM = DateInRegion().startOf(component: .day).atTime(hour: 7, minute: 0, second: 0)?.absoluteDate
        let noon = DateInRegion().startOf(component: .day).atTime(hour: 12, minute: 0, second: 0)?.absoluteDate
        let sevenPM = DateInRegion().startOf(component: .day).atTime(hour: 19, minute: 0, second: 0)?.absoluteDate

        sunrise = DateInRegion(absoluteDate: solar.sunrise ?? sevenAM!, in: Region.Local())
        sunset = DateInRegion(absoluteDate: solar.sunset ?? sevenPM!, in: Region.Local())
        solarNoon = DateInRegion(absoluteDate: solar.solarNoon ?? noon!, in: Region.Local())
        dayLength = UInt64(solar.sunset! - solar.sunset!)
        civilSunrise = DateInRegion(absoluteDate: solar.civilSunrise ?? sevenAM!, in: Region.Local())
        civilSunset = DateInRegion(absoluteDate: solar.civilSunset ?? sevenPM!, in: Region.Local())
        nauticalSunrise = DateInRegion(absoluteDate: solar.nauticalSunrise ?? sevenAM!, in: Region.Local())
        nauticalSunset = DateInRegion(absoluteDate: solar.nauticalSunset ?? sevenPM!, in: Region.Local())
        astronomicalSunrise = DateInRegion(absoluteDate: solar.astronomicalSunrise ?? sevenAM!, in: Region.Local())
        astronomicalSunset = DateInRegion(absoluteDate: solar.astronomicalSunset ?? sevenPM!, in: Region.Local())
    }

    init(result: [String: JSON]) {
        let localTime = { (key: String) in DateInRegion(
            string: result[key]!.stringValue,
            format: .iso8601(options: .withInternetDateTime)
        )!.toRegion(Region.Local())
        }

        sunrise = localTime("sunrise")
        sunset = localTime("sunset")
        solarNoon = localTime("solar_noon")
        dayLength = result["day_length"]!.uInt64Value
        civilSunrise = localTime("civil_twilight_begin")
        civilSunset = localTime("civil_twilight_end")
        nauticalSunrise = localTime("nautical_twilight_begin")
        nauticalSunset = localTime("nautical_twilight_end")
        astronomicalSunrise = localTime("astronomical_twilight_begin")
        astronomicalSunset = localTime("astronomical_twilight_end")
    }

    // MARK: UserDefaults

    init?(defaults: UserDefaults = datastore.defaults) {
        let localTime = { (iso: String) in DateInRegion(
            string: iso,
            format: .iso8601Auto
        )!.toRegion(Region.Local())
        }

        guard let sunrise = defaults.string(forKey: "sunrise"),
            let sunset = defaults.string(forKey: "sunset"),
            let solarNoon = defaults.string(forKey: "solar_noon"),
            let civilTwilightBegin = defaults.string(forKey: "civil_twilight_begin"),
            let civilTwilightEnd = defaults.string(forKey: "civil_twilight_end"),
            let nauticalTwilightBegin = defaults.string(forKey: "nautical_twilight_begin"),
            let nauticalTwilightEnd = defaults.string(forKey: "nautical_twilight_end"),
            let astronomicalTwilightBegin = defaults.string(forKey: "astronomical_twilight_begin"),
            let astronomicalTwilightEnd = defaults.string(forKey: "astronomical_twilight_end") else {
            log.error("Unable to decode moment.")
            return nil
        }

        self.sunrise = localTime(sunrise)
        self.sunset = localTime(sunset)
        self.solarNoon = localTime(solarNoon)
        dayLength = UInt64(defaults.integer(forKey: "day_length"))
        civilSunrise = localTime(civilTwilightBegin)
        civilSunset = localTime(civilTwilightEnd)
        nauticalSunrise = localTime(nauticalTwilightBegin)
        nauticalSunset = localTime(nauticalTwilightEnd)
        astronomicalSunrise = localTime(astronomicalTwilightBegin)
        astronomicalSunset = localTime(astronomicalTwilightEnd)
    }

    func store() {
        datastore.defaults.set(sunrise.iso8601(), forKey: "sunrise")
        datastore.defaults.set(sunset.iso8601(), forKey: "sunset")
        datastore.defaults.set(solarNoon.iso8601(), forKey: "solar_noon")
        datastore.defaults.set(dayLength, forKey: "day_length")
        datastore.defaults.set(civilSunrise.iso8601(), forKey: "civil_twilight_begin")
        datastore.defaults.set(civilSunset.iso8601(), forKey: "civil_twilight_end")
        datastore.defaults.set(nauticalSunrise.iso8601(), forKey: "nautical_twilight_begin")
        datastore.defaults.set(nauticalSunset.iso8601(), forKey: "nautical_twilight_end")
        datastore.defaults.set(astronomicalSunrise.iso8601(), forKey: "astronomical_twilight_begin")
        datastore.defaults.set(astronomicalSunset.iso8601(), forKey: "astronomical_twilight_end")
    }

    // MARK: NSCoding

    func encode(with aCoder: NSCoder) {
        aCoder.encode(sunrise.iso8601(), forKey: "sunrise")
        aCoder.encode(sunset.iso8601(), forKey: "sunset")
        aCoder.encode(solarNoon.iso8601(), forKey: "solar_noon")
        aCoder.encode(dayLength, forKey: "day_length")
        aCoder.encode(civilSunrise.iso8601(), forKey: "civil_twilight_begin")
        aCoder.encode(civilSunset.iso8601(), forKey: "civil_twilight_end")
        aCoder.encode(nauticalSunrise.iso8601(), forKey: "nautical_twilight_begin")
        aCoder.encode(nauticalSunset.iso8601(), forKey: "nautical_twilight_end")
        aCoder.encode(astronomicalSunrise.iso8601(), forKey: "astronomical_twilight_begin")
        aCoder.encode(astronomicalSunset.iso8601(), forKey: "astronomical_twilight_end")
    }

    required init?(coder aDecoder: NSCoder) {
        let localTime = { (iso: String) in DateInRegion(
            string: iso,
            format: .iso8601Auto
        )!.toRegion(Region.Local())
        }

        guard let sunrise = aDecoder.decodeObject(forKey: "sunrise") as? String,
            let sunset = aDecoder.decodeObject(forKey: "sunset") as? String,
            let solarNoon = aDecoder.decodeObject(forKey: "solar_noon") as? String,
            let civilTwilightBegin = aDecoder.decodeObject(forKey: "civil_twilight_begin") as? String,
            let civilTwilightEnd = aDecoder.decodeObject(forKey: "civil_twilight_end") as? String,
            let nauticalTwilightBegin = aDecoder.decodeObject(forKey: "nautical_twilight_begin") as? String,
            let nauticalTwilightEnd = aDecoder.decodeObject(forKey: "nautical_twilight_end") as? String,
            let astronomicalTwilightBegin = aDecoder.decodeObject(forKey: "astronomical_twilight_begin") as? String,
            let astronomicalTwilightEnd = aDecoder.decodeObject(forKey: "astronomical_twilight_end") as? String else {
            log.error("Unable to decode moment.")
            return nil
        }

        self.sunrise = localTime(sunrise)
        self.sunset = localTime(sunset)
        self.solarNoon = localTime(solarNoon)
        dayLength = UInt64(aDecoder.decodeInt64(forKey: "day_length"))
        civilSunrise = localTime(civilTwilightBegin)
        civilSunset = localTime(civilTwilightEnd)
        nauticalSunrise = localTime(nauticalTwilightBegin)
        nauticalSunset = localTime(nauticalTwilightEnd)
        astronomicalSunrise = localTime(astronomicalTwilightBegin)
        astronomicalSunset = localTime(astronomicalTwilightEnd)
    }

    func serialize() {
        if NSKeyedArchiver.archiveRootObject(self, toFile: Moment.ArchiveURL.path) {
            log.info("Saved moment data to \(Moment.ArchiveURL.path)")
        } else {
            log.error("Failed to save moment data to \(Moment.ArchiveURL.path)")
        }
    }

    static func deserialize() -> Moment? {
        return NSKeyedUnarchiver.unarchiveObject(withFile: Moment.ArchiveURL.path) as? Moment
    }
}
