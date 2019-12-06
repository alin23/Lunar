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

    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first
    static let ArchiveURL = DocumentsDirectory?.appendingPathComponent("moments")

    static func defaultMoments() -> (DateInRegion, DateInRegion, DateInRegion) {
        guard let sevenAM = DateInRegion().convertTo(region: Region.local).dateBySet(hour: 7, min: 0, secs: 0),
            let noon = DateInRegion().convertTo(region: Region.local).dateBySet(hour: 12, min: 0, secs: 0),
            let sevenPM = DateInRegion().convertTo(region: Region.local).dateBySet(hour: 19, min: 0, secs: 0) else {
            let today = Date.nowAt(.startOfDay)
            return (
                DateInRegion(Date(year: today.year, month: today.month, day: today.day, hour: 7, minute: 0, second: 0, nanosecond: 0, region: Region.local), region: Region.local),
                DateInRegion(Date(year: today.year, month: today.month, day: today.day, hour: 12, minute: 0, second: 0, nanosecond: 0, region: Region.local), region: Region.local),
                DateInRegion(Date(year: today.year, month: today.month, day: today.day, hour: 19, minute: 0, second: 0, nanosecond: 0, region: Region.local), region: Region.local)
            )
        }

        return (sevenAM, noon, sevenPM)
    }

    static func defaultMomentsAsDates() -> (Date, Date, Date) {
        let (sevenAM, noon, sevenPM) = defaultMoments()
        return (
            sevenAM.date,
            noon.date,
            sevenPM.date
        )
    }

    init(_ solar: Solar) {
        let (sevenAM, noon, sevenPM) = Moment.defaultMomentsAsDates()

        sunrise = DateInRegion(solar.sunrise ?? sevenAM, region: Region.local)
        sunset = DateInRegion(solar.sunset ?? sevenPM, region: Region.local)
        solarNoon = DateInRegion(solar.solarNoon ?? noon, region: Region.local)
        dayLength = UInt64(sunset - sunrise)
        civilSunrise = DateInRegion(solar.civilSunrise ?? sevenAM, region: Region.local)
        civilSunset = DateInRegion(solar.civilSunset ?? sevenPM, region: Region.local)
        nauticalSunrise = DateInRegion(solar.nauticalSunrise ?? sevenAM, region: Region.local)
        nauticalSunset = DateInRegion(solar.nauticalSunset ?? sevenPM, region: Region.local)
        astronomicalSunrise = DateInRegion(solar.astronomicalSunrise ?? sevenAM, region: Region.local)
        astronomicalSunset = DateInRegion(solar.astronomicalSunset ?? sevenPM, region: Region.local)
    }

    init(result: [String: JSON]) {
        let (sevenAM, noon, sevenPM) = Moment.defaultMoments()

        let localTime = { (key: String) -> DateInRegion? in
            let strDate = result[key]?.stringValue
            return strDate?.toDate()?.convertTo(region: Region.local)
        }

        sunrise = localTime("sunrise") ?? sevenAM
        sunset = localTime("sunset") ?? sevenPM
        solarNoon = localTime("solar_noon") ?? noon
        let length = result["day_length"]?.uInt64Value ?? 0
        if length == 0 {
            dayLength = UInt64((localTime("sunset") ?? sevenPM) - (localTime("sunrise") ?? sevenAM))
        } else {
            dayLength = length
        }
        civilSunrise = localTime("civil_twilight_begin") ?? sevenAM
        civilSunset = localTime("civil_twilight_end") ?? sevenPM
        nauticalSunrise = localTime("nautical_twilight_begin") ?? sevenAM
        nauticalSunset = localTime("nautical_twilight_end") ?? sevenPM
        astronomicalSunrise = localTime("astronomical_twilight_begin") ?? sevenAM
        astronomicalSunset = localTime("astronomical_twilight_end") ?? sevenPM
    }

    // MARK: UserDefaults

    init?(defaults: UserDefaults = datastore.defaults) {
        let (sevenAM, noon, sevenPM) = Moment.defaultMoments()

        let localTime = { (iso: String) -> DateInRegion? in
            iso.toDate()?.convertTo(region: Region.local)
        }

        guard let sunrise = defaults.string(forKey: "sunrise"),
            let sunset = defaults.string(forKey: "sunset"),
            let solarNoon = defaults.string(forKey: "solarNoon"),
            let civilTwilightBegin = defaults.string(forKey: "civilTwilightBegin"),
            let civilTwilightEnd = defaults.string(forKey: "civilTwilightEnd"),
            let nauticalTwilightBegin = defaults.string(forKey: "nauticalTwilightBegin"),
            let nauticalTwilightEnd = defaults.string(forKey: "nauticalTwilightEnd"),
            let astronomicalTwilightBegin = defaults.string(forKey: "astronomicalTwilightBegin"),
            let astronomicalTwilightEnd = defaults.string(forKey: "astronomicalTwilightEnd") else {
            log.error("Unable to decode moment.")
            return nil
        }

        self.sunrise = localTime(sunrise) ?? sevenAM
        self.sunset = localTime(sunset) ?? sevenPM
        self.solarNoon = localTime(solarNoon) ?? noon
        let length = UInt64(defaults.integer(forKey: "dayLength"))
        if length == 0 {
            dayLength = UInt64(self.sunset - self.sunrise)
        } else {
            dayLength = length
        }
        civilSunrise = localTime(civilTwilightBegin) ?? sevenAM
        civilSunset = localTime(civilTwilightEnd) ?? sevenPM
        nauticalSunrise = localTime(nauticalTwilightBegin) ?? sevenAM
        nauticalSunset = localTime(nauticalTwilightEnd) ?? sevenPM
        astronomicalSunrise = localTime(astronomicalTwilightBegin) ?? sevenAM
        astronomicalSunset = localTime(astronomicalTwilightEnd) ?? sevenPM
    }

    func store() {
        datastore.defaults.set(sunrise.toISO(), forKey: "sunrise")
        datastore.defaults.set(sunset.toISO(), forKey: "sunset")
        datastore.defaults.set(solarNoon.toISO(), forKey: "solarNoon")
        datastore.defaults.set(dayLength, forKey: "dayLength")
        datastore.defaults.set(civilSunrise.toISO(), forKey: "civilTwilightBegin")
        datastore.defaults.set(civilSunset.toISO(), forKey: "civilTwilightEnd")
        datastore.defaults.set(nauticalSunrise.toISO(), forKey: "nauticalTwilightBegin")
        datastore.defaults.set(nauticalSunset.toISO(), forKey: "nauticalTwilightEnd")
        datastore.defaults.set(astronomicalSunrise.toISO(), forKey: "astronomicalTwilightBegin")
        datastore.defaults.set(astronomicalSunset.toISO(), forKey: "astronomicalTwilightEnd")
    }

    // MARK: NSCoding

    func encode(with aCoder: NSCoder) {
        aCoder.encode(sunrise.toISO(), forKey: "sunrise")
        aCoder.encode(sunset.toISO(), forKey: "sunset")
        aCoder.encode(solarNoon.toISO(), forKey: "solarNoon")
        aCoder.encode(dayLength, forKey: "dayLength")
        aCoder.encode(civilSunrise.toISO(), forKey: "civilTwilightBegin")
        aCoder.encode(civilSunset.toISO(), forKey: "civilTwilightEnd")
        aCoder.encode(nauticalSunrise.toISO(), forKey: "nauticalTwilightBegin")
        aCoder.encode(nauticalSunset.toISO(), forKey: "nauticalTwilightEnd")
        aCoder.encode(astronomicalSunrise.toISO(), forKey: "astronomicalTwilightBegin")
        aCoder.encode(astronomicalSunset.toISO(), forKey: "astronomicalTwilightEnd")
    }

    required init?(coder aDecoder: NSCoder) {
        let (sevenAM, noon, sevenPM) = Moment.defaultMoments()

        let localTime = { (iso: String) -> DateInRegion? in
            iso.toDate()?.convertTo(region: Region.local)
        }

        guard let sunrise = aDecoder.decodeObject(forKey: "sunrise") as? String,
            let sunset = aDecoder.decodeObject(forKey: "sunset") as? String,
            let solarNoon = aDecoder.decodeObject(forKey: "solarNoon") as? String,
            let civilTwilightBegin = aDecoder.decodeObject(forKey: "civilTwilightBegin") as? String,
            let civilTwilightEnd = aDecoder.decodeObject(forKey: "civilTwilightEnd") as? String,
            let nauticalTwilightBegin = aDecoder.decodeObject(forKey: "nauticalTwilightBegin") as? String,
            let nauticalTwilightEnd = aDecoder.decodeObject(forKey: "nauticalTwilightEnd") as? String,
            let astronomicalTwilightBegin = aDecoder.decodeObject(forKey: "astronomicalTwilightBegin") as? String,
            let astronomicalTwilightEnd = aDecoder.decodeObject(forKey: "astronomicalTwilightEnd") as? String else {
            log.error("Unable to decode moment.")
            return nil
        }

        self.sunrise = localTime(sunrise) ?? sevenAM
        self.sunset = localTime(sunset) ?? sevenPM
        self.solarNoon = localTime(solarNoon) ?? noon
        let length = UInt64(aDecoder.decodeInt64(forKey: "dayLength"))
        if length == 0 {
            dayLength = UInt64(self.sunset - self.sunrise)
        } else {
            dayLength = length
        }
        civilSunrise = localTime(civilTwilightBegin) ?? sevenAM
        civilSunset = localTime(civilTwilightEnd) ?? sevenPM
        nauticalSunrise = localTime(nauticalTwilightBegin) ?? sevenAM
        nauticalSunset = localTime(nauticalTwilightEnd) ?? sevenPM
        astronomicalSunrise = localTime(astronomicalTwilightBegin) ?? sevenAM
        astronomicalSunset = localTime(astronomicalTwilightEnd) ?? sevenPM
    }

    func serialize() {
        if let archiveURL = Moment.ArchiveURL {
            if NSKeyedArchiver.archiveRootObject(self, toFile: archiveURL.path) {
                log.info("Saved moment data to \(archiveURL.path)")
            } else {
                log.error("Failed to save moment data to \(archiveURL.path)")
            }
        }
    }

    static func deserialize() -> Moment? {
        if let archiveURL = Moment.ArchiveURL {
            return NSKeyedUnarchiver.unarchiveObject(withFile: archiveURL.path) as? Moment
        }
        return nil
    }
}
