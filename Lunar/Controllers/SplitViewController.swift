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
- The `Curve Factor` from the gear ⚙️ icon menu helps to adjust how fast the brightness should rise or fall between thresholds

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
- The `Curve Factor` from the gear ⚙️ icon menu helps to adjust how fast the brightness should rise or fall between thresholds

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
- The `Curve Factor` from the gear ⚙️ icon menu helps to adjust how fast the brightness should rise or fall between thresholds

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
let CLOCK_HELP_TEXT = """
# Clock Mode

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

// MARK: - SplitViewController

class SplitViewController: NSSplitViewController {
    // MARK: Lifecycle

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            do { log.verbose("END DEINIT") }
        #endif
    }

    // MARK: Internal

    @objc dynamic var version = "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4")"
    var adaptiveModeObserver: Cancellable?
    var defaultAutoModeTitle: NSAttributedString?

    @objc dynamic var pages: [NSTabViewItem] = {
        let hotkeysTab = NSTabViewItem(identifier: "Hotkeys")
        let configurationTab = NSTabViewItem(identifier: "Configuration")
        let builtinTab = NSTabViewItem(identifier: "Built-in")

        hotkeysTab.label = "Hotkeys"
        configurationTab.label = "Configuration"
        builtinTab.label = "Built-in"

        return [hotkeysTab, configurationTab, builtinTab]
    }()

    @Atomic var applyPage = true
    @IBOutlet var logo: NSTextField?

    @IBOutlet var containerView: NSView?

    @IBOutlet var activeModeButton: AdaptiveModeButton!
    @IBOutlet var _activeHelpButton: NSButton!
    @IBOutlet var pageControl: NSSegmentedControl!

    var onLeftButtonPress: (() -> Void)?
    var onRightButtonPress: (() -> Void)?

    var overrideAdaptiveModeObserver: Cancellable?
    var pausedAdaptiveModeObserver: Bool = false

    @objc dynamic var page: Int = 2 {
        didSet {
            guard applyPage else { return }
            appDelegate!.currentPage = page
            appDelegate!.goToPage(ignoreUIElement: true)
        }
    }

    weak var pageController: PageController? {
        didSet {
            guard let pageController = pageController else { return }
            pages = pageController.arrangedObjects.compactMap { obj in
                switch obj {
                case let page as NSPageController.ObjectIdentifier:
                    let tab = NSTabViewItem(identifier: page.stripped)
                    tab.label = page.stripped
                    return tab
                case let display as Display:
                    let tab = NSTabViewItem(identifier: display.serial)
                    tab.label = display.name.stripped
                    return tab
                default:
                    return nil
                }
            }
            page = pageController.selectedIndex

            pageControl.sizeToFit()
            pageControl.center(within: view.visibleRect, vertically: false)
        }
    }

    var activeHelpButton: HelpButton? {
        _activeHelpButton as? HelpButton
    }

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

    func setPage(_ pageNumber: Int?) {
        guard let pageNumber = pageNumber else { return }
        applyPage = false
        page = pageNumber
        applyPage = true
    }

    func lastPage() {
        setPage(pageController?.selectedIndex)
        whiteBackground()
    }

    func whiteBackground() {
        setPage(pageController?.selectedIndex)
        view.transition(0.2)
        if let logo = logo {
            logo.transition(0.2)
            logo.textColor = logoColor
            logo.stringValue = "LUNAR"
        }

        if darkMode {
            activeModeButton?.page = .hotkeys
            activeModeButton?.fade()

            POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantDark)
            POPOVERS["settings"]??.appearance = NSAppearance(named: .vibrantDark)
            view.bg = darkMauve

            pageControl?.appearance = NSAppearance(named: .vibrantDark)
        } else {
            activeModeButton?.page = .display
            activeModeButton?.fade()

            POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantLight)
            POPOVERS["settings"]??.appearance = NSAppearance(named: .vibrantLight)
            view.bg = white

            pageControl?.appearance = NSAppearance(named: .aqua)
        }
    }

    func yellowBackground() {
        setPage(pageController?.selectedIndex)
        if let logo = logo {
            logo.transition(0.2)
            logo.textColor = bgColor
            logo.stringValue = "SETTINGS"
        }

        activeModeButton?.page = .settings
        activeModeButton?.fade()

        POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantLight)
        pageControl?.appearance = NSAppearance(named: .aqua)
    }

    func mauveBackground() {
        setPage(pageController?.selectedIndex)
        if let logo = logo {
            logo.transition(0.2)
            logo.textColor = logoColor
            logo.stringValue = "HOTKEYS"
        }

        activeModeButton?.page = .hotkeys
        activeModeButton?.fade()

        POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantDark)
        pageControl?.appearance = NSAppearance(named: .darkAqua)
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
