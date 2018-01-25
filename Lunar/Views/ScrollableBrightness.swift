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
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if let min = minValue,
            let max = maxValue,
            min.onValueChanged == nil,
            max.onValueChanged == nil
        {
            min.onValueChanged = { (value: Int) in
                self.maxValue?.lowerLimit = value
                if self.display != nil {
                    self.displayMinValue = value
                }
            }
            max.onValueChanged = { (value: Int) in
                self.minValue?.upperLimit = value
                if self.display != nil {
                    self.displayMaxValue = value
                }
            }
        }
        
        if let minCaption = minValueCaption,
            let maxCaption = maxValueCaption,
            let min = minValue,
            let max = maxValue,
            min.caption == nil,
            max.caption == nil
        {
            min.caption = minCaption
            max.caption = maxCaption
        }
    }
    
}
