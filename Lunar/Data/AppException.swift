//
//  AppException.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa
import Sentry

let APP_MAX_BRIGHTNESS: UInt8 = 30
let APP_MAX_CONTRAST: UInt8 = 30
let DEFAULT_APP_EXCEPTIONS = ["VLC", "Plex", "QuickTime Player", "Plex Media Player", "IINA", "Netflix"]

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
        addSentryData()
    }

    @objc func remove() {
        datastore.context.delete(self)
        try? datastore.context.save()
        removeSentryData()
    }

    func addSentryData() {
        if let client = Client.shared {
            if client.extra == nil {
                log.info("Creating Sentry extra context")
                client.extra = [
                    "settings": datastore.settingsDictionary(),
                    "displays": [:],
                    "apps": [:],
                ]
            }

            if var appExtra = client.extra?["apps"] as? [String: Any] {
                appExtra[name] = [
                    "brightness": brightness,
                    "contrast": contrast,
                ]
                client.extra!["apps"] = appExtra
            }
        }
    }

    func removeSentryData() {
        if let client = Client.shared, let extra = client.extra, var appExtra = extra["apps"] as? [String: Any] {
            appExtra.removeValue(forKey: name)
            client.extra!["apps"] = appExtra
        }
    }

    func addObservers() {
        observers = [
            observe(\.brightness, options: [.new], changeHandler: { _, change in
                if let newVal = change.newValue {
                    datastore.save()
                    self.addSentryData()
                    log.debug("\(self.name): Set brightness to \(newVal.uint8Value)")
                }
            }),
            observe(\.contrast, options: [.new], changeHandler: { _, change in
                if let newVal = change.newValue {
                    datastore.save()
                    self.addSentryData()
                    log.debug("\(self.name): Set contrast to \(newVal.uint8Value)")
                }
            }),
        ]
    }

    func removeObservers() {
        observers.removeAll(keepingCapacity: true)
    }
}
