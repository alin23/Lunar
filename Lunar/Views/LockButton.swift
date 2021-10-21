//
//  LockButton.swift
//  Lunar
//
//  Created by Alin on 07/08/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

// MARK: - LockButtonCell

class LockButtonCell: NSButtonCell {
    override func _shouldDrawTextWithDisabledAppearance() -> Bool {
        (controlView as! LockButton).grayDisabledText
    }
}

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

    @IBInspectable dynamic var grayDisabledText: Bool = true
    @IBInspectable dynamic var verticalPadding: CGFloat = 0.7

    @IBInspectable dynamic var bgOn: NSColor = lockButtonBgOn
    @IBInspectable dynamic var bgOff: NSColor = lockButtonBgOff

    var bgOnHover: NSColor { bgOn.blended(withFraction: 0.3, of: bgOff) ?? bgOff
        // darkMode ?
        //     bgOn.highlight(withLevel: 0.2) ?? bgOn :
        //     bgOn.highlight(withLevel: 0.2) ?? bgOn
    }

    var bgOffHover: NSColor { bgOff.blended(withFraction: 0.3, of: bgOn) ?? bgOn
        // darkMode ?
        //     bgOn.highlight(withLevel: 0.4) ?? bgOn :
        //     bgOn.highlight(withLevel: 0.4) ?? bgOn
    }

    @IBInspectable dynamic var labelOn: NSColor = lockButtonLabelOn {
        didSet {
            attributedAlternateTitle = attributedAlternateTitle.withTextColor(labelOn)
        }
    }

    @IBInspectable dynamic var labelOff: NSColor = lockButtonLabelOff {
        didSet {
            attributedTitle = attributedTitle.withTextColor(labelOff)
        }
    }

    override var isEnabled: Bool {
        didSet {
            if isEnabled {
                attributedAlternateTitle = attributedAlternateTitle.withTextColor(labelOn)
                attributedTitle = attributedTitle.withTextColor(labelOff)
                bg = state == .on ? bgOn : bgOff
            } else {
                attributedAlternateTitle = attributedAlternateTitle.withTextColor(labelOn.with(alpha: -0.2))
                attributedTitle = attributedTitle.withTextColor(labelOff.with(alpha: -0.2))
                bg = state == .on ? bgOn.with(alpha: -0.2) : bgOff.with(alpha: -0.2)
            }
        }
    }

    override var state: NSControl.StateValue {
        didSet {
            bg = state == .on ? bgOn : bgOff
        }
    }

    @IBInspectable dynamic lazy var cornerRadius: CGFloat = (frame.height / 2) {
        didSet {
            radius = cornerRadius.ns
        }
    }

    override func cursorUpdate(with _: NSEvent) {
        if isEnabled {
            NSCursor.pointingHand.set()
        }
    }

    func setup(_ locked: Bool = false) {
        wantsLayer = true

        attributedTitle = attributedTitle.withTextColor(labelOff)
        attributedAlternateTitle = attributedAlternateTitle.withTextColor(labelOn)

        setFrameSize(NSSize(width: frame.width, height: frame.height + (frame.height * verticalPadding)))
        radius = cornerRadius.ns
        if locked {
            state = .on
            bg = bgOn
        } else {
            state = .off
            bg = bgOff
        }
        trackHover(cursor: true)
    }

    override func mouseEntered(with _: NSEvent) {
        guard isEnabled else { return }
        transition(0.2)

        if state == .on {
            bg = bgOnHover
        } else {
            bg = bgOffHover
        }
    }

    override func mouseExited(with _: NSEvent) {
        guard isEnabled else { return }
        transition(0.4)

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
    override var bgOn: NSColor { get { enableButtonBgOn }
        set {}
    }

    override var bgOff: NSColor { get { enableButtonBgOff }
        set {}
    }

    override var labelOn: NSColor { get { enableButtonLabelOn }
        set {}
    }

    override var labelOff: NSColor { get { enableButtonLabelOff }
        set {}
    }
}
