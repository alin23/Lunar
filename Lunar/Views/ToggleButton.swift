//
//  ToggleButton.swift
//  Lunar
//
//  Created by Alin on 23/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Defaults
import SwiftyAttributes

enum HoverState: Int {
    case hover
    case noHover
}

enum Page: Int {
    case hotkeys
    case settings
    case display
}

class ToggleButton: NSButton {
    var page = Page.display {
        didSet {
            setColors()
        }
    }

    var hoverState = HoverState.noHover
    var bgColor: NSColor {
        if state == .on {
            return onStateButtonColor[hoverState]![page]!
        } else {
            return offStateButtonColor[hoverState]![page]!
        }
    }

    var labelColor: NSColor {
        if state == .on {
            return onStateButtonLabelColor[hoverState]![page]!
        } else {
            return offStateButtonLabelColor[hoverState]![page]!
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func mouseEntered(with _: NSEvent) {
        hover()
    }

    override func mouseExited(with _: NSEvent) {
        defocus()
    }

    func setColors(fadeDuration: TimeInterval = 0.2) {
        layer?.add(fadeTransition(duration: fadeDuration), forKey: "transition")
        layer?.backgroundColor = bgColor.cgColor
        attributedTitle = attributedTitle.string.withAttribute(.textColor(labelColor))
    }

    func fade() {
        setColors()
    }

    func defocus() {
        hoverState = .noHover
        setColors()
    }

    func hover() {
        hoverState = .hover
        setColors(fadeDuration: 0.1)
    }

    func setup() {
        wantsLayer = true

        setFrameSize(NSSize(width: frame.width, height: frame.height + 10))
        layer?.cornerRadius = frame.height / 2
        allowsMixedState = false
        setColors()

        let area = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
