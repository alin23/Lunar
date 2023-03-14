//
//  Geolocation.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import CoreLocation
import Defaults
import Solar
import SwiftDate
import SwiftyJSON

final class Geolocation: NSObject, Codable, Defaults.Serializable {
    init?(location: CLLocation) {
        guard location.coordinate.latitude != 0 || location.coordinate.longitude != 0 else { return nil }
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        super.init()
        cacheRefresher = Repeater(every: 1.days.timeInterval) { [weak self] in
            guard let self else { return }
            self.sunElevationCache = self.computeCache()
        }
    }

    init(latitude: Double, longitude: Double, altitude: Double = 0.0) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        super.init()
        cacheRefresher = Repeater(every: 1.days.timeInterval) { [weak self] in
            guard let self else { return }
            self.sunElevationCache = self.computeCache()
        }
    }

    init?(result: JSON) {
        guard let latitude = result["latitude"].double, let longitude = result["longitude"].double else {
            return nil
        }
        self.latitude = latitude
        self.longitude = longitude
        altitude = result["altitude"].double ?? 0.0
        super.init()
        cacheRefresher = Repeater(every: 1.days.timeInterval) { [weak self] in
            guard let self else { return }
            self.sunElevationCache = self.computeCache()
        }

        store()
        log
            .debug(
                "IP Geolocation: \(latitude.str(decimals: 1)), \(longitude.str(decimals: 1)) (altitude: \(altitude.str(decimals: 1)))"
            )
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        altitude = try container.decode(Double.self, forKey: .altitude)
        super.init()
        cacheRefresher = Repeater(every: 1.days.timeInterval) { [weak self] in
            guard let self else { return }
            self.sunElevationCache = self.computeCache()
        }
    }

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case altitude
    }

    var cacheRefresher: Repeater! = nil

    var altitude: Double
    var latitude: Double
    var longitude: Double
    lazy var _solar: Solar? = Solar(for: localNow().date, coordinate: coordinate)

    lazy var sunElevationCache: [Double: Double] = computeCache()

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var solar: Solar? {
        get {
            if let s = _solar, let noon = s.solarNoon, !noon.isToday {
                _solar = Solar(for: localNow().date, coordinate: coordinate)
            }
            return _solar
        }
        set {
            if let s = newValue, let noon = s.solarNoon, !noon.isToday {
                _solar = Solar(for: localNow().date, coordinate: coordinate)
            } else {
                _solar = newValue
            }
        }
    }

    func computeCache() -> [Double: Double] {
        let startOfDay = Date().dateAtStartOf(.day)
        return (0 ... 2880).dict { minute in
            let date = startOfDay + minute.minutes
            guard let elevation = solar?.computeSunPosition(date: date)?.elevation else {
                return nil
            }
            return (date.timeIntervalSinceReferenceDate, elevation)
        }
    }

    func sun(date: Date? = nil) -> Double? {
        let date = date ?? Date()
        let key = (date.timeIntervalSinceReferenceDate / 60).rounded() * 60
        if let elevation = sunElevationCache[key] {
            return elevation
        }

        guard let sun = solar?.computeSunPosition(date: date) else {
            return nil
        }
        sunElevationCache[key] = sun.elevation
        return sun.elevation
    }

    func store() {
        CachedDefaults[.location] = self
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(altitude, forKey: .altitude)
    }
}
