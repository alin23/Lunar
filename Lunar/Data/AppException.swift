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

@objc class AppException: NSObject {
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

    @objc dynamic var brightness: NSNumber {
        didSet {
            save()
            addSentryData()
            log.debug("\(name): Set brightness to \(brightness.uint8Value)")
        }
    }

    @objc dynamic var contrast: NSNumber {
        didSet {
            save()
            addSentryData()
            log.debug("\(name): Set contrast to \(contrast.uint8Value)")
        }
    }

    init(identifier: String, name: String, brightness: UInt8 = APP_MAX_BRIGHTNESS, contrast: UInt8 = APP_MAX_CONTRAST) {
        self.identifier = identifier
        self.name = name
        self.brightness = NSNumber(value: brightness)
        self.contrast = NSNumber(value: contrast)
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
        if var apps = datastore.defaults.appExceptions {
            apps.removeAll(where: DataStore.appByIdentifier(identifier))
            datastore.defaults.set(apps as NSArray, forKey: "appExceptions")
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

    func dictionaryRepresentation() -> [String: Any] {
        return [
            "identifier": identifier,
            "name": name,
            "brightness": brightness,
            "contrast": contrast,
        ]
    }
}
