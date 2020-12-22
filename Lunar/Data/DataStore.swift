//
//  DataStore.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import AnyCodable
import Cocoa
import Defaults

let APP_SETTINGS = [
    Defaults.Keys.adaptiveBrightnessMode,
    .brightnessLimitMax,
    .brightnessLimitMin,
    .brightnessClipMax,
    .brightnessClipMin,
    .brightnessOffset,
    .volumeStep,
    .brightnessStep,
    .contrastLimitMax,
    .contrastLimitMin,
    .contrastOffset,
    .contrastStep,
    .curveFactor,
    .daylightExtensionMinutes,
    .debug,
    .didScrollTextField,
    .didSwipeLeft,
    .didSwipeRight,
    .didSwipeToHotkeys,
    .firstRun,
    .hotkeys,
    .manualLocation,
    .noonDurationMinutes,
    .refreshValues,
    .showNavigationHints,
    .showQuickActions,
    .smoothTransition,
    .solarNoon,
    .startAtLogin,
    .sunrise,
    .sunset,
    .syncPollingSeconds,
    .clamshellModeDetection,
    .brightnessKeysEnabled,
    .volumeKeysEnabled,
    .useCoreDisplay,
]

class DataStore: NSObject {
    func displays(serials: [String]? = nil) -> [Display]? {
        guard let displays = Defaults[.displays] else { return nil }
        if let ids = serials {
            return displays.filter { display in ids.contains(display.serial) }
        }
        return displays
    }

    func appExceptions(identifiers: [String]? = nil) -> [AppException]? {
        guard let apps = Defaults[.appExceptions] else { return nil }
        if let ids = identifiers {
            return apps.filter { app in ids.contains(app.identifier) }
        }
        return apps
    }

    func settingsDictionary() -> [String: Any]? {
        let settings = [String: AnyCodable](APP_SETTINGS.map { key in
            (key.name, Defaults[Defaults.Key<AnyCodable>(key.name, default: nil)])
        }, uniquingKeysWith: { v1, _ in v1 })
        return settings.dictionary
    }

    static func storeAppException(app: AppException) {
        guard var appExceptions = Defaults[.appExceptions] else {
            Defaults[.appExceptions] = [app]
            return
        }

        if let appIndex = appExceptions.firstIndex(where: { $0.identifier == app.identifier }) {
            appExceptions[appIndex] = app
        } else {
            appExceptions.append(app)
        }

        Defaults[.appExceptions] = appExceptions
    }

    func storeDisplays(_ displays: [Display]) -> [Display] {
        let displays = displays.filter {
            display in !BrightnessAdapter.isBuiltinDisplay(display.id)
        }

        guard let storedDisplays = self.displays() else {
            Defaults[.displays] = displays
            return displays
        }
        let newDisplaySerials = displays.map { $0.serial }
        let newDisplayIDs = displays.map { $0.id }

        let inactiveDisplays = storedDisplays.filter { d in !newDisplaySerials.contains(d.serial) }
        for display in inactiveDisplays {
            display.active = false
            while newDisplayIDs.contains(display.id) {
                display.id = UInt32.random(in: 100 ... 1000)
            }
        }

        let allDisplays = (inactiveDisplays + displays).filter {
            display in !BrightnessAdapter.isBuiltinDisplay(display.id)
        }
        Defaults[.displays] = allDisplays

        return allDisplays
    }

    static func storeDisplay(display: Display) {
        if display.id == TEST_DISPLAY_ID || display.id == GENERIC_DISPLAY_ID {
            return
        }

        guard var displays = Defaults[.displays] else {
            Defaults[.displays] = [display]
            return
        }

        if let displayIndex = displays.firstIndex(where: { $0.serial == display.serial }) {
            displays[displayIndex] = display
        } else {
            displays.append(display)
        }

        Defaults[.displays] = displays
    }

    static func firstRun() {
        log.debug("First run")
        thisIsFirstRun = true
        for app in DEFAULT_APP_EXCEPTIONS {
            let appPath = "/Applications/\(app).app"
            if FileManager.default.fileExists(atPath: appPath) {
                let bundle = Bundle(path: appPath)
                guard let id = bundle?.bundleIdentifier,
                      let name = bundle?.infoDictionary?["CFBundleName"] as? String
                else {
                    continue
                }
                if let exc = Defaults[.appExceptions]?.first(where: { $0.identifier == id }) {
                    log.debug("Existing app for \(app): \(String(describing: exc))")
                    continue
                }
                storeAppException(app: AppException(identifier: id, name: name))
            }
        }
    }

    override init() {
        super.init()

        NSUserDefaultsController.shared.appliesImmediately = true

        log.debug("Checking First Run")
        if Defaults[.firstRun] == nil {
            DataStore.firstRun()
            Defaults[.firstRun] = true
        }
    }
}

extension Defaults.Keys {
    static let firstRun = Key<Bool?>("firstRun", default: nil)
    static let curveFactor = Key<Double>("curveFactor", default: 0.5)
    static let brightnessKeysEnabled = Key<Bool>("brightnessKeysEnabled", default: true)
    static let volumeKeysEnabled = Key<Bool>("volumeKeysEnabled", default: true)
    static let didScrollTextField = Key<Bool>("didScrollTextField", default: false)
    static let didSwipeToHotkeys = Key<Bool>("didSwipeToHotkeys", default: false)
    static let didSwipeLeft = Key<Bool>("didSwipeLeft", default: false)
    static let didSwipeRight = Key<Bool>("didSwipeRight", default: false)
    static let smoothTransition = Key<Bool>("smoothTransition", default: false)
    static let refreshValues = Key<Bool>("refreshValues", default: false)
    static let useCoreDisplay = Key<Bool>("useCoreDisplay", default: true)
    static let debug = Key<Bool>("debug", default: false)
    static let showQuickActions = Key<Bool>("showQuickActions", default: true)
    static let manualLocation = Key<Bool>("manualLocation", default: false)
    static let showNavigationHints = Key<Bool>("showNavigationHints", default: false)
    static let startAtLogin = Key<Bool>("startAtLogin", default: true)
    static let clamshellModeDetection = Key<Bool>("clamshellModeDetection", default: true)
    static let daylightExtensionMinutes = Key<Int>("daylightExtensionMinutes", default: 180)
    static let noonDurationMinutes = Key<Int>("noonDurationMinutes", default: 240)
    static let brightnessOffset = Key<Int>("brightnessOffset", default: 5)
    static let contrastOffset = Key<Int>("contrastOffset", default: 20)
    static let brightnessClipMax = Key<Int>("brightnessClipMax", default: 100)
    static let brightnessClipMin = Key<Int>("brightnessClipMin", default: 0)
    static let brightnessLimitMin = Key<Int>("brightnessLimitMin", default: 5)
    static let contrastLimitMin = Key<Int>("contrastLimitMin", default: 20)
    static let brightnessLimitMax = Key<Int>("brightnessLimitMax", default: 90)
    static let contrastLimitMax = Key<Int>("contrastLimitMax", default: 70)
    static let brightnessStep = Key<Int>("brightnessStep", default: 6)
    static let contrastStep = Key<Int>("contrastStep", default: 6)
    static let volumeStep = Key<Int>("volumeStep", default: 6)
    static let syncPollingSeconds = Key<Int>("syncPollingSeconds", default: 2)
    static let adaptiveBrightnessMode = Key<AdaptiveMode>("adaptiveBrightnessMode", default: .sync)
    static let hotkeys = Key<[HotkeyIdentifier: [HotkeyPart: Int]]>("hotkeys", default: Hotkey.defaults)
    static let displays = Key<[Display]?>("displays", default: nil)
    static let appExceptions = Key<[AppException]?>("appExceptions", default: nil)
    static let sunrise = Key<String?>("sunrise", default: nil)
    static let sunset = Key<String?>("sunset", default: nil)
    static let solarNoon = Key<String?>("solarNoon", default: nil)
    static let locationLat = Key<Double>("locationLat", default: 0.0)
    static let locationLon = Key<Double>("locationLon", default: 0.0)
    static let civilTwilightBegin = Key<String?>("civilTwilightBegin", default: nil)
    static let civilTwilightEnd = Key<String?>("civilTwilightEnd", default: nil)
    static let nauticalTwilightBegin = Key<String?>("nauticalTwilightBegin", default: nil)
    static let nauticalTwilightEnd = Key<String?>("nauticalTwilightEnd", default: nil)
    static let astronomicalTwilightBegin = Key<String?>("astronomicalTwilightBegin", default: nil)
    static let astronomicalTwilightEnd = Key<String?>("astronomicalTwilightEnd", default: nil)
    static let dayLength = Key<UInt64>("dayLength", default: 0)
    static let hideMenuBarIcon = Key<Bool>("hideMenuBarIcon", default: false)
}
