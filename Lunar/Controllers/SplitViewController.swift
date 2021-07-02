//
//  SplitViewController.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Combine
import Defaults

let NOTE_TEXT = """
[]()

**Note:** The same logic applies for both brightness and contrast
"""
let SENSOR_HELP_TEXT = """
# Sensor Mode

With an external ambient light sensor

\(NOTE_TEXT)
"""
let LOCATION_HELP_TEXT = """
# Location Mode

In `Location` mode, Lunar adjusts the brightness and contrast automatically
based on the sun elevation in the sky, at your location.

The location detection uses the system **Location Services**, but the user needs
to give Lunar permission to access it.

If this fails, Lunar will try to find a rough location through a **GeoIP** service like [ipstack.com](https://ipstack.com).

## Algorithm

1. Lunar starts by setting the brightness to a minimum at night
2. Then, from sunrise to noon, the brightness is raised gradually until it reaches the `MAX` setting at noon
3. After noon, Lunar lowers the brightness gradually until it reaches the `MIN` setting again at sunset

[]()

## Settings
- Adjusting the curve is as simple as changing the brightness to whatever you want it to be at that time of the day
    - Lunar will learn from that and adjust the curve accordingly
- The `Curve Factor` on the `Configuration` page helps to adjust how fast the brightness should rise or fall between thresholds

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

## Settings
- Adjusting the curve is as simple as changing the brightness of an external monitor to whatever you want it to be
    - Lunar will learn from that and adjust the curve accordingly
- The `Curve Factor` on the `Configuration` page helps to adjust how fast the brightness should rise or fall between thresholds

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
- `Brightness/Contrast Step` adjusts how much to increase or decrease the values when using the up/down hotkeys

\(NOTE_TEXT)
"""

let AUTO_MODE_TAG = 99

class SplitViewController: NSSplitViewController {
    var adaptiveModeObserver: Cancellable?
    var defaultAutoModeTitle: NSAttributedString?

    @IBOutlet var logo: NSTextField?

    @IBOutlet var containerView: NSView?

    @IBOutlet var activeModeButton: AdaptiveModeButton!
    @IBOutlet var _activeHelpButton: NSButton!
    var activeHelpButton: HelpButton? {
        _activeHelpButton as? HelpButton
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

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            do { log.verbose("END DEINIT") }
        #endif
    }

    var pausedAdaptiveModeObserver: Bool = false
    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = adaptiveBrightnessModePublisher.sink { [weak self] change in
            guard let self = self, !self.pausedAdaptiveModeObserver else {
                return
            }
            mainThread {
                self.pausedAdaptiveModeObserver = true
                Defaults.withoutPropagation {
                    self.activeModeButton.update(modeKey: change.newValue)
                    self.updateHelpButton(modeKey: change.newValue)
                }
                self.pausedAdaptiveModeObserver = false
            }
        }
    }

    func updateHelpButton(modeKey: AdaptiveModeKey? = nil) {
        guard let button = activeHelpButton, let modeButton = activeModeButton else { return }

        if CachedDefaults[.overrideAdaptiveMode] {
            button.helpText = (modeKey ?? displayController.adaptiveModeKey).helpText
            button.link = (modeKey ?? displayController.adaptiveModeKey).helpLink
        } else {
            let mode = DisplayController.getAdaptiveMode()
            button.helpText = mode.key.helpText
            button.link = mode.key.helpLink
        }
        button.setFrameOrigin(NSPoint(x: modeButton.frame.minX - (button.frame.width + 10), y: button.frame.minY))
    }

    func hasWhiteBackground() -> Bool {
        view.layer?.backgroundColor == white.cgColor
    }

    func lastPage() {
        goLeftButton.enable()
        goRightButton.disable()
    }

    func whiteBackground() {
        view.transition(0.2)
//        view.bg = white
        if let logo = logo {
            logo.transition(0.2)
            logo.textColor = logoColor
            logo.stringValue = "LUNAR"
        }

        activeModeButton?.page = .display
        activeModeButton?.fade()

        POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantLight)

        goLeftButton.enable()
        goRightButton.enable()
    }

    func yellowBackground() {
//        view.bg = bgColor
        if let logo = logo {
            logo.transition(0.2)
            logo.textColor = bgColor
            logo.stringValue = "SETTINGS"
        }

        activeModeButton?.page = .settings
        activeModeButton?.fade()

        POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantLight)

        goLeftButton.enable()
        goRightButton.enable()
    }

    func mauveBackground() {
//        view.bg = hotkeysBgColor
        if let logo = logo {
            logo.transition(0.2)
            logo.textColor = logoColor
            logo.stringValue = "HOTKEYS"
        }

        activeModeButton?.page = .hotkeys
        activeModeButton?.fade()

        POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantDark)

        goLeftButton.disable()
        goRightButton.enable(color: logoColor)
    }

    override func viewDidLoad() {
        view.wantsLayer = true
        view.radius = 12.0.ns
        view.bg = white
        whiteBackground()
        updateHelpButton()
        listenForAdaptiveModeChange()

        super.viewDidLoad()
    }
}
