//
//  AppDelegate.swift
//  Lunar
//
//  Created by Alin on 30/11/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Alamofire
import Carbon.HIToolbox
import Cocoa
import Compression
import CoreLocation
import Defaults
import LaunchAtLogin
import LetsMove
import Magnet
import Path
import Sauce
import Sentry
import SimplyCoreAudio
import Sparkle
import SwiftDate
import WAYWindow

let fm = FileManager()
let simplyCA = SimplyCoreAudio()
var screensSleeping = false
let SCREEN_WAKE_ADAPTER_TASK_KEY = "screenWakeAdapter"

private let kAppleInterfaceThemeChangedNotification = "AppleInterfaceThemeChangedNotification"
private let kAppleInterfaceStyle = "AppleInterfaceStyle"
private let kAppleInterfaceStyleSwitchesAutomatically = "AppleInterfaceStyleSwitchesAutomatically"

let operationHighlightQueue = RunloopQueue(named: "fyi.lunar.operation.queue")
let serviceBrowserQueue = RunloopQueue(named: "fyi.lunar.serviceBrowser.queue")
let realtimeQueue = RunloopQueue(named: "fyi.lunar.realtime.queue")
let lowprioQueue = RunloopQueue(named: "fyi.lunar.lowprio.queue")
let concurrentQueue = DispatchQueue(label: "fyi.lunar.concurrent.queue", qos: .userInitiated, attributes: .concurrent)
let serialQueue = DispatchQueue(label: "fyi.lunar.serial.queue", qos: .userInitiated)
let appName = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Lunar"

let TEST_MODE = AppSettings.testMode
let LOG_URL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(appName, isDirectory: true)
    .appendingPathComponent("swiftybeaver.log", isDirectory: false)
let TRANSFER_URL = "https://transfer.sh"
let LOG_UPLOAD_URL = "https://log.lunar.fyi/upload"
let ANALYTICS_URL = "https://log.lunar.fyi/analytics"
let DEBUG_DATA_HEADERS: HTTPHeaders = [
    "Content-type": "application/octet-stream",
    "Max-Downloads": "50",
    "Max-Days": "5",
]
let LOG_ENCODING_THRESHOLD: UInt64 = 100_000_000 // 100MB

var activeDisplay: Display?

var thisIsFirstRun = false
var thisIsFirstRunAfterLunar4Upgrade = false

func fadeTransition(duration: TimeInterval) -> CATransition {
    let transition = CATransition()
    transition.duration = duration
    transition.type = .fade
    return transition
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate, NSMenuDelegate, SUUpdaterDelegate {
    var locationManager: CLLocationManager?
    var windowControllerSemaphore = DispatchSemaphore(value: 1)
    var _windowController: ModernWindowController?
    var windowController: ModernWindowController? {
        get {
            windowControllerSemaphore.wait()
            let controller = _windowController
            windowControllerSemaphore.signal()
            return controller
        }
        set {
            windowControllerSemaphore.wait()
            _windowController = newValue
            windowControllerSemaphore.signal()
        }
    }

    var sshWindowController: ModernWindowController?
    var updateInfoWindowController: ModernWindowController?
    var diagnosticsWindowController: ModernWindowController?
    var gammaWindowController: ModernWindowController?

    var valuesReaderThread: CFRunLoopTimer?
    var refreshValues: Bool = Defaults[.refreshValues]

    var statusButtonTrackingArea: NSTrackingArea?
    var statusItemButtonController: StatusItemButtonController?
    var alamoFireManager = buildAlamofireSession(requestTimeout: 24.hours, resourceTimeout: 7.days)

    var adaptiveBrightnessModeObserver: Defaults.Observation?
    var startAtLoginObserver: Defaults.Observation?
    var dayMomentsObserver: Defaults.Observation?
    var curveFactorObserver: Defaults.Observation?
    var refreshValuesObserver: Defaults.Observation?
    var hotkeysObserver: Defaults.Observation?
    var mediaKeysObserver: Defaults.Observation?
    var hideMenuBarIconObserver: Defaults.Observation?
    var showDockIconObserver: Defaults.Observation?

    @IBOutlet var versionMenuItem: NSMenuItem!
    @IBOutlet var menu: NSMenu!
    @IBOutlet var preferencesMenuItem: NSMenuItem!
    @IBOutlet var debugMenuItem: NSMenuItem!
    @IBOutlet var infoMenuItem: NSMenuItem!

    @IBOutlet var percent0MenuItem: NSMenuItem!
    @IBOutlet var percent25MenuItem: NSMenuItem!
    @IBOutlet var percent50MenuItem: NSMenuItem!
    @IBOutlet var percent75MenuItem: NSMenuItem!
    @IBOutlet var percent100MenuItem: NSMenuItem!

    @IBOutlet var brightnessUpMenuItem: NSMenuItem!
    @IBOutlet var brightnessDownMenuItem: NSMenuItem!
    @IBOutlet var contrastUpMenuItem: NSMenuItem!
    @IBOutlet var contrastDownMenuItem: NSMenuItem!
    @IBOutlet var resetTrialMenuItem: NSMenuItem!
    @IBOutlet var expireTrialMenuItem: NSMenuItem!
    @IBOutlet var updater: SUUpdater!

    @IBOutlet var lunarProMenuItem: NSMenuItem!
    @IBOutlet var activateLicenseMenuItem: NSMenuItem!
    @IBOutlet var faceLightMenuItem: NSMenuItem!

    @objc dynamic var faceLightOn = false

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    func menuWillOpen(_: NSMenu) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4"

        initLicensingMenuItems(version)
    }

    func initHotkeys() {
        var hotkeyConfig = Defaults[.hotkeys]

        for identifierCase in HotkeyIdentifier.allCases {
            let identifier = identifierCase.rawValue
            guard let hotkey = hotkeyConfig[identifier] ?? Hotkey.defaults[identifier],
                  let keyCode = hotkey[.keyCode],
                  var enabled = hotkey[.enabled],
                  let modifiers = hotkey[.modifiers]
            else {
                continue
            }

            if hotkeyConfig[identifier] == nil {
                hotkeyConfig[identifier] = hotkey
            }

            if !preciseHotkeys.contains(identifier) {
                if let keyCombo = KeyCombo(QWERTYKeyCode: keyCode, carbonModifiers: modifiers) {
                    Hotkey.keys[identifier] = PersistentHotkey(hotkey: Magnet.HotKey(
                        identifier: identifier,
                        keyCombo: keyCombo,
                        target: self,
                        action: Hotkey.handler(identifier: identifierCase)
                    ), isEnabled: enabled == 1)
                }
            } else {
                guard let coarseIdentifier = coarseHotkeysMapping[identifier],
                      let coarseHotkey = hotkeyConfig[coarseIdentifier] ?? Hotkey.defaults[coarseIdentifier],
                      let coarseKeyCode = coarseHotkey[.keyCode],
                      let coarseEnabled = coarseHotkey[.enabled],
                      let coarseModifiers = coarseHotkey[.modifiers]
                else {
                    continue
                }

                var flags = NSEvent.ModifierFlags(carbonModifiers: coarseModifiers)
                if flags.contains(.option) {
                    log.warning("Hotkey \(coarseIdentifier) already binds option. Fine adjustment will be disabled")
                    enabled = 0
                } else {
                    if coarseEnabled == 0 {
                        enabled = coarseEnabled
                    }
                    flags.insert(.option)
                }

                let newModifiers = flags.carbonModifiers()

                hotkeyConfig[identifier]?[.modifiers] = newModifiers
                hotkeyConfig[identifier]?[.keyCode] = coarseKeyCode

                if let keyCombo = KeyCombo(QWERTYKeyCode: coarseKeyCode, carbonModifiers: newModifiers) {
                    Hotkey.keys[identifier] = PersistentHotkey(hotkey: Magnet.HotKey(
                        identifier: identifier,
                        keyCombo: keyCombo,
                        target: self,
                        action: Hotkey.handler(identifier: identifierCase)
                    ), isEnabled: enabled == 1)
                }
            }
        }
        Defaults[.hotkeys] = hotkeyConfig
        setKeyEquivalents(hotkeyConfig)
        startOrRestartMediaKeyTap()
    }

    func listenForAdaptiveModeChange() {
        adaptiveBrightnessModeObserver = adaptiveBrightnessModeObserver ?? Defaults.observe(.adaptiveBrightnessMode) { change in
            SentrySDK.configureScope { scope in
                scope.setTag(value: displayController.adaptiveModeString(), key: "adaptiveMode")
                scope.setTag(value: displayController.adaptiveModeString(last: true), key: "lastAdaptiveMode")
                scope.setTag(value: Defaults[.overrideAdaptiveMode] ? "false" : "true", key: "autoMode")
            }
            if change.newValue == change.oldValue || !Defaults[.overrideAdaptiveMode] {
                return
            }
            Defaults[.nonManualMode] = change.newValue != .manual
            displayController.adaptiveMode = change.newValue.mode
            mainThread {
                self.resetElements()
            }
            self.manageDisplayControllerActivity(mode: displayController.adaptiveModeKey)
        }
    }

    func listenForSettingsChange() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adaptToSettingsChange(notification:)),
            name: UserDefaults.didChangeNotification,
            object: UserDefaults.standard
        )
    }

    @objc func adaptToSettingsChange(notification _: Notification) {
        displayController.addSentryData()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let mode = AdaptiveModeKey(rawValue: menuItem.tag) else {
            return false
        }
        return mode.available
    }

    func showWindow() {
        createAndShowWindow("windowController", controller: &windowController)
    }

    @objc private func activate() {
        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
    }

    func handleDaemon() {
        let handler = { (shouldStartAtLogin: Bool) in
            LaunchAtLogin.isEnabled = shouldStartAtLogin

            guard let appPath = Path(Bundle.main.bundlePath), appPath.parent == Path("/Applications")
            else { return }
            if shouldStartAtLogin {
                LoginServiceKit.addLoginItems()
            } else if !shouldStartAtLogin {
                LoginServiceKit.removeLoginItems()
            }
        }

        handler(Defaults[.startAtLogin])
        startAtLoginObserver = startAtLoginObserver ?? Defaults.observe(.startAtLogin) { change in
            if change.newValue == change.oldValue {
                return
            }
            handler(change.newValue)
        }
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
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        showWindow()
        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
        return true
    }

    func applicationDidBecomeActive(_: Notification) {
        if Defaults[.hideMenuBarIcon] {
            showWindow()
        }
    }

    @objc func updateInfoMenuItem(notification: Notification) {
        switch displayController.adaptiveModeKey {
        case .sensor:
            guard let info = notification.userInfo as? [String: Double], let ambientLight = info["ambientLight"] else { return }
            mainThread {
                self.infoMenuItem?.title = "Ambient light: \(String(format: "%.2f", ambientLight)) lux"
            }
        case .location:
            guard let info = notification.userInfo as? [String: Double], let elevation = info["sunElevation"] else { return }
            mainThread {
                self.infoMenuItem?.title = "Sun elevation: \(String(format: "%.2f", elevation))°"
            }
        case .sync:
            guard let info = notification.userInfo as? [String: Double], let builtinBrightness = info["brightness"] else { return }
            mainThread {
                self.infoMenuItem?.title = "Built-in display brightness: \(builtinBrightness.rounded(.toNearestOrAwayFromZero))%"
            }
        case .manual:
            guard let info = notification.userInfo as? [String: Double] else { return }
            mainThread {
                if let brightness = info["brightness"] {
                    self.infoMenuItem?.title = "Last set brightness: \(brightness)"
                } else if let contrast = info["contrast"] {
                    self.infoMenuItem?.title = "Last set contrast: \(contrast)"
                }
            }
        }
    }

    func manageDisplayControllerActivity(mode: AdaptiveModeKey) {
        log.debug("Started DisplayController in \(mode.str) mode")
        updateDataPointObserver()
        _ = displayController.adaptiveMode.watch()
        displayController.adaptBrightness()
    }

    func startValuesReaderThread() {
        valuesReaderThread = asyncEvery(10.seconds, queue: lowprioQueue) { _ in
            guard !screensSleeping else { return }

            if self.refreshValues {
                displayController.fetchValues()
            }
        }
    }

    func initDisplayControllerActivity() {
        if refreshValues {
            startValuesReaderThread()
        }

        manageDisplayControllerActivity(mode: displayController.adaptiveModeKey)
    }

    func initMenubarIcon() {
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("MenubarIcon"))
            button.image?.isTemplate = true

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
        statusItem.menu = menu

        if POPOVERS[.menu]!!.contentViewController == nil {
            guard let storyboard = NSStoryboard.main else { return }

            POPOVERS[.menu]!!.contentViewController = storyboard
                .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("MenuPopoverController")) as! MenuPopoverController
            POPOVERS[.menu]!!.contentViewController!.loadView()

            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(appleInterfaceThemeChangedNotification(notification:)),
                name: NSNotification.Name(rawValue: kAppleInterfaceThemeChangedNotification),
                object: nil
            )
            // adaptAppearance()
        }
    }

    @objc func appleInterfaceThemeChangedNotification(notification _: Notification) {
        // adaptAppearance()
    }

    func adaptAppearance() {
        mainThread {
            guard let menuPopover = POPOVERS[.menu]! else { return }
            menuPopover.appearance = NSAppearance(named: .vibrantLight)
            let appearanceDescription = NSApplication.shared.effectiveAppearance.debugDescription.lowercased()
            if appearanceDescription.contains("dark") {
                menuPopover.appearance = NSAppearance(named: .vibrantDark)
            }
        }
    }

    func listenForScreenConfigurationChanged() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adaptToScreenConfiguration(notification:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(adaptToScreenConfiguration(notification:)),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(adaptToScreenConfiguration(notification:)),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
    }

    func updateDataPointObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: currentDataPointChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateInfoMenuItem(notification:)),
            name: currentDataPointChanged,
            object: nil
        )
    }

    @objc func adaptToScreenConfiguration(notification: Notification) {
        log.debug("Screen configuration notification: \(notification)")
        switch notification.name {
        case NSApplication.didChangeScreenParametersNotification:
            log.debug("Screen configuration changed")
            POPOVERS[.menu]!!.close()
            displayController.manageClamshellMode()
            displayController.resetDisplayList()
            SyncMode.builtinDisplay = SyncMode.getBuiltinDisplay()
            asyncAfter(ms: 5000) {
                NetworkControl.resetState()
            }
            if let visible = windowController?.window?.isVisible, visible {
                windowController?.close()
                windowController?.window = nil
                windowController = nil
                showWindow()
            }
        case NSWorkspace.screensDidWakeNotification:
            log.debug("Screens woke up")
            screensSleeping = false

            if refreshValues {
                startValuesReaderThread()
            }
            _ = displayController.adaptiveMode.watch()

            if Defaults[.reapplyValuesAfterWake] {
                asyncAfter(ms: 5000, uniqueTaskKey: SCREEN_WAKE_ADAPTER_TASK_KEY) {
                    NetworkControl.resetState()

                    for _ in 1 ... 5 {
                        displayController.adaptBrightness(force: true)
                        sleep(3)
                    }
                }
            }
        case NSWorkspace.screensDidSleepNotification:
            log.debug("Screens gone to sleep")
            screensSleeping = true
            if let task = valuesReaderThread {
                lowprioQueue.cancel(timer: task)
            }
            displayController.adaptiveMode.stopWatching()
        default:
            return
        }
    }

    func addObservers() {
        dayMomentsObserver = dayMomentsObserver ?? Defaults.observe(keys: .sunset, .sunset, .solarNoon) {
            if displayController.adaptiveModeKey == .location {
                displayController.adaptBrightness()
            }
        }
        curveFactorObserver = curveFactorObserver ?? Defaults.observe(.curveFactor) { _ in
            displayController.adaptBrightness()
        }

        refreshValuesObserver = refreshValuesObserver ?? Defaults.observe(.refreshValues) { change in
            self.refreshValues = change.newValue

            if let task = self.valuesReaderThread {
                lowprioQueue.cancel(timer: task)
            }
            if self.refreshValues {
                self.startValuesReaderThread()
            }
        }

        hotkeysObserver = hotkeysObserver ?? Defaults.observe(.hotkeys) { _ in
            mainThread {
                self.setKeyEquivalents(Defaults[.hotkeys])
            }
        }

        mediaKeysObserver = mediaKeysObserver ?? Defaults.observe(keys: .brightnessKeysEnabled, .volumeKeysEnabled, .mediaKeysControlAllMonitors) {
            self.startOrRestartMediaKeyTap()
        }

        hideMenuBarIconObserver = hideMenuBarIconObserver ?? Defaults.observe(.hideMenuBarIcon) { change in
            log.info("Hiding menu bar icon: \(change.newValue)")
            self.statusItem.isVisible = !change.newValue
        }
        statusItem.isVisible = !Defaults[.hideMenuBarIcon]

        showDockIconObserver = showDockIconObserver ?? Defaults.observe(.showDockIcon) { change in
            log.info("Showing dock icon: \(change.newValue)")
            NSApp.setActivationPolicy(change.newValue ? .regular : .accessory)
            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
        }
        NSApp.setActivationPolicy(Defaults[.showDockIcon] ? .regular : .accessory)

        NotificationCenter.default.addObserver(
            forName: .defaultOutputDeviceChanged,
            object: nil,
            queue: .main
        ) { _ in
            mainThread {
                appDelegate().startOrRestartMediaKeyTap()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .defaultSystemOutputDeviceChanged,
            object: nil,
            queue: .main
        ) { _ in
            mainThread {
                appDelegate().startOrRestartMediaKeyTap()
            }
        }
    }

    func setKeyEquivalents(_ hotkeys: [String: [HotkeyPart: Int]]) {
        Hotkey.setKeyEquivalent(HotkeyIdentifier.lunar.rawValue, menuItem: preferencesMenuItem, hotkeys: hotkeys)

        Hotkey.setKeyEquivalent(HotkeyIdentifier.percent0.rawValue, menuItem: percent0MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.percent25.rawValue, menuItem: percent25MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.percent50.rawValue, menuItem: percent50MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.percent75.rawValue, menuItem: percent75MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.percent100.rawValue, menuItem: percent100MenuItem, hotkeys: hotkeys)

        Hotkey.setKeyEquivalent(HotkeyIdentifier.brightnessUp.rawValue, menuItem: brightnessUpMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.brightnessDown.rawValue, menuItem: brightnessDownMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.contrastUp.rawValue, menuItem: contrastUpMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(HotkeyIdentifier.contrastDown.rawValue, menuItem: contrastDownMenuItem, hotkeys: hotkeys)

        menu?.update()
    }

    func acquirePrivileges(_ onAcquire: @escaping (() -> Void)) {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true as CFBoolean,
        ]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if accessEnabled {
            onAcquire()
            return
        }

        asyncEvery(2.seconds, uniqueTaskKey: "AXPermissionsChecker") {
            if AXIsProcessTrusted() {
                onAcquire()
                cancelAsyncRecurringTask("AXPermissionsChecker")
            }
        }
    }

    func onboard() {}

    func applicationWillFinishLaunching(_: Notification) {
        PFMoveToApplicationsFolderIfNecessary()
    }

    func applicationDidFinishLaunching(_: Notification) {
        signal(SIGINT) { _ in
            for display in displayController.displays.values {
                display.resetGamma()
                display.gammaUnlock()
                refreshScreen()
            }
            exit(0)
        }

        if let idx = CommandLine.arguments.firstIndex(of: "@") {
            log.initLogger(cli: true)
            async {
                Lunar.main(Array(CommandLine.arguments[idx + 1 ..< CommandLine.arguments.count]))
            }
            return
        }

        log.initLogger()
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        NetworkControl.setup()
        ValueTransformer.setValueTransformer(AppExceptionTransformer(), forName: .appExceptionTransformerName)
        ValueTransformer.setValueTransformer(DisplayTransformer(), forName: .displayTransformerName)

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
            scope.setTag(value: Defaults[.overrideAdaptiveMode] ? "false" : "true", key: "autoMode")
        }

        acquirePrivileges {
            self.startOrRestartMediaKeyTap()
        }

        displayController.displays = DisplayController.getDisplays()
        displayController.addSentryData()

        if let logPath = LOG_URL?.path.cString(using: .utf8) {
            log.info("Setting log path to \(LOG_URL?.path ?? "")")
            setLogPath(logPath, logPath.count)
        }

        handleDaemon()

        initDisplayControllerActivity()
        initMenubarIcon()
        initHotkeys()

        listenForAdaptiveModeChange()
        listenForScreenConfigurationChanged()
        displayController.listenForRunningApps()

        addObservers()
        initLicensing()
        if thisIsFirstRun || TEST_MODE {
            showWindow()
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

        asyncAfter(ms: 200, uniqueTaskKey: SCREEN_WAKE_ADAPTER_TASK_KEY) {
            for _ in 1 ... 5 {
                displayController.adaptBrightness(force: true)
                sleep(3)
            }
        }

        log.debug("App finished launching")
    }

    @IBAction func openLunarDiagnostics(_: Any) {
        createAndShowWindow("diagnosticsWindowController", controller: &diagnosticsWindowController)
    }

    func applicationWillTerminate(_: Notification) {
        log.info("Going down")

        Defaults[.debug] = false

        if let task = valuesReaderThread {
            lowprioQueue.cancel(timer: task)
        }
    }

    func geolocationFallback() {
        LocationMode.specific.fetchGeolocation()
    }

    internal func locationManager(_ lm: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !Defaults[.manualLocation] else { return }

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
        guard !Defaults[.manualLocation] else { return }

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
        if Defaults[.manualLocation] {
            LocationMode.specific.geolocation = Defaults[.location]
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
        if let splitView = windowController?.window?.contentViewController as? SplitViewController {
            splitView.activeModeButton?.needsDisplay = true
        }
    }

    func adapt() {
        displayController.adaptBrightness()
    }

    func setLightPercent(percent: Int8) {
        guard Defaults[.secure].checkRemainingAdjustments() else { return }
        displayController.disable()
        displayController.setBrightnessPercent(value: percent)
        displayController.setContrastPercent(value: percent)
        log.debug("Setting brightness and contrast to \(percent)%")
    }

    func toggleAudioMuted() {
        displayController.toggleAudioMuted()
    }

    func increaseVolume(
        by amount: Int? = nil,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        currentAudioDisplay _: Bool = true
    ) {
        let amount = amount ?? Defaults[.volumeStep]
        displayController.adjustVolume(by: amount, for: displays, currentDisplay: currentDisplay, currentAudioDisplay: currentDisplay)
    }

    func decreaseVolume(
        by amount: Int? = nil,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        currentAudioDisplay _: Bool = true
    ) {
        let amount = amount ?? Defaults[.volumeStep]
        displayController.adjustVolume(by: -amount, for: displays, currentDisplay: currentDisplay, currentAudioDisplay: currentDisplay)
    }

    func increaseBrightness(by amount: Int? = nil, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        let amount = amount ?? Defaults[.brightnessStep]
        displayController.adjustBrightness(by: amount, for: displays, currentDisplay: currentDisplay)
    }

    func increaseContrast(by amount: Int? = nil, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        let amount = amount ?? Defaults[.contrastStep]
        displayController.adjustContrast(by: amount, for: displays, currentDisplay: currentDisplay)
    }

    func decreaseBrightness(by amount: Int? = nil, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        let amount = amount ?? Defaults[.brightnessStep]
        displayController.adjustBrightness(by: -amount, for: displays, currentDisplay: currentDisplay)
    }

    func decreaseContrast(by amount: Int? = nil, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        let amount = amount ?? Defaults[.contrastStep]
        displayController.adjustContrast(by: -amount, for: displays, currentDisplay: currentDisplay)
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
        increaseBrightness()
    }

    @IBAction func brightnessDown(_: Any) {
        decreaseBrightness()
    }

    @IBAction func contrastUp(_: Any) {
        increaseContrast()
    }

    @IBAction func contrastDown(_: Any) {
        decreaseContrast()
    }

    @IBAction func showPreferencesWindow(sender _: Any?) {
        showWindow()
    }

    @IBAction func buyMeACoffee(_: Any) {
        if let url = URL(string: "https://www.buymeacoffee.com/alin23") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func leaveFeedback(_: Any) {
        if let url = URL(string: "https://alinpanaitiu.com/contact/") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func faq(_: Any) {
        if let url = URL(string: "https://lunar.fyi/faq") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func howDoHotkeysWork(_: Any) {
        if let url = URL(string: "https://lunar.fyi/faq#hotkeys") {
            NSWorkspace.shared.open(url)
        }
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
            fm.createFile(
                atPath: "/usr/local/bin/lunar",
                contents: LUNAR_CLI_SCRIPT.data(using: .utf8),
                attributes: [.posixPermissions: 0o755]
            )
            dialog(message: "Lunar CLI installed", info: "", cancelButton: nil).runModal()
        }
    }
}
