//
//  AppException.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

let APP_MAX_BRIGHTNESS: UInt8 = 50
let APP_MAX_CONTRAST: UInt8 = 30
let DEFAULT_APP_EXCEPTIONS = ["VLC", "Plex", "QuickTime Player", "Plex Media Player"]

class AppException: NSManagedObject {
    @NSManaged var identifier: String
    @NSManaged var name: String
    @NSManaged var brightness: NSNumber
    @NSManaged var contrast: NSNumber
    var observers: [NSKeyValueObservation] = []

    convenience init(identifier: String, name: String, brightness: UInt8 = APP_MAX_BRIGHTNESS, contrast: UInt8 = APP_MAX_CONTRAST, context: NSManagedObjectContext? = nil) {
        let context = context ?? datastore.context
        let entity = NSEntityDescription.entity(forEntityName: "AppException", in: context)!
        self.init(entity: entity, insertInto: context)

        self.identifier = identifier
        self.name = name
        self.brightness = NSNumber(value: brightness)
        self.contrast = NSNumber(value: contrast)
    }

    @objc func remove() {
        datastore.context.delete(self)
        try? datastore.context.save()
    }

    func addObservers() {
        observers = [
            observe(\.brightness, options: [.new], changeHandler: { _, change in
                if let newVal = change.newValue {
                    datastore.save()
                    log.debug("\(self.name): Set brightness to \(newVal.uint8Value)")
                }
            }),
            observe(\.contrast, options: [.new], changeHandler: { _, change in
                if let newVal = change.newValue {
                    datastore.save()
                    log.debug("\(self.name): Set contrast to \(newVal.uint8Value)")
                }
            }),
        ]
    }

    func removeObservers() {
        observers.removeAll(keepingCapacity: true)
    }
}
