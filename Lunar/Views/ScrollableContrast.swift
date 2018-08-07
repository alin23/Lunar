//
//  ScrollableValueController.swift
//  Lunar
//
//  Created by Alin on 25/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class ScrollableContrast: NSView {
    @IBOutlet var label: NSTextField!
    @IBOutlet var minValue: ScrollableTextField!
    @IBOutlet var maxValue: ScrollableTextField!
    @IBOutlet var currentValue: ScrollableTextField!

    @IBOutlet var minValueCaption: ScrollableTextFieldCaption!
    @IBOutlet var maxValueCaption: ScrollableTextFieldCaption!
    @IBOutlet var currentValueCaption: ScrollableTextFieldCaption!

    @IBOutlet var lockButton: LockButton!

    var contrastObserver: NSKeyValueObservation?
    var onMinValueChanged: ((Int) -> Void)?
    var onMaxValueChanged: ((Int) -> Void)?
    var disabled = false {
        didSet {
            minValue.disabled = disabled
            maxValue.disabled = disabled
        }
    }

    var display: Display! {
        didSet {
            update(from: display)
        }
    }

    var name: String! {
        didSet {
            label?.stringValue = name
        }
    }

    var displayMinValue: Int {
        get {
            return (display.value(forKey: "minContrast") as! NSNumber).intValue
        }
        set {
            display.setValue(newValue, forKey: "minContrast")
        }
    }

    var displayMaxValue: Int {
        get {
            return (display.value(forKey: "maxContrast") as! NSNumber).intValue
        }
        set {
            display.setValue(newValue, forKey: "maxContrast")
        }
    }

    var displayValue: Int {
        get {
            return (display.value(forKey: "contrast") as! NSNumber).intValue
        }
        set {
            display.setValue(newValue, forKey: "contrast")
        }
    }

    func addObserver(_ display: Display) {
        contrastObserver = display.observe(\.contrast, options: [.new], changeHandler: { _, change in
            if let newContrast = change.newValue, let display = self.display, display.id != GENERIC_DISPLAY_ID {
                let newContrast = cap(newContrast.uint8Value, minVal: display.minContrast.uint8Value, maxVal: display.maxContrast.uint8Value)
                DispatchQueue.main.async {
                    self.currentValue?.stringValue = String(newContrast)
                }
            }
        })
    }

    func setValuesHidden(_ hidden: Bool, mode: AdaptiveMode? = nil) {
        if currentValue.isHidden == !hidden && minValue.isHidden == hidden && maxValue.isHidden == hidden {
            return
        }
        if let display = display,
            !hidden &&
            (!display.adaptive || (mode ?? brightnessAdapter.mode) == .manual) {
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

        let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64((1_000_000_000 * 0.2)))
        if hidden {
            minValue?.alphaValue = limitsAlpha
            minValueCaption?.alphaValue = limitsAlpha
            maxValue?.alphaValue = limitsAlpha
            maxValueCaption?.alphaValue = limitsAlpha

            currentValue?.isHidden = !hidden
            currentValueCaption?.isHidden = !hidden
            DispatchQueue.main.asyncAfter(deadline: deadline, execute: {
                self.currentValue?.alphaValue = currentAlpha
                self.currentValueCaption?.alphaValue = currentAlpha
                self.minValue?.isHidden = hidden
                self.minValueCaption?.isHidden = hidden
                self.maxValue?.isHidden = hidden
                self.maxValueCaption?.isHidden = hidden
            })
        } else {
            minValue?.isHidden = hidden
            minValueCaption?.isHidden = hidden
            maxValue?.isHidden = hidden
            maxValueCaption?.isHidden = hidden

            currentValue?.alphaValue = currentAlpha
            currentValueCaption?.alphaValue = currentAlpha
            DispatchQueue.main.asyncAfter(deadline: deadline, execute: {
                self.minValue?.alphaValue = limitsAlpha
                self.minValueCaption?.alphaValue = limitsAlpha
                self.maxValue?.alphaValue = limitsAlpha
                self.maxValueCaption?.alphaValue = limitsAlpha
                self.currentValue?.isHidden = !hidden
                self.currentValueCaption?.isHidden = !hidden
            })
        }
    }

    func update(from display: Display) {
        minValue?.intValue = Int32(displayMinValue)
        minValue?.upperLimit = displayMaxValue - 1
        maxValue?.intValue = Int32(displayMaxValue)
        maxValue?.lowerLimit = displayMinValue + 1
        currentValue?.intValue = Int32(displayValue)
        currentValue?.lowerLimit = 0
        currentValue?.upperLimit = 100

        if let button = lockButton {
            button.setup(display.lockedContrast)
            if display.lockedContrast {
                button.state = .on
                setValuesHidden(true)
            } else {
                button.state = .off
                setValuesHidden(false)
            }
        }

        contrastObserver = nil
        addObserver(display)
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
            display?.setValue(true, forKey: "lockedContrast")
            setValuesHidden(true)
        case .off:
            sender.layer?.backgroundColor = lockButtonBgOff.cgColor
            display?.setValue(false, forKey: "lockedContrast")
            setValuesHidden(false)
        default:
            return
        }
        brightnessAdapter.adaptBrightness()
    }

    func setup() {
        minValue?.onValueChangedInstant = onMinValueChanged
        minValue?.onValueChanged = { (value: Int) in
            self.maxValue?.lowerLimit = value + 1
            if self.display != nil {
                self.displayMinValue = value
            }
        }
        maxValue?.onValueChangedInstant = onMaxValueChanged
        maxValue?.onValueChanged = { (value: Int) in
            self.minValue?.upperLimit = value - 1
            if self.display != nil {
                self.displayMaxValue = value
            }
        }

        currentValue?.onValueChanged = { (value: Int) in
            if self.display != nil {
                self.displayValue = value
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
        minValue?.onValueChanged = minValue?.onValueChanged ?? { (value: Int) in
            self.maxValue?.lowerLimit = value + 1
            if self.display != nil {
                self.displayMinValue = value
            }
        }
        maxValue?.onValueChangedInstant = maxValue?.onValueChangedInstant ?? onMaxValueChanged
        maxValue?.onValueChanged = maxValue?.onValueChanged ?? { (value: Int) in
            self.minValue?.upperLimit = value - 1
            if self.display != nil {
                self.displayMaxValue = value
            }
        }

        currentValue?.onValueChanged = currentValue?.onValueChanged ?? { (value: Int) in
            if self.display != nil {
                self.displayValue = value
            }
        }

        minValue?.caption = minValue?.caption ?? minValueCaption
        maxValue?.caption = maxValue?.caption ?? maxValueCaption
        currentValue?.caption = currentValue?.caption ?? currentValueCaption
    }
}
