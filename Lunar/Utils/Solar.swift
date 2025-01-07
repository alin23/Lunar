//
//  Solar.swift
//  SolarExample
//
//  Created by Chris Howell on 16/01/2016.
//  Copyright © 2016 Chris Howell. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the “Software”), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import CoreLocation
import Foundation

/** Astronomical Unit in km. As defined by JPL */
let AU = 149_597_870.691

/** Earth equatorial radius in km. IERS 2003 Conventions */
let EARTH_RADIUS = 6378.1366

/** Length of a sidereal day in days according to IERS Conventions */
let SIDEREAL_DAY_LENGTH = 1.00273781191135448

/** Julian century conversion constant = 100 * days per year */
let JULIAN_DAYS_PER_CENTURY: Double = 36525

/** Seconds in one day */
let SECONDS_PER_DAY: Double = 86400

/** Minutes in one day */
let MINUTES_PER_DAY = 1440

/** Our default epoch.<br>
 The Julian Day which represents noon on 2000-01-01 */
let J2000: Double = 2_451_545

/** Lunar cycle length in days */
let LUNAR_CYCLE_DAYS = 29.530588853

struct Sun {
    let azimuth: Double
    let elevation: Double
}

extension TimeZone {
    static let gmt = TimeZone(secondsFromGMT: 0)!
}

final class Solar {
    // MARK: Init

    init?(for date: Date = Date(), coordinate: CLLocationCoordinate2D) {
        self.date = date
        guard let startOfDayDate = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: date) else {
            return nil
        }
        startOfDay = startOfDayDate

        guard CLLocationCoordinate2DIsValid(coordinate) else {
            return nil
        }

        self.coordinate = coordinate
    }

    // MARK: - Private functions

    enum SunriseSunset {
        case sunrise
        case sunset
    }

    /// Used for generating several of the possible sunrise / sunset times
    enum Zenith: Double {
        case official = 90.83
        case civil = 96
        case nautical = 102
        case astronomical = 108
    }

    /// The coordinate that is used for the calculation
    let coordinate: CLLocationCoordinate2D

    /// The date to generate sunrise / sunset times for
    private(set) var date: Date
    private(set) var startOfDay: Date
    private(set) var sunElevationCache = {
        let c = NSCache<NSNumber, NSNumber>()
        c.countLimit = 1500
        return c
    }()

    private(set) var sunPositionByMinuteInitialized = false
    private(set) lazy var sunPositionByMinute: [Sun?] = {
        let positions = (0 ..< MINUTES_PER_DAY).map { minute in
            computeSunPosition(date: Calendar.current.date(byAdding: DateComponents(minute: minute), to: startOfDay)!)
        }
        sunPositionByMinuteInitialized = true
        return positions
    }()

    private(set) lazy var sunrise: Date? = calculate(.sunrise, for: date, and: .official)
    private(set) lazy var sunset: Date? = calculate(.sunset, for: date, and: .official)
    private(set) lazy var civilSunrise: Date? = calculate(.sunrise, for: date, and: .civil)
    private(set) lazy var civilSunset: Date? = calculate(.sunset, for: date, and: .civil)
    private(set) lazy var nauticalSunrise: Date? = calculate(.sunrise, for: date, and: .nautical)
    private(set) lazy var nauticalSunset: Date? = calculate(.sunset, for: date, and: .nautical)
    private(set) lazy var astronomicalSunrise: Date? = calculate(.sunrise, for: date, and: .astronomical)
    private(set) lazy var astronomicalSunset: Date? = calculate(.sunset, for: date, and: .astronomical)
    private(set) lazy var solarNoon: Date? = {
        let highestElevation = sunPositionByMinute.compactMap { $0 }.enumerated().max(by: { this, other in
            this.1.elevation <= other.1.elevation
        })

        guard let highestElevationMinute = highestElevation?.0 else { return nil }
        return Calendar.current.date(byAdding: DateComponents(minute: highestElevationMinute), to: startOfDay)
    }()

    private(set) lazy var sunrisePosition: Sun? = sunrise != nil ? computeSunPosition(date: sunrise!) : nil
    private(set) lazy var sunsetPosition: Sun? = sunset != nil ? computeSunPosition(date: sunset!) : nil
    private(set) lazy var civilSunrisePosition: Sun? = civilSunrise != nil ? computeSunPosition(date: civilSunrise!) : nil
    private(set) lazy var civilSunsetPosition: Sun? = civilSunset != nil ? computeSunPosition(date: civilSunset!) : nil
    private(set) lazy var nauticalSunrisePosition: Sun? = nauticalSunrise != nil ? computeSunPosition(date: nauticalSunrise!) : nil
    private(set) lazy var nauticalSunsetPosition: Sun? = nauticalSunset != nil ? computeSunPosition(date: nauticalSunset!) : nil
    private(set) lazy var astronomicalSunrisePosition: Sun? = astronomicalSunrise != nil ? computeSunPosition(date: astronomicalSunrise!) : nil
    private(set) lazy var astronomicalSunsetPosition: Sun? = astronomicalSunset != nil ? computeSunPosition(date: astronomicalSunset!) : nil
    private(set) lazy var solarNoonPosition: Sun? = solarNoon != nil ? computeSunPosition(date: solarNoon!) : nil

    /// Sets all of the Solar object's sunrise / sunset variables, if possible.
    /// - Note: Can return `nil` objects if sunrise / sunset does not occur on that day.
    func calculate() {
        sunrise = calculate(.sunrise, for: date, and: .official)
        sunset = calculate(.sunset, for: date, and: .official)
        civilSunrise = calculate(.sunrise, for: date, and: .civil)
        civilSunset = calculate(.sunset, for: date, and: .civil)
        nauticalSunrise = calculate(.sunrise, for: date, and: .nautical)
        nauticalSunset = calculate(.sunset, for: date, and: .nautical)
        astronomicalSunrise = calculate(.sunrise, for: date, and: .astronomical)
        astronomicalSunset = calculate(.sunset, for: date, and: .astronomical)
    }

    func getSunElevation(date: Date? = nil) -> Double? {
        let date = date ?? Date()
        let key = ((date.timeIntervalSinceReferenceDate / 60).rounded() * 60).ns
        if let elevation = sunElevationCache.object(forKey: key) {
            return elevation.doubleValue
        }

        guard let sun = computeSunPosition(date: date) else {
            return nil
        }
        sunElevationCache.setObject(sun.elevation.ns, forKey: key)
        return sun.elevation
    }

    func computeSunPosition(date: Date? = nil) -> Sun? {
        let date = date ?? Date()

        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        if sunPositionByMinuteInitialized,
           let startOfDayDate = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: date), startOfDayDate == startOfDay,
           let sun = sunPositionByMinute[components.hour! * 60 + components.minute!]
        {
            return sun
        }

        let (jd_UT, t) = jd(date)
        var pos: [Double] = getSun(t: t)

        // Ecliptic to equatorial coordinates
        let t2: Double = t / 100
        var tmp: Double = t2 * (27.87 + t2 * (5.79 + t2 * 2.45))
        tmp = t2 * (-249.67 + t2 * (-39.05 + t2 * (7.12 + tmp)))
        tmp = t2 * (-1.55 + t2 * (1999.25 + t2 * (-51.38 + tmp)))
        tmp = (t2 * (-4680.93 + tmp)) / 3600
        var angle: Double = (23.4392911111111 + tmp).degreesToRadians // obliquity
        // Add nutation in obliquity
        let M1: Double = (124.90 - 1934.134 * t + 0.002063 * t * t).degreesToRadians,
            M2: Double = (201.11 + 72001.5377 * t + 0.00057 * t * t).degreesToRadians,
            d = 0.002558 * cos(M1) - 0.00015339 * cos(M2)
        angle += d.degreesToRadians

        pos[0] = pos[0].degreesToRadians
        pos[1] = pos[1].degreesToRadians
        let cl: Double = cos(pos[1]),
            x: Double = pos[2] * cos(pos[0]) * cl
        var y: Double = pos[2] * sin(pos[0]) * cl,
            z: Double = pos[2] * sin(pos[1])
        tmp = y * cos(angle) - z * sin(angle)
        z = y * sin(angle) + z * cos(angle)
        y = tmp

        // Obtain local apparent sidereal time
        let jd0: Double = floor(jd_UT - 0.5) + 0.5,
            T0: Double = (jd0 - J2000) / JULIAN_DAYS_PER_CENTURY,
            secs: Double = (jd_UT - jd0) * SECONDS_PER_DAY
        var gmst: Double = (((((-6.2e-6 * T0) + 9.3104e-2) * T0) + 8_640_184.812866) * T0) + 24110.54841
        let msday: Double = 1 +
            (
                ((((-1.86e-5 * T0) + 0.186208) * T0) + 8_640_184.812866) /
                    (SECONDS_PER_DAY * JULIAN_DAYS_PER_CENTURY)
            )
        gmst = (gmst + msday * secs) * (15 / 3600).degreesToRadians

        let obsLon = coordinate.longitude.degreesToRadians
        let obsLat = coordinate.latitude.degreesToRadians
        let lst: Double = gmst + obsLon

        // Obtain topocentric rectangular coordinates
        // Set radiusAU = 0 for geocentric calculations
        // (rise/set/transit will have no sense in this case)
        let radiusAU: Double = EARTH_RADIUS / AU
        let correction: [Double] = [
            radiusAU * cos(obsLat) * cos(lst),
            radiusAU * cos(obsLat) * sin(lst),
            radiusAU * sin(obsLat),
        ]
        let xtopo: Double = x - correction[0],
            ytopo: Double = y - correction[1],
            ztopo: Double = z - correction[2]

        // Obtain topocentric equatorial coordinates
        var ra: Double = 0,
            dec = Double.pi / 2
        if ztopo < 0 {
            dec = -dec
        }
        if ytopo != 0 || xtopo != 0 {
            ra = atan2(ytopo, xtopo)
            dec = atan2(ztopo / sqrt(xtopo * xtopo + ytopo * ytopo), 1)
        }

        // Hour angle
        let angh: Double = lst - ra

        // Obtain azimuth and geometric alt
        let sinlat: Double = sin(obsLat),
            coslat: Double = cos(obsLat),
            sindec: Double = sin(dec), cosdec: Double = cos(dec),
            h: Double = sinlat * sindec + coslat * cosdec * cos(angh)
        var alt: Double = asin(h)
        let azy: Double = sin(angh),
            azx: Double = cos(angh) * sinlat - sindec * coslat / cosdec,
            azi = Double.pi + atan2(azy, azx) // 0 = north
        // Get apparent elevation
        if alt > -3.degreesToRadians {
            let r = 0.016667
                .degreesToRadians * abs(tan(Double.pi / 2 - (alt.radiansToDegrees + 7.31 / (alt.radiansToDegrees + 4.4)).degreesToRadians))
            let refr: Double = r * (0.28 * 1010 / (10 + 273)) // Assuming pressure of 1010 mb and T = 10 C
            alt = min(alt + refr, Double.pi / 2) // This is not accurate, but acceptable
        }

        return Sun(azimuth: azi.radiansToDegrees, elevation: alt.radiansToDegrees)
    }

    private func jd(_ date: Date) -> (Double, Double) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.gmt
        let dc: DateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date),
            year: Int = dc.year!,
            month: Int = dc.month!,
            day: Int = dc.day!,
            h: Int = dc.hour!,
            m: Int = dc.minute!,
            s: Int = dc.second!

        // The conversion formulas are from Meeus, chapter 7.
        var julian = false
        if year < 1582 || (year == 1582 && month <= 10) || (year == 1582 && month == 10 && day < 15) {
            julian = true
        }
        let D: Int = day
        var M: Int = month,
            Y: Int = year
        if M < 3 {
            Y -= 1
            M += 12
        }
        let A: Int = Y / 100,
            B: Int = julian ? 0 : 2 - A + A / 4,
            dayFraction: Double = (Double(h) + (Double(m) + (Double(s) / 60)) / 60) / 24,
            jd: Double = dayFraction + Double(Int(365.25 * Double(Y + 4716)) + Int(30.6001 * Double(M + 1))) + Double(D + B) -
            1524.5

        var TTminusUT: Double = 0
        if year > -600, year < 2200 {
            let x = Double(year) + (Double(month) - 1 + Double(day) / 30) / 12
            let x2: Double = x * x, x3: Double = x2 * x, x4: Double = x3 * x
            if year < 1600 {
                TTminusUT = 10535.328003326353 - 9.995238627481024 * x + 0.003067307630020489 * x2 - 7.76340698361363e-6 * x3 +
                    3.1331045394223196e-9 * x4 +
                    8.225530854405553e-12 * x2 * x3 - 7.486164715632051e-15 * x4 * x2 + 1.9362461549678834e-18 * x4 * x3 -
                    8.489224937827653e-23 * x4 * x4
            } else {
                TTminusUT = -1_027_175.3477559977 + 2523.256625418965 * x - 1.885686849058459 * x2 + 5.869246227888417e-5 * x3 +
                    3.3379295816475025e-7 * x4 +
                    1.7758961671447929e-10 * x2 * x3 - 2.7889902806153024e-13 * x2 * x4 + 1.0224295822336825e-16 * x3 * x4 -
                    1.2528102370680435e-20 * x4 * x4
            }
        }

        let t = (jd + TTminusUT / SECONDS_PER_DAY - J2000) / JULIAN_DAYS_PER_CENTURY
        return (jd, t)
    }

    private func getSun(t: Double) -> [Double] {
        // SUN PARAMETERS (Formulae from "Calendrical Calculations")
        let lon: Double = (280.46645 + 36000.76983 * t + 0.0003032 * t * t),
            anom: Double = (357.5291 + 35999.0503 * t - 0.0001559 * t * t - 4.8e-07 * t * t * t)
        let sanomaly = anom.degreesToRadians
        var c: Double = (1.9146 - 0.004817 * t - 0.000014 * t * t) * sin(sanomaly)
        c = c + (0.019993 - 0.000101 * t) * sin(2 * sanomaly)
        c = c + 0.00029 * sin(3 * sanomaly) // Correction to the mean ecliptic longitude

        // Now, let calculate nutation and aberration
        let M1: Double = (124.90 - 1934.134 * t + 0.002063 * t * t).degreesToRadians,
            M2: Double = (201.11 + 72001.5377 * t + 0.00057 * t * t).degreesToRadians,
            d: Double = -0.00569 - 0.0047785 * sin(M1) - 0.0003667 * sin(M2)

        let slongitude = lon + c + d // apparent longitude (error<0.003 deg)
        let slatitude: Double = 0, // Sun's ecliptic latitude is always negligible
            ecc = 0.016708617 - 4.2037e-05 * t - 1.236e-07 * t * t, // Eccentricity
            v: Double = sanomaly + c.degreesToRadians, // True anomaly
            sdistance = 1.000001018 * (1 - ecc * ecc) / (1 + ecc * cos(v)) // In UA

        return [slongitude, slatitude, sdistance, atan(696_000 / (AU * sdistance))]
    }

    private func calculate(_ sunriseSunset: SunriseSunset, for date: Date, and zenith: Zenith) -> Date? {
        let utcTimezone = TimeZone.gmt

        // Get the day of the year
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utcTimezone
        guard let dayInt = calendar.ordinality(of: .day, in: .year, for: date) else { return nil }
        let day = Double(dayInt)

        // Convert longitude to hour value and calculate an approx. time
        let lngHour = coordinate.longitude / 15

        let hourTime: Double = sunriseSunset == .sunrise ? 6 : 18
        let t = day + ((hourTime - lngHour) / 24)

        // Calculate the suns mean anomaly
        let M = (0.9856 * t) - 3.289

        // Calculate the sun's true longitude
        let subexpression1 = 1.916 * sin(M.degreesToRadians)
        let subexpression2 = 0.020 * sin(2 * M.degreesToRadians)
        var L = M + subexpression1 + subexpression2 + 282.634

        // Normalise L into [0, 360] range
        L = normalise(L, withMaximum: 360)

        // Calculate the Sun's right ascension
        var RA = atan(0.91764 * tan(L.degreesToRadians)).radiansToDegrees

        // Normalise RA into [0, 360] range
        RA = normalise(RA, withMaximum: 360)

        // Right ascension value needs to be in the same quadrant as L...
        let Lquadrant = floor(L / 90) * 90
        let RAquadrant = floor(RA / 90) * 90
        RA = RA + (Lquadrant - RAquadrant)

        // Convert RA into hours
        RA = RA / 15

        // Calculate Sun's declination
        let sinDec = 0.39782 * sin(L.degreesToRadians)
        let cosDec = cos(asin(sinDec))

        // Calculate the Sun's local hour angle
        let cosH = (cos(zenith.rawValue.degreesToRadians) - (sinDec * sin(coordinate.latitude.degreesToRadians))) /
            (cosDec * cos(coordinate.latitude.degreesToRadians))

        // No sunrise
        guard cosH < 1 else {
            return nil
        }

        // No sunset
        guard cosH > -1 else {
            return nil
        }

        // Finish calculating H and convert into hours
        let tempH = sunriseSunset == .sunrise ? 360 - acos(cosH).radiansToDegrees : acos(cosH).radiansToDegrees
        let H = tempH / 15.0

        // Calculate local mean time of rising
        let T = H + RA - (0.06571 * t) - 6.622

        // Adjust time back to UTC
        var UT = T - lngHour

        // Normalise UT into [0, 24] range
        UT = normalise(UT, withMaximum: 24)

        // Calculate all of the sunrise's / sunset's date components
        let hour = floor(UT)
        let minute = floor((UT - hour) * 60.0)
        let second = (((UT - hour) * 60) - minute) * 60.0

        let shouldBeYesterday = lngHour > 0 && UT > 12 && sunriseSunset == .sunrise
        let shouldBeTomorrow = lngHour < 0 && UT < 12 && sunriseSunset == .sunset

        let setDate: Date = if shouldBeYesterday {
            Date(timeInterval: -(60 * 60 * 24), since: date)
        } else if shouldBeTomorrow {
            Date(timeInterval: 60 * 60 * 24, since: date)
        } else {
            date
        }

        var components = calendar.dateComponents([.day, .month, .year], from: setDate)
        components.hour = Int(hour)
        components.minute = Int(minute)
        components.second = Int(second)

        calendar.timeZone = utcTimezone
        return calendar.date(from: components)
    }

    /// Normalises a value between 0 and `maximum`, by adding or subtracting `maximum`
    private func normalise(_ value: Double, withMaximum maximum: Double) -> Double {
        var value = value

        if value < 0 {
            value += maximum
        }

        if value > maximum {
            value -= maximum
        }

        return value
    }
}

extension Solar {
    /// Whether the location specified by the `latitude` and `longitude` is in daytime on `date`
    /// - Complexity: O(1)
    var isDaytime: Bool {
        guard let sunrise,
              let sunset
        else {
            return false
        }

        let beginningOfDay = sunrise.timeIntervalSince1970
        let endOfDay = sunset.timeIntervalSince1970
        let currentTime = date.timeIntervalSince1970

        let isSunriseOrLater = currentTime >= beginningOfDay
        let isBeforeSunset = currentTime < endOfDay

        return isSunriseOrLater && isBeforeSunset
    }

    /// Whether the location specified by the `latitude` and `longitude` is in nighttime on `date`
    /// - Complexity: O(1)
    var isNighttime: Bool {
        !isDaytime
    }
}

// MARK: - Helper extensions

extension Double {
    var degreesToRadians: Double {
        Double(self) * (Double.pi / 180.0)
    }

    var radiansToDegrees: Double {
        (Double(self) * 180.0) / Double.pi
    }
}
