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
        layer?.cornerRadius = frame.height / 2
        if locked {
            state = .on
            layer?.backgroundColor = lockButtonBgOn.cgColor
        } else {
            state = .off
            layer?.backgroundColor = lockButtonBgOff.cgColor
        }
        lockButtonTrackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(lockButtonTrackingArea)
    }

    override func mouseEntered(with _: NSEvent) {
        layer?.add(fadeTransition(duration: 0.1), forKey: "transition")

        if state == .on {
            layer?.backgroundColor = lockButtonBgOnHover.cgColor
        } else {
            layer?.backgroundColor = lockButtonBgOffHover.cgColor
        }
    }

    override func mouseExited(with _: NSEvent) {
        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")

        if state == .on {
            layer?.backgroundColor = lockButtonBgOn.cgColor
        } else {
            layer?.backgroundColor = lockButtonBgOff.cgColor
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
