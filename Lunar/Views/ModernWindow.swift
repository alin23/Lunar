//
//  ModernWindow.swift
//  Lunar
//
//  Created by Alin on 18/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Carbon.HIToolbox
import Cocoa
import WAYWindow

var navigationHotkeysEnabled = true
var scrollableAdjustHotkeysEnabled = true

class ModernWindow: WAYWindow {
    var pageController: PageController? {
        guard let contentView = contentView,
              !contentView.subviews.isEmpty, !contentView.subviews[0].subviews.isEmpty,
              let controller = contentView.subviews[0].subviews[0].nextResponder as? PageController else { return nil }
        return controller
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        log.verbose("Created window '\(title)'")
    }

    override func mouseDown(with event: NSEvent) {
        for popover in POPOVERS.values {
            popover?.close()
            if let c = popover?.contentViewController as? HelpPopoverController {
                c.onClick = nil
            }
        }
        endEditing(for: nil)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case kVK_Escape.u16:
            undoManager?.undo()
            endEditing(for: nil)
        case kVK_LeftArrow.u16 where navigationHotkeysEnabled && title == "Settings":
            pageController?.navigateBack(nil)
        case kVK_RightArrow.u16 where navigationHotkeysEnabled && title == "Settings":
            pageController?.navigateForward(nil)
        default:
            super.keyDown(with: event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            log.verbose("Precise scroll threshold")
            scrollDeltaYThreshold = PRECISE_SCROLL_Y_THRESHOLD
        } else if event.modifierFlags.contains(.option) {
            log.verbose("Fast scroll threshold")
            scrollDeltaYThreshold = FAST_SCROLL_Y_THRESHOLD
        } else if event.modifierFlags.isDisjoint(with: [.command, .option]) {
            log.verbose("Normal scroll threshold")
            scrollDeltaYThreshold = NORMAL_SCROLL_Y_THRESHOLD
        }
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

    deinit {
        log.verbose("")
    }
}
