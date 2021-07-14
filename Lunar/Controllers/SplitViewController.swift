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
**Note:** The same logic applies for both brightness and contrast
"""
let SENSOR_HELP_TEXT = """
# Sensor Mode

In `Sensor` mode, Lunar will read the ambient light from an external light sensor and adapt the brightness and contrast of the monitors based on the lux value.

You can configure how often Lunar reacts to the ambient light changes by changing the `Polling Interval` on the `Configuration` page.

## Algorithm

1. **Every 2 seconds** the sensor will send the lux value of the ambient light to Lunar
1. Lunar will compare the received lux to the last value
1. If the new value is different, it is passed through the **Curve Algorithm** to compute the best brightness for each monitor
1. After computing the monitor values, Lunar will set the brightness for each monitor based on their settings

*The 2 seconds interval is user configurable to any value greater or equal to 1 second.*

## Settings

- Adjusting the curve is as simple as changing the brightness of an external monitor to whatever you want it to be
    - Lunar will learn from that and adjust the curve accordingly
- The `Curve Factor` on the `Configuration` page helps to adjust how fast the brightness should rise or fall between thresholds

\(NOTE_TEXT)
"""
let LOCATION_HELP_TEXT = """
# Location Mode

In `Location` mode, Lunar adjusts the brightness and contrast automatically based on the sun elevation in the sky, at your location.

The location detection uses the system **Location Services**, but the user needs to give Lunar permission to access it.

If this fails, Lunar will try to find a rough location through a **GeoIP** service like [ipstack.com](https://ipstack.com).

## Algorithm

1. Lunar starts by setting the brightness to a minimum at night
1. Then, from sunrise to noon, the brightness is raised gradually until it reaches the `MAX` setting at noon
1. After noon, Lunar lowers the brightness gradually until it reaches the `MIN` setting again at sunset

## Settings

- Adjusting the curve is as simple as changing the brightness to whatever you want it to be at that time of the day
    - Lunar will learn from that and adjust the curve accordingly
- The `Curve Factor` on the `Configuration` page helps to adjust how fast the brightness should rise or fall between thresholds

\(NOTE_TEXT)
"""
let SYNC_HELP_TEXT = """
# Sync Mode

`Sync` refers to the algorithm that Lunar uses to synchronize the brightness from the built-in display of a Mac device to the external monitors' brightness.

The built-in display of a Macbook is always adapted to the ambient light using the Ambient Light Sensor near the camera.

Lunar takes advantage of that by periodically reading the display brightness, and sending it to the external monitors.

## Algorithm

1. **Every 2 seconds** the display brightness is read and compared to the last value
1. If the brightness has changed, Lunar starts a **fast polling** process where the brightness is read every **100ms**
1. The built-in brightness is passed through the **Curve Algorithm** to bring it to a better suited value for each monitor
1. After computing the brightness value, Lunar will set the brightness for each monitor based on their settings
1. If **no new brightness** change has been detected in the **last 3 seconds**, Lunar switches back to the efficient polling interval of **2 seconds**

*The 2 seconds interval is user configurable to any value greater or equal to 1 second.*

## Settings

- Adjusting the curve is as simple as changing the brightness of an external monitor to whatever you want it to be
    - Lunar will learn from that and adjust the curve accordingly
- The `Curve Factor` on the `Configuration` page helps to adjust how fast the brightness should rise or fall between thresholds

\(NOTE_TEXT)
"""
let MANUAL_HELP_TEXT = """
# Manual Mode

The adaptive algorithm is disabled in `Manual` mode, but Lunar provides useful hotkeys to control all the monitors' brightness and contrast from your keyboard.

This mode is the last resort for people that:

1. Don't have a built-in display (*Mac Mini*)
1. Don't use the built-in display (*Macbook with lid closed*)
1. Work in an environment without much natural light (*where Location mode is useless*)
1. Don't have an Ambient Light Sensor (*Hackintosh*)
1. Don't trust machines to do their work

## Algorithm

1. Percentage Hotkeys: `0%`, `25%`, `50%`, `75%`, `100%`
	- When one of these hotkeys is pressed, Lunar computes the brightness by taking into account the `MIN` and `MAX` limits.
1. Brightness/Contrast Up/Down Hotkeys
	- When the brightness is adjusted using these hotkeys, it will stay within the `MIN` and `MAX` global limits.

##### Percentage Hotkeys Example:
- `MIN` Brightness = 15
- `MAX` Brightness = 100
- `MIN` Contrast = 40
- `MAX` Contrast = 75
- `25%` hotkey is pressed
- **The monitor will get**:
	- `brightness = 25% * (100 - 15) + 15 =` **36**
	- `contrast = 25% * (75 - 40) + 40 =` **49**

## Settings
- `Brightness/Contrast Step` adjusts how much to increase or decrease the values when using the up/down hotkeys

\(NOTE_TEXT)
"""

let AUTO_MODE_TAG = 99
var leftHintsShown = false
var rightHintsShown = false

class SplitViewController: NSSplitViewController {
    @objc dynamic var version = "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4")"
    var adaptiveModeObserver: Cancellable?
    var defaultAutoModeTitle: NSAttributedString?

    @IBOutlet var logo: NSTextField?

    @IBOutlet var containerView: NSView?

    @IBOutlet var activeModeButton: AdaptiveModeButton!
    @IBOutlet var _activeHelpButton: NSButton!
    var activeHelpButton: HelpButton? {
        _activeHelpButton as? HelpButton
    }

    @IBOutlet var goLeftButton: PageButton?
    @IBOutlet var goRightButton: PageButton?
    @IBOutlet var goLeftNotice: NSTextField?
    @IBOutlet var goRightNotice: NSTextField?

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

    var overrideAdaptiveModeObserver: Cancellable?
    var pausedAdaptiveModeObserver: Bool = false

    func listenForAdaptiveModeChange() {
        overrideAdaptiveModeObserver = overrideAdaptiveModePublisher.sink { [weak self] _ in
            guard let self = self, let button = self.activeModeButton else { return }

            mainThread {
                Defaults.withoutPropagation {
                    button.update()
                    self.updateHelpButton()
                }
            }
        }

        adaptiveModeObserver = adaptiveBrightnessModePublisher.sink { [weak self] change in
            guard let self = self, !self.pausedAdaptiveModeObserver,
                  let button = self.activeModeButton
            else {
                return
            }

            mainThread {
                self.pausedAdaptiveModeObserver = true
                Defaults.withoutPropagation {
                    button.update(modeKey: change.newValue)
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
        goLeftButton?.enable()
        goRightButton?.disable()
        if thisIsFirstRun || thisIsFirstRunAfterM1DDCUpgrade {
            rightHintsShown = true
        }
    }

    func whiteBackground() {
        view.transition(0.2)
        if let logo = logo {
            logo.transition(0.2)
            logo.textColor = logoColor
            logo.stringValue = "LUNAR"
        }

        activeModeButton?.page = .display
        activeModeButton?.fade()

        POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantLight)

        if thisIsFirstRun || thisIsFirstRunAfterM1DDCUpgrade {
            if !leftHintsShown {
                goLeftNotice?.stringValue = "Click to go to the\nConfiguration page"
            }
            if !rightHintsShown {
                goRightNotice?.stringValue = "Click to configure\nthe next monitor"
            }
        }

        goLeftButton?.enable()
        goRightButton?.enable()
    }

    func yellowBackground() {
        if let logo = logo {
            logo.transition(0.2)
            logo.textColor = bgColor
            logo.stringValue = "SETTINGS"
        }

        activeModeButton?.page = .settings
        activeModeButton?.fade()

        POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantLight)

        goLeftButton?.enable()
        goRightButton?.enable()

        if thisIsFirstRun || thisIsFirstRunAfterM1DDCUpgrade {
            if !leftHintsShown {
                goLeftNotice?.stringValue = "Click to go to the\nHotkeys page"
            }
            if !rightHintsShown {
                goRightNotice?.stringValue = "Click to go back to\nthe Display page"
                goRightButton?.highlight()
            }
        }
    }

    func mauveBackground() {
        if let logo = logo {
            logo.transition(0.2)
            logo.textColor = logoColor
            logo.stringValue = "HOTKEYS"
        }

        activeModeButton?.page = .hotkeys
        activeModeButton?.fade()

        POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantDark)

        if thisIsFirstRun || thisIsFirstRunAfterM1DDCUpgrade {
            if !leftHintsShown {
                goLeftNotice?.stringValue = ""
                leftHintsShown = true
            }
            if !rightHintsShown {
                goRightNotice?.stringValue = "Click to go back to the\n Configuration page"
            }
        }

        goLeftButton?.disable()
        goRightButton?.enable(color: logoColor)
    }

    override func viewDidAppear() {
        if thisIsFirstRun || thisIsFirstRunAfterM1DDCUpgrade {
            showNavigationHints()
        }
    }

    override func viewDidDisappear() {
        hideNavigationHints()
    }

    func showNavigationHints() {
        if !leftHintsShown {
            goLeftButton?.highlight()
        }
        if !rightHintsShown {
            goRightButton?.highlight()
        }
    }

    func hideNavigationHints() {
        goLeftButton?.stopHighlighting()
        goRightButton?.stopHighlighting()
    }

    override func viewDidLoad() {
        view.wantsLayer = true
        view.radius = 12.0.ns
        view.bg = white

        goLeftButton?.notice = goLeftNotice
        goRightButton?.notice = goRightNotice

        whiteBackground()
        updateHelpButton()
        listenForAdaptiveModeChange()

        super.viewDidLoad()
    }
}
