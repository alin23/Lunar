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

class AdaptiveModeButton: PopUpButton, NSMenuItemValidation {
    var defaultAutoModeTitle: NSAttributedString!
    var adaptiveModeObserver: DefaultsObservation?
    var pausedAdaptiveModeObserver: Bool = false

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = adaptiveModeObserver ?? Defaults.observe(.adaptiveBrightnessMode) { [weak self] change in
            guard let self = self, !self.pausedAdaptiveModeObserver, change.newValue != change.oldValue else { return }
            mainThread {
                self.pausedAdaptiveModeObserver = true
                self.update()
                self.pausedAdaptiveModeObserver = false
            }
        }
    }

    override func defocus() {
        super.defocus()
    }

    override func hover() {
        super.hover()
    }

    func setAutoModeItemTitle(modeKey: AdaptiveModeKey? = nil) {
        if Defaults[.overrideAdaptiveMode] {
            if let buttonTitle = defaultAutoModeTitle, let item = lastItem {
                item.attributedTitle = buttonTitle
            }
        } else {
            let modeKey = modeKey ?? DisplayController.getAdaptiveMode().key
            if let buttonTitle = defaultAutoModeTitle, let item = lastItem {
                item.attributedTitle = buttonTitle.string.replacingOccurrences(of: " Mode", with: ": \(modeKey.str) Mode").attributedString
            }
        }
    }

    func update(modeKey: AdaptiveModeKey? = nil) {
        if Defaults[.overrideAdaptiveMode] {
            selectItem(withTag: (modeKey ?? Defaults[.adaptiveBrightnessMode]).rawValue)
        } else {
            selectItem(withTag: AUTO_MODE_TAG)
        }
        setAutoModeItemTitle(modeKey: modeKey)
        fade()
    }

    override func setup() {
        super.setup()

        defaultAutoModeTitle = lastItem?.attributedTitle
        action = #selector(setAdaptiveMode(sender:))
        target = self
        listenForAdaptiveModeChange()

        update()
    }

    @IBAction func setAdaptiveMode(sender button: AdaptiveModeButton?) {
        guard let button = button else { return }
        if let mode = AdaptiveModeKey(rawValue: button.selectedTag()) {
            if !mode.available {
                log.warning("Mode \(mode) not available!")
                button.selectItem(withTag: Defaults[.overrideAdaptiveMode] ? displayController.adaptiveModeKey.rawValue : AUTO_MODE_TAG)
            } else {
                log.debug("Changed mode to \(mode)")
                Defaults[.overrideAdaptiveMode] = true
                Defaults[.adaptiveBrightnessMode] = mode
            }
        } else if button.selectedTag() == AUTO_MODE_TAG {
            Defaults[.overrideAdaptiveMode] = false

            let mode = DisplayController.getAdaptiveMode()
            log.debug("Changed mode to Auto: \(mode)")
            Defaults[.adaptiveBrightnessMode] = mode.key
        }
        button.setAutoModeItemTitle()
        button.fade()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.tag == AUTO_MODE_TAG {
            return true
        }

        guard let mode = AdaptiveModeKey(rawValue: menuItem.tag) else {
            return false
        }
        return mode.available
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
