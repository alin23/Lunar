//
//  Shared.swift
//  Lunar
//
//  Created by Alin Panaitiu on 10.12.2022.
//  Copyright © 2022 Alin. All rights reserved.
//

import CoreGraphics
import Defaults
import Foundation

// MARK: - BrightnessKeyAction

enum BrightnessKeyAction: Int, CaseIterable, Defaults.Serializable {
    case all
    case external
    case cursor
    case builtin
    case source
    case main
    case nonMain
}

// MARK: - BrightnessTransition

enum BrightnessTransition: Int, CaseIterable, Defaults.Serializable {
    case instant
    case smooth
    case slow
}

// MARK: - ScheduleTransition

enum ScheduleTransition: Int, CaseIterable, Defaults.Serializable {
    case none
    case minutes30
    case full
}

// MARK: - AdaptiveModeKey

enum AdaptiveModeKey: Int, Defaults.Serializable, CaseIterable, Sendable {
    case location = 1
    case sync = -1
    case manual = 0
    case sensor = 2
    case clock = 3
    case auto = 99

    var usesCurve: Bool {
        self == .location || self == .sensor || (
            self == .sync && !SyncMode.specific.isSyncingNits
        )
    }
    var hasUsefulInfo: Bool {
        self == .location || self == .sensor || (
            self == .sync && SyncMode.specific.isSyncingNits
        )
    }
}

let XDR_DEFAULT_LUX: Float = 6500
let LUNAR_CLI_PORT: Int32 = 23803
let CLI_ARG_SEPARATOR = "\u{01}"

extension Defaults.Keys {
    static let firstRun = Key<Bool?>("firstRun", default: nil)
    static let launchCount = Key<Int>("launchCount", default: 0)
    static let lastLaunchVersion = Key<String>("lastLaunchVersion", default: "")

    static let secondPhase = Key<Bool?>("secondPhase", default: nil)
    static let firstRunAfterLunar4Upgrade = Key<Bool?>("firstRunAfterLunar4Upgrade", default: nil)
    static let firstRunAfterLunar6Upgrade = Key<Bool?>("firstRunAfterLunar6Upgrade", default: nil)
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

    static let fullRangeMaxOnDoublePress = Key<Bool>("fullRangeMaxOnDoublePress", default: false)

    static let autoXdr = Key<Bool>("autoXdr", default: true)
    static let autoXdrSensor = Key<Bool>("autoXdrSensor", default: false)
    static let autoXdrSensorShowOSD = Key<Bool>("autoXdrSensorShowOSD", default: true)
    static let autoXdrSensorLuxThreshold = Key<Float>("autoXdrSensorLuxThreshold", default: XDR_DEFAULT_LUX)
    static let customOSDVerticalOffset = Key<Float>("customOSDVerticalOffset", default: 0)
    static let allowAnySyncSource = Key<Bool>("allowAnySyncSource", default: true)
    static let hideOSD = Key<Bool>("hideOSD", default: false)

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
    #if arch(arm64)
        static let newBlackOutDisconnect = Key<Bool>("newBlackOutDisconnect", default: true)
    #else
        static let newBlackOutDisconnect = Key<Bool>("newBlackOutDisconnect", default: false)
    #endif
    static let disableNightShiftXDR = Key<Bool>("disableNightShiftXDR", default: true)
    static let enableDarkModeXDR = Key<Bool>("enableDarkModeXDR", default: false)
    static let screenBlankingIssueWarningShown = Key<Bool>("screenBlankingIssueWarningShown", default: false)
    static let xdrContrast = Key<Bool>("xdrContrast", default: true)
    static let subzeroContrast = Key<Bool>("subzeroContrast", default: true)
    static let xdrContrastFactor = Key<Float>("xdrContrastFactor", default: 0.3)
    static let subzeroContrastFactor = Key<Float>("subzeroContrastFactor", default: 1.75)

    static let keyboardBacklightOffBlackout = Key<Bool>("keyboardBacklightOffBlackout", default: true)

    static let dcpMatchingIODisplayLocation = Key<Bool>("dcpMatchingIODisplayLocation", default: false)
    static let newXDRMode = Key<Bool>("newXDRMode", default: false)
    static let askedAboutXDR = Key<Bool>("askedAboutXDR", default: false)
    static let xdrWarningShown = Key<Bool>("xdrWarningShown", default: false)
    static let xdrTipShown = Key<Bool>("xdrTipShown", default: false)
    static let fullRangeTipShown = Key<Bool>("fullRangeTipShown", default: false)
    static let autoXdrTipShown = Key<Bool>("autoXdrTipShown", default: false)
    static let autoBlackoutBuiltin = Key<Bool>("autoBlackoutBuiltin", default: false)
    static let workaroundBuiltinDisplay = Key<Bool>("workaroundBuiltinDisplay", default: false)
    static let mergeBrightnessContrast = Key<Bool>("mergeBrightnessContrast", default: true)
    static let enableBlackOutKillSwitch = Key<Bool>("enableBlackOutKillSwitch", default: true)
    static let enableSentry = Key<Bool>("enableSentry", default: true)
    static let paddleConsent = Key<Bool>("paddleConsent", default: false)

    static let menuBarClosed = Key<Bool>("menuBarClosed", default: true)
    static let showVolumeSlider = Key<Bool>("showVolumeSlider", default: true)
    static let showRawValues = Key<Bool>("showRawValues", default: false)
    static let showNitsOSDExternal = Key<Bool>("showNitsOSDExternal", default: false)
    static let showNitsOSDBuiltin = Key<Bool>("showNitsOSDBuiltin", default: true)
    static let showNitsText = Key<Bool>("showNitsText", default: true)
    static let showStandardPresets = Key<Bool>("showStandardPresets", default: true)
    static let showCustomPresets = Key<Bool>("showCustomPresets", default: true)
    static let hidePresetsOnSingleDisplay = Key<Bool>("hidePresetsOnSingleDisplay", default: true)
    static let showXDRSelector = Key<Bool>("showXDRSelector", default: true)
    static let showHeaderOnHover = Key<Bool>("showHeaderOnHover", default: false)
    static let showFooterOnHover = Key<Bool>("showFooterOnHover", default: false)
    static let showOptionsMenu = Key<Bool>("showOptionsMenu", default: false)
    static let keepOptionsMenu = Key<Bool>("keepOptionsMenu", default: false)
    static let showSliderValues = Key<Bool>("showSliderValues", default: false)
    static let showSliderValuesNits = Key<Bool>("showSliderValuesNits", default: false)
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
    static let volumeKeysControlAllMonitors = Key<Bool>("volumeKeysControlAllMonitors", default: false)
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
    static let showQuickActions = Key<Bool>("showQuickActions", default: true)
    static let dimNonEssentialUI = Key<Bool>("dimNonEssentialUI", default: false)
    static let manualLocation = Key<Bool>("manualLocation", default: false)
    static let startAtLogin = Key<Bool>("startAtLogin", default: true)
    static let showBrightnessMenuBar = Key<Bool>("showBrightnessMenuBar", default: false)
    static let showOnlyExternalBrightnessMenuBar = Key<Bool>("showOnlyExternalBrightnessMenuBar", default: false)
    static let showOrientationInQuickActions = Key<Bool>("showOrientationInQuickActions", default: false)
    static let showOrientationForBuiltinInQuickActions = Key<Bool>("showOrientationForBuiltinInQuickActions", default: false)
    static let showInputInQuickActions = Key<Bool>("showInputInQuickActions", default: true)
    static let showPowerInQuickActions = Key<Bool>("showPowerInQuickActions", default: true)
    static let neverShowBlackoutPopover = Key<Bool>("neverShowBlackoutPopover", default: false)
    static let clamshellModeDetection = Key<Bool>("clamshellModeDetection", default: true)
    static let disableBrightnessObservers = Key<Bool>("disableBrightnessObservers", default: false)
    static let brightnessStep = Key<Int>("brightnessStep", default: 6)
    static let contrastStep = Key<Int>("contrastStep", default: 6)
    static let volumeStep = Key<Int>("volumeStep", default: 6)
    static let syncPollingSeconds = Key<Int>("syncPollingSeconds", default: 0)
    #if arch(arm64)
        static let syncNits = Key<Bool>("syncNits", default: true)
    #else
        static let syncNits = Key<Bool>("syncNits", default: false)
    #endif

    static let ddcSleepLonger = Key<Bool>("ddcSleeplonger", default: false)

    static let sensorPollingSeconds = Key<Double>("sensorPollingSeconds", default: 1)
    static let adaptiveBrightnessMode = Key<AdaptiveModeKey>("adaptiveBrightnessMode", default: .sync)

    static let hasBuiltin = Key<Bool>("hasBuiltin", default: Sysctl.isMacBook || Sysctl.isiMac)
    static let nonManualMode = Key<Bool>("nonManualMode", default: true)
    static let curveMode = Key<Bool>("curveMode", default: true)
    static let clockMode = Key<Bool>("clockMode", default: false)
    static let fullyAutomatedClockMode = Key<Bool>("fullyAutomatedClockMode", default: false)
    static let syncMode = Key<Bool>("syncMode", default: false)
    static let overrideAdaptiveMode = Key<Bool>("overrideAdaptiveMode", default: false)
    static let reapplyValuesAfterWake = Key<Bool>("reapplyValuesAfterWake", default: true)
    static let allowAdjustmentsWhileLocked = Key<Bool>("allowAdjustmentsWhileLocked", default: false)
    static let waitAfterWakeSeconds = Key<Int>("waitAfterWakeSeconds", default: 30)
    static let delayDDCAfterWake = Key<Bool>("delayDDCAfterWake", default: false)
    static let wakeReapplyTries = Key<Int>("wakeReapplyTries", default: 5)
    static let syncModeBrightnessKeyPressedExpireSeconds = Key<Double>("syncModeBrightnessKeyPressedExpireSeconds", default: 1.0)

    static let sunrise = Key<String?>("sunrise", default: nil)
    static let sunset = Key<String?>("sunset", default: nil)
    static let solarNoon = Key<String?>("solarNoon", default: nil)

    static let civilTwilightBegin = Key<String?>("civilTwilightBegin", default: nil)
    static let civilTwilightEnd = Key<String?>("civilTwilightEnd", default: nil)
    static let nauticalTwilightBegin = Key<String?>("nauticalTwilightBegin", default: nil)
    static let nauticalTwilightEnd = Key<String?>("nauticalTwilightEnd", default: nil)
    static let astronomicalTwilightBegin = Key<String?>("astronomicalTwilightBegin", default: nil)
    static let astronomicalTwilightEnd = Key<String?>("astronomicalTwilightEnd", default: nil)
    static let dayLength = Key<UInt64>("dayLength", default: 0)
    static let hideMenuBarIcon = Key<Bool>("hideMenuBarIcon", default: false)
    static let alternateMenuBarIcon = Key<Bool>("alternateMenuBarIcon", default: false)
    static let showDockIcon = Key<Bool>("showDockIcon", default: false)
    static let disableControllerVideo = Key<Bool>("disableControllerVideo", default: true)
    static let neverAskAboutFlux = Key<Bool>("neverAskAboutFlux", default: false)
    static let hasActiveDisplays = Key<Bool>("hasActiveDisplays", default: true)
    static let hasActiveExternalDisplays = Key<Bool>("hasActiveExternalDisplays", default: false)
    static let toolTipDelay = Key<Int>("NSInitialToolTipDelay", default: 3)
//    static let wttr = Key<Wttr?>("wttr")
    static let ignoredVolumes = Key<Set<String>>("ignoredVolumes", default: [])

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
    static let ignoreDisplaysWithMissingMetadata = Key<Bool>("ignoreDisplaysWithMissingMetadata", default: true)

    static let autoRestartOnCrash = Key<Bool>("autoRestartOnCrash", default: true)
    static let autoRestartOnHang = Key<Bool>("autoRestartOnHang", default: true)
    static let autoRestartOnFailedDDC = Key<Bool>("autoRestartOnFailedDDC", default: false)
    static let autoRestartOnFailedDDCSooner = Key<Bool>("autoRestartOnFailedDDCSooner", default: false)
    static let autoRestartOnCoreAudioHang = Key<Bool>("autoRestartOnCoreAudioHang", default: false)
    static let disableVolumeKeysOnSleep = Key<Bool>("disableVolumeKeysOnSleep", default: false)
    static let sleepInClamshellMode = Key<Bool>("sleepInClamshellMode", default: false)
    static let disableCliffDetection = Key<Bool>("disableCliffDetection", default: false)
    static let jitterBrightnessOnWake = Key<Bool>("jitterBrightnessOnWake", default: false)

    static let sensorHostname = Key<String>("sensorHostname", default: "lunarsensor.local")
    static let sensorPort = Key<Int>("sensorPort", default: 80)
    static let sensorPathPrefix = Key<String>("sensorPathPrefix", default: "")
    static let disableExternalSensorWhenNoExternalMonitor = Key<Bool>("disableExternalSensorWhenNoExternalMonitor", default: false)

    #if arch(arm64)
        static let possiblyDisconnectedDisplays = Key<[Display]>("possiblyDisconnectedDisplays", default: [])
        // static let nitsBrightnessMapping = Key<[String: [AutoLearnMapping]]>("nitsBrightnessMapping", default: [:])
        // static let nitsContrastMapping = Key<[String: [AutoLearnMapping]]>("nitsContrastMapping", default: [:])
    #endif
}
