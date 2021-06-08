//
//  PopoverButon.swift
//  Lunar
//
//  Created by Alin Panaitiu on 23.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Foundation

class SettingsButton: PopoverButton<SettingsPopoverController> {
    weak var display: Display? {
        didSet {
            popoverController?.display = display
        }
    }

    override var popoverKey: PopoverKey {
        .settings
    }

    override func mouseDown(with event: NSEvent) {
        popoverController?.display = display
        super.mouseDown(with: event)
    }
}

class PopoverButton<T: NSViewController>: Button {
    var popoverKey: PopoverKey {
        .help
    }

    var popoverController: T? {
        guard let popover = POPOVERS[popoverKey]! else { return nil }
        return popover.contentViewController as? T
    }

    @IBInspectable var showPopover = true

    override func mouseDown(with event: NSEvent) {
        guard let popover = POPOVERS[popoverKey]!, isEnabled else { return }

        if popover.isShown {
            popover.close()
            return
        }

        guard showPopover else {
            super.mouseDown(with: event)
            return
        }

        if (popover.contentViewController as? T) != nil {
            popover.show(relativeTo: visibleRect, of: self, preferredEdge: .maxY)
            popover.becomeFirstResponder()
        }

        super.mouseDown(with: event)
    }
}

class Button: NSButton {
    @IBInspectable var circle: Bool = true {
        didSet {
            mainThread {
                setShape()
            }
        }
    }

    @IBInspectable var alpha: CGFloat = 0.2 {
        didSet {
            if !hover {
                mainThread {
                    alphaValue = alpha
                }
            }
        }
    }

    @IBInspectable var hoverAlpha: CGFloat = 0.7 {
        didSet {
            if hover {
                mainThread {
                    alphaValue = hoverAlpha
                }
            }
        }
    }

    var trackingArea: NSTrackingArea!
    var buttonShadow: NSShadow!

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var onClick: (() -> Void)?
    var hover = false

    func setShape() {
        mainThread {
            let buttonSize = frame
            if circle, abs(buttonSize.height - buttonSize.width) < 3 {
                setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.width))
                radius = (min(frame.width, frame.height) / 2).ns
            } else if circle {
                radius = (min(frame.width, frame.height) / 2).ns
            } else {
                radius = (min(frame.width, frame.height) / 3).ns
            }
        }
    }

    func setup() {
        wantsLayer = true

        setShape()

        layer?.backgroundColor = .clear
        alphaValue = alpha

        buttonShadow = shadow
        shadow = nil

        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        super.mouseDown(with: event)
    }

    override func mouseEntered(with _: NSEvent) {
        if !isEnabled { return }
        hover = true

        layer?.add(fadeTransition(duration: 0.1), forKey: "transition")
        alphaValue = hoverAlpha
        shadow = buttonShadow

        onMouseEnter?()
    }

    override func mouseExited(with _: NSEvent) {
        if !isEnabled { return }
        hover = false

        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        alphaValue = alpha
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
