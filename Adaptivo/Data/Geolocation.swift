//
//  Geolocation.swift
//  Adaptivo
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import CoreLocation
import SwiftyJSON

class Geolocation: NSObject, NSCoding {
    let latitude: Double
    let longitude: Double
    let coordinate: CLLocationCoordinate2D
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("geolocation")
    
    
    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.coordinate = location.coordinate
    }
    
    init(result: JSON) {
        if let latitude = result["latitude"].double, let longitude = result["longitude"].double {
            self.latitude = latitude
            self.longitude = longitude
            self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            log.debug("IP Geolocation: \(latitude), \(longitude)")
        } else {
            self.latitude = 0
            self.longitude = 0
            self.coordinate = CLLocationCoordinate2D()
            log.warning("IP Geolocation response does not contain coordinates")
        }
    }
    
    //MARK: NSCoding
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.latitude, forKey: "latitude")
        aCoder.encode(self.longitude, forKey: "longitude")
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.latitude = aDecoder.decodeDouble(forKey: "latitude")
        self.longitude = aDecoder.decodeDouble(forKey: "longitude")
        self.coordinate = CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    
}
