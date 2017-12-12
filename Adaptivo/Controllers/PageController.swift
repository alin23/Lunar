//
//  PageController.swift
//  Adaptivo
//
//  Created by Alin on 30/11/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Foundation

class PageController: NSPageController {
    @IBOutlet var displays: [Display]!
    @IBOutlet weak var activeStateButton: NSButton!
    
    func getButtonTitleActive() -> NSAttributedString {
        let title = "ACTIVE"
        let attr = [ NSAttributedStringKey.foregroundColor: #colorLiteral(red: 0.2732363343, green: 0.9008609056, blue: 0.4932668209, alpha: 1) ]
        return NSAttributedString(string: title, attributes: attr)
    }
    func getButtonTitleInactive() -> NSAttributedString {
        let title = "INACTIVE"
        let attr = [ NSAttributedStringKey.foregroundColor: #colorLiteral(red: 1, green: 0.0941176489, blue: 0.1686274558, alpha: 1) ]
        return NSAttributedString(string: title, attributes: attr)
    }
    
    override func viewDidLoad() {
        self.displays = [Display](brightnessAdapter.displays.values)
        
        view.wantsLayer = true
        view.layer!.cornerRadius = 12.0
        view.layer!.backgroundColor = NSColor(deviceWhite: 0.984, alpha: 1.0).cgColor
        
        let buttonSize = activeStateButton.frame
        activeStateButton.wantsLayer = true
        activeStateButton.attributedTitle = getButtonTitleActive()
        activeStateButton.attributedAlternateTitle = getButtonTitleInactive()
        activeStateButton.setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.height + 6))
        activeStateButton.layer!.backgroundColor = NSColor(deviceWhite: 1.0, alpha: 0.8).cgColor
        activeStateButton.layer!.cornerRadius = activeStateButton.frame.height / 2
        
        super.viewDidLoad()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}

