//
//  SplitViewController.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class SplitViewController: NSSplitViewController {
    var activeTitle: NSMutableAttributedString?
    var activeTitleHover: NSMutableAttributedString?

    @IBOutlet var logo: NSTextField?
    @IBOutlet var activeStateButton: ToggleButton?
    @IBOutlet var containerView: NSView?

    @IBAction func toggleBrightnessAdapter(sender _: NSButton?) {
        brightnessAdapter.toggle()
    }

    override func mouseEntered(with _: NSEvent) {
        activeStateButton?.hover()
    }

    override func mouseExited(with _: NSEvent) {
        activeStateButton?.defocus()
    }

    func hasWhiteBackground() -> Bool {
        return view.layer?.backgroundColor == white.cgColor
    }

    func whiteBackground() {
        view.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        view.layer?.backgroundColor = white.cgColor
        if let logo = logo {
            logo.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
            logo.textColor = logoColor
            logo.stringValue = "LUNAR"
        }
        activeStateButton?.page = .display
        activeStateButton?.fade()
    }

    func yellowBackground() {
        view.layer?.backgroundColor = bgColor.cgColor
        if let logo = logo {
            logo.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
            logo.textColor = bgColor
            logo.stringValue = "LUNAR"
        }
        activeStateButton?.page = .settings
        activeStateButton?.fade()
    }

    func mauveBackground() {
        view.layer?.backgroundColor = mauve.cgColor
        if let logo = logo {
            logo.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
            logo.textColor = logoColor
            logo.stringValue = "HOTKEYS"
        }
        activeStateButton?.page = .hotkeys
        activeStateButton?.fade()
    }

    override func viewDidLoad() {
        view.wantsLayer = true
        view.layer?.cornerRadius = 12.0
        whiteBackground()
        super.viewDidLoad()
    }
}
