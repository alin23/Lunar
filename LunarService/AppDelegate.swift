//
//  AppDelegate.swift
//  LunarService
//
//  Created by Alin on 03/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import SwiftyBeaver

let log = SwiftyBeaver.self

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
     
    @objc func terminate() {
        NSApp.terminate(nil)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let console = ConsoleDestination()
        let file = FileDestination()
        
        log.addDestination(console)
        log.addDestination(file)
        
        let mainAppIdentifier = "com.alinp.Lunar"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains(where: { app in app.bundleIdentifier == mainAppIdentifier })
        
        if !isRunning {
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(self.terminate),
                name: .killLauncher,
                object: mainAppIdentifier)
            
            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast()
            components.removeLast()
            components.removeLast()
            components.append("MacOS")
            components.append("Lunar")
            
            let newPath = NSString.path(withComponents: components)
            log.debug("Launching \(newPath)")
            
            NSWorkspace.shared.launchApplication(newPath)
        }
        else {
            self.terminate()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    
}

