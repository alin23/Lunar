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
    
    var trackingArea: NSTrackingArea?
    var captionTrackingArea: NSTrackingArea?
    var caption: ScrollableTextFieldCaption! {
        didSet {
            if didScrollTextField {
                return
            }
            if let area = captionTrackingArea {
                removeTrackingArea(area)
            }
            captionTrackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: caption, userInfo: nil)
            addTrackingArea(captionTrackingArea!)
        }
    }
    
    func setup() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        centerAlign = paragraphStyle
        
        usesSingleLineMode = false
        allowsEditingTextAttributes = true
        textColor = scrollableTextFieldColor
        
        normalSize = frame.size
        activeSize = NSSize(width: normalSize!.width, height: normalSize!.height + growPointSize)
        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
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
    
    override func mouseEntered(with event: NSEvent) {
        self.lightenUp(color: scrollableTextFieldColorHover)
    }
    
    override func mouseExited(with event: NSEvent) {
        self.darken(color: scrollableTextFieldColor)
    }
    
    
    func lightenUp(color: NSColor) {
        layer!.add(fadeTransition(duration: 0.2), forKey: "transition")
        textColor = color
    }
    
    func darken(color: NSColor) {
        layer!.add(fadeTransition(duration: 0.3), forKey: "transition")
        textColor = color
    }
    
    func disableScrollHint() {
        if !didScrollTextField {
            didScrollTextField = true
            datastore.defaults.set(true, forKey: "didScrollTextField")
            removeTrackingArea(captionTrackingArea!)
            caption.resetText()
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaX) <= 1.0 {
            if event.scrollingDeltaY < 0.0 {
                disableScrollHint()
                if !scrolling {
                    scrolling = true
                    lightenUp(color: scrollableTextFieldColorLight)
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
                    lightenUp(color: scrollableTextFieldColorLight)
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
                    darken(color: scrollableTextFieldColorHover)
                }
            }
        } else {
            super.scrollWheel(with: event)
        }
    }
}
