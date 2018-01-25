//
//  ModernWindowController.swift
//  Lunar
//
//  Created by Alin on 04/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import WAYWindow

class ModernWindowController: NSWindowController, NSWindowDelegate {
    
    func setupWindow() {
        if let w = window as? WAYWindow {
            w.delegate = self
            w.titleBarHeight = 50
            w.verticallyCenterTitle = true
            w.centerTrafficLightButtons = true
            w.hidesTitle = true
            w.trafficLightButtonsLeftMargin = 20
            w.trafficLightButtonsTopMargin = 0
            w.hideTitleBarInFullScreen = false
            w.isOpaque = false
            w.backgroundColor = NSColor.clear
            w.makeKeyAndOrderFront(nil)
        }
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        setupWindow()
    }
    
    func windowWillClose(_ notification: Notification) {
        log.info("Window closing")
    }
    
}
