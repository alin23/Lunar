//
//  ScrollableTextField.swift
//  Lunar
//
//  Created by Alin on 24/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import HotKey

class ScrollableTextField: NSTextField {
    @IBInspectable var lowerLimit: Int = 0
    @IBInspectable var upperLimit: Int = 100

    @IBInspectable var textFieldColor: NSColor = scrollableTextFieldColor {
        didSet {
            if !hover {
                textColor = textFieldColor
            }
        }
    }

    @IBInspectable var textFieldColorHover: NSColor = scrollableTextFieldColorHover {
        didSet {
            if hover {
                textColor = textFieldColorHover
            }
        }
    }

    @IBInspectable var textFieldColorLight: NSColor = scrollableTextFieldColorLight

    let growPointSize: CGFloat = 2
    var hover: Bool = false
    var scrolling: Bool = false

    var onValueChanged: ((Int) -> Void)?
    var onValueChangedInstant: ((Int) -> Void)?

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?

    var centerAlign: NSParagraphStyle?
    var scrolledOnce: Bool = false
    var didScrollTextField: Bool = datastore.defaults.didScrollTextField

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
        textColor = textFieldColor

        normalSize = frame.size
        activeSize = NSSize(width: normalSize!.width, height: normalSize!.height + growPointSize)
        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
        setNeedsDisplay()
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

    override func mouseEntered(with _: NSEvent) {
        hover = true
        lightenUp(color: textFieldColorHover)
        upHotkey = HotKey(
            key: .upArrow,
            modifiers: [],
            keyDownHandler: {
                if self.intValue < self.upperLimit {
                    self.intValue += 1
                    self.onValueChangedInstant?(self.integerValue)
                }
            },
            keyUpHandler: {
                self.onValueChanged?(self.integerValue)
            }
        )
        downHotkey = HotKey(
            key: .downArrow,
            modifiers: [],
            keyDownHandler: {
                if self.intValue > self.lowerLimit {
                    self.intValue -= 1
                    self.onValueChangedInstant?(self.integerValue)
                }
            },
            keyUpHandler: {
                self.onValueChanged?(self.integerValue)
            }
        )
        onMouseEnter?()
    }

    override func mouseExited(with _: NSEvent) {
        hover = false
        darken(color: textFieldColor)
        upHotkey = nil
        downHotkey = nil
        onMouseExit?()
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
            if let area = captionTrackingArea {
                removeTrackingArea(area)
            }
            caption?.resetText()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaX) <= 1.0 {
            if event.scrollingDeltaY < 0.0 {
                disableScrollHint()
                if !scrolling {
                    scrolling = true
                    lightenUp(color: textFieldColorLight)
                }
                if intValue < upperLimit {
                    if scrolledOnce {
                        intValue += 1
                        onValueChangedInstant?(integerValue)
                        scrolledOnce = false
                    } else {
                        scrolledOnce = true
                    }
                }
            } else if event.scrollingDeltaY > 0.0 {
                disableScrollHint()
                if !scrolling {
                    scrolling = true
                    lightenUp(color: textFieldColorLight)
                }
                if intValue > lowerLimit {
                    if scrolledOnce {
                        intValue -= 1
                        onValueChangedInstant?(integerValue)
                        scrolledOnce = false
                    } else {
                        scrolledOnce = true
                    }
                }
            } else {
                if scrolling {
                    scrolling = false
                    scrolledOnce = false
                    onValueChanged?(integerValue)
                    darken(color: textFieldColorHover)
                }
            }
        } else {
            super.scrollWheel(with: event)
        }
    }
}
