//
//  ScrollableTextFieldCaption.swift
//  Lunar
//
//  Created by Alin on 25/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa


class ScrollableTextFieldCaption: NSTextField {
    var didScrollTextField: Bool = datastore.defaults.bool(forKey: "didScrollTextField")
    
    var initialText: String!
    var initialAlphaValue: CGFloat!
    
    func setup() {
        usesSingleLineMode = false
        allowsEditingTextAttributes = true
        textColor = scrollableTextFieldCaptionColor
        initialText = stringValue
        initialAlphaValue = alphaValue
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
    
    func resetText() {
        layer!.add(fadeTransition(duration: 0.3), forKey: "transition")
        stringValue = initialText
        alphaValue = initialAlphaValue
    }
    
    override func mouseEntered(with event: NSEvent) {
        layer!.add(fadeTransition(duration: 0.2), forKey: "transition")
        stringValue = "Scroll to change value"
        alphaValue = 0.5
    }
    
    override func mouseExited(with event: NSEvent) {
        resetText()
    }
    
    
    
}
