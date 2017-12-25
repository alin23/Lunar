//
//  DisplayViewController.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class DisplayViewController: NSViewController {
    
    @IBOutlet weak var displayName: NSTextField!
    @IBOutlet weak var minBrightness: ScrollableTextField!
    @IBOutlet weak var maxBrightness: ScrollableTextField!
    
    @IBOutlet weak var minContrast: ScrollableTextField!
    @IBOutlet weak var maxContrast: ScrollableTextField!
    @IBOutlet weak var adaptiveButton: NSButton!
    var display: Display?
    let adaptiveButtonBgOn = #colorLiteral(red: 1, green: 0.8352941275, blue: 0.5254902244, alpha: 1)
    let adaptiveButtonLabelOn = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.796875)
    let adaptiveButtonBgOff = #colorLiteral(red: 0.9254902005, green: 0.9294117689, blue: 0.9450980425, alpha: 1)
    let adaptiveButtonLabelOff = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.2513754401)
    
    func update(from display: Display) {
        displayName.stringValue = display.name
        minBrightness.intValue = display.minBrightness.int32Value
        minBrightness.upperLimit = display.maxBrightness.intValue
        maxBrightness.intValue = display.maxBrightness.int32Value
        maxBrightness.lowerLimit = display.minBrightness.intValue
        minContrast.intValue = display.minContrast.int32Value
        minContrast.upperLimit = display.maxContrast.intValue
        maxContrast.intValue = display.maxContrast.int32Value
        maxContrast.lowerLimit = display.minContrast.intValue
        if display.adaptive {
            adaptiveButton.state = .on
        } else {
            adaptiveButton.state = .off
        }
    }
    
    @IBAction func toggleAdaptive(_ sender: NSButton) {
        switch sender.state {
        case .on:
            sender.layer!.backgroundColor = adaptiveButtonBgOn.cgColor
            display?.adaptive = true
            datastore.save()
        case .off:
            sender.layer!.backgroundColor = adaptiveButtonBgOff.cgColor
            display?.adaptive = false
            datastore.save()
        default:
            return
        }
    }
    
    func initAdaptiveButton() {
        if let button = adaptiveButton {
            let buttonSize = button.frame
            button.wantsLayer = true
            
            let activeTitle = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
            activeTitle.addAttribute(NSAttributedStringKey.foregroundColor, value: adaptiveButtonLabelOn, range: NSMakeRange(0, activeTitle.length))
            let inactiveTitle = NSMutableAttributedString(attributedString: button.attributedTitle)
            inactiveTitle.addAttribute(NSAttributedStringKey.foregroundColor, value: adaptiveButtonLabelOff, range: NSMakeRange(0, inactiveTitle.length))
            
            button.attributedTitle = inactiveTitle
            button.attributedAlternateTitle = activeTitle
            
            button.setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.height + 10))
            button.layer!.cornerRadius = button.frame.height / 2
            if button.state == .on {
                button.layer!.backgroundColor = adaptiveButtonBgOn.cgColor
            } else {
                button.layer!.backgroundColor = adaptiveButtonBgOff.cgColor
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let display = display {
            update(from: display)
        }
        initAdaptiveButton()
        minBrightness.onValueChanged = { (value: Int) in
            self.maxBrightness.lowerLimit = value
            if let display = self.display {
                display.minBrightness = NSNumber(value: value)
                datastore.save()
            }
        }
        maxBrightness.onValueChanged = { (value: Int) in
            self.minBrightness.upperLimit = value
            if let display = self.display {
                display.maxBrightness = NSNumber(value: value)
                datastore.save()
            }
        }
        minContrast.onValueChanged = { (value: Int) in
            self.maxContrast.lowerLimit = value
            if let display = self.display {
                display.minContrast = NSNumber(value: value)
                datastore.save()
            }
        }
        maxContrast.onValueChanged = { (value: Int) in
            self.minContrast.upperLimit = value
            if let display = self.display {
                display.maxContrast = NSNumber(value: value)
                datastore.save()
            }
        }
    }
}
