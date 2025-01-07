//
//  TextButton.swift
//  Lunar
//
//  Created by Alin on 23/05/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa

final class TextButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    @IBInspectable var bgColor: CGColor = NSColor(deviceWhite: 1.0, alpha: 0.25).cgColor
    @IBInspectable var hoverBgColor: CGColor = mauve.withAlphaComponent(0.5).cgColor
    @IBInspectable var clickColor: NSColor = lunarYellow
    @IBInspectable var textColor = mauve.withAlphaComponent(0.4)
    @IBInspectable var hoverTextColor = white

    override func mouseExited(with _: NSEvent) {
        transition(0.4)
        layer?.backgroundColor = bgColor
        setTitleColor(color: textColor)
    }

    override func mouseEntered(with _: NSEvent) {
        transition(0.2)
        layer?.backgroundColor = hoverBgColor
        setTitleColor(color: hoverTextColor)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    func setTitleColor(color: NSColor) {
        let mutableTitle = NSMutableAttributedString(attributedString: NSAttributedString(string: title))
        mutableTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: NSMakeRange(0, mutableTitle.length))
        mutableTitle.setAlignment(alignment, range: NSMakeRange(0, mutableTitle.length))
        attributedTitle = mutableTitle
    }

    func setup() {
        wantsLayer = true

        setFrameSize(NSSize(width: frame.width, height: frame.height + 4))
        radius = (frame.height / 2.0).ns
        layer?.backgroundColor = bgColor

        let mutableTitle = NSMutableAttributedString(attributedString: NSAttributedString(string: title))
        mutableTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: clickColor, range: NSMakeRange(0, mutableTitle.length))
        mutableTitle.setAlignment(alignment, range: NSMakeRange(0, mutableTitle.length))
        attributedAlternateTitle = mutableTitle

        let area = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(area)
    }

}
