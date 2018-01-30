//
//  AppDelegate.swift
//  Lunar
//
//  Created by Alin on 30/11/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import CoreLocation
import SwiftyBeaver
import ServiceManagement
import WAYWindow
import HotKey

let log = SwiftyBeaver.self
let brightnessAdapter = BrightnessAdapter()
let datastore = DataStore()
var activity: NSBackgroundActivityScheduler!

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

let toggleHotKey = HotKey(key: .l, modifiers: [.command, .control])
let pauseHotKey = HotKey(key: .k, modifiers: [.command, .control])
let startHotKey = HotKey(key: .k, modifiers: [.command, .control, .shift])
let lunarHotKey = HotKey(key: .l, modifiers: [.command, .control, .shift])

func fadeTransition(duration: TimeInterval) -> CATransition {
    let transition = CATransition()
    transition.duration = duration
    transition.type = kCATransitionFade
    return transition
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate, NSMenuDelegate {
    var locationManager: CLLocationManager!
    var windowController: ModernWindowController?
    var appObserver: NSKeyValueObservation?
    var daylightObserver: NSKeyValueObservation?
    var noonObserver: NSKeyValueObservation?
    var runningAppExceptions: [AppException]!
    @IBOutlet weak var menu: NSMenu!
    @IBOutlet weak var toggleMenuItem: NSMenuItem!
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    
    func menuWillOpen(_ menu: NSMenu) {
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
            self.toggleBrightnessAdapter(sender: nil)
            log.debug("Toggle Hotkey pressed")
        }
        pauseHotKey.keyDownHandler = {
            self.disableBrightnessAdapter()
            log.debug("Pause Hotkey pressed")
        }
        startHotKey.keyDownHandler = {
            self.enableBrightnessAdapter()
            log.debug("Start Hotkey pressed")
        }
        lunarHotKey.keyDownHandler = {
            self.showWindow()
            log.debug("Show Window Hotkey pressed")
        }
    }
    
    func showWindow() {
        if self.windowController == nil {
            self.windowController = NSStoryboard.main?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "windowController")) as? ModernWindowController
        }
        if let windowController = self.windowController,
            let window = windowController.window,
            !window.isVisible {
            windowController.showWindow(nil)
        }
    }
    
    func handleDaemon() {
        let launcherAppId = "com.alinp.LunarService"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = (runningApps.first(where: { app in app.bundleIdentifier == launcherAppId }) != nil)
        
        SMLoginItemSetEnabled(launcherAppId as CFString, true)
        
        if isRunning {
            DistributedNotificationCenter.default().post(
                name: .killLauncher,
                object: Bundle.main.bundleIdentifier!)
        }
    }
    
    func initBrightnessAdapterActivity(interval: TimeInterval) {
        activity = NSBackgroundActivityScheduler(identifier: "com.alinp.Lunar.adaptBrightness")
        activity.repeats = true
        activity.interval = interval
        activity.qualityOfService = .userInitiated
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
            selector: #selector(self.adaptToScreenConfiguration(notification:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
        
    }
    
    func listenForRunningApps() {
        let appNames = NSWorkspace.shared.runningApplications.map({app in app.localizedName ?? ""})
        runningAppExceptions = (try? datastore.fetchAppExceptions(by: appNames)) ?? []
        
        adapt()
        
        appObserver = NSWorkspace.shared.observe(\.runningApplications, options: [.old, .new], changeHandler: {(workspace, change) in
            let oldAppNames = change.oldValue?.map({app in app.localizedName ?? ""})
            let newAppNames = change.newValue?.map({app in app.localizedName ?? ""})
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
    
    @objc func adaptToScreenConfiguration(notification: Notification) {
        brightnessAdapter.resetDisplayList()
        let pageController = (self.windowController?.window?.contentViewController as? SplitViewController)?.childViewControllers[0] as? PageController
        pageController?.setup()
    }
    
    func addObservers() {
        daylightObserver = datastore.defaults.observe(\.daylightExtensionMinutes, changeHandler: {(defaults, change) in
            brightnessAdapter.adaptBrightness()
        })
        noonObserver = datastore.defaults.observe(\.noonDurationMinutes, changeHandler: {(defaults, change) in
            brightnessAdapter.adaptBrightness()
        })
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        initLogger()
        handleDaemon()
        startReceivingSignificantLocationChanges()
        initBrightnessAdapterActivity(interval: 60)
        brightnessAdapter.running = true
        initMenubarIcon()
        initHotkeys()
        listenForScreenConfigurationChanged()
        listenForRunningApps()
        addObservers()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        log.info("Going down")
        datastore.save()
        activity.invalidate()
    }
    
    func geolocationFallback() {
        if brightnessAdapter.geolocation == nil {
            brightnessAdapter.fetchGeolocation()
        }
    }
    
    internal func locationManager(_ manager: CLLocationManager,  didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            brightnessAdapter.geolocation = Geolocation(location: location)
            locationManager.stopMonitoringSignificantLocationChanges()
            log.debug("LocationManager coordinates: \(brightnessAdapter.geolocation.latitude), \(brightnessAdapter.geolocation.longitude)")
            brightnessAdapter.fetchMoments()
        } else {
            geolocationFallback()
        }
    }
    
    internal func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
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
        let splitView = self.windowController?.window?.contentViewController as? SplitViewController
        splitView?.activeStateButton?.setNeedsDisplay()
    }
    
    func adapt() {
        if !runningAppExceptions.isEmpty {
            disableBrightnessAdapter()
            let lastApp = runningAppExceptions.last!
            brightnessAdapter.setBrightness(brightness: lastApp.brightness)
            brightnessAdapter.setContrast(contrast: lastApp.contrast)
        } else {
            enableBrightnessAdapter()
            brightnessAdapter.adaptBrightness()
        }
    }
    
    func disableBrightnessAdapter() {
        brightnessAdapter.running = false
        resetElements()
    }
    
    func enableBrightnessAdapter() {
        brightnessAdapter.running = true
        resetElements()
    }
    
    @IBAction func toggleBrightnessAdapter(sender: Any?) {
        _ = brightnessAdapter.toggle()
        resetElements()
    }
    
    @IBAction func showWindow(sender: Any?) {
        self.showWindow()
    }
}

