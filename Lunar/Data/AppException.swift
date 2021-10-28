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

let APP_MAX_BRIGHTNESS_OFFSET: Int8 = 30
let APP_MAX_CONTRAST_OFFSET: Int8 = 20
let DEFAULT_APP_BRIGHTNESS_CONTRAST: Double = 0.8
let DEFAULT_APP_EXCEPTIONS = ["VLC", "Plex", "QuickTime Player", "Plex Media Player", "IINA", "Netflix", "Elmedia Player"]

// MARK: - AppException

@objc class AppException: NSObject, Codable, Defaults.Serializable {
    // MARK: Lifecycle

    init(identifier: String, name: String) {
        self.identifier = identifier
        self.name = name
        super.init()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        name = try container.decode(String.self, forKey: .name)
        brightness = try container.decodeIfPresent(Int8.self, forKey: .brightness) ?? APP_MAX_BRIGHTNESS_OFFSET
        contrast = try container.decodeIfPresent(Int8.self, forKey: .contrast) ?? APP_MAX_CONTRAST_OFFSET
        manualBrightnessContrast = try container
            .decodeIfPresent(Double.self, forKey: .manualBrightnessContrast) ?? DEFAULT_APP_BRIGHTNESS_CONTRAST
        applyBuiltin = try container.decodeIfPresent(Bool.self, forKey: .applyBuiltin) ?? false
        reapplyPreviousBrightness = try container.decodeIfPresent(Bool.self, forKey: .reapplyPreviousBrightness) ?? true
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
        case identifier
        case name
        case brightness
        case contrast
        case manualBrightnessContrast
        case applyBuiltin
        case reapplyPreviousBrightness
    }

    override var description: String {
        "\(name)[\(identifier)]"
    }

    var runningApps: [NSRunningApplication]? {
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

    @objc dynamic var brightness: Int8 = APP_MAX_BRIGHTNESS_OFFSET {
        didSet {
            save()
            log.verbose("\(name): Set brightness to \(brightness)")
        }
    }

    @objc dynamic var contrast: Int8 = APP_MAX_CONTRAST_OFFSET {
        didSet {
            save()
            log.verbose("\(name): Set contrast to \(contrast)")
        }
    }

    @objc dynamic var manualBrightnessContrast: Double = DEFAULT_APP_BRIGHTNESS_CONTRAST {
        didSet { save() }
    }

    @objc dynamic var applyBuiltin: Bool = false {
        didSet { save() }
    }

    @objc dynamic var reapplyPreviousBrightness: Bool = true {
        didSet { save() }
    }

    func save() {
        DataStore.storeAppException(app: self)
    }

    @objc func remove() {
        if var apps = CachedDefaults[.appExceptions] {
            apps.removeAll(where: { $0.identifier == identifier })
            CachedDefaults[.appExceptions] = apps
        }
    }
}
