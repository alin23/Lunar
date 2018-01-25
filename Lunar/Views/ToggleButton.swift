//
//  ToggleButton.swift
//  Lunar
//
//  Created by Alin on 23/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class ToggleButton: NSButton {
    
    func getButtonState() -> NSControl.StateValue {
        if brightnessAdapter.running {
            return .on
        } else {
            return .off
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        state = getButtonState()
        super.draw(dirtyRect)
    }
    
}
