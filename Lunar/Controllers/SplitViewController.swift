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
import Sentry

let NOTE_TEXT = """
**Note:** The same logic applies for both brightness and contrast
"""
let SENSOR_HELP_TEXT = """
# Sensor Mode

In `Sensor` mode, Lunar will read the ambient light from an external light sensor and adapt the brightness and contrast of the monitors based on the lux value.

You can configure how often Lunar reacts to the ambient light changes by changing the `Polling Interval` on the `Configuration` page.

## Algorithm

1. **Every 2 seconds** the sensor will send the lux value of the ambient light to Lunar
2. Lunar will compare the received lux to the last value
3. If the new value is different, it is passed through the **Curve Algorithm** to compute the best brightness for each monitor
4. After computing the monitor values, Lunar will set the brightness for each monitor based on their settings

*The 2 seconds interval is user configurable to any value greater or equal to 1 second.*

## Settings

- Adjusting the curve is as simple as changing the brightness of an external monitor to whatever you want it to be
    - Lunar will learn from that and adjust the curve accordingly
- The `Curve Factor` from the **Display Settings** menu helps to adjust how fast the brightness should rise or fall between thresholds

\(NOTE_TEXT)
"""
let LOCATION_HELP_TEXT = """
# Location Mode

In `Location` mode, Lunar adjusts the brightness and contrast automatically based on the sun elevation in the sky, at your location.

The location detection uses the system **Location Services**, but the user needs to give Lunar permission to access it.

If this fails, Lunar will try to find a rough location through a **GeoIP** service like [ipstack.com](https://ipstack.com).

## Algorithm

1. Lunar starts by setting the brightness to a minimum at night
2. Then, from sunrise to noon, the brightness is raised gradually until it reaches the `MAX` setting at noon
3. After noon, Lunar lowers the brightness gradually until it reaches the `MIN` setting again at sunset

## Settings

- Adjusting the curve is as simple as changing the brightness to whatever you want it to be at that time of the day
    - Lunar will learn from that and adjust the curve accordingly
- The `Curve Factor` from the **Display Settings** menu helps to adjust how fast the brightness should rise or fall between thresholds

\(NOTE_TEXT)
"""
let SYNC_HELP_TEXT = """
# Sync Mode

`Sync` refers to the algorithm that Lunar uses to synchronize the brightness from the built-in display of a Mac device to the external monitors' brightness.

The built-in display of a Macbook is always adapted to the ambient light using the Ambient Light Sensor near the camera.

Lunar takes advantage of that by periodically reading the display brightness, and sending it to the external monitors.

## Algorithm

1. **Every 2 seconds** the display brightness is read and compared to the last value
2. If the brightness has changed, Lunar starts a **fast polling** process where the brightness is read every **100ms**
3. The built-in brightness is passed through the **Curve Algorithm** to bring it to a better suited value for each monitor
4. After computing the brightness value, Lunar will set the brightness for each monitor based on their settings
5. If **no new brightness** change has been detected in the **last 3 seconds**, Lunar switches back to the efficient polling interval of **2 seconds**

*The 2 seconds interval is user configurable to any value greater or equal to 1 second.*

## Settings

- Adjusting the curve is as simple as changing the brightness of an external monitor to whatever you want it to be
    - Lunar will learn from that and adjust the curve accordingly
- The `Curve Factor` from the **Display Settings** menu helps to adjust how fast the brightness should rise or fall between thresholds

\(NOTE_TEXT)
"""
let MANUAL_HELP_TEXT = """
# Manual Mode

The adaptive algorithm is disabled in `Manual` mode, but Lunar provides useful hotkeys to control all the monitors' brightness and contrast from your keyboard.

This mode is the last resort for people that:

1. Don't have a built-in display (*Mac Mini*)
2. Don't use the built-in display (*Macbook with lid closed*)
3. Work in an environment without much natural light (*where Location mode is useless*)
4. Don't have an Ambient Light Sensor (*Hackintosh*)
5. Don't trust machines to do their work

## Algorithm

1. Percentage Hotkeys: `0%`, `25%`, `50%`, `75%`, `100%`
    - When one of these hotkeys is pressed, Lunar computes the brightness by taking into account the `MIN` and `MAX` limits.
2. Brightness/Contrast Up/Down Hotkeys
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

This mode allows you to apply brightness and contrast values based on a custom schedule.

Each schedule can be of the following types:
1. `Time`: apply values at a specific time of day
2. `Sunrise`: apply values when the sun starts to rise above the horizon
3. `Noon`: apply values when the sun is at its highest point in the sky
4. `Sunset`: apply values when the sun starts to fall below the horizon

### Sunrise, sunset and noon
- The time for these types is computed daily
- The time can be offset using the hour/minute and sign values
- If the sign is `+` the values will be applied *after* the sunset time
- If the sign is `-` the values will be applied *before* the sunset time

## Schedule Transitions
1. `None`: the brightness and contrast are applied at the exact time of the schedule
2. `30 minutes`: the brightness and contrast start transitioning 30 minutes before the schedule time, from your current brightness to the schedule brightness
    - *When the transition starts, the algorithm applies the computed values every 30 seconds so it doesn't allow for manual adjustments in the 30 minutes before the schedule*
3. `Full`: the brightness and contrast transition from schedule to schedule
    - *This transition applies the computed values every 30 seconds so it doesn't allow for manual adjustments*

## Events

The previous schedule values are re-applied when following events happen:
- Wake from sleep
- Display list changes (display connected/disconnected or enters standby)
- App is launched

**To disable this event behaviour, uncheck `Re-apply brightness on screen wake` in [Advanced settings](lunar://advanced)**
"""

var leftHintsShown = false
var rightHintsShown = false

// MARK: - SplitViewController

class SplitViewController: NSSplitViewController {
    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            do { log.verbose("END DEINIT") }
        #endif
    }

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
    var pausedAdaptiveModeObserver = false

    var nameObservers: Set<AnyCancellable> = []

    @objc dynamic var page = 2 {
        didSet {
            guard applyPage else { return }
            appDelegate!.currentPage = page
            appDelegate!.goToPage(ignoreUIElement: true)
        }
    }

    weak var pageController: PageController? {
        didSet {
            nameObservers = []
            guard let pageController else { return }
            var tabIndex = 0
            pages = pageController.arrangedObjects.compactMap { obj in
                defer { tabIndex += 1 }
                switch obj {
                case let page as NSPageController.ObjectIdentifier:
                    let tab = NSTabViewItem(identifier: page.stripped)
                    tab.label = page.stripped
                    return tab
                case let display as Display:
                    let serial = display.serial
                    let tab = NSTabViewItem(identifier: serial)
                    tab.label = display.name.stripped
                    display.$name
                        .debounce(for: .milliseconds(10), scheduler: RunLoop.main)
                        .sink { [weak self] name in
                            guard let self else { return }

                            self.pages = self.pages.map { tab in
                                guard (tab.identifier as? String) == serial else { return tab }

                                let newTab = NSTabViewItem(identifier: tab.identifier)
                                newTab.label = name.stripped
                                return newTab
                            }
                        }.store(in: &nameObservers)
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
            guard let self, let button = self.activeModeButton else { return }

            mainAsync { [weak self] in
                guard let self else { return }
                Defaults.withoutPropagation {
                    button.update()
                    self.updateHelpButton()
                }
            }
        }

        adaptiveModeObserver = adaptiveBrightnessModePublisher.sink { [weak self] change in
            mainAsync {
                guard let self, !self.pausedAdaptiveModeObserver, let button = self.activeModeButton
                else { return }

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
        guard let pageNumber else { return }
        applyPage = false
        page = pageNumber
        applyPage = true
    }

    func lastPage() {
        setPage(pageController?.selectedIndex)
        displayPage()
    }

    func displayPage() {
        uiCrumb("Display Page \(pageController?.selectedIndex ?? 0)")
        setPage(pageController?.selectedIndex)
        view.transition(0.2)
        if let logo {
            logo.transition(0.2)
            logo.textColor = logoColor
            logo.stringValue = "LUNAR"
        }

        if darkMode {
            activeModeButton.bg = lunarYellow.withAlphaComponent(0.2)
            activeModeButton.appearance = .dark

            POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantDark)
            POPOVERS["settings"]??.appearance = NSAppearance(named: .vibrantDark)
            view.bg = darkMauve

            pageControl?.appearance = NSAppearance(named: .vibrantDark)
        } else {
            activeModeButton.bg = white.withAlphaComponent(0.3)
            activeModeButton.appearance = .light

            POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantLight)
            POPOVERS["settings"]??.appearance = NSAppearance(named: .vibrantLight)
            view.bg = white

            pageControl?.appearance = NSAppearance(named: .aqua)
        }
    }

    func configurationPage() {
        uiCrumb("Configuration Page")
        setPage(pageController?.selectedIndex)
        if let logo {
            logo.transition(0.2)
            logo.textColor = bgColor
            logo.stringValue = "SETTINGS"
        }

        activeModeButton.bg = white.withAlphaComponent(darkMode ? 0.3 : 0.6)
        activeModeButton.appearance = .light

        POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantLight)
        pageControl?.appearance = NSAppearance(named: .aqua)
    }

    func hotkeysPage() {
        uiCrumb("Hotkeys Page")

        setPage(pageController?.selectedIndex)
        if let logo {
            logo.transition(0.2)
            logo.textColor = logoColor
            logo.stringValue = "HOTKEYS"
        }

        activeModeButton.bg = lunarYellow.withAlphaComponent(0.2)
        activeModeButton.appearance = .dark

        POPOVERS["help"]!?.appearance = NSAppearance(named: .vibrantDark)
        pageControl?.appearance = NSAppearance(named: .darkAqua)
    }

    override func viewDidLoad() {
        view.wantsLayer = true
        view.radius = 22.0.ns
        view.bg = white

        displayPage()
        updateHelpButton()
        listenForAdaptiveModeChange()

        super.viewDidLoad()
    }
}
