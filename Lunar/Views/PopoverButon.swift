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

    var popover: NSPopover? {
        if !POPOVERS.keys.contains(popoverKey) || POPOVERS[popoverKey]! == nil {
            appDelegate!.initPopovers()
        }
        guard let popover = POPOVERS[popoverKey]! else { return nil }
        return popover
    }

    var popoverController: T? {
        popover?.contentViewController as? T
    }

    override func mouseDown(with event: NSEvent) {
        guard let popover = popover, isEnabled else { return }
        handlePopoverClick(popover, with: event)
    }

    func close() {
        popover?.close()
    }

    func open(edge _: NSRectEdge = .maxY) {
        guard let popover = popover, (popover.contentViewController as? T) != nil else {
            return
        }
        popover.show(relativeTo: visibleRect, of: self, preferredEdge: .maxY)
        popover.becomeFirstResponder()
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

// MARK: - NSSize + Comparable

extension NSSize: Comparable {
    var area: CGFloat { width * height }
    public static func < (lhs: CGSize, rhs: CGSize) -> Bool {
        lhs.area < rhs.area
    }
}

// MARK: - Box

class Box: NSBox {
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

    var hover = false

    @IBInspectable var alpha: CGFloat = 0.5 {
        didSet {
            if !hover {
                mainThread {
                    alphaValue = alpha
                }
            }
        }
    }

    @IBInspectable var hoverAlpha: CGFloat = 1.0 {
        didSet {
            if hover {
                mainThread {
                    alphaValue = hoverAlpha
                }
            }
        }
    }

    override var frame: NSRect {
        didSet { trackHover() }
    }

    override var isHidden: Bool {
        didSet { trackHover() }
    }

    func setup() {
        bg = .clear
        alphaValue = alpha

        trackHover()
    }

    override func mouseEntered(with event: NSEvent) {
        if isHidden { return }
        hover = true

        transition(0.2)
        alphaValue = hoverAlpha
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        if isHidden { return }
        hover = false

        transition(0.4)
        alphaValue = alpha
        super.mouseExited(with: event)
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

    var buttonShadow: NSShadow!

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var onClick: (() -> Void)?
    var hover = false

    @IBInspectable var horizontalPadding: CGFloat = 0
    @IBInspectable var verticalPadding: CGFloat = 0

    override var frame: NSRect {
        didSet { trackHover() }
    }

    override var isHidden: Bool {
        didSet { trackHover() }
    }

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += horizontalPadding
        size.height += verticalPadding
        return size
    }

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

    @objc override func trackHover() {
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let size = max(intrinsicContentSize, frame.size)
        let area = NSTrackingArea(
            rect: NSRect(origin: .zero, size: size),
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
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

        trackHover()
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

        transition(0.2)
        alphaValue = hoverAlpha
        shadow = buttonShadow

        onMouseEnter?()
    }

    override func mouseExited(with _: NSEvent) {
        if !isEnabled { return }
        hover = false

        transition(0.4)
        alphaValue = alpha
        shadow = nil

        onMouseExit?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
