//
//  RemoveAppButton.swift
//  Lunar
//
//  Created by Alin on 10/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

class RemoveAppButton: NSButton {

    override func draw(_ dirtyRect: NSRect) {
        wantsLayer = true
        
        setFrameSize(NSSize(width: 14, height: 14))
        layer!.cornerRadius = 7
        layer!.backgroundColor = removeButtonColor.cgColor
        
        
        super.draw(dirtyRect)
    }
    
}
