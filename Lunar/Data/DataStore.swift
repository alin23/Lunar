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

extension Defaults.Keys {
    static let presets = Key<[Preset]>("presets", default: [])
    static let updateChannel = Key<UpdateChannel>("updateChannel", default: .release)
    static let ddcSleepFactor = Key<DDCSleepFactor>("ddcSleepFactor", default: .short)
    static let menuDensity = Key<MenuDensity>("menuDensity", default: .comfortable)
    static let colorScheme = Key<ColorScheme>("colorScheme", default: .system)
    static let hotkeys = Key<Set<PersistentHotkey>>("hotkeys", default: Hotkey.defaults)
    static let displays = Key<[Display]?>("displays", default: nil)
    static let appExceptions = Key<[AppException]?>("appExceptions", default: nil)
    static let location = Key<Geolocation?>("location", default: nil)
    static let secure = Key<SecureSettings>("secure", default: SecureSettings())
}

let APP_SETTINGS: [Defaults.Keys] = [
    .oldHdrWorkaround,
    .oldAutoXdr,
    .oldAutoXdrSensor,
    .oldAutoSubzero,
    .oldXdrContrast,
    .oldShowXDRSelector,
    .oldAllowHDREnhanceBrightness,
    .oldAllowHDREnhanceContrast,

    .oldReapplyValuesAfterWake,
    .oldBrightnessTransition,
    .oldDetectResponsiveness,

    .adaptiveBrightnessMode,
    .colorScheme,
    .autoSubzero,
    .customOSDVerticalOffset,
    .autoXdr,
    .autoXdrSensor,
    .autoXdrSensorShowOSD,
    .autoXdrSensorLuxThreshold,
    .allowAnySyncSource,
    .gammaDisabledCompletely,
    .hdrWorkaround,
    .oldBlackOutMirroring,
    .disableNightShiftXDR,
    .enableDarkModeXDR,
    .screenBlankingIssueWarningShown,
    .xdrContrast,
    .xdrContrastFactor,
    .xdrWarningShown,
    .xdrTipShown,
    .autoXdrTipShown,
    .workaroundBuiltinDisplay,
    .autoBlackoutBuiltin,
    .streamLogs,
    .mergeBrightnessContrast,
    .enableBlackOutKillSwitch,
    .enableSentry,
    .paddleConsent,
    .presets,
    .menuBarClosed,
    .showVolumeSlider,
    .showRawValues,
    .showStandardPresets,
    .showCustomPresets,
    .showXDRSelector,
    .showHeaderOnHover,
    .showFooterOnHover,
    .showOptionsMenu,
    .keepOptionsMenu,
    .showSliderValues,
    .showAdvancedDisplaySettings,
    .notificationsPermissionsGranted,
    .accessibilityPermissionsGranted,
    .cliInstalled,
    .lunarProActive,
    .lunarProOnTrial,
    .lunarProAccessDialogShown,
    .completedOnboarding,
    .showTwoSchedules,
    .showThreeSchedules,
    .showFourSchedules,
    .showFiveSchedules,
    .infoMenuShown,
    .allowBlackOutOnSingleScreen,
    .moreGraphData,
    .enableOrientationHotkeys,
    .detectKeyHold,
    .appExceptions,
    .muteVolumeZero,
    .hotkeysAffectBuiltin,
    .showVirtualDisplays,
    .showDummyDisplays,
    .showAirplayDisplays,
    .showProjectorDisplays,
    .showDisconnectedDisplays,
    .mediaKeysNotified,
    .detectResponsiveness,
    .allowHDREnhanceBrightness,
    .allowHDREnhanceContrast,
    .brightnessKeysEnabled,
    .brightnessStep,
    .clamshellModeDetection,
    .contrastStep,
    .debug,
    .trace,
    .didScrollTextField,
    .didSwipeLeft,
    .didSwipeRight,
    .didSwipeToHotkeys,
    .disableControllerVideo,
    .launchCount,
    .firstRun,
    .firstRunAfterLunar4Upgrade,
    .firstRunAfterM1DDCUpgrade,
    .firstRunAfterDefaults5Upgrade,
    .firstRunAfterBuiltinUpgrade,
    .firstRunAfterHotkeysUpgrade,
    .firstRunAfterExperimentalDDCUpgrade,
    .fKeysAsFunctionKeys,
    .hasActiveDisplays,
    .hasActiveExternalDisplays,
    .hideMenuBarIcon,
    .hotkeys,
    .ignoredVolumes,
    .manualLocation,
    .mediaKeysControlAllMonitors,
    .brightnessHotkeysControlAllMonitors,
    .contrastHotkeysControlAllMonitors,
    .volumeHotkeysControlAllMonitors,
    .useAlternateBrightnessKeys,
    .neverAskAboutFlux,
    .apiKey,
    .listenForRemoteCommands,
    .neverAskAboutXDR,
    .autoRestartOnFailedDDC,
    .autoRestartOnFailedDDCSooner,
    .sensorHostname,
    .nonManualMode,
    .clockMode,
    .syncMode,
    .overrideAdaptiveMode,
    .refreshValues,
    .sensorPollingSeconds,
    .showQuickActions,
    .smoothTransition,
    .brightnessTransition,
    .scheduleTransition,
    .solarNoon,
    .startAtLogin,
    .showBrightnessMenuBar,
    .showOnlyExternalBrightnessMenuBar,
    .showOrientationInQuickActions,
    .showInputInQuickActions,
    .sunrise,
    .sunset,
    .syncPollingSeconds,
    .volumeKeysEnabled,
    .volumeStep,
    .reapplyValuesAfterWake,
    .jitterAfterWake,
    .waitAfterWakeSeconds,
    .delayDDCAfterWake,
    .wakeReapplyTries,
    .ddcSleepFactor,
    .ddcSleepLonger,
    .updateChannel,
    .menuDensity,

    .brightnessKeysSyncControl,
    .brightnessKeysControl,
    .ctrlBrightnessKeysSyncControl,
    .ctrlBrightnessKeysControl,
    .shiftBrightnessKeysSyncControl,
    .shiftBrightnessKeysControl,
]

// MARK: - DDCSleepFactor

enum DDCSleepFactor: UInt8, DefaultsSerializable {
    case short = 0
    case medium = 1
    case long = 2
}

// MARK: - UpdateChannel

enum UpdateChannel: UInt8, DefaultsSerializable {
    case release = 0
    case beta = 1
    case alpha = 2
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
    .lunarProActive,
    .lunarProOnTrial,
    .lunarProAccessDialogShown,
    .completedOnboarding,
]

// MARK: - DataStore

class DataStore: NSObject {
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
            Defaults[.firstRunAfterBuiltinUpgrade] = true
            Defaults[.firstRunAfterHotkeysUpgrade] = true
            Defaults[.firstRunAfterExperimentalDDCUpgrade] = true
            shouldOnboard = true
        }

        if Defaults[.firstRunAfterHotkeysUpgrade] == nil {
            DataStore.firstRunAfterHotkeysUpgrade()
            Defaults[.firstRunAfterHotkeysUpgrade] = true
        }

        if Defaults[.firstRunAfterBuiltinUpgrade] == nil {
            DataStore.firstRunAfterBuiltinUpgrade()
            Defaults[.firstRunAfterBuiltinUpgrade] = true
        }

        if Defaults[.firstRunAfterLunar4Upgrade] == nil {
            DataStore.firstRunAfterLunar4Upgrade()
            Defaults[.firstRunAfterLunar4Upgrade] = true
            shouldOnboard = true
        }

        if Defaults[.firstRunAfterDefaults5Upgrade] == nil {
            DataStore.firstRunAfterDefaults5Upgrade()
            Defaults[.firstRunAfterDefaults5Upgrade] = true
        }

        if Defaults[.firstRunAfterM1DDCUpgrade] == nil {
            DataStore.firstRunAfterM1DDCUpgrade()
            Defaults[.firstRunAfterM1DDCUpgrade] = true
        }

        if Defaults[.firstRunAfterExperimentalDDCUpgrade] == nil {
            DataStore.firstRunAfterExperimentalDDCUpgrade()
            Defaults[.firstRunAfterExperimentalDDCUpgrade] = true
        }

        Defaults[.toolTipDelay] = 5
        if !shouldOnboard, !Defaults[.completedOnboarding] {
            Defaults[.completedOnboarding] = true
            Defaults[.lunarProAccessDialogShown] = true
        }
    }

    var shouldOnboard = false

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

    static func firstRunAfterHotkeysUpgrade() {
        thisIsFirstRunAfterHotkeysUpgrade = true
        CachedDefaults[.brightnessKeysControl] = CachedDefaults[.mediaKeysControlAllMonitors] ? .all : .cursor
        CachedDefaults[.ctrlBrightnessKeysSyncControl] = CachedDefaults[.mediaKeysControlAllMonitors] ? .external : .cursor
        CachedDefaults[.ctrlBrightnessKeysControl] = CachedDefaults[.mediaKeysControlAllMonitors] ? .external : .cursor
        CachedDefaults[.brightnessTransition] = CachedDefaults[.smoothTransition] ? .smooth : .instant
        CachedDefaults.reset(.mediaKeysControlAllMonitors)
    }

    static func firstRunAfterBuiltinUpgrade() {
        thisIsFirstRunAfterBuiltinUpgrade = true
        guard let displays = CachedDefaults[.displays] else { return }

        displays.filter(\.isSmartBuiltin).forEach { display in
            display.enabledControls[.gamma] = false
            display.save()
        }
    }

    static func firstRunAfterLunar4Upgrade() {
        thisIsFirstRunAfterLunar4Upgrade = true
        DataStore.reset()
    }

    static func firstRunAfterDefaults5Upgrade() {
        thisIsFirstRunAfterDefaults5Upgrade = true
        DataStore.reset()
    }

    static func firstRunAfterM1DDCUpgrade() {
        thisIsFirstRunAfterM1DDCUpgrade = true
    }

    static func firstRunAfterExperimentalDDCUpgrade() {
        thisIsFirstRunAfterExperimentalDDCUpgrade = true
        CachedDefaults[.refreshValues] = false
    }

    static func reset() {
        let settings = Set(APP_SETTINGS).subtracting(Set(NON_RESETTABLE_SETTINGS))
        CachedDefaults.reset(Array(settings))
    }

    static func firstRun() {
        log.debug("First run")
        thisIsFirstRun = true
    }

    func displays(serials: [String]? = nil) -> [Display]? {
        guard let displays = CachedDefaults[.displays] else { return nil }
        if let serials {
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
            case let valueKey as Defaults.Key<BrightnessKeyAction>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey].rawValue).str()
            case let valueKey as Defaults.Key<DDCSleepFactor>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey].rawValue).str()
            case let valueKey as Defaults.Key<UpdateChannel>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey].rawValue).str()
            case let valueKey as Defaults.Key<ScheduleTransition>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey].rawValue).str()
            case let valueKey as Defaults.Key<BrightnessTransition>:
                dict[key.name] = try! encoder.encode(Defaults[valueKey].rawValue).str()
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

    @discardableResult
    func storeDisplays(_ displays: [Display], now: Bool = false) -> [Display] {
        guard let storedDisplays = self.displays() else {
            CachedDefaults[.displays] = displays
            if now { Defaults[.displays] = displays }
            return displays
        }
        let newDisplaySerials = displays.map(\.serial)
        let newDisplayIDs = displays.map(\.id)

        let inactiveDisplays = storedDisplays.filter { d in !newDisplaySerials.contains(d.serial) }
        for display in inactiveDisplays {
            mainThread { display.active = false }
            while newDisplayIDs.contains(display.id) {
                display.id = UInt32.random(in: 100 ... 100_000)
            }
        }

        let allDisplays = (inactiveDisplays + displays)
        CachedDefaults[.displays] = allDisplays
        if now { Defaults[.displays] = allDisplays }

        return allDisplays
    }
}

// MARK: - AnyCodable + Defaults.Serializable

//
//
// extension Defaults.AnyKey: Hashable {
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(name)
//    }
//
//    public static func == (lhs: Defaults.Keys, rhs: Defaults.Keys) -> Bool {
//        lhs.name == rhs.name
//    }
// }

extension AnyCodable: Defaults.Serializable {}

// MARK: - ThreadSafeDictionary

class ThreadSafeDictionary<V: Hashable, T>: Collection {
    init(dict: [V: T] = [V: T]()) {
        mutableDictionary = dict
    }

    let accessQueue = DispatchQueue(
        label: "Dictionary Barrier Queue",
        attributes: .concurrent
    )

    var dictionary: [V: T] {
        accessQueue.sync {
            let dict = Dictionary(uniqueKeysWithValues: mutableDictionary.map { ($0.key, $0.value) })
            return dict
        }
    }

    var startIndex: Dictionary<V, T>.Index {
        mutableDictionary.startIndex
    }

    var endIndex: Dictionary<V, T>.Index {
        mutableDictionary.endIndex
    }

    func index(after i: Dictionary<V, T>.Index) -> Dictionary<V, T>.Index {
        mutableDictionary.index(after: i)
    }

    subscript(key: V) -> T? {
        set(newValue) {
            accessQueue.async(flags: .barrier) { [weak self] in
                self?.mutableDictionary[key] = newValue
            }
        }
        get {
            accessQueue.sync {
                self.mutableDictionary[key]
            }
        }
    }

    // has implicity get
    subscript(index: Dictionary<V, T>.Index) -> Dictionary<V, T>.Element {
        accessQueue.sync {
            self.mutableDictionary[index]
        }
    }

    func removeAll() {
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.mutableDictionary.removeAll()
        }
    }

    func removeValue(forKey key: V) {
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.mutableDictionary.removeValue(forKey: key)
        }
    }

    private var mutableDictionary: [V: T]
}

// MARK: - CachedDefaults

enum CachedDefaults {
    public static subscript<Value: Defaults.Serializable>(key: Defaults.Key<Value>) -> Value {
        get {
            mainThread {
                if let value = cache[key.name]?.value as? Value {
                    return value
                }

                let value = key.suite[key]

                cache[key.name] = AnyCodable(value)
                return value
            }
        }
        set {
            mainAsync {
                cache[key.name] = AnyCodable(newValue)
                if key == .displays {
                    Defaults.withoutPropagation {
                        key.suite[key] = newValue
                    }
                    return
                }

                if key == .hotkeys {
                    Defaults.withoutPropagation {
                        key.suite[key] = newValue
                    }
                    return
                }

                key.suite[key] = newValue

                guard !crumbKeys.contains(key) else { return }
                crumb("Set \(key.name) to \(newValue)", level: .info, category: "Settings")
            }
            return
        }
    }

    static var crumbKeys: Set<Defaults.AnyKey> = [
        .adaptiveBrightnessMode,
        .astronomicalTwilightBegin,
        .astronomicalTwilightEnd,
        .civilTwilightBegin,
        .civilTwilightEnd,
        .clockMode,
        .dayLength,
        .debug,
        .hasActiveDisplays,
        .hasActiveExternalDisplays,
        .location,
        .nauticalTwilightBegin,
        .nauticalTwilightEnd,
        .nonManualMode,
        .secure,
        .solarNoon,
        .streamLogs,
        .sunrise,
        .sunset,
        .syncMode,
        .hotkeys,
        .displays,
        .apiKey,
    ]

    static var cache: ThreadSafeDictionary<String, AnyCodable> = ThreadSafeDictionary()
    static var locks: [String: NSRecursiveLock] = [:]
    static var observers = Set<AnyCancellable>()
    static var lock = NSRecursiveLock()
    static var semaphore = DispatchSemaphore(value: 1, name: "Cached Defaults Lock")

    static func reset(_ keys: Defaults.AnyKey...) {
        reset(keys)
    }

    static func reset(_ keys: [Defaults.AnyKey]) {
        lock.around {
            Defaults.reset(keys)
            for key in keys {
                cache.removeValue(forKey: key.name)
            }
        }
    }
}

let displayEncodingLock = NSRecursiveLock()

func cacheKey(_ key: Defaults.Key<some Any>, load: Bool = true) {
    if load {
        CachedDefaults.cache[key.name] = AnyCodable(Defaults[key])
    }
    CachedDefaults.locks[key.name] = NSRecursiveLock()
    if key == .secondPhase {
        initSecondPhase()
    }
    Defaults.publisher(key).dropFirst().sink { change in
        // log.debug("Caching \(key.name) = \(change.newValue)")
        CachedDefaults.cache[key.name] = AnyCodable(change.newValue)

        guard !CachedDefaults.crumbKeys.contains(key) else { return }
        crumb("Set \(key.name) to \(change.newValue)", level: .info, category: "Settings")
    }.store(in: &CachedDefaults.observers)
}

func initCache() {
    cacheKey(.brightnessKeysEnabled)
    cacheKey(.mediaKeysNotified)
    cacheKey(.detectResponsiveness)
    cacheKey(.allowHDREnhanceBrightness)
    cacheKey(.allowHDREnhanceContrast)
    cacheKey(.muteVolumeZero)
    cacheKey(.hotkeysAffectBuiltin)

    cacheKey(.brightnessKeysSyncControl)
    cacheKey(.brightnessKeysControl)
    cacheKey(.ctrlBrightnessKeysSyncControl)
    cacheKey(.ctrlBrightnessKeysControl)
    cacheKey(.shiftBrightnessKeysSyncControl)
    cacheKey(.shiftBrightnessKeysControl)

    cacheKey(.showVirtualDisplays)
    cacheKey(.showDummyDisplays)
    cacheKey(.showAirplayDisplays)
    cacheKey(.showProjectorDisplays)
    cacheKey(.showDisconnectedDisplays)

    cacheKey(.autoSubzero)
    cacheKey(.autoXdr)
    cacheKey(.autoXdrSensor)
    cacheKey(.autoXdrSensorShowOSD)
    cacheKey(.autoXdrSensorLuxThreshold)
    cacheKey(.customOSDVerticalOffset)
    cacheKey(.allowAnySyncSource)

    cacheKey(.gammaDisabledCompletely)
    cacheKey(.oldHdrWorkaround)
    cacheKey(.oldAutoXdr)
    cacheKey(.oldAutoXdrSensor)
    cacheKey(.oldAutoSubzero)
    cacheKey(.oldXdrContrast)
    cacheKey(.oldShowXDRSelector)
    cacheKey(.oldAllowHDREnhanceBrightness)
    cacheKey(.oldAllowHDREnhanceContrast)

    cacheKey(.oldReapplyValuesAfterWake)
    cacheKey(.oldBrightnessTransition)
    cacheKey(.oldDetectResponsiveness)

    cacheKey(.hdrWorkaround)
    cacheKey(.oldBlackOutMirroring)
    cacheKey(.disableNightShiftXDR)
    cacheKey(.enableDarkModeXDR)
    cacheKey(.screenBlankingIssueWarningShown)
    cacheKey(.xdrContrast)
    cacheKey(.xdrContrastFactor)
    cacheKey(.xdrWarningShown)
    cacheKey(.xdrTipShown)
    cacheKey(.autoXdrTipShown)
    cacheKey(.autoBlackoutBuiltin)
    cacheKey(.workaroundBuiltinDisplay)
    cacheKey(.streamLogs)
    cacheKey(.mergeBrightnessContrast)
    cacheKey(.enableBlackOutKillSwitch)
    cacheKey(.enableSentry)
    cacheKey(.paddleConsent)
    cacheKey(.presets)
    cacheKey(.showVolumeSlider)
    cacheKey(.showRawValues)
    cacheKey(.showStandardPresets)
    cacheKey(.showCustomPresets)
    cacheKey(.showXDRSelector)
    cacheKey(.showHeaderOnHover)
    cacheKey(.showFooterOnHover)
    cacheKey(.showOptionsMenu)
    cacheKey(.keepOptionsMenu)
    cacheKey(.showSliderValues)
    cacheKey(.showAdvancedDisplaySettings)
    cacheKey(.lunarProActive)
    cacheKey(.lunarProOnTrial)
    cacheKey(.lunarProAccessDialogShown)
    cacheKey(.completedOnboarding)
    cacheKey(.showTwoSchedules)
    cacheKey(.showThreeSchedules)
    cacheKey(.showFourSchedules)
    cacheKey(.showFiveSchedules)
    cacheKey(.infoMenuShown)
    cacheKey(.allowBlackOutOnSingleScreen)
    cacheKey(.moreGraphData)
    cacheKey(.enableOrientationHotkeys)
    cacheKey(.detectKeyHold)
    cacheKey(.volumeKeysEnabled)
    cacheKey(.mediaKeysControlAllMonitors)
    cacheKey(.brightnessHotkeysControlAllMonitors)
    cacheKey(.contrastHotkeysControlAllMonitors)
    cacheKey(.volumeHotkeysControlAllMonitors)
    cacheKey(.useAlternateBrightnessKeys)
    cacheKey(.didScrollTextField)
    cacheKey(.didSwipeToHotkeys)
    cacheKey(.didSwipeLeft)
    cacheKey(.didSwipeRight)
    cacheKey(.smoothTransition)
    cacheKey(.brightnessTransition)
    cacheKey(.scheduleTransition)
    cacheKey(.refreshValues)
    cacheKey(.debug)
    cacheKey(.trace)
    cacheKey(.showQuickActions)
    cacheKey(.manualLocation)
    cacheKey(.startAtLogin)
    cacheKey(.showBrightnessMenuBar)
    cacheKey(.showOnlyExternalBrightnessMenuBar)
    cacheKey(.showOrientationInQuickActions)
    cacheKey(.showInputInQuickActions)
    cacheKey(.clamshellModeDetection)
    cacheKey(.brightnessStep)
    cacheKey(.contrastStep)
    cacheKey(.volumeStep)
    cacheKey(.syncPollingSeconds)
    cacheKey(.ddcSleepFactor)
    cacheKey(.ddcSleepLonger)
    cacheKey(.updateChannel)
    cacheKey(.menuDensity)
    cacheKey(.sensorPollingSeconds)
    cacheKey(.adaptiveBrightnessMode)
    cacheKey(.colorScheme)
    cacheKey(.nonManualMode)
    cacheKey(.clockMode)
    cacheKey(.syncMode)
    cacheKey(.overrideAdaptiveMode)
    cacheKey(.reapplyValuesAfterWake)
    cacheKey(.jitterAfterWake)
    cacheKey(.waitAfterWakeSeconds)
    cacheKey(.delayDDCAfterWake)
    cacheKey(.wakeReapplyTries)
    cacheKey(.sunrise)
    cacheKey(.sunset)
    cacheKey(.solarNoon)
    cacheKey(.civilTwilightBegin)
    cacheKey(.civilTwilightEnd)
    cacheKey(.secondPhase)
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
    cacheKey(.hasActiveExternalDisplays)
    cacheKey(.ignoredVolumes)
    cacheKey(.listenForRemoteCommands)
    cacheKey(.neverAskAboutXDR)
    cacheKey(.autoRestartOnFailedDDC)
    cacheKey(.autoRestartOnFailedDDCSooner)
    cacheKey(.sensorHostname)
    cacheKey(.apiKey)

    cacheKey(.location)
    cacheKey(.secure)
    // cacheKey(.wttr)
    cacheKey(.hotkeys)
    cacheKey(.displays)
    cacheKey(.appExceptions)
}

let datastore = DataStore()

// MARK: - InfoPlistKey

enum InfoPlistKey {
    static let testMode = "TestMode"
    static let beta = "Beta"
}

// MARK: - AppSettings

enum AppSettings {
    static let testMode = (infoDict[InfoPlistKey.testMode] as! String) == "YES"
    static let beta = (infoDict[InfoPlistKey.beta] as! String) == "YES"

    private static var infoDict: [String: Any] {
        if let dict = Bundle.main.infoDictionary {
            return dict
        } else {
            fatalError("Info Plist file not found")
        }
    }
}

let adaptiveBrightnessModePublisher = Defaults.publisher(.adaptiveBrightnessMode)

let colorSchemePublisher = Defaults.publisher(.colorScheme).removeDuplicates().dropFirst().filter { $0.oldValue != $0.newValue }
let startAtLoginPublisher = Defaults.publisher(.startAtLogin).removeDuplicates().dropFirst().filter { $0.oldValue != $0.newValue }
let showBrightnessMenuBarPublisher = Defaults.publisher(.showBrightnessMenuBar).removeDuplicates().dropFirst()
    .filter { $0.oldValue != $0.newValue }
let showOnlyExternalBrightnessMenuBarPublisher = Defaults.publisher(.showOnlyExternalBrightnessMenuBar).removeDuplicates().dropFirst()
    .filter { $0.oldValue != $0.newValue }
let showOrientationInQuickActionsPublisher = Defaults.publisher(.showOrientationInQuickActions).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let autoBlackoutBuiltinPublisher = Defaults.publisher(.autoBlackoutBuiltin).removeDuplicates().filter { $0.oldValue != $0.newValue }
let autoSubzeroPublisher = Defaults.publisher(.autoSubzero).removeDuplicates().dropFirst()
    .filter { $0.oldValue != $0.newValue }
let autoXdrPublisher = Defaults.publisher(.autoXdr).removeDuplicates().dropFirst().filter { $0.oldValue != $0.newValue }
let autoXdrSensorPublisher = Defaults.publisher(.autoXdrSensor).removeDuplicates().dropFirst().filter { $0.oldValue != $0.newValue }
let autoXdrSensorShowOSDPublisher = Defaults.publisher(.autoXdrSensorShowOSD).removeDuplicates().dropFirst()
    .filter { $0.oldValue != $0.newValue }
let autoXdrSensorLuxThresholdPublisher = Defaults.publisher(.autoXdrSensorLuxThreshold).removeDuplicates().dropFirst()
    .filter { $0.oldValue != $0.newValue }
let customOSDVerticalOffsetPublisher = Defaults.publisher(.customOSDVerticalOffset).removeDuplicates().dropFirst()
    .filter { $0.oldValue != $0.newValue }
let allowAnySyncSourcePublisher = Defaults.publisher(.allowAnySyncSource).removeDuplicates().dropFirst()
    .filter { $0.oldValue != $0.newValue }
let gammaDisabledCompletelyPublisher = Defaults.publisher(.gammaDisabledCompletely).removeDuplicates().dropFirst()
    .filter { $0.oldValue != $0.newValue }
let hdrWorkaroundPublisher = Defaults.publisher(.hdrWorkaround).removeDuplicates().dropFirst().filter { $0.oldValue != $0.newValue }
let oldBlackOutMirroringPublisher = Defaults.publisher(.oldBlackOutMirroring).removeDuplicates().dropFirst()
    .filter { $0.oldValue != $0.newValue }
let xdrContrastPublisher = Defaults.publisher(.xdrContrast).removeDuplicates().dropFirst().filter { $0.oldValue != $0.newValue }
let xdrContrastFactorPublisher = Defaults.publisher(.xdrContrastFactor).removeDuplicates().dropFirst().filter { $0.oldValue != $0.newValue }
let allowHDREnhanceContrastPublisher = Defaults.publisher(.allowHDREnhanceContrast).removeDuplicates().dropFirst()
    .filter { $0.oldValue != $0.newValue }
let allowHDREnhanceBrightnessPublisher = Defaults.publisher(.allowHDREnhanceBrightness).removeDuplicates().dropFirst()
    .filter { $0.oldValue != $0.newValue }
let workaroundBuiltinDisplayPublisher = Defaults.publisher(.workaroundBuiltinDisplay).removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let streamLogsPublisher = Defaults.publisher(.streamLogs).removeDuplicates().filter { $0.oldValue != $0.newValue }
let mergeBrightnessContrastPublisher = Defaults.publisher(.mergeBrightnessContrast).removeDuplicates().filter { $0.oldValue != $0.newValue }
let enableSentryPublisher = Defaults.publisher(.enableSentry).dropFirst().removeDuplicates().filter { $0.oldValue != $0.newValue }
let waitAfterWakeSecondsPublisher = Defaults.publisher(.waitAfterWakeSeconds).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let delayDDCAfterWakePublisher = Defaults.publisher(.delayDDCAfterWake).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let showVolumeSliderPublisher = Defaults.publisher(.showVolumeSlider).removeDuplicates().filter { $0.oldValue != $0.newValue }
let showSliderValuesPublisher = Defaults.publisher(.showSliderValues).removeDuplicates().filter { $0.oldValue != $0.newValue }
let showAdvancedDisplaySettingsPublisher = Defaults.publisher(.showAdvancedDisplaySettings).removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let lunarProActivePublisher = Defaults.publisher(.lunarProActive).removeDuplicates().filter { $0.oldValue != $0.newValue }
let infoMenuShownPublisher = Defaults.publisher(.infoMenuShown).removeDuplicates().filter { $0.oldValue != $0.newValue }
let showTwoSchedulesPublisher = Defaults.publisher(.showTwoSchedules).removeDuplicates().filter { $0.oldValue != $0.newValue }
let showThreeSchedulesPublisher = Defaults.publisher(.showThreeSchedules).removeDuplicates().filter { $0.oldValue != $0.newValue }
let showFourSchedulesPublisher = Defaults.publisher(.showFourSchedules).removeDuplicates().filter { $0.oldValue != $0.newValue }
let showFiveSchedulesPublisher = Defaults.publisher(.showFiveSchedules).removeDuplicates().filter { $0.oldValue != $0.newValue }
let allowBlackOutOnSingleScreenPublisher = Defaults.publisher(.allowBlackOutOnSingleScreen).removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let moreGraphDataPublisher = Defaults.publisher(.moreGraphData).removeDuplicates().filter { $0.oldValue != $0.newValue }
let enableOrientationHotkeysPublisher = Defaults.publisher(.enableOrientationHotkeys).removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let detectKeyHoldPublisher = Defaults.publisher(.detectKeyHold).removeDuplicates().filter { $0.oldValue != $0.newValue }
let refreshValuesPublisher = Defaults.publisher(.refreshValues).removeDuplicates().filter { $0.oldValue != $0.newValue }
let hideMenuBarIconPublisher = Defaults.publisher(.hideMenuBarIcon).removeDuplicates().filter { $0.oldValue != $0.newValue }
let showDockIconPublisher = Defaults.publisher(.showDockIcon).removeDuplicates().filter { $0.oldValue != $0.newValue }
let disableControllerVideoPublisher = Defaults.publisher(.disableControllerVideo).removeDuplicates().filter { $0.oldValue != $0.newValue }
let locationPublisher = Defaults.publisher(.location).removeDuplicates().filter { $0.oldValue != $0.newValue }
let brightnessStepPublisher = Defaults.publisher(.brightnessStep).removeDuplicates().filter { $0.oldValue != $0.newValue }
let syncPollingSecondsPublisher = Defaults.publisher(.syncPollingSeconds).removeDuplicates().filter { $0.oldValue != $0.newValue }
let sensorPollingSecondsPublisher = Defaults.publisher(.sensorPollingSeconds).removeDuplicates().filter { $0.oldValue != $0.newValue }
let contrastStepPublisher = Defaults.publisher(.contrastStep).removeDuplicates().filter { $0.oldValue != $0.newValue }
let volumeStepPublisher = Defaults.publisher(.volumeStep).removeDuplicates().filter { $0.oldValue != $0.newValue }
let appExceptionsPublisher = Defaults.publisher(.appExceptions).removeDuplicates().filter { $0.oldValue != $0.newValue }
let securePublisher = Defaults.publisher(.secure).removeDuplicates().filter { $0.oldValue != $0.newValue }
let debugPublisher = Defaults.publisher(.debug).removeDuplicates().filter { $0.oldValue != $0.newValue }
let tracePublisher = Defaults.publisher(.trace).removeDuplicates().filter { $0.oldValue != $0.newValue }
let overrideAdaptiveModePublisher = Defaults.publisher(.overrideAdaptiveMode).removeDuplicates().filter { $0.oldValue != $0.newValue }
let dayMomentsPublisher = Defaults.publisher(keys: .sunrise, .sunset, .solarNoon)
let brightnessKeysEnabledPublisher = Defaults.publisher(.brightnessKeysEnabled).removeDuplicates().filter { $0.oldValue != $0.newValue }
let brightnessTransitionPublisher = Defaults.publisher(.brightnessTransition).removeDuplicates().filter { $0.oldValue != $0.newValue }
let volumeKeysEnabledPublisher = Defaults.publisher(.volumeKeysEnabled).removeDuplicates().filter { $0.oldValue != $0.newValue }
let useAlternateBrightnessKeysPublisher = Defaults.publisher(.useAlternateBrightnessKeys).removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let mediaKeysPublisher = Defaults.publisher(
    keys: .brightnessKeysEnabled,
    .volumeKeysEnabled,
    .volumeHotkeysControlAllMonitors,
    .brightnessHotkeysControlAllMonitors,
    .contrastHotkeysControlAllMonitors
)
let silentUpdatePublisher = Defaults.publisher(.silentUpdate).removeDuplicates().filter { $0.oldValue != $0.newValue }
let checkForUpdatePublisher = Defaults.publisher(.checkForUpdate).removeDuplicates().filter { $0.oldValue != $0.newValue }
let showDummyDisplaysPublisher = Defaults.publisher(.showDummyDisplays).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let showVirtualDisplaysPublisher = Defaults.publisher(.showVirtualDisplays).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let showAirplayDisplaysPublisher = Defaults.publisher(.showAirplayDisplays).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let showProjectorDisplaysPublisher = Defaults.publisher(.showProjectorDisplays).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let showDisconnectedDisplaysPublisher = Defaults.publisher(.showDisconnectedDisplays).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let detectResponsivenessPublisher = Defaults.publisher(.detectResponsiveness).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let nonManualModePublisher = Defaults.publisher(.nonManualMode).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let listenForRemoteCommandsPublisher = Defaults.publisher(.listenForRemoteCommands).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let ddcSleepLongerPublisher = Defaults.publisher(.ddcSleepLonger).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let ddcSleepFactorPublisher = Defaults.publisher(.ddcSleepFactor).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
let updateChannelPublisher = Defaults.publisher(.updateChannel).dropFirst().removeDuplicates()
    .filter { $0.oldValue != $0.newValue }
