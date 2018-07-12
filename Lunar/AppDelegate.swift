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

let toggleHotKey = HotKey(key: .l, modifiers: [.command, .control])
let startHotKey = HotKey(key: .l, modifiers: [.command, .control, .option])
let pauseHotKey = HotKey(key: .l, modifiers: [.command, .control, .option, .shift])
let lunarHotKey = HotKey(key: .l, modifiers: [.command, .option])
let percent0HotKey = HotKey(key: .zero, modifiers: [.command, .control])
let percent25HotKey = HotKey(key: .one, modifiers: [.command, .control])
let percent50HotKey = HotKey(key: .two, modifiers: [.command, .control])
let percent75HotKey = HotKey(key: .three, modifiers: [.command, .control])
let percent100HotKey = HotKey(key: .four, modifiers: [.command, .control])
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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate, NSMenuDelegate {
    var locationManager: CLLocationManager!
    var windowController: ModernWindowController?
    var activity: NSBackgroundActivityScheduler!

    var appObserver: NSKeyValueObservation?
    var daylightObserver: NSKeyValueObservation?
    var noonObserver: NSKeyValueObservation?
    var loginItemObserver: NSKeyValueObservation?
    var adaptiveEnabledObserver: NSKeyValueObservation?

    var runningAppExceptions: [AppException]!
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
    }

    func listenForAdaptiveModeChange() {
        adaptiveEnabledObserver = datastore.defaults.observe(\.adaptiveBrightnessMode, options: [.old, .new], changeHandler: { _, change in
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
        switch mode {
        case .location:
            log.debug("Started BrightnessAdapter in Location mode")
            activity.interval = 60
        case .sync:
            log.debug("Started BrightnessAdapter in Sync mode")
            activity.interval = 2
        case .manual:
            log.debug("BrightnessAdapter set to manual")
        }
        if mode != .manual {
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
        }
    }

    func initBrightnessAdapterActivity() {
        activity = NSBackgroundActivityScheduler(identifier: "com.alinp.Lunar.adaptBrightness")
        activity.repeats = true
        activity.qualityOfService = .userInitiated
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

    func listenForRunningApps() {
        let appNames = NSWorkspace.shared.runningApplications.map({ app in app.bundleIdentifier ?? "" })
        runningAppExceptions = (try? datastore.fetchAppExceptions(by: appNames)) ?? []
        for app in runningAppExceptions {
            app.addObservers()
        }

        adapt()

        appObserver = NSWorkspace.shared.observe(\.runningApplications, options: [.old, .new], changeHandler: { _, change in
            let oldAppNames = change.oldValue?.map({ app in app.bundleIdentifier ?? "" })
            let newAppNames = change.newValue?.map({ app in app.bundleIdentifier ?? "" })
            do {
                if let names = newAppNames {
                    self.runningAppExceptions.append(contentsOf: try datastore.fetchAppExceptions(by: names))
                }
                if let names = oldAppNames {
                    let exceptions = try datastore.fetchAppExceptions(by: names)
                    for exception in exceptions {
                        if let idx = self.runningAppExceptions.index(where: { app in app.name == exception.name }) {
                            self.runningAppExceptions.remove(at: idx)
                        }
                    }
                }
                self.adapt()
            } catch {
                log.error("Error on fetching app exceptions for app names: \(newAppNames ?? [""])")
            }
        })
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
            brightnessAdapter.adaptBrightness()
        })
        noonObserver = datastore.defaults.observe(\.noonDurationMinutes, changeHandler: { _, _ in
            brightnessAdapter.adaptBrightness()
        })
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
        listenForRunningApps()

        addObservers()
        if thisIsFirstRun {
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
        if !runningAppExceptions.isEmpty {
            let lastApp = runningAppExceptions.last!
            brightnessAdapter.adaptBrightness(app: lastApp)
        } else {
            brightnessAdapter.enable()
            brightnessAdapter.adaptBrightness()
        }
    }

    func setLightPercent(percent: Int8) {
        brightnessAdapter.disable()
        brightnessAdapter.setBrightnessPercent(value: percent)
        brightnessAdapter.setContrastPercent(value: percent)
        log.debug("Setting brightness and contrast to \(percent)%")
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

    @IBAction func toggleBrightnessAdapter(sender _: Any?) {
        brightnessAdapter.toggle()
    }

    @IBAction func showWindow(sender _: Any?) {
        showWindow()
    }

    @IBAction func buyMeACoffee(_: Any) {
        NSWorkspace.shared.open(URL(string: "https://www.buymeacoffee.com/alin23")!)
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
