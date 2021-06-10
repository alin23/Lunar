//
//  DataStore.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import AnyCodable
import Cocoa
import Combine
import Defaults

let APP_SETTINGS: [Defaults.Keys] = [
    .adaptiveBrightnessMode,
    .appExceptions,
    .brightnessKeysEnabled,
    .brightnessOnInputChange,
    .brightnessStep,
    .clamshellModeDetection,
    .contrastOnInputChange,
    .contrastStep,
    .curveFactor,
    .debug,
    .didScrollTextField,
    .didSwipeLeft,
    .didSwipeRight,
    .didSwipeToHotkeys,
    .disableControllerVideo,
    .firstRun,
    .firstRunAfterLunar4Upgrade,
    .firstRunAfterDefaults5Upgrade,
    .fKeysAsFunctionKeys,
    .hasActiveDisplays,
    .hideMenuBarIcon,
    .hotkeys,
    .ignoredVolumes,
    .manualLocation,
    .mediaKeysControlAllMonitors,
    .neverAskAboutFlux,
    .nonManualMode,
    .overrideAdaptiveMode,
    .refreshValues,
    .sensorPollingSeconds,
    .showQuickActions,
    .smoothTransition,
    .solarNoon,
    .startAtLogin,
    .sunrise,
    .sunset,
    .syncPollingSeconds,
    .useCoreDisplay,
    .volumeKeysEnabled,
    .volumeStep,
    .reapplyValuesAfterWake,
]

let NON_RESETTABLE_SETTINGS: [Defaults.Keys] = [
    .appExceptions,
    .astronomicalTwilightBegin,
    .astronomicalTwilightEnd,
    .civilTwilightBegin,
    .civilTwilightEnd,
    .dayLength,
    .displays,
    .hotkeys,
    .location,
    .nauticalTwilightBegin,
    .nauticalTwilightEnd,
    .solarNoon,
    .sunrise,
    .sunset,
    .secure,
]

class DataStore: NSObject {
    func displays(serials: [String]? = nil) -> [Display]? {
        serialSync {
            guard let displays = CachedDefaults[.displays] else { return nil }
            if let ids = serials {
                return displays.filter { display in ids.contains(display.serial) }
            }
            return displays
        }
    }

    func appExceptions(identifiers: [String]? = nil) -> [AppException]? {
        guard let apps = CachedDefaults[.appExceptions] else { return nil }
        if let ids = identifiers {
            return apps.filter { app in ids.contains(app.identifier) }
        }
        return apps
    }

    func settingsDictionary() -> [String: String] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var dict: [String: String] = [:]

        for key in APP_SETTINGS {
            switch key {
            case let boolKey as Defaults.Key<Bool>:
                dict[key.name] = try! encoder.encode(Defaults[boolKey]).str()
            case let boolKey as Defaults.Key<Bool?>:
                dict[key.name] = try! encoder.encode(Defaults[boolKey]).str()
            case let stringKey as Defaults.Key<String>:
                dict[key.name] = try! encoder.encode(Defaults[stringKey]).str()
            case let stringKey as Defaults.Key<String?>:
                dict[key.name] = try! encoder.encode(Defaults[stringKey]).str()
            case let valueKey as Defaults.Key<Double>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey]).str()
            case let valueKey as Defaults.Key<Int>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey]).str()
            case let valueKey as Defaults.Key<AdaptiveModeKey>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey]).str()
            case let valueKey as Defaults.Key<[String]>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey]).str()
            case let valueKey as Defaults.Key<[Display]>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey]).str()
            case let valueKey as Defaults.Key<[AppException]?>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey]).str()
            case let valueKey as Defaults.Key<Set<String>>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey]).str()
            case let valueKey as Defaults.Key<Geolocation?>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey]).str()
            case let valueKey as Defaults.Key<UInt64>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey]).str()
            case let valueKey as Defaults.Key<[PersistentHotkey]>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey]).str()
            default:
                continue
            }
        }

        return dict
    }

    static func storeAppException(app: AppException) {
        guard var appExceptions = CachedDefaults[.appExceptions] else {
            CachedDefaults[.appExceptions] = [app]
            return
        }

        if let appIndex = appExceptions.firstIndex(where: { $0.identifier == app.identifier }) {
            appExceptions[appIndex] = app
        } else {
            appExceptions.append(app)
        }

        CachedDefaults[.appExceptions] = appExceptions
    }

    @discardableResult
    func storeDisplays(_ displays: [Display]) -> [Display] {
        let displays = displays.filter {
            display in !SyncMode.isBuiltinDisplay(display.id)
        }

        guard let storedDisplays = self.displays() else {
            CachedDefaults[.displays] = displays
            return displays
        }
        let newDisplaySerials = displays.map(\.serial)
        let newDisplayIDs = displays.map(\.id)

        let inactiveDisplays = storedDisplays.filter { d in !newDisplaySerials.contains(d.serial) }
        for display in inactiveDisplays {
            display.active = false
            while newDisplayIDs.contains(display.id) {
                display.id = UInt32.random(in: 100 ... 100_000)
            }
        }

        let allDisplays = (inactiveDisplays + displays).filter {
            display in !SyncMode.isBuiltinDisplay(display.id)
        }
        CachedDefaults[.displays] = allDisplays

        return allDisplays
    }

    static func storeDisplay(display: Display) {
        guard display.id != TEST_DISPLAY_ID, display.id != GENERIC_DISPLAY_ID else {
            return
        }

        guard var displays = CachedDefaults[.displays] else {
            CachedDefaults[.displays] = [display]
            return
        }

        if let displayIndex = displays.firstIndex(where: { $0.serial == display.serial }) {
            displays[displayIndex] = display
        } else {
            displays.append(display)
        }

        CachedDefaults[.displays] = displays
    }

    static func firstRunAfterLunar4Upgrade() {
        thisIsFirstRunAfterLunar4Upgrade = true
        DataStore.reset()
        mainThread { appDelegate().onboard() }
    }

    static func firstRunAfterDefaults5Upgrade() {
        thisIsFirstRunAfterDefaults5Upgrade = true
        DataStore.reset()
    }

    static func reset() {
        let settings = Set(APP_SETTINGS).subtracting(Set(NON_RESETTABLE_SETTINGS))
        CachedDefaults.reset(Array(settings))
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
                if let exc = CachedDefaults[.appExceptions]?.first(where: { $0.identifier == id }) {
                    log.debug("Existing app for \(app): \(String(describing: exc))")
                    continue
                }
                storeAppException(app: AppException(identifier: id, name: name))
            }
        }
        mainThread { appDelegate().onboard() }
    }

    override init() {
        super.init()

        NSUserDefaultsController.shared.appliesImmediately = true

        log.debug("Checking First Run")
        if Defaults[.firstRun] == nil {
            DataStore.firstRun()
            Defaults[.firstRun] = true
            Defaults[.firstRunAfterLunar4Upgrade] = true
        }

        if Defaults[.firstRunAfterLunar4Upgrade] == nil {
            DataStore.firstRunAfterLunar4Upgrade()
            Defaults[.firstRunAfterLunar4Upgrade] = true
        }

        if Defaults[.firstRunAfterDefaults5Upgrade] == nil {
            DataStore.firstRunAfterDefaults5Upgrade()
            Defaults[.firstRunAfterDefaults5Upgrade] = true
        }

        Defaults[.toolTipDelay] = 1
    }
}

extension Defaults.AnyKey: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    public static func == (lhs: Defaults.Keys, rhs: Defaults.Keys) -> Bool {
        lhs.name == rhs.name
    }
}

extension AnyCodable: Defaults.Serializable {}

enum CachedDefaults {
    static var displaysPublisher = PassthroughSubject<[Display], Never>()
    static var cache: [String: AnyCodable] = [:]
    static var lock = UnfairLock()
    static var semaphore = DispatchSemaphore(value: 1, name: "Cached Defaults Lock")

    static func reset(_ keys: Defaults.AnyKey...) {
        reset(keys)
    }

    static func reset(_ keys: [Defaults.AnyKey]) {
        semaphore.wait(for: nil, context: "Reset \(keys.map(\.name))")
        defer { semaphore.signal() }

        Defaults.reset(keys)
        for key in keys {
            cache.removeValue(forKey: key.name)
        }
    }

    public static subscript<Value: Defaults.Serializable>(key: Defaults.Key<Value>) -> Value {
        get {
            semaphore.wait(for: nil, context: "get \(key.name)")

            if let value = cache[key.name]?.value as? Value {
                semaphore.signal()
                return value
            }
            semaphore.signal()

            return lock.around {
                key.suite[key]
            }
        }
        set {
            semaphore.wait(for: nil, context: "set \(key.name)")
            cache[key.name] = AnyCodable(newValue)
            semaphore.signal()

            if key == .displays, let displays = newValue as? [Display] {
                displaysPublisher.send(displays)
            }

            lock.around {
                key.suite[key] = newValue
            }
        }
    }
}

func initCache() {
    CachedDefaults.cache["curveFactor"] = AnyCodable(Defaults[.curveFactor])
    CachedDefaults.cache["brightnessKeysEnabled"] = AnyCodable(Defaults[.brightnessKeysEnabled])
    CachedDefaults.cache["volumeKeysEnabled"] = AnyCodable(Defaults[.volumeKeysEnabled])
    CachedDefaults.cache["mediaKeysControlAllMonitors"] = AnyCodable(Defaults[.mediaKeysControlAllMonitors])
    CachedDefaults.cache["didScrollTextField"] = AnyCodable(Defaults[.didScrollTextField])
    CachedDefaults.cache["didSwipeToHotkeys"] = AnyCodable(Defaults[.didSwipeToHotkeys])
    CachedDefaults.cache["didSwipeLeft"] = AnyCodable(Defaults[.didSwipeLeft])
    CachedDefaults.cache["didSwipeRight"] = AnyCodable(Defaults[.didSwipeRight])
    CachedDefaults.cache["smoothTransition"] = AnyCodable(Defaults[.smoothTransition])
    CachedDefaults.cache["refreshValues"] = AnyCodable(Defaults[.refreshValues])
    CachedDefaults.cache["useCoreDisplay"] = AnyCodable(Defaults[.useCoreDisplay])
    CachedDefaults.cache["debug"] = AnyCodable(Defaults[.debug])
    CachedDefaults.cache["showQuickActions"] = AnyCodable(Defaults[.showQuickActions])
    CachedDefaults.cache["manualLocation"] = AnyCodable(Defaults[.manualLocation])
    CachedDefaults.cache["startAtLogin"] = AnyCodable(Defaults[.startAtLogin])
    CachedDefaults.cache["clamshellModeDetection"] = AnyCodable(Defaults[.clamshellModeDetection])
    CachedDefaults.cache["brightnessStep"] = AnyCodable(Defaults[.brightnessStep])
    CachedDefaults.cache["contrastStep"] = AnyCodable(Defaults[.contrastStep])
    CachedDefaults.cache["volumeStep"] = AnyCodable(Defaults[.volumeStep])
    CachedDefaults.cache["syncPollingSeconds"] = AnyCodable(Defaults[.syncPollingSeconds])
    CachedDefaults.cache["sensorPollingSeconds"] = AnyCodable(Defaults[.sensorPollingSeconds])
    CachedDefaults.cache["adaptiveBrightnessMode"] = AnyCodable(Defaults[.adaptiveBrightnessMode])
    CachedDefaults.cache["nonManualMode"] = AnyCodable(Defaults[.nonManualMode])
    CachedDefaults.cache["overrideAdaptiveMode"] = AnyCodable(Defaults[.overrideAdaptiveMode])
    CachedDefaults.cache["reapplyValuesAfterWake"] = AnyCodable(Defaults[.reapplyValuesAfterWake])
    CachedDefaults.cache["sunrise"] = AnyCodable(Defaults[.sunrise])
    CachedDefaults.cache["sunset"] = AnyCodable(Defaults[.sunset])
    CachedDefaults.cache["solarNoon"] = AnyCodable(Defaults[.solarNoon])
    CachedDefaults.cache["civilTwilightBegin"] = AnyCodable(Defaults[.civilTwilightBegin])
    CachedDefaults.cache["civilTwilightEnd"] = AnyCodable(Defaults[.civilTwilightEnd])
    CachedDefaults.cache["nauticalTwilightBegin"] = AnyCodable(Defaults[.nauticalTwilightBegin])
    CachedDefaults.cache["nauticalTwilightEnd"] = AnyCodable(Defaults[.nauticalTwilightEnd])
    CachedDefaults.cache["astronomicalTwilightBegin"] = AnyCodable(Defaults[.astronomicalTwilightBegin])
    CachedDefaults.cache["astronomicalTwilightEnd"] = AnyCodable(Defaults[.astronomicalTwilightEnd])
    CachedDefaults.cache["dayLength"] = AnyCodable(Defaults[.dayLength])
    CachedDefaults.cache["hideMenuBarIcon"] = AnyCodable(Defaults[.hideMenuBarIcon])
    CachedDefaults.cache["showDockIcon"] = AnyCodable(Defaults[.showDockIcon])
    CachedDefaults.cache["brightnessOnInputChange"] = AnyCodable(Defaults[.brightnessOnInputChange])
    CachedDefaults.cache["contrastOnInputChange"] = AnyCodable(Defaults[.contrastOnInputChange])
    CachedDefaults.cache["disableControllerVideo"] = AnyCodable(Defaults[.disableControllerVideo])
    CachedDefaults.cache["neverAskAboutFlux"] = AnyCodable(Defaults[.neverAskAboutFlux])
    CachedDefaults.cache["hasActiveDisplays"] = AnyCodable(Defaults[.hasActiveDisplays])
    CachedDefaults.cache["ignoredVolumes"] = AnyCodable(Defaults[.ignoredVolumes])

    CachedDefaults.cache["location"] = AnyCodable(Defaults[.location])
    CachedDefaults.cache["secure"] = AnyCodable(Defaults[.secure])
    CachedDefaults.cache["wttr"] = AnyCodable(Defaults[.wttr])
    CachedDefaults.cache["hotkeys"] = AnyCodable(Defaults[.hotkeys])
    CachedDefaults.cache["displays"] = AnyCodable(Defaults[.displays])
    CachedDefaults.cache["appExceptions"] = AnyCodable(Defaults[.appExceptions])
}

extension Defaults.Keys {
    static let firstRun = Key<Bool?>("firstRun", default: nil)
    static let firstRunAfterLunar4Upgrade = Key<Bool?>("firstRunAfterLunar4Upgrade", default: nil)
    static let firstRunAfterDefaults5Upgrade = Key<Bool?>("firstRunAfterDefaults5Upgrade", default: nil)
    static let curveFactor = Key<Double>("curveFactor", default: 0.5)
    static let brightnessKeysEnabled = Key<Bool>("brightnessKeysEnabled", default: true)
    static let volumeKeysEnabled = Key<Bool>("volumeKeysEnabled", default: true)
    static let mediaKeysControlAllMonitors = Key<Bool>("mediaKeysControlAllMonitors", default: true)
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
    static let startAtLogin = Key<Bool>("startAtLogin", default: true)
    static let clamshellModeDetection = Key<Bool>("clamshellModeDetection", default: true)
    static let brightnessStep = Key<Int>("brightnessStep", default: 6)
    static let contrastStep = Key<Int>("contrastStep", default: 6)
    static let volumeStep = Key<Int>("volumeStep", default: 6)
    static let syncPollingSeconds = Key<Int>("syncPollingSeconds", default: 2)
    static let sensorPollingSeconds = Key<Int>("sensorPollingSeconds", default: 2)
    static let adaptiveBrightnessMode = Key<AdaptiveModeKey>("adaptiveBrightnessMode", default: .sync)
    static let nonManualMode = Key<Bool>("nonManualMode", default: true)
    static let overrideAdaptiveMode = Key<Bool>("overrideAdaptiveMode", default: false)
    static let reapplyValuesAfterWake = Key<Bool>("reapplyValuesAfterWake", default: true)
    static let hotkeys = Key<Set<PersistentHotkey>>("hotkeys", default: Hotkey.defaults)
    static let displays = Key<[Display]?>("displays", default: nil)
    static let appExceptions = Key<[AppException]?>("appExceptions", default: nil)
    static let sunrise = Key<String?>("sunrise", default: nil)
    static let sunset = Key<String?>("sunset", default: nil)
    static let solarNoon = Key<String?>("solarNoon", default: nil)
    static let location = Key<Geolocation?>("location", default: nil)
    static let civilTwilightBegin = Key<String?>("civilTwilightBegin", default: nil)
    static let civilTwilightEnd = Key<String?>("civilTwilightEnd", default: nil)
    static let nauticalTwilightBegin = Key<String?>("nauticalTwilightBegin", default: nil)
    static let nauticalTwilightEnd = Key<String?>("nauticalTwilightEnd", default: nil)
    static let astronomicalTwilightBegin = Key<String?>("astronomicalTwilightBegin", default: nil)
    static let astronomicalTwilightEnd = Key<String?>("astronomicalTwilightEnd", default: nil)
    static let dayLength = Key<UInt64>("dayLength", default: 0)
    static let hideMenuBarIcon = Key<Bool>("hideMenuBarIcon", default: false)
    static let showDockIcon = Key<Bool>("showDockIcon", default: false)
    static let brightnessOnInputChange = Key<Int>("brightnessOnInputChange", default: 100)
    static let contrastOnInputChange = Key<Int>("contrastOnInputChange", default: 70)
    static let disableControllerVideo = Key<Bool>("disableControllerVideo", default: true)
    static let neverAskAboutFlux = Key<Bool>("neverAskAboutFlux", default: false)
    static let hasActiveDisplays = Key<Bool>("hasActiveDisplays", default: true)
    static let toolTipDelay = Key<Int>("NSInitialToolTipDelay", default: 1)
    static let wttr = Key<Wttr?>("wttr")
    static let ignoredVolumes = Key<Set<String>>("ignoredVolumes", default: [])
    static let secure = Key<SecureSettings>("secure", default: SecureSettings())
    static let fKeysAsFunctionKeys = Key<Bool>(
        "com.apple.keyboard.fnState",
        default: true,
        suite: UserDefaults(suiteName: ".GlobalPreferences") ?? .standard
    )
}

let datastore = DataStore()

enum InfoPlistKey {
    static let testMode = "TestMode"
    static let beta = "Beta"
}

enum AppSettings {
    private static var infoDict: [String: Any] {
        if let dict = Bundle.main.infoDictionary {
            return dict
        } else {
            fatalError("Info Plist file not found")
        }
    }

    static let testMode = (infoDict[InfoPlistKey.testMode] as! String) == "YES"
    static let beta = (infoDict[InfoPlistKey.beta] as! String) == "YES"
}

let adaptiveBrightnessModePublisher = Defaults.publisher(.adaptiveBrightnessMode).removeDuplicates()
let startAtLoginPublisher = Defaults.publisher(.startAtLogin).removeDuplicates()
let curveFactorPublisher = Defaults.publisher(.curveFactor).removeDuplicates()
let refreshValuesPublisher = Defaults.publisher(.refreshValues).removeDuplicates()
let hotkeysPublisher = Defaults.publisher(.hotkeys).removeDuplicates()
let hideMenuBarIconPublisher = Defaults.publisher(.hideMenuBarIcon).removeDuplicates()
let showDockIconPublisher = Defaults.publisher(.showDockIcon).removeDuplicates()
let disableControllerVideoPublisher = Defaults.publisher(.disableControllerVideo).removeDuplicates()
let locationPublisher = Defaults.publisher(.location).removeDuplicates()
let brightnessStepPublisher = Defaults.publisher(.brightnessStep).removeDuplicates()
let syncPollingSecondsPublisher = Defaults.publisher(.syncPollingSeconds).removeDuplicates()
let sensorPollingSecondsPublisher = Defaults.publisher(.sensorPollingSeconds).removeDuplicates()
let contrastStepPublisher = Defaults.publisher(.contrastStep).removeDuplicates()
let volumeStepPublisher = Defaults.publisher(.volumeStep).removeDuplicates()
let appExceptionsPublisher = Defaults.publisher(.appExceptions).removeDuplicates()
let securePublisher = Defaults.publisher(.secure).removeDuplicates()
// let displaysPublisher = Defaults.publisher(.displays).removeDuplicates()
let debugPublisher = Defaults.publisher(.debug).removeDuplicates()
let overrideAdaptiveModePublisher = Defaults.publisher(.overrideAdaptiveMode).removeDuplicates()
let dayMomentsPublisher = Defaults.publisher(keys: .sunrise, .sunset, .solarNoon)
let mediaKeysPublisher = Defaults.publisher(keys: .brightnessKeysEnabled, .volumeKeysEnabled, .mediaKeysControlAllMonitors)
