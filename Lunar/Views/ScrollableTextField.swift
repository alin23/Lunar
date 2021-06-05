//
//  ScrollableTextField.swift
//  Lunar
//
//  Created by Alin on 24/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import AtomicWrite
import Carbon.HIToolbox
import Cocoa
import Defaults
import Magnet

let PRECISE_SCROLL_Y_THRESHOLD: CGFloat = 25.0
let NORMAL_SCROLL_Y_THRESHOLD: CGFloat = 9.0
let FAST_SCROLL_Y_THRESHOLD: CGFloat = 2.0

var scrollDeltaYThreshold: CGFloat = NORMAL_SCROLL_Y_THRESHOLD

class ScrollableTextField: NSTextField, NSTextFieldDelegate {
    @IBInspectable var lowerLimit: Double = 0.0
    @IBInspectable var upperLimit: Double = 100.0
    @IBInspectable var step: Double = 1.0

    @IBInspectable var bgColor: NSColor = .clear {
        didSet {
            if !hover {
                textColor = textFieldColor
            }
        }
    }

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
                stringValue = String(round(doubleValue).i)
            }
        }
    }

    let growPointSize: CGFloat = 2
    var hover: Bool = false
    var scrolling: Bool = false

    var onValueChanged: ((Int) -> Void)?
    var onValueChangedInstant: ((Int) -> Void)?
    var onValueChangedDouble: ((Double) -> Void)?
    var onValueChangedInstantDouble: ((Double) -> Void)?

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?

    var centerAlign: NSParagraphStyle?
    var didScrollTextField: Bool = Defaults[.didScrollTextField]

    var normalSize: CGSize?
    var activeSize: CGSize?

    var scrolledY: CGFloat = 0.0

    var trackingArea: NSTrackingArea?
    var captionTrackingArea: NSTrackingArea?
    weak var caption: ScrollableTextFieldCaption? {
        didSet {
            if didScrollTextField {
                return
            }
            if let area = captionTrackingArea {
                removeTrackingArea(area)
            }
            captionTrackingArea = NSTrackingArea(
                rect: visibleRect,
                options: [.mouseEnteredAndExited, .activeInActiveApp],
                owner: caption,
                userInfo: nil
            )
            addTrackingArea(captionTrackingArea!)
        }
    }

    var adaptToScrollingFinished: DispatchWorkItem?

    override func becomeFirstResponder() -> Bool {
        refusesFirstResponder = false
        let success = super.becomeFirstResponder()

        if let editor = currentEditor() as? NSTextView {
            editor.selectedTextAttributes[.backgroundColor] = darkMauve.withAlphaComponent(0.05)
            editor.insertionPointColor = darkMauve
            if let fieldEditor = editor.window?.fieldEditor(true, for: self) as? NSTextView {
                fieldEditor.insertionPointColor = darkMauve
            }
        }
        return success
    }

    func setup() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        centerAlign = paragraphStyle

        usesSingleLineMode = false
        allowsEditingTextAttributes = true
        textColor = textFieldColor
        radius = 8.ns
        delegate = self
        focusRingType = .none

        normalSize = frame.size
        activeSize = NSSize(width: normalSize!.width, height: normalSize!.height + growPointSize)
        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
        needsDisplay = true
    }

    override func cancelOperation(_: Any?) {
        darken(color: textFieldColor)
        abortEditing()
    }

    override func textDidBeginEditing(_ notification: Notification) {
        if let editor = currentEditor() as? NSTextView {
            editor.selectedTextAttributes[.backgroundColor] = darkMauve.withAlphaComponent(0.05)
        }
        log.verbose("Editing text \(stringValue)")
        super.textDidBeginEditing(notification)
    }

    override func textDidEndEditing(_ notification: Notification) {
        log.verbose("Finished editing text \(stringValue)")
        darken(color: textFieldColor)
        super.textDidEndEditing(notification)
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

    func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(insertNewline(_:)):
            validateEditing()
            if let editor = currentEditor(), textShouldEndEditing(editor) {
                endEditing(editor)
            }
            return true
        case #selector(moveUp(_:))
            where scrollableAdjustHotkeysEnabled && window != nil &&
            (window!.title == "Settings" || (window!.parent != nil && window!.parent!.title == "Settings")):
            increaseValue()
            onValueChanged?(integerValue)
            onValueChangedDouble?(doubleValue)
            return true
        case #selector(moveDown(_:))
            where scrollableAdjustHotkeysEnabled && window != nil &&
            (window!.title == "Settings" || (window!.parent != nil && window!.parent!.title == "Settings")):
            decreaseValue()
            onValueChanged?(integerValue)
            onValueChangedDouble?(doubleValue)
            return true
        default:
            return false
        }
    }

    override func mouseEntered(with event: NSEvent) {
        log.verbose("mouseEntered: \(caption?.stringValue ?? stringValue)")
        guard isEnabled else { return }

        hover = true
        lightenUp(color: textFieldColorHover)

        onMouseEnter?()

//        refusesFirstResponder = false
//        window?.makeFirstResponder(self)

//        if let editor = currentEditor() as? NSTextView {
//            editor.selectedTextAttributes[.backgroundColor] = darkMauve.withAlphaComponent(0.05)
//        }
    }

    override func mouseExited(with event: NSEvent) {
        log.verbose("mouseExited: \(caption?.stringValue ?? stringValue)")
//        if let editor = currentEditor() as? NSTextView {
//            validateEditing()
//            endEditing(editor)
//            editor.resignFirstResponder()
//        }
//        window?.makeFirstResponder(window)
//        refusesFirstResponder = true

        guard isEnabled else { return }

        finishScrolling()

        hover = false
        darken(color: textFieldColor)

        onMouseExit?()
    }

    func setBgAlpha() {
        guard bgColor.alphaComponent > 0 else { return }
        if scrolling {
            bg = bgColor.withAlphaComponent(0.5)
        } else if hover || currentEditor() != nil {
            bg = bgColor.withAlphaComponent(0.25)
        } else {
            bg = bgColor.withAlphaComponent(0.05)
        }
    }

    @AtomicWrite var highlighterTask: CFRunLoopTimer?
    var highlighterSemaphore = DispatchSemaphore(value: 1)

    func highlight(message: String) {
        mainThread {
            guard highlighterTask == nil || !realtimeQueue.isValid(timer: highlighterTask!),
                  let caption = self.caption, let w = window, w.isVisible
            else {
                return
            }

            caption.stringValue = message
            highlighterTask = realtimeQueue.async(every: 1.seconds) { [weak self] (_: CFRunLoopTimer?) in
                guard let s = self else {
                    if let timer = self?.highlighterTask {
                        realtimeQueue.cancel(timer: timer)
                    }
                    return
                }

                s.highlighterSemaphore.wait()
                defer {
                    s.highlighterSemaphore.signal()
                }

                var windowVisible = false
                var textColor: NSColor?
                mainThread {
                    windowVisible = s.window?.isVisible ?? false
                    textColor = caption.textColor
                }
                guard windowVisible, let caption = s.caption, let currentColor = textColor
                else {
                    if let timer = self?.highlighterTask {
                        realtimeQueue.cancel(timer: timer)
                    }
                    return
                }

                mainThread {
                    caption.lightenUp(color: lunarYellow)
                    caption.needsDisplay = true
                }

                Thread.sleep(forTimeInterval: 0.5)

                mainThread {
                    caption.darken(color: currentColor)
                    caption.needsDisplay = true
                }
            }
        }
    }

    func stopHighlighting() {
        if let timer = highlighterTask {
            realtimeQueue.cancel(timer: timer)
        }
        highlighterTask = nil
        highlighterSemaphore.wait()
        defer {
            self.highlighterSemaphore.signal()
        }

        mainThread { [weak self] in
            guard let caption = self?.caption else { return }
            caption.resetText()
            caption.needsDisplay = true
        }
    }

    func lightenUp(color: NSColor) {
        layer?.add(fadeTransition(duration: 0.15), forKey: "transition")
        textColor = color
        setBgAlpha()
    }

    func darken(color: NSColor) {
        layer?.add(fadeTransition(duration: 0.3), forKey: "transition")
        textColor = color
        setBgAlpha()
    }

    func disableScrollHint() {
        if !didScrollTextField {
            didScrollTextField = true
            Defaults[.didScrollTextField] = true
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

    func finishScrolling() {
        adaptToScrollingFinished?.cancel()
        adaptToScrollingFinished = nil
        if scrolling {
            scrolling = false
            log.verbose("Changed \(caption?.stringValue ?? "") to \(doubleValue)")
            onValueChanged?(integerValue)
            onValueChangedDouble?(doubleValue)
            darken(color: textFieldColorHover)
        }
    }

    func finishScrolling(after ms: Int) {
        adaptToScrollingFinished?.cancel()
        adaptToScrollingFinished = DispatchWorkItem { [weak self] in
            self?.finishScrolling()
            self?.adaptToScrollingFinished = nil
        }
        mainAsyncAfter(ms: ms, adaptToScrollingFinished!)
    }

    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaX) <= 3.0 {
            if !isEnabled {
                return
            }
            if event.scrollingDeltaY < 0.0 {
                scrolledY += event.scrollingDeltaY
                if abs(scrolledY) < scrollDeltaYThreshold {
                    return
                }

                scrolledY = 0.0
                disableScrollHint()
                if !scrolling {
                    scrolling = true
                    lightenUp(color: textFieldColorLight)
                }
                if event.isDirectionInvertedFromDevice {
                    increaseValue()
                } else {
                    decreaseValue()
                }
                finishScrolling(after: 2000)
            } else if event.scrollingDeltaY > 0.0 {
                scrolledY += event.scrollingDeltaY
                if abs(scrolledY) < scrollDeltaYThreshold {
                    return
                }

                scrolledY = 0.0
                disableScrollHint()
                if !scrolling {
                    scrolling = true
                    lightenUp(color: textFieldColorLight)
                }
                if event.isDirectionInvertedFromDevice {
                    decreaseValue()
                } else {
                    increaseValue()
                }
                finishScrolling(after: 2000)
            } else {
                finishScrolling()
            }
        } else {
            super.scrollWheel(with: event)
        }
    }
}
