//
//  DisplayViewController.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class DisplayViewController: NSViewController {
    
    @IBOutlet weak var displayView: DisplayView!
    @IBOutlet weak var displayName: NSTextField!
    @IBOutlet weak var adaptiveButton: NSButton!
    
    @IBOutlet weak var scrollableBrightness: ScrollableBrightness!
    @IBOutlet weak var scrollableContrast: ScrollableContrast!
    
    @IBOutlet weak var deleteButton: DeleteButton!
    
    var display: Display! {
        didSet {
            if let display = display {
                update(from: display)
            }
        }
    }
    
    var adaptiveButtonTrackingArea: NSTrackingArea!
    var deleteButtonTrackingArea: NSTrackingArea!
    
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
    
    @IBAction func delete(_ sender: NSButton) {
        (self.view.superview!.nextResponder as! PageController).deleteDisplay()
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
            adaptiveButtonTrackingArea = NSTrackingArea(rect: button.visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
            button.addTrackingArea(adaptiveButtonTrackingArea)
        }
    }
    
    
    override func mouseEntered(with event: NSEvent) {
        if let button = adaptiveButton {
            button.layer!.add(fadeTransition(duration: 0.1), forKey: "transition")
            
            if button.state == .on {
                button.layer!.backgroundColor = adaptiveButtonBgOnHover.cgColor
            } else {
                button.layer!.backgroundColor = adaptiveButtonBgOffHover.cgColor
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if let button = adaptiveButton {
            button.layer!.add(fadeTransition(duration: 0.2), forKey: "transition")
            
            if button.state == .on {
                button.layer!.backgroundColor = adaptiveButtonBgOn.cgColor
            } else {
                button.layer!.backgroundColor = adaptiveButtonBgOff.cgColor
            }
        }
    }
    
    func setIsHidden(_ value: Bool) {
        adaptiveButton.isHidden = value
        scrollableBrightness.isHidden = value
        scrollableContrast.isHidden = value
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let display = display, display != GENERIC_DISPLAY {
            update(from: display)
            scrollableBrightness.display = display
            scrollableContrast.display = display
            initAdaptiveButton()
            scrollableBrightness.label.textColor = scollableViewLabelColor
            scrollableContrast.label.textColor = scollableViewLabelColor
        } else {
            setIsHidden(true)
        }
    }
}
