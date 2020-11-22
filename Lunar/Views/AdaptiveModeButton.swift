//
//  AdaptiveModeButton.swift
//  Lunar
//
//  Created by Alin Panaitiu on 22.11.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Defaults
import Foundation

let titleString: [AdaptiveMode: String] = [
    .sync: "Sync       ⚫︎",
    .location: "Location ⚫︎",
    .manual: "Manual   ⚫︎",
    .sensor: "Sensor   ⚫︎",
]

class AdaptiveModeButton: ToggleButton {
    var adaptiveModeObserver: DefaultsObservation?
    @IBInspectable var mode: NSInteger = AdaptiveMode.manual.rawValue

    func getStateTitle(adaptiveMode: AdaptiveMode, hoverState: HoverState, page: Page) -> NSMutableAttributedString {
        return titleWithAttributes(title: titleString[self.adaptiveMode]!, mode: adaptiveMode, hoverState: hoverState, page: page)
    }

    var adaptiveMode: AdaptiveMode {
        return AdaptiveMode(rawValue: mode)!
    }

    func buttonState(_ mode: AdaptiveMode? = nil) -> NSControl.StateValue {
        return NSControl.StateValue(rawValue: ((mode ?? brightnessAdapter.mode) == adaptiveMode) ? 1 : 0)
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = Defaults.observe(.adaptiveBrightnessMode) { change in
            if change.newValue == change.oldValue {
                return
            }
            self.fade(change.newValue)
        }
    }

    func titleWithAttributes(title: String, mode: AdaptiveMode, hoverState _: HoverState, page _: Page) -> NSMutableAttributedString {
        let mutableTitle = NSMutableAttributedString(attributedString: NSAttributedString(string: title))
        mutableTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: labelColor, range: NSMakeRange(0, mutableTitle.length - 2))
        mutableTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: mode == adaptiveMode ? buttonDotColor[mode]! : labelColor,
            range: NSMakeRange(mutableTitle.length - 2, 2)
        )
        mutableTitle.setAlignment(.center, range: NSMakeRange(0, mutableTitle.length))
        return mutableTitle
    }

    func setTitle(_ mode: AdaptiveMode? = nil) {
        let buttonTitle = getStateTitle(adaptiveMode: mode ?? brightnessAdapter.mode, hoverState: hoverState, page: page)
        attributedTitle = buttonTitle
        attributedAlternateTitle = buttonTitle
    }

    func fade(_ mode: AdaptiveMode? = nil) {
        state = buttonState(mode)
        setTitle(mode)
        super.fade()
    }

    override func defocus() {
        super.defocus()
        setTitle()
    }

    override func hover() {
        super.hover()
        setTitle()
    }

    override func setup() {
        super.setup()
        listenForAdaptiveModeChange()
    }

    override func draw(_ dirtyRect: NSRect) {
        state = buttonState()
        setTitle()
        super.draw(dirtyRect)
    }
}
