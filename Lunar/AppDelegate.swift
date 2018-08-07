//
//  AppDelegate.swift
//  Lunar
//
//  Created by Alin on 30/11/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import CoreLocation
import Crashlytics
import Fabric
import HotKey
import ServiceManagement
import WAYWindow

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

let launcherAppId = "com.alinp.LunarService"
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

let toggleHotKey = HotKey(key: .l, modifiers: [.command, .control])
let startHotKey = HotKey(key: .l, modifiers: [.command, .control, .option])
let pauseHotKey = HotKey(key: .l, modifiers: [.command, .control, .option, .shift])
let lunarHotKey = HotKey(key: .l, modifiers: [.command, .option])
let percent0HotKey = HotKey(key: .zero, modifiers: [.command, .control])
let percent25HotKey = HotKey(key: .one, modifiers: [.command, .control])
let percent50HotKey = HotKey(key: .two, modifiers: [.command, .control])
let percent75HotKey = HotKey(key: .three, modifiers: [.command, .control])
let percent100HotKey = HotKey(key: .four, modifiers: [.command, .control])

let preciseBrightnessUpHotKey = HotKey(key: .upArrow, modifiers: [.command, .control, .option])
let preciseBrightnessDownHotKey = HotKey(key: .downArrow, modifiers: [.command, .control, .option])
let preciseContrastUpHotKey = HotKey(key: .upArrow, modifiers: [.command, .control, .option, .shift])
let preciseContrastDownHotKey = HotKey(key: .downArrow, modifiers: [.command, .control, .option, .shift])

let brightnessUpHotKey = HotKey(key: .f2, modifiers: [.control])
let brightnessDownHotKey = HotKey(key: .f1, modifiers: [.control])
let contrastUpHotKey = HotKey(key: .f2, modifiers: [.control, .shift])
let contrastDownHotKey = HotKey(key: .f1, modifiers: [.control, .shift])

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

    @IBOutlet var menu: NSMenu!
    @IBOutlet var stateMenuItem: NSMenuItem!
    @IBOutlet var toggleMenuItem: NSMenuItem!

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    func menuWillOpen(_: NSMenu) {
        toggleMenuItem.title = AppDelegate.getToggleMenuItemTitle()
        stateMenuItem.title = AppDelegate.getStateMenuItemTitle()
    }

    func initHotkeys() {
        toggleHotKey.keyDownHandler = {
            brightnessAdapter.toggle()
            log.debug("Toggle Hotkey pressed")
        }
        pauseHotKey.keyDownHandler = {
            brightnessAdapter.disable()
            log.debug("Pause Hotkey pressed")
        }
        startHotKey.keyDownHandler = {
            brightnessAdapter.enable()
            log.debug("Start Hotkey pressed")
        }
        lunarHotKey.keyDownHandler = {
            self.showWindow()
            log.debug("Show Window Hotkey pressed")
        }
        percent0HotKey.keyDownHandler = {
            self.setLightPercent(percent: 0)
            log.debug("0% Hotkey pressed")
        }
        percent25HotKey.keyDownHandler = {
            self.setLightPercent(percent: 25)
            log.debug("25% Hotkey pressed")
        }
        percent50HotKey.keyDownHandler = {
            self.setLightPercent(percent: 50)
            log.debug("50% Hotkey pressed")
        }
        percent75HotKey.keyDownHandler = {
            self.setLightPercent(percent: 75)
            log.debug("75% Hotkey pressed")
        }
        percent100HotKey.keyDownHandler = {
            self.setLightPercent(percent: 100)
            log.debug("100% Hotkey pressed")
        }

        brightnessUpHotKey.keyDownHandler = {
            self.increaseBrightness()
        }
        brightnessDownHotKey.keyDownHandler = {
            self.decreaseBrightness()
        }
        contrastUpHotKey.keyDownHandler = {
            self.increaseContrast()
        }
        contrastDownHotKey.keyDownHandler = {
            self.decreaseContrast()
        }

        preciseBrightnessUpHotKey.keyDownHandler = {
            self.increaseBrightness(by: 1)
        }
        preciseBrightnessDownHotKey.keyDownHandler = {
            self.decreaseBrightness(by: 1)
        }
        preciseContrastUpHotKey.keyDownHandler = {
            self.increaseContrast(by: 1)
        }
        preciseContrastDownHotKey.keyDownHandler = {
            self.decreaseContrast(by: 1)
        }
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
                let displayIDs = brightnessAdapter.displays.values.map({ $0.objectID })
                do {
                    let displays = try displayIDs.map({ id in (try datastore.context.existingObject(with: id) as! Display) })
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
                        let displayIDs = brightnessAdapter.displays.values.map({ $0.objectID })
                        do {
                            let displays = try displayIDs.map({ id in (try datastore.context.existingObject(with: id) as! Display) })
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
        if brightnessAdapter.displays.isEmpty && brightnessAdapter.mode != .manual {
            brightnessAdapter.disable()
        } else {
            brightnessAdapter.enable()
        }
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
        if thisIsFirstRun {
            showWindow()
        }
        if brightnessAdapter.displays.isEmpty {
            brightnessAdapter.disable()
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
            if brightnessAdapter.geolocation.latitude != 0 && brightnessAdapter.geolocation.longitude != 0 {
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

    private func increaseBrightness(by amount: Int8 = 3) {
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustBrightness(by: amount)
        } else {
            let newBrightnessOffset = cap(datastore.defaults.brightnessOffset + Int(amount * 3), minVal: -100, maxVal: 90)
            datastore.defaults.set(newBrightnessOffset, forKey: "brightnessOffset")
        }
    }

    private func increaseContrast(by amount: Int8 = 3) {
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustContrast(by: amount)
        } else {
            let newContrastOffset = cap(datastore.defaults.contrastOffset + Int(amount * 3), minVal: -100, maxVal: 90)
            datastore.defaults.set(newContrastOffset, forKey: "contrastOffset")
        }
    }

    private func decreaseBrightness(by amount: Int8 = 3) {
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustBrightness(by: -amount)
        } else {
            let newBrightnessOffset = cap(datastore.defaults.brightnessOffset + Int(-amount * 3), minVal: -100, maxVal: 90)
            datastore.defaults.set(newBrightnessOffset, forKey: "brightnessOffset")
        }
    }

    private func decreaseContrast(by amount: Int8 = 3) {
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
fileprivate func convertToCATransitionType(_ input: String) -> CATransitionType {
    return CATransitionType(rawValue: input)
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromCATransitionType(_ input: CATransitionType) -> String {
    return input.rawValue
}
