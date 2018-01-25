//
//  SplitViewController.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class SplitViewController: NSViewController {
    let bgColor = NSColor.init(deviceWhite: 1.0, alpha: 1.0)
    let buttonLabelColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.2513754401)
    let buttonLabelColorHover = #colorLiteral(red: 0.0808076635, green: 0.0326673463, blue: 0.2609090805, alpha: 1)
    let buttonColor = #colorLiteral(red: 0.9254902005, green: 0.9294117689, blue: 0.9450980425, alpha: 1)
    let buttonColorHover = #colorLiteral(red: 1, green: 0.8352941275, blue: 0.5254902244, alpha: 1)
    let onButtonColor = #colorLiteral(red: 0.3295102879, green: 0.8284319043, blue: 0.5044205216, alpha: 1)
    let offButtonColor = #colorLiteral(red: 0.9481818676, green: 0.2008136532, blue: 0.262285579, alpha: 1)
    
    var activeTitle: NSMutableAttributedString?
    var inactiveTitle: NSMutableAttributedString?
    var activeTitleHover: NSMutableAttributedString?
    var inactiveTitleHover: NSMutableAttributedString?
    
    @IBOutlet weak var activeStateButton: NSButton?
    
    @IBAction func toggleBrightnessAdapter(sender: Any?) {
        _ = brightnessAdapter.toggle()
    }
    
    func initActiveStateButton() {
        if let button = activeStateButton {
            let buttonSize = button.frame
            button.wantsLayer = true
            
            activeTitle = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
            activeTitle?.addAttribute(NSAttributedStringKey.foregroundColor, value: buttonLabelColor, range: NSMakeRange(0, activeTitle!.length - 2))
            activeTitle?.addAttribute(NSAttributedStringKey.foregroundColor, value: offButtonColor, range: NSMakeRange(activeTitle!.length - 2, 2))
            
            inactiveTitle = NSMutableAttributedString(attributedString: button.attributedTitle)
            inactiveTitle?.addAttribute(NSAttributedStringKey.foregroundColor, value: buttonLabelColor, range: NSMakeRange(0, inactiveTitle!.length - 2))
            inactiveTitle?.addAttribute(NSAttributedStringKey.foregroundColor, value: onButtonColor, range: NSMakeRange(inactiveTitle!.length - 2, 2))
            
            activeTitleHover = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
            activeTitleHover?.addAttribute(NSAttributedStringKey.foregroundColor, value: buttonLabelColorHover, range: NSMakeRange(0, activeTitleHover!.length - 2))
            activeTitleHover?.addAttribute(NSAttributedStringKey.foregroundColor, value: offButtonColor, range: NSMakeRange(activeTitleHover!.length - 2, 2))
            
            inactiveTitleHover = NSMutableAttributedString(attributedString: button.attributedTitle)
            inactiveTitleHover?.addAttribute(NSAttributedStringKey.foregroundColor, value: buttonLabelColorHover, range: NSMakeRange(0, inactiveTitleHover!.length - 2))
            inactiveTitleHover?.addAttribute(NSAttributedStringKey.foregroundColor, value: onButtonColor, range: NSMakeRange(inactiveTitleHover!.length - 2, 2))
            
            button.attributedTitle = inactiveTitle!
            button.attributedAlternateTitle = activeTitle!
            
            button.setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.height + 10))
            button.layer!.backgroundColor = buttonColor.cgColor
            button.layer!.cornerRadius = button.frame.height / 2
            
            let area = NSTrackingArea(rect: button.visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
            button.addTrackingArea(area)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        if let button = activeStateButton {
            button.layer!.add(fadeTransition(duration: 0.1), forKey: "transition")
            
            button.layer!.backgroundColor = buttonColorHover.cgColor
            button.attributedTitle = inactiveTitleHover!
            button.attributedAlternateTitle = activeTitleHover!
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if let button = activeStateButton {
            button.layer!.add(fadeTransition(duration: 0.2), forKey: "transition")
            
            button.layer!.backgroundColor = buttonColor.cgColor
            button.attributedTitle = inactiveTitle!
            button.attributedAlternateTitle = activeTitle!
        }
    }
    
    override func viewDidLoad() {
        view.wantsLayer = true
        view.layer!.cornerRadius = 12.0
        view.layer!.backgroundColor = bgColor.cgColor
        initActiveStateButton()
        super.viewDidLoad()
    }
}
