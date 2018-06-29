//
//  AppDelegate.swift
//  Lunar
//
//  Created by Alin on 30/11/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import CoreLocation
import HotKey
import Sentry
import ServiceManagement
import SwiftyBeaver
import WAYWindow

let launcherAppId = "com.alinp.LunarService"
let log = SwiftyBeaver.self
let brightnessAdapter = BrightnessAdapter()
let datastore = DataStore()
var activeDisplay: Display?

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

let toggleHotKey = HotKey(key: .l, modifiers: [.command, .control, .option])
let startHotKey = HotKey(key: .l, modifiers: [.command, .control])
let pauseHotKey = HotKey(key: .l, modifiers: [.command, .control, .shift])
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
    @IBOutlet var toggleMenuItem: NSMenuItem!

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    func application(
        application _: NSApplication,
        didFinishLaunchingWithOptions _: [NSObject: AnyObject]?
    ) -> Bool {
        do {
            Client.shared = try Client(dsn: "https://ba8be236fd94466f83fcf732301c8663@sentry.io/1235087")
            try Client.shared?.startCrashHandler()
        } catch let error {
            log.error(error)
        }

        return true
    }

    func menuWillOpen(_: NSMenu) {
        toggleMenuItem.title = AppDelegate.getToggleMenuItemTitle()
    }

    func initLogger() {
        let console = ConsoleDestination()
        let file = FileDestination()

        log.addDestination(console)
        log.addDestination(file)
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
        }
        percent25HotKey.keyDownHandler = {
            self.setLightPercent(percent: 25)
        }
        percent50HotKey.keyDownHandler = {
            self.setLightPercent(percent: 50)
        }
        percent75HotKey.keyDownHandler = {
            self.setLightPercent(percent: 75)
        }
        percent100HotKey.keyDownHandler = {
            self.setLightPercent(percent: 100)
        }
    }

    func listenForAdaptiveEnabled() {
        adaptiveEnabledObserver = datastore.defaults.observe(\.adaptiveBrightnessEnabled, options: [.old, .new], changeHandler: { _, change in
            guard let running = change.newValue, let oldRunning = change.oldValue, running != oldRunning else {
                return
            }
            brightnessAdapter.running = running
            self.resetElements()
            self.manageBrightnessAdapterActivity(start: running)
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
        if windowController == nil {
            windowController = NSStoryboard.main?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("windowController")) as? ModernWindowController
        } else if windowController?.window == nil {
            windowController = NSStoryboard.main?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("windowController")) as? ModernWindowController
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

    func manageBrightnessAdapterActivity(start: Bool) {
        if start {
            log.debug("Started BrightnessAdapter")
            brightnessAdapter.adaptBrightness()
            activity.schedule { completion in
                //                let context = datastore.container.newBackgroundContext()
                let displayIDs = brightnessAdapter.displays.values.map({ $0.objectID })
                do {
                    let displays = try displayIDs.map({ id in (try datastore.context.existingObject(with: id) as! Display) })
                    brightnessAdapter.adaptBrightness(for: displays)
                } catch {
                    log.error("Error on fetching Displays by IDs")
                }
                completion(NSBackgroundActivityScheduler.Result.finished)
            }
        } else {
            log.debug("Paused BrightnessAdapter")
            activity.invalidate()
        }
    }

    func initBrightnessAdapterActivity(interval: TimeInterval) {
        activity = NSBackgroundActivityScheduler(identifier: "com.alinp.Lunar.adaptBrightness")
        activity.repeats = true
        activity.interval = interval
        activity.qualityOfService = .userInitiated
        manageBrightnessAdapterActivity(start: brightnessAdapter.running)
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
        initLogger()
        handleDaemon()
        startReceivingSignificantLocationChanges()

        initBrightnessAdapterActivity(interval: 60)
        initMenubarIcon()
        initHotkeys()

        listenForAdaptiveEnabled()
        listenForScreenConfigurationChanged()
        listenForRunningApps()

        addObservers()
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
            log.debug("LocationManager coordinates: \(brightnessAdapter.geolocation.latitude), \(brightnessAdapter.geolocation.longitude)")
            brightnessAdapter.fetchMoments()
        } else {
            geolocationFallback()
        }
    }

    internal func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        log.error("Location manager failed with error: \(error)")
        geolocationFallback()
    }

    func startReceivingSignificantLocationChanges() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.startMonitoringSignificantLocationChanges()
        let authorizationStatus = CLLocationManager.authorizationStatus()
        guard authorizationStatus == .authorized else {
            log.warning("User has not authorized location services")
            geolocationFallback()
            return
        }

        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            log.warning("Location services are not available")
            geolocationFallback()
            return
        }
    }

    static func getToggleMenuItemTitle() -> String {
        if brightnessAdapter.running {
            return "Pause Lunar"
        } else {
            return "Start Lunar"
        }
    }

    func resetElements() {
        toggleMenuItem.title = AppDelegate.getToggleMenuItemTitle()
        let splitView = windowController?.window?.contentViewController as? SplitViewController
        splitView?.activeStateButton?.setNeedsDisplay()
    }

    func adapt() {
        if !runningAppExceptions.isEmpty {
            brightnessAdapter.disable()
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
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToCATransitionType(_ input: String) -> CATransitionType {
    return CATransitionType(rawValue: input)
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromCATransitionType(_ input: CATransitionType) -> String {
    return input.rawValue
}
