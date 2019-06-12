//
//  ToggleButton.swift
//  Lunar
//
//  Created by Alin on 23/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

enum HoverState: Int {
    case hover
    case noHover
}

enum Page: Int {
    case hotkeys
    case settings
    case display
}

let titleString: [AdaptiveMode: String] = [
    .sync: "Sync    ⚫︎",
    .location: "Location ⚫︎",
    .manual: "Manual  ⚫︎",
]

class ToggleButton: NSButton {
    static func getStateTitle(adaptiveMode: AdaptiveMode, hoverState: HoverState, page: Page) -> NSMutableAttributedString {
        return ToggleButton.titleWithAttributes(title: titleString[adaptiveMode]!, mode: adaptiveMode, hoverState: hoverState, page: page)
    }

    var page = Page.display
    var hoverState = HoverState.noHover
    var bgColor: CGColor {
        return stateButtonColor[hoverState]![page]!.cgColor
    }

    var labelColor: CGColor {
        return stateButtonLabelColor[hoverState]![page]!.cgColor
    }

    var buttonState: NSControl.StateValue {
        return NSControl.StateValue(rawValue: brightnessAdapter.mode.rawValue)
    }

    var buttonTitle: NSMutableAttributedString {
        return ToggleButton.getStateTitle(adaptiveMode: brightnessAdapter.mode, hoverState: hoverState, page: page)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    static func titleWithAttributes(title: String, mode: AdaptiveMode, hoverState: HoverState, page: Page) -> NSMutableAttributedString {
        let mutableTitle = NSMutableAttributedString(attributedString: NSAttributedString(string: title))
        mutableTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: stateButtonLabelColor[hoverState]![page]!, range: NSMakeRange(0, mutableTitle.length - 2))
        mutableTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: buttonDotColor[mode]!, range: NSMakeRange(mutableTitle.length - 2, 2))
        mutableTitle.setAlignment(.center, range: NSMakeRange(0, mutableTitle.length))
        return mutableTitle
    }

    func fade() {
        layer?.add(fadeTransition(duration: 0.1), forKey: "transition")
        layer?.backgroundColor = bgColor
        setTitle()
    }

    func defocus() {
        hoverState = .noHover
        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        layer?.backgroundColor = bgColor
        setTitle()
    }

    func hover() {
        hoverState = .hover
        layer?.add(fadeTransition(duration: 0.1), forKey: "transition")
        layer?.backgroundColor = bgColor
        setTitle()
    }

    func setTitle() {
        attributedTitle = buttonTitle
        attributedAlternateTitle = buttonTitle
    }

    func setup() {
        wantsLayer = true

        setFrameSize(NSSize(width: frame.width, height: frame.height + 10))
        layer?.cornerRadius = frame.height / 2
        allowsMixedState = true

        let area = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func draw(_ dirtyRect: NSRect) {
        state = buttonState
        setTitle()
        super.draw(dirtyRect)
    }
}
