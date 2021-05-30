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
    override var popoverKey: PopoverKey {
        .hotkey
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        super.mouseDown(with: event)
    }
}
