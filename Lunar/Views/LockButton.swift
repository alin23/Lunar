//
//  LockButton.swift
//  Lunar
//
//  Created by Alin on 07/08/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

class LockButton: NSButton {
    var lockButtonTrackingArea: NSTrackingArea!

    func setup(_ locked: Bool = false) {
        wantsLayer = true

        let activeTitle = NSMutableAttributedString(attributedString: attributedAlternateTitle)
        activeTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: lockButtonLabelOn, range: NSMakeRange(0, activeTitle.length))
        let inactiveTitle = NSMutableAttributedString(attributedString: attributedTitle)
        inactiveTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: lockButtonLabelOff, range: NSMakeRange(0, inactiveTitle.length))

        attributedTitle = inactiveTitle
        attributedAlternateTitle = activeTitle

        setFrameSize(NSSize(width: frame.width, height: frame.height + 10))
        radius = (frame.height / 2).ns
        if locked {
            state = .on
            bg = lockButtonBgOn
        } else {
            state = .off
            bg = lockButtonBgOff
        }
        lockButtonTrackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(lockButtonTrackingArea)
    }

    override func mouseEntered(with _: NSEvent) {
        layer?.add(fadeTransition(duration: 0.1), forKey: "transition")

        if state == .on {
            bg = lockButtonBgOnHover
        } else {
            bg = lockButtonBgOffHover
        }
    }

    override func mouseExited(with _: NSEvent) {
        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")

        if state == .on {
            bg = lockButtonBgOn
        } else {
            bg = lockButtonBgOff
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
