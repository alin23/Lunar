//
//  PaddedButton.swift
//  Lunar
//
//  Created by Alin Panaitiu on 31.03.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa

let NO_SHADOW: NSShadow = {
    let s = NSShadow()
    s.shadowColor = .clear
    s.shadowOffset = .zero
    s.shadowBlurRadius = 0
    return s
}()

// MARK: - PaddedButton

class PaddedButton: NSButton {
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
    var baseFrame: NSRect!

    lazy var disabledBgColor = (bgColor?.blended(withFraction: 0.3, of: gray) ?? gray).withAlphaComponent(0.2)
    lazy var hoverBgColor = bgColor?.blended(withFraction: 0.2, of: red) ?? bg
    var hoverState = HoverState.noHover

    lazy var bgColor = bg {
        didSet {
            disabledBgColor = (bgColor?.blended(withFraction: 0.3, of: gray) ?? gray).withAlphaComponent(0.2)
            hoverBgColor = bgColor?.blended(withFraction: 0.2, of: red) ?? bg
        }
    }

    override var isEnabled: Bool {
        didSet {
            if isEnabled {
                alphaValue = 1.0
            } else {
                alphaValue = 0.7
            }
            fade(resize: false)
        }
    }

    @IBInspectable var textColor: NSColor? {
        didSet {
            if let color = textColor {
                textColor = color
                attributedTitle = attributedTitle.string.withAttribute(.textColor(color))
            }
        }
    }

    func setup() {
        wantsLayer = true
        if let color = bg {
            bg = color
        }

        setFrameSize(NSSize(width: frame.width, height: frame.height + 10))
        radius = (frame.height / 2).ns
        allowsMixedState = false
        setColors()

        buttonShadow = shadow
        baseFrame = frame
        shadow = NO_SHADOW
        trackHover(cursor: true)
    }

    override func mouseEntered(with _: NSEvent) {
        if isEnabled {
            hover()
        }
    }

    override func mouseExited(with _: NSEvent) {
        if isEnabled {
            defocus()
        }
    }

    func setColors(fadeDuration: TimeInterval = 0.3, resize: Bool = true) {
        transition(fadeDuration)

        guard let bgColor else { return }
        if hoverState == .hover {
            bg = hoverBgColor
            shadow = buttonShadow
            if resize {
                frame = baseFrame.larger(by: 2)
            }
        } else {
            if isEnabled {
                bg = bgColor
            } else {
                bg = disabledBgColor
            }
            shadow = NO_SHADOW
            if resize {
                frame = baseFrame
            }
        }
        needsDisplay = true
    }

    func fade(resize: Bool = true) {
        setColors(resize: resize)
    }

    func defocus() {
        hoverState = .noHover
        setColors()
    }

    func hover() {
        hoverState = .hover
        setColors(fadeDuration: 0.2)
    }

    override func cursorUpdate(with _: NSEvent) {
        if isEnabled {
            NSCursor.pointingHand.set()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        fade(resize: false)

        super.draw(dirtyRect)
    }
}
