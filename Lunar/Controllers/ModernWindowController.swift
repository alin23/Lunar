//
//  ModernWindowController.swift
//  Lunar
//
//  Created by Alin on 04/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Magnet

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

        if helpPopover.contentViewController == nil {
            var storyboard: NSStoryboard?
            if #available(OSX 10.13, *) {
                storyboard = NSStoryboard.main
            } else {
                storyboard = NSStoryboard(name: "Main", bundle: nil)
            }

            helpPopover.contentViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("HelpPopoverController")) as! HelpPopoverController
            helpPopover.contentViewController!.loadView()
        }
    }

    func windowWillClose(_: Notification) {
        log.info("Window closing")

        log.debug("Unregistering up/down hotkeys")
        HotKeyCenter.shared.unregisterHotKey(with: "increaseValue")
        HotKeyCenter.shared.unregisterHotKey(with: "decreaseValue")
        upHotkey?.unregister()
        downHotkey?.unregister()
        upHotkey = nil
        downHotkey = nil

        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.setupHotkeys(enable: false)
        }
        helpPopover.contentViewController = nil
    }
}
