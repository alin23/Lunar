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
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        initLogger()
        handleDaemon()
        startReceivingSignificantLocationChanges()
        initBrightnessAdapterActivity(interval: 60)
        brightnessAdapter.running = true
        initMenubarIcon()
        initHotkeys()
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
    
    @IBAction func toggleBrightnessAdapter(sender: Any?) {
        _ = brightnessAdapter.toggle()
        toggleMenuItem.title = AppDelegate.getToggleMenuItemTitle()
        let splitView = self.windowController?.window?.contentViewController as? SplitViewController
        splitView?.activeStateButton?.setNeedsDisplay()
    }
    
    @IBAction func showWindow(sender: Any?) {
        self.showWindow()
    }
}

