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
import SwiftyJSON

class Geolocation: NSObject, NSCoding {
    var latitude: Double {
        didSet {
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    var longitude: Double {
        didSet {
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    var coordinate: CLLocationCoordinate2D
    var latitudeObserver: DefaultsObservation?
    var longitudeObserver: DefaultsObservation?

    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first
    static let ArchiveURL = DocumentsDirectory?.appendingPathComponent("geolocation")

    init(location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        coordinate = location.coordinate
        super.init()

        store()
        initObservers()
    }

    init(result: JSON) {
        if let latitude = result["latitude"].double, let longitude = result["longitude"].double {
            self.latitude = latitude
            self.longitude = longitude
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            super.init()

            store()
            log.debug("IP Geolocation: \(latitude), \(longitude)")
        } else {
            latitude = 0
            longitude = 0
            coordinate = CLLocationCoordinate2D()
            super.init()

            log.warning("IP Geolocation response does not contain coordinates")
        }
        initObservers()
    }

    // MARK: UserDefaults

    init?(_: Defaults? = nil) {
        let latitude = Defaults[.locationLat]
        let longitude = Defaults[.locationLat]
        if latitude == 0.0, longitude == 0.0 {
            return nil
        }
        self.latitude = latitude
        self.longitude = longitude
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        super.init()

        log.debug("UserDefaults Geolocation: \(latitude), \(longitude)")

        initObservers()
    }

    func store() {
        Defaults[.locationLat] = latitude
        Defaults[.locationLon] = longitude
    }

    func initObservers() {
        latitudeObserver = Defaults.observe(.locationLat) { [weak self] change in
            guard let self = self, change.newValue != change.oldValue else {
                return
            }
            self.latitude = change.newValue
            brightnessAdapter.fetchMoments()
        }
        longitudeObserver = Defaults.observe(.locationLon) { [weak self] change in
            guard let self = self, change.newValue != change.oldValue else {
                return
            }
            self.longitude = change.newValue
            brightnessAdapter.fetchMoments()
        }
    }

    // MARK: NSCoding

    func encode(with aCoder: NSCoder) {
        aCoder.encode(latitude, forKey: "locationLat")
        aCoder.encode(longitude, forKey: "locationLon")
    }

    required init?(coder aDecoder: NSCoder) {
        latitude = aDecoder.decodeDouble(forKey: "locationLat")
        longitude = aDecoder.decodeDouble(forKey: "locationLon")
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        super.init()

        store()
        initObservers()
    }

    func serialize() {
        if let archiveURL = Geolocation.ArchiveURL {
            if NSKeyedArchiver.archiveRootObject(self, toFile: archiveURL.path) {
                log.info("Saved geolocation data to \(archiveURL.path)")
            } else {
                log.error("Failed to save geolocation data to \(archiveURL.path)")
            }
        }
    }

    static func deserialize() -> Geolocation? {
        if let archiveURL = Geolocation.ArchiveURL {
            let geolocation = NSKeyedUnarchiver.unarchiveObject(withFile: archiveURL.path) as? Geolocation
            geolocation?.initObservers()

            return geolocation
        }
        return nil
    }
}
