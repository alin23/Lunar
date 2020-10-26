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
    .sync: "Sync       ⚫︎",
    .location: "Location ⚫︎",
    .manual: "Manual   ⚫︎",
    .sensor: "Sensor   ⚫︎",
]

class ToggleButton: NSButton {
    var adaptiveModeObserver: NSKeyValueObservation?

    @IBInspectable var mode: NSInteger = AdaptiveMode.manual.rawValue

    func getStateTitle(adaptiveMode: AdaptiveMode, hoverState: HoverState, page: Page) -> NSMutableAttributedString {
        return titleWithAttributes(title: titleString[self.adaptiveMode]!, mode: adaptiveMode, hoverState: hoverState, page: page)
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

    var adaptiveMode: AdaptiveMode {
        return AdaptiveMode(rawValue: self.mode)!
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func mouseEntered(with _: NSEvent) {
        hover()
    }

    override func mouseExited(with _: NSEvent) {
        defocus()
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = datastore.defaults.observe(\.adaptiveBrightnessMode, options: [.old, .new], changeHandler: { _, change in
            guard let mode = change.newValue, let oldMode = change.oldValue, mode != oldMode else {
                return
            }
            self.fade(AdaptiveMode(rawValue: mode) ?? .sync)
        })
    }

    func titleWithAttributes(title: String, mode: AdaptiveMode, hoverState: HoverState, page: Page) -> NSMutableAttributedString {
        let mutableTitle = NSMutableAttributedString(attributedString: NSAttributedString(string: title))
        mutableTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: stateButtonLabelColor[hoverState]![page]!, range: NSMakeRange(0, mutableTitle.length - 2))
        mutableTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: mode == adaptiveMode ? buttonDotColor[mode]! : stateButtonLabelColor[hoverState]![page]!, range: NSMakeRange(mutableTitle.length - 2, 2))
        mutableTitle.setAlignment(.center, range: NSMakeRange(0, mutableTitle.length))
        return mutableTitle
    }

    func fade(_ mode: AdaptiveMode? = nil) {
        layer?.add(fadeTransition(duration: 0.1), forKey: "transition")
        layer?.backgroundColor = bgColor
        setTitle(mode)
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

    func setTitle(_ mode: AdaptiveMode? = nil) {
        let buttonTitle = getStateTitle(adaptiveMode: mode ?? brightnessAdapter.mode, hoverState: hoverState, page: page)
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
        listenForAdaptiveModeChange()
    }

    override func draw(_ dirtyRect: NSRect) {
        state = buttonState
        setTitle()
        super.draw(dirtyRect)
    }
}
