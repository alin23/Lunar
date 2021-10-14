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

    var didScrollTextField: Bool = CachedDefaults[.didScrollTextField]

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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    func lightenUp(color: NSColor) {
        transition(0.2)
        textColor = color
    }

    func darken(color: NSColor) {
        transition(0.4)
        textColor = color
    }

    func resetText() {
        transition(0.3)
        textColor = initialColor
        stringValue = initialText
        alphaValue = initialAlphaValue
    }

    override func mouseEntered(with _: NSEvent) {
        guard tag == 98 || tag == 99 else { return }
        transition(0.2)
//        stringValue = "Scroll, type or press ↑/↓"
        stringValue = "Scroll or click to edit"
        alphaValue = 0.5
    }

    override func mouseExited(with _: NSEvent) {
        resetText()
    }
}
