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
    var onMinValueChanged: ((Int) -> Void)?
    var onMaxValueChanged: ((Int) -> Void)?

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

    func update(from _: Display) {
        minValue?.intValue = Int32(displayMinValue)
        minValue?.upperLimit = displayMaxValue - 1
        maxValue?.intValue = Int32(displayMaxValue)
        maxValue?.lowerLimit = displayMinValue + 1
        currentValue?.intValue = Int32(displayValue)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
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

        minValue?.caption = minValueCaption
        maxValue?.caption = maxValueCaption
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

        minValue?.caption = minValue?.caption ?? minValueCaption
        maxValue?.caption = maxValue?.caption ?? maxValueCaption
    }
}
