//
//  ModernWindowController.swift
//  Adaptivo
//
//  Created by Alin on 04/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import WAYWindow

class ModernWindowController: NSWindowController {
    
    override func windowDidLoad() {
        if let w = window as? WAYWindow {
            w.titleBarHeight = 40
            w.verticallyCenterTitle = true
            w.centerTrafficLightButtons = true
            w.hidesTitle = true
            w.trafficLightButtonsLeftMargin = 14
            w.trafficLightButtonsTopMargin = 0
            w.hideTitleBarInFullScreen = false
            w.isOpaque = false
            w.backgroundColor = NSColor.clear
        }
        super.windowDidLoad()
    }
    
}
