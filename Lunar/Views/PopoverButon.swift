//
//  PopoverButon.swift
//  Lunar
//
//  Created by Alin Panaitiu on 23.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Foundation

class PopoverButton<T: NSViewController>: NSButton {
    var trackingArea: NSTrackingArea!
    var buttonShadow: NSShadow!
    var popoverKey: PopoverKey {
        return .help
    }

    var popoverController: T? {
        guard let popover = POPOVERS[popoverKey]! else { return nil }
        return popover.contentViewController as? T
    }

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var onClick: (() -> Void)?

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

    override func mouseDown(with _: NSEvent) {
        guard let popover = POPOVERS[popoverKey]! else { return }

        if popover.isShown {
            popover.close()
            return
        }

        if (popover.contentViewController as? T) != nil {
            popover.show(relativeTo: visibleRect, of: self, preferredEdge: .maxY)
            popover.becomeFirstResponder()
        }
        onClick?()
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
