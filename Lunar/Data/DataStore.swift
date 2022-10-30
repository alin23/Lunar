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

// MARK: - BrightnessTransition

enum BrightnessTransition: Int, CaseIterable, Defaults.Serializable {
    case instant
    case smooth
    case slow
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
    // MARK: Lifecycle

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

    // MARK: Internal

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

//// MARK: - Defaults.AnyKey + Hashable
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
    // MARK: Lifecycle

    init(dict: [V: T] = [V: T]()) {
        mutableDictionary = dict
    }

    // MARK: Internal

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

    // MARK: Private

    private var mutableDictionary: [V: T]
}

// MARK: - CachedDefaults

enum CachedDefaults {
    // MARK: Public

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

    // MARK: Internal

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
    cacheKey(.apiKey)

    cacheKey(.location)
    cacheKey(.secure)
    // cacheKey(.wttr)
    cacheKey(.hotkeys)
    cacheKey(.displays)
    cacheKey(.appExceptions)
}

extension Defaults.Keys {
    static let firstRun = Key<Bool?>("firstRun", default: nil)
    static let launchCount = Key<Int>("launchCount", default: 0)
    static let secondPhase = Key<Bool?>("secondPhase", default: nil)
    static let firstRunAfterLunar4Upgrade = Key<Bool?>("firstRunAfterLunar4Upgrade", default: nil)
    static let firstRunAfterDefaults5Upgrade = Key<Bool?>("firstRunAfterDefaults5Upgrade", default: nil)
    static let firstRunAfterBuiltinUpgrade = Key<Bool?>("firstRunAfterBuiltinUpgrade", default: nil)
    static let firstRunAfterHotkeysUpgrade = Key<Bool?>("firstRunAfterHotkeysUpgrade", default: nil)
    static let firstRunAfterM1DDCUpgrade = Key<Bool?>("firstRunAfterM1DDCUpgrade", default: nil)
    static let firstRunAfterExperimentalDDCUpgrade = Key<Bool?>("firstRunAfterExperimentalDDCUpgrade", default: nil)
    static let brightnessKeysEnabled = Key<Bool>("brightnessKeysEnabled", default: true)
    static let mediaKeysNotified = Key<Bool>("mediaKeysNotified", default: false)
    static let detectResponsiveness = Key<Bool>("detectResponsiveness", default: true)
    static let allowHDREnhanceBrightness = Key<Bool>("allowHDREnhanceBrightness", default: false)
    static let allowHDREnhanceContrast = Key<Bool>("allowHDREnhanceContrast", default: false)
    static let muteVolumeZero = Key<Bool>("muteVolumeZero", default: true)
    static let hotkeysAffectBuiltin = Key<Bool>("hotkeysAffectBuiltin", default: true)

    static let brightnessKeysSyncControl = Key<BrightnessKeyAction>("brightnessKeysSyncControl", default: .source)
    static let brightnessKeysControl = Key<BrightnessKeyAction>("brightnessKeysControl", default: .all)
    static let ctrlBrightnessKeysSyncControl = Key<BrightnessKeyAction>("ctrlBrightnessKeysSyncControl", default: .external)
    static let ctrlBrightnessKeysControl = Key<BrightnessKeyAction>("ctrlBrightnessKeysControl", default: .external)
    static let shiftBrightnessKeysSyncControl = Key<BrightnessKeyAction>("shiftBrightnessKeysSyncControl", default: .cursor)
    static let shiftBrightnessKeysControl = Key<BrightnessKeyAction>("shiftBrightnessKeysControl", default: .builtin)

    static let showVirtualDisplays = Key<Bool>("showVirtualDisplays", default: true)
    static let showDummyDisplays = Key<Bool>("showDummyDisplays", default: false)
    static let showAirplayDisplays = Key<Bool>("showAirplayDisplays", default: true)
    static let showProjectorDisplays = Key<Bool>("showProjectorDisplays", default: true)
    static let showDisconnectedDisplays = Key<Bool>("showDisconnectedDisplays", default: false)
    static let autoSubzero = Key<Bool>("autoSubzero", default: true)
    static let autoXdr = Key<Bool>("autoXdr", default: true)
    static let autoXdrSensor = Key<Bool>("autoXdrSensor", default: false)
    static let autoXdrSensorShowOSD = Key<Bool>("autoXdrSensorShowOSD", default: true)
    static let autoXdrSensorLuxThreshold = Key<Float>("autoXdrSensorLuxThreshold", default: XDR_DEFAULT_LUX)
    static let customOSDVerticalOffset = Key<Float>("customOSDVerticalOffset", default: 0)
    static let allowAnySyncSource = Key<Bool>("allowAnySyncSource", default: false)

    static let gammaDisabledCompletely = Key<Bool>("gammaDisabledCompletely", default: false)
    static let oldHdrWorkaround = Key<Bool?>("oldHdrWorkaround", default: nil)
    static let oldAutoXdr = Key<Bool?>("oldAutoXdr", default: nil)
    static let oldAutoXdrSensor = Key<Bool?>("oldAutoXdrSensor", default: nil)
    static let oldAutoSubzero = Key<Bool?>("oldAutoSubzero", default: nil)
    static let oldXdrContrast = Key<Bool?>("oldXdrContrast", default: nil)
    static let oldShowXDRSelector = Key<Bool?>("oldShowXDRSelector", default: nil)
    static let oldAllowHDREnhanceBrightness = Key<Bool?>("oldAllowHDREnhanceBrightness", default: nil)
    static let oldAllowHDREnhanceContrast = Key<Bool?>("oldAllowHDREnhanceContrast", default: nil)

    static let oldReapplyValuesAfterWake = Key<Bool?>("oldReapplyValuesAfterWake", default: nil)
    static let oldDetectResponsiveness = Key<Bool?>("oldDetectResponsiveness", default: nil)
    static let oldBrightnessTransition = Key<BrightnessTransition?>("oldBrightnessTransition", default: nil)

    static let hdrWorkaround = Key<Bool>("hdrWorkaround", default: true)
    static let oldBlackOutMirroring = Key<Bool>("oldBlackOutMirroring", default: false)
    static let disableNightShiftXDR = Key<Bool>("disableNightShiftXDR", default: false)
    static let enableDarkModeXDR = Key<Bool>("enableDarkModeXDR", default: false)
    static let screenBlankingIssueWarningShown = Key<Bool>("screenBlankingIssueWarningShown", default: false)
    static let xdrContrast = Key<Bool>("xdrContrast", default: true)
    static let xdrContrastFactor = Key<Float>("xdrContrastFactor", default: 0.3)
    static let xdrWarningShown = Key<Bool>("xdrWarningShown", default: false)
    static let xdrTipShown = Key<Bool>("xdrTipShown", default: false)
    static let autoXdrTipShown = Key<Bool>("autoXdrTipShown", default: false)
    static let autoBlackoutBuiltin = Key<Bool>("autoBlackoutBuiltin", default: false)
    static let workaroundBuiltinDisplay = Key<Bool>("workaroundBuiltinDisplay", default: false)
    static let streamLogs = Key<Bool>("streamLogs", default: false)
    static let mergeBrightnessContrast = Key<Bool>("mergeBrightnessContrast", default: true)
    static let enableBlackOutKillSwitch = Key<Bool>("enableBlackOutKillSwitch", default: true)
    static let enableSentry = Key<Bool>("enableSentry", default: true)
    static let paddleConsent = Key<Bool>("paddleConsent", default: false)
    static let presets = Key<[Preset]>("presets", default: [])
    static let menuBarClosed = Key<Bool>("menuBarClosed", default: true)
    static let showVolumeSlider = Key<Bool>("showVolumeSlider", default: true)
    static let showRawValues = Key<Bool>("showRawValues", default: false)
    static let showStandardPresets = Key<Bool>("showStandardPresets", default: true)
    static let showCustomPresets = Key<Bool>("showCustomPresets", default: true)
    static let showXDRSelector = Key<Bool>("showXDRSelector", default: true)
    static let showHeaderOnHover = Key<Bool>("showHeaderOnHover", default: false)
    static let showFooterOnHover = Key<Bool>("showFooterOnHover", default: false)
    static let showOptionsMenu = Key<Bool>("showOptionsMenu", default: false)
    static let keepOptionsMenu = Key<Bool>("keepOptionsMenu", default: false)
    static let showSliderValues = Key<Bool>("showSliderValues", default: false)
    static let showAdvancedDisplaySettings = Key<Bool>("showAdvancedDisplaySettings", default: false)
    static let notificationsPermissionsGranted = Key<Bool>("notificationsPermissionsGranted", default: false)
    static let accessibilityPermissionsGranted = Key<Bool>("accessibilityPermissionsGranted", default: false)
    static let cliInstalled = Key<Bool>("cliInstalled", default: false)
    static let lunarProActive = Key<Bool>("lunarProActive", default: true)
    static let lunarProOnTrial = Key<Bool>("lunarProOnTrial", default: true)
    static let lunarProAccessDialogShown = Key<Bool>("lunarProAccessDialogShown", default: false)
    static let completedOnboarding = Key<Bool>("completedOnboarding", default: false)
    static let showTwoSchedules = Key<Bool>("showTwoSchedules", default: false)
    static let showThreeSchedules = Key<Bool>("showThreeSchedules", default: false)
    static let showFourSchedules = Key<Bool>("showFourSchedules", default: false)
    static let showFiveSchedules = Key<Bool>("showFiveSchedules", default: false)
    static let infoMenuShown = Key<Bool>("infoMenuShown", default: true)
    static let allowBlackOutOnSingleScreen = Key<Bool>("allowBlackOutOnSingleScreen", default: false)
    static let moreGraphData = Key<Bool>("moreGraphData", default: false)
    static let enableOrientationHotkeys = Key<Bool>("enableOrientationHotkeys", default: false)
    static let detectKeyHold = Key<Bool>("detectKeyHold", default: true)
    static let volumeKeysEnabled = Key<Bool>("volumeKeysEnabled", default: true)
    static let mediaKeysControlAllMonitors = Key<Bool>("mediaKeysControlAllMonitors", default: false)
    static let brightnessHotkeysControlAllMonitors = Key<Bool>("brightnessHotkeysControlAllMonitors", default: false)
    static let contrastHotkeysControlAllMonitors = Key<Bool>("contrastHotkeysControlAllMonitors", default: false)
    static let volumeHotkeysControlAllMonitors = Key<Bool>("volumeHotkeysControlAllMonitors", default: false)
    static let useAlternateBrightnessKeys = Key<Bool>("useAlternateBrightnessKeys", default: true)
    static let didScrollTextField = Key<Bool>("didScrollTextField", default: false)
    static let didSwipeToHotkeys = Key<Bool>("didSwipeToHotkeys", default: false)
    static let didSwipeLeft = Key<Bool>("didSwipeLeft", default: false)
    static let didSwipeRight = Key<Bool>("didSwipeRight", default: false)
    static let smoothTransition = Key<Bool>("smoothTransition", default: false)
    static let brightnessTransition = Key<BrightnessTransition>("brightnessTransition", default: .smooth)
    static let scheduleTransition = Key<ScheduleTransition>("scheduleTransition", default: .minutes30)
    static let refreshValues = Key<Bool>("refreshValues", default: false)
    static let debug = Key<Bool>("debug", default: false)
    static let trace = Key<Bool>("trace", default: false)
    static let showQuickActions = Key<Bool>("showQuickActions", default: true)
    static let manualLocation = Key<Bool>("manualLocation", default: false)
    static let startAtLogin = Key<Bool>("startAtLogin", default: true)
    static let showBrightnessMenuBar = Key<Bool>("showBrightnessMenuBar", default: false)
    static let showOnlyExternalBrightnessMenuBar = Key<Bool>("showOnlyExternalBrightnessMenuBar", default: false)
    static let showOrientationInQuickActions = Key<Bool>("showOrientationInQuickActions", default: false)
    static let showInputInQuickActions = Key<Bool>("showInputInQuickActions", default: true)
    static let showPowerInQuickActions = Key<Bool>("showPowerInQuickActions", default: true)
    static let neverShowBlackoutPopover = Key<Bool>("neverShowBlackoutPopover", default: false)
    static let clamshellModeDetection = Key<Bool>("clamshellModeDetection", default: true)
    static let brightnessStep = Key<Int>("brightnessStep", default: 6)
    static let contrastStep = Key<Int>("contrastStep", default: 6)
    static let volumeStep = Key<Int>("volumeStep", default: 6)
    static let syncPollingSeconds = Key<Int>("syncPollingSeconds", default: 0)
    static let updateChannel = Key<UpdateChannel>("updateChannel", default: .release)
    static let ddcSleepFactor = Key<DDCSleepFactor>("ddcSleepFactor", default: .short)
    static let ddcSleepLonger = Key<Bool>("ddcSleeplonger", default: false)
    static let menuDensity = Key<MenuDensity>("menuDensity", default: .comfortable)
    static let sensorPollingSeconds = Key<Int>("sensorPollingSeconds", default: 2)
    static let adaptiveBrightnessMode = Key<AdaptiveModeKey>("adaptiveBrightnessMode", default: .sync)
    static let colorScheme = Key<ColorScheme>("colorScheme", default: .system)
    static let nonManualMode = Key<Bool>("nonManualMode", default: true)
    static let clockMode = Key<Bool>("clockMode", default: false)
    static let syncMode = Key<Bool>("syncMode", default: false)
    static let overrideAdaptiveMode = Key<Bool>("overrideAdaptiveMode", default: false)
    static let reapplyValuesAfterWake = Key<Bool>("reapplyValuesAfterWake", default: true)
    static let jitterAfterWake = Key<Bool>("jitterAfterWake", default: false)
    static let waitAfterWakeSeconds = Key<Int>("waitAfterWakeSeconds", default: 30)
    static let delayDDCAfterWake = Key<Bool>("delayDDCAfterWake", default: false)
    static let wakeReapplyTries = Key<Int>("wakeReapplyTries", default: 5)
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
    static let hasActiveExternalDisplays = Key<Bool>("hasActiveExternalDisplays", default: false)
    static let toolTipDelay = Key<Int>("NSInitialToolTipDelay", default: 3)
    static let wttr = Key<Wttr?>("wttr")
    static let ignoredVolumes = Key<Set<String>>("ignoredVolumes", default: [])
    static let secure = Key<SecureSettings>("secure", default: SecureSettings())
    static let fKeysAsFunctionKeys = Key<Bool>(
        "com.apple.keyboard.fnState",
        default: true,
        suite: UserDefaults(suiteName: ".GlobalPreferences") ?? .standard
    )
    static let beepFeedback = Key<Bool>(
        "com.apple.sound.beep.feedback",
        default: false,
        suite: UserDefaults(suiteName: ".GlobalPreferences") ?? .standard
    )

    static let silentUpdate = Key<Bool>("SUAutomaticallyUpdate", default: false)
    static let checkForUpdate = Key<Bool>("SUEnableAutomaticChecks", default: true)
    static let updateCheckInterval = Key<Int>("SUScheduledCheckInterval", default: 86400)
    static let apiKey = Key<String>("apiKey", default: "")
    static let listenForRemoteCommands = Key<Bool>("listenForRemoteCommands", default: false)
    static let neverAskAboutXDR = Key<Bool>("neverAskAboutXDR", default: false)
}

let datastore = DataStore()

// MARK: - InfoPlistKey

enum InfoPlistKey {
    static let testMode = "TestMode"
    static let beta = "Beta"
}

// MARK: - AppSettings

enum AppSettings {
    // MARK: Internal

    static let testMode = (infoDict[InfoPlistKey.testMode] as! String) == "YES"
    static let beta = (infoDict[InfoPlistKey.beta] as! String) == "YES"

    // MARK: Private

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
let startAtLoginPublisher = Defaults.publisher(.startAtLogin).removeDuplicates().filter { $0.oldValue != $0.newValue }
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
