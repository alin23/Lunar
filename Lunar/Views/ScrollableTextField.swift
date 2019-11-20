//
//  ScrollableTextField.swift
//  Lunar
//
//  Created by Alin on 24/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Carbon.HIToolbox
import Cocoa
import Magnet

class ScrollableTextField: NSTextField {
    @IBInspectable var lowerLimit: Double = 0.0
    @IBInspectable var upperLimit: Double = 100.0
    @IBInspectable var step: Double = 1.0

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

    var decimalPoints = 0
    override var doubleValue: Double {
        didSet {
            if decimalPoints > 0 {
                stringValue = String(format: "%.\(decimalPoints)f", doubleValue)
            } else {
                stringValue = String(Int(round(doubleValue)))
            }
        }
    }

    let growPointSize: CGFloat = 2
    var hover: Bool = false
    var scrolling: Bool = false
    var disabled: Bool = false

    var onValueChanged: ((Int) -> Void)?
    var onValueChangedInstant: ((Int) -> Void)?
    var onValueChangedDouble: ((Double) -> Void)?
    var onValueChangedInstantDouble: ((Double) -> Void)?

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?

    var centerAlign: NSParagraphStyle?
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
        wantsLayer = true
        layer?.cornerRadius = 8

        normalSize = frame.size
        activeSize = NSSize(width: normalSize!.width, height: normalSize!.height + growPointSize)
        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
        setNeedsDisplay()
    }

    override func textDidBeginEditing(_: Notification) {
        log.debug("Editing text")
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.setupHotkeys(enable: false)
        }
    }

    override func textDidEndEditing(_: Notification) {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.setupHotkeys(enable: true)
        }
        darken(color: textFieldColor)
    }

    override func textShouldEndEditing(_ textObject: NSText) -> Bool {
        if let val = Double(textObject.string), val >= lowerLimit, val <= upperLimit {
            doubleValue = val
            onValueChanged?(integerValue)
            onValueChangedDouble?(doubleValue)
            onValueChangedInstant?(integerValue)
            onValueChangedInstantDouble?(doubleValue)
            return true
        }
        return false
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
        if disabled {
            return
        }
        hover = true
        lightenUp(color: textFieldColorHover)

        log.debug("Unregistering up/down hotkeys")
        HotKeyCenter.shared.unregisterHotKey(with: "increaseValue")
        HotKeyCenter.shared.unregisterHotKey(with: "decreaseValue")

        log.debug("Registering up/down hotkeys")
        upHotkey = Magnet.HotKey(identifier: "increaseValue", keyCombo: KeyCombo(keyCode: kVK_UpArrow, carbonModifiers: 0)!) { _ in
            self.increaseValue()
            self.onValueChanged?(self.integerValue)
            self.onValueChangedDouble?(self.doubleValue)
        }
        downHotkey = Magnet.HotKey(identifier: "decreaseValue", keyCombo: KeyCombo(keyCode: kVK_DownArrow, carbonModifiers: 0)!) { _ in
            self.decreaseValue()
            self.onValueChanged?(self.integerValue)
            self.onValueChangedDouble?(self.doubleValue)
        }
        upHotkey?.register()
        downHotkey?.register()

        onMouseEnter?()
    }

    override func mouseExited(with _: NSEvent) {
        if disabled {
            return
        }
        hover = false
        darken(color: textFieldColor)

        log.debug("Unregistering up/down hotkeys")
        HotKeyCenter.shared.unregisterHotKey(with: "increaseValue")
        HotKeyCenter.shared.unregisterHotKey(with: "decreaseValue")
        upHotkey?.unregister()
        downHotkey?.unregister()
        upHotkey = nil
        downHotkey = nil

        onMouseExit?()
    }

    func lightenUp(color: NSColor) {
        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        textColor = color
    }

    func darken(color: NSColor) {
        layer?.add(fadeTransition(duration: 0.3), forKey: "transition")
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

    func increaseValue() {
        if doubleValue < upperLimit {
            doubleValue += step
            onValueChangedInstant?(integerValue)
            onValueChangedInstantDouble?(doubleValue)
        }
    }

    func decreaseValue() {
        if doubleValue > lowerLimit {
            doubleValue -= step
            onValueChangedInstant?(integerValue)
            onValueChangedInstantDouble?(doubleValue)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaX) <= 3.0 {
            if disabled {
                return
            }
            if event.scrollingDeltaY < 0.0 {
                disableScrollHint()
                if !scrolling {
                    scrolling = true
                    lightenUp(color: textFieldColorLight)
                }
                increaseValue()
            } else if event.scrollingDeltaY > 0.0 {
                disableScrollHint()
                if !scrolling {
                    scrolling = true
                    lightenUp(color: textFieldColorLight)
                }
                decreaseValue()
            } else {
                if scrolling {
                    scrolling = false
                    log.debug("Changed \(caption?.stringValue ?? "") to \(doubleValue)")
                    onValueChanged?(integerValue)
                    onValueChangedDouble?(doubleValue)
                    darken(color: textFieldColorHover)
                }
            }
        } else {
            super.scrollWheel(with: event)
        }
    }
}
