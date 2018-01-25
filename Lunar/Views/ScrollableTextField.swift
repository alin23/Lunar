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
    let growPointSize: CGFloat = 2
    var scrolling: Bool = false
    var onValueChanged: ((Int) -> Void)?
    var centerAlign: NSParagraphStyle?
    var scrolledOnce: Bool = false
    var didScrollTextField: Bool = datastore.defaults.bool(forKey: "didScrollTextField")
    
    var normalSize: CGSize?
    var activeSize: CGSize?
    var normalFont: NSFont?
    var activeFont: NSFont?
    
    let color = #colorLiteral(red: 0.95, green: 0.748125, blue: 0.1425, alpha: 0.7989381602)
    let colorHover = #colorLiteral(red: 1, green: 0.7875, blue: 0.15, alpha: 0.7989381602)
    let colorLight = #colorLiteral(red: 1, green: 0.7733493961, blue: 0.347030403, alpha: 1)
    
    var trackingArea: NSTrackingArea?
    var captionTrackingArea: NSTrackingArea?
    var caption: ScrollableTextFieldCaption! {
        didSet {
            if didScrollTextField {
                return
            }
            if let area = captionTrackingArea {
                self.removeTrackingArea(area)
            }
            captionTrackingArea = NSTrackingArea(rect: self.visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: caption, userInfo: nil)
            self.addTrackingArea(captionTrackingArea!)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        centerAlign = paragraphStyle
        
        self.usesSingleLineMode = false
        self.allowsEditingTextAttributes = true
        super.draw(dirtyRect)
        
        if normalFont == nil {
            normalFont = NSFont(name: (self.font?.fontName)!, size: self.font!.pointSize)
            activeFont = NSFont(name: (self.font?.fontName)!, size: self.font!.pointSize + growPointSize)
        }
        if normalSize == nil {
            normalSize = self.frame.size
            activeSize = NSSize(width: normalSize!.width, height: normalSize!.height + growPointSize)
        }
        if trackingArea == nil {
            trackingArea = NSTrackingArea(rect: dirtyRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
            self.addTrackingArea(trackingArea!)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        self.lightenUp(grow: false, color: colorHover)
    }
    
    override func mouseExited(with event: NSEvent) {
        self.darken(color: self.color)
    }
    
    
    func lightenUp(grow: Bool, color: NSColor) {
        self.layer!.add(fadeTransition(duration: 0.2), forKey: "transition")
        self.textColor = color
//        if let font = activeFont {
//            if grow {
//                self.font = font
//            }
//        }
    }
    
    func darken(color: NSColor) {
        self.layer!.add(fadeTransition(duration: 0.3), forKey: "transition")
        self.textColor = color
//        if let font = normalFont {
//            self.font = font
//        }
    }
    
    func disableScrollHint() {
        if !didScrollTextField {
            didScrollTextField = true
            datastore.defaults.set(true, forKey: "didScrollTextField")
            self.removeTrackingArea(captionTrackingArea!)
            caption.resetText()
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaX) <= 1.0 {
            if event.scrollingDeltaY < 0.0 {
                disableScrollHint()
                if !scrolling {
                    scrolling = true
                    self.lightenUp(grow: true, color: colorLight)
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
                disableScrollHint()
                if !scrolling {
                    scrolling = true
                    self.lightenUp(grow: true, color: colorLight)
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
                    self.darken(color: self.colorHover)
                }
            }
        } else {
            super.scrollWheel(with: event)
        }
    }
}
