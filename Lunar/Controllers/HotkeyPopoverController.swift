//
//  HotkeyPopoverController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 23.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Foundation

class HotkeyPopoverController: NSViewController {
    @IBOutlet var hotkeyLabel: NSTextField!
    @IBOutlet var hotkeyView: HotkeyView!
    @IBOutlet var dropdown: NSPopUpButton!

    var onClick: (() -> Void)?
    var onDropdownSelect: ((NSPopUpButton) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        view.window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }

    @IBAction func selectItem(_ sender: NSPopUpButton) {
        onDropdownSelect?(sender)
    }
}
