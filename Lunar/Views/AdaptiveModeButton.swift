//
//  AdaptiveModeButton.swift
//  Lunar
//
//  Created by Alin Panaitiu on 22.11.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Combine
import Defaults
import Foundation

class AdaptiveModeButton: NSPopUpButton, NSMenuItemValidation {
    // MARK: Lifecycle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Internal

    let defaultAutoModeTitle = "Auto Mode"
    var adaptiveModeObserver: Cancellable?
    var pausedAdaptiveModeObserver = false

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = adaptiveModeObserver ?? adaptiveBrightnessModePublisher.sink { [weak self] change in
            mainAsync {
                guard let self = self, !self.pausedAdaptiveModeObserver else { return }
                self.pausedAdaptiveModeObserver = true
                Defaults.withoutPropagation { self.update(modeKey: change.newValue) }
                self.pausedAdaptiveModeObserver = false
            }
        }
    }

    func setAutoModeItemTitle(modeKey: AdaptiveModeKey? = nil) {
        if CachedDefaults[.overrideAdaptiveMode] {
            if let item = lastItem {
                item.title = defaultAutoModeTitle
            }
        } else {
            let modeKey = modeKey ?? DisplayController.getAdaptiveMode().key
            if let item = lastItem {
                item.title = defaultAutoModeTitle.replacingOccurrences(of: "Auto Mode", with: "Auto: \(modeKey.str)")
            }
        }
    }

    func update(modeKey: AdaptiveModeKey? = nil) {
        if CachedDefaults[.overrideAdaptiveMode] {
            selectItem(withTag: (modeKey ?? CachedDefaults[.adaptiveBrightnessMode]).rawValue)
        } else {
            selectItem(withTag: AUTO_MODE_TAG)
        }
        setAutoModeItemTitle(modeKey: modeKey)
        // fade(modeKey: modeKey)
    }

    func setup() {
        action = #selector(setAdaptiveMode(sender:))
        target = self
        listenForAdaptiveModeChange()
        radius = (frame.height / 2).ns

        update()
    }

    @IBAction func setAdaptiveMode(sender button: AdaptiveModeButton?) {
        guard let button = button else { return }
        if let mode = AdaptiveModeKey(rawValue: button.selectedTag()) {
            if !mode.available {
                log.warning("Mode \(mode) not available!")
                button
                    .selectItem(withTag: CachedDefaults[.overrideAdaptiveMode] ? displayController.adaptiveModeKey.rawValue : AUTO_MODE_TAG)
            } else {
                log.debug("Changed mode to \(mode)")
                CachedDefaults[.overrideAdaptiveMode] = true
                CachedDefaults[.adaptiveBrightnessMode] = mode
            }
        } else if button.selectedTag() == AUTO_MODE_TAG {
            CachedDefaults[.overrideAdaptiveMode] = false

            let mode = DisplayController.getAdaptiveMode()
            log.debug("Changed mode to Auto: \(mode)")
            CachedDefaults[.adaptiveBrightnessMode] = mode.key
        }
        button.setAutoModeItemTitle()
        // button.fade(modeKey: AdaptiveModeKey(rawValue: button.selectedTag()))
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.tag == AUTO_MODE_TAG {
            return true
        }

        guard let mode = AdaptiveModeKey(rawValue: menuItem.tag) else {
            return false
        }

        guard mode.available else {
            switch mode {
            case .location:
                if lunarProActive {
                    menuItem
                        .toolTip =
                        "Disabled because location can't be requested.\nCheck if Lunar has access to Location Services in System Preferences -> Security & Privacy"
                } else {
                    menuItem.toolTip = "Disabled because Lunar Pro is not activated."
                }
            case .sensor:
                if lunarProActive {
                    menuItem.toolTip = "Disabled because there is no external light sensor connected to this \(Sysctl.device)"
                } else {
                    menuItem.toolTip = "Disabled because Lunar Pro is not activated."
                }
            case .sync:
                if lunarProActive {
                    menuItem.toolTip = "Disabled because no source display was found"
                } else {
                    menuItem.toolTip = "Disabled because Lunar Pro is not activated."
                }
            case .clock:
                menuItem.toolTip = "Disabled because Lunar Pro is not activated."
            default:
                break
            }
            return false
        }
        menuItem.toolTip = nil
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
