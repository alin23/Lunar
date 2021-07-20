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
    .advancedSettingsShown,
    .appExceptions,
    .muteVolumeZero,
    .mediaKeysNotified,
    .brightnessKeysEnabled,
    .hideYellowDot,
    .brightnessStep,
    .clamshellModeDetection,
    .contrastStep,
    .debug,
    .didScrollTextField,
    .didSwipeLeft,
    .didSwipeRight,
    .didSwipeToHotkeys,
    .disableControllerVideo,
    .firstRun,
    .firstRunAfterLunar4Upgrade,
    .firstRunAfterM1DDCUpgrade,
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
    .ddcSleepFactor,
]

enum DDCSleepFactor: UInt8, DefaultsSerializable {
    case short = 0
    case medium = 1
    case long = 2
}

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
        guard let displays = CachedDefaults[.displays] else { return nil }
        if let serials = serials {
            return displays.filter { display in serials.contains(display.serial) }
        }
        return displays
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

    static func storeAppException(app: AppException, now: Bool = false) {
        guard var appExceptions = CachedDefaults[.appExceptions] else {
            CachedDefaults[.appExceptions] = [app]
            if now { Defaults[.appExceptions] = [app] }
            return
        }

        if let appIndex = appExceptions.firstIndex(where: { $0.identifier == app.identifier }) {
            appExceptions[appIndex] = app
        } else {
            appExceptions.append(app)
        }

        CachedDefaults[.appExceptions] = appExceptions
        if now { Defaults[.appExceptions] = appExceptions }
    }

    @discardableResult
    func storeDisplays(_ displays: [Display], now: Bool = false) -> [Display] {
        let displays = displays.filter {
            display in !DDC.isBuiltinDisplay(display.id)
        }

        guard let storedDisplays = self.displays() else {
            CachedDefaults[.displays] = displays
            if now { Defaults[.displays] = displays }
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
            display in !DDC.isBuiltinDisplay(display.id)
        }
        CachedDefaults[.displays] = allDisplays
        if now { Defaults[.displays] = allDisplays }

        return allDisplays
    }

    static func storeDisplay(display: Display, now: Bool = false) {
        guard !isGeneric(display.id) else {
            return
        }

        guard var displays = CachedDefaults[.displays] else {
            CachedDefaults[.displays] = [display]
            if now { Defaults[.displays] = [display] }
            return
        }

        if let displayIndex = displays.firstIndex(where: { $0.serial == display.serial }) {
            displays[displayIndex] = display
        } else {
            displays.append(display)
        }

        CachedDefaults[.displays] = displays
        if now { Defaults[.displays] = displays }
    }

    static func firstRunAfterLunar4Upgrade() {
        thisIsFirstRunAfterLunar4Upgrade = true
        DataStore.reset()
        mainThread { appDelegate.onboard() }
    }

    static func firstRunAfterDefaults5Upgrade() {
        thisIsFirstRunAfterDefaults5Upgrade = true
        DataStore.reset()
    }

    static func firstRunAfterM1DDCUpgrade() {
        thisIsFirstRunAfterM1DDCUpgrade = true
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
        mainThread { appDelegate.onboard() }
    }

    override init() {
        super.init()

        NSUserDefaultsController.shared.appliesImmediately = true

        log.debug("Checking First Run")
        if Defaults[.firstRun] == nil {
            DataStore.firstRun()
            Defaults[.firstRun] = true
            Defaults[.firstRunAfterLunar4Upgrade] = true
            Defaults[.firstRunAfterM1DDCUpgrade] = true
            Defaults[.firstRunAfterDefaults5Upgrade] = true
        }

        if Defaults[.firstRunAfterLunar4Upgrade] == nil {
            DataStore.firstRunAfterLunar4Upgrade()
            Defaults[.firstRunAfterLunar4Upgrade] = true
        }

        if Defaults[.firstRunAfterDefaults5Upgrade] == nil {
            DataStore.firstRunAfterDefaults5Upgrade()
            Defaults[.firstRunAfterDefaults5Upgrade] = true
        }

        if Defaults[.firstRunAfterM1DDCUpgrade] == nil {
            DataStore.firstRunAfterM1DDCUpgrade()
            Defaults[.firstRunAfterM1DDCUpgrade] = true
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

class ThreadSafeDictionary<V: Hashable, T>: Collection {
    private var dictionary: [V: T]
    let accessQueue = DispatchQueue(
        label: "Dictionary Barrier Queue",
        attributes: .concurrent
    )
    var startIndex: Dictionary<V, T>.Index {
        dictionary.startIndex
    }

    var endIndex: Dictionary<V, T>.Index {
        dictionary.endIndex
    }

    init(dict: [V: T] = [V: T]()) {
        dictionary = dict
    }

    func index(after i: Dictionary<V, T>.Index) -> Dictionary<V, T>.Index {
        dictionary.index(after: i)
    }

    subscript(key: V) -> T? {
        set(newValue) {
            accessQueue.async(flags: .barrier) { [weak self] in
                self?.dictionary[key] = newValue
            }
        }
        get {
            accessQueue.sync {
                self.dictionary[key]
            }
        }
    }

    // has implicity get
    subscript(index: Dictionary<V, T>.Index) -> Dictionary<V, T>.Element {
        accessQueue.sync {
            self.dictionary[index]
        }
    }

    func removeAll() {
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.dictionary.removeAll()
        }
    }

    func removeValue(forKey key: V) {
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.dictionary.removeValue(forKey: key)
        }
    }
}

enum CachedDefaults {
    static var displaysPublisher = PassthroughSubject<[Display], Never>()
    static var cache: ThreadSafeDictionary<String, AnyCodable> = ThreadSafeDictionary()
    static var locks: [String: NSRecursiveLock] = [:]
    static var observers = Set<AnyCancellable>()
    static var lock = NSRecursiveLock()
    static var semaphore = DispatchSemaphore(value: 1, name: "Cached Defaults Lock")

    static func reset(_ keys: Defaults.AnyKey...) {
        reset(keys)
    }

    static func reset(_ keys: [Defaults.AnyKey]) {
        // semaphore.wait(for: nil, context: "Reset \(keys.map(\.name))")
        // defer { semaphore.signal() }

        lock.around {
            Defaults.reset(keys)
            for key in keys {
                cache.removeValue(forKey: key.name)
            }
        }
    }

    public static subscript<Value: Defaults.Serializable>(key: Defaults.Key<Value>) -> Value {
        get {
            displayEncodingLock.around(ignoreMainThread: true) {
                let lock = locks[key.name] ?? Self.lock
                return lock.around(ignoreMainThread: true) {
                    if let value = cache[key.name]?.value as? Value {
                        return value
                    }

                    return key.suite[key]
                }
            }
        }
        set {
            displayEncodingLock.around(ignoreMainThread: true) {
                guard let lock = locks[key.name] else {
                    Self.lock.around(ignoreMainThread: true) {
                        cache[key.name] = AnyCodable(newValue)
                        asyncNow {
                            Self.lock.around(ignoreMainThread: true) {
                                key.suite[key] = newValue
                            }
                        }
                    }
                    return
                }
                lock.around(ignoreMainThread: true) {
                    cache[key.name] = AnyCodable(newValue)

                    if key == .displays, let displays = newValue as? [Display] {
                        asyncNow { displaysPublisher.send(displays) }
                        asyncNow {
                            lock.around(ignoreMainThread: true) {
                                Defaults.withoutPropagation {
                                    key.suite[key] = newValue
                                }
                            }
                        }
                        return
                    }

                    if key == .hotkeys {
                        asyncNow {
                            lock.around(ignoreMainThread: true) {
                                Defaults.withoutPropagation {
                                    key.suite[key] = newValue
                                }
                            }
                        }
                        return
                    }

                    asyncNow {
                        lock.around(ignoreMainThread: true) {
                            key.suite[key] = newValue
                        }
                    }
                }
            }
        }
    }
}

let displayEncodingLock = NSRecursiveLock()

func cacheKey<Value>(_ key: Defaults.Key<Value>) {
    CachedDefaults.cache[key.name] = AnyCodable(Defaults[key])
    CachedDefaults.locks[key.name] = NSRecursiveLock()
    Defaults.publisher(key).sink { change in
        log.debug("Caching \(key.name) = \(change.newValue)")
        CachedDefaults.cache[key.name] = AnyCodable(change.newValue)
        if key == .displays, let displays = change.newValue as? [Display] {
            asyncNow { CachedDefaults.displaysPublisher.send(displays) }
        }
    }.store(in: &CachedDefaults.observers)
}

func initCache() {
    cacheKey(.hideYellowDot)
    cacheKey(.brightnessKeysEnabled)
    cacheKey(.mediaKeysNotified)
    cacheKey(.muteVolumeZero)
    cacheKey(.advancedSettingsShown)
    cacheKey(.volumeKeysEnabled)
    cacheKey(.mediaKeysControlAllMonitors)
    cacheKey(.didScrollTextField)
    cacheKey(.didSwipeToHotkeys)
    cacheKey(.didSwipeLeft)
    cacheKey(.didSwipeRight)
    cacheKey(.smoothTransition)
    cacheKey(.refreshValues)
    cacheKey(.useCoreDisplay)
    cacheKey(.debug)
    cacheKey(.showQuickActions)
    cacheKey(.manualLocation)
    cacheKey(.startAtLogin)
    cacheKey(.clamshellModeDetection)
    cacheKey(.brightnessStep)
    cacheKey(.contrastStep)
    cacheKey(.volumeStep)
    cacheKey(.syncPollingSeconds)
    cacheKey(.ddcSleepFactor)
    cacheKey(.sensorPollingSeconds)
    cacheKey(.adaptiveBrightnessMode)
    cacheKey(.nonManualMode)
    cacheKey(.overrideAdaptiveMode)
    cacheKey(.reapplyValuesAfterWake)
    cacheKey(.sunrise)
    cacheKey(.sunset)
    cacheKey(.solarNoon)
    cacheKey(.civilTwilightBegin)
    cacheKey(.civilTwilightEnd)
    cacheKey(.nauticalTwilightBegin)
    cacheKey(.nauticalTwilightEnd)
    cacheKey(.astronomicalTwilightBegin)
    cacheKey(.astronomicalTwilightEnd)
    cacheKey(.dayLength)
    cacheKey(.hideMenuBarIcon)
    cacheKey(.showDockIcon)
    cacheKey(.disableControllerVideo)
    cacheKey(.neverAskAboutFlux)
    cacheKey(.hasActiveDisplays)
    cacheKey(.ignoredVolumes)

    cacheKey(.location)
    cacheKey(.secure)
    cacheKey(.wttr)
    cacheKey(.hotkeys)
    cacheKey(.displays)
    cacheKey(.appExceptions)
}

extension Defaults.Keys {
    static let firstRun = Key<Bool?>("firstRun", default: nil)
    static let firstRunAfterLunar4Upgrade = Key<Bool?>("firstRunAfterLunar4Upgrade", default: nil)
    static let firstRunAfterDefaults5Upgrade = Key<Bool?>("firstRunAfterDefaults5Upgrade", default: nil)
    static let firstRunAfterM1DDCUpgrade = Key<Bool?>("firstRunAfterM1DDCUpgrade", default: nil)
    static let hideYellowDot = Key<Bool>("hideYellowDot", default: false)
    static let brightnessKeysEnabled = Key<Bool>("brightnessKeysEnabled", default: true)
    static let mediaKeysNotified = Key<Bool>("mediaKeysNotified", default: false)
    static let muteVolumeZero = Key<Bool>("muteVolumeZero", default: false)
    static let advancedSettingsShown = Key<Bool>("advancedSettingsShown", default: false)
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
    static let ddcSleepFactor = Key<DDCSleepFactor>("ddcSleepFactor", default: .short)
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

    static let silentUpdate = Key<Bool>("SUAutomaticallyUpdate", default: false)
    static let checkForUpdate = Key<Bool>("SUEnableAutomaticChecks", default: true)
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
let advancedSettingsShownPublisher = Defaults.publisher(.advancedSettingsShown).removeDuplicates()
let refreshValuesPublisher = Defaults.publisher(.refreshValues).removeDuplicates()
// let hotkeysPublisher = Defaults.publisher(.hotkeys).removeDuplicates()
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
let hideYellowDotPublisher = Defaults.publisher(.hideYellowDot).removeDuplicates()
let dayMomentsPublisher = Defaults.publisher(keys: .sunrise, .sunset, .solarNoon)
let brightnessKeysEnabledPublisher = Defaults.publisher(.brightnessKeysEnabled).removeDuplicates()
let volumeKeysEnabledPublisher = Defaults.publisher(.volumeKeysEnabled).removeDuplicates()
let mediaKeysControlAllMonitorsPublisher = Defaults.publisher(.mediaKeysControlAllMonitors).removeDuplicates()
let mediaKeysPublisher = Defaults.publisher(keys: .brightnessKeysEnabled, .volumeKeysEnabled, .mediaKeysControlAllMonitors)
let silentUpdatePublisher = Defaults.publisher(.silentUpdate).removeDuplicates()
let checkForUpdatePublisher = Defaults.publisher(.checkForUpdate).removeDuplicates()
