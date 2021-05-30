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
    case hotkeysReset
    case settingsReset
    case displayReset
    case displayBrightnessRange
    case displayAlgorithm
}

class ToggleButton: NSButton {
    var page = Page.display {
        didSet {
            setColors()
        }
    }

    var hoverState = HoverState.noHover
    var bgColor: NSColor {
        if !isEnabled {
            return (offStateButtonColor[hoverState]![page] ?? offStateButtonColor[hoverState]![.display]!).shadow(withLevel: 0.3)!
        } else if state == .on {
            return onStateButtonColor[hoverState]![page] ?? onStateButtonColor[hoverState]![.display]!
        } else {
            return offStateButtonColor[hoverState]![page] ?? offStateButtonColor[hoverState]![.display]!
        }
    }

    var labelColor: NSColor {
        if state == .on {
            return onStateButtonLabelColor[hoverState]![page] ?? offStateButtonLabelColor[hoverState]![.display]!
        } else {
            return offStateButtonLabelColor[hoverState]![page] ?? offStateButtonLabelColor[hoverState]![.display]!
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
        if isEnabled {
            hover()
        }
    }

    override func mouseExited(with _: NSEvent) {
        defocus()
    }

    func setColors(fadeDuration: TimeInterval = 0.2) {
        layer?.add(fadeTransition(duration: fadeDuration), forKey: "transition")
        bg = bgColor
        attributedTitle = attributedTitle.string.withAttribute(.textColor(labelColor))
        attributedAlternateTitle = attributedAlternateTitle.string.withAttribute(.textColor(labelColor))
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
        radius = (frame.height / 2).ns
        allowsMixedState = false
        setColors()

        let area = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
