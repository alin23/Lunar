//
//  ScrollableValueController.swift
//  Lunar
//
//  Created by Alin on 25/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class ScrollableValueController: NSViewController {
    @IBOutlet weak var name: NSTextField!
    @IBOutlet weak var minValue: ScrollableTextField!
    @IBOutlet weak var maxValue: ScrollableTextField!
    @IBOutlet weak var currentValue: ScrollableTextField!

    var display: Display!
    var displayMinValue: Int {
        get {
            switch name.stringValue {
            case "Brightness":
                return display.minBrightness.intValue
            case "Contrast":
                return display.minContrast.intValue
            default:
                log.warning("Unknown display value: \(name.stringValue)")
                return 0
            }
        }
        set {
            switch name.stringValue {
            case "Brightness":
                display.minBrightness = NSNumber(value: newValue)
            case "Contrast":
                display.minContrast = NSNumber(value: newValue)
            default:
                log.warning("Unknown display value: \(name.stringValue)")
                return
            }
        }
    }
    var displayMaxValue: Int {
        get {
            switch name.stringValue {
            case "Brightness":
                return display.maxBrightness.intValue
            case "Contrast":
                return display.maxContrast.intValue
            default:
                log.warning("Unknown display value: \(name.stringValue)")
                return 0
            }
        }
        set {
            switch name.stringValue {
            case "Brightness":
                display.maxBrightness = NSNumber(value: newValue)
            case "Contrast":
                display.maxContrast = NSNumber(value: newValue)
            default:
                log.warning("Unknown display value: \(name.stringValue)")
                return
            }
        }
    }
    var displayValue: Int {
        get {
            switch name.stringValue {
            case "Brightness":
                return Int(display.brightness)
            case "Contrast":
                return Int(display.contrast)
            default:
                log.warning("Unknown display value: \(name.stringValue)")
                return 0
            }
        }
        set {
            switch name.stringValue {
            case "Brightness":
                display.brightness = UInt8(newValue)
            case "Contrast":
                display.contrast = UInt8(newValue)
            default:
                log.warning("Unknown display value: \(name.stringValue)")
                return
            }
        }
    }
    
    func setValues(display: Display, name: String) {
        self.display = display
        self.name?.stringValue = name
        minValue?.intValue = Int32(displayMinValue)
        minValue?.upperLimit = displayMaxValue
        maxValue?.intValue = Int32(displayMaxValue)
        maxValue?.lowerLimit = displayMinValue
        currentValue?.intValue = Int32(displayValue)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
}
