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

let log = SwiftyBeaver.self
let brightnessAdapter = BrightnessAdapter()
let datastore = DataStore()
var activity: NSBackgroundActivityScheduler!

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate, NSMenuDelegate {
    var locationManager: CLLocationManager!
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
    }
}

