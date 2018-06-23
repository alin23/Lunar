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
    var inactiveTitle: NSMutableAttributedString?
    var activeTitleHover: NSMutableAttributedString?
    var inactiveTitleHover: NSMutableAttributedString?

    var activeTitleDisplay: NSMutableAttributedString?
    var inactiveTitleDisplay: NSMutableAttributedString?
    var activeTitleHoverDisplay: NSMutableAttributedString?
    var inactiveTitleHoverDisplay: NSMutableAttributedString?

    var activeTitleSettings: NSMutableAttributedString?
    var inactiveTitleSettings: NSMutableAttributedString?
    var activeTitleHoverSettings: NSMutableAttributedString?
    var inactiveTitleHoverSettings: NSMutableAttributedString?

    @IBOutlet var logo: NSTextField?
    @IBOutlet var activeStateButton: NSButton?
    @IBOutlet var containerView: NSView!

    @IBAction func toggleBrightnessAdapter(sender _: Any?) {
        brightnessAdapter.toggle()
    }

    func initActiveStateButton() {
        if let button = activeStateButton {
            let buttonSize = button.frame
            button.wantsLayer = true

            activeTitleDisplay = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
            activeTitleDisplay?.addAttribute(NSAttributedString.Key.foregroundColor, value: stateButtonLabelColorDisplay, range: NSMakeRange(0, activeTitleDisplay!.length - 2))
            activeTitleDisplay?.addAttribute(NSAttributedString.Key.foregroundColor, value: offButtonColor, range: NSMakeRange(activeTitleDisplay!.length - 2, 2))

            inactiveTitleDisplay = NSMutableAttributedString(attributedString: button.attributedTitle)
            inactiveTitleDisplay?.addAttribute(NSAttributedString.Key.foregroundColor, value: stateButtonLabelColorDisplay, range: NSMakeRange(0, inactiveTitleDisplay!.length - 2))
            inactiveTitleDisplay?.addAttribute(NSAttributedString.Key.foregroundColor, value: onButtonColor, range: NSMakeRange(inactiveTitleDisplay!.length - 2, 2))

            activeTitleHoverDisplay = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
            activeTitleHoverDisplay?.addAttribute(NSAttributedString.Key.foregroundColor, value: stateButtonLabelColorHoverDisplay, range: NSMakeRange(0, activeTitleHoverDisplay!.length - 2))
            activeTitleHoverDisplay?.addAttribute(NSAttributedString.Key.foregroundColor, value: offButtonColor, range: NSMakeRange(activeTitleHoverDisplay!.length - 2, 2))

            inactiveTitleHoverDisplay = NSMutableAttributedString(attributedString: button.attributedTitle)
            inactiveTitleHoverDisplay?.addAttribute(NSAttributedString.Key.foregroundColor, value: stateButtonLabelColorHoverDisplay, range: NSMakeRange(0, inactiveTitleHoverDisplay!.length - 2))
            inactiveTitleHoverDisplay?.addAttribute(NSAttributedString.Key.foregroundColor, value: onButtonColor, range: NSMakeRange(inactiveTitleHoverDisplay!.length - 2, 2))

            activeTitleSettings = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
            activeTitleSettings?.addAttribute(NSAttributedString.Key.foregroundColor, value: stateButtonLabelColorSettings, range: NSMakeRange(0, activeTitleSettings!.length - 2))
            activeTitleSettings?.addAttribute(NSAttributedString.Key.foregroundColor, value: offButtonColor, range: NSMakeRange(activeTitleSettings!.length - 2, 2))

            inactiveTitleSettings = NSMutableAttributedString(attributedString: button.attributedTitle)
            inactiveTitleSettings?.addAttribute(NSAttributedString.Key.foregroundColor, value: stateButtonLabelColorSettings, range: NSMakeRange(0, inactiveTitleSettings!.length - 2))
            inactiveTitleSettings?.addAttribute(NSAttributedString.Key.foregroundColor, value: onButtonColor, range: NSMakeRange(inactiveTitleSettings!.length - 2, 2))

            activeTitleHoverSettings = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
            activeTitleHoverSettings?.addAttribute(NSAttributedString.Key.foregroundColor, value: stateButtonLabelColorHoverSettings, range: NSMakeRange(0, activeTitleHoverSettings!.length - 2))
            activeTitleHoverSettings?.addAttribute(NSAttributedString.Key.foregroundColor, value: offButtonColor, range: NSMakeRange(activeTitleHoverSettings!.length - 2, 2))

            inactiveTitleHoverSettings = NSMutableAttributedString(attributedString: button.attributedTitle)
            inactiveTitleHoverSettings?.addAttribute(NSAttributedString.Key.foregroundColor, value: stateButtonLabelColorHoverSettings, range: NSMakeRange(0, inactiveTitleHoverSettings!.length - 2))
            inactiveTitleHoverSettings?.addAttribute(NSAttributedString.Key.foregroundColor, value: onButtonColor, range: NSMakeRange(inactiveTitleHoverSettings!.length - 2, 2))

            button.setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.height + 10))
            button.layer!.cornerRadius = button.frame.height / 2

            let area = NSTrackingArea(rect: button.visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
            button.addTrackingArea(area)
        }
    }

    override func mouseEntered(with _: NSEvent) {
        if let button = activeStateButton {
            button.layer!.add(fadeTransition(duration: 0.1), forKey: "transition")

            button.layer!.backgroundColor = stateButtonColorHover.cgColor
            button.attributedTitle = inactiveTitleHover!
            button.attributedAlternateTitle = activeTitleHover!
        }
    }

    override func mouseExited(with _: NSEvent) {
        if let button = activeStateButton {
            button.layer!.add(fadeTransition(duration: 0.2), forKey: "transition")

            button.layer!.backgroundColor = stateButtonColor.cgColor
            button.attributedTitle = inactiveTitle!
            button.attributedAlternateTitle = activeTitle!
        }
    }

    func fadeActiveStateButton() {
        if let button = activeStateButton {
            button.layer?.add(fadeTransition(duration: 0.1), forKey: "transition")
            button.attributedTitle = inactiveTitle!
            button.attributedAlternateTitle = activeTitle!
            button.layer!.backgroundColor = stateButtonColor.cgColor
        }
    }

    func hasWhiteBackground() -> Bool {
        return logo?.textColor == logoColor
    }

    func whiteBackground() {
        view.layer!.backgroundColor = bgColor.cgColor
        logo?.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        logo?.textColor = logoColor

        activeTitle = activeTitleDisplay
        inactiveTitle = inactiveTitleDisplay
        activeTitleHover = activeTitleHoverDisplay
        inactiveTitleHover = inactiveTitleHoverDisplay

        stateButtonLabelColor = stateButtonLabelColorDisplay
        stateButtonLabelColorHover = stateButtonLabelColorHoverDisplay
        stateButtonColor = stateButtonColorDisplay
        stateButtonColorHover = stateButtonColorHoverDisplay

        fadeActiveStateButton()
    }

    func yellowBackground() {
        logo?.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        logo?.textColor = bgColor

        activeTitle = activeTitleSettings
        inactiveTitle = inactiveTitleSettings
        activeTitleHover = activeTitleHoverSettings
        inactiveTitleHover = inactiveTitleHoverSettings

        stateButtonLabelColor = stateButtonLabelColorSettings
        stateButtonLabelColorHover = stateButtonLabelColorHoverSettings
        stateButtonColor = stateButtonColorSettings
        stateButtonColorHover = stateButtonColorHoverSettings

        fadeActiveStateButton()
    }

    override func viewDidLoad() {
        view.wantsLayer = true
        view.layer!.cornerRadius = 12.0
        initActiveStateButton()
        whiteBackground()
        super.viewDidLoad()
    }
}
