//
//  HelpButton.swift
//  Lunar
//
//  Created by Alin on 14/06/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa

class PageButton: NSButton {
    var trackingArea: NSTrackingArea!
    var buttonShadow: NSShadow!

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?

    func disable() {
        layer?.add(fadeTransition(duration: 0.1), forKey: "transition")

        isHidden = true
        isEnabled = false
        alphaValue = 0.0
    }

    func enable(color: NSColor? = nil) {
        layer?.add(fadeTransition(duration: 0.1), forKey: "transition")

        isHidden = false
        isEnabled = true
        if alphaValue == 0.0 {
            alphaValue = 0.2
        }

        if #available(OSX 10.14, *) {
            contentTintColor = color
        } else {
            // Fallback on earlier versions
        }
    }

    func setup() {
        let buttonSize = frame
        wantsLayer = true

        setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.width))
        layer?.cornerRadius = frame.width / 2
        layer?.backgroundColor = .clear
        alphaValue = 0.2

        buttonShadow = shadow
        shadow = nil

        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with _: NSEvent) {
        if !isEnabled { return }

        layer?.add(fadeTransition(duration: 0.1), forKey: "transition")
        alphaValue = 0.7
        shadow = buttonShadow

        onMouseEnter?()
    }

    override func mouseExited(with _: NSEvent) {
        if !isEnabled { return }

        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        alphaValue = 0.2
        shadow = nil

        onMouseExit?()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
