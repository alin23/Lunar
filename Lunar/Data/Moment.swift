//
//  Moment.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Defaults
import Solar
import SwiftDate
import SwiftyJSON

class Moment: NSObject {
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

    var isToday: Bool {
        sunrise.isToday && sunset.isToday && solarNoon.isToday
    }

    static func defaultMoments() -> (DateInRegion, DateInRegion, DateInRegion) {
        guard let sevenAM = DateInRegion().convertTo(region: Region.local).dateBySet(hour: 7, min: 0, secs: 0),
              let noon = DateInRegion().convertTo(region: Region.local).dateBySet(hour: 12, min: 0, secs: 0),
              let sevenPM = DateInRegion().convertTo(region: Region.local).dateBySet(hour: 19, min: 0, secs: 0)
        else {
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

    init(_ solar: inout Solar) {
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

    init?(defaults _: Bool = true) {
        let (sevenAM, noon, sevenPM) = Moment.defaultMoments()

        let localTime = { (iso: String) -> DateInRegion? in
            iso.toDate()?.convertTo(region: Region.local)
        }

        guard let sunrise = CachedDefaults[.sunrise],
              let sunset = CachedDefaults[.sunset],
              let solarNoon = CachedDefaults[.solarNoon],
              let civilTwilightBegin = CachedDefaults[.civilTwilightBegin],
              let civilTwilightEnd = CachedDefaults[.civilTwilightEnd],
              let nauticalTwilightBegin = CachedDefaults[.nauticalTwilightBegin],
              let nauticalTwilightEnd = CachedDefaults[.nauticalTwilightEnd],
              let astronomicalTwilightBegin = CachedDefaults[.astronomicalTwilightBegin],
              let astronomicalTwilightEnd = CachedDefaults[.astronomicalTwilightEnd]
        else {
            log.error("Unable to decode moment.")
            return nil
        }

        self.sunrise = localTime(sunrise) ?? sevenAM
        self.sunset = localTime(sunset) ?? sevenPM
        self.solarNoon = localTime(solarNoon) ?? noon
        let length = UInt64(CachedDefaults[.dayLength])
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
        CachedDefaults[.sunrise] = sunrise.toISO()
        CachedDefaults[.sunset] = sunset.toISO()
        CachedDefaults[.solarNoon] = solarNoon.toISO()
        CachedDefaults[.dayLength] = dayLength
        CachedDefaults[.civilTwilightBegin] = civilSunrise.toISO()
        CachedDefaults[.civilTwilightEnd] = civilSunset.toISO()
        CachedDefaults[.nauticalTwilightBegin] = nauticalSunrise.toISO()
        CachedDefaults[.nauticalTwilightEnd] = nauticalSunset.toISO()
        CachedDefaults[.astronomicalTwilightBegin] = astronomicalSunrise.toISO()
        CachedDefaults[.astronomicalTwilightEnd] = astronomicalSunset.toISO()
    }
}
