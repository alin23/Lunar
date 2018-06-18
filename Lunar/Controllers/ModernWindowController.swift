//
//  ModernWindowController.swift
//  Lunar
//
//  Created by Alin on 04/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class ModernWindowController: NSWindowController, NSWindowDelegate {
    var observer: NSKeyValueObservation?

    func setupWindow() {
        if let w = window as? ModernWindow {
            w.delegate = self
            w.setup()
        }
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        setupWindow()
    }

    func windowWillClose(_: Notification) {
        log.info("Window closing")
        upHotkey = nil
        downHotkey = nil
    }
}
