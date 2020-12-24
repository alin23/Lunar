//
//  HotkeyButton.swift
//  Lunar
//
//  Created by Alin Panaitiu on 23.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Foundation

class HotkeyButton: PopoverButton<HotkeyPopoverController> {
    @IBInspectable var label: String = ""
    override var popoverKey: PopoverKey {
        return .hotkey
    }

    override func mouseDown(with event: NSEvent) {
        if !label.isEmpty, let c = popoverController {
            c.hotkeyLabel?.stringValue = label
        }
        super.mouseDown(with: event)
    }
}
