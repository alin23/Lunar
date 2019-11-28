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
import Magnet
import Sentry
import ServiceManagement
import SwiftDate
import WAYWindow

extension Collection where Index: Comparable {
    subscript(back i: Int) -> Iterator.Element {
        let backBy = i + 1
        return self[self.index(self.endIndex, offsetBy: -backBy)]
    }
}

private let kAppleInterfaceThemeChangedNotification = "AppleInterfaceThemeChangedNotification"
private let kAppleInterfaceStyle = "AppleInterfaceStyle"
private let kAppleInterfaceStyleSwitchesAutomatically = "AppleInterfaceStyleSwitchesAutomatically"

let TEST_MODE = false

let LOG_URL = FileManager().urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(appName, isDirectory: true).appendingPathComponent("swiftybeaver.log", isDirectory: false)

let TRANSFER_URL = "https://transfer.sh"
let DEBUG_DATA_HEADERS: HTTPHeaders = [
    "Content-type": "application/octet-stream",
    "Max-Downloads": "2",
    "Max-Days": "5",
]
let LOG_ENCODING_THRESHOLD: UInt64 = 100_000_000 // 100MB
let DIAGNOSTICS_EMAIL_BODY = """
# Diagnostics
DIAGNOSTICS_URL

# Write your issue details below

Was the diagnostics process able to change the brightness on your external monitor(s)?
    # write response here

Mac device where Lunar is installed (Macbook Pro 2019, iMac, Mac Mini, Hackintosh etc.):
    # write response here

Monitor connection to the Mac device (HDMI-to-USB-C, USB-C-to-USB-C, miniDisplayPort-to-DisplayPort etc.):
    # write response here

Using an USB Docking Station or Hub:
    # write yes or no here

Lunar mode used (check it in the top-right corner of the Lunar interface)
    # Sync, Location or Manual

(only if you know how to compile a C program) Does this utility work for you? https://github.com/kfix/ddcctl
    # optional response


Issue description:
    # write a short description of what doesn't work as expected
"""

var lunarDisplayNames = [
    "Moony",
    "Celestial",
    "Lunatic",
    "Solar",
    "Stellar",
    "Apollo",
    "Selene",
    "Auroral",
    "Luna",
]

let launcherAppId = "site.lunarapp.LunarService"
let log = Logger.self
let brightnessAdapter = BrightnessAdapter()
let datastore = DataStore()
var activeDisplay: Display?
var helpPopover = NSPopover()
var menuPopover = NSPopover()
var menuPopoverCloser = DispatchWorkItem {
    menuPopover.close()
}

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

func cap<T: Comparable>(_ number: T, minVal: T, maxVal: T) -> T {
    return max(min(number, maxVal), minVal)
}

var upHotkey: Magnet.HotKey?
var downHotkey: Magnet.HotKey?
var leftHotkey: Magnet.HotKey?
var rightHotkey: Magnet.HotKey?
var thisIsFirstRun = false

func fadeTransition(duration: TimeInterval) -> CATransition {
    let transition = CATransition()
    transition.duration = duration
    transition.type = .fade
    return transition
}

extension String {
    var stripped: String {
        let okayChars = Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890+-=().!_")
        return filter { okayChars.contains($0) }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate, NSMenuDelegate {
    var locationManager: CLLocationManager!
    var windowController: ModernWindowController?
    var brightnessReaderActivity: NSBackgroundActivityScheduler!
    var locationActivity: NSBackgroundActivityScheduler!
    var syncQueue: OperationQueue!
    var syncActivity: NSObjectProtocol!

    var daylightObserver: NSKeyValueObservation?
    var curveFactorObserver: NSKeyValueObservation?
    var noonObserver: NSKeyValueObservation?
    var sunsetObserver: NSKeyValueObservation?
    var sunriseObserver: NSKeyValueObservation?
    var solarNoonObserver: NSKeyValueObservation?
    var brightnessOffsetObserver: NSKeyValueObservation?
    var contrastOffsetObserver: NSKeyValueObservation?
    var adaptiveModeObserver: NSKeyValueObservation?
    var hotkeyObserver: NSKeyValueObservation?
    var loginItemObserver: NSKeyValueObservation?

    var statusButtonTrackingArea: NSTrackingArea?
    var statusItemButtonController: StatusItemButtonController?
    var alamoFireManager: SessionManager?

    @IBOutlet var menu: NSMenu!
    @IBOutlet var preferencesMenuItem: NSMenuItem!
    @IBOutlet var stateMenuItem: NSMenuItem!
    @IBOutlet var toggleMenuItem: NSMenuItem!
    @IBOutlet var debugMenuItem: NSMenuItem!

    @IBOutlet var percent0MenuItem: NSMenuItem!
    @IBOutlet var percent25MenuItem: NSMenuItem!
    @IBOutlet var percent50MenuItem: NSMenuItem!
    @IBOutlet var percent75MenuItem: NSMenuItem!
    @IBOutlet var percent100MenuItem: NSMenuItem!

    @IBOutlet var brightnessUpMenuItem: NSMenuItem!
    @IBOutlet var brightnessDownMenuItem: NSMenuItem!
    @IBOutlet var contrastUpMenuItem: NSMenuItem!
    @IBOutlet var contrastDownMenuItem: NSMenuItem!

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    func menuWillOpen(_: NSMenu) {
        toggleMenuItem.title = AppDelegate.getToggleMenuItemTitle()
        stateMenuItem.title = AppDelegate.getStateMenuItemTitle()
    }

    func initHotkeys() {
        guard let hotkeyConfig: [HotkeyIdentifier: [HotkeyPart: Int]] = datastore.hotkeys() else { return }
        for identifier in HotkeyIdentifier.allCases {
            guard let hotkey = hotkeyConfig[identifier], let keyCode = hotkey[.keyCode], let enabled = hotkey[.enabled], let modifiers = hotkey[.modifiers] else { return }
            if let keyCombo = KeyCombo(keyCode: keyCode, carbonModifiers: modifiers) {
                Hotkey.keys[identifier] = Magnet.HotKey(identifier: identifier.rawValue, keyCombo: keyCombo, target: self, action: Hotkey.handler(identifier: identifier))
                if enabled == 1 {
                    Hotkey.keys[identifier]??.register()
                }
            }
        }
        setKeyEquivalents(hotkeyConfig)
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = datastore.defaults.observe(\.adaptiveBrightnessMode, options: [.old, .new], changeHandler: { _, change in
            guard let mode = change.newValue, let oldMode = change.oldValue, mode != oldMode else {
                return
            }
            brightnessAdapter.mode = AdaptiveMode(rawValue: mode) ?? .location
            self.resetElements()
            self.manageBrightnessAdapterActivity(mode: brightnessAdapter.mode)
        })
    }

    func listenForWindowClose(window: NSWindow) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(notification:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }

    func showWindow() {
        var mainStoryboard: NSStoryboard?
        if #available(OSX 10.13, *) {
            mainStoryboard = NSStoryboard.main
        } else {
            mainStoryboard = NSStoryboard(name: "Main", bundle: nil)
        }

        if windowController == nil {
            windowController = mainStoryboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("windowController")) as? ModernWindowController
        } else if windowController?.window == nil {
            windowController = mainStoryboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("windowController")) as? ModernWindowController
        }

        if let wc = self.windowController {
            wc.showWindow(nil)
            if let window = wc.window {
                window.orderFrontRegardless()
                listenForWindowClose(window: window)
            }
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }

    func handleDaemon() {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains(where: { app in app.bundleIdentifier == launcherAppId })

        SMLoginItemSetEnabled(launcherAppId as CFString, datastore.defaults.startAtLogin)
        loginItemObserver = datastore.defaults.observe(\.startAtLogin, options: [.new], changeHandler: { _, change in
            SMLoginItemSetEnabled(launcherAppId as CFString, change.newValue ?? false)
        })

        if isRunning {
            DistributedNotificationCenter.default().post(
                name: .killLauncher,
                object: Bundle.main.bundleIdentifier!
            )
        }
    }

    func applicationDidResignActive(_: Notification) {
        log.debug("applicationDidResignActive")

        log.debug("Unregistering up/down hotkeys")
        HotKeyCenter.shared.unregisterHotKey(with: "increaseValue")
        HotKeyCenter.shared.unregisterHotKey(with: "decreaseValue")
        upHotkey?.unregister()
        downHotkey?.unregister()
        upHotkey = nil
        downHotkey = nil

        setupHotkeys(enable: false)
    }

    func setupHotkeys(enable: Bool) {
        if let pageController = windowController?.window?.contentView?.subviews[0].subviews[0].nextResponder as? PageController {
            pageController.setupHotkeys(enable: enable)
        }
    }

    func applicationDidBecomeActive(_: Notification) {
        setupHotkeys(enable: true)
    }

    func manageBrightnessAdapterActivity(mode: AdaptiveMode) {
        locationActivity.invalidate()
        if syncActivity != nil {
            ProcessInfo.processInfo.endActivity(syncActivity)
        }

        switch mode {
        case .location:
            log.debug("Started BrightnessAdapter in Location mode")
            brightnessAdapter.adaptBrightness()

            locationActivity.interval = 60
            locationActivity.tolerance = 10
            locationActivity.schedule { completion in
                let displayIDs = brightnessAdapter.displays.values.map { $0.objectID }
                do {
                    let displays = try displayIDs.map { id in try datastore.context.existingObject(with: id) as! Display }
                    brightnessAdapter.adaptBrightness(for: displays)
                } catch {
                    log.error("Error on fetching Displays by IDs")
                }
                completion(NSBackgroundActivityScheduler.Result.finished)
            }
        case .sync:
            log.debug("Started BrightnessAdapter in Sync mode")
            brightnessAdapter.adaptBrightness()
            syncActivity = ProcessInfo.processInfo.beginActivity(options: .background, reason: "Built-in brightness synchronization")
            syncQueue.addOperation {
                while true {
                    if var builtinBrightness = brightnessAdapter.getBuiltinDisplayBrightness(),
                        brightnessAdapter.lastBuiltinBrightness != builtinBrightness {
                        if builtinBrightness == 0 || builtinBrightness == 100, IsLidClosed(),
                            let lastBrightness = brightnessAdapter.builtinBrightnessHistory.last(where: { b in b > 0 && b < 100 }) {
                            builtinBrightness = Double(lastBrightness)
                        }

                        brightnessAdapter.lastBuiltinBrightness = builtinBrightness
                        let displayIDs = brightnessAdapter.displays.values.map { $0.objectID }
                        do {
                            let displays = try displayIDs.map { id in try datastore.context.existingObject(with: id) as! Display }
                            brightnessAdapter.adaptBrightness(for: displays, percent: builtinBrightness)
                        } catch {
                            log.error("Error on fetching Displays by IDs")
                        }
                    }
                    Thread.sleep(forTimeInterval: TimeInterval(datastore.defaults.syncPollingSeconds))
                }
            }
        case .manual:
            log.debug("BrightnessAdapter set to manual")
        }
    }

    func initBrightnessAdapterActivity() {
        brightnessReaderActivity = NSBackgroundActivityScheduler(identifier: "site.lunarapp.Lunar.refreshBrightness")
        brightnessReaderActivity.repeats = true
        brightnessReaderActivity.qualityOfService = .userInitiated
        brightnessReaderActivity.interval = 5
        brightnessReaderActivity.tolerance = 3

        DispatchQueue.global(qos: .userInitiated).async {
            brightnessAdapter.fetchBrightness()
        }

        brightnessReaderActivity.schedule { completion in
            let displayIDs = brightnessAdapter.displays.values.map { $0.objectID }
            do {
                let displays = try displayIDs.map { id in try datastore.context.existingObject(with: id) as! Display }
                brightnessAdapter.fetchBrightness(for: displays)
            } catch {
                log.error("Error on fetching Displays by IDs")
            }
            completion(NSBackgroundActivityScheduler.Result.finished)
        }

        locationActivity = NSBackgroundActivityScheduler(identifier: "site.lunarapp.Lunar.adaptBrightness")
        locationActivity.repeats = true
        locationActivity.qualityOfService = .userInitiated

        syncQueue = OperationQueue()
        manageBrightnessAdapterActivity(mode: brightnessAdapter.mode)
    }

    func initMenubarIcon() {
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("MenubarIcon"))
            button.image?.isTemplate = true

            statusItemButtonController = StatusItemButtonController(button: button)
            statusButtonTrackingArea = NSTrackingArea(rect: button.visibleRect, options: [.mouseEnteredAndExited, .activeAlways], owner: statusItemButtonController, userInfo: nil)
            if let trackingArea = statusButtonTrackingArea {
                button.addTrackingArea(trackingArea)
            }
            button.addSubview(statusItemButtonController!)
        }
        statusItem.menu = menu
        toggleMenuItem.title = AppDelegate.getToggleMenuItemTitle()

        if menuPopover.contentViewController == nil {
            var storyboard: NSStoryboard?
            if #available(OSX 10.13, *) {
                storyboard = NSStoryboard.main
            } else {
                storyboard = NSStoryboard(name: "Main", bundle: nil)
            }

            menuPopover.contentViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("MenuPopoverController")) as! MenuPopoverController
            menuPopover.contentViewController!.loadView()

            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(appleInterfaceThemeChangedNotification(notification:)),
                name: NSNotification.Name(rawValue: kAppleInterfaceThemeChangedNotification),
                object: nil
            )
            adaptAppearance()
        }
    }

    @objc func appleInterfaceThemeChangedNotification(notification _: Notification) {
        adaptAppearance()
    }

    func adaptAppearance() {
        menuPopover.appearance = NSAppearance(named: .vibrantLight)
        if #available(OSX 10.15, *) {
            let appearanceDescription = NSApplication.shared.effectiveAppearance.debugDescription.lowercased()
            if appearanceDescription.contains("dark") {
                menuPopover.appearance = NSAppearance(named: .vibrantDark)
            }

        } else if #available(OSX 10.14, *) {
            if let appleInterfaceStyle = UserDefaults.standard.object(forKey: kAppleInterfaceStyle) as? String {
                if appleInterfaceStyle.lowercased().contains("dark") {
                    menuPopover.appearance = NSAppearance(named: .vibrantDark)
                }
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
    }

    @objc func windowWillClose(notification _: Notification) {
        windowController?.window = nil
        windowController = nil
    }

    @objc func adaptToScreenConfiguration(notification _: Notification) {
        brightnessAdapter.manageClamshellMode()
        brightnessAdapter.resetDisplayList()
        brightnessAdapter.builtinDisplay = DDC.getBuiltinDisplay()
        if let visible = windowController?.window?.isVisible, visible {
            windowController?.close()
            windowController?.window = nil
            windowController = nil
            showWindow()
        }
    }

    func addObservers() {
        sunsetObserver = datastore.defaults.observe(\.sunset, changeHandler: { _, _ in
            if brightnessAdapter.mode == .location {
                brightnessAdapter.adaptBrightness()
            }
        })
        sunriseObserver = datastore.defaults.observe(\.sunrise, changeHandler: { _, _ in
            if brightnessAdapter.mode == .location {
                brightnessAdapter.adaptBrightness()
            }
        })
        solarNoonObserver = datastore.defaults.observe(\.solarNoon, changeHandler: { _, _ in
            if brightnessAdapter.mode == .location {
                brightnessAdapter.adaptBrightness()
            }
        })
        curveFactorObserver = datastore.defaults.observe(\.curveFactor, changeHandler: { _, _ in
            if brightnessAdapter.mode == .location {
                brightnessAdapter.adaptBrightness()
            }
        })
        daylightObserver = datastore.defaults.observe(\.daylightExtensionMinutes, changeHandler: { _, _ in
            if brightnessAdapter.mode == .location {
                brightnessAdapter.adaptBrightness()
            }
        })
        noonObserver = datastore.defaults.observe(\.noonDurationMinutes, changeHandler: { _, _ in
            if brightnessAdapter.mode == .location {
                brightnessAdapter.adaptBrightness()
            }
        })
        brightnessOffsetObserver = datastore.defaults.observe(\.brightnessOffset, changeHandler: { _, _ in
            if brightnessAdapter.mode != .manual {
                brightnessAdapter.adaptBrightness()
            }
        })
        contrastOffsetObserver = datastore.defaults.observe(\.contrastOffset, changeHandler: { _, _ in
            if brightnessAdapter.mode != .manual {
                brightnessAdapter.adaptBrightness()
            }
        })

        hotkeyObserver = datastore.defaults.observe(\.hotkeys, changeHandler: { _, _ in
            if let hotkeys = datastore.hotkeys() {
                self.setKeyEquivalents(hotkeys)
            }
        })
    }

    func setKeyEquivalents(_ hotkeys: [HotkeyIdentifier: [HotkeyPart: Int]]) {
        Hotkey.setKeyEquivalent(.lunar, menuItem: preferencesMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.toggle, menuItem: toggleMenuItem, hotkeys: hotkeys)

        Hotkey.setKeyEquivalent(.percent0, menuItem: percent0MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.percent25, menuItem: percent25MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.percent50, menuItem: percent50MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.percent75, menuItem: percent75MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.percent100, menuItem: percent100MenuItem, hotkeys: hotkeys)

        Hotkey.setKeyEquivalent(.brightnessUp, menuItem: brightnessUpMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.brightnessDown, menuItem: brightnessDownMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.contrastUp, menuItem: contrastUpMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.contrastDown, menuItem: contrastDownMenuItem, hotkeys: hotkeys)

        menu?.update()
    }

    func acquirePrivileges() -> Bool {
        let accessEnabled = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )

        if accessEnabled != true {
            log.warning("You need to enable the event listener in the System Preferences")
        }
        return accessEnabled
    }

    func sendUniqueVisitorHash() {
        guard let serialNumberHash = getSerialNumberHash(),
            let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String),
            let data = "\(serialNumberHash) \(appVersion)".data(using: .utf8, allowLossyConversion: true) else {
            return
        }

        Alamofire.upload(data, to: "https://patchbay.pub/count-lunar-unique-users-anonymously")
    }

    func configureAlamofire() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 24.hours.timeInterval
        configuration.timeoutIntervalForResource = 7.days.timeInterval
        alamoFireManager = Alamofire.SessionManager(configuration: configuration)
    }

    func applicationDidFinishLaunching(_: Notification) {
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        do {
            Client.shared = try Client(dsn: secrets.sentryDSN)
            try Client.shared?.startCrashHandler()
        } catch {
            print("\(error)")
        }
        log.initLogger()

        if let logPath = LOG_URL.path.cString(using: .utf8) {
            log.info("Setting log path to \(LOG_URL.path)")
            setLogPath(logPath, logPath.count)
        }

        handleDaemon()
        startReceivingSignificantLocationChanges()

        initBrightnessAdapterActivity()
        initMenubarIcon()
        initHotkeys()

        listenForAdaptiveModeChange()
        listenForScreenConfigurationChanged()
        brightnessAdapter.listenForRunningApps()

        addObservers()
        if thisIsFirstRun || TEST_MODE {
            showWindow()
        }

        configureAlamofire()
        sendUniqueVisitorHash()
        log.debug("App finished launching")
    }

    func applicationWillTerminate(_: Notification) {
        log.info("Going down")

        datastore.save()
        datastore.defaults.set(false, forKey: "debug")

        locationActivity.invalidate()
        brightnessReaderActivity.invalidate()
    }

    func geolocationFallback() {
        brightnessAdapter.fetchGeolocation()
    }

    internal func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            brightnessAdapter.geolocation = Geolocation(location: location)
            locationManager.stopMonitoringSignificantLocationChanges()
            if brightnessAdapter.geolocation.latitude != 0, brightnessAdapter.geolocation.longitude != 0 {
                log.debug("Zero LocationManager coordinates")
            } else {
                log.debug("Got LocationManager coordinates")
            }
            brightnessAdapter.fetchMoments()
        } else {
            geolocationFallback()
        }
    }

    internal func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        log.error("Location manager failed with error: \(error)")
        geolocationFallback()
    }

    func locationManager(_: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationManager.startMonitoringSignificantLocationChanges()
        case .denied, .restricted:
            log.warning("User has not authorized location services")
            geolocationFallback()
        case .authorizedAlways:
            locationManager.startMonitoringSignificantLocationChanges()
        @unknown default:
            log.error("Unknown location manager status \(status)")
        }
    }

    func startReceivingSignificantLocationChanges() {
        if datastore.defaults.manualLocation {
            brightnessAdapter.geolocation = Geolocation()
            return
        }
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        locationManager.stopUpdatingLocation()

        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            log.warning("Location services are not available")
            geolocationFallback()
            return
        }
    }

    static func getToggleMenuItemTitle() -> String {
        switch brightnessAdapter.mode {
        case .location:
            return "Adapt brightness based on built-in display"
        case .sync:
            return "Disable adaptive brightness"
        case .manual:
            return "Adapt brightness based on location"
        }
    }

    static func getStateMenuItemTitle() -> String {
        switch brightnessAdapter.mode {
        case .location:
            return "☀️ Location Mode"
        case .sync:
            return "💻 Display Sync Mode"
        case .manual:
            return "🖥 Manual Mode"
        }
    }

    func resetElements() {
        toggleMenuItem.title = AppDelegate.getToggleMenuItemTitle()
        if let splitView = windowController?.window?.contentViewController as? SplitViewController {
            splitView.activeStateButton?.setNeedsDisplay()
            splitView.setHelpButtonText()
        }
    }

    func adapt() {
        brightnessAdapter.adaptBrightness()
    }

    func setLightPercent(percent: Int8) {
        brightnessAdapter.disable()
        brightnessAdapter.setBrightnessPercent(value: percent)
        brightnessAdapter.setContrastPercent(value: percent)
        log.debug("Setting brightness and contrast to \(percent)%")
    }

    func increaseBrightness(by amount: Int? = nil) {
        let amount = amount ?? datastore.defaults.brightnessStep
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustBrightness(by: amount)
        } else if brightnessAdapter.mode == .location {
            let newCurveFactor = cap(datastore.defaults.curveFactor - Double(amount) * 0.1, minVal: 0.0, maxVal: 10.0)
            datastore.defaults.set(newCurveFactor, forKey: "curveFactor")
        } else {
            let newBrightnessOffset = cap(datastore.defaults.brightnessOffset + amount * 3, minVal: -100, maxVal: 90)
            datastore.defaults.set(newBrightnessOffset, forKey: "brightnessOffset")
        }
    }

    func increaseContrast(by amount: Int? = nil) {
        let amount = amount ?? datastore.defaults.contrastStep
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustContrast(by: amount)
        } else if brightnessAdapter.mode == .location {
            let newCurveFactor = cap(datastore.defaults.curveFactor - Double(amount) * 0.1, minVal: 0.0, maxVal: 10.0)
            datastore.defaults.set(newCurveFactor, forKey: "curveFactor")
        } else {
            let newContrastOffset = cap(datastore.defaults.contrastOffset + amount * 3, minVal: -100, maxVal: 90)
            datastore.defaults.set(newContrastOffset, forKey: "contrastOffset")
        }
    }

    func decreaseBrightness(by amount: Int? = nil) {
        let amount = amount ?? datastore.defaults.brightnessStep
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustBrightness(by: -amount)
        } else if brightnessAdapter.mode == .location {
            let newCurveFactor = cap(datastore.defaults.curveFactor + Double(amount) * 0.1, minVal: 0.0, maxVal: 10.0)
            datastore.defaults.set(newCurveFactor, forKey: "curveFactor")
        } else {
            let newBrightnessOffset = cap(datastore.defaults.brightnessOffset + -amount * 3, minVal: -100, maxVal: 90)
            datastore.defaults.set(newBrightnessOffset, forKey: "brightnessOffset")
        }
    }

    func decreaseContrast(by amount: Int? = nil) {
        let amount = amount ?? datastore.defaults.contrastStep
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustContrast(by: -amount)
        } else if brightnessAdapter.mode == .location {
            let newCurveFactor = cap(datastore.defaults.curveFactor + Double(amount) * 0.1, minVal: 0.0, maxVal: 10.0)
            datastore.defaults.set(newCurveFactor, forKey: "curveFactor")
        } else {
            let newContrastOffset = cap(datastore.defaults.contrastOffset + -amount * 3, minVal: -100, maxVal: 90)
            datastore.defaults.set(newContrastOffset, forKey: "contrastOffset")
        }
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

    @IBAction func toggleBrightnessAdapter(sender _: Any?) {
        brightnessAdapter.toggle()
    }

    @IBAction func showPreferencesWindow(sender _: Any?) {
        showWindow()
    }

    @IBAction func buyMeACoffee(_: Any) {
        NSWorkspace.shared.open(URL(string: "https://www.buymeacoffee.com/alin23")!)
    }

    @IBAction func leaveFeedback(_: Any) {
        NSWorkspace.shared.open(URL(string: "mailto:alin.panaitiu@gmail.com?Subject=Let%27s%20talk%20about%20Lunar%21")!)
    }

    func failDebugData() {
        if dialog(message: "There's no debug data stored for Lunar", info: "Do you want to send a message to the developer?") {
            NSWorkspace.shared.open(URL(string: "mailto:alin.panaitiu@gmail.com?Subject=Let%27s%20talk%20about%20Lunar%21")!)
        }
    }

    @IBAction func sendDebugData(_: Any) {
        guard dialog(message: "This will run a few diagnostic tests by trying to change the brightness and contrast of all of your external displays", info: "Do you want to continue?") else {
            return
        }

        let oldTitle = debugMenuItem.title
        menu.autoenablesItems = false
        debugMenuItem.isEnabled = false
        debugMenuItem.title = "Diagnosing displays"

        let oldDebugState = datastore.defaults.debug
        let oldSmoothTransitionState = datastore.defaults.smoothTransition
        datastore.defaults.set(true, forKey: "debug")
        datastore.defaults.set(false, forKey: "smoothTransition")

        setDebugMode(1)
        let oldBrightness = [CGDirectDisplayID: NSNumber](uniqueKeysWithValues: brightnessAdapter.displays.map { ($0, $1.brightness) })
        let oldContrast = [CGDirectDisplayID: NSNumber](uniqueKeysWithValues: brightnessAdapter.displays.map { ($0, $1.contrast) })

        brightnessAdapter.resetDisplayList()
        for (id, display) in brightnessAdapter.displays {
            for value in 1 ... 100 {
                display.brightness = NSNumber(value: value)
                display.contrast = NSNumber(value: value)
            }
            if let brightness = oldBrightness[id] {
                for value in stride(from: 100, through: brightness.intValue, by: -1) {
                    display.brightness = NSNumber(value: value)
                }
            }
            if let contrast = oldContrast[id] {
                for value in stride(from: 100, through: contrast.intValue, by: -1) {
                    display.contrast = NSNumber(value: value)
                }
            }
        }

        datastore.defaults.set(oldDebugState, forKey: "debug")
        datastore.defaults.set(oldSmoothTransitionState, forKey: "smoothTransition")

        setDebugMode(0)

        debugMenuItem.title = "Gathering logs"
        guard let sourceString = FileManager().contents(atPath: LOG_URL.path) else {
            failDebugData()
            return
        }

//        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: sourceString.count)
//        let sourceBuffer = sourceString.map { $0 }
//        let algorithm = COMPRESSION_LZ4_RAW

//        debugMenuItem.title = "Compressing logs"
//        let compressedSize = compression_encode_buffer(
//            destinationBuffer, sourceString.count,
//            sourceBuffer, sourceString.count,
//            nil,
//            algorithm
//        )

        var debugData = sourceString
        var mimeType = "text/plain"
        var fileName = "lunar.log"
//        if compressedSize > 0 {
//            let encodedFileURL = LOG_URL.appendingPathExtension("lz4")
//
//            FileManager.default.createFile(
//                atPath: encodedFileURL.path,
//                contents: nil,
//                attributes: nil
//            )
//
//            debugData = NSData(
//                bytesNoCopy: destinationBuffer,
//                length: compressedSize
//            ) as Data
//            mimeType = "application/x-lz4"
//            fileName = "lunar.log.lz4"
//        }

        debugMenuItem.title = "Compressing logs"
        Alamofire.upload(debugData, to: "\(TRANSFER_URL)/\(fileName)", method: .put, headers: DEBUG_DATA_HEADERS).validate(statusCode: 200 ..< 300).responseString(completionHandler: {
            response in
            defer {
                self.menu.autoenablesItems = true
                self.debugMenuItem.title = oldTitle
                self.debugMenuItem.isEnabled = true
            }
            log.info("Got response from transfer.sh", context: response.response)
            if let err = response.error {
                log.error("Debug data upload response error: \(err)")
                self.failDebugData()
                return
            }

            guard let url = response.value, !url.isEmpty,
                let urlEncoded = DIAGNOSTICS_EMAIL_BODY.replacingOccurrences(of: "DIAGNOSTICS_URL", with: url).addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                let subject = "Lunar logs: \(url)".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
                log.error("Debug data upload response empty")
                self.failDebugData()
                return
            }
            log.info("Uploaded logs to \(url)")
            NSWorkspace.shared.open(URL(string: "mailto:alin.panaitiu@gmail.com?subject=\(subject)&body=\(urlEncoded)")!)
        })
    }

    func dialog(message: String, info: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
