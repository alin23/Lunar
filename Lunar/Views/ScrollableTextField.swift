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
    var centerAlign: NSParagraphStyle?
    var scrolledOnce: Bool = false
    
    override func draw(_ dirtyRect: NSRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        centerAlign = paragraphStyle
        
        self.darken()
        self.usesSingleLineMode = false
        self.allowsEditingTextAttributes = true
        super.draw(dirtyRect)
    }
    
    func lightenUp() {
        self.attributedStringValue = NSAttributedString(string: stringValue, attributes: [.foregroundColor: #colorLiteral(red: 1, green: 0.8352941275, blue: 0.5254902244, alpha: 1), .paragraphStyle: centerAlign!])
        self.font = NSFont(name: (self.font?.fontName)!, size: 54)
    }
    
    func darken() {
        self.attributedStringValue = NSAttributedString(string: stringValue, attributes: [.foregroundColor: #colorLiteral(red: 0.1024531499, green: 0.05745264143, blue: 0.1409771144, alpha: 0.6786421655), .paragraphStyle: centerAlign!])
        self.font = NSFont(name: (self.font?.fontName)!, size: 48)
    }
    
    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaX) <= 1.0 {
            if event.scrollingDeltaY < 0.0 {
                if !scrolling {
                    scrolling = true
                    self.lightenUp()
                }
                if intValue < upperLimit {
                    if scrolledOnce {
                        intValue += 1
                        scrolledOnce = false
                    } else {
                        scrolledOnce = true
                    }
                }
            } else if event.scrollingDeltaY > 0.0 {
                if !scrolling {
                    scrolling = true
                    self.lightenUp()
                }
                if intValue > lowerLimit {
                    if scrolledOnce {
                        intValue -= 1
                        scrolledOnce = false
                    } else {
                        scrolledOnce = true
                    }
                }
            } else {
                if scrolling {
                    scrolling = false
                    scrolledOnce = false
                    if let updater = onValueChanged {
                        updater(integerValue)
                    }
                    self.darken()
                }
            }
        } else {
            super.scrollWheel(with: event)
        }
    }
}
