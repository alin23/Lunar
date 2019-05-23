//
//  Geolocation.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import CoreLocation
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
    var latitudeObserver: NSKeyValueObservation?
    var longitudeObserver: NSKeyValueObservation?

    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("geolocation")

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

    init?(defaults: UserDefaults = datastore.defaults) {
        let latitude = defaults.double(forKey: "locationLat")
        let longitude = defaults.double(forKey: "locationLon")
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
        datastore.defaults.set(latitude, forKey: "locationLat")
        datastore.defaults.set(longitude, forKey: "locationLon")
    }

    func initObservers() {
        latitudeObserver = datastore.defaults.observe(\.locationLat, options: [.old, .new], changeHandler: { _, change in
            guard let lat = change.newValue, let oldLat = change.oldValue, lat != oldLat else {
                return
            }
            self.latitude = lat
            brightnessAdapter.fetchMoments()
        })
        longitudeObserver = datastore.defaults.observe(\.locationLon, options: [.old, .new], changeHandler: { _, change in
            guard let lon = change.newValue, let oldLon = change.oldValue, lon != oldLon else {
                return
            }
            self.longitude = lon
            brightnessAdapter.fetchMoments()
        })
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
        if NSKeyedArchiver.archiveRootObject(self, toFile: Geolocation.ArchiveURL.path) {
            log.info("Saved geolocation data to \(Geolocation.ArchiveURL.path)")
        } else {
            log.error("Failed to save geolocation data to \(Geolocation.ArchiveURL.path)")
        }
    }

    static func deserialize() -> Geolocation? {
        let geolocation = NSKeyedUnarchiver.unarchiveObject(withFile: Geolocation.ArchiveURL.path) as? Geolocation
        geolocation?.initObservers()

        return geolocation
    }
}

