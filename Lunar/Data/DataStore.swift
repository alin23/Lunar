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

#if arch(arm64)
    let ARM_KEYS: [Defaults.Keys] = []
#else
    let ARM_KEYS: [Defaults.Keys] = []
#endif

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
    .fullRangeMaxOnDoublePress,
    .autoXdr,
    .autoXdrSensor,
    .autoXdrSensorShowOSD,
    .hideOSD,
    .autoXdrSensorLuxThreshold,
    .allowAnySyncSource,
    .gammaDisabledCompletely,
    .hdrWorkaround,
    .oldBlackOutMirroring,
    .newBlackOutDisconnect,
    .disableNightShiftXDR,
    .enableDarkModeXDR,
    .screenBlankingIssueWarningShown,
    .xdrContrast,
    .xdrContrastFactor,
    .subzeroContrast,
    .subzeroContrastFactor,
    .keyboardBacklightOffBlackout,
    .xdrWarningShown,
    .xdrTipShown,
    .autoXdrTipShown,
    .workaroundBuiltinDisplay,
    .autoBlackoutBuiltin,
    .mergeBrightnessContrast,
    .enableBlackOutKillSwitch,
    .enableSentry,
    .paddleConsent,
    .presets,
    .menuBarClosed,
    .showVolumeSlider,
    .showRawValues,
    .showNitsText,
    .showNitsOSD,
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
    .sleepInClamshellMode,
    .disableCliffDetection,
    .disableBrightnessObservers,
    .contrastStep,
    .didScrollTextField,
    .didSwipeLeft,
    .didSwipeRight,
    .didSwipeToHotkeys,
    .disableControllerVideo,
    .launchCount,
    .firstRun,
    .firstRunAfterLunar4Upgrade,
    .firstRunAfterLunar6Upgrade,
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
    .volumeKeysControlAllMonitors,
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
    .sensorPort,
    .sensorPathPrefix,
    .disableExternalSensorWhenNoExternalMonitor,
    .nonManualMode,
    .curveMode,
    .hasBuiltin,
    .clockMode,
    .fullyAutomatedClockMode,
    .syncMode,
    .overrideAdaptiveMode,
    .refreshValues,
    .sensorPollingSeconds,
    .showQuickActions,
    .dimNonEssentialUI,
    .smoothTransition,
    .brightnessTransition,
    .scheduleTransition,
    .solarNoon,
    .startAtLogin,
    .showBrightnessMenuBar,
    .showOnlyExternalBrightnessMenuBar,
    .showOrientationInQuickActions,
    .showOrientationForBuiltinInQuickActions,
    .showInputInQuickActions,
    .sunrise,
    .sunset,
    .syncPollingSeconds,
    .syncNits,
    .volumeKeysEnabled,
    .volumeStep,
    .reapplyValuesAfterWake,
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

] + ARM_KEYS

// MARK: - DDCSleepFactor

enum DDCSleepFactor: UInt8, Defaults.Serializable {
    case short = 0
    case medium = 1
    case long = 2
}

// MARK: - UpdateChannel

enum UpdateChannel: UInt8, Defaults.Serializable {
    case release = 0
    case beta = 1
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

final class DataStore: NSObject {
    override init() {
        super.init()

        NSUserDefaultsController.shared.appliesImmediately = true

        log.debug("Checking First Run")
        if Defaults[.firstRun] == nil {
            DataStore.firstRun()
            Defaults[.firstRun] = true
            Defaults[.firstRunAfterLunar4Upgrade] = true
            Defaults[.firstRunAfterLunar6Upgrade] = true
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

        if Defaults[.firstRunAfterLunar6Upgrade] == nil {
            DataStore.firstRunAfterLunar6Upgrade()
            Defaults[.firstRunAfterLunar6Upgrade] = true
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
        CachedDefaults[.brightnessKeysControl] = UserDefaults.standard.bool(forKey: "mediaKeysControlAllMonitors") ? .all : .cursor
        CachedDefaults[.ctrlBrightnessKeysSyncControl] = UserDefaults.standard.bool(forKey: "mediaKeysControlAllMonitors") ? .external : .cursor
        CachedDefaults[.ctrlBrightnessKeysControl] = UserDefaults.standard.bool(forKey: "mediaKeysControlAllMonitors") ? .external : .cursor
        CachedDefaults[.brightnessTransition] = CachedDefaults[.smoothTransition] ? .smooth : .instant
    }

    static func firstRunAfterBuiltinUpgrade() {
        thisIsFirstRunAfterBuiltinUpgrade = true
        guard let displays = CachedDefaults[.displays] else { return }

        for display in displays.filter(\.isSmartBuiltin) {
            display.enabledControls[.gamma] = false
            display.save()
        }
    }

    static func firstRunAfterLunar4Upgrade() {
        thisIsFirstRunAfterLunar4Upgrade = true
        DataStore.reset()
    }

    static func firstRunAfterLunar6Upgrade() {
        thisIsFirstRunAfterLunar6Upgrade = true

//        guard let displays = CachedDefaults[.displays] else { return }
//
//        displays.forEach { display in
//            display.userBrightness = Display.DEFAULT_USER_BRIGHTNESS_DICT
//            display.userContrast = Display.DEFAULT_USER_CONTRAST_DICT
//        }
//        CachedDefaults[.displays] = displays
//        Defaults[.displays] = displays
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
// extension Defaults._AnyKey: Hashable {
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(name)
//    }
//
//    static func == (lhs: Defaults.Keys, rhs: Defaults.Keys) -> Bool {
//        lhs.name == rhs.name
//    }
// }

extension AnyCodable: Defaults.Serializable {}

// MARK: - ThreadSafeDictionary

final class ThreadSafeDictionary<V: Hashable, T>: Collection {
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
    static var crumbKeys: Set<Defaults._AnyKey> = [
        .adaptiveBrightnessMode,
        .astronomicalTwilightBegin,
        .astronomicalTwilightEnd,
        .civilTwilightBegin,
        .civilTwilightEnd,
        .clockMode,
        .dayLength,
        .hasActiveDisplays,
        .hasActiveExternalDisplays,
        .location,
        .nauticalTwilightBegin,
        .nauticalTwilightEnd,
        .nonManualMode,
        .curveMode,
        .secure,
        .solarNoon,
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

    static subscript<Value: Defaults.Serializable>(key: Defaults.Key<Value>) -> Value {
        get {
            mainThread {
                if ISCLI, cache[key.name] == nil {
                    cacheKey(key)
                }

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

    static func reset(_ keys: Defaults._AnyKey...) {
        reset(keys)
    }

    static func reset(_ keys: [Defaults._AnyKey]) {
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
        decode(gamma: [255, 255, 255])
    }
    Defaults.publisher(key).dropFirst().sink { change in
        // log.debug("Caching \(key.name) = \(change.newValue)")
        CachedDefaults.cache[key.name] = AnyCodable(change.newValue)

        guard !CachedDefaults.crumbKeys.contains(key) else { return }
        crumb("Set \(key.name) to \(change.newValue)", level: .info, category: "Settings")
    }.store(in: &CachedDefaults.observers)
}

func initCache() {
    guard !ISCLI else { return }

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

    cacheKey(.fullRangeMaxOnDoublePress)
    cacheKey(.autoSubzero)
    cacheKey(.autoXdr)
    cacheKey(.autoXdrSensor)
    cacheKey(.autoXdrSensorShowOSD)
    cacheKey(.autoXdrSensorLuxThreshold)
    cacheKey(.customOSDVerticalOffset)
    cacheKey(.allowAnySyncSource)
    cacheKey(.hideOSD)

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
    cacheKey(.newBlackOutDisconnect)
    cacheKey(.disableNightShiftXDR)
    cacheKey(.enableDarkModeXDR)
    cacheKey(.screenBlankingIssueWarningShown)
    cacheKey(.xdrContrast)
    cacheKey(.xdrContrastFactor)
    cacheKey(.subzeroContrast)
    cacheKey(.subzeroContrastFactor)
    cacheKey(.keyboardBacklightOffBlackout)
    cacheKey(.xdrWarningShown)
    cacheKey(.xdrTipShown)
    cacheKey(.autoXdrTipShown)
    cacheKey(.autoBlackoutBuiltin)
    cacheKey(.workaroundBuiltinDisplay)
    cacheKey(.mergeBrightnessContrast)
    cacheKey(.enableBlackOutKillSwitch)
    cacheKey(.enableSentry)
    cacheKey(.showNitsOSD)
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
    cacheKey(.volumeKeysControlAllMonitors)
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
    cacheKey(.showQuickActions)
    cacheKey(.dimNonEssentialUI)
    cacheKey(.manualLocation)
    cacheKey(.startAtLogin)
    cacheKey(.showBrightnessMenuBar)
    cacheKey(.showOnlyExternalBrightnessMenuBar)
    cacheKey(.showOrientationInQuickActions)
    cacheKey(.showOrientationForBuiltinInQuickActions)
    cacheKey(.showInputInQuickActions)
    cacheKey(.clamshellModeDetection)
    cacheKey(.sleepInClamshellMode)
    cacheKey(.disableCliffDetection)
    cacheKey(.disableBrightnessObservers)
    cacheKey(.brightnessStep)
    cacheKey(.contrastStep)
    cacheKey(.volumeStep)
    cacheKey(.syncPollingSeconds)
    cacheKey(.syncNits)
    cacheKey(.ddcSleepFactor)
    cacheKey(.ddcSleepLonger)
    cacheKey(.updateChannel)
    cacheKey(.menuDensity)
    cacheKey(.sensorPollingSeconds)
    cacheKey(.adaptiveBrightnessMode)
    cacheKey(.colorScheme)
    cacheKey(.nonManualMode)
    cacheKey(.curveMode)
    cacheKey(.hasBuiltin)
    cacheKey(.clockMode)
    cacheKey(.fullyAutomatedClockMode)
    cacheKey(.syncMode)
    cacheKey(.overrideAdaptiveMode)
    cacheKey(.reapplyValuesAfterWake)
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
    cacheKey(.sensorPort)
    cacheKey(.sensorPathPrefix)
    cacheKey(.disableExternalSensorWhenNoExternalMonitor)
    cacheKey(.apiKey)

    cacheKey(.location)
    cacheKey(.secure)
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

//    static let beta = (infoDict[InfoPlistKey.beta] as! String) == "YES"

    private static var infoDict: [String: Any] {
        if let dict = Bundle.main.infoDictionary {
            dict
        } else {
            fatalError("Info Plist file not found")
        }
    }
}

func pub<T: Equatable>(_ key: Defaults.Key<T>) -> Publishers.Filter<Publishers.RemoveDuplicates<Publishers.Drop<AnyPublisher<Defaults.KeyChange<T>, Never>>>> {
    Defaults.publisher(key).dropFirst().removeDuplicates().filter { $0.oldValue != $0.newValue }
}

let adaptiveBrightnessModePublisher = pub(.adaptiveBrightnessMode)

let colorSchemePublisher = pub(.colorScheme)
let startAtLoginPublisher = pub(.startAtLogin)
let showBrightnessMenuBarPublisher = pub(.showBrightnessMenuBar)
let showOnlyExternalBrightnessMenuBarPublisher = pub(.showOnlyExternalBrightnessMenuBar)
let showOrientationInQuickActionsPublisher = pub(.showOrientationInQuickActions)
let showOrientationForBuiltinInQuickActionsPublisher = pub(.showOrientationForBuiltinInQuickActions)
let autoBlackoutBuiltinPublisher = pub(.autoBlackoutBuiltin)
let autoSubzeroPublisher = pub(.autoSubzero)
let autoXdrPublisher = pub(.autoXdr)
let autoXdrSensorPublisher = pub(.autoXdrSensor)
let autoXdrSensorShowOSDPublisher = pub(.autoXdrSensorShowOSD)
let autoXdrSensorLuxThresholdPublisher = pub(.autoXdrSensorLuxThreshold)
let customOSDVerticalOffsetPublisher = pub(.customOSDVerticalOffset)
let allowAnySyncSourcePublisher = pub(.allowAnySyncSource)
let gammaDisabledCompletelyPublisher = pub(.gammaDisabledCompletely)
let hdrWorkaroundPublisher = pub(.hdrWorkaround)
let oldBlackOutMirroringPublisher = pub(.oldBlackOutMirroring)
let xdrContrastPublisher = pub(.xdrContrast)
let xdrContrastFactorPublisher = pub(.xdrContrastFactor)
let subzeroContrastPublisher = pub(.subzeroContrast)
let subzeroContrastFactorPublisher = pub(.subzeroContrastFactor)
let allowHDREnhanceContrastPublisher = pub(.allowHDREnhanceContrast)
let allowHDREnhanceBrightnessPublisher = pub(.allowHDREnhanceBrightness)
let workaroundBuiltinDisplayPublisher = pub(.workaroundBuiltinDisplay)
let mergeBrightnessContrastPublisher = pub(.mergeBrightnessContrast)
let enableSentryPublisher = pub(.enableSentry)
let waitAfterWakeSecondsPublisher = pub(.waitAfterWakeSeconds)
let delayDDCAfterWakePublisher = pub(.delayDDCAfterWake)
let showVolumeSliderPublisher = pub(.showVolumeSlider)
let showSliderValuesPublisher = pub(.showSliderValues)
let showAdvancedDisplaySettingsPublisher = pub(.showAdvancedDisplaySettings)
let lunarProActivePublisher = pub(.lunarProActive)
let infoMenuShownPublisher = pub(.infoMenuShown)
let showTwoSchedulesPublisher = pub(.showTwoSchedules)
let showThreeSchedulesPublisher = pub(.showThreeSchedules)
let showFourSchedulesPublisher = pub(.showFourSchedules)
let showFiveSchedulesPublisher = pub(.showFiveSchedules)
let allowBlackOutOnSingleScreenPublisher = pub(.allowBlackOutOnSingleScreen)
let moreGraphDataPublisher = pub(.moreGraphData)
let enableOrientationHotkeysPublisher = pub(.enableOrientationHotkeys)
let detectKeyHoldPublisher = pub(.detectKeyHold)
let refreshValuesPublisher = pub(.refreshValues)
let hideMenuBarIconPublisher = pub(.hideMenuBarIcon)
let showDockIconPublisher = pub(.showDockIcon)
let disableControllerVideoPublisher = pub(.disableControllerVideo)
let locationPublisher = pub(.location)
let brightnessStepPublisher = pub(.brightnessStep)
let syncPollingSecondsPublisher = pub(.syncPollingSeconds)
let syncNitsPublisher = pub(.syncNits)
let sensorPollingSecondsPublisher = pub(.sensorPollingSeconds)
let contrastStepPublisher = pub(.contrastStep)
let volumeStepPublisher = pub(.volumeStep)
let appExceptionsPublisher = pub(.appExceptions)
let securePublisher = pub(.secure)
let overrideAdaptiveModePublisher = pub(.overrideAdaptiveMode)
let dayMomentsPublisher = Defaults.publisher(keys: .sunrise, .sunset, .solarNoon)
let brightnessKeysEnabledPublisher = pub(.brightnessKeysEnabled)
let brightnessTransitionPublisher = pub(.brightnessTransition)
let volumeKeysEnabledPublisher = pub(.volumeKeysEnabled)
let useAlternateBrightnessKeysPublisher = pub(.useAlternateBrightnessKeys)

let mediaKeysPublisher = Defaults.publisher(
    keys: .brightnessKeysEnabled,
    .volumeKeysEnabled,
    .volumeHotkeysControlAllMonitors,
    .brightnessHotkeysControlAllMonitors,
    .contrastHotkeysControlAllMonitors
)
let silentUpdatePublisher = pub(.silentUpdate)
let checkForUpdatePublisher = pub(.checkForUpdate)
let showDummyDisplaysPublisher = pub(.showDummyDisplays)
let showVirtualDisplaysPublisher = pub(.showVirtualDisplays)
let showAirplayDisplaysPublisher = pub(.showAirplayDisplays)
let showProjectorDisplaysPublisher = pub(.showProjectorDisplays)
let showDisconnectedDisplaysPublisher = pub(.showDisconnectedDisplays)
let detectResponsivenessPublisher = pub(.detectResponsiveness)
let nonManualModePublisher = pub(.nonManualMode)
let listenForRemoteCommandsPublisher = pub(.listenForRemoteCommands)
let ddcSleepLongerPublisher = pub(.ddcSleepLonger)
let ddcSleepFactorPublisher = pub(.ddcSleepFactor)
let updateChannelPublisher = pub(.updateChannel)
let sensorHostnamePublisher = pub(.sensorHostname)
let scheduleTransitionPublisher = pub(.scheduleTransition)
let fullyAutomatedClockModePublisher = pub(.fullyAutomatedClockMode)
