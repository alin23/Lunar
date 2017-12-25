//
//  ScrollableTextField.swift
//  Lunar
//
//  Created by Alin on 24/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class ScrollableTextField: NSTextField {
    @IBInspectable var lowerLimit: Int = 0
    @IBInspectable var upperLimit: Int = 100
    var scrolling: Bool = false
    var onValueChanged: ((Int) -> Void)?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaX) <= 1.0 {
            if event.scrollingDeltaY < 0.0 {
                scrolling = true
                if intValue < upperLimit {
                    intValue += 1
                }
            } else if event.scrollingDeltaY > 0.0 {
                scrolling = true
                if intValue > lowerLimit {
                    intValue -= 1
                }
            } else {
                if scrolling {
                    if let updater = onValueChanged {
                        updater(integerValue)
                    }
                }
                scrolling = false
            }
        } else {
            super.scrollWheel(with: event)
        }
    }
}
