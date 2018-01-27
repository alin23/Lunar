//
//  ScrollableValueController.swift
//  Lunar
//
//  Created by Alin on 25/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class ScrollableBrightness: NSView {
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var minValue: ScrollableTextField!
    @IBOutlet weak var maxValue: ScrollableTextField!
    @IBOutlet weak var currentValue: ScrollableTextField!
    
    @IBOutlet weak var minValueCaption: ScrollableTextFieldCaption!
    @IBOutlet weak var maxValueCaption: ScrollableTextFieldCaption!
    @IBOutlet weak var currentValueCaption: ScrollableTextFieldCaption!
    
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
            return (display.value(forKey: "minBrightness") as! NSNumber).intValue
        }
        set {
            display.setValue(newValue, forKey: "minBrightness")
        }
    }
    var displayMaxValue: Int {
        get {
            return (display.value(forKey: "maxBrightness") as! NSNumber).intValue
        }
        set {
            display.setValue(newValue, forKey: "maxBrightness")
        }
    }
    var displayValue: Int {
        get {
            return (display.value(forKey: "brightness") as! NSNumber).intValue
        }
        set {
            display.setValue(newValue, forKey: "brightness")
        }
    }
    
    func update(from display: Display) {
        minValue?.intValue = Int32(displayMinValue)
        minValue?.upperLimit = displayMaxValue
        maxValue?.intValue = Int32(displayMaxValue)
        maxValue?.lowerLimit = displayMinValue
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
        minValue?.onValueChanged = { (value: Int) in
            self.maxValue?.lowerLimit = value
            if self.display != nil {
                self.displayMinValue = value
            }
        }
        maxValue?.onValueChanged = { (value: Int) in
            self.minValue?.upperLimit = value
            if self.display != nil {
                self.displayMaxValue = value
            }
        }
        
        minValue?.caption = minValueCaption
        maxValue?.caption = maxValueCaption
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        minValue?.onValueChanged = minValue?.onValueChanged ?? { (value: Int) in
            self.maxValue?.lowerLimit = value
            if self.display != nil {
                self.displayMinValue = value
            }
        }
        maxValue?.onValueChanged = maxValue?.onValueChanged ?? { (value: Int) in
            self.minValue?.upperLimit = value
            if self.display != nil {
                self.displayMaxValue = value
            }
        }
        
        minValue?.caption = minValue?.caption ?? minValueCaption
        maxValue?.caption = maxValue?.caption ?? maxValueCaption
    }
    
}
