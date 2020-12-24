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
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        log.verbose("Creating window")
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }

    override func mouseDown(with event: NSEvent) {
        for popover in POPOVERS.values {
            popover?.close()
            if let c = popover?.contentViewController as? HelpPopoverController {
                c.onClick = nil
            }
        }
        super.mouseDown(with: event)
    }

    func setup() {
        titleBarHeight = 50
        verticallyCenterTitle = true
        centerTrafficLightButtons = true
        hidesTitle = true
        trafficLightButtonsLeftMargin = 20
        trafficLightButtonsTopMargin = 0
        hideTitleBarInFullScreen = false
        if let v = titlebarAccessoryViewControllers[0].parent?.view.subviews[3] {
            v.frame = NSRect(x: 0, y: 0, width: 100, height: v.frame.height)
        }

        setContentBorderThickness(0.0, for: NSRectEdge.minY)
        setAutorecalculatesContentBorderThickness(false, for: NSRectEdge.minY)
        isOpaque = false
        backgroundColor = NSColor.clear
        makeKeyAndOrderFront(self)
        orderFrontRegardless()
    }
}
