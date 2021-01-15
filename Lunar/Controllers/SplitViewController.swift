//
//  SplitViewController.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Defaults

let NOTE_TEXT = """
[]()

**Note:** The same logic applies for both brightness and contrast
"""
let SENSOR_HELP_TEXT = """
# Sensor Mode

To do..

\(NOTE_TEXT)
"""
let LOCATION_HELP_TEXT = """
# Location Mode

In `Location` mode, Lunar adjusts the brightness and contrast automatically
using the **sunrise**, **noon** and **sunset** times of your location.

The location detection uses the system **Location Services**, but the user needs
to give Lunar permission to access it.

If this fails, Lunar will try to find a rough location through a **GeoIP** service like [ipstack.com](https://ipstack.com).

## Algorithm

1. Lunar starts by setting the brightness to a minimum at night
2. Then, from sunrise to noon, the brightness is raised gradually until it reaches the `MAX` setting at noon
3. After noon, Lunar lowers the brightness gradually until it reaches the `MIN` setting again at sunset

[]()

## Settings
- Sunrise and sunset times can be offset by adjusting the `Daylight Extension` setting
    - A higher daylight extension value will mean that, for Lunar, the sun will rise earlier and will set later
- The noon period can be enlarged by adjusting the `Noon Duration` setting
    - A higher noon duration will mean that the brightness will stay at `MAX` longer
- The `Curve Factor` helps to adjust how fast the brightness should rise or fall between sunrise, noon and sunset

\(NOTE_TEXT)
"""
let SYNC_HELP_TEXT = """
# Sync Mode

`Sync` refers to the algorithm that Lunar uses to synchronize the brightness
from the built-in display of a Mac device to the external monitors' brightness.

The built-in display of a Macbook is always adapted to the ambient light
using the Ambient Light Sensor near the camera.

Lunar takes advantage of that by periodically reading the display brightness,
and sending it to the external monitors.

## Algorithm

1. Every second, Lunar reads the built-in display brightness and compares it to the monitor brightness
2. If the built-in brightness has changed, the value is passed through an adaptive algorithm to bring it to a better suited value for each monitor
3. After adapting the brightness value, Lunar will set the brightness for each monitor based on their settings

[]()

**Note:** This makes the brightness keys on the keyboard work for both the built-in display and the monitors at the same time.

## Settings

- The `Brightness/Contrast Offset` setting models how the built-in brightness relates to the monitor brightness.
    - **Example if the built-in brightness goes from 0% to 100%**
        - A **negative** offset will make the monitor brightness rise **slow** for the **first** half (*until the built-in brightness reaches ~50%*) and rise **fast** for the **second** half
        - A **positive** offset will make the monitor brightness rise **fast** for the **first** half and then rise **slow** for the **second** half

\(NOTE_TEXT)
"""
let MANUAL_HELP_TEXT = """
# Manual Mode

The adaptive algorithm is disabled in `Manual` mode, but Lunar provides useful hotkeys
to control all the monitors' brightness and contrast from your keyboard.

This mode is the last resort for people that:
1. Don't have a built-in display (*Mac Mini*)
2. Don't use the built-in display (*Macbook with lid closed*)
3. Work in an environment without much natural light (*where Location mode is useless*)
4. Don't have an Ambient Light Sensor (*Hackintosh*)
5. Don't trust machines to do their work `¯\\_(ツ)_/¯`

[]()

## Algorithm

1. Percentage Hotkeys: `0%`, `25%`, `50%`, `75%`, `100%`
    - When one of these hotkeys is pressed, Lunar computes the brightness
      by taking into account the `MIN` and `MAX` limits
    - **Example:**
        - `MIN` Brightness = 15
        - `MAX` Brightness = 100
        - `MIN` Contrast = 40
        - `MAX` Contrast = 75
        - `25%` hotkey is pressed
    - **The monitor will get**:
        - `brightness = 25% * (100 - 15) + 15 = ` **36**
        - `contrast = 25% * (75 - 40) + 40 = ` **49**
2. Brightness/Contrast Up/Down Hotkeys
    - When the brightness is adjusted using these hotkeys, it will stay within the `MIN` and `MAX` global limits

[]()

## Settings

- `Brightness/Contrast Limit` restricts the computed values to always stay between these limits
- `Brightness/Contrast Step` adjusts how much to increase or decrease the values when using the up/down hotkeys

\(NOTE_TEXT)
"""

let AUTO_MODE_TAG = 99

class SplitViewController: NSSplitViewController {
    var adaptiveModeObserver: DefaultsObservation?
    var defaultAutoModeTitle: NSAttributedString?

    @IBOutlet var logo: NSTextField?

    @IBOutlet var containerView: NSView?

    @IBOutlet var activeModeButton: PopUpButton!
    @IBOutlet var _activeHelpButton: NSButton!
    var activeHelpButton: HelpButton? {
        _activeHelpButton as? HelpButton
    }

    @IBOutlet var _navigationHelpButton: NSButton?
    var navigationHelpButton: HelpButton? {
        _navigationHelpButton as? HelpButton
    }

    @IBOutlet var goLeftButton: PageButton!
    @IBOutlet var goRightButton: PageButton!

    var onLeftButtonPress: (() -> Void)?
    var onRightButtonPress: (() -> Void)?

    @IBAction func goRight(_: Any) {
        onRightButtonPress?()
    }

    @IBAction func goLeft(_: Any) {
        onLeftButtonPress?()
    }

    @IBAction func toggleDisplayController(sender button: PopUpButton?) {
        guard let button = button else { return }
        if let mode = AdaptiveModeKey(rawValue: button.selectedTag()) {
            log.debug("Changed mode to \(mode)")
            Defaults[.overrideAdaptiveMode] = true
            Defaults[.adaptiveBrightnessMode] = mode

            setHelpButtonText(modeKey: mode)
            button.lastItem?.attributedTitle = defaultAutoModeTitle
        } else if button.selectedTag() == AUTO_MODE_TAG {
            Defaults[.overrideAdaptiveMode] = false

            let mode = DisplayController.getAdaptiveMode()
            log.debug("Changed mode to Auto: \(mode)")
            Defaults[.adaptiveBrightnessMode] = mode.key

            setHelpButtonText(modeKey: mode.key)
            if let buttonTitle = defaultAutoModeTitle, let item = button.lastItem {
                item.attributedTitle = buttonTitle.string.replacingOccurrences(of: " Mode", with: ": \(mode.str) Mode").attributedString
            }
        }
        activeModeButton.fade()
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = Defaults.observe(.adaptiveBrightnessMode) { change in
            if change.newValue == change.oldValue {
                return
            }
            self.setupModeButton()
        }
    }

    func setupModeButton() {
        guard let button = activeModeButton else { return }

        if Defaults[.overrideAdaptiveMode] {
            button.selectItem(withTag: Defaults[.adaptiveBrightnessMode].rawValue)
            setHelpButtonText()
            if let buttonTitle = defaultAutoModeTitle, let item = button.lastItem {
                item.attributedTitle = buttonTitle
            }
        } else {
            let mode = DisplayController.getAdaptiveMode()
            setHelpButtonText(modeKey: mode.key)
            if let buttonTitle = defaultAutoModeTitle, let item = button.lastItem {
                item.attributedTitle = buttonTitle.string.replacingOccurrences(of: " Mode", with: ": \(mode.str) Mode").attributedString
            }
            button.selectItem(withTag: AUTO_MODE_TAG)
        }
        button.fade()
    }

    func setHelpButtonText(modeKey: AdaptiveModeKey? = nil) {
        activeHelpButton?.helpText = (modeKey ?? displayController.adaptiveModeKey).helpText
        activeHelpButton?.link = (modeKey ?? displayController.adaptiveModeKey).helpLink
    }

    func hasWhiteBackground() -> Bool {
        return view.layer?.backgroundColor == white.cgColor
    }

    func lastPage() {
        goLeftButton.enable()
        goRightButton.disable()
    }

    func whiteBackground() {
        view.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        view.layer?.backgroundColor = white.cgColor
        if let logo = logo {
            logo.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
            logo.textColor = logoColor
            logo.stringValue = "LUNAR"
        }

        activeModeButton?.page = .display
        activeModeButton?.fade()

        POPOVERS[.help]!?.appearance = NSAppearance(named: .vibrantLight)

        goLeftButton.enable()
        goRightButton.enable()
    }

    func yellowBackground() {
        view.layer?.backgroundColor = bgColor.cgColor
        if let logo = logo {
            logo.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
            logo.textColor = bgColor
            logo.stringValue = "SETTINGS"
        }

        activeModeButton?.page = .settings
        activeModeButton?.fade()

        POPOVERS[.help]!?.appearance = NSAppearance(named: .vibrantLight)

        goLeftButton.enable()
        goRightButton.enable()
    }

    func mauveBackground() {
        view.layer?.backgroundColor = hotkeysBgColor.cgColor
        if let logo = logo {
            logo.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
            logo.textColor = logoColor
            logo.stringValue = "HOTKEYS"
        }

        activeModeButton?.page = .hotkeys
        activeModeButton?.fade()

        POPOVERS[.help]!?.appearance = NSAppearance(named: .vibrantDark)

        goLeftButton.disable()
        goRightButton.enable(color: logoColor)
    }

    override func viewDidLoad() {
        view.wantsLayer = true
        view.layer?.cornerRadius = 12.0
        whiteBackground()
        setHelpButtonText()
        navigationHelpButton?.onMouseEnter = {
            Defaults[.showNavigationHints] = true
        }
        navigationHelpButton?.onMouseExit = {
            Defaults[.showNavigationHints] = false
        }

        defaultAutoModeTitle = activeModeButton?.lastItem?.attributedTitle
        setupModeButton()
        listenForAdaptiveModeChange()

        super.viewDidLoad()
    }
}
