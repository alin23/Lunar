//
//  LockButton.swift
//  Lunar
//
//  Created by Alin on 07/08/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

// MARK: - LockButton

class LockButton: NSButton {
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

    @IBInspectable dynamic var verticalPadding: CGFloat = 0.7

    var bgOn: NSColor { lockButtonBgOn }
    var bgOff: NSColor { lockButtonBgOff }
    var bgOnHover: NSColor {
        darkMode ?
            bgOn.highlight(withLevel: 0.2) ?? bgOn :
            bgOn.highlight(withLevel: 0.2) ?? bgOn
    }

    var bgOffHover: NSColor {
        darkMode ?
            bgOn.highlight(withLevel: 0.4) ?? bgOn :
            bgOn.highlight(withLevel: 0.4) ?? bgOn
    }

    var labelOn: NSColor { lockButtonLabelOn }
    var labelOff: NSColor { lockButtonLabelOff }

    override var state: NSControl.StateValue {
        didSet {
            bg = state == .on ? bgOn : bgOff
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    func setup(_ locked: Bool = false) {
        wantsLayer = true

        let activeTitle = NSMutableAttributedString(attributedString: attributedAlternateTitle)
        activeTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: labelOn,
            range: NSMakeRange(0, activeTitle.length)
        )
        let inactiveTitle = NSMutableAttributedString(attributedString: attributedTitle)
        inactiveTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: labelOff,
            range: NSMakeRange(0, inactiveTitle.length)
        )

        attributedTitle = inactiveTitle
        attributedAlternateTitle = activeTitle

        setFrameSize(NSSize(width: frame.width, height: frame.height + (frame.height * verticalPadding)))
        radius = (frame.height / 2).ns
        if locked {
            state = .on
            bg = bgOn
        } else {
            state = .off
            bg = bgOff
        }
        trackHover()
    }

    override func mouseEntered(with _: NSEvent) {
        transition(0.1)

        if state == .on {
            bg = bgOnHover
        } else {
            bg = bgOffHover
        }
    }

    override func mouseExited(with _: NSEvent) {
        transition(0.2)

        if state == .on {
            bg = bgOn
        } else {
            bg = bgOff
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}

// MARK: - EnableButton

class EnableButton: LockButton {
    override var bgOn: NSColor { enableButtonBgOn }
    override var bgOff: NSColor { enableButtonBgOff }
    override var labelOn: NSColor { enableButtonLabelOn }
    override var labelOff: NSColor { enableButtonLabelOff }
}
