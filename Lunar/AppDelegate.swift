//
//  AppDelegate.swift
//  Lunar
//
//  Created by Alin on 30/11/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Carbon.HIToolbox
import Cocoa
import CoreLocation
import Crashlytics
import Fabric
import class HotKey.HotKey
import Magnet
import ServiceManagement
import WAYWindow

extension Collection where Index: Comparable {
    subscript(back i: Int) -> Iterator.Element {
        let backBy = i + 1
        return self[self.index(self.endIndex, offsetBy: -backBy)]
    }
}

let TEST_MODE = false

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

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

func cap<T: Comparable>(_ number: T, minVal: T, maxVal: T) -> T {
    return max(min(number, maxVal), minVal)
}

var upHotkey: HotKey?
var downHotkey: HotKey?
var leftHotkey: HotKey?
var rightHotkey: HotKey?
var thisIsFirstRun = false

func fadeTransition(duration: TimeInterval) -> CATransition {
    let transition = CATransition()
    transition.duration = duration
    transition.type = convertToCATransitionType(convertFromCATransitionType(CATransitionType.fade))
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
    var activity: NSBackgroundActivityScheduler!
    var adapterSyncQueue: OperationQueue!
    var adapterSyncActivity: NSObjectProtocol!

    var daylightObserver: NSKeyValueObservation?
    var noonObserver: NSKeyValueObservation?
    var brightnessOffsetObserver: NSKeyValueObservation?
    var contrastOffsetObserver: NSKeyValueObservation?
    var loginItemObserver: NSKeyValueObservation?
    var adaptiveModeObserver: NSKeyValueObservation?
    var hotkeyObserver: NSKeyValueObservation?

    @IBOutlet var menu: NSMenu!
    @IBOutlet var preferencesMenuItem: NSMenuItem!
    @IBOutlet var stateMenuItem: NSMenuItem!
    @IBOutlet var toggleMenuItem: NSMenuItem!
    @IBOutlet var loginMenuItem: NSMenuItem!

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
        self.setKeyEquivalents(hotkeyConfig)
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

    func setLoginMenuItemState(state: Bool) {
        if state {
            loginMenuItem?.state = .on
        } else {
            loginMenuItem?.state = .off
        }
    }

    func handleDaemon() {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains(where: { app in app.bundleIdentifier == launcherAppId })

        SMLoginItemSetEnabled(launcherAppId as CFString, datastore.defaults.startAtLogin)
        setLoginMenuItemState(state: datastore.defaults.startAtLogin)
        loginItemObserver = datastore.defaults.observe(\.startAtLogin, options: [.new], changeHandler: { _, change in
            SMLoginItemSetEnabled(launcherAppId as CFString, change.newValue ?? false)
            self.setLoginMenuItemState(state: change.newValue ?? false)
        })

        if isRunning {
            DistributedNotificationCenter.default().post(
                name: .killLauncher,
                object: Bundle.main.bundleIdentifier!
            )
        }
    }

    func applicationDidResignActive(_: Notification) {
        upHotkey = nil
        downHotkey = nil
        leftHotkey = nil
        rightHotkey = nil
    }

    func applicationDidBecomeActive(_: Notification) {
        if let pageController = windowController?.window?.contentView?.subviews[0].subviews[0].nextResponder as? PageController {
            pageController.setupHotkeys()
        }
    }

    func manageBrightnessAdapterActivity(mode: AdaptiveMode) {
        activity.invalidate()
        if adapterSyncActivity != nil {
            ProcessInfo.processInfo.endActivity(adapterSyncActivity)
        }

        switch mode {
        case .location:
            log.debug("Started BrightnessAdapter in Location mode")
            activity.interval = 60
            activity.tolerance = 10
            brightnessAdapter.adaptBrightness()
            activity.schedule { completion in
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
            adapterSyncActivity = ProcessInfo.processInfo.beginActivity(options: .background, reason: "Built-in brightness synchronization")
            adapterSyncQueue.addOperation {
                while true {
                    if let builtinBrightness = brightnessAdapter.getBuiltinDisplayBrightness(),
                        brightnessAdapter.lastBuiltinBrightness != builtinBrightness {
                        brightnessAdapter.lastBuiltinBrightness = builtinBrightness
                        let displayIDs = brightnessAdapter.displays.values.map { $0.objectID }
                        do {
                            let displays = try displayIDs.map { id in try datastore.context.existingObject(with: id) as! Display }
                            brightnessAdapter.adaptBrightness(for: displays, percent: builtinBrightness)
                        } catch {
                            log.error("Error on fetching Displays by IDs")
                        }
                    }
                    Thread.sleep(forTimeInterval: 1)
                }
            }
        case .manual:
            log.debug("BrightnessAdapter set to manual")
        }
    }

    func initBrightnessAdapterActivity() {
        activity = NSBackgroundActivityScheduler(identifier: "com.alinp.Lunar.adaptBrightness")
        activity.repeats = true
        activity.qualityOfService = .userInitiated
        adapterSyncQueue = OperationQueue()
        manageBrightnessAdapterActivity(mode: brightnessAdapter.mode)
    }

    func initMenubarIcon() {
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("MenubarIcon"))
            button.image?.isTemplate = true
        }
        statusItem.menu = menu
        toggleMenuItem.title = AppDelegate.getToggleMenuItemTitle()
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
        Hotkey.setKeyEquivalent(.lunar, menuItem: self.preferencesMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.toggle, menuItem: self.toggleMenuItem, hotkeys: hotkeys)

        Hotkey.setKeyEquivalent(.percent0, menuItem: self.percent0MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.percent25, menuItem: self.percent25MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.percent50, menuItem: self.percent50MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.percent75, menuItem: self.percent75MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.percent100, menuItem: self.percent100MenuItem, hotkeys: hotkeys)

        Hotkey.setKeyEquivalent(.brightnessUp, menuItem: self.brightnessUpMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.brightnessDown, menuItem: self.brightnessDownMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.contrastUp, menuItem: self.contrastUpMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.contrastDown, menuItem: self.contrastDownMenuItem, hotkeys: hotkeys)

        self.menu?.update()
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

    func applicationDidFinishLaunching(_: Notification) {
        lunarDisplayNames.shuffle()
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        Fabric.with([Crashlytics.self])
        log.initLogger()
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

        log.debug("App finished launching")
    }

    func applicationWillTerminate(_: Notification) {
        log.info("Going down")
        datastore.save()
        activity.invalidate()
    }

    func geolocationFallback() {
        if brightnessAdapter.geolocation == nil {
            brightnessAdapter.fetchGeolocation()
        }
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
        }
    }

    func startReceivingSignificantLocationChanges() {
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
        let splitView = windowController?.window?.contentViewController as? SplitViewController
        splitView?.activeStateButton?.setNeedsDisplay()
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

    func increaseBrightness(by amount: Int8 = 3) {
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustBrightness(by: amount)
        } else {
            let newBrightnessOffset = cap(datastore.defaults.brightnessOffset + Int(amount * 3), minVal: -100, maxVal: 90)
            datastore.defaults.set(newBrightnessOffset, forKey: "brightnessOffset")
        }
    }

    func increaseContrast(by amount: Int8 = 3) {
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustContrast(by: amount)
        } else {
            let newContrastOffset = cap(datastore.defaults.contrastOffset + Int(amount * 3), minVal: -100, maxVal: 90)
            datastore.defaults.set(newContrastOffset, forKey: "contrastOffset")
        }
    }

    func decreaseBrightness(by amount: Int8 = 3) {
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustBrightness(by: -amount)
        } else {
            let newBrightnessOffset = cap(datastore.defaults.brightnessOffset + Int(-amount * 3), minVal: -100, maxVal: 90)
            datastore.defaults.set(newBrightnessOffset, forKey: "brightnessOffset")
        }
    }

    func decreaseContrast(by amount: Int8 = 3) {
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustContrast(by: -amount)
        } else {
            let newContrastOffset = cap(datastore.defaults.contrastOffset + Int(-amount * 3), minVal: -100, maxVal: 90)
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

    @IBAction func toggleStartAtLogin(sender _: Any?) {
        datastore.defaults.set(!datastore.defaults.startAtLogin, forKey: "startAtLogin")
    }

    @IBAction func showWindow(sender _: Any?) {
        showWindow()
    }

    @IBAction func buyMeACoffee(_: Any) {
        NSWorkspace.shared.open(URL(string: "https://www.buymeacoffee.com/alin23")!)
    }

    @IBAction func leaveFeedback(_: Any) {
        NSWorkspace.shared.open(URL(string: "mailto:alin.panaitiu@gmail.com?Subject=Let%27s%20talk%20about%20Lunar%21")!)
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToCATransitionType(_ input: String) -> CATransitionType {
    return CATransitionType(rawValue: input)
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromCATransitionType(_ input: CATransitionType) -> String {
    return input.rawValue
}
