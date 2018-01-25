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
    
    override func draw(_ dirtyRect: NSRect) {
        self.usesSingleLineMode = false
        self.allowsEditingTextAttributes = true
        super.draw(dirtyRect)
        if initialText == nil {
            initialText = self.stringValue
        }
        if initialAlphaValue == nil {
            initialAlphaValue = self.alphaValue
        }
    }
    
    func resetText() {
        self.layer!.add(fadeTransition(duration: 0.3), forKey: "transition")
        self.stringValue = initialText
        self.alphaValue = initialAlphaValue
    }
    
    override func mouseEntered(with event: NSEvent) {
        self.layer!.add(fadeTransition(duration: 0.2), forKey: "transition")
        self.stringValue = "Scroll to change value"
        self.alphaValue = 0.5
    }
    
    override func mouseExited(with event: NSEvent) {
        resetText()
    }
    
    
    
}
