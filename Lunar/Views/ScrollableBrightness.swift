//
//  ScrollableValueController.swift
//  Lunar
//
//  Created by Alin on 25/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Defaults

class ScrollableBrightness: NSView {
    @IBOutlet var label: NSTextField!
    @IBOutlet var minValue: ScrollableTextField!
    @IBOutlet var maxValue: ScrollableTextField!
    @IBOutlet var currentValue: ScrollableTextField!

    @IBOutlet var minValueCaption: ScrollableTextFieldCaption!
    @IBOutlet var maxValueCaption: ScrollableTextFieldCaption!
    @IBOutlet var currentValueCaption: ScrollableTextFieldCaption!

    @IBOutlet var lockButton: LockButton!

    var minObserver: DefaultsObservation?
    var maxObserver: DefaultsObservation?
    var onMinValueChanged: ((Int) -> Void)?
    var onMaxValueChanged: ((Int) -> Void)?
    var disabled = false {
        didSet {
            minValue.isEnabled = !disabled
            maxValue.isEnabled = !disabled
        }
    }

    weak var display: Display? {
        didSet {
            if let d = display {
                update(from: d)
            }
        }
    }

    var name: String! {
        didSet {
            label?.stringValue = name
        }
    }

    var displayMinValue: Int {
        get {
            return display?.minBrightness.intValue ?? 0
        }
        set {
            display?.minBrightness = NSNumber(value: newValue)
        }
    }

    var displayMaxValue: Int {
        get {
            return display?.maxBrightness.intValue ?? 100
        }
        set {
            display?.maxBrightness = NSNumber(value: newValue)
        }
    }

    var displayValue: Int {
        get {
            return display?.brightness.intValue ?? 50
        }
        set {
            display?.brightness = NSNumber(value: newValue)
        }
    }

    var brightnessObserver: ((NSNumber, NSNumber) -> Void)?

    func addObserver(_ display: Display) {
        minObserver = Defaults.observe(.brightnessLimitMin) { [weak self] change in
            guard let currentValue = self?.currentValue else { return }
            runInMainThread {
                currentValue.lowerLimit = Double(change.newValue)
                let newBrightness = Int(round(cap(currentValue.doubleValue, minVal: currentValue.lowerLimit, maxVal: currentValue.upperLimit)))
                currentValue.stringValue = String(newBrightness)
                if brightnessAdapter.mode == .manual {
                    currentValue.onValueChanged?(newBrightness)
                }
            }
        }
        maxObserver = Defaults.observe(.brightnessLimitMax) { [weak self] change in
            guard let currentValue = self?.currentValue else { return }
            runInMainThread {
                currentValue.upperLimit = Double(change.newValue)
                let newBrightness = Int(round(cap(currentValue.doubleValue, minVal: currentValue.lowerLimit, maxVal: currentValue.upperLimit)))
                currentValue.stringValue = String(newBrightness)
                if brightnessAdapter.mode == .manual {
                    currentValue.onValueChanged?(newBrightness)
                }
            }
        }

        brightnessObserver = { [weak self] newBrightness, _ in
            if let display = self?.display, display.id != GENERIC_DISPLAY_ID {
                let minBrightness: UInt8
                let maxBrightness: UInt8

                if brightnessAdapter.mode != .manual {
                    minBrightness = display.minBrightness.uint8Value
                    maxBrightness = display.maxBrightness.uint8Value
                } else {
                    minBrightness = UInt8(Defaults[.brightnessLimitMin])
                    maxBrightness = UInt8(Defaults[.brightnessLimitMax])
                }

                let newBrightness = cap(newBrightness.uint8Value, minVal: minBrightness, maxVal: maxBrightness)
                runInMainThread {
                    self?.currentValue?.stringValue = String(newBrightness)
                }
            }
        }
        display.setObserver(prop: "brightness", key: "scrollableBrightness-\(accessibilityIdentifier())", action: brightnessObserver!)
    }

    func setValuesHidden(_ hidden: Bool, mode: AdaptiveMode? = nil) {
        if currentValue.isHidden == !hidden, minValue.isHidden == hidden, maxValue.isHidden == hidden {
            return
        }
        if let display = display,
            !hidden,
            !display.adaptive || (mode ?? brightnessAdapter.mode) == .manual {
            return
        }

        var limitsAnimDuration = 0.15
        var currentAnimDuration = 0.7
        var limitsAlpha: CGFloat = 0.0
        var currentAlpha: CGFloat = 1.0
        if !hidden {
            limitsAnimDuration = 0.7
            currentAnimDuration = 0.15
            limitsAlpha = 1.0
            currentAlpha = 0.0
        }

        minValue?.layer?.add(fadeTransition(duration: limitsAnimDuration), forKey: "lockingTransition")
        maxValue?.layer?.add(fadeTransition(duration: limitsAnimDuration), forKey: "lockingTransition")
        minValueCaption?.layer?.add(fadeTransition(duration: limitsAnimDuration), forKey: "lockingTransition")
        maxValueCaption?.layer?.add(fadeTransition(duration: limitsAnimDuration), forKey: "lockingTransition")
        currentValue?.layer?.add(fadeTransition(duration: currentAnimDuration), forKey: "lockingTransition")
        currentValueCaption?.layer?.add(fadeTransition(duration: currentAnimDuration), forKey: "lockingTransition")

        let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(1_000_000_000 * 0.2))
        if hidden {
            minValue?.alphaValue = limitsAlpha
            minValueCaption?.alphaValue = limitsAlpha
            maxValue?.alphaValue = limitsAlpha
            maxValueCaption?.alphaValue = limitsAlpha

            currentValue?.isHidden = !hidden
            currentValueCaption?.isHidden = !hidden
            DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
                guard let self = self else { return }
                self.currentValue?.alphaValue = currentAlpha
                self.currentValueCaption?.alphaValue = currentAlpha
                self.minValue?.isHidden = hidden
                self.minValueCaption?.isHidden = hidden
                self.maxValue?.isHidden = hidden
                self.maxValueCaption?.isHidden = hidden
            }
        } else {
            minValue?.isHidden = hidden
            minValueCaption?.isHidden = hidden
            maxValue?.isHidden = hidden
            maxValueCaption?.isHidden = hidden

            currentValue?.alphaValue = currentAlpha
            currentValueCaption?.alphaValue = currentAlpha
            DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
                guard let self = self else { return }
                self.minValue?.alphaValue = limitsAlpha
                self.minValueCaption?.alphaValue = limitsAlpha
                self.maxValue?.alphaValue = limitsAlpha
                self.maxValueCaption?.alphaValue = limitsAlpha
                self.currentValue?.isHidden = !hidden
                self.currentValueCaption?.isHidden = !hidden
            }
        }
    }

    func update(from display: Display) {
        minValue?.intValue = Int32(displayMinValue)
        minValue?.upperLimit = Double(displayMaxValue - 1)
        maxValue?.intValue = Int32(displayMaxValue)
        maxValue?.lowerLimit = Double(displayMinValue + 1)
        currentValue?.intValue = Int32(displayValue)
        currentValue?.lowerLimit = Double(Defaults[.brightnessLimitMin])
        currentValue?.upperLimit = Double(Defaults[.brightnessLimitMax])

        if let button = lockButton {
            button.setup(display.lockedBrightness)
            if display.lockedBrightness {
                button.state = .on
                setValuesHidden(true)
            } else {
                button.state = .off
                setValuesHidden(false)
            }
        }

        addObserver(display)
    }

    deinit {
        display?.resetObserver(prop: "brightness", key: "scrollableBrightness-\(self.accessibilityIdentifier())", type: NSNumber.self)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    @IBAction func toggleLock(_ sender: LockButton) {
        switch sender.state {
        case .on:
            sender.layer?.backgroundColor = lockButtonBgOn.cgColor
            display?.lockedBrightness = true
            setValuesHidden(true)
        case .off:
            sender.layer?.backgroundColor = lockButtonBgOff.cgColor
            display?.lockedBrightness = false
            setValuesHidden(false)
        default:
            return
        }
        brightnessAdapter.adaptBrightness()
    }

    func setup() {
        minValue?.onValueChangedInstant = onMinValueChanged
        minValue?.onValueChanged = { [weak self] (value: Int) in
            self?.maxValue?.lowerLimit = Double(value + 1)
            if self?.display != nil {
                self?.displayMinValue = value
            }
        }
        maxValue?.onValueChangedInstant = onMaxValueChanged
        maxValue?.onValueChanged = { [weak self] (value: Int) in
            self?.minValue?.upperLimit = Double(value - 1)
            if self?.display != nil {
                self?.displayMaxValue = value
            }
        }

        currentValue?.onValueChanged = { [weak self] (value: Int) in
            if self?.display != nil {
                self?.displayValue = value
            }
        }

        minValue?.caption = minValueCaption
        maxValue?.caption = maxValueCaption
        currentValue?.caption = currentValueCaption

        lockButton?.setup()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        minValue?.onValueChangedInstant = minValue?.onValueChangedInstant ?? onMinValueChanged
        minValue?.onValueChanged = minValue?.onValueChanged ?? { [weak self] (value: Int) in
            self?.maxValue?.lowerLimit = Double(value + 1)
            if self?.display != nil {
                self?.displayMinValue = value
            }
        }
        maxValue?.onValueChangedInstant = maxValue?.onValueChangedInstant ?? onMaxValueChanged
        maxValue?.onValueChanged = maxValue?.onValueChanged ?? { [weak self] (value: Int) in
            self?.minValue?.upperLimit = Double(value - 1)
            if self?.display != nil {
                self?.displayMaxValue = value
            }
        }

        currentValue?.onValueChanged = currentValue?.onValueChanged ?? { [weak self] (value: Int) in
            if self?.display != nil {
                self?.displayValue = value
            }
        }

        minValue?.caption = minValue?.caption ?? minValueCaption
        maxValue?.caption = maxValue?.caption ?? maxValueCaption
        currentValue?.caption = currentValue?.caption ?? currentValueCaption
    }
}
