//
//  AppException.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

let APP_MAX_BRIGHTNESS: UInt8 = 100
let APP_MAX_CONTRAST: UInt8 = 75
let DEFAULT_APP_EXCEPTIONS = ["VLC", "OpenPHT", "QuickTime Player", "Plex Media Player"]

class AppException: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var brightness: NSNumber
    @NSManaged var contrast: NSNumber
    
    convenience init(name: String, brightness: UInt8 = APP_MAX_BRIGHTNESS, contrast: UInt8 = APP_MAX_CONTRAST, context: NSManagedObjectContext? = nil) {
        let context = context ?? datastore.context
        let entity = NSEntityDescription.entity(forEntityName: "AppException", in: context)!
        self.init(entity: entity, insertInto: context)
        
        self.name = name
        self.brightness = NSNumber(value: brightness)
        self.contrast = NSNumber(value: contrast)
    }
}
