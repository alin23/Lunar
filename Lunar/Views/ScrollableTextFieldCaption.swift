//
//  ScrollableTextFieldCaption.swift
//  Lunar
//
//  Created by Alin on 25/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa
import Defaults

class ScrollableTextFieldCaption: NSTextField {
    var didScrollTextField: Bool = Defaults[.didScrollTextField]

    var initialText: String!
    var initialAlphaValue: CGFloat!
    var initialColor: NSColor!

    func setup() {
        usesSingleLineMode = false
        allowsEditingTextAttributes = true
        textColor = scrollableTextFieldCaptionColor
        initialText = stringValue
        initialAlphaValue = alphaValue
        initialColor = textColor
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    func lightenUp(color: NSColor) {
        layer?.add(fadeTransition(duration: 0.15), forKey: "transition")
        textColor = color
    }

    func darken(color: NSColor) {
        layer?.add(fadeTransition(duration: 0.3), forKey: "transition")
        textColor = color
    }

    func resetText() {
        layer?.add(fadeTransition(duration: 0.3), forKey: "transition")
        textColor = initialColor
        stringValue = initialText
        alphaValue = initialAlphaValue
    }

    override func mouseEntered(with _: NSEvent) {
        guard tag == 98 || tag == 99 else { return }
        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
//        stringValue = "Scroll, type or press ↑/↓"
        stringValue = "Scroll or click to edit"
        alphaValue = 0.5
    }

    override func mouseExited(with _: NSEvent) {
        resetText()
    }
}
