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

    static func defaultMoments() -> (DateInRegion, DateInRegion, DateInRegion) {
        let sevenAM = DateInRegion().convertTo(region: Region.local).dateBySet(hour: 7, min: 0, secs: 0)!
        let noon = DateInRegion().convertTo(region: Region.local).dateBySet(hour: 12, min: 0, secs: 0)!
        let sevenPM = DateInRegion().convertTo(region: Region.local).dateBySet(hour: 19, min: 0, secs: 0)!

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
        dayLength = UInt64((sunset - sunset).timeInterval)
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
        dayLength = result["day_length"]!.uInt64Value
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

        self.sunrise = localTime(sunrise) ?? sevenAM
        self.sunset = localTime(sunset) ?? sevenPM
        self.solarNoon = localTime(solarNoon) ?? noon
        dayLength = UInt64(defaults.integer(forKey: "day_length"))
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
        datastore.defaults.set(solarNoon.toISO(), forKey: "solar_noon")
        datastore.defaults.set(dayLength, forKey: "day_length")
        datastore.defaults.set(civilSunrise.toISO(), forKey: "civil_twilight_begin")
        datastore.defaults.set(civilSunset.toISO(), forKey: "civil_twilight_end")
        datastore.defaults.set(nauticalSunrise.toISO(), forKey: "nautical_twilight_begin")
        datastore.defaults.set(nauticalSunset.toISO(), forKey: "nautical_twilight_end")
        datastore.defaults.set(astronomicalSunrise.toISO(), forKey: "astronomical_twilight_begin")
        datastore.defaults.set(astronomicalSunset.toISO(), forKey: "astronomical_twilight_end")
    }

    // MARK: NSCoding

    func encode(with aCoder: NSCoder) {
        aCoder.encode(sunrise.toISO(), forKey: "sunrise")
        aCoder.encode(sunset.toISO(), forKey: "sunset")
        aCoder.encode(solarNoon.toISO(), forKey: "solar_noon")
        aCoder.encode(dayLength, forKey: "day_length")
        aCoder.encode(civilSunrise.toISO(), forKey: "civil_twilight_begin")
        aCoder.encode(civilSunset.toISO(), forKey: "civil_twilight_end")
        aCoder.encode(nauticalSunrise.toISO(), forKey: "nautical_twilight_begin")
        aCoder.encode(nauticalSunset.toISO(), forKey: "nautical_twilight_end")
        aCoder.encode(astronomicalSunrise.toISO(), forKey: "astronomical_twilight_begin")
        aCoder.encode(astronomicalSunset.toISO(), forKey: "astronomical_twilight_end")
    }

    required init?(coder aDecoder: NSCoder) {
        let (sevenAM, noon, sevenPM) = Moment.defaultMoments()

        let localTime = { (iso: String) -> DateInRegion? in
            iso.toDate()?.convertTo(region: Region.local)
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

        self.sunrise = localTime(sunrise) ?? sevenAM
        self.sunset = localTime(sunset) ?? sevenPM
        self.solarNoon = localTime(solarNoon) ?? noon
        dayLength = UInt64(aDecoder.decodeInt64(forKey: "day_length"))
        civilSunrise = localTime(civilTwilightBegin) ?? sevenAM
        civilSunset = localTime(civilTwilightEnd) ?? sevenPM
        nauticalSunrise = localTime(nauticalTwilightBegin) ?? sevenAM
        nauticalSunset = localTime(nauticalTwilightEnd) ?? sevenPM
        astronomicalSunrise = localTime(astronomicalTwilightBegin) ?? sevenAM
        astronomicalSunset = localTime(astronomicalTwilightEnd) ?? sevenPM
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
