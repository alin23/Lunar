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
import SwiftyJSON

final class Geolocation: NSObject, Codable, Defaults.Serializable {
    init?(location: CLLocation) {
        guard location.coordinate.latitude != 0 || location.coordinate.longitude != 0 else { return nil }
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        super.init()
    }

    init(latitude: Double, longitude: Double, altitude: Double = 0.0) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        super.init()
    }

    init?(result: JSON) {
        guard let latitude = result["latitude"].double, let longitude = result["longitude"].double else {
            return nil
        }
        self.latitude = latitude
        self.longitude = longitude
        altitude = result["altitude"].double ?? 0.0
        super.init()

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
    }

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case altitude
    }

    var altitude: Double
    var latitude: Double
    var longitude: Double
    lazy var _solar: Solar? = Solar(for: localNow().date, coordinate: coordinate)

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

    func sun(date: Date? = nil) -> Sun? {
        solar?.computeSunPosition(date: date)
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
