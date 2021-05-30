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

let APP_MAX_BRIGHTNESS: UInt8 = 30
let APP_MAX_CONTRAST: UInt8 = 30
let DEFAULT_APP_EXCEPTIONS = ["VLC", "Plex", "QuickTime Player", "Plex Media Player", "IINA", "Netflix"]

@objc class AppException: NSObject, Codable {
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

    @objc dynamic var brightness: UInt8 {
        didSet {
            save()
            addSentryData()
            log.verbose("\(name): Set brightness to \(brightness)")
        }
    }

    @objc dynamic var contrast: UInt8 {
        didSet {
            save()
            addSentryData()
            log.verbose("\(name): Set contrast to \(contrast)")
        }
    }

    init(identifier: String, name: String, brightness: UInt8 = APP_MAX_BRIGHTNESS, contrast: UInt8 = APP_MAX_CONTRAST) {
        self.identifier = identifier
        self.name = name
        self.brightness = brightness
        self.contrast = contrast
        super.init()
        addSentryData()
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
            brightness: (config["brightness"] as? UInt8) ?? APP_MAX_BRIGHTNESS,
            contrast: (config["contrast"] as? UInt8) ?? APP_MAX_CONTRAST
        )
    }

    @objc func remove() {
        if var apps = Defaults[.appExceptions] {
            apps.removeAll(where: { $0.identifier == identifier })
            Defaults[.appExceptions] = apps
        }
        removeSentryData()
    }

    func addSentryData() {
        SentrySDK.configureScope { [weak self] scope in
            guard let self = self else { return }
            scope.setExtra(value: [
                "brightness": self.brightness,
                "contrast": self.contrast,
            ], key: "app-\(self.name)")
        }
    }

    func removeSentryData() {
        SentrySDK.configureScope { [weak self] scope in
            guard let self = self else { return }
            scope.setExtra(value: "DELETED", key: "app-\(self.name)")
        }
    }
}
