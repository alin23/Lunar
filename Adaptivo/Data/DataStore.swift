//
//  DataStore.swift
//  Adaptivo
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class DataStore: NSObject {
    static func loadDisplays() -> [CGDirectDisplayID: Display]? {
        return NSKeyedUnarchiver.unarchiveObject(withFile: Display.ArchiveURL.path) as? [CGDirectDisplayID: Display]
    }
    
    static func saveDisplays(displays: [CGDirectDisplayID: Display]) {
        if NSKeyedArchiver.archiveRootObject(displays, toFile: Display.ArchiveURL.path) {
            log.info("Saved display data to \(Display.ArchiveURL.path)")
        } else {
            log.error("Failed to save display data to \(Display.ArchiveURL.path)")
        }
    }
    
    static func loadMoment() -> Moment? {
        return NSKeyedUnarchiver.unarchiveObject(withFile: Moment.ArchiveURL.path) as? Moment
    }
    
    static func saveMoment(moment: Moment) {
        if NSKeyedArchiver.archiveRootObject(moment, toFile: Moment.ArchiveURL.path) {
            log.info("Saved moment data to \(Moment.ArchiveURL.path)")
        } else {
            log.error("Failed to save moment data to \(Moment.ArchiveURL.path)")
        }
    }
    
    static func loadGeolocation() -> Geolocation? {
        return NSKeyedUnarchiver.unarchiveObject(withFile: Geolocation.ArchiveURL.path) as? Geolocation
    }
    
    static func saveGeolocation(geolocation: Geolocation) {
        if NSKeyedArchiver.archiveRootObject(geolocation, toFile: Geolocation.ArchiveURL.path) {
            log.info("Saved geolocation data to \(Geolocation.ArchiveURL.path)")
        } else {
            log.error("Failed to save geolocation data to \(Geolocation.ArchiveURL.path)")
        }
    }
}
