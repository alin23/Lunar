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
    @IBOutlet var activeStateButton: ToggleButton!
    @IBOutlet var containerView: NSView!

    @IBAction func toggleBrightnessAdapter(sender _: NSButton?) {
        brightnessAdapter.toggle()
    }

    override func mouseEntered(with _: NSEvent) {
        activeStateButton.hover()
    }

    override func mouseExited(with _: NSEvent) {
        activeStateButton.defocus()
    }

    func hasWhiteBackground() -> Bool {
        return logo?.textColor == logoColor
    }

    func whiteBackground() {
        view.layer!.backgroundColor = bgColor.cgColor
        logo?.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        logo?.textColor = logoColor
        activeStateButton.page = .display
        activeStateButton.fade()
    }

    func yellowBackground() {
        logo?.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        logo?.textColor = bgColor
        activeStateButton.page = .settings
        activeStateButton.fade()
    }

    override func viewDidLoad() {
        view.wantsLayer = true
        view.layer!.cornerRadius = 12.0
        whiteBackground()
        super.viewDidLoad()
    }
}
