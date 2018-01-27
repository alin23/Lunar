//
//  SplitViewController.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class SplitViewController: NSViewController {
    var activeTitle: NSMutableAttributedString?
    var inactiveTitle: NSMutableAttributedString?
    var activeTitleHover: NSMutableAttributedString?
    var inactiveTitleHover: NSMutableAttributedString?
    
    @IBOutlet weak var logo: NSTextField?
    @IBOutlet weak var activeStateButton: NSButton?
    
    @IBAction func toggleBrightnessAdapter(sender: Any?) {
        _ = brightnessAdapter.toggle()
    }
    
    func initActiveStateButton() {
        if let button = activeStateButton {
            let buttonSize = button.frame
            button.wantsLayer = true
            
            activeTitle = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
            activeTitle?.addAttribute(NSAttributedStringKey.foregroundColor, value: stateButtonLabelColor, range: NSMakeRange(0, activeTitle!.length - 2))
            activeTitle?.addAttribute(NSAttributedStringKey.foregroundColor, value: offButtonColor, range: NSMakeRange(activeTitle!.length - 2, 2))
            
            inactiveTitle = NSMutableAttributedString(attributedString: button.attributedTitle)
            inactiveTitle?.addAttribute(NSAttributedStringKey.foregroundColor, value: stateButtonLabelColor, range: NSMakeRange(0, inactiveTitle!.length - 2))
            inactiveTitle?.addAttribute(NSAttributedStringKey.foregroundColor, value: onButtonColor, range: NSMakeRange(inactiveTitle!.length - 2, 2))
            
            activeTitleHover = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
            activeTitleHover?.addAttribute(NSAttributedStringKey.foregroundColor, value: stateButtonLabelColorHover, range: NSMakeRange(0, activeTitleHover!.length - 2))
            activeTitleHover?.addAttribute(NSAttributedStringKey.foregroundColor, value: offButtonColor, range: NSMakeRange(activeTitleHover!.length - 2, 2))
            
            inactiveTitleHover = NSMutableAttributedString(attributedString: button.attributedTitle)
            inactiveTitleHover?.addAttribute(NSAttributedStringKey.foregroundColor, value: stateButtonLabelColorHover, range: NSMakeRange(0, inactiveTitleHover!.length - 2))
            inactiveTitleHover?.addAttribute(NSAttributedStringKey.foregroundColor, value: onButtonColor, range: NSMakeRange(inactiveTitleHover!.length - 2, 2))
            
            button.attributedTitle = inactiveTitle!
            button.attributedAlternateTitle = activeTitle!
            
            button.setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.height + 10))
            button.layer!.backgroundColor = stateButtonColor.cgColor
            button.layer!.cornerRadius = button.frame.height / 2
            
            let area = NSTrackingArea(rect: button.visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
            button.addTrackingArea(area)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        if let button = activeStateButton {
            button.layer!.add(fadeTransition(duration: 0.1), forKey: "transition")
            
            button.layer!.backgroundColor = stateButtonColorHover.cgColor
            button.attributedTitle = inactiveTitleHover!
            button.attributedAlternateTitle = activeTitleHover!
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if let button = activeStateButton {
            button.layer!.add(fadeTransition(duration: 0.2), forKey: "transition")
            
            button.layer!.backgroundColor = stateButtonColor.cgColor
            button.attributedTitle = inactiveTitle!
            button.attributedAlternateTitle = activeTitle!
        }
    }
    
    override func viewDidLoad() {
        view.wantsLayer = true
        view.layer!.cornerRadius = 12.0
        view.layer!.backgroundColor = bgColor.cgColor
        logo?.textColor = logoColor
        initActiveStateButton()
        super.viewDidLoad()
    }
}
