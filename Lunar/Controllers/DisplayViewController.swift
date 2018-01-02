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
    @IBOutlet weak var adaptiveButton: NSButton!
    
    @IBOutlet weak var scrollableBrightness: ScrollableBrightness!
    @IBOutlet weak var scrollableContrast: ScrollableContrast!
    
    
    var display: Display! {
        didSet {
            if let display = display {
                update(from: display)
            }
        }
    }
    let adaptiveButtonBgOn = #colorLiteral(red: 1, green: 0.8352941275, blue: 0.5254902244, alpha: 1)
    let adaptiveButtonLabelOn = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.796875)
    let adaptiveButtonBgOff = #colorLiteral(red: 0.9254902005, green: 0.9294117689, blue: 0.9450980425, alpha: 1)
    let adaptiveButtonLabelOff = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.2513754401)
    
    func update(from display: Display) {
        displayName?.stringValue = display.name
        if display.adaptive {
            adaptiveButton?.state = .on
        } else {
            adaptiveButton?.state = .off
        }
    }
    
    @IBAction func toggleAdaptive(_ sender: NSButton) {
        switch sender.state {
        case .on:
            sender.layer!.backgroundColor = adaptiveButtonBgOn.cgColor
            display?.setValue(true, forKey: "adaptive")
        case .off:
            sender.layer!.backgroundColor = adaptiveButtonBgOff.cgColor
            display?.setValue(false, forKey: "adaptive")
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
            scrollableBrightness.display = display
            scrollableContrast.display = display
            if display.adaptive {
            }
        }
        initAdaptiveButton()
    }
}
