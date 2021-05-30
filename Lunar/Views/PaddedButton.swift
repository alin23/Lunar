//
//  PaddedButton.swift
//  Lunar
//
//  Created by Alin Panaitiu on 31.03.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa

class PaddedButton: NSButton {
    override var isEnabled: Bool {
        didSet {
            if isEnabled {
                alphaValue = 1.0
            } else {
                alphaValue = 0.7
            }
            fade()
        }
    }

    var hoverState = HoverState.noHover

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

        let area = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(area)
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
        if isEnabled {
            defocus()
        }
    }

    func setColors(fadeDuration: TimeInterval = 0.2) {
        layer?.add(fadeTransition(duration: fadeDuration), forKey: "transition")

        guard let bgColor = bg else { return }
        if hoverState == .hover {
            bg = bgColor.blended(withFraction: 0.2, of: red)

        } else {
            if isEnabled {
                bg = bgColor
            } else {
                bg = (bgColor.blended(withFraction: 0.3, of: gray) ?? bgColor).withAlphaComponent(0.2)
            }
        }
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

    override func draw(_ dirtyRect: NSRect) {
        fade()

        super.draw(dirtyRect)
    }
}
