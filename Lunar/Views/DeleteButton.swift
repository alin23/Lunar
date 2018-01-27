//
//  DeleteButton.swift
//  Lunar
//
//  Created by Alin on 26/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

class DeleteButton: NSButton {
    
    func setup() {
        alphaValue = 0.0
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override func mouseEntered(with event: NSEvent) {
        layer!.add(fadeTransition(duration: 0.2), forKey: "transition")
        alphaValue = 1.0
    }
    
    override func mouseExited(with event: NSEvent) {
        layer!.add(fadeTransition(duration: 0.3), forKey: "transition")
        alphaValue = 0.0
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
}
