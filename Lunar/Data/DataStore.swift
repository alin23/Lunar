//
//  DataStore.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

let APP_SETTINGS = [
    "adaptiveBrightnessMode",
    "brightnessLimitMax",
    "brightnessLimitMin",
    "brightnessClipMax",
    "brightnessClipMin",
    "brightnessOffset",
    "volumeStep",
    "brightnessStep",
    "contrastLimitMax",
    "contrastLimitMin",
    "contrastOffset",
    "contrastStep",
    "curveFactor",
    "daylightExtensionMinutes",
    "debug",
    "didScrollTextField",
    "didSwipeLeft",
    "didSwipeRight",
    "didSwipeToHotkeys",
    "firstRun",
    "hotkeys",
    "manualLocation",
    "noonDurationMinutes",
    "refreshValues",
    "showNavigationHints",
    "showQuickActions",
    "smoothTransition",
    "solarNoon",
    "startAtLogin",
    "sunrise",
    "sunset",
    "syncPollingSeconds",
    "clamshellModeDetection",
    "mediaKeysEnabled",
]

extension UserDefaults {
    @objc dynamic var sunrise: String {
        return string(forKey: "sunrise") ?? ""
    }

    @objc dynamic var sunset: String {
        return string(forKey: "sunset") ?? ""
    }

    @objc dynamic var solarNoon: String {
        return string(forKey: "solarNoon") ?? ""
    }

    @objc dynamic var noonDurationMinutes: Int {
        return integer(forKey: "noonDurationMinutes")
    }

    @objc dynamic var daylightExtensionMinutes: Int {
        return integer(forKey: "daylightExtensionMinutes")
    }

    @objc dynamic var curveFactor: Double {
        return double(forKey: "curveFactor")
    }

    @objc dynamic var locationLat: Double {
        return double(forKey: "locationLat")
    }

    @objc dynamic var locationLon: Double {
        return double(forKey: "locationLon")
    }

    @objc dynamic var mediaKeysEnabled: Bool {
        return bool(forKey: "mediaKeysEnabled")
    }

    @objc dynamic var manualLocation: Bool {
        return bool(forKey: "manualLocation")
    }

    @objc dynamic var showNavigationHints: Bool {
        return bool(forKey: "showNavigationHints")
    }

    @objc dynamic var startAtLogin: Bool {
        return bool(forKey: "startAtLogin")
    }

    @objc dynamic var clamshellModeDetection: Bool {
        return bool(forKey: "clamshellModeDetection")
    }

    @objc dynamic var didScrollTextField: Bool {
        return bool(forKey: "didScrollTextField")
    }

    @objc dynamic var didSwipeLeft: Bool {
        return bool(forKey: "didSwipeLeft")
    }

    @objc dynamic var didSwipeToHotkeys: Bool {
        return bool(forKey: "didSwipeToHotkeys")
    }

    @objc dynamic var didSwipeRight: Bool {
        return bool(forKey: "didSwipeRight")
    }

    @objc dynamic var smoothTransition: Bool {
        return bool(forKey: "smoothTransition")
    }

    @objc dynamic var refreshValues: Bool {
        return bool(forKey: "refreshValues")
    }

    @objc dynamic var debug: Bool {
        return bool(forKey: "debug")
    }

    @objc dynamic var showQuickActions: Bool {
        return bool(forKey: "showQuickActions")
    }

    @objc dynamic var syncPollingSeconds: Int {
        return integer(forKey: "syncPollingSeconds")
    }

    @objc dynamic var adaptiveBrightnessMode: Int {
        return integer(forKey: "adaptiveBrightnessMode")
    }

    @objc dynamic var volumeStep: Int {
        return integer(forKey: "volumeStep")
    }

    @objc dynamic var brightnessStep: Int {
        return integer(forKey: "brightnessStep")
    }

    @objc dynamic var contrastStep: Int {
        return integer(forKey: "contrastStep")
    }

    @objc dynamic var brightnessOffset: Int {
        return integer(forKey: "brightnessOffset")
    }

    @objc dynamic var contrastOffset: Int {
        return integer(forKey: "contrastOffset")
    }

    @objc dynamic var brightnessLimitMin: Int {
        return integer(forKey: "brightnessLimitMin")
    }

    @objc dynamic var brightnessClipMax: Int {
        return integer(forKey: "brightnessClipMax")
    }

    @objc dynamic var brightnessClipMin: Int {
        return integer(forKey: "brightnessClipMin")
    }

    @objc dynamic var contrastLimitMin: Int {
        return integer(forKey: "contrastLimitMin")
    }

    @objc dynamic var brightnessLimitMax: Int {
        return integer(forKey: "brightnessLimitMax")
    }

    @objc dynamic var contrastLimitMax: Int {
        return integer(forKey: "contrastLimitMax")
    }

    @objc dynamic var hotkeys: [String: Any]? {
        return dictionary(forKey: "hotkeys")
    }

    @objc dynamic var displays: [Any]? {
        return array(forKey: "displays")
    }

    @objc dynamic var appExceptions: [Any]? {
        return array(forKey: "appExceptions")
    }
}

class DataStore: NSObject {
    static let defaults: UserDefaults = NSUserDefaultsController.shared.defaults
    let defaults: UserDefaults = DataStore.defaults

    func hotkeys() -> [HotkeyIdentifier: [HotkeyPart: Int]]? {
        guard let hotkeyConfig = defaults.hotkeys else { return nil }
        return Hotkey.toDictionary(hotkeyConfig)
    }

    func displays(serials: [String]? = nil) -> [Display]? {
        guard let displayConfig = defaults.displays else { return nil }
        return displayConfig.map { config in
            guard let config = config as? [String: Any],
                let serial = config["serial"] as? String else { return nil }

            if let serials = serials, !serials.contains(serial) {
                return nil
            }
            return Display.fromDictionary(config)
        }.compactMap { $0 }
    }

    func appExceptions(identifiers: [String]? = nil) -> [AppException]? {
        guard let appConfig = defaults.appExceptions else { return nil }
        return appConfig.map { config in
            guard let config = config as? [String: Any],
                let identifier = config["identifier"] as? String else { return nil }

            if let identifiers = identifiers, !identifiers.contains(identifier) {
                return nil
            }
            return AppException.fromDictionary(config)
        }.compactMap { $0 }
    }

    func settingsDictionary() -> [String: Any] {
        return defaults.dictionaryRepresentation().filter { elem in
            APP_SETTINGS.contains(elem.key)
        }
    }

    static func storeAppException(app: AppException) {
        guard var appExceptions = DataStore.defaults.appExceptions else {
            DataStore.defaults.set([
                app.dictionaryRepresentation(),
            ] as NSArray, forKey: "appExceptions")
            return
        }

        if let appIndex = appExceptions.firstIndex(where: appByIdentifier(app.identifier)) {
            appExceptions[appIndex] = app.dictionaryRepresentation()
        } else {
            appExceptions.append(app.dictionaryRepresentation())
        }

        DataStore.defaults.set(appExceptions as NSArray, forKey: "appExceptions")
    }

    func storeDisplays(_ displays: [Display]) -> [Display] {
        let displays = displays.filter {
            display in !BrightnessAdapter.isBuiltinDisplay(display.id)
        }

        guard let storedDisplays = self.displays() else {
            let nsDisplays = displays.map {
                $0.dictionaryRepresentation()
            } as NSArray
            defaults.set(nsDisplays, forKey: "displays")
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
        let nsDisplays = allDisplays.map {
            $0.dictionaryRepresentation()
        } as NSArray
        defaults.set(nsDisplays, forKey: "displays")

        return allDisplays
    }

    static func storeDisplay(display: Display) {
        if display.id == TEST_DISPLAY_ID || display.id == GENERIC_DISPLAY_ID {
            return
        }

        guard var displays = DataStore.defaults.displays else {
            DataStore.defaults.set([
                display.dictionaryRepresentation(),
            ] as NSArray, forKey: "displays")
            return
        }

        if let displayIndex = displays.firstIndex(where: displayBySerial(display.serial)) {
            displays[displayIndex] = display.dictionaryRepresentation()
        } else {
            displays.append(display.dictionaryRepresentation())
        }

        DataStore.defaults.set(displays as NSArray, forKey: "displays")
    }

    static func appByIdentifier(_ identifier: String) -> ((Any) -> Bool) {
        return { app in
            guard let id = (app as? [String: Any])?["identifier"] as? String else { return false }
            return id == identifier
        }
    }

    static func displayBySerial(_ serial: String) -> ((Any) -> Bool) {
        return { display in
            guard let displaySerial = (display as? [String: Any])?["serial"] as? String else { return false }
            return serial == displaySerial
        }
    }

    static func firstRun() {
        log.debug("First run")
        thisIsFirstRun = true
        for app in DEFAULT_APP_EXCEPTIONS {
            let appPath = "/Applications/\(app).app"
            if FileManager.default.fileExists(atPath: appPath) {
                let bundle = Bundle(path: appPath)
                guard let id = bundle?.bundleIdentifier,
                    let name = bundle?.infoDictionary?["CFBundleName"] as? String else {
                    continue
                }
                if let exc = defaults.appExceptions?.first(where: appByIdentifier(id)) {
                    log.debug("Existing app for \(app): \(String(describing: exc))")
                    continue
                }
                storeAppException(app: AppException(identifier: id, name: name))
            }
        }
    }

    static func setDefault(_ value: Int, for key: String) {
        if DataStore.defaults.object(forKey: key) == nil {
            DataStore.defaults.set(value, forKey: key)
        }
    }

    static func setDefault(_ value: Double, for key: String) {
        if DataStore.defaults.object(forKey: key) == nil {
            DataStore.defaults.set(value, forKey: key)
        }
    }

    static func setDefault(_ value: Bool, for key: String) {
        if DataStore.defaults.object(forKey: key) == nil {
            DataStore.defaults.set(value, forKey: key)
        }
    }

    static func setDefault(_ value: NSDictionary, for key: String) {
        if DataStore.defaults.object(forKey: key) == nil {
            DataStore.defaults.set(value, forKey: key)
        }
    }

    override init() {
        super.init()

        NSUserDefaultsController.shared.appliesImmediately = true

        log.debug("Checking First Run")
        if DataStore.defaults.object(forKey: "firstRun") == nil {
            DataStore.firstRun()
            DataStore.defaults.set(true, forKey: "firstRun")
        }

        DataStore.setDefault(0.5, for: "curveFactor")
        DataStore.setDefault(true, for: "mediaKeysEnabled")
        DataStore.setDefault(false, for: "didScrollTextField")
        DataStore.setDefault(false, for: "didSwipeToHotkeys")
        DataStore.setDefault(false, for: "didSwipeLeft")
        DataStore.setDefault(false, for: "didSwipeRight")
        DataStore.setDefault(false, for: "smoothTransition")
        DataStore.setDefault(DataStore.defaults.bool(forKey: "refreshBrightness"), for: "refreshValues")
        DataStore.setDefault(false, for: "debug")
        DataStore.setDefault(true, for: "showQuickActions")
        DataStore.setDefault(false, for: "manualLocation")
        DataStore.setDefault(false, for: "showNavigationHints")
        DataStore.setDefault(true, for: "startAtLogin")
        DataStore.setDefault(true, for: "clamshellModeDetection")
        DataStore.setDefault(180, for: "daylightExtensionMinutes")
        DataStore.setDefault(240, for: "noonDurationMinutes")
        DataStore.setDefault(5, for: "brightnessOffset")
        DataStore.setDefault(20, for: "contrastOffset")
        DataStore.setDefault(100, for: "brightnessClipMax")
        DataStore.setDefault(0, for: "brightnessClipMin")
        DataStore.setDefault(5, for: "brightnessLimitMin")
        DataStore.setDefault(20, for: "contrastLimitMin")
        DataStore.setDefault(90, for: "brightnessLimitMax")
        DataStore.setDefault(70, for: "contrastLimitMax")
        DataStore.setDefault(6, for: "brightnessStep")
        DataStore.setDefault(6, for: "contrastStep")
        DataStore.setDefault(6, for: "volumeStep")
        DataStore.setDefault(2, for: "syncPollingSeconds")
        DataStore.setDefault(AdaptiveMode.sync.rawValue, for: "adaptiveBrightnessMode")
        DataStore.setDefault(Hotkey.defaultHotkeys, for: "hotkeys")
    }
}
