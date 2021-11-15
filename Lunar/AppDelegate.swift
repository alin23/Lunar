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
import FuzzyFind
import LetsMove
import Magnet
import MediaKeyTap
import Regex
import Sauce
import Sentry
import SimplyCoreAudio
import Sparkle
import SwiftDate
import SwiftyMarkdown
import UserNotifications
import WAYWindow

import Path

let fm = FileManager()
let simplyCA = SimplyCoreAudio()
var screensSleeping = ManagedAtomic<Bool>(false)
var brightnessTransition = BrightnessTransition.instant
let SCREEN_WAKE_ADAPTER_TASK_KEY = "screenWakeAdapter"
let CONTACT_URL = "https://lunar.fyi/contact".asURL()!

private let kAppleInterfaceThemeChangedNotification = "AppleInterfaceThemeChangedNotification"
private let kAppleInterfaceStyle = "AppleInterfaceStyle"
private let kAppleInterfaceStyleSwitchesAutomatically = "AppleInterfaceStyleSwitchesAutomatically"

let dataPublisherQueue = DispatchQueue(label: "fyi.lunar.data.queue", qos: .utility)
let mediaKeyStarterQueue = RunloopQueue(named: "fyi.lunar.mediaKeyStarter.queue")
let debounceQueue = RunloopQueue(named: "fyi.lunar.debounce.queue")
let mainQueue = RunloopQueue(named: "fyi.lunar.main.queue")
// let operationHighlightQueue = RunloopQueue(named: "fyi.lunar.operationHighlight.queue")
let serviceBrowserQueue = RunloopQueue(named: "fyi.lunar.serviceBrowser.queue")
let realtimeQueue = RunloopQueue(named: "fyi.lunar.realtime.queue")
let lowprioQueue = RunloopQueue(named: "fyi.lunar.lowprio.queue")
let sensorHostnameQueue = RunloopQueue(named: "fyi.lunar.sensor.hostname.queue")
let windowControllerQueue = DispatchQueue(label: "fyi.lunar.windowControllerQueue.queue", qos: .userInitiated)
let concurrentQueue = DispatchQueue(label: "fyi.lunar.concurrent.queue", qos: .userInitiated, attributes: .concurrent)
let smoothDDCQueue = DispatchQueue(label: "fyi.lunar.smooth.ddc.queue", qos: .userInitiated, attributes: .concurrent)
let smoothDisplayServicesQueue = DispatchQueue(
    label: "fyi.lunar.smooth.displayservices.queue",
    qos: .userInitiated,
    attributes: .concurrent
)
let timerQueue = RunloopQueue(named: "fyi.lunar.timer.queue")
let taskManagerQueue = RunloopQueue(named: "fyi.lunar.taskManager.queue")
let serialQueue = DispatchQueue(label: "fyi.lunar.serial.queue", qos: .userInitiated)
let serialSyncQueue = DispatchQueue(label: "fyi.lunar.serialSync.queue", qos: .userInitiated)
let mainSerialQueue = DispatchQueue(label: "fyi.lunar.mainSerial.queue", qos: .userInitiated, target: .main)
let dataSerialQueue = DispatchQueue(label: "fyi.lunar.dataSerial.queue", qos: .utility, target: DispatchQueue.global(qos: .utility))
let appName = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Lunar"

let TEST_MODE = AppSettings.testMode
let LOG_URL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(appName, isDirectory: true)
    .appendingPathComponent("swiftybeaver.log", isDirectory: false)

var activeDisplay: Display?

var thisIsFirstRun = false
var thisIsFirstRunAfterLunar4Upgrade = false
var thisIsFirstRunAfterDefaults5Upgrade = false
var thisIsFirstRunAfterM1DDCUpgrade = false
var thisIsFirstRunAfterBuiltinUpgrade = false
var thisIsFirstRunAfterHotkeysUpgrade = false

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

// MARK: - NonClosingMenuText

class NonClosingMenuText: NSTextField {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        log.info("mouseDown: \(event.locationInWindow)")
        onClick?()
    }
}

// MARK: - MemoryUsageError

enum MemoryUsageError: Error {
    case highMemoryUsage(Int)
}

// MARK: - AppDelegate

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate, NSMenuDelegate {
    // MARK: Internal

    enum UIElement {
        case displayControls
        case displayDDC
        case displayGamma
        case displayReset
        case advancedSettingsButton
    }

    var locationManager: CLLocationManager?
    var _windowControllerLock = NSRecursiveLock()
    var _windowController: ModernWindowController?
    var alsWindowController: ModernWindowController?
    var sshWindowController: ModernWindowController?
    var diagnosticsWindowController: ModernWindowController?
    var onboardWindowController: ModernWindowController?

    var observers: Set<AnyCancellable> = []

    var valuesReaderThread: CFRunLoopTimer?

    var statusButtonTrackingArea: NSTrackingArea?
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
    @IBOutlet var faceLightExplanationMenuItem: NSMenuItem!
    @IBOutlet var blackOutExplanationMenuItem: NSMenuItem!
    @IBOutlet var infoMenuItem: NSMenuItem!

    @Atomic var faceLightOn = false

    lazy var updater = SPUUpdater(
        hostBundle: Bundle.main,
        applicationBundle: Bundle.main,
        userDriver: SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil),
        delegate: self
    )

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    var uiElement: UIElement?

    var didBecomeActiveAtLeastOnce = false
    var screenIDs: Set<CGDirectDisplayID> = Set(NSScreen.onlineDisplayIDs)

    var brightnessIcon = "brightness"

    lazy var markdown: SwiftyMarkdown = getMarkdownRenderer()

    @IBOutlet var infoMenuToggle: NSMenuItem!

    var menuUpdater: Timer?

    var memoryUsageChecker: Foundation.Thread?

    lazy var needsAccessibilityPermissions = CachedDefaults[.brightnessKeysEnabled] || CachedDefaults[.volumeKeysEnabled] ||
        !(CachedDefaults[.appExceptions]?.isEmpty ?? true)

    var currentPage: Int = Page.display.rawValue {
        didSet {
            log.verbose("Current Page: \(currentPage)")
        }
    }

    var windowController: ModernWindowController? {
        get { _windowControllerLock.around { _windowController } }
        set { _windowControllerLock.around { _windowController = newValue } }
    }

    var externalLux: String {
        guard SensorMode.wirelessSensorURL != nil else { return "" }
        return "External light sensor: **\(SensorMode.specific.lastAmbientLight.str(decimals: 2)) lux**\n"
    }

    var internalLux: String {
        guard let lux = SensorMode.getInternalSensorLux() else { return "" }
        return "Internal light sensor: **\(lux) lux**\n"
    }

    var sun: String {
        guard let moment = LocationMode.specific.moment, let sun = LocationMode.specific.geolocation?.sun() else { return "" }
        let sunrise = moment.sunrise.toString(.time(.short))
        let sunset = moment.sunset.toString(.time(.short))
        let noon = moment.solarNoon.toString(.time(.short))
        let elevation = sun.elevation.str(decimals: 1)

        return "Sun: (**sunrise \(sunrise)**) (**sunset \(sunset)**)\n       (noon \(noon)) [elevation \(elevation)°]\n"
    }

    var memory500MBPassed = false {
        didSet {
            guard memory500MBPassed, !oldValue, let mb = memoryFootprintMB() else { return }

            SentrySDK.configureScope { scope in
                scope.setTag(value: "500MB", key: "memory")
                scope.setExtra(value: mb, key: "usedMB")
                SentrySDK.capture(error: MemoryUsageError.highMemoryUsage(mb.intround))
            }
        }
    }

    var memory1GBPassed = false {
        didSet {
            guard memory1GBPassed, !oldValue, let mb = memoryFootprintMB() else { return }
            SentrySDK.configureScope { scope in
                scope.setTag(value: "1GB", key: "memory")
                scope.setExtra(value: mb, key: "usedMB")
                SentrySDK.capture(error: MemoryUsageError.highMemoryUsage(mb.intround))
                self.restartApp(self)
            }
        }
    }

    var memory2GBPassed = false {
        didSet {
            guard memory2GBPassed, !oldValue, let mb = memoryFootprintMB() else { return }
            SentrySDK.configureScope { scope in
                scope.setTag(value: "2GB", key: "memory")
                scope.setExtra(value: mb, key: "usedMB")
                SentrySDK.capture(error: MemoryUsageError.highMemoryUsage(mb.intround))
                self.restartApp(self)
            }
        }
    }

    var memory4GBPassed = false {
        didSet {
            guard memory4GBPassed, !oldValue, let mb = memoryFootprintMB() else { return }
            SentrySDK.configureScope { scope in
                scope.setTag(value: "4GB", key: "memory")
                scope.setExtra(value: mb, key: "usedMB")
                SentrySDK.capture(error: MemoryUsageError.highMemoryUsage(mb.intround))
                self.restartApp(self)
            }
        }
    }

    var memory8GBPassed = false {
        didSet {
            guard memory8GBPassed, !oldValue, let mb = memoryFootprintMB() else { return }
            SentrySDK.configureScope { scope in
                scope.setTag(value: "8GB", key: "memory")
                scope.setExtra(value: mb, key: "usedMB")
                SentrySDK.capture(error: MemoryUsageError.highMemoryUsage(mb.intround))
                self.restartApp(self)
            }
        }
    }

    func menuWillOpen(_: NSMenu) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4"

        initLicensingMenuItems(version)
        initMenuItems()
        menuUpdater = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] _ in
            updateInfoMenuItem()
        }
        RunLoop.main.add(menuUpdater!, forMode: .common)
    }

    func menuDidClose(_: NSMenu) {
        menuUpdater?.invalidate()
    }

    @IBAction func checkForUpdates(_: Any) {
        updater.checkForUpdates()
    }

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let scheme = url.scheme, let host = url.host, scheme == "lunar" else { continue }

            mainAsync {
                CachedDefaults[.advancedSettingsShown] = host == "advanced"
            }

            switch host {
            case "checkout":
                if windowController != nil {
                    showCheckout()
                } else {
                    mainAsyncAfter(ms: 2000) { showCheckout() }
                }
            case "advanced":
                currentPage = Page.settings.rawValue
                uiElement = .advancedSettingsButton
                showWindow(after: windowController == nil ? 2000 : nil)
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
                    if let number = firstPath.i, number > 0, number <= displayController.activeDisplays.count {
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
                            let alignments = fuzzyFind(queries: [firstPath], inputs: displayController.displays.values.map(\.name))
                            if let name = alignments.first?.result.asString {
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
        for hotkey in hotkeys {
            hotkey.handleRegistration(persist: false)
        }
        CachedDefaults[.hotkeys] = hotkeys

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
        CachedDefaults[.clockMode] = mode == .clock
        CachedDefaults[.syncMode] = mode == .sync

        adaptiveBrightnessModePublisher.sink { change in
            SentrySDK.configureScope { scope in
                scope.setTag(value: change.newValue.str, key: "adaptiveMode")
                scope.setTag(value: change.oldValue.str, key: "lastAdaptiveMode")
                scope.setTag(value: CachedDefaults[.overrideAdaptiveMode] ? "false" : "true", key: "autoMode")
            }

            let modeKey = change.newValue
            mainAsync {
                CachedDefaults[.nonManualMode] = modeKey != .manual
                CachedDefaults[.clockMode] = modeKey == .clock
                CachedDefaults[.syncMode] = modeKey == .sync
                displayController.adaptiveMode = modeKey.mode
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
            displayController.resetDisplayList(configurationPage: true)
        }.store(in: &observers)
        showVirtualDisplaysPublisher.sink { _ in
            displayController.resetDisplayList(configurationPage: true)
        }.store(in: &observers)
        showAirplayDisplaysPublisher.sink { _ in
            displayController.resetDisplayList(configurationPage: true)
        }.store(in: &observers)
        showProjectorDisplaysPublisher.sink { _ in
            displayController.resetDisplayList(configurationPage: true)
        }.store(in: &observers)
        showDisconnectedDisplaysPublisher.sink { _ in
            displayController.resetDisplayList(configurationPage: true)
        }.store(in: &observers)
        detectResponsivenessPublisher.sink { change in
            let shouldDetect = change.newValue
            if !shouldDetect {
                displayController.activeDisplays.values.forEach { $0.responsiveDDC = true }
            }
        }.store(in: &observers)
        // NotificationCenter.default
        //     .publisher(for: UserDefaults.didChangeNotification, object: UserDefaults.standard)
        //     .sink { _ in displayController.addSentryData() }
        //     .store(in: &observers)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let mode = AdaptiveModeKey(rawValue: menuItem.tag) else {
            return false
        }
        return mode.available
    }

    func showWindow(after ms: Int? = nil, position: NSPoint? = nil, focus: Bool = true) {
        guard let ms = ms else {
            createAndShowWindow(
                "windowController",
                controller: &windowController,
                focus: focus,
                screen: NSScreen.withMouse,
                position: position
            )
            return
        }
        mainAsyncAfter(ms: ms) { [self] in
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
            guard let appPath = p(Bundle.main.bundlePath),
                  appPath.parent == p("/Applications")
            else { return }
            LaunchAtLoginController().setLaunchAtLogin(shouldStartAtLogin, for: appPath.url)
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
        guard let w = notification.object as? ModernWindow, w.isVisible, w.title == "Settings" else { return }

        switch CLLocationManager.authorizationStatus() {
        case .notDetermined, .restricted, .denied:
            log.debug("Requesting location permissions")
            locationManager?.requestAlwaysAuthorization()
        case .authorizedAlways:
            log.debug("Location authorized")
        @unknown default:
            log.debug("Location status unknown")
        }
        goToPage(ignoreUIElement: true)
        mainAsyncAfter(ms: 500) { [self] in
            goToPage()
        }
    }

    func activateUIElement(_ uiElement: UIElement, page: Int, highlight: Bool = true) {
        guard let w = windowController?.window, let view = w.contentView, !view.subviews.isEmpty, !view.subviews[0].subviews.isEmpty,
              let pageController = view.subviews[0].subviews[0].nextResponder as? PageController else { return }

        switch uiElement {
        case .advancedSettingsButton:
            guard let settingsPageController = pageController
                .viewControllers[pageController.settingsPageControllerIdentifier] as? SettingsPageController,
                let button = settingsPageController.advancedSettingsButton else { return }
            if highlight { button.highlight() }
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
                splitViewController.mauveBackground()
            case 1:
                splitViewController.yellowBackground()
            case pageController.arrangedObjects.count - 1:
                splitViewController.lastPage()
            default:
                splitViewController.whiteBackground()
            }
        }

        if !ignoreUIElement, let uiElement = uiElement {
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

    func updateInfoMenuItem() {
        if CachedDefaults[.showBrightnessMenuBar],
           let display = CachedDefaults[.showOnlyExternalBrightnessMenuBar] ?
           displayController.mainExternalDisplay :
           displayController.cursorDisplay
        {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineHeightMultiple = 0.6
            statusItem.button?.attributedTitle = " B: \(display.brightness.uint8Value)\n C: \(display.contrast.uint8Value)"
                .withFont(.systemFont(ofSize: 10, weight: .medium)).withBaselineOffset(-5).withParagraphStyle(paragraphStyle)
        }
        infoMenuItem.attributedTitle = markdown.attributedString(from: "\(externalLux)\(internalLux)\(sun)".trimmed)
            .withFont(.systemFont(ofSize: 12, weight: .semibold))
        infoMenuItem.isEnabled = false
    }

    func manageDisplayControllerActivity(mode: AdaptiveModeKey) {
        log.debug("Started DisplayController in \(mode.str) mode")
        displayController.adaptBrightness()
    }

    func startValuesReaderThread() {
        valuesReaderThread = asyncEvery(10.seconds, queue: lowprioQueue) { _ in
            guard !screensSleeping.load(ordering: .relaxed) else { return }

            if CachedDefaults[.refreshValues] {
                displayController.fetchValues()
            }
        }
    }

    func initDisplayControllerActivity() {
        if CachedDefaults[.refreshValues] {
            startValuesReaderThread()
        }

        manageDisplayControllerActivity(mode: displayController.adaptiveModeKey)
        if displayController.adaptiveMode.available {
            displayController.adaptiveMode.watch()
        }
    }

    @discardableResult func initMenuPopover() -> NSPopover {
        guard let storyboard = NSStoryboard.main else { return NSPopover() }

        menuPopover = NSPopover()
        guard let menuPopover = menuPopover else { return NSPopover() }
        menuPopover.contentViewController = storyboard
            .instantiateController(
                withIdentifier: NSStoryboard
                    .SceneIdentifier("QuickActionsViewController")
            ) as! QuickActionsViewController
        menuPopover.contentViewController?.loadView()
        if let w = menuPopover.contentViewController?.view.window {
            w.setAccessibilityRole(.popover)
            w.setAccessibilitySubrole(.unknown)
        }

        menuPopover.animates = false
        // menuPopover.behavior = .transient

        return menuPopover
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
        setInfoMenuToggleTitle()
        updateInfoMenuItem()
    }

    func initMenubarIcon() {
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("MenubarIcon"))
            button.image?.isTemplate = true
            button.imagePosition = CachedDefaults[.showBrightnessMenuBar] ? .imageLeading : .imageOnly

            statusItemButtonController = StatusItemButtonController(button: button)
            statusButtonTrackingArea = NSTrackingArea(
                rect: button.visibleRect,
                options: [.mouseEnteredAndExited, .activeAlways],
                owner: statusItemButtonController,
                userInfo: nil
            )
            if let trackingArea = statusButtonTrackingArea {
                button.addTrackingArea(trackingArea)
            }
            button.addSubview(statusItemButtonController!)
        }
        statusItem.menu = nil
        initMenuItems()

        initMenuPopover()
        DistributedNotificationCenter.default()
            .publisher(for: NSNotification.Name(rawValue: kAppleInterfaceThemeChangedNotification), object: nil)
            .sink { [self] _ in
                mainAsync {
                    initMenuItems()
                    for (key, popover) in POPOVERS {
                        guard let popover = popover else { continue }
                        popover.close()
                        POPOVERS[key] = nil
                    }
                    recreateWindow()
                }
            }
            .store(in: &observers)
        colorSchemePublisher
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [self] _ in
                CachedDefaults[.advancedSettingsShown] = true
                recreateWindow(page: Page.settings.rawValue, advancedSettings: true)
            }.store(in: &observers)
    }

    func listenForScreenConfigurationChanged() {
        asyncEvery(3.seconds, uniqueTaskKey: "zeroGammaChecker") { _ in
            displayController.activeDisplays.values
                .filter { d in
                    !d.isForTesting && !d.settingGamma && d.control is GammaControl && !d.blackOutEnabled && GammaTable(for: d.id).isZero
                }
                .forEach { d in
                    log.warning("Gamma tables are zeroed out for display \(d)!\nReverting to last non-zero gamma tables")
                    if let table = d.lastGammaTable {
                        d.apply(gamma: table)
                    }
                }
        }

        CGDisplayRegisterReconfigurationCallback({ displayID, _, _ in
            debounce(ms: 2000, uniqueTaskKey: "panel-refresh-\(displayID)", mainThread: true, value: displayID) { id in
                DisplayController.panelManager = MPDisplayMgr()
                if let display = displayController.activeDisplays[id] {
                    display.refreshPanel()
                }
            }
        }, nil)

        DistributedNotificationCenter
            .default()
            .publisher(
                for: NSNotification.Name(rawValue: kColorSyncDisplayDeviceProfilesNotification.takeRetainedValue() as String),
                object: nil
            )
            .sink { n in
                guard let displayUUID = n.userInfo?["DeviceID"] as? String,
                      let display = displayController.activeDisplays.values.first(where: { $0.serial == displayUUID }) else { return }
                log.debug("ColorSync changed for \(display)")
                display.refreshGamma()
                display.reapplyGamma()

            }.store(in: &observers)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
            .eraseToAnyPublisher().map { $0 as Any? }
            .merge(with: NSWorkspace.shared.publisher(for: \.frontmostApplication).map { $0 as Any? }.eraseToAnyPublisher())
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [self] _ in
                displayController.adaptBrightness(force: true)
                updateInfoMenuItem()
            }
            .store(in: &observers)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification, object: nil)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { _ in
                log.debug("Screen configuration changed")
                displayController.activeDisplays.values.forEach { d in
                    d.updateCornerWindow()
                }

                let newScreenIDs = Set(NSScreen.onlineDisplayIDs)
                let newLidClosed = IsLidClosed()
                guard newScreenIDs != self.screenIDs || newLidClosed != displayController.lidClosed else { return }

                if newScreenIDs != self.screenIDs {
                    log.info(
                        "New screen IDs after screen configuration change",
                        context: ["old": self.screenIDs.commaSeparatedString, "new": newScreenIDs.commaSeparatedString]
                    )
                    self.screenIDs = newScreenIDs
                }
                if newLidClosed != displayController.lidClosed {
                    log.info(
                        "Lid state changed",
                        context: [
                            "old": displayController.lidClosed ? "closed" : "opened",
                            "new": newLidClosed ? "closed" : "opened",
                        ]
                    )
                    displayController.lidClosed = newLidClosed
                }

                menuPopover?.close()

                displayController.manageClamshellMode()
                displayController.resetDisplayList()

                displayController.adaptBrightness(force: true)

                debounce(ms: 3000, uniqueTaskKey: "resetStates") {
                    self.disableFaceLight(smooth: false)
                    NetworkControl.resetState()
                    DDCControl.resetState()
                    appDelegate!.startOrRestartMediaKeyTap()
                    displayController.activeDisplays.values.forEach { d in
                        d.updateCornerWindow()
                    }
                }
            }.store(in: &observers)

        let wakePublisher = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.screensDidWakeNotification, object: nil)
        let sleepPublisher = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.screensDidSleepNotification, object: nil)

        wakePublisher.merge(with: sleepPublisher)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { notif in
                switch notif.name {
                case NSWorkspace.screensDidWakeNotification:
                    log.debug("Screens woke up")
                    screensSleeping.store(false, ordering: .sequentiallyConsistent)

                    if CachedDefaults[.refreshValues] {
                        self.startValuesReaderThread()
                    }
                    SyncMode.refresh()
                    if displayController.adaptiveMode.available {
                        displayController.adaptiveMode.watch()
                    }

                    debounce(ms: 3000, uniqueTaskKey: "resetStates") {
                        self.disableFaceLight(smooth: false)
                        NetworkControl.resetState()
                        DDCControl.resetState()
                        appDelegate!.startOrRestartMediaKeyTap()
                    }

                    if CachedDefaults[.reapplyValuesAfterWake] {
                        asyncEvery(
                            2.seconds,
                            uniqueTaskKey: SCREEN_WAKE_ADAPTER_TASK_KEY,
                            runs: CachedDefaults[.wakeReapplyTries],
                            skipIfExists: true
                        ) { _ in
                            if displayController.adaptiveModeKey == .manual, CachedDefaults[.jitterAfterWake] {
                                for (num, display) in displayController.activeDisplayList.enumerated() {
                                    let br = display.brightness.uint8Value
                                    mainAsyncAfter(ms: num * 50) {
                                        display.withForce { display.brightness = cap(br - 1, minVal: 0, maxVal: 100).ns }
                                    }
                                    mainAsyncAfter(ms: 300 + num * 50) {
                                        display.withForce { display.brightness = cap(br, minVal: 0, maxVal: 100).ns }
                                    }
                                    mainAsyncAfter(ms: 600 + num * 50) {
                                        display.withForce { display.brightness = cap(br + 1, minVal: 0, maxVal: 100).ns }
                                    }
                                    mainAsyncAfter(ms: 900 + num * 50) {
                                        display.withForce { display.brightness = cap(br, minVal: 0, maxVal: 100).ns }
                                    }
                                }
                            } else {
                                displayController.adaptBrightness(force: true)
                            }

                            for display in displayController.activeDisplays.values.filter(\.blackOutEnabled) {
                                display.apply(gamma: GammaTable.zero, force: true)

                                if display.isSmartBuiltin, display.readBrightness() != 0 {
                                    display.withoutSmoothTransition {
                                        display.withForce {
                                            display.brightness = 0
                                        }
                                    }
                                }
                            }

                            for display in displayController.activeDisplays.values.filter({ !$0.blackOutEnabled }) {
                                if display.redGain.uint8Value != DEFAULT_COLOR_GAIN {
                                    _ = display.control?.setRedGain(display.redGain.uint8Value)
                                }
                                if display.greenGain.uint8Value != DEFAULT_COLOR_GAIN {
                                    _ = display.control?.setGreenGain(display.greenGain.uint8Value)
                                }
                                if display.blueGain.uint8Value != DEFAULT_COLOR_GAIN {
                                    _ = display.control?.setBlueGain(display.blueGain.uint8Value)
                                }
                            }
                        }
                    }

                case NSWorkspace.screensDidSleepNotification:
                    log.debug("Screens gone to sleep")
                    screensSleeping.store(true, ordering: .sequentiallyConsistent)

                    if let task = self.valuesReaderThread {
                        lowprioQueue.cancel(timer: task)
                    }
                    displayController.adaptiveMode.stopWatching()
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

    func showAdvancedSettings(highlight: Bool = false) {
        CachedDefaults[.advancedSettingsShown] = true
        currentPage = Page.settings.rawValue
        uiElement = .advancedSettingsButton
        appDelegate!.goToPage(highlight: highlight)
    }

    func showConfigurationPage() {
        CachedDefaults[.advancedSettingsShown] = false
        currentPage = Page.settings.rawValue
        uiElement = nil
        appDelegate!.goToPage()
    }

    func hideAdvancedSettings() {
        CachedDefaults[.advancedSettingsShown] = false
        uiElement = nil
    }

    func recreateWindow(page: Int? = nil, advancedSettings: Bool? = nil) {
        if windowController?.window != nil {
            let window = windowController!.window!
            let shouldShow = window.isVisible
            let lastPosition = window.frame.origin
            windowController?.close()
            windowController?.window = nil
            windowController = nil
            if let page = page {
                currentPage = page
            }
            if let advancedSettings = advancedSettings {
                CachedDefaults[.advancedSettingsShown] = advancedSettings
            }
            if shouldShow {
                showWindow(position: lastPosition, focus: NSRunningApplication.current.isActive)
            }
        }
    }

    func addWatchers() {
        // asyncEvery
    }

    func addObservers() {
        dayMomentsPublisher.sink {
            if displayController.adaptiveModeKey == .location {
                displayController.adaptBrightness()
            }
        }.store(in: &observers)

        refreshValuesPublisher.sink { change in
            if let task = self.valuesReaderThread {
                lowprioQueue.cancel(timer: task)
            }
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
            log.info("Hiding menu bar icon: \(change.newValue)")
            self.statusItem.isVisible = !change.newValue
        }.store(in: &observers)
        statusItem.isVisible = !CachedDefaults[.hideMenuBarIcon]

        showDockIconPublisher.sink { change in
            log.info("Showing dock icon: \(change.newValue)")
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
            .receive(on: RunLoop.main)
            .sink { _ in appDelegate!.startOrRestartMediaKeyTap() }
            .store(in: &observers)
        NotificationCenter.default
            .publisher(for: currentDataPointChanged, object: nil)
            .receive(on: RunLoop.main)
            .sink { _ in appDelegate!.updateInfoMenuItem() }
            .store(in: &observers)
        showBrightnessMenuBarPublisher.sink { [self] change in
            mainAsync {
                if change.newValue {
                    statusItem.button?.imagePosition = .imageLeading
                    updateInfoMenuItem()
                } else {
                    statusItem.button?.imagePosition = .imageOnly
                }
            }
        }.store(in: &observers)
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
        PFMoveToApplicationsFolderIfNecessary()
    }

    func addGlobalMouseDownMonitor() {
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { _ in
            guard let menuPopover = menuPopover, menuPopover.isShown else { return }
            menuPopover.close()
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        let xsdf = initStuff
        if !CommandLine.arguments.contains("@") {
            log.initLogger()
        }

        initCache()
        brightnessTransition = CachedDefaults[.brightnessTransition]
        brightnessTransitionPublisher.sink { change in
            brightnessTransition = change.newValue
        }.store(in: &observers)

        signal(SIGINT) { _ in
            for display in displayController.displays.values {
                if display.gammaChanged {
                    display.resetGamma()
                }

                display.gammaUnlock()
                refreshScreen()
            }

            globalExit(0)
        }

        if let idx = CommandLine.arguments.firstIndex(of: "@") {
            asyncNow {
                log.initLogger(cli: true)
                Lunar.main(Array(CommandLine.arguments[idx + 1 ..< CommandLine.arguments.count]))
            }
            return
        }

        Defaults[.cliInstalled] = fm.isExecutableBinary(atPath: "/usr/local/bin/lunar")
        Defaults[.accessibilityPermissionsGranted] = AXIsProcessTrusted()
        let nc = UNUserNotificationCenter.current()
        nc.getNotificationSettings { settings in
            mainAsync {
                let enabled = settings.alertSetting == .enabled
                Defaults[.notificationsPermissionsGranted] = enabled
                // if !enabled, !datastore.shouldOnboard {
                //     nc.requestAuthorization(options: [.alert, .provisional], completionHandler: { _, _ in })
                // }
            }
        }

        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        ValueTransformer.setValueTransformer(StringNumberTransformer(), forName: .stringNumberTransformerName)
        ValueTransformer.setValueTransformer(UpdateCheckIntervalTransformer(), forName: .updateCheckIntervalTransformerName)
        ValueTransformer.setValueTransformer(SignedIntTransformer(), forName: .signedIntTransformerName)
        ValueTransformer.setValueTransformer(ColorSchemeTransformer(), forName: .colorSchemeTransformerName)

        let release = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
        SentrySDK.start { options in
            options.dsn = secrets.sentryDSN
            options.releaseName = "v\(release)"
            options.dist = release
            options.environment = "production"
        }

        let user = User(userId: getSerialNumberHash() ?? "NOID")
        user.email = lunarProProduct?.activationEmail
        user.username = lunarProProduct?.activationID
        SentrySDK.configureScope { scope in
            scope.setUser(user)
            scope.setTag(value: displayController.adaptiveModeString(), key: "adaptiveMode")
            scope.setTag(value: displayController.adaptiveModeString(last: true), key: "lastAdaptiveMode")
            scope.setTag(value: CachedDefaults[.overrideAdaptiveMode] ? "false" : "true", key: "autoMode")
        }

        let runningApp = NSWorkspace.shared.runningApplications
            .filter { item in item.bundleIdentifier == Bundle.main.bundleIdentifier }
            .first { item in item.processIdentifier != getpid() }

        if let app = runningApp, app.forceTerminate() {
            notify(
                identifier: "lunar-single-instance",
                title: "Lunar was already running",
                body: "The other instance was terminated and this instance will now continue to run normally."
            )
        }

        DDC.setup()

        displayController.displays = displayController.getDisplaysLock.around {
            DisplayController.getDisplays(
                includeVirtual: CachedDefaults[.showVirtualDisplays],
                includeAirplay: CachedDefaults[.showAirplayDisplays],
                includeProjector: CachedDefaults[.showProjectorDisplays],
                includeDummy: CachedDefaults[.showDummyDisplays]
            )
        }
        displayController.addSentryData()

        if let logPath = LOG_URL?.path.cString(using: .utf8) {
            log.info("Setting log path to \(LOG_URL?.path ?? "")")
            setLogPath(logPath, logPath.count)
        }

        try? updater.start()
        handleDaemon()

        initDisplayControllerActivity()
        initMenubarIcon()

        addGlobalMouseDownMonitor()
        initHotkeys()

        listenForAdaptiveModeChange()
        listenForSettingsChange()
        checkForHighMemoryUsage()
        listenForScreenConfigurationChanged()
        displayController.listenForRunningApps()

        addWatchers()
        addObservers()
        initLicensing()

        NetworkControl.setup()
        if datastore.shouldOnboard {
            onboard()
        } else if CachedDefaults[.brightnessKeysEnabled] || CachedDefaults[.volumeKeysEnabled] {
            startOrRestartMediaKeyTap(checkPermissions: true)
        } else if let apps = CachedDefaults[.appExceptions], !apps.isEmpty {
            acquirePrivileges(
                notificationTitle: "Lunar can now watch for app exceptions",
                notificationBody: "Whenever an app in the exception list is focused or visible on a screen, Lunar will apply its offsets."
            )
        }

        if TEST_MODE, !datastore.shouldOnboard {
            showWindow()
            // onboard()
        }

        if TEST_MODE {
            fm.createFile(
                atPath: "/usr/local/bin/lunar",
                contents: LUNAR_CLI_SCRIPT.data(using: .utf8),
                attributes: [.posixPermissions: 0o755]
            )
            // createAndShowWindow("diagnosticsWindowController", controller: &diagnosticsWindowController)
        }

        startReceivingSignificantLocationChanges()

        if !TEST_MODE {
            SentrySDK.capture(message: "Launch")
        }

        if CachedDefaults[.reapplyValuesAfterWake] {
            asyncEvery(2.seconds, uniqueTaskKey: SCREEN_WAKE_ADAPTER_TASK_KEY, runs: 5, skipIfExists: true) { _ in
                displayController.adaptBrightness(force: true)
                for display in displayController.activeDisplays.values {
                    if display.redGain.uint8Value != DEFAULT_COLOR_GAIN {
                        _ = display.control?.setRedGain(display.redGain.uint8Value)
                    }
                    if display.greenGain.uint8Value != DEFAULT_COLOR_GAIN {
                        _ = display.control?.setGreenGain(display.greenGain.uint8Value)
                    }
                    if display.blueGain.uint8Value != DEFAULT_COLOR_GAIN {
                        _ = display.control?.setBlueGain(display.blueGain.uint8Value)
                    }
                }
            }
        }

        NotificationCenter.default.post(name: displayListChanged, object: nil)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4"
        log.info("App finished launching v\(version)")
    }

    @IBAction func forceUpdateDisplayList(_: Any) {
        displayController.resetDisplayList()
        appDelegate!.startOrRestartMediaKeyTap()
    }

    @IBAction func openLunarDiagnostics(_: Any) {
        useOnboardingForDiagnostics = true
        createAndShowWindow("onboardWindowController", controller: &onboardWindowController)
        // createAndShowWindow("diagnosticsWindowController", controller: &diagnosticsWindowController)
    }

    @IBAction func restartApp(_: Any) {
        _ = shell(
            command: "while ps -p \(ProcessInfo.processInfo.processIdentifier) >/dev/null 2>/dev/null; do sleep 0.1; done; open '\(Bundle.main.path.string)'",
            wait: false
        )
        exit(0)
    }

    func applicationWillTerminate(_: Notification) {
        log.info("Going down")

        CachedDefaults[.debug] = false

        if let task = valuesReaderThread {
            lowprioQueue.cancel(timer: task)
        }
        displayController.activeDisplays.values.filter(\.faceLightEnabled).forEach { display in
            display.disableFaceLight(smooth: false)
            display.save(now: true)
        }
        displayController.activeDisplays.values.filter(\.blackOutEnabled).forEach { display in
            display.disableBlackOut()
            display.save(now: true)
        }
    }

    func geolocationFallback() {
        LocationMode.specific.fetchGeolocation()
    }

    internal func locationManager(_ lm: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !CachedDefaults[.manualLocation] else { return }

        guard let location = locations.last ?? lm.location, let geolocation = Geolocation(location: location)
        else {
            log.debug("Zero LocationManager coordinates")
            geolocationFallback()
            return
        }

        log.debug("Got LocationManager coordinates")
        LocationMode.specific.geolocation = geolocation
        geolocation.store()
        LocationMode.specific.fetchMoments()
    }

    internal func locationManager(_ lm: CLLocationManager, didFailWithError error: Error) {
        log.error("Location manager failed with error: \(error)")
        guard !CachedDefaults[.manualLocation] else { return }

        guard let location = lm.location, let geolocation = Geolocation(location: location)
        else {
            log.debug("Zero LocationManager coordinates")
            geolocationFallback()
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
        case .denied, .restricted:
            log.warning("User has not authorised location services")
            lm.stopUpdatingLocation()
            geolocationFallback()
        @unknown default:
            log.error("Unknown location manager status \(status)")
        }
    }

    func startReceivingSignificantLocationChanges() {
        if CachedDefaults[.manualLocation] {
            LocationMode.specific.geolocation = CachedDefaults[.location]
            return
        }

        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager!.delegate = self
            locationManager!.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            locationManager!.distanceFilter = 10000
        }

        locationManager!.stopUpdatingLocation()
        locationManager!.startUpdatingLocation()

        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways:
            log.debug("Location authStatus: authorizedAlways")
        case .denied:
            log.debug("Location authStatus: denied")
        case .notDetermined:
            log.debug("Location authStatus: notDetermined")
        case .restricted:
            log.debug("Location authStatus: restricted")
        case .authorized:
            log.debug("Location authStatus: authorized")
        @unknown default:
            log.debug("Location authStatus: unknown??")
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
        displayController.adaptBrightness()
    }

    func setLightPercent(percent: Int8) {
        guard checkRemainingAdjustments() else { return }

        displayController.disable()
        displayController.setBrightnessPercent(value: percent)
        displayController.setContrastPercent(value: percent)
        log.debug("Setting brightness and contrast to \(percent)%")
    }

    func toggleAudioMuted(for displays: [Display]? = nil, currentDisplay: Bool = false, currentAudioDisplay: Bool = true) {
        displayController.toggleAudioMuted(for: displays, currentDisplay: currentDisplay, currentAudioDisplay: currentAudioDisplay)
    }

    func increaseVolume(
        by amount: Int? = nil,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        currentAudioDisplay: Bool = true
    ) {
        let amount = amount ?? CachedDefaults[.volumeStep]
        serialQueue
            .async {
                displayController.adjustVolume(
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
        serialQueue
            .async {
                displayController.adjustVolume(
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
        sourceDisplay: Bool = false
    ) {
        let amount = amount ?? CachedDefaults[.brightnessStep]
        displayController.adjustBrightness(
            by: amount,
            for: displays,
            currentDisplay: currentDisplay,
            builtinDisplay: builtinDisplay,
            sourceDisplay: sourceDisplay
        )
    }

    func increaseContrast(
        by amount: Int? = nil,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        sourceDisplay: Bool = false
    ) {
        let amount = amount ?? CachedDefaults[.contrastStep]
        displayController.adjustContrast(by: amount, for: displays, currentDisplay: currentDisplay, sourceDisplay: sourceDisplay)
    }

    func decreaseBrightness(
        by amount: Int? = nil,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        builtinDisplay: Bool = false,
        sourceDisplay: Bool = false
    ) {
        let amount = amount ?? CachedDefaults[.brightnessStep]
        displayController.adjustBrightness(
            by: -amount,
            for: displays,
            currentDisplay: currentDisplay,
            builtinDisplay: builtinDisplay,
            sourceDisplay: sourceDisplay
        )
    }

    func decreaseContrast(
        by amount: Int? = nil,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        sourceDisplay: Bool = false
    ) {
        let amount = amount ?? CachedDefaults[.contrastStep]
        displayController.adjustContrast(by: -amount, for: displays, currentDisplay: currentDisplay, sourceDisplay: sourceDisplay)
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

    @IBAction func buyMeACoffee(_: Any) {
        if let url = URL(string: "https://www.buymeacoffee.com/alin23") {
            NSWorkspace.shared.open(url)
        }
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

    @IBAction func installCLI(_: Any) {
        let shouldInstall: Bool = ask(
            message: "Lunar CLI",
            info: "This will install the `lunar` binary into /usr/local/bin.\n\nDo you want to proceed?",
            okButton: "Yes",
            cancelButton: "No",
            unique: true
        )
        if shouldInstall {
            do {
                try installCLIBinary()
                dialog(message: "Lunar CLI installed", info: "", cancelButton: nil).runModal()
            } catch let error as InstallCLIError {
                dialog(message: error.message, info: error.info, cancelButton: nil).runModal()
            } catch {
                dialog(message: "Error installing Lunar CLI", info: "\(error)", cancelButton: nil).runModal()
            }
        }
    }

    // MARK: Private

    @objc private func activate() {
        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
    }
}

// MARK: - InstallCLIError

struct InstallCLIError: Error {
    let message: String
    let info: String
}

func installCLIBinary() throws {
    if !fm.fileExists(atPath: "/usr/local/bin") {
        do {
            try fm.createDirectory(atPath: "/usr/local/bin", withIntermediateDirectories: false)
        } catch {
            log.error("Error on creating /usr/local/bin: \(error)")
            throw InstallCLIError(
                message: "Missing /usr/local/bin",
                info: "Error on creating the '/usr/local/bin' directory: \(error)"
            )
        }
    }

    fm.createFile(
        atPath: "/usr/local/bin/lunar",
        contents: LUNAR_CLI_SCRIPT.data(using: .utf8),
        attributes: [.posixPermissions: 0o755]
    )

    guard fm.isExecutableBinary(atPath: "/usr/local/bin/lunar") else {
        throw InstallCLIError(
            message: "File permissions error",
            info: """
            You can fix permissions by running the following commands in a terminal:

            sudo chown -R $(whoami) /usr/local/bin
            sudo chmod 755 /usr/local/bin
            """
        )
    }
    Defaults[.cliInstalled] = true
}

func acquirePrivileges(notificationTitle: String = "Lunar is now listening for media keys", notificationBody: String? = nil) {
    let onAcquire = {
        mainAsync { Defaults[.accessibilityPermissionsGranted] = true }
        appDelegate!.startOrRestartMediaKeyTap()
        guard !CachedDefaults[.mediaKeysNotified] else { return }
        CachedDefaults[.mediaKeysNotified] = true

        var body = notificationBody ??
            "You can now use PLACEHOLDER keys to control your monitors. Swipe right in the Lunar window to get to the Hotkeys page and manage this funtionality."

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

    asyncEvery(2.seconds, uniqueTaskKey: "AXPermissionsChecker") { _ in
        if AXIsProcessTrusted() {
            onAcquire()
            cancelTask("AXPermissionsChecker")
        }
    }
}
