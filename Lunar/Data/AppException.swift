//
//  AppException.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import AnyCodable
import Cocoa
import Defaults
import Sentry

let APP_MAX_BRIGHTNESS: Int8 = 30
let APP_MAX_CONTRAST: Int8 = 30
let DEFAULT_APP_EXCEPTIONS = ["VLC", "Plex", "QuickTime Player", "Plex Media Player", "IINA", "Netflix", "Elmedia Player"]

@objc class AppException: NSObject, Codable, Defaults.Serializable {
    var runningApp: [NSRunningApplication]? {
        NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
    }

    @objc dynamic var identifier: String {
        didSet {
            save()
        }
    }

    @objc dynamic var name: String {
        didSet {
            save()
        }
    }

    @objc dynamic var brightness: Int8 {
        didSet {
            save()
            log.verbose("\(name): Set brightness to \(brightness)")
        }
    }

    @objc dynamic var contrast: Int8 {
        didSet {
            save()
            log.verbose("\(name): Set contrast to \(contrast)")
        }
    }

    init(identifier: String, name: String, brightness: Int8 = APP_MAX_BRIGHTNESS, contrast: Int8 = APP_MAX_CONTRAST) {
        self.identifier = identifier
        self.name = name
        self.brightness = brightness
        self.contrast = contrast
        super.init()
    }

    func save() {
        DataStore.storeAppException(app: self)
    }

    static func fromDictionary(_ config: [String: Any]) -> AppException? {
        guard let identifier = config["identifier"] as? String,
              let name = config["name"] as? String else { return nil }

        return AppException(
            identifier: identifier,
            name: name,
            brightness: (config["brightness"] as? Int8) ?? APP_MAX_BRIGHTNESS,
            contrast: (config["contrast"] as? Int8) ?? APP_MAX_CONTRAST
        )
    }

    @objc func remove() {
        if var apps = CachedDefaults[.appExceptions] {
            apps.removeAll(where: { $0.identifier == identifier })
            CachedDefaults[.appExceptions] = apps
        }
    }
}
