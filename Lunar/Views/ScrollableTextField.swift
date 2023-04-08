//
//  ScrollableTextField.swift
//  Lunar
//
//  Created by Alin on 24/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Carbon.HIToolbox
import Cocoa
import Defaults
import Magnet

let PRECISE_SCROLL_Y_THRESHOLD: CGFloat = 25.0
let NORMAL_SCROLL_Y_THRESHOLD: CGFloat = 9.0
let FAST_SCROLL_Y_THRESHOLD: CGFloat = 2.0
let FASTEST_SCROLL_Y_THRESHOLD: CGFloat = 0.1

var scrollDeltaYThreshold: CGFloat = NORMAL_SCROLL_Y_THRESHOLD

// MARK: - ScrollableTextField

final class ScrollableTextField: NSTextField, NSTextFieldDelegate {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    @IBInspectable dynamic var step = 1.0
    @IBInspectable dynamic var leftPadding: UInt8 = 0
    @IBInspectable dynamic var showPlusSign = false
    @IBInspectable dynamic var decimalPoints: UInt8 = 0

    var editingTextFieldColorChanged = false

    var _floatValue: Float = 0
    var _doubleValue: Double = 0
    var _integerValue = 0
    let growPointSize: CGFloat = 2
    var hover = false
    var scrolling = false
    var onValueChanged: ((Int) -> Void)?
    var onValueChangedInstant: ((Int) -> Void)?
    var onValueChangedDouble: ((Double) -> Void)?
    var onValueChangedInstantDouble: ((Double) -> Void)?

    var onEditStateChange: ((Bool) -> Void)?
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?

    var centerAlign: NSParagraphStyle?
    var didScrollTextField: Bool = CachedDefaults[.didScrollTextField]

    var normalSize: CGSize?
    var activeSize: CGSize?

    var scrolledY: CGFloat = 0.0

    var trackingArea: NSTrackingArea?
    var captionTrackingArea: NSTrackingArea?
    var adaptToScrollingFinished: DispatchWorkItem?
    lazy var lastValidValue: Double = doubleValue

    var highlighterTask: Repeater?

    @IBInspectable var textFieldColorLight: NSColor = scrollableTextFieldColorLight

    @IBInspectable dynamic var backgroundOpacity: CGFloat = 0.05

    @objc var shouldAllowEmptyValue = false

    @IBInspectable dynamic var lowerLimit = 0.0 {
        didSet { doubleValue = cap(doubleValue, minVal: lowerLimit, maxVal: upperLimit) }
    }

    @IBInspectable dynamic var upperLimit = 100.0 {
        didSet { doubleValue = cap(doubleValue, minVal: lowerLimit, maxVal: upperLimit) }
    }

    @IBInspectable var bgColor: NSColor = .clear {
        didSet {
            if !hover {
                textColor = textFieldColor
            }
        }
    }

    @IBInspectable var editingTextFieldColor: NSColor = scrollableTextFieldColor {
        didSet {
            textColor = editingTextFieldColor
            editingTextFieldColorChanged = true
        }
    }

    @IBInspectable var textFieldColor: NSColor = scrollableTextFieldColor {
        didSet {
            if !hover {
                textColor = textFieldColor
            }
            if !editingTextFieldColorChanged {
                editingTextFieldColor = textFieldColor
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

//    var _stringValue: String = ""
    override var stringValue: String {
        didSet {
            guard let number = NumberFormatter.shared.number(from: stringValue) else { return }
            _floatValue = number.floatValue
            _doubleValue = number.doubleValue
            _integerValue = number.intValue
        }
    }

    override var floatValue: Float {
        get { _floatValue }
        set {
            _floatValue = newValue
            _doubleValue = newValue.d
            _integerValue = newValue.i
            let number = newValue
            if number <= 0.0001, number >= -0.0001 {
                stringValue = 0.str(decimals: decimalPoints, padding: leftPadding)
            } else {
                stringValue = "\(showPlusSign && number > 0 ? "+" : "")\(number.str(decimals: decimalPoints, padding: leftPadding))"
            }
        }
    }

    override var doubleValue: Double {
        get { _doubleValue }
        set {
            _doubleValue = newValue
            _floatValue = newValue.f
            _integerValue = newValue.i
            let number = newValue
            if number <= 0.0001, number >= -0.0001 {
                stringValue = 0.str(decimals: decimalPoints, padding: leftPadding)
            } else {
                stringValue = "\(showPlusSign && number > 0 ? "+" : "")\(number.str(decimals: decimalPoints, padding: leftPadding))"
            }
        }
    }

    override var intValue: Int32 {
        didSet {
            integerValue = intValue.i
        }
    }

    override var integerValue: Int {
        get { _integerValue }
        set {
            _integerValue = newValue
            _floatValue = newValue.f
            _doubleValue = newValue.d
            let number = newValue
            if number == 0 {
                stringValue = 0.str(decimals: decimalPoints, padding: leftPadding)
            } else {
                stringValue = "\(showPlusSign && number > 0 ? "+" : "")\(number.d.str(decimals: decimalPoints, padding: leftPadding))"
            }
        }
    }

    var editing = false {
        didSet {
            log.debug("Editing: \(editing)")
            onEditStateChange?(editing)
        }
    }

    @IBOutlet var caption: ScrollableTextFieldCaption? {
        didSet {
            caption?.isHidden = isHidden
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

    override var isHidden: Bool {
        didSet { caption?.isHidden = isHidden }
    }

    override var isEnabled: Bool {
        didSet {
            guard bgColor.alphaComponent > 0 else { return }
            mainThread { bg = bgColor.withAlphaComponent(isEnabled ? backgroundOpacity : 0.05) }
        }
    }

    var captionHighlighterTask: DispatchWorkItem? {
        didSet { oldValue?.cancel() }
    }

    override func viewDidMoveToWindow() {
        trackHover()
        setBgAlpha()
    }

    override func viewDidMoveToSuperview() {
        trackHover()
        setBgAlpha()
    }

    func trackHover() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func becomeFirstResponder() -> Bool {
        editing = true
        lastValidValue = doubleValue
        refusesFirstResponder = false
        let success = super.becomeFirstResponder()

        if let editor = currentEditor() as? NSTextView {
            editor.selectedTextAttributes[.backgroundColor] = darkMauve.withAlphaComponent(0.05)
            editor.insertionPointColor = darkMauve
            if let fieldEditor = editor.window?.fieldEditor(true, for: self) as? NSTextView {
                fieldEditor.insertionPointColor = darkMauve
            }
        }
        mainAsyncAfter(ms: 200) { self.lightenUp(color: self.editingTextFieldColor) }
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
        trackHover()
        setBgAlpha()
        needsDisplay = true
        if let font {
            self.font = .monospacedSystemFont(
                ofSize: font.pointSize,
                weight: font.pointSize >= 50 ? .bold : (font.pointSize > 40 ? .bold : .heavy)
            )
        }

        // toolTip = """
        // Scroll to change, click to edit.

        // When scrolling, you can:
        // • Hold Command for more precise adjustments
        // • Hold Option for faster adjustments
        // • Hold Control for highest sensitivity possible
        // """
    }

    override func cancelOperation(_: Any?) {
        editing = false
        darken(color: textFieldColor)
        doubleValue = lastValidValue
        abortEditing()
    }

    override func textDidBeginEditing(_ notification: Notification) {
        editing = true
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
        guard !textObject.string.trimmed.isEmpty else {
            if shouldAllowEmptyValue {
                doubleValue = -1
                onValueChanged?(-1)
                onValueChangedDouble?(-1)
                onValueChangedInstant?(-1)
                onValueChangedInstantDouble?(-1)
                editing = false
                return true
            }
            return false
        }
        guard let val = textObject.string.d, val >= lowerLimit, val <= upperLimit else {
            return false
        }
        doubleValue = val
        onValueChanged?(integerValue)
        onValueChangedDouble?(doubleValue)
        onValueChangedInstant?(integerValue)
        onValueChangedInstantDouble?(doubleValue)
        editing = false
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(insertNewline(_:)), #selector(insertTab(_:)):
            guard let editor = currentEditor() else {
                return false
            }
            guard textShouldEndEditing(editor) else {
                window?.shake()
                return true
            }
            validateEditing()
            endEditing(editor)
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

    override func mouseEntered(with _: NSEvent) {
        log.verbose("mouseEntered \(caption?.stringValue ?? stringValue)")
        guard isEnabled else { return }
        stringValue = stringValue

        hover = true
        if !editing { lightenUp(color: textFieldColorHover) }

        onMouseEnter?()
    }

    override func mouseExited(with _: NSEvent) {
        log.verbose("mouseExited \(caption?.stringValue ?? stringValue)")

        guard isEnabled else { return }

        finishScrolling()

        hover = false
        if !editing { darken(color: textFieldColor) }

        onMouseExit?()
    }

    func setBgAlpha() {
        guard bgColor.alphaComponent > 0 else { return }
        if scrolling {
            bg = bgColor.withAlphaComponent(0.5)
        } else if hover || currentEditor() != nil {
            bg = bgColor.withAlphaComponent(0.25)
        } else {
            bg = bgColor.withAlphaComponent(isEnabled ? backgroundOpacity : 0.05)
        }
    }

    func highlight(message: String) {
        let windowVisible: Bool = mainThread { window?.isVisible ?? false }

        guard highlighterTask == nil, let caption, windowVisible else {
            return
        }

        mainThread { caption.stringValue = message }
        highlighterTask = Repeater(every: 1, name: "scrollableTextFieldHighlighter") { [weak self] in
            guard let s = self else {
                self?.stopHighlighting()
                return
            }

            var windowVisible = false
            var textColor: NSColor?
            windowVisible = s.window?.isVisible ?? false
            textColor = caption.textColor

            guard windowVisible, let caption = s.caption, let currentColor = textColor else {
                self?.stopHighlighting()
                return
            }

            caption.lightenUp(color: lunarYellow)
            caption.needsDisplay = true

            s.captionHighlighterTask = mainAsyncAfter(ms: 500) {
                caption.darken(color: currentColor)
                caption.needsDisplay = true
            }
        }
    }

    func stopHighlighting() {
        mainThread { [weak self] in
            self?.highlighterTask = nil
            self?.captionHighlighterTask = nil

            guard let caption = self?.caption else { return }
            caption.resetText()
            caption.needsDisplay = true
        }
    }

    func lightenUp(color: NSColor) {
        transition(0.4)
        textColor = color
        setBgAlpha()
    }

    func darken(color: NSColor) {
        transition(0.8)
        textColor = color
        setBgAlpha()
    }

    func disableScrollHint() {
        if !didScrollTextField {
            didScrollTextField = true
            CachedDefaults[.didScrollTextField] = true
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
            if !editing { darken(color: textFieldColorHover) }
        }
    }

    func finishScrolling(after ms: Int) {
        adaptToScrollingFinished?.cancel()
        adaptToScrollingFinished = DispatchWorkItem(name: "adaptToScrollingFinished") { [weak self] in
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
                    if !editing { lightenUp(color: textFieldColorLight) }
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
                    if !editing { lightenUp(color: textFieldColorLight) }
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
