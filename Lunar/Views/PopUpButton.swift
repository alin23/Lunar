//
//  PopUpButton.swift
//  Lunar
//
//  Created by Alin on 23/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Defaults
import SwiftyAttributes

// MARK: - PopUpButtonCell

class PopUpButtonCell: NSPopUpButtonCell {
    var textColor: NSColor?
    var dotColor: NSColor?

    override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
        if let color = textColor {
            let title = title.withAttribute(.textColor(color))
            if let dotColor = dotColor, let font = NSFont(name: "HiraKakuProN-W3", size: 11.0) {
                title.addAttributes([.font(font), .textColor(dotColor)], range: 0 ..< 3)
            }
            return super.drawTitle(title, withFrame: frame, in: controlView)
        } else {
            return super.drawTitle(title, withFrame: frame, in: controlView)
        }
    }
}

// MARK: - PopUpButton

class PopUpButton: NSPopUpButton {
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

    var hoverState = HoverState.noHover

    var page = Page.display {
        didSet {
            setColors()
        }
    }

    var bgColor: NSColor {
        if state == .off {
            return onStateButtonColor[hoverState]![page] ?? onStateButtonColor[hoverState]![.display]!
        } else {
            return offStateButtonColor[hoverState]![page] ?? offStateButtonColor[hoverState]![.display]!
        }
    }

    var labelColor: NSColor {
        if state == .off {
            return onStateButtonLabelColor[hoverState]![page] ?? offStateButtonLabelColor[hoverState]![.display]!
        } else {
            return offStateButtonLabelColor[hoverState]![page] ?? offStateButtonLabelColor[hoverState]![.display]!
        }
    }

    func dotColor(modeKey: AdaptiveModeKey? = nil, overrideMode: Bool? = nil) -> NSColor {
        if overrideMode ?? CachedDefaults[.overrideAdaptiveMode] {
            return buttonDotColor[modeKey ?? displayController.adaptiveModeKey]!
        } else {
            return darkMauve
        }
    }

    override func mouseEntered(with _: NSEvent) {
        hover()
    }

    override func mouseExited(with _: NSEvent) {
        defocus()
    }

    func setColors(fadeDuration: TimeInterval = 0.2, modeKey: AdaptiveModeKey? = nil) {
        if let cell = cell as? PopUpButtonCell {
            cell.textColor = labelColor
            cell.dotColor = dotColor(modeKey: modeKey)
        }
        layer?.add(fadeTransition(duration: fadeDuration), forKey: "transition")
        bg = bgColor

        let title = attributedTitle.withAttribute(.textColor(labelColor))
        title.addAttributes([.textColor(dotColor(modeKey: modeKey))], range: 0 ..< 2)
        attributedTitle = title

        attributedAlternateTitle = attributedAlternateTitle.string.withAttribute(.textColor(labelColor))
    }

    func resizeToFitTitle() {
        let width = sizeThatFits(attributedTitle.size()).width + 16

        let x: CGFloat
        if width > frame.width {
            x = frame.minX - (width - frame.width) / 2
        } else {
            x = frame.minX + (frame.width - width) / 2
        }
        setFrameOrigin(NSPoint(x: x, y: frame.minY))

        setFrameSize(NSSize(width: width, height: frame.height))
    }

    func fade(modeKey: AdaptiveModeKey? = nil) {
        mainThread {
            setColors(modeKey: modeKey)
            resizeToFitTitle()
        }
    }

    func defocus() {
        mainThread {
            hoverState = .noHover
            setColors()
        }
    }

    func hover() {
        mainThread {
            hoverState = .hover
            setColors(fadeDuration: 0.1)
        }
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
