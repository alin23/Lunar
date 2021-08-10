//
//  PopoverButon.swift
//  Lunar
//
//  Created by Alin Panaitiu on 23.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Foundation

// MARK: - SettingsButton

class SettingsButton: PopoverButton<SettingsPopoverController> {
    weak var displayViewController: DisplayViewController? {
        didSet {
            popoverController?.displayViewController = displayViewController
        }
    }

    weak var display: Display? {
        didSet {
            popoverController?.display = display
        }
    }

    override var popoverKey: String {
        "settings"
    }

    override func mouseDown(with event: NSEvent) {
        popoverController?.display = display
        popoverController?.displayViewController = displayViewController
        super.mouseDown(with: event)
    }
}

// MARK: - PopoverButton

class PopoverButton<T: NSViewController>: Button {
    @IBInspectable var showPopover = true

    var popoverKey: String {
        "help"
    }

    var popoverController: T? {
        if !POPOVERS.keys.contains(popoverKey) || POPOVERS[popoverKey]! == nil {
            appDelegate.initPopovers()
        }
        guard let popover = POPOVERS[popoverKey]! else { return nil }
        return popover.contentViewController as? T
    }

    override func mouseDown(with event: NSEvent) {
        if !POPOVERS.keys.contains(popoverKey) || POPOVERS[popoverKey]! == nil {
            appDelegate.initPopovers()
        }
        guard let popover = POPOVERS[popoverKey]!, isEnabled else { return }
        handlePopoverClick(popover, with: event)
    }

    func handlePopoverClick(_ popover: NSPopover, with event: NSEvent) {
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

// MARK: - Button

class Button: NSButton {
    // MARK: Lifecycle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Internal

    var trackingArea: NSTrackingArea!
    var buttonShadow: NSShadow!

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var onClick: (() -> Void)?
    var hover = false

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

        transition(0.1)
        alphaValue = hoverAlpha
        shadow = buttonShadow

        onMouseEnter?()
    }

    override func mouseExited(with _: NSEvent) {
        if !isEnabled { return }
        hover = false

        transition(0.2)
        alphaValue = alpha
        shadow = nil

        onMouseExit?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
