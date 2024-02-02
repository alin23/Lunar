//
//  AppDelegate.swift
//  Lunar
//
//  Created by Alin on 30/11/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Atomics
import Carbon.HIToolbox
import Cocoa
import Combine
import Compression
import CoreLocation
import Defaults
import FuzzyMatcher
import LetsMove
import Magnet
import MediaKeyTap
import Paddle
import Regex
import Sauce
import Sentry
import SimplyCoreAudio
import Socket
import Sparkle
import SwiftDate
import SwiftyMarkdown
import UserNotifications
import WAYWindow

import AVFoundation
import Path
import SwiftUI

import ServiceManagement

extension CLLocationManager {
    var auth: CLAuthorizationStatus? {
        withTimeout(5.seconds, name: "locationAuth") {
            self.authorizationStatus
        }
    }
}

func withTimeout<T>(_ timeout: DateComponents, name: String, _ block: @escaping () throws -> T) -> T? {
    var value: T?
    let workItem = DispatchWorkItem(name: name) {
        do {
            value = try block()
        } catch {
            log.error("\(name) failed: \(error.localizedDescription)")
        }
    }
    DispatchQueue.global().async(execute: workItem.workItem)
    let result = workItem.wait(for: timeout)
    if result == .timedOut {
        log.error("\(name) timed out")
        workItem.cancel()
    }

    return value
}

let fm = FileManager()
let simplyCA: SimplyCoreAudio? = withTimeout(5.seconds, name: "simplyCA") {
    SimplyCoreAudio()
}
var brightnessTransition = BrightnessTransition.instant
let SCREEN_WAKE_ADAPTER_TASK_KEY = "screenWakeAdapter"
let CONTACT_URL = "https://lunar.fyi/contact".asURL()!
var startTime = Date()
var wakeTime = startTime

let kAppleInterfaceThemeChangedNotification = "AppleInterfaceThemeChangedNotification"
let kAppleInterfaceStyle = "AppleInterfaceStyle"
let kAppleInterfaceStyleSwitchesAutomatically = "AppleInterfaceStyleSwitchesAutomatically"

let mediaKeyTapQueue = DispatchQueue(label: "fyi.lunar.serviceBrowser.queue", qos: .userInteractive)
let serviceBrowserQueue = DispatchQueue(label: "fyi.lunar.serviceBrowser.queue", qos: .userInteractive)
let sensorHostnameQueue = DispatchQueue(label: "fyi.lunar.sensor.hostname.queue", qos: .background)
let windowControllerQueue = DispatchQueue(label: "fyi.lunar.windowControllerQueue.queue", qos: .userInitiated)
let concurrentQueue = DispatchQueue(label: "fyi.lunar.concurrent.queue", qos: .userInitiated, attributes: .concurrent)
let smoothDDCQueue = DispatchQueue(label: "fyi.lunar.smooth.ddc.queue", qos: .userInitiated, attributes: .concurrent)
let smoothDisplayServicesQueue = DispatchQueue(
    label: "fyi.lunar.smooth.displayservices.queue",
    qos: .userInitiated,
    attributes: .concurrent
)

let serialQueue = DispatchQueue(label: "fyi.lunar.serial.queue", qos: .userInitiated)
let gammaQueue = DispatchQueue(label: "fyi.lunar.gamma.queue", qos: .userInteractive)
let appName = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Lunar"

var activeDisplay: Display?

var thisIsFirstRun = false
var thisIsFirstRunAfterLunar4Upgrade = false
var thisIsFirstRunAfterLunar6Upgrade = false
var thisIsFirstRunAfterDefaults5Upgrade = false
var thisIsFirstRunAfterM1DDCUpgrade = false
var thisIsFirstRunAfterBuiltinUpgrade = false
var thisIsFirstRunAfterHotkeysUpgrade = false
var thisIsFirstRunAfterExperimentalDDCUpgrade = false

func createTransition(
    duration: TimeInterval,
    type: CATransitionType,
    subtype: CATransitionSubtype = .fromTop,
    start: Float = 0.0,
    end: Float = 1.0,
    easing: CAMediaTimingFunction = .easeOutQuart
) -> CATransition {
    let transition = CATransition()
    transition.duration = duration
    transition.type = type
    transition.subtype = subtype
    transition.startProgress = start
    transition.endProgress = end
    transition.timingFunction = easing
    return transition
}

func fadeTransition(duration: TimeInterval) -> CATransition {
    let transition = CATransition()
    transition.duration = duration
    transition.type = .fade
    return transition
}

var audioPlayer: AVAudioPlayer?

func playVolumeChangedSound() {
    do {
        audioPlayer =
            try AVAudioPlayer(
                contentsOf: URL(fileURLWithPath: "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff")
            )
        audioPlayer?.volume = 1
        audioPlayer?.play()
    } catch {
        log.error(error.localizedDescription)
    }
}

// MARK: - NonClosingMenuText

final class NonClosingMenuText: NSTextField {
    var onClick: (() -> Void)?

    override func mouseDown(with _: NSEvent) {
        // log.info("mouseDown: \(event.locationInWindow)")
        onClick?()
    }
}

// MARK: - MemoryUsageError

enum MemoryUsageError: Error {
    case highMemoryUsage(Int)
}

let SWIFTUI_PREVIEW = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

var lastXDRContrastResetTime = Date()

final class UpdateManager: ObservableObject {
    #if DEBUG
        @Published var newVersion: String? = nil // "6.4.0"
    #else
        @Published var newVersion: String? = nil
    #endif
}

final class KeysManager: ObservableObject {
    @Published var noModifiers = true

    @Published var optionKeyPressed = false {
        didSet {
            noModifiers = !optionKeyPressed && !shiftKeyPressed && !controlKeyPressed && !commandKeyPressed
        }
    }

    @Published var shiftKeyPressed = false {
        didSet {
            noModifiers = !optionKeyPressed && !shiftKeyPressed && !controlKeyPressed && !commandKeyPressed
        }
    }

    @Published var controlKeyPressed = false {
        didSet {
            noModifiers = !optionKeyPressed && !shiftKeyPressed && !controlKeyPressed && !commandKeyPressed
        }
    }

    @Published var commandKeyPressed = false {
        didSet {
            noModifiers = !optionKeyPressed && !shiftKeyPressed && !controlKeyPressed && !commandKeyPressed
        }
    }
}

let KM = KeysManager()
let UM = UpdateManager()

// MARK: - AppDelegate

@main
final class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate, NSMenuDelegate, SPUStandardUserDriverDelegate {
    enum UIElement {
        case displayControls
        case displayDDC
        case displayGamma
        case displayReset
    }

    static var signalHandlers: [DispatchSourceSignal] = []
    static var observers: Set<AnyCancellable> = []
    static var enableSentry = CachedDefaults[.enableSentry]
    static var supportsHDR: Bool = {
        concurrentQueue.asyncAfter(ms: 1) {
            NotificationCenter.default
                .publisher(for: AVPlayer.eligibleForHDRPlaybackDidChangeNotification)
                .sink { _ in supportsHDR = AVPlayer.eligibleForHDRPlayback }
                .store(in: &observers)
            let hdr = AVPlayer.eligibleForHDRPlayback
            mainAsync { supportsHDR = hdr }
        }

        return false
    }()

    static var hdrWorkaround: Bool = Defaults[.hdrWorkaround]

    static var colorScheme: ColorScheme = {
        colorSchemePublisher.sink { AppDelegate.colorScheme = $0.newValue }.store(in: &observers)
        return Defaults[.colorScheme]
    }()

    @Atomic var paddleDismissed = true

    var locationManager: CLLocationManager?
    var _windowControllerLock = NSRecursiveLock()
    var _windowController: ModernWindowController?
    var alsWindowController: ModernWindowController?
    var sshWindowController: ModernWindowController?
    var diagnosticsWindowController: ModernWindowController?
    var onboardWindowController: ModernWindowController?

    var observers: Set<AnyCancellable> = []
    var valuesReaderThread: Repeater?

    var statusItemButtonController: StatusItemButtonController?

    @IBOutlet var versionMenuItem: NSMenuItem!
    @IBOutlet var menu: NSMenu!
    @IBOutlet var preferencesMenuItem: NSMenuItem!
    @IBOutlet var restartMenuItem: NSMenuItem!

    @IBOutlet var percent0MenuItem: NSMenuItem!
    @IBOutlet var percent25MenuItem: NSMenuItem!
    @IBOutlet var percent50MenuItem: NSMenuItem!
    @IBOutlet var percent75MenuItem: NSMenuItem!
    @IBOutlet var percent100MenuItem: NSMenuItem!

    @IBOutlet var brightnessUpMenuItem: NSMenuItem!
    @IBOutlet var brightnessDownMenuItem: NSMenuItem!
    @IBOutlet var contrastUpMenuItem: NSMenuItem!
    @IBOutlet var contrastDownMenuItem: NSMenuItem!
    @IBOutlet var volumeDownMenuItem: NSMenuItem!
    @IBOutlet var volumeUpMenuItem: NSMenuItem!
    @IBOutlet var muteAudioMenuItem: NSMenuItem!
    @IBOutlet var resetTrialMenuItem: NSMenuItem!
    @IBOutlet var expireTrialMenuItem: NSMenuItem!

    @IBOutlet var lunarProMenuItem: NSMenuItem!
    @IBOutlet var activateLicenseMenuItem: NSMenuItem!
    @IBOutlet var faceLightMenuItem: NSMenuItem!
    @IBOutlet var blackOutMenuItem: NSMenuItem!
    @IBOutlet var blackOutNoMirroringMenuItem: NSMenuItem!
    @IBOutlet var blackOutPowerOffMenuItem: NSMenuItem!
    @IBOutlet var blackOutOthersMenuItem: NSMenuItem!
    @IBOutlet var faceLightExplanationMenuItem: NSMenuItem!
    @IBOutlet var blackOutExplanationMenuItem: NSMenuItem!
    @IBOutlet var blackOutKillSwitchExplanationMenuItem: NSMenuItem!
    @IBOutlet var infoMenuItem: NSMenuItem!

    @Atomic var faceLightOn = false

    var wakeObserver: Cancellable?
    var screenObserver: Cancellable?

    lazy var updater = SPUUpdater(
        hostBundle: Bundle.main,
        applicationBundle: Bundle.main,
        userDriver: SPUStandardUserDriver(hostBundle: Bundle.main, delegate: self),
        delegate: self
    )

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    var uiElement: UIElement?

    var didBecomeActiveAtLeastOnce = false

    var brightnessIcon = "brightness"

    lazy var markdown: SwiftyMarkdown = getMarkdownRenderer()

    @IBOutlet var infoMenuToggle: NSMenuItem!

    var menuUpdater: Repeater?

    var memoryUsageChecker: Foundation.Thread?

    lazy var needsAccessibilityPermissions = CachedDefaults[.brightnessKeysEnabled] || CachedDefaults[.volumeKeysEnabled] ||
        !(CachedDefaults[.appExceptions]?.isEmpty ?? true)

    var appPresetHandler: DispatchWorkItem?

    var lastCommandModifierPressedTime: Date?
    var commandModifierPressedCount = 0

    var screenWakeAdapterTask: Repeater?

    lazy var resetStatesPublisher: PassthroughSubject<Bool, Never> = {
        let p = PassthroughSubject<Bool, Never>()
        p.debounce(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [self] shouldReset in
                guard shouldReset else { return }

                resetStates()
            }.store(in: &observers)
        return p
    }()

    var zeroGammaChecker: Repeater?

    var enableSentryObserver: Cancellable?

    var hdrFixer: Repeater? = AppDelegate.fixHDR()

    @Atomic var mediaKeyTapBrightnessStarting = false
    @Atomic var mediaKeyTapAudioStarting = false

    @Atomic var menuShown = false

    var env = EnvState()

    let APP_DIR = ((try? p("/Applications")?.realpath()) ?? p("/Applications"))?.components ?? ["Applications"]
    let SVAPP_DIR = ((try? p("/System/Volumes/Data/Applications")?.realpath()) ?? p("/System/Volumes/Data/Applications"))?.components ?? ["System", "Volumes", "Data", "Applications"]

    @Atomic @objc dynamic var cleaningMode = false {
        didSet {
            log.debug("Cleaning Mode: \(cleaningMode)")
        }
    }

    @Atomic @objc dynamic var nightMode = false {
        didSet {
            guard nightMode != oldValue else { return }
            log.debug("Night Mode: \(nightMode)")
            DC.nightMode = nightMode
        }
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }
    var currentPage: Int = Page.display.rawValue {
        didSet {
            log.verbose("Current Page \(currentPage)")
        }
    }

    var windowController: ModernWindowController? {
        get { _windowControllerLock.around { _windowController } }
        set { _windowControllerLock.around { _windowController = newValue } }
    }

    var externalLux: String {
        guard SensorMode.wirelessSensorURL != nil, let lux = SensorMode.specific.lastExternalAmbientLight else { return "" }
        return "External light sensor: **\(lux.str(decimals: 2)) lux**\n"
    }

    var internalLux: String {
        guard let lux = SensorMode.specific.lastInternalAmbientLight else { return "" }
        return "Internal light sensor: **\(lux.str(decimals: 2)) lux**\n"
    }

    var sun: String {
        guard let moment = LocationMode.specific.moment, let elevation = LocationMode.specific.geolocation?.sunElevation else { return "" }
        let sunrise = moment.sunrise.toString(.time(.short))
        let sunset = moment.sunset.toString(.time(.short))
        let noon = moment.solarNoon.toString(.time(.short))

        return "Sun: (**sunrise \(sunrise)**) (**sunset \(sunset)**)\n       (noon \(noon)) [elevation \(elevation.str(decimals: 1))°]\n"
    }

    var memory500MBPassed = false {
        didSet {
            guard AppDelegate.enableSentry, memory500MBPassed, !oldValue, let mb = memoryFootprintMB() else { return }

            SentrySDK.configureScope { scope in
                scope.setTag(value: "500MB", key: "memory")
                scope.setExtra(value: mb, key: "usedMB")
                // SentrySDK.capture(error: MemoryUsageError.highMemoryUsage(mb.intround))
            }
        }
    }

    var memory1GBPassed = false {
        didSet {
            guard AppDelegate.enableSentry, memory1GBPassed, !oldValue, let mb = memoryFootprintMB() else { return }
            #if !DEBUG
                SentrySDK.configureScope { scope in
                    scope.setTag(value: "1GB", key: "memory")
                    scope.setExtra(value: mb, key: "usedMB")
                    SentrySDK.capture(error: MemoryUsageError.highMemoryUsage(mb.intround))
                    self.restartApp(self)
                }
            #endif
        }
    }

    var memory2GBPassed = false {
        didSet {
            guard AppDelegate.enableSentry, memory2GBPassed, !oldValue, let mb = memoryFootprintMB() else { return }
            #if !DEBUG
                SentrySDK.configureScope { scope in
                    scope.setTag(value: "2GB", key: "memory")
                    scope.setExtra(value: mb, key: "usedMB")
                    SentrySDK.capture(error: MemoryUsageError.highMemoryUsage(mb.intround))
                    self.restartApp(self)
                }
            #endif
        }
    }

    var memory4GBPassed = false {
        didSet {
            guard AppDelegate.enableSentry, memory4GBPassed, !oldValue, let mb = memoryFootprintMB() else { return }
            #if !DEBUG
                SentrySDK.configureScope { scope in
                    scope.setTag(value: "4GB", key: "memory")
                    scope.setExtra(value: mb, key: "usedMB")
                    SentrySDK.capture(error: MemoryUsageError.highMemoryUsage(mb.intround))
                    self.restartApp(self)
                }
            #endif
        }
    }

    var memory8GBPassed = false {
        didSet {
            guard AppDelegate.enableSentry, memory8GBPassed, !oldValue, let mb = memoryFootprintMB() else { return }
            SentrySDK.configureScope { scope in
                scope.setTag(value: "8GB", key: "memory")
                scope.setExtra(value: mb, key: "usedMB")
                SentrySDK.capture(error: MemoryUsageError.highMemoryUsage(mb.intround))
                self.restartApp(self)
            }
        }
    }

    var mediaKeyTapStartingFinishTask: DispatchWorkItem? {
        didSet { oldValue?.cancel() }
    }

    var server = LunarServer() {
        didSet {
            oldValue.stopAsync()
        }
    }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        // If the standard user driver will show the update in immediate focus (e.g. near app launch),
        // then let Sparkle take care of showing the update.
        // Otherwise we will handle showing any other scheduled updates
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state _: SPUUserUpdateState) {
        // We will ignore updates that the user driver will handle showing
        // This includes user initiated (non-scheduled) updates
        guard !handleShowingUpdate else {
            return
        }

        // Attach a gentle UI indicator on our window
        UM.newVersion = update.displayVersionString
    }

    func standardUserDriverWillFinishUpdateSession() {
        // We will dismiss our gentle UI indicator if the user session for the update finishes
        UM.newVersion = nil
    }

    func resetStates() {
        disableFaceLight(smooth: false)
        NetworkControl.resetState()
        DDCControl.resetState()
        startOrRestartMediaKeyTap()
        for d in DC.activeDisplays.values {
            d.updateCornerWindow()
        }
    }

    @IBAction func blackOutPowerOff(_: Any) {
        guard let display = DC.mainExternalDisplay else { return }
        _ = display.control?.setPower(.off)
    }

    func showTestWindow(text: String? = nil) {
        mainThread {
            for d in DC.activeDisplayList {
                createWindow(
                    "testWindowController",
                    controller: &d.testWindowController,
                    screen: d.nsScreen,
                    show: true,
                    backgroundColor: .clear,
                    level: .screenSaver,
                    fillScreen: false,
                    stationary: true
                )
                if let text, let wc = d.testWindowController, let w = wc.window,
                   let view = w.contentViewController as? LunarTestViewController
                {
                    view.lunarTestText = text
                    view.taskKey = "lunarTestHighlighter-\(d.serial)"
                    view.label.textColor = red
                }
            }
        }
        wakeObserver = wakeObserver ?? NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.screensDidWakeNotification, object: nil)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [self] _ in
                showTestWindow()
            }
        screenObserver = screenObserver ?? NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification, object: nil)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [self] _ in
                showTestWindow()
            }
    }

    func menuWillOpen(_: NSMenu) {
        menuShown = true
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "6"

        initGammaMenuItems(version)
        initMenuItems()
        menuUpdater = Repeater(every: 0.5, name: "infoMenuItemUpdater") { [self] in
            updateInfoMenuItem()
        }
    }

    func menuDidClose(_: NSMenu) {
        menuShown = false
        menuUpdater = nil
    }

    @IBAction func checkForUpdates(_: Any) {
        updater.checkForUpdates()
    }

    func closeAndOpenMenuWindow(afterMs: Int = 10) {
        statusItemButtonController?.closeMenuBar()
        mainAsyncAfter(ms: afterMs) {
            self.statusItemButtonController?.showMenuBar()
        }
    }

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let scheme = url.scheme, let host = url.host, scheme == "lunar" else { continue }

            switch host {
            case "checkout":
                if windowController != nil {
                    showCheckout()
                } else {
                    windowShowTask = mainAsyncAfter(ms: 2000) { showCheckout() }
                }
            case "advanced":
                statusItemButtonController?.showMenuBar()
                Defaults[.showOptionsMenu] = true

                env.optionsTab = .advanced
            case "xdr", "hdr":
                statusItemButtonController?.showMenuBar()
                Defaults[.showOptionsMenu] = true

                env.optionsTab = .hdr
            case "menu":
                statusItemButtonController?.showMenuBar()
                Defaults[.showOptionsMenu] = false
            case "options", "layout":
                statusItemButtonController?.showMenuBar()
                Defaults[.showOptionsMenu] = true

                env.optionsTab = .layout
            case "appinfo", "app-info", "info":
                Defaults[.showAdditionalInfo] = false
                additionInfoTask = nil
                windowShowTask = mainAsyncAfter(ms: 100) {
                    self.statusItemButtonController?.showMenuBar()
                    additionInfoTask = mainAsyncAfter(ms: 500) {
                        withAnimation(.spring()) {
                            Defaults[.showAdditionalInfo] = true
                        }
                    }
                }
            case "settings", "configuration":
                currentPage = Page.settings.rawValue
                showWindow(after: windowController == nil ? 2000 : nil)
            case "hotkeys":
                currentPage = Page.hotkeys.rawValue
                showWindow(after: windowController == nil ? 2000 : nil)
            case "display":
                currentPage = Page.display.rawValue
                if let firstPath = url.pathComponents.prefix(2).last, !firstPath.isEmpty,
                   let lastPath = url.pathComponents.last, !lastPath.isEmpty
                {
                    if let number = firstPath.i, number > 0, number <= DC.activeDisplays.count {
                        currentPage += (number - 1)
                    } else if firstPath == "builtin" || firstPath == "internal" || firstPath == "built-in" {
                        if let w = windowController?.window, let view = w.contentView,
                           !view.subviews.isEmpty, !view.subviews[0].subviews.isEmpty,
                           let pageController = view.subviews[0].subviews[0].nextResponder as? PageController
                        {
                            currentPage = pageController.arrangedObjects.firstIndex {
                                ($0 as? Display)?.isBuiltin ?? false
                            } ?? currentPage
                        }
                    } else if firstPath != "settings" && firstPath != "displaySettings" {
                        if let w = windowController?.window, let view = w.contentView,
                           !view.subviews.isEmpty, !view.subviews[0].subviews.isEmpty,
                           let pageController = view.subviews[0].subviews[0].nextResponder as? PageController
                        {
                            if let name = DC.displays.values.map(\.name).fuzzyFind(firstPath) {
                                currentPage = pageController.arrangedObjects.firstIndex {
                                    (($0 as? Display)?.name ?? "") == name
                                } ?? currentPage
                            }
                        }
                    }
                    if firstPath =~ "(display)?settings|controls?" || lastPath =~ "(display)?settings|controls?" {
                        uiElement = .displayControls
                    } else if firstPath =~ "ddc|dcc" || lastPath =~ "ddc|dcc" {
                        uiElement = .displayDDC
                    } else if firstPath =~ "gamm?a|colors?|rgb" || lastPath =~ "gamm?a|colors?|rgb" {
                        uiElement = .displayGamma
                    } else if firstPath =~ "reset" || lastPath =~ "reset" {
                        uiElement = .displayReset
                    }
                }
                showWindow(after: windowController == nil ? 2000 : nil)
            default:
                continue
            }
        }
    }

    func initHotkeys() {
        guard !CachedDefaults[.hotkeys].isEmpty else {
            CachedDefaults[.hotkeys] = Hotkey.defaults
            Hotkey.toggleOrientationHotkeys()
            return
        }
        MediaKeyTap.useAlternateBrightnessKeys = CachedDefaults[.useAlternateBrightnessKeys]

        var hotkeys = CachedDefaults[.hotkeys]
        let existingIdentifiers = Set(hotkeys.map(\.identifier))

        for identifierCase in HotkeyIdentifier.allCases {
            let identifier = identifierCase.rawValue
            if !existingIdentifiers.contains(identifier), let hotkey = Hotkey.defaults.first(where: { $0.identifier == identifier }) {
                hotkeys.remove(hotkey)
                hotkeys.insert(hotkey)
            }
        }
        for hotkey in Hotkey.defaults {
            hotkey.unregister()
        }

        var toRemove = Set<String>()
        for hotkey in hotkeys {
            if hotkey.isPresetHotkey, hotkey.preset == nil {
                hotkey.unregister()
                toRemove.insert(hotkey.identifier)
                continue
            }

            hotkey.handleRegistration(persist: false)
            guard let alternates = alternateHotkeysMapping[hotkey.identifier] else { continue }
            for (flags, altIdentifier) in alternates {
                guard let altHotkey = hotkeys.first(where: { $0.identifier == altIdentifier }) else {
                    continue
                }
                altHotkey.isEnabled = hotkey.isEnabled && !NSEvent.ModifierFlags(carbonModifiers: hotkey.modifiers).contains(flags)
                altHotkey.handleRegistration(persist: false)
            }
        }
        CachedDefaults[.hotkeys] = hotkeys.filter { !toRemove.contains($0.identifier) }

        HotKeyCenter.shared.detectKeyHold = CachedDefaults[.detectKeyHold]
        detectKeyHoldPublisher.sink { change in
            HotKeyCenter.shared.detectKeyHold = change.newValue
        }.store(in: &observers)

        Hotkey.toggleOrientationHotkeys()
        enableOrientationHotkeysPublisher.sink { change in
            Hotkey.toggleOrientationHotkeys(enabled: change.newValue)
        }.store(in: &observers)

        setKeyEquivalents(hotkeys)
        startOrRestartMediaKeyTap(checkPermissions: !datastore.shouldOnboard && needsAccessibilityPermissions)
    }

    func listenForAdaptiveModeChange() {
        let mode = CachedDefaults[.adaptiveBrightnessMode]
        CachedDefaults[.nonManualMode] = mode != .manual
        CachedDefaults[.curveMode] = mode.usesCurve
        CachedDefaults[.clockMode] = mode == .clock
        CachedDefaults[.syncMode] = mode == .sync

        adaptiveBrightnessModePublisher.sink { change in
            // log.info("adaptiveBrightnessModePublisher \(change)")
            if AppDelegate.enableSentry {
                SentrySDK.configureScope { scope in
                    scope.setTag(value: change.newValue.str, key: "adaptiveMode")
                    scope.setTag(value: change.oldValue.str, key: "lastAdaptiveMode")
                    scope.setTag(value: CachedDefaults[.overrideAdaptiveMode] ? "false" : "true", key: "autoMode")
                }
            }

            let modeKey = change.newValue
            mainAsync {
                if change.oldValue == .manual, change.newValue != .manual {
                    for d in DC.activeDisplayList {
                        guard d.hasAmbientLightAdaptiveBrightness, let lastAppPreset = d.appPreset
                        else { continue }

                        if !d.systemAdaptiveBrightness {
                            d.systemAdaptiveBrightness = true
                        }
                        if lastAppPreset.reapplyPreviousBrightness {
                            if CachedDefaults[.mergeBrightnessContrast] {
                                let (br, _) = d.sliderValueToBrightnessContrast(d.preciseBrightnessContrastBeforeAppPreset)
                                d.brightness = br.ns
                            } else {
                                d.brightness = d.sliderValueToBrightness(d.preciseBrightnessBeforeAppPreset)
                            }
                        }
                    }
                }

                CachedDefaults[.nonManualMode] = modeKey != .manual
                CachedDefaults[.curveMode] = modeKey.usesCurve
                CachedDefaults[.clockMode] = modeKey == .clock
                CachedDefaults[.syncMode] = modeKey == .sync
                DC.adaptiveMode = modeKey.mode
                self.resetElements()
                self.windowController?.window?.displayIfNeeded()
                self.manageDisplayControllerActivity(mode: modeKey)
            }
        }.store(in: &observers)
    }

    func checkForHighMemoryUsage() {
        memoryUsageChecker = asyncEvery(30.seconds) { [self] _ in
            #if DEBUG
                log.debug(formattedMemoryFootprint())
            #endif
            guard let mb = memoryFootprintMB() else { return }

            if mb >= 8192 {
                memory8GBPassed = true
                return
            }
            if mb >= 4096 {
                memory4GBPassed = true
                return
            }
            if mb >= 2048 {
                memory2GBPassed = true
                return
            }
            if mb >= 1024 {
                memory1GBPassed = true
                return
            }
            if mb >= 512 {
                memory500MBPassed = true
                return
            }
        }
    }

    func listenForSettingsChange() {
        silentUpdatePublisher.sink { change in
            self.updater.automaticallyDownloadsUpdates = change.newValue
        }.store(in: &observers)
        checkForUpdatePublisher.sink { change in
            self.updater.automaticallyChecksForUpdates = change.newValue
        }.store(in: &observers)
        showDummyDisplaysPublisher.sink { _ in
            DC.resetDisplayList(configurationPage: true)
        }.store(in: &observers)
        showVirtualDisplaysPublisher.sink { _ in
            DC.resetDisplayList(configurationPage: true)
        }.store(in: &observers)
        showAirplayDisplaysPublisher.sink { _ in
            DC.resetDisplayList(configurationPage: true)
        }.store(in: &observers)
        showProjectorDisplaysPublisher.sink { _ in
            DC.resetDisplayList(configurationPage: true)
        }.store(in: &observers)
        showDisconnectedDisplaysPublisher.sink { _ in
            DC.resetDisplayList(configurationPage: true)
        }.store(in: &observers)
        detectResponsivenessPublisher.sink { change in
            let shouldDetect = change.newValue
            if !shouldDetect {
                DC.activeDisplays.values.forEach { $0.responsiveDDC = true }
            }
        }.store(in: &observers)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let mode = AdaptiveModeKey(rawValue: menuItem.tag) else {
            return false
        }
        return mode.available
    }

    func showWindow(after ms: Int? = nil, position: NSPoint? = nil, focus: Bool = true) {
        guard let ms else {
            createAndShowWindow(
                "windowController",
                controller: &windowController,
                focus: focus,
                screen: NSScreen.withMouse,
                position: position
            )
            return
        }
        windowShowTask = mainAsyncAfter(ms: ms) { [self] in
            createAndShowWindow(
                "windowController",
                controller: &windowController,
                focus: focus,
                screen: NSScreen.withMouse,
                position: position
            )
        }
    }

    func handleDaemon() {
        let handler = { (shouldStartAtLogin: Bool) in
            guard let appPath = p(Bundle.main.bundlePath) else { return }

            let appDir = (try? appPath.parent.realpath()) ?? appPath.parent
            guard appDir.components.starts(with: self.APP_DIR) || appDir.components.starts(with: self.SVAPP_DIR) else { return }

            if #available(macOS 13.0, *),
               withTimeout(5.seconds, name: "SMAppService", {
                   if shouldStartAtLogin {
                       try SMAppService.mainApp.register()
                   } else {
                       try SMAppService.mainApp.unregister()
                   }
                   return true
               }) == true
            {
                log.debug("SMAppService registered")
            } else {
                LaunchAtLoginController().setLaunchAtLogin(shouldStartAtLogin, for: appPath.url)
                log.debug("LaunchAtLoginController registered")
            }
        }

        handler(CachedDefaults[.startAtLogin])
        startAtLoginPublisher.sink { change in
            handler(change.newValue)
        }.store(in: &observers)
    }

    func applicationDidResignActive(_: Notification) {
        log.debug("applicationDidResignActive")
    }

    func windowDidResignKey(_ notification: Notification) {
        log.debug("windowDidResignKey")
        guard let w = notification.object as? ModernWindow, w.isVisible, w.title == "Settings" else { return }
    }

    func windowDidResignMain(_ notification: Notification) {
        log.debug("windowDidResignMain")
        guard let w = notification.object as? ModernWindow, w.isVisible, w.title == "Settings" else { return }
    }

    func windowDidBecomeMain(_ notification: Notification) {
        log.debug("windowDidBecomeMain")
        guard let w = notification.object as? ModernWindow, w.isVisible, w.title == "Settings",
              let locationManager else { return }

        switch locationManager.auth {
        case .notDetermined, .restricted:
            if !CachedDefaults[.manualLocation] {
                log.debug("Requesting location permissions")
                locationManager.requestAlwaysAuthorization()
            }
        case .authorizedAlways:
            log.debug("Location authorized")
        case .denied:
            log.debug("Location denied")
        @unknown default:
            log.debug("Location status unknown")
        }
        goToPage(ignoreUIElement: true)
        mainAsyncAfter(ms: 500) { [self] in
            goToPage()
        }
    }

    func activateUIElement(_ uiElement: UIElement, page: Int, highlight _: Bool = true) {
        guard let w = windowController?.window, let view = w.contentView, !view.subviews.isEmpty, !view.subviews[0].subviews.isEmpty,
              let pageController = view.subviews[0].subviews[0].nextResponder as? PageController else { return }

        switch uiElement {
        case .displayControls:
            guard let display = pageController.arrangedObjects.prefix(page + 1).last as? Display,
                  let displayViewController = pageController
                  .viewControllers[NSPageController.ObjectIdentifier(display.serial)] as? DisplayViewController,
                  let button = displayViewController.settingsButton
            else { return }
            log.debug("Clicking on Controls")
            if !CachedDefaults[.showAdvancedDisplaySettings] {
                CachedDefaults[.showAdvancedDisplaySettings] = true
            }
            mainAsyncAfter(ms: 300) { button.open() }
        case .displayDDC:
            guard let display = pageController.arrangedObjects.prefix(page + 1).last as? Display,
                  let displayViewController = pageController
                  .viewControllers[NSPageController.ObjectIdentifier(display.serial)] as? DisplayViewController,
                  let button = displayViewController.ddcButton
            else { return }
            log.debug("Clicking on DDC")
            if !CachedDefaults[.showAdvancedDisplaySettings] {
                CachedDefaults[.showAdvancedDisplaySettings] = true
            }
            mainAsyncAfter(ms: 300) { button.open() }
        case .displayGamma:
            guard let display = pageController.arrangedObjects.prefix(page + 1).last as? Display,
                  let displayViewController = pageController
                  .viewControllers[NSPageController.ObjectIdentifier(display.serial)] as? DisplayViewController,
                  let button = displayViewController.colorsButton
            else { return }
            log.debug("Clicking on Colors")
            if !CachedDefaults[.showAdvancedDisplaySettings] {
                CachedDefaults[.showAdvancedDisplaySettings] = true
            }
            mainAsyncAfter(ms: 300) { button.open() }
        case .displayReset:
            guard let display = pageController.arrangedObjects.prefix(page + 1).last as? Display,
                  let displayViewController = pageController
                  .viewControllers[NSPageController.ObjectIdentifier(display.serial)] as? DisplayViewController,
                  let button = displayViewController.resetButton
            else { return }
            log.debug("Clicking on Reset")
            if !CachedDefaults[.showAdvancedDisplaySettings] {
                CachedDefaults[.showAdvancedDisplaySettings] = true
            }
            mainAsyncAfter(ms: 300) { button.open() }
        }
    }

    func goToPage(ignoreUIElement: Bool = false, highlight: Bool = false) {
        guard let view = windowController?.window?.contentView, !view.subviews.isEmpty, !view.subviews[0].subviews.isEmpty,
              let pageController = view.subviews[0].subviews[0].nextResponder as? PageController,
              let splitViewController = pageController.parent as? SplitViewController,
              pageController.arrangedObjects.count > currentPage
        else { return }

        if pageController.selectedIndex != currentPage {
            // pageController.animator().selectedIndex = currentPage
            pageController.select(index: currentPage)
            switch currentPage {
            case 0:
                splitViewController.hotkeysPage()
            case 1:
                splitViewController.configurationPage()
            case pageController.arrangedObjects.count - 1:
                splitViewController.lastPage()
            default:
                splitViewController.displayPage()
            }
        }

        if !ignoreUIElement, let uiElement {
            mainAsyncAfter(ms: 500) { [self] in
                activateUIElement(uiElement, page: currentPage, highlight: highlight)
                self.uiElement = nil
            }
        }
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        showWindow()
        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
        return true
    }

    func applicationDidBecomeActive(_: Notification) {
        if didBecomeActiveAtLeastOnce, CachedDefaults[.hideMenuBarIcon] {
            showWindow()
        }
        didBecomeActiveAtLeastOnce = true
    }

    func getMarkdownRenderer() -> SwiftyMarkdown {
        let md = getMD(dark: darkMode)

        md.code.color = infoColor
        md.body.color = infoColor
        md.body.fontSize = 12

        md.bold.color = dullRed

        md.h6.fontSize = 13
        md.h6.color = infoColor

        return md
    }

    func setInfoMenuToggleTitle(show infoMenuShown: Bool? = nil) {
        let infoMenuShown = infoMenuShown ?? CachedDefaults[.infoMenuShown]
        let padding = (CachedDefaults[.startAtLogin] || blackOutMenuItem.state == .on || faceLightMenuItem.state == .on) ? "      " : "   "
        if infoMenuShown {
            (infoMenuToggle.view as! NSTextField).attributedStringValue = "\(padding)Useful Info"
                .withFont(.systemFont(ofSize: 13, weight: .regular)) + " (click to hide)"
                .withFont(monospace(size: 12, weight: .regular)).withTextColor(explanationColor)
        } else {
            (infoMenuToggle.view as! NSTextField).attributedStringValue = "\(padding)Useful Info"
                .withFont(.systemFont(ofSize: 13, weight: .regular)) + " (click to show)"
                .withFont(monospace(size: 12, weight: .regular)).withTextColor(explanationColor)
        }
    }

    func toggleInfoMenuItem() {
        mainAsync { [self] in
            let show = !CachedDefaults[.infoMenuShown]
            CachedDefaults[.infoMenuShown] = show
            infoMenuItem.isHidden = !show
            setInfoMenuToggleTitle(show: show)
        }
    }

    func updateInfoMenuItem(showBrightnessMenuBar: Bool? = nil) {
        if showBrightnessMenuBar ?? CachedDefaults[.showBrightnessMenuBar],
           let button = statusItem.button,
           let display = CachedDefaults[.showOnlyExternalBrightnessMenuBar]
           ? DC.mainExternalDisplay
           : DC.cursorDisplay
        {
            button.imagePosition = .imageLeading
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineHeightMultiple = 0.55
            button.attributedTitle = " B \(display.brightness.uint16Value)\n C \(display.contrast.uint16Value)"
                .withFont(.monospacedSystemFont(ofSize: 10, weight: .medium))
                .withBaselineOffset(-5)
                .withParagraphStyle(paragraphStyle)
                .withKern(-0.8)
            mainAsync {
                self.statusItemButtonController?.frame = button.frame
            }
        } else if let button = statusItem.button {
            button.attributedTitle = "".attributedString
            button.imagePosition = .imageOnly
            mainAsync {
                self.statusItemButtonController?.frame = button.frame
            }
        }

        guard menuShown else { return }
        infoMenuItem.attributedTitle = markdown.attributedString(from: "\(externalLux)\(internalLux)\(sun)".trimmed)
            .withFont(.systemFont(ofSize: 12, weight: .semibold))
        infoMenuItem.isEnabled = false
    }

    func manageDisplayControllerActivity(mode _: AdaptiveModeKey) {
//        log.debug("Started DisplayController in \(mode.str) mode")
        mainAsyncAfter(ms: 1000) {
            DC.recomputeAllDisplaysBrightness(activeDisplays: DC.activeDisplayList)
            DC.adaptBrightness()
        }
    }

    func startValuesReaderThread() {
        valuesReaderThread = Repeater(every: 10, name: "DDCReader", tolerance: 5) {
            guard !DC.screensSleeping, !DC.locked else { return }

            if CachedDefaults[.refreshValues] {
                DC.fetchValues()
            }
        }
    }

    func initDisplayController() {
        DC.displays = DC.getDisplaysLock.around {
            DisplayController.getDisplays(
                includeVirtual: CachedDefaults[.showVirtualDisplays],
                includeAirplay: CachedDefaults[.showAirplayDisplays],
                includeProjector: CachedDefaults[.showProjectorDisplays],
                includeDummy: CachedDefaults[.showDummyDisplays]
            )
        }
        DC.sentryDataTask = mainAsyncAfter(ms: 5000) {
            DC.addSentryData()
        }

        if CachedDefaults[.refreshValues] {
            startValuesReaderThread()
        }

        manageDisplayControllerActivity(mode: DC.adaptiveModeKey)
        if DC.adaptiveMode.available {
            DC.adaptiveMode.watch()
        }

        DC.screencaptureIsRunning.removeDuplicates()
            .debounce(for: .milliseconds(10), scheduler: RunLoop.main)
            .sink { takingScreenshot in
                if takingScreenshot, DC.activeDisplayList.contains(where: { $0.shadeWindowController != nil }) {
                    DC.activeDisplayList
                        .filter { $0.shadeWindowController != nil }
                        .forEach { d in
                            d.shadeWindowController?.close()
                            d.shadeWindowController = nil
                        }
                }

                if !takingScreenshot {
                    DC.activeDisplayList
                        .filter { $0.hasSoftwareControl && !$0.supportsGamma }
                        .forEach { $0.preciseBrightness = $0.preciseBrightness }
                }
            }.store(in: &observers)
    }

    @discardableResult func initMenuWindow() -> PanelWindow {
        if menuWindow == nil {
            let view = AnyView(QuickActionsView())
            menuWindow = PanelWindow(swiftuiView: view)
        }

        return menuWindow!
    }

    func setExplanationStyle(_ menuItem: NSMenuItem, title: String? = nil) {
        menuItem.attributedTitle = (title ?? menuItem.attributedTitle?.string ?? menuItem.title).withTextColor(explanationColor)
            .withFont(.systemFont(ofSize: 11, weight: .semibold))
    }

    func initMenuItems() {
        markdown = getMarkdownRenderer()

        let view = NonClosingMenuText(frame: NSRect(x: 0, y: 0, width: 300, height: 16))
        view.isEditable = false
        view.drawsBackground = false
        view.backgroundColor = .clear
        view.isBordered = false
        view.bg = .clear
        view.onClick = { [self] in
            toggleInfoMenuItem()
        }
        infoMenuToggle.view = view
        infoMenuItem.isHidden = !CachedDefaults[.infoMenuShown]

        setExplanationStyle(faceLightExplanationMenuItem)
        setExplanationStyle(blackOutExplanationMenuItem)
        setExplanationStyle(blackOutKillSwitchExplanationMenuItem)
        setInfoMenuToggleTitle()
        updateInfoMenuItem()
    }

    func initMenubarIcon() {
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name(Defaults[.alternateMenuBarIcon] ? "MenubarIcon2" : "MenubarIcon"))
            button.image?.isTemplate = true
            button.imagePosition = CachedDefaults[.showBrightnessMenuBar] ? .imageLeading : .imageOnly

            statusItemButtonController = StatusItemButtonController(button: button)
            button.addSubview(statusItemButtonController!)
        }
        statusItem.menu = nil
        initMenuItems()

        pub(.alternateMenuBarIcon)
            .sink { change in
                guard let button = self.statusItem.button else {
                    return
                }
                button.image = NSImage(named: NSImage.Name(change.newValue ? "MenubarIcon2" : "MenubarIcon"))
            }.store(in: &observers)

        initMenuWindow()
        DistributedNotificationCenter.default()
            .publisher(for: NSNotification.Name(rawValue: kAppleInterfaceThemeChangedNotification), object: nil)
            .sink { [self] notification in
                log.info("\(notification.name)")
                mainAsync { [self] in
                    initMenuItems()
                    for (key, popover) in POPOVERS {
                        guard let popover else { continue }
                        popover.close()
                        popover.contentViewController = nil
                        POPOVERS[key] = nil
                    }

                    for (key, popover) in INPUT_HOTKEY_POPOVERS {
                        log.debug("Adapting \(key) input hotkey popover")

                        guard let backingView = popover?.contentViewController?.view.subviews
                            .first(where: { $0.identifier == POPOVER_BACKING_VIEW_ID }),
                            let blurView = popover?.contentViewController?.view.subviews
                            .first(where: { $0.identifier == POPOVER_BLUR_VIEW_ID })
                        else {
                            log.debug("Can't find input hotkey popover for \(key)")
                            continue
                        }

                        backingView.layer?.backgroundColor = popoverBackgroundColor.cgColor
                        blurView.shadow = POPOVER_SHADOW
                    }
                    recreateWindow()
                }
            }
            .store(in: &observers)
        colorSchemePublisher
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [self] _ in
                recreateWindow(page: Page.settings.rawValue)
            }.store(in: &observers)
    }

    func listenForScreenConfigurationChanged() {
        zeroGammaChecker = Repeater(every: 3, name: "zeroGammaChecker", tolerance: 10) {
            DC.activeDisplayList
                .filter { d in
                    !d.isForTesting && !d.settingGamma && !d.blackOutEnabled &&
                        (d.hasSoftwareControl || CachedDefaults[.hdrWorkaround] || d.enhanced || d.subzero || d.applyGamma) &&
                        GammaTable(for: d.id, allowZero: true).isZero
                }
                .forEach { d in
                    log.warning("Gamma tables are zeroed out for display \(d.description)!\nTrying to revert to last non-zero gamma tables")
                    if let table = d.lastGammaTable, !table.isZero {
                        d.apply(gamma: table)
                    } else {
                        d.apply(gamma: GammaTable.original)
                    }

                    if !CachedDefaults[.screenBlankingIssueWarningShown] {
                        CachedDefaults[.screenBlankingIssueWarningShown] = true
                        askAndHandle(
                            message: "Screen Blanking Issue Detected",
                            info: """
                            Because of a macOS bug in the **Gamma API**, your screen might have gone blank.

                            Lunar will now try to minimise future Gamma changes by disabling the **HDR compatibility workaround**.

                            If the screen doesn't come back on by itself, you can try one of the following:

                            * Changing the display color profile in `System Preferences`
                            * Logging out, then logging back in
                            * Restarting the computer
                            """,
                            cancelButton: nil,
                            screen: NSScreen.screens.first(where: { !$0.isVirtual && !$0.hasDisplayID(1) }),
                            wide: true,
                            markdown: true
                        ) { _ in
                            CachedDefaults[.hdrWorkaround] = false
                        }
                    }

                    if GammaTable(for: d.id, allowZero: true).isZero {
                        log
                            .warning(
                                "Applying last gamma tables didn't work for display \(d.description)!\nTrying to reset ColorSync settings"
                            )
                        restoreColorSyncSettings()
                    }
                }
        }

        CGDisplayRegisterReconfigurationCallback({ displayID, flags, _ in
            guard !flags.isSubset(of: [.beginConfigurationFlag, .desktopShapeChangedFlag, .movedFlag, .setMainFlag]) else {
                return
            }

            log.debug("CGDisplayRegisterReconfigurationCallback \(flags) \(displayID)")

            let removedDisplay: Bool = flags.has(someOf: [.removeFlag, .disabledFlag])
            let addedDisplay: Bool = flags.has(someOf: [.addFlag, .enabledFlag])

            if removedDisplay {
                let wcs: [(String, NSWindowController)] = ["corner", "gamma", "shade", "faceLight"].compactMap { wt in
                    guard let wc = Display.getWindowController(displayID, type: wt) else {
                        return nil
                    }
                    return (wt, wc)
                }

                for (windowType, wc) in wcs {
                    wc.close()
                    Display.setWindowController(displayID, type: windowType, windowController: nil)
                }
            }

            DC.panelRefreshPublisher.send(displayID)
            if addedDisplay {
                DC.retryAutoBlackoutLater()
            }

            #if arch(arm64)
                if addedDisplay || removedDisplay {
                    DDC.rebuildDCPList()
                }
            #endif

            #if arch(arm64)
                if #available(macOS 13, *) {
                    if addedDisplay, let d = DC.displaysBySerial[Display.uuid(id: displayID)], !d.active, d.keepDisconnected {
                        mainAsyncAfter(ms: 10) {
                            DC.dis(displayID, display: d, force: true)
                        }
                        return
                    } else {
                        log.verbose("addedDisplay: \(addedDisplay)")
                        if let d = DC.displaysBySerial[Display.uuid(id: displayID)] {
                            log.verbose("storedDisplay: \(d)")
                            log.verbose("storedDisplay.active: \(d.active)")
                            log.verbose("storedDisplay.keepDisconnected: \(d.keepDisconnected)")
                        } else {
                            log.verbose("storedDisplay: \(Display.uuid(id: displayID))")
                        }
                    }
                }
            #endif

            if addedDisplay, DC.screenIDs.count == 1, DC.xdrContrast > 0 {
                log.info("Disabling XDR Contrast if we have more than 1 screen")
                lastXDRContrastResetTime = Date()
                DC.setXDRContrast(0)
            }

        }, nil)

        DistributedNotificationCenter
            .default()
            .publisher(
                for: NSNotification.Name(rawValue: kColorSyncDisplayDeviceProfilesNotification.takeRetainedValue() as String),
                object: nil
            )
            .sink { n in
                log.info("\(n.name)")
                guard let displayUUID = n.userInfo?["DeviceID"] as? String,
                      let display = DC.activeDisplays.values.first(where: { $0.serial == displayUUID }) else { return }
                log.info("ColorSync changed for \(display)")
                display.refreshGamma()
                display.reapplyGamma()

            }.store(in: &observers)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
            .eraseToAnyPublisher().map { $0 as Any? }
            .merge(with: NSWorkspace.shared.publisher(for: \.frontmostApplication).map { $0 as Any? }.eraseToAnyPublisher())
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [self] notif in
                switch notif {
                case let n as Notification:
                    log.info("\(n.name)")
                case let a as NSRunningApplication:
                    log.info("Frontmost App: \(a.localizedName ?? "") \(a.bundleIdentifier ?? "") \(a.processIdentifier)")
                default:
                    log.info("\(notif.debugDescription)")
                }

                guard let apps = CachedDefaults[.appExceptions], !apps.isEmpty else {
                    updateInfoMenuItem()
                    return
                }

                DC.adaptBrightness(force: true)
                updateInfoMenuItem()
            }
            .store(in: &observers)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification, object: nil)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { notification in
                log.info("\(notification.name)")
                DC.reconfigure()
                DC.retryAutoBlackoutLater()
            }.store(in: &observers)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification, object: nil)
            .sink { _ in
                lastColorSyncReset = Date()
                for d in DC.activeDisplayList {
                    d.hdrOn = d.potentialEDR > 2 && d.edr > 1
                }
                #if DEBUG
                    if let d = NSScreen.main {
                        log.verbose("Max EDR: \(d.maximumExtendedDynamicRangeColorComponentValue.str(decimals: 3))")
                        log.verbose("Potential EDR: \(d.maximumPotentialExtendedDynamicRangeColorComponentValue.str(decimals: 3))")
                        log.verbose("Reference EDR: \(d.maximumReferenceExtendedDynamicRangeColorComponentValue.str(decimals: 3))")
                    }
                #endif
            }.store(in: &observers)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification, object: nil)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { notification in
                log.info("\(notification.name)")

                #if arch(arm64)
                    DDC.rebuildDCPList()
                #endif

                DC.activeDisplays.values.filter { !$0.isForTesting }.forEach { d in
                    let maxEDR = d.computeMaxEDR()

                    guard d.maxEDR != maxEDR else {
                        return
                    }

                    let oldMaxSoftwareBrightness = d.maxSoftwareBrightness
                    d.maxEDR = maxEDR

                    if d.softwareBrightness > 1.0, timeSince(d.hdrWindowOpenedAt) > 1 {
                        let oldSoftwareBrightness = d.softwareBrightness.map(from: (1.0, oldMaxSoftwareBrightness), to: (0.0, 1.0))
                        d.softwareBrightness = oldSoftwareBrightness.map(from: (0.0, 1.0), to: (1.0, d.maxSoftwareBrightness))
                    }
                }
            }.store(in: &observers)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification, object: nil)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { _ in
                log.info("Screen configuration changed")

                for d in DC.activeDisplays.values {
                    d.updateCornerWindow()
                }
                DC.screenIDs = Set(NSScreen.onlineDisplayIDs)
            }.store(in: &observers)

        let wakePublisher = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.screensDidWakeNotification, object: nil)
        let sleepPublisher = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.screensDidSleepNotification, object: nil)

        let logoutPublisher = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        let loginPublisher = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        let lockPublisher = DistributedNotificationCenter.default()
            .publisher(for: NSNotification.Name(rawValue: "com.apple.screenIsLocked"), object: nil)
        let unlockPublisher = DistributedNotificationCenter.default()
            .publisher(for: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"), object: nil)

        func reapplyAfterWake() {
            guard CachedDefaults[.reapplyValuesAfterWake] else { return }

            for display in DC.activeDisplayList.filter(\.isNative) {
                guard let control = display.control as? AppleNativeControl else { continue }

                let brightness = AppleNativeControl.readBrightnessDisplayServices(id: display.id)
                guard let lastBrightness = display.lastNativeBrightness, brightness != lastBrightness else {
                    continue
                }

                log.debug("After wake brightness is \(brightness). Re-applying previous brightness \(lastBrightness) for \(display.description)")
                if lastBrightness == 1.0 {
                    _ = control.writeBrightness(0, preciseBrightness: 0.99)
                }
                _ = control.writeBrightness(0, preciseBrightness: lastBrightness)
            }

        }

        lockPublisher.sink { _ in DC.locked = true }.store(in: &observers)
        unlockPublisher.sink { _ in DC.locked = false }.store(in: &observers)
        unlockPublisher
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { _ in
                guard !DC.screensSleeping else { return }
                reapplyAfterWake()
            }
            .store(in: &observers)

        wakePublisher
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { _ in
                guard !DC.locked else { return }
                reapplyAfterWake()
            }.store(in: &observers)

        loginPublisher
            .merge(with: logoutPublisher)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { notif in
                log.info(notif.name.rawValue)
                switch notif.name {
                case NSWorkspace.sessionDidBecomeActiveNotification:
                    DC.loggedOut = false
                    log.info("SESSION: Log in")
                case NSWorkspace.sessionDidResignActiveNotification:
                    DC.loggedOut = true
                    DC.resetDisplayListTask?.cancel()
                    log.info("SESSION: Log out")
                default:
                    break
                }
            }.store(in: &observers)

        sleepPublisher
            .debounce(for: .milliseconds(1), scheduler: RunLoop.main)
            .sink { notif in
                log.info(notif.name.rawValue)
                switch notif.name {
                case NSWorkspace.screensDidSleepNotification:
                    DC.screensSleeping = true
                    DC.resetDisplayListTask?.cancel()
                    for display in DC.activeDisplayList {
                        display.resetScheduledTransition()
                    }
                    ClockMode.specific.readaptTask = nil

                    log.info("SESSION: Screen sleep warmup")
                default:
                    break
                }
            }.store(in: &observers)

        wakePublisher
            .merge(with: sleepPublisher)
            .merge(with: logoutPublisher)
            .merge(with: loginPublisher)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { notif in
                log.info(notif.name.rawValue)
                switch notif.name {
                case NSWorkspace.screensDidWakeNotification where !DC.loggedOut,
                     NSWorkspace.sessionDidBecomeActiveNotification:
                    log.debug("SESSION: Screen wake")
                    wakeTime = Date()
                    DC.screensSleeping = false
                    DC.retryAutoBlackoutLater()

                    if CachedDefaults[.refreshValues] {
                        self.startValuesReaderThread()
                    }
                    SyncMode.refresh()
                    if DC.adaptiveMode.available {
                        DC.adaptiveMode.watch()
                    }
                    self.resetStatesPublisher.send(true)

                    if CachedDefaults[.reapplyValuesAfterWake] {
                        self.screenWakeAdapterTask = Repeater(every: 2, times: CachedDefaults[.wakeReapplyTries], name: "screenWakeAdapter") {
                            DC.adaptBrightness(force: true)

                            for display in DC.activeDisplayList.filter(\.blackOutEnabled) {
                                display.apply(gamma: GammaTable.zero, force: true)

                                if display.isSmartBuiltin, display.readBrightness() != 0 {
                                    display.withoutSmoothTransition {
                                        display.withForce {
                                            display.brightness = 0
                                        }
                                    }
                                }
                            }

                            for display in DC.activeDisplayList.filter({ !$0.blackOutEnabled && $0.reapplyColorGain }) {
                                _ = display.control?.setRedGain(display.redGain.uint16Value)
                                _ = display.control?.setGreenGain(display.greenGain.uint16Value)
                                _ = display.control?.setBlueGain(display.blueGain.uint16Value)
                            }
                            for (serial, hdrShouldBeOn) in DC.enabledHDRBeforeXDR where hdrShouldBeOn {
                                DC.activeDisplaysBySerial[serial]?.panel?.setPreferHDRModes(true)
                            }

                            for display in DC.activeDisplayList.filter({ $0.keepHDREnabled && !$0.hdr }) {
                                display.hdr = true
                            }

                            if Defaults[.jitterBrightnessOnWake] {
                                for display in DC.externalActiveDisplays.filter(\.isNative) {
                                    guard let br = display.lastNativeBrightness, let control = display.control as? AppleNativeControl else {
                                        continue
                                    }

                                    log.debug("Jittering brightness for \(display.description)")
                                    let brDown = (br - 0.01).capped(between: 0.0, and: 1.0)
                                    let brUp = (br + 0.01).capped(between: 0.0, and: 1.0)

                                    log.debug("  Writing brightness \(brDown) for \(display.description)")
                                    _ = control.writeBrightness(0, preciseBrightness: brDown)
                                    log.debug("  Writing brightness \(br) for \(display.description)")
                                    _ = control.writeBrightness(0, preciseBrightness: br)
                                    log.debug("  Writing brightness \(brUp) for \(display.description)")
                                    _ = control.writeBrightness(0, preciseBrightness: brUp)
                                    log.debug("  Writing brightness \(br) for \(display.description)")
                                    _ = control.writeBrightness(0, preciseBrightness: br)
                                }
                            }
                        }
                    }
                    serve(host: CachedDefaults[.listenForRemoteCommands] ? "0.0.0.0" : "127.0.0.1")

                case NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification:
                    log.debug("SESSION: Screen sleep")
                    DC.screensSleeping = true
                    DC.cancelAutoBlackout()

                    self.valuesReaderThread = nil
                    DC.adaptiveMode.stopWatching()
                    self.server.stopAsync()
                default:
                    break
                }
            }.store(in: &observers)
    }

    func initPopover<T: NSViewController>(
        _ popoverKey: String,
        identifier: String,
        controllerType _: T.Type,
        appearance: NSAppearance.Name = .vibrantLight
    ) {
        if !POPOVERS.keys.contains(popoverKey) || POPOVERS[popoverKey]! == nil {
            POPOVERS[popoverKey] = NSPopover()
        }

        guard let popover = POPOVERS[popoverKey]! else { return }

        if popover.contentViewController == nil, let stb = NSStoryboard.main,
           let controller = stb.instantiateController(
               withIdentifier: NSStoryboard.SceneIdentifier(identifier)
           ) as? T
        {
            popover.contentViewController = controller
            popover.contentViewController!.loadView()
            popover.appearance = NSAppearance(named: appearance)
        }
    }

    func initPopovers() {
        initPopover(
            "help",
            identifier: "HelpPopoverController",
            controllerType: HelpPopoverController.self,
            appearance: darkMode ? .vibrantDark : .vibrantLight
        )
        initPopover(
            "settings",
            identifier: "SettingsPopoverController",
            controllerType: SettingsPopoverController.self,
            appearance: darkMode ? .vibrantDark : .vibrantLight
        )
        initPopover(
            "colors",
            identifier: "ColorsPopoverController",
            controllerType: ColorsPopoverController.self,
            appearance: darkMode ? .vibrantDark : .vibrantLight
        )
        initPopover(
            "ddc",
            identifier: "DDCPopoverController",
            controllerType: DDCPopoverController.self,
            appearance: darkMode ? .vibrantDark : .vibrantLight
        )
        initPopover(
            "reset",
            identifier: "ResetPopoverController",
            controllerType: ResetPopoverController.self,
            appearance: darkMode ? .vibrantDark : .vibrantLight
        )
    }

    func showConfigurationPage() {
        currentPage = Page.settings.rawValue
        uiElement = nil
        appDelegate!.goToPage()
    }

    func recreateWindow(page: Int? = nil) {
        if windowController?.window != nil {
            let window = windowController!.window!
            let shouldShow = window.isVisible
            let lastPosition = window.frame.origin
            windowController?.close()
            windowController?.window = nil
            windowController = nil
            if let page {
                currentPage = page
            }
            if shouldShow {
                showWindow(position: lastPosition, focus: NSRunningApplication.current.isActive)
            }
        }
    }

    func addObservers() {
        hdrWorkaroundPublisher.sink { change in
            Self.hdrWorkaround = change.newValue
            self.hdrFixer = change.newValue ? Self.fixHDR() : nil
        }.store(in: &observers)

        ddcSleepLongerPublisher.sink { change in
            Defaults.withoutPropagation {
                CachedDefaults[.ddcSleepFactor] = change.newValue ? .long : .short
            }
        }.store(in: &observers)

        ddcSleepFactorPublisher.sink { change in
            Defaults.withoutPropagation {
                CachedDefaults[.ddcSleepLonger] = change.newValue == .long
            }
        }.store(in: &observers)

        dayMomentsPublisher.sink {
            if DC.adaptiveModeKey == .location {
                DC.adaptBrightness()
            }
        }.store(in: &observers)

        refreshValuesPublisher.sink { change in
            self.valuesReaderThread = nil
            if change.newValue {
                self.startValuesReaderThread()
            }
        }.store(in: &observers)

        brightnessKeysEnabledPublisher.sink { change in
            self.startOrRestartMediaKeyTap(brightnessKeysEnabled: change.newValue)
        }.store(in: &observers)
        volumeKeysEnabledPublisher.sink { change in
            self.startOrRestartMediaKeyTap(volumeKeysEnabled: change.newValue)
        }.store(in: &observers)
        useAlternateBrightnessKeysPublisher.sink { change in
            MediaKeyTap.useAlternateBrightnessKeys = change.newValue
        }.store(in: &observers)

        hideMenuBarIconPublisher.sink { change in
            log.info("Hiding menu bar icon \(change.newValue)")
            self.statusItem.isVisible = !change.newValue
        }.store(in: &observers)
        statusItem.isVisible = !CachedDefaults[.hideMenuBarIcon]

        showDockIconPublisher.sink { change in
            log.info("Showing dock icon \(change.newValue)")
            NSApp.setActivationPolicy(change.newValue ? .regular : .accessory)
            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
        }.store(in: &observers)
        NSApp.setActivationPolicy(CachedDefaults[.showDockIcon] ? .regular : .accessory)

        NotificationCenter.default
            .publisher(for: .defaultOutputDeviceChanged, object: nil)
            .merge(
                with: NotificationCenter.default
                    .publisher(for: .defaultSystemOutputDeviceChanged, object: nil)
            )
            .debounce(for: .milliseconds(700), scheduler: RunLoop.main)
            .sink { _ in appDelegate!.startOrRestartMediaKeyTap() }
            .store(in: &observers)
        NotificationCenter.default
            .publisher(for: currentDataPointChanged, object: nil)
            .debounce(for: .milliseconds(700), scheduler: RunLoop.main)
            .sink { _ in appDelegate!.updateInfoMenuItem() }
            .store(in: &observers)
        showBrightnessMenuBarPublisher
            .merge(with: showOnlyExternalBrightnessMenuBarPublisher)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [self] change in
                if change.newValue {
                    statusItem.button?.imagePosition = .imageLeading
                } else {
                    statusItem.button?.imagePosition = .imageOnly
                }
                updateInfoMenuItem(showBrightnessMenuBar: change.newValue)
                closeAndOpenMenuWindow()

            }.store(in: &observers)
    }

    func setKeyEquivalent(_ hotkeyIdentifier: HotkeyIdentifier) {
        guard let menuItem = menuItem(hotkeyIdentifier) else { return }
        Hotkey.setKeyEquivalent(hotkeyIdentifier.rawValue, menuItem: menuItem, hotkeys: CachedDefaults[.hotkeys])
    }

    func menuItem(_ hotkeyIdentifier: HotkeyIdentifier) -> NSMenuItem? {
        switch hotkeyIdentifier {
        case .lunar:
            preferencesMenuItem
        case .restart:
            restartMenuItem
        case .percent0:
            percent0MenuItem
        case .percent25:
            percent25MenuItem
        case .percent50:
            percent50MenuItem
        case .percent75:
            percent75MenuItem
        case .percent100:
            percent100MenuItem
        case .faceLight:
            faceLightMenuItem
        case .blackOut:
            blackOutMenuItem
        case .blackOutNoMirroring:
            blackOutNoMirroringMenuItem
        case .blackOutPowerOff:
            blackOutPowerOffMenuItem
        case .blackOutOthers:
            blackOutOthersMenuItem
        case .brightnessUp:
            brightnessUpMenuItem
        case .brightnessDown:
            brightnessDownMenuItem
        case .contrastUp:
            contrastUpMenuItem
        case .contrastDown:
            contrastDownMenuItem
        case .volumeDown:
            volumeDownMenuItem
        case .volumeUp:
            volumeUpMenuItem
        case .muteAudio:
            muteAudioMenuItem
        default:
            nil
        }
    }

    func setKeyEquivalents(_ hotkeys: Set<PersistentHotkey>) {
        Hotkey.setKeyEquivalent(HotkeyIdentifier.lunar.rawValue, menuItem: preferencesMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.restart.rawValue, menuItem: restartMenuItem, hotkeys: hotkeys)

        Hotkey.setKeyEquivalent(HotkeyIdentifier.percent0.rawValue, menuItem: percent0MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.percent25.rawValue, menuItem: percent25MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.percent50.rawValue, menuItem: percent50MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.percent75.rawValue, menuItem: percent75MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.percent100.rawValue, menuItem: percent100MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.faceLight.rawValue, menuItem: faceLightMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.blackOut.rawValue, menuItem: blackOutMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.blackOutNoMirroring.rawValue, menuItem: blackOutNoMirroringMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.blackOutPowerOff.rawValue, menuItem: blackOutPowerOffMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.blackOutOthers.rawValue, menuItem: blackOutOthersMenuItem, hotkeys: hotkeys)

        Hotkey.setKeyEquivalent(HotkeyIdentifier.brightnessUp.rawValue, menuItem: brightnessUpMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.brightnessDown.rawValue, menuItem: brightnessDownMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.contrastUp.rawValue, menuItem: contrastUpMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.contrastDown.rawValue, menuItem: contrastDownMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.volumeDown.rawValue, menuItem: volumeDownMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.volumeUp.rawValue, menuItem: volumeUpMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.muteAudio.rawValue, menuItem: muteAudioMenuItem, hotkeys: hotkeys)

        menu?.update()
    }

    func onboard() {
        useOnboardingForDiagnostics = false
        createAndShowWindow("onboardWindowController", controller: &onboardWindowController)
    }

    func applicationWillFinishLaunching(_: Notification) {
        #if !DEBUG && arch(arm64)
            PFMoveToApplicationsFolderIfNecessary()
        #endif
    }

    func checkEmergencyBlackoutOff(flags: NSEvent.ModifierFlags) {
        guard CachedDefaults[.enableBlackOutKillSwitch] || appDelegate!.cleaningMode,
              flags.intersection([.command, .option, .shift, .control]) == [.command]
        else {
            if commandModifierPressedCount > 0 {
                let mods = flags.intersection([.command, .option, .shift, .control])
                log.debug(
                    "Setting commandModifierPressedCount to 0",
                    context: ["modifiers": mods.keyEquivalentStrings(), "modifiersRawValue": mods]
                )
                commandModifierPressedCount = 0
            }
            return
        }

        guard lastCommandModifierPressedTime == nil || timeSince(lastCommandModifierPressedTime!) < 0.4 else {
            commandModifierPressedCount = 0
            lastCommandModifierPressedTime = nil
            return
        }

        lastCommandModifierPressedTime = Date()
        commandModifierPressedCount += 1

        if commandModifierPressedCount >= 8 {
            commandModifierPressedCount = 0
            lastCommandModifierPressedTime = nil

            log.warning("Command key pressed 8 times in a row, disabling BlackOut forcefully!")
            #if arch(arm64)
                if #available(macOS 13, *) {
                    DC.autoBlackoutPause = true
                    DC.en()
                }
            #endif

            deactivateCleaningMode()
        }
    }

    func handleModifierScrollThreshold(event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            log.verbose("Fastest scroll threshold")
            scrollDeltaYThreshold = FASTEST_SCROLL_Y_THRESHOLD
        } else if event.modifierFlags.contains(.command) {
            log.verbose("Precise scroll threshold")
            scrollDeltaYThreshold = PRECISE_SCROLL_Y_THRESHOLD
        } else if event.modifierFlags.contains(.option) {
            log.verbose("Fast scroll threshold")
            scrollDeltaYThreshold = FAST_SCROLL_Y_THRESHOLD
        } else if event.modifierFlags.isDisjoint(with: [.command, .option, .control]) {
            log.verbose("Normal scroll threshold")
            scrollDeltaYThreshold = NORMAL_SCROLL_Y_THRESHOLD
        }

        KM.optionKeyPressed = event.modifierFlags.contains(.option)
        KM.shiftKeyPressed = event.modifierFlags.contains(.shift)
        KM.controlKeyPressed = event.modifierFlags.contains(.control)
        KM.commandKeyPressed = event.modifierFlags.contains(.command)
        // log.debug("Option key pressed: \(AppDelegate.optionKeyPressed)")
        // log.debug("Shift key pressed: \(AppDelegate.shiftKeyPressed)")
        // log.debug("Control key pressed: \(AppDelegate.controlKeyPressed)")
        // log.debug("Command key pressed: \(AppDelegate.commandKeyPressed)")
    }

    func addGlobalModifierMonitor() {
        NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [self] event in
            guard !event.modifierFlags.intersection([.command, .option, .shift, .control]).isEmpty else {
                if KM.optionKeyPressed { KM.optionKeyPressed = false }
                if KM.shiftKeyPressed { KM.shiftKeyPressed = false }
                if KM.controlKeyPressed { KM.controlKeyPressed = false }
                if KM.commandKeyPressed { KM.commandKeyPressed = false }
                return
            }
            checkEmergencyBlackoutOff(flags: event.modifierFlags)
        }
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [self] event in
            if !event.modifierFlags.intersection([.command, .option, .shift, .control]).isEmpty {
                checkEmergencyBlackoutOff(flags: event.modifierFlags)
            }
            handleModifierScrollThreshold(event: event)

            return event
        }
    }

    func handleAutoOSDEvent(_ event: NSEvent) {
        switch event.keyCode.i {
//        case kVK_Escape where DC.calibrating:
//            DC.stopCalibration()
        case kVK_Escape where DC.autoBlackoutPending:
            DC.cancelAutoBlackout()
        case kVK_Escape where DC.autoXdrPendingEnabled:
            DC.cancelAutoXdr()
        case kVK_Escape where DC.autoXdrPendingDisabled:
            DC.cancelAutoXdr()
        default:
            break
        }
    }

    func addGlobalKeyMonitor() {
        if Defaults[.accessibilityPermissionsGranted] {
            NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
                self.handleAutoOSDEvent(event)
            }
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleAutoOSDEvent(event)
            return event
        }
    }

    func addGlobalMouseDownMonitor() {
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { _ in
            guard let menuWindow, menuWindow.isVisible, !DC.calibrating else { return }
            menuWindow.forceClose()
        }
    }

    func otherLunar() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications
            .filter { item in item.bundleIdentifier == Bundle.main.bundleIdentifier }
            .first { item in item.processIdentifier != getpid() }
    }

    func trap(signal: Int32, _ action: @escaping () -> Void) {
        let s = DispatchSource.makeSignalSource(signal: signal)
        s.setEventHandler(handler: action)
        s.activate()
        AppDelegate.signalHandlers.append(s)
    }

    func handleCLI() -> Bool {
        Trap.handle(signals: [.interrupt, .termination]) { signal in
            if isServer { DC.cleanup() }
            guard signal == SIGINT else { exit(0) }

            for display in DC.displays.values {
                if display.gammaChanged {
                    display.resetGamma()
                }

                refreshScreen()
            }

            exit(0)
        }

        guard let idx = CommandLine.arguments.firstIndex(of: "@") else { return false }

        configureSentry()
        asyncNow { [self] in
            #if DEBUG
                let argList: [String] = if CommandLine.arguments.contains("-NSDocumentRevisionsDebugMode"), CommandLine.arguments.last == "YES" {
                    Array(CommandLine.arguments[idx + 1 ..< CommandLine.arguments.count - 2])
                } else {
                    Array(CommandLine.arguments[idx + 1 ..< CommandLine.arguments.count])
                }
            #else
                let argList = Array(CommandLine.arguments[idx + 1 ..< CommandLine.arguments.count])
            #endif

            let exc = tryBlock {
                guard !argList.contains("--new-instance"), self.otherLunar() != nil,
                      let socket = try? Socket.create(), let opts = Lunar.globalOptions(args: argList)
                else {
                    if !argList.contains("--remote") {
                        self.initCacheTransitionLogging()
                        Lunar.main(argList)
                    } else if argList.contains("--new-instance") {
                        print("Can't use `--remote` and `--new-instance` at the same time.")
                        cliExit(1)
                    } else {
                        print("Can't connect to a running Lunar instance.")
                        cliExit(1)
                    }
                    return
                }

                let argString = argList.without("--remote").joined(separator: CLI_ARG_SEPARATOR)
                let key = opts.key.isEmpty ? Defaults[.apiKey] : opts.key

                do {
                    try socket.connect(to: opts.host, port: LUNAR_CLI_PORT)
                    try socket.write(from: "\(key)\(CLI_ARG_SEPARATOR)\(argString)")

                    if let response = try (socket.readString())?.trimmed, !response.isEmpty {
                        print(response)
                    }
                    if argList.contains("listen") || argList.contains("--listen") {
                        var line = try socket.readString()
                        while let currentLine = line, !currentLine.isEmpty {
                            print(currentLine.trimmed)
                            line = try socket.readString()
                        }
                    }
                    cliExit(0)
                } catch {
                    print(error.localizedDescription)
                    cliExit(1)
                }
            }

            if let exc {
                log.error(exc.description)
                cliExit(1)
            }
        }

        return true
    }

    func configureSentry() {
        enableSentryObserver = enableSentryObserver ?? enableSentryPublisher
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { change in
                AppDelegate.enableSentry = change.newValue
                if change.newValue {
                    self.configureSentry()
                } else {
                    SentrySDK.close()
                }
            }

        guard AppDelegate.enableSentry else { return }
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])

        let release = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
        SentrySDK.start { options in
            options.dsn = SENTRY_DSN
            options.releaseName = "v\(release)"
            options.dist = release
            #if DEBUG
                options.environment = "dev"
                options.appHangTimeoutInterval = 10
            #else
                options.environment = "production"
                options.appHangTimeoutInterval = 60
            #endif

            if Defaults[.autoRestartOnHang] {
                options.beforeSend = { event in
                    if let exc = event.exceptions?.first, let mech = exc.mechanism, mech.type == "AppHang", let stack = exc.stacktrace {
                        log.warning("App Hanging: \(stack)")
                        concurrentQueue.asyncAfter(ms: 5000) { restart() }
                        if event.tags == nil {
                            event.tags = ["restarted": "true"]
                        } else {
                            event.tags!["restarted"] = "true"
                        }
                        return event
                    }

                    if event.tags == nil {
                        event.tags = ["restarted": restarted ? "true" : "false"]
                    } else {
                        event.tags!["restarted"] = restarted ? "true" : "false"
                    }
                    return event
                }
            }
        }

        let user = User(userId: SERIAL_NUMBER_HASH)

        if CachedDefaults[.paddleConsent] {
            user.email = producct?.activationEmail
        }

        user.username = producct?.activationID
        SentrySDK.configureScope { scope in
            scope.setUser(user)
            scope.setTag(value: DC.adaptiveModeString(), key: "adaptiveMode")
            scope.setTag(value: DC.adaptiveModeString(last: true), key: "lastAdaptiveMode")
            scope.setTag(value: CachedDefaults[.overrideAdaptiveMode] ? "false" : "true", key: "autoMode")
        }
    }

    func initCacheTransitionLogging() {
        initCache()

        brightnessTransition = CachedDefaults[.brightnessTransition]
        brightnessTransitionPublisher.sink { change in
            brightnessTransition = change.newValue
        }.store(in: &observers)
    }

    func handleCLIUpdate() {
        let lunarBin = "\(CLI_BIN_DIR)/lunar"
        if fm.fileExists(atPath: lunarBin), let currentScript = fm.contents(atPath: lunarBin)?.s,
           currentScript.contains("Contents/MacOS/Lunar"), currentScript.contains(" $@ ")
        {
            fm.createFile(
                atPath: lunarBin,
                contents: LUNAR_CLI_SCRIPT.data(using: .utf8),
                attributes: [.posixPermissions: 0o755]
            )
        }
    }

    func handleCLIInstall() {
        guard CommandLine.arguments.contains("install-cli") || CommandLine.arguments
            .contains("installcli") || (CommandLine.arguments.contains("install") && CommandLine.arguments.contains("cli"))
        else { return }

        do {
            try installCLIBinary()
            print("Lunar CLI installed")
        } catch let error as InstallCLIError {
            print(error.message)
            print(error.info)
            exit(1)
        } catch {
            print("Error installing Lunar CLI")
            print(error.localizedDescription)
            exit(2)
        }
        exit(0)
    }

    func setupValueTransformers() {
        ValueTransformer.setValueTransformer(StringNumberTransformer(), forName: .stringNumberTransformerName)
        ValueTransformer.setValueTransformer(UpdateCheckIntervalTransformer(), forName: .updateCheckIntervalTransformerName)
        ValueTransformer.setValueTransformer(SignedIntTransformer(), forName: .signedIntTransformerName)
        ValueTransformer.setValueTransformer(ColorSchemeTransformer(), forName: .colorSchemeTransformerName)
        ValueTransformer.setValueTransformer(IntBoolTransformer(), forName: .intBoolTransformerName)
    }

    func terminateOtherLunarInstances() {
        if let app = otherLunar(), app.forceTerminate() {
            notify(
                identifier: "lunar-single-instance",
                title: "Lunar was already running",
                body: "The other instance was terminated and this instance will now continue to run normally."
            )
        }
    }

    func checkPermissions() {
        Defaults[.accessibilityPermissionsGranted] = AXIsProcessTrusted()
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            mainAsync {
                let enabled = settings.alertSetting == .enabled
                Defaults[.notificationsPermissionsGranted] = enabled
            }
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        initDDCLogging()
        guard !SWIFTUI_PREVIEW else {
            DC.displays = DC.getDisplaysLock.around {
                DisplayController.getDisplays(
                    includeVirtual: CachedDefaults[.showVirtualDisplays],
                    includeAirplay: CachedDefaults[.showAirplayDisplays],
                    includeProjector: CachedDefaults[.showProjectorDisplays],
                    includeDummy: CachedDefaults[.showDummyDisplays]
                )
            }
            return
        }

        if Defaults[.apiKey].isEmpty {
            Defaults[.apiKey] = SERIAL_NUMBER_HASH
        }

        handleCLIInstall()
        handleCLIUpdate()
        if handleCLI() {
            return
        }
        restartOnCrash()

        initCacheTransitionLogging()
        Defaults[.launchCount] += 1

        startTime = Date()
        lastBlackOutToggleDate = Date()
        Defaults[.secondPhase] = initSecondPhase()
        #if arch(arm64)
            if #available(macOS 13, *) {
                if restarted {
                    DC.possiblyDisconnectedDisplays = Defaults[.possiblyDisconnectedDisplays].dict { ($0.id, $0) }
                } else {
                    log.info("Reconnecting all displays")
                    DC.en()
                }

                Defaults[.possiblyDisconnectedDisplays] = []
            }
        #endif

        listenForRemoteCommandsPublisher
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { change in
                self.server.stopAsync()
                serve(host: change.newValue ? "0.0.0.0" : "127.0.0.1")
            }.store(in: &observers)
        serve(host: CachedDefaults[.listenForRemoteCommands] ? "0.0.0.0" : "127.0.0.1")

        Defaults[.cliInstalled] = fm.isExecutableBinary(atPath: "\(CLI_BIN_DIR)/lunar")
        checkPermissions()
        setupValueTransformers()
        configureSentry()
        terminateOtherLunarInstances()
        DDC.setup()

        try? updater.start()
        updater.automaticallyDownloadsUpdates = Defaults[.silentUpdate]

        handleDaemon()

        initDisplayController()
        initMenubarIcon()

        addGlobalMouseDownMonitor()
        addGlobalModifierMonitor()
        addGlobalKeyMonitor()
        initHotkeys()

        listenForAdaptiveModeChange()
        listenForSettingsChange()
        checkForHighMemoryUsage()
        listenForScreenConfigurationChanged()
        DC.listenForRunningApps()

        addObservers()
        initGamma()
        manageDisplayControllerActivity(mode: DC.adaptiveModeKey)
        if DC.adaptiveMode.available {
            DC.adaptiveMode.watch()
        }

        NetworkControl.setup()
        if datastore.shouldOnboard {
            onboard()
        } else if CachedDefaults[.brightnessKeysEnabled] || CachedDefaults[.volumeKeysEnabled] {
            startOrRestartMediaKeyTap(checkPermissions: true)
        } else if let apps = CachedDefaults[.appExceptions], !apps.isEmpty {
            acquirePrivileges(
                notificationTitle: "Lunar can now watch for app presets",
                notificationBody: "Whenever an app in the presets list is focused or visible on a screen, Lunar will apply its configured brightness."
            )
        }

        startReceivingSignificantLocationChanges()

        #if DEBUG
            fm.createFile(
                atPath: "\(CLI_BIN_DIR)/lunar",
                contents: LUNAR_CLI_SCRIPT.data(using: .utf8),
                attributes: [.posixPermissions: 0o755]
            )
        #else
            mainAsyncAfter(ms: 60 * 1000 * 10) {
                guard AppDelegate.enableSentry else { return }

                let user = User(userId: SERIAL_NUMBER_HASH)
                if CachedDefaults[.paddleConsent] {
                    user.email = producct?.activationEmail
                }
                user.username = producct?.activationID
                SentrySDK.configureScope { scope in
                    scope.setUser(user)
                    scope.setTag(value: DC.adaptiveModeString(), key: "adaptiveMode")
                    scope.setTag(value: DC.adaptiveModeString(last: true), key: "lastAdaptiveMode")
                    scope.setTag(value: CachedDefaults[.overrideAdaptiveMode] ? "false" : "true", key: "autoMode")
                }
                DC.addSentryData()

                guard let release = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String),
                      Defaults[.lastLaunchVersion] != release
                else { return }
                Defaults[.lastLaunchVersion] = release

                SentrySDK.capture(message: "Launch")
            }
        #endif

        mainAsyncAfter(ms: 3000) {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: FLUX_IDENTIFIER).first
            else {
                return
            }
            GammaControl.fluxChecker(flux: app)
        }

        if CachedDefaults[.reapplyValuesAfterWake] {
            screenWakeAdapterTask = Repeater(every: 2, times: CachedDefaults[.wakeReapplyTries], name: "launchAdapter") {
                DC.adaptBrightness(force: true)
                for display in DC.activeDisplays.values.filter({ !$0.blackOutEnabled && $0.reapplyColorGain }) {
                    _ = display.control?.setRedGain(display.redGain.uint16Value)
                    _ = display.control?.setGreenGain(display.greenGain.uint16Value)
                    _ = display.control?.setBlueGain(display.blueGain.uint16Value)
                }
            }
        }

        NotificationCenter.default.post(name: displayListChanged, object: nil)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "6"
        log.info("App finished launching v\(version)")
    }

    @IBAction func toggleCleaningMode(_: Any) {
        if cleaningMode {
            deactivateCleaningMode(withoutSettingFlag: true)
        } else {
            activateCleaningMode(withoutSettingFlag: true)
        }
    }

    @IBAction func forceUpdateDisplayList(_: Any) {
        DC.resetDisplayList()
        appDelegate!.startOrRestartMediaKeyTap()
    }

    @IBAction func openOnboardingProcess(_: Any) {
        onboard()
    }

    @IBAction func openLunarDiagnostics(_: Any) {
        guard !DC.externalDisplaysForTest.isEmpty else {
            notify(identifier: "diagnostics", title: "No monitors to diagnose", body: "")
            return
        }
        useOnboardingForDiagnostics = true
        createAndShowWindow("onboardWindowController", controller: &onboardWindowController)
    }

    @IBAction func restartApp(_: Any) {
        restart()
    }

    func applicationWillTerminate(_: Notification) {
        if isServer {
            DC.cleanup()
        }
    }

    func geolocationFallback() {
        LocationMode.specific.fetchGeolocation()
    }

    func locationManager(_ lm: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !CachedDefaults[.manualLocation] else { return }

        guard lm.auth != .denied, let location = locations.last ?? lm.location,
              let geolocation = Geolocation(location: location)
        else {
            log.debug("Zero LocationManager coordinates")
            if lm.auth != .denied {
                geolocationFallback()
            }
            return
        }

        log.debug("Got LocationManager coordinates")
        LocationMode.specific.geolocation = geolocation
        geolocation.store()
        LocationMode.specific.fetchMoments()
    }

    func locationManager(_ lm: CLLocationManager, didFailWithError error: Error) {
        log.error("Location manager failed with error \(error)")
        guard !CachedDefaults[.manualLocation] else { return }

        guard lm.auth != .denied, let location = lm.location, let geolocation = Geolocation(location: location)
        else {
            log.debug("Zero LocationManager coordinates")
            if lm.auth != .denied {
                geolocationFallback()
            }
            return
        }

        log.debug("Got LocationManager coordinates")
        LocationMode.specific.geolocation = geolocation
        geolocation.store()
        LocationMode.specific.fetchMoments()
    }

    func locationManager(_ lm: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined, .authorizedAlways:
            lm.startUpdatingLocation()
        case .restricted:
            log.warning("User has not authorised location services")
            lm.stopUpdatingLocation()
            geolocationFallback()
        case .denied:
            log.warning("User has denied location services")
            lm.stopUpdatingLocation()
        @unknown default:
            log.error("Unknown location manager status \(status)")
        }
    }

    func startReceivingSignificantLocationChanges() {
        if CachedDefaults[.manualLocation] {
            LocationMode.specific.geolocation = CachedDefaults[.location]
        }

        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager!.delegate = self
            locationManager!.desiredAccuracy = kCLLocationAccuracyReduced
        }

        let locationManager: CLLocationManager? = withTimeout(5.seconds, name: "locationManager") {
            guard let loc = self.locationManager, loc.authorizationStatus != .denied else {
                log.warning("Location authStatus denied")
                self.locationManager?.stopUpdatingLocation()
                throw "Location authStatus denied".err
            }
            return loc
        }

        guard let locationManager else {
            return
        }

        locationManager.stopUpdatingLocation()
        if !CachedDefaults[.manualLocation] {
            locationManager.startUpdatingLocation()
        }

        switch locationManager.auth {
        case .authorizedAlways:
            log.debug("Location authStatus authorizedAlways")
        case .denied:
            log.debug("Location authStatus denied")
        case .notDetermined:
            log.debug("Location authStatus notDetermined")
        case .restricted:
            log.debug("Location authStatus restricted")
        case .authorized:
            log.debug("Location authStatus authorized")
        @unknown default:
            log.debug("Location authStatus unknown??")
        }
    }

    func resetElements() {
        mainAsync { [self] in
            if let splitView = windowController?.window?.contentViewController as? SplitViewController {
                splitView.activeModeButton?.needsDisplay = true
            }
        }
    }

    func adapt() {
        DC.adaptBrightness()
    }

    func setLightPercent(percent: Int8) {
        guard checkRemainingAdjustments() else { return }

        DC.disable()
        DC.setBrightnessPercent(value: percent)
        DC.setContrastPercent(value: percent)
        log.debug("Setting brightness and contrast to \(percent)%")
    }

    func toggleAudioMuted(for displays: [Display]? = nil, currentDisplay: Bool = false, currentAudioDisplay: Bool = true) {
        DC.toggleAudioMuted(for: displays, currentDisplay: currentDisplay, currentAudioDisplay: currentAudioDisplay)
    }

    func increaseVolume(
        by amount: Int? = nil,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        currentAudioDisplay: Bool = true
    ) {
        let amount = amount ?? CachedDefaults[.volumeStep]
        mainAsync {
            DC.adjustVolume(
                by: amount,
                for: displays,
                currentDisplay: currentDisplay,
                currentAudioDisplay: currentAudioDisplay
            )
        }
    }

    func decreaseVolume(
        by amount: Int? = nil,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        currentAudioDisplay: Bool = true
    ) {
        let amount = amount ?? CachedDefaults[.volumeStep]
        mainAsync {
            DC.adjustVolume(
                by: -amount,
                for: displays,
                currentDisplay: currentDisplay,
                currentAudioDisplay: currentAudioDisplay
            )
        }
    }

    func increaseBrightness(
        by amount: Int? = nil,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        builtinDisplay: Bool = false,
        sourceDisplay: Bool = false,
        mainDisplay: Bool = false,
        nonMainDisplays: Bool = false
    ) {
        let amount = amount ?? CachedDefaults[.brightnessStep]
        DC.adjustBrightness(
            by: amount,
            for: displays,
            currentDisplay: currentDisplay,
            builtinDisplay: builtinDisplay,
            sourceDisplay: sourceDisplay,
            mainDisplay: mainDisplay,
            nonMainDisplays: nonMainDisplays
        )
    }

    func increaseContrast(
        by amount: Int? = nil,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        sourceDisplay: Bool = false,
        mainDisplay: Bool = false,
        nonMainDisplays: Bool = false
    ) {
        let amount = amount ?? CachedDefaults[.contrastStep]
        DC.adjustContrast(
            by: amount,
            for: displays,
            currentDisplay: currentDisplay,
            sourceDisplay: sourceDisplay,
            mainDisplay: mainDisplay,
            nonMainDisplays: nonMainDisplays
        )
    }

    func decreaseBrightness(
        by amount: Int? = nil,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        builtinDisplay: Bool = false,
        sourceDisplay: Bool = false,
        mainDisplay: Bool = false,
        nonMainDisplays: Bool = false
    ) {
        let amount = amount ?? CachedDefaults[.brightnessStep]
        DC.adjustBrightness(
            by: -amount,
            for: displays,
            currentDisplay: currentDisplay,
            builtinDisplay: builtinDisplay,
            sourceDisplay: sourceDisplay,
            mainDisplay: mainDisplay,
            nonMainDisplays: nonMainDisplays
        )
    }

    func decreaseContrast(
        by amount: Int? = nil,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        sourceDisplay: Bool = false,
        mainDisplay: Bool = false,
        nonMainDisplays: Bool = false
    ) {
        let amount = amount ?? CachedDefaults[.contrastStep]
        DC.adjustContrast(
            by: -amount,
            for: displays,
            currentDisplay: currentDisplay,
            sourceDisplay: sourceDisplay,
            mainDisplay: mainDisplay,
            nonMainDisplays: nonMainDisplays
        )
    }

    @IBAction func setLight0Percent(sender _: Any?) {
        setLightPercent(percent: 0)
    }

    @IBAction func setLight25Percent(sender _: Any?) {
        setLightPercent(percent: 25)
    }

    @IBAction func setLight50Percent(sender _: Any?) {
        setLightPercent(percent: 50)
    }

    @IBAction func setLight75Percent(sender _: Any?) {
        setLightPercent(percent: 75)
    }

    @IBAction func setLight100Percent(sender _: Any?) {
        setLightPercent(percent: 100)
    }

    @IBAction func brightnessUp(_: Any) {
        brightnessUpHotkeyHandler()
    }

    @IBAction func brightnessDown(_: Any) {
        brightnessDownHotkeyHandler()
    }

    @IBAction func contrastUp(_: Any) {
        contrastUpHotkeyHandler()
    }

    @IBAction func contrastDown(_: Any) {
        contrastDownHotkeyHandler()
    }

    @IBAction func volumeUp(_: Any) {
        volumeUpHotkeyHandler()
    }

    @IBAction func volumeDown(_: Any) {
        volumeDownHotkeyHandler()
    }

    @IBAction func muteAudio(_: Any) {
        muteAudioHotkeyHandler()
    }

    @IBAction func showPreferencesWindow(sender _: Any?) {
        showWindow()
    }

    @IBAction func joinCommunity(_: Any) {
        if let url = URL(string: "https://discord.gg/dJPHpWgAhV") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func leaveFeedback(_: Any) {
        NSWorkspace.shared.open(contactURL())
    }

    @IBAction func faq(_: Any) {
        if let url = URL(string: "https://lunar.fyi/faq") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func badDDC(_: Any) {
        if let url = URL(string: "https://lunar.fyi/faq#bad-ddc") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func brightnessNotChanging(_: Any) {
        if let url = URL(string: "https://lunar.fyi/faq#brightness-not-changing") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func changelog(_: Any) {
        if let url = URL(string: "https://lunar.fyi/changelog") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func releases(_: Any) {
        if let url = URL(string: "https://releases.lunar.fyi") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func privacy(_: Any) {
        if let url = URL(string: "https://lunar.fyi/privacy") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func monitorDB(_: Any) {
        if let url = URL(string: "https://db.lunar.fyi") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func badKeys(_: Any) {
        if let url = URL(string: "https://lunar.fyi/faq#media-keys-not-working") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func startALSFirmwareInstall(_: Any) {
        createAndShowWindow("alsWindowController", controller: &alsWindowController)
    }

    @IBAction func startDDCServerInstall(_: Any) {
        createAndShowWindow("sshWindowController", controller: &sshWindowController)
    }

    func installCLIAndShowDialog() {
        do {
            try installCLIBinary()
            dialog(message: "Lunar CLI installed at \(CLI_BIN_DIR)", info: "", cancelButton: nil).runModal()
        } catch let error as InstallCLIError {
            dialog(message: error.message, info: error.info, cancelButton: nil).runModal()
        } catch {
            dialog(message: "Error installing Lunar CLI", info: "\(error)", cancelButton: nil).runModal()
        }
    }

    @IBAction func installCLI(_: Any) {
        let shouldInstall: Bool = askBool(
            message: "Lunar CLI",
            info: "This will install the `lunar` script into `\(CLI_BIN_DIR)`.\n\nDo you want to proceed?",
            okButton: "Yes",
            cancelButton: "No",
            unique: true,
            markdown: true
        )
        if shouldInstall {
            installCLIAndShowDialog()
        }
    }

    @objc private func activate() {
        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
    }
}

// MARK: - InstallCLIError

struct InstallCLIError: Error {
    let message: String
    let info: String
}

let CLI_BIN_DIR = (Path.home / ".local" / "bin").string
let CLI_BIN_DIR_ENV = "$HOME/.local/bin"
let ZSHRC = (Path.home / ".zshrc").string
let BASHRC = (Path.home / ".bashrc").string
let FISHRC = (Path.home / ".config" / "fish" / "config.fish").string
let PATH_EXPORT = """

export PATH="$PATH:\(CLI_BIN_DIR_ENV)"

"""

func installCLIBinary() throws {
    if !fm.fileExists(atPath: CLI_BIN_DIR) {
        do {
            try fm.createDirectory(atPath: CLI_BIN_DIR, withIntermediateDirectories: true)
        } catch {
            log.error("Error on creating \(CLI_BIN_DIR): \(error)")
            throw InstallCLIError(
                message: "Missing \(CLI_BIN_DIR)",
                info: "Error on creating the '\(CLI_BIN_DIR)' directory: \(error)"
            )
        }
    }

    fm.createFile(
        atPath: "\(CLI_BIN_DIR)/lunar",
        contents: LUNAR_CLI_SCRIPT.data(using: .utf8),
        attributes: [.posixPermissions: 0o755]
    )

    guard fm.isExecutableBinary(atPath: "\(CLI_BIN_DIR)/lunar") else {
        throw InstallCLIError(
            message: "File permissions error",
            info: """
            You can fix permissions by running the following commands in a terminal:

            sudo chown -R $(whoami) '\(CLI_BIN_DIR)'
            sudo chmod 755 '\(CLI_BIN_DIR)'
            """
        )
    }

    for config in [BASHRC, ZSHRC, FISHRC] {
        let contents = fm.contents(atPath: config)?.s ?? ""
        guard !contents.contains(CLI_BIN_DIR_ENV), !contents.contains(CLI_BIN_DIR) else {
            continue
        }

        fm.createFile(
            atPath: config,
            contents: (contents + PATH_EXPORT).data(using: .utf8),
            attributes: [.posixPermissions: 0o644]
        )
    }

    Defaults[.cliInstalled] = true
}

func acquirePrivileges(notificationTitle: String = "Lunar is now listening for media keys", notificationBody: String? = nil) {
//    #if DEBUG
//        if CommandLine.arguments.contains("-NSDocumentRevisionsDebugMode") {
//            return
//        }
//    #endif

    let onAcquire = {
        mainAsync { Defaults[.accessibilityPermissionsGranted] = true }
        appDelegate!.startOrRestartMediaKeyTap()
        guard !CachedDefaults[.mediaKeysNotified] else { return }
        CachedDefaults[.mediaKeysNotified] = true

        var body = notificationBody ??
            "You can now use PLACEHOLDER keys to control your monitors. Swipe right in the Lunar window to get to the Hotkeys page and manage this functionality."

        if CachedDefaults[.brightnessKeysEnabled], CachedDefaults[.volumeKeysEnabled] {
            body = body.replacingOccurrences(of: "PLACEHOLDER", with: "brightness and volume")
        } else if CachedDefaults[.brightnessKeysEnabled] {
            body = body.replacingOccurrences(of: "PLACEHOLDER", with: "brightness")
        } else {
            body = body.replacingOccurrences(of: "PLACEHOLDER", with: "volume")
        }
        notify(identifier: "mediaKeysListener", title: notificationTitle, body: body)
    }

    let options = [
        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true as CFBoolean,
    ]
    let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
    mainAsync { Defaults[.accessibilityPermissionsGranted] = accessEnabled }

    if accessEnabled {
        onAcquire()
        return
    }
    CachedDefaults[.mediaKeysNotified] = false

    axPermissionsChecker = Repeater(every: 2, name: "AXPermissionsChecker") {
        guard AXIsProcessTrusted() else { return }
        onAcquire()
        axPermissionsChecker?.stop()
        axPermissionsChecker = nil
    }
}

var axPermissionsChecker: Repeater?
let restarted = CommandLine.arguments[safe: 1]?.starts(with: "restarts=") ?? false
var restarting = false

func isLidClosed() -> Bool {
    guard !Sysctl.isiMac else { return false }
    guard Sysctl.isMacBook else { return true }
    return IsLidClosed()
}

func resetAllSettings() {
    UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
}

func restart() {
    restarting = true
    // check if the app was started fresh or if was restarted with arg `restarts=timestamp:timestamp:timestamp`
    // if it was restarted more than 3 times in 1 minute, exit

    guard CommandLine.arguments.count == 1 || (
        CommandLine.arguments.count == 2 && CommandLine.arguments[1].starts(with: "restarts=")
    ) else {
        exit(1)
    }

    var restartArg = "restarts=\(Date().timeIntervalSince1970)"
    if CommandLine.arguments.count == 2 {
        let restarts = CommandLine.arguments[1].split(separator: "=")[1].split(separator: ":").map { TimeInterval($0)! }
        let now = Date().timeIntervalSince1970
        if restarts.filter({ now - $0 < 60 }).count > 3 {
            exit(1)
        } else {
            restartArg = "\(CommandLine.arguments[1]):\(now)"
        }
    }

    do {
        _ = shell(
            command: "while /bin/ps -o pid -p \(ProcessInfo.processInfo.processIdentifier) >/dev/null 2>/dev/null; do /bin/sleep 0.1; done; /bin/sleep 0.5; /usr/bin/open '\(Bundle.main.path.string)' --args '\(restartArg)'",
            wait: false
        )
        // try exec(arg0: Bundle.main.executablePath!, args: args)
    } catch {
        err("Failed to restart: \(error)")
    }
    exit(0)
}

public func restartOnCrash() {
    if Defaults[.autoRestartOnCrash] {
        NSSetUncaughtExceptionHandler { _ in restart() }
        signal(SIGABRT) { _ in restart() }
        signal(SIGILL) { _ in restart() }
        signal(SIGSEGV) { _ in restart() }
        signal(SIGFPE) { _ in restart() }
        signal(SIGBUS) { _ in restart() }
        signal(SIGPIPE) { _ in restart() }
        signal(SIGTRAP) { _ in restart() }
    }
    signal(SIGHUP) { _ in restart() }
    signal(SIGINT) { _ in NSApp.terminate(nil) }
}

extension CGEventFlags {
    var nsModifierFlags: NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if contains(.maskAlphaShift) {
            flags.insert(.capsLock)
        }
        if contains(.maskShift) {
            flags.insert(.shift)
        }
        if contains(.maskControl) {
            flags.insert(.control)
        }
        if contains(.maskAlternate) {
            flags.insert(.option)
        }
        if contains(.maskCommand) {
            flags.insert(.command)
        }
        if contains(.maskSecondaryFn) {
            flags.insert(.function)
        }
        return flags
    }
}
