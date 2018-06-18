//
//  ModernWindow.swift
//  Lunar
//
//  Created by Alin on 18/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa
import WAYWindow

class ModernWindow: WAYWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }

    func setup() {
        titleBarHeight = 50
        verticallyCenterTitle = true
        centerTrafficLightButtons = true
        hidesTitle = true
        trafficLightButtonsLeftMargin = 20
        trafficLightButtonsTopMargin = 0
        hideTitleBarInFullScreen = false
        setContentBorderThickness(0.0, for: NSRectEdge.minY)
        setAutorecalculatesContentBorderThickness(false, for: NSRectEdge.minY)
        isOpaque = false
        backgroundColor = NSColor.clear
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }
}
