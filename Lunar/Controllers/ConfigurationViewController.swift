//
//  ConfigurationViewController.swift
//  Lunar
//
//  Created by Alin on 16/04/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

let CHART_LINK = "https://www.desmos.com/calculator/zciiqhtnov"
let UI_NOTE_INFO = """
[]()

**Note:** Manual adjustments through the UI on the Display page of Lunar won't take these values into account.
"""
let ADJUSTING_VALUES_INFO = """
[]()

## Adjusting values
Use one of the following gestures **while hovering on the value with your mouse or trackpad**
- Scroll vertically using the mouse or trackpad
- Press the up/down arrow keys on your keyboard
"""
let NOON_DURATION_TOOLTIP = """
## Description
The number of minutes for which the daylight in your area is very high.

## Effect
This keeps the brightness/contrast at its highest value for as much as needed.
\(ADJUSTING_VALUES_INFO)
"""
let DAYLIGHT_EXTENSION_TOOLTIP = """
## Description
The number of minutes for which the daylight in your area is still visible before sunrise and after sunset.

## Effect
This keeps the brightness/contrast from going to its lowest value too soon.
\(ADJUSTING_VALUES_INFO)
"""
let CURVE_FACTOR_TOOLTIP = """
## Description
Value for adjusting the brightness/contrast curve.

[How does the curve factor affect brightness?](\(CHART_LINK))
"""
let BRIGHTNESS_OFFSET_TOOLTIP = """
## Description
Offset for adjusting the brightness curve of the adaptive algorithm.

## Effect
The offset is transformed into a curve factor using the following rules:
  - **if** ` offset > 0 ` **then** ` factor = 1 - (offset / 100) `
      - the result will have a value between **0.0** and **1.0**
  - **if** ` offset <= 0 ` **then** ` factor = 1 + (offset / -10) `
      - the result will have a value between **1.0** and **1.9**

\(ADJUSTING_VALUES_INFO)

[How does the curve factor affect brightness?](\(CHART_LINK))
"""
let BRIGHTNESS_CLIP_TOOLTIP = """
## Description
Limits for mapping the high range of the built-in display brightness to a lower range monitor brightness.

## Effect
When the built-in display brightness is within these limits, the monitor brightness is computed according to the usual rules.

Otherwise:
  - **if** ` builtinBrightness ≥ clipMax ` **then** ` monitorBrightness = clipMax `
  - **if** ` builtinBrightness ≤ clipMin ` **then** ` monitorBrightness = clipMin `

\(ADJUSTING_VALUES_INFO)
"""
let POLLING_INTERVAL_TOOLTIP = """
## Description
Value that describes how often Lunar should check for changes in the built-in display brightness.

## Effect
The adaptive algorithm synchronizes the monitors with the built-in display brightness
using the following steps:
    - Read built-in display brightness
    - Compute each monitor's brightness by taking into account the configured offsets
    - Apply the brightness for each monitor
    - *Sleep for `x` seconds*

The last step uses this value to know how much to sleep.
If you experience lags and system freeze in Sync mode,
your monitor might have slow DDC response time.

In this case, you might benefit from a larger polling interval like 10 seconds.

\(ADJUSTING_VALUES_INFO)
"""
let HOTKEY_STEP_TOOLTIP = """
## Description
Value for adjusting how much to increase/decrease the brightness/contrast/volume when using hotkeys.

## Effect
When using the Brightness/Contrast/Volume Up/Down actions, the values will be computed using the following formulas:
* Brightness Up: ` brightness = oldValue + step `
* Brightness Down: ` brightness = oldValue - step `
* Contrast Up: ` contrast = oldValue + step `
* Contrast Down: ` contrast = oldValue - step `
* Volume Up: ` volume = oldValue + step `
* Volume Down: ` volume = oldValue - step `

\(ADJUSTING_VALUES_INFO)

\(UI_NOTE_INFO)
"""
let BRIGHTNESS_LIMIT_TOOLTIP = """
## Description
Hard limits for brightness percentage adjustments through **hotkeys** or **menu items**.

## Effect
When using the percent settings (0%, 25%, etc.) or the increase/decrease hotkeys, the brightness will be computed using the following formula:
```
percent / 100 * (max - min) + min
```

\(ADJUSTING_VALUES_INFO)

\(UI_NOTE_INFO)
"""
let CONTRAST_LIMIT_TOOLTIP = """
## Description
Hard limits for contrast percentage adjustments through **hotkeys** or **menu items**.

## Effect
When using the percent settings (0%, 25%, etc.) or the increase/decrease hotkeys, the contrast will be computed using the following formula:
```
percent / 100 * (max - min) + min
```

\(ADJUSTING_VALUES_INFO)

\(UI_NOTE_INFO)
"""
let LOCATION_TOOLTIP = """
## Description
Adjustable location coordinates.

## Effect
The sunrise, noon and sunset times will be computed based on these coordinates.

## Adjusting values
- Click to edit then press enter to set custom values.
- Press reset to use the last location stored by the system.
"""
let SMOOTH_TRANSITION_TOOLTIP = """
## Description
Allows brightness/contrast to change smoothly from a value to another.

## Effect
A custom algorithm is used to auto-adapt the smoothing logic based on each monitor's response time.

If the monitor isn't fast enough, changing the brightness/contrast may look jaggy or cause flashes.
[]()

**Note:** This can make the system lag in transitions if the monitor has a *very* slow response time
"""

class ConfigurationViewController: NSViewController {
    @IBOutlet var smoothTransitionLabel: NSTextField!
    @IBOutlet var smoothTransitionCheckbox: NSButton!

    @IBOutlet var helpButton1: HelpButton!
    @IBOutlet var helpButton2: HelpButton!
    @IBOutlet var helpButton3: HelpButton!
    @IBOutlet var helpButton4: HelpButton!
    @IBOutlet var helpButtonStep: HelpButton!
    @IBOutlet var helpButtonBottom: HelpButton!

    @IBOutlet var noonDurationField: ScrollableTextField!
    @IBOutlet var noonDurationCaption: ScrollableTextFieldCaption!
    @IBOutlet var noonDurationLabel: NSTextField!
    var noonDurationVisible: Bool = false {
        didSet {
            noonDurationField?.isHidden = !noonDurationVisible
            noonDurationCaption?.isHidden = !noonDurationVisible
            noonDurationLabel?.isHidden = !noonDurationVisible
        }
    }

    @IBOutlet var daylightExtensionField: ScrollableTextField!
    @IBOutlet var daylightExtensionCaption: ScrollableTextFieldCaption!
    @IBOutlet var daylightExtensionLabel: NSTextField!
    var daylightExtensionVisible: Bool = false {
        didSet {
            daylightExtensionField?.isHidden = !daylightExtensionVisible
            daylightExtensionCaption?.isHidden = !daylightExtensionVisible
            daylightExtensionLabel?.isHidden = !daylightExtensionVisible
        }
    }

    @IBOutlet var curveFactorField: ScrollableTextField!
    @IBOutlet var curveFactorCaption: ScrollableTextFieldCaption!
    @IBOutlet var curveFactorLabel: NSTextField!
    var curveFactorVisible: Bool = false {
        didSet {
            curveFactorField?.isHidden = !curveFactorVisible
            curveFactorCaption?.isHidden = !curveFactorVisible
            curveFactorLabel?.isHidden = !curveFactorVisible
        }
    }

    @IBOutlet var brightnessOffsetField: ScrollableTextField!
    @IBOutlet var brightnessOffsetCaption: ScrollableTextFieldCaption!
    @IBOutlet var brightnessOffsetLabel: NSTextField!
    @IBOutlet var contrastOffsetField: ScrollableTextField!
    @IBOutlet var contrastOffsetCaption: ScrollableTextFieldCaption!
    var brightnessOffsetVisible: Bool = false {
        didSet {
            brightnessOffsetField?.isHidden = !brightnessOffsetVisible
            brightnessOffsetCaption?.isHidden = !brightnessOffsetVisible
            contrastOffsetField?.isHidden = !brightnessOffsetVisible
            contrastOffsetCaption?.isHidden = !brightnessOffsetVisible
            brightnessOffsetLabel?.isHidden = !brightnessOffsetVisible
        }
    }

    @IBOutlet var brightnessClipMinField: ScrollableTextField!
    @IBOutlet var brightnessClipMinCaption: ScrollableTextFieldCaption!
    @IBOutlet var brightnessClipMaxField: ScrollableTextField!
    @IBOutlet var brightnessClipMaxCaption: ScrollableTextFieldCaption!
    @IBOutlet var brightnessClipLabel: NSTextField!
    var brightnessClipVisible: Bool = false {
        didSet {
            brightnessClipMinField?.isHidden = !brightnessClipVisible
            brightnessClipMinCaption?.isHidden = !brightnessClipVisible
            brightnessClipMaxField?.isHidden = !brightnessClipVisible
            brightnessClipMaxCaption?.isHidden = !brightnessClipVisible
            brightnessClipLabel?.isHidden = !brightnessClipVisible
        }
    }

    @IBOutlet var brightnessStepField: ScrollableTextField!
    @IBOutlet var brightnessStepCaption: ScrollableTextFieldCaption!
    @IBOutlet var contrastStepField: ScrollableTextField!
    @IBOutlet var contrastStepCaption: ScrollableTextFieldCaption!
    @IBOutlet var volumeStepField: ScrollableTextField!
    @IBOutlet var volumeStepCaption: ScrollableTextFieldCaption!
    @IBOutlet var hotkeyStepLabel: NSTextField!
    var hotkeyStepVisible: Bool = false {
        didSet {
            brightnessStepField?.isHidden = !hotkeyStepVisible
            brightnessStepCaption?.isHidden = !hotkeyStepVisible
            contrastStepField?.isHidden = !hotkeyStepVisible
            contrastStepCaption?.isHidden = !hotkeyStepVisible
            volumeStepField?.isHidden = !hotkeyStepVisible
            volumeStepCaption?.isHidden = !hotkeyStepVisible
            hotkeyStepLabel?.isHidden = !hotkeyStepVisible
        }
    }

    @IBOutlet var pollingIntervalField: ScrollableTextField!
    @IBOutlet var pollingIntervalCaption: ScrollableTextFieldCaption!
    @IBOutlet var pollingIntervalLabel: NSTextField!
    var pollingIntervalVisible: Bool = false {
        didSet {
            pollingIntervalField?.isHidden = !pollingIntervalVisible
            pollingIntervalCaption?.isHidden = !pollingIntervalVisible
            pollingIntervalLabel?.isHidden = !pollingIntervalVisible
        }
    }

    @IBOutlet var brightnessLimitMinField: ScrollableTextField!
    @IBOutlet var brightnessLimitMaxField: ScrollableTextField!
    @IBOutlet var brightnessLimitMinCaption: ScrollableTextFieldCaption!
    @IBOutlet var brightnessLimitMaxCaption: ScrollableTextFieldCaption!
    @IBOutlet var brightnessLimitLabel: NSTextField!
    var brightnessLimitVisible: Bool = false {
        didSet {
            brightnessLimitMinField?.isHidden = !brightnessLimitVisible
            brightnessLimitMaxField?.isHidden = !brightnessLimitVisible
            brightnessLimitMinCaption?.isHidden = !brightnessLimitVisible
            brightnessLimitMaxCaption?.isHidden = !brightnessLimitVisible
            brightnessLimitLabel?.isHidden = !brightnessLimitVisible
        }
    }

    @IBOutlet var contrastLimitMinField: ScrollableTextField!
    @IBOutlet var contrastLimitMaxField: ScrollableTextField!
    @IBOutlet var contrastLimitMinCaption: ScrollableTextFieldCaption!
    @IBOutlet var contrastLimitMaxCaption: ScrollableTextFieldCaption!
    @IBOutlet var contrastLimitLabel: NSTextField!
    var contrastLimitVisible: Bool = false {
        didSet {
            contrastLimitMinField?.isHidden = !contrastLimitVisible
            contrastLimitMaxField?.isHidden = !contrastLimitVisible
            contrastLimitMinCaption?.isHidden = !contrastLimitVisible
            contrastLimitMaxCaption?.isHidden = !contrastLimitVisible
            contrastLimitLabel?.isHidden = !contrastLimitVisible
        }
    }

    @IBOutlet var locationLatField: ScrollableTextField!
    @IBOutlet var locationLonField: ScrollableTextField!
    @IBOutlet var locationLatCaption: ScrollableTextFieldCaption!
    @IBOutlet var locationLonCaption: ScrollableTextFieldCaption!
    @IBOutlet var locationLabel: NSTextField!
    @IBOutlet var locationReset: TextButton!
    var locationVisible: Bool = false {
        didSet {
            locationLatField?.isHidden = !locationVisible
            locationLonField?.isHidden = !locationVisible
            locationLatCaption?.isHidden = !locationVisible
            locationLonCaption?.isHidden = !locationVisible
            locationLabel?.isHidden = !locationVisible
            locationReset?.isHidden = !locationVisible
        }
    }

    @IBOutlet var swipeLeftHint: NSTextField!

    var curveFactorObserver: NSKeyValueObservation?
    var brightnessOffsetObserver: NSKeyValueObservation?
    var contrastOffsetObserver: NSKeyValueObservation?
    var pollingIntervalObserver: NSKeyValueObservation?
    var brightnessStepObserver: NSKeyValueObservation?
    var contrastStepObserver: NSKeyValueObservation?
    var volumeStepObserver: NSKeyValueObservation?
    var brightnessClipMinObserver: NSKeyValueObservation?
    var brightnessClipMaxObserver: NSKeyValueObservation?
    var brightnessLimitMinObserver: NSKeyValueObservation?
    var contrastLimitMinObserver: NSKeyValueObservation?
    var brightnessLimitMaxObserver: NSKeyValueObservation?
    var contrastLimitMaxObserver: NSKeyValueObservation?
    var didSwipeToHotkeysObserver: NSKeyValueObservation?
    var adaptiveModeObserver: NSKeyValueObservation?
    var showNavigationHintsObserver: NSKeyValueObservation?
    var sunriseObserver: NSKeyValueObservation?
    var sunsetObserver: NSKeyValueObservation?
    var solarNoonObserver: NSKeyValueObservation?
    var locationLatObserver: NSKeyValueObservation?
    var locationLonObserver: NSKeyValueObservation?

    weak var settingsController: SettingsPageController?

    func showRelevantSettings(_ adaptiveMode: AdaptiveMode) {
        let locationMode = adaptiveMode == .location
        let syncMode = adaptiveMode == .sync
        let manualMode = adaptiveMode == .manual

        noonDurationVisible = locationMode
        daylightExtensionVisible = locationMode
        curveFactorVisible = locationMode
        locationVisible = locationMode
        brightnessOffsetVisible = syncMode
        brightnessClipVisible = syncMode
        pollingIntervalVisible = syncMode
        brightnessLimitVisible = manualMode
        contrastLimitVisible = manualMode
        hotkeyStepVisible = true

        helpButtonStep.helpText = HOTKEY_STEP_TOOLTIP
        helpButtonBottom.helpText = SMOOTH_TRANSITION_TOOLTIP

        var refX: CGFloat
        switch adaptiveMode {
        case .manual:
            let refFrame1 = contrastLimitMinField.frame
            let refFrame2 = contrastLimitMaxField.frame
            let width = refFrame2.maxX - refFrame1.minX
            refX = refFrame2.maxX - (width / 2)

            helpButton1.helpText = BRIGHTNESS_LIMIT_TOOLTIP
            helpButton1.link = nil
            helpButton2.helpText = CONTRAST_LIMIT_TOOLTIP
            helpButton2.link = CHART_LINK
        case .location:
            let refFrame = daylightExtensionField.frame
            refX = refFrame.maxX - (refFrame.width / 2)

            helpButton1.helpText = NOON_DURATION_TOOLTIP
            helpButton1.link = nil
            helpButton2.helpText = DAYLIGHT_EXTENSION_TOOLTIP
            helpButton2.link = nil
            helpButton3.helpText = CURVE_FACTOR_TOOLTIP
            helpButton3.link = CHART_LINK
            helpButton4.helpText = LOCATION_TOOLTIP
            helpButton4.link = nil
        case .sync:
            let refFrame = brightnessOffsetField.frame
            refX = refFrame.maxX - (refFrame.width / 2)

            helpButton1.helpText = BRIGHTNESS_OFFSET_TOOLTIP
            helpButton1.link = CHART_LINK
            helpButton2.helpText = BRIGHTNESS_CLIP_TOOLTIP
            helpButton2.link = CHART_LINK
            helpButton3.helpText = POLLING_INTERVAL_TOOLTIP
            helpButton3.link = nil
        }

        smoothTransitionCheckbox.setFrameOrigin(NSPoint(
            x: refX - CGFloat(4.5),
            y: smoothTransitionCheckbox.frame.origin.y
        ))

        helpButton1.isHidden = !brightnessOffsetVisible && !brightnessLimitVisible && !noonDurationVisible
        helpButton2.isHidden = !brightnessClipVisible && !contrastLimitVisible && !daylightExtensionVisible
        helpButton3.isHidden = !curveFactorVisible && !pollingIntervalVisible
        helpButton4.isHidden = !locationVisible
    }

    func listenForShowNavigationHintsChange() {
        showNavigationHintsObserver = datastore.defaults.observe(\.showNavigationHints, options: [.old, .new], changeHandler: { _, change in
            guard let show = change.newValue, let oldShow = change.oldValue, show != oldShow else {
                return
            }
            runInMainThread {
                self.swipeLeftHint?.isHidden = !show
            }
        })
    }

    func listenForCurveFactorChange() {
        curveFactorObserver = datastore.defaults.observe(\.curveFactor, options: [.old, .new], changeHandler: { _, change in
            guard let value = change.newValue, let oldValue = change.oldValue, value != oldValue else {
                return
            }
            runInMainThread {
                self.curveFactorField?.doubleValue = value
            }
        })
    }

    func listenForLocationChange() {
        let updateDataset = { (_: UserDefaults, change: NSKeyValueObservedChange<String>) -> Void in
            guard let value = change.newValue, let oldValue = change.oldValue, value != oldValue else {
                return
            }
            self.settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, updateLimitLines: true)
        }
        sunriseObserver = datastore.defaults.observe(\.sunrise, options: [.old, .new], changeHandler: updateDataset)
        sunsetObserver = datastore.defaults.observe(\.sunset, options: [.old, .new], changeHandler: updateDataset)
        solarNoonObserver = datastore.defaults.observe(\.solarNoon, options: [.old, .new], changeHandler: updateDataset)
        locationLatObserver = datastore.defaults.observe(\.locationLat, options: [.old, .new], changeHandler: { _, change in
            guard let value = change.newValue, let oldValue = change.oldValue, value != oldValue else {
                return
            }
            runInMainThread {
                self.locationLatField?.doubleValue = value
            }
        })
        locationLonObserver = datastore.defaults.observe(\.locationLon, options: [.old, .new], changeHandler: { _, change in
            guard let value = change.newValue, let oldValue = change.oldValue, value != oldValue else {
                return
            }
            runInMainThread {
                self.locationLonField?.doubleValue = value
            }
        })
    }

    func listenForBrightnessOffsetChange() {
        brightnessOffsetObserver = datastore.defaults.observe(\.brightnessOffset, options: [.old, .new], changeHandler: { _, change in
            guard let brightness = change.newValue, let oldBrightness = change.oldValue, brightness != oldBrightness else {
                return
            }
            runInMainThread {
                self.brightnessOffsetField?.stringValue = String(brightness)
            }
        })
    }

    func listenForContrastOffsetChange() {
        contrastOffsetObserver = datastore.defaults.observe(\.contrastOffset, options: [.old, .new], changeHandler: { _, change in
            guard let contrast = change.newValue, let oldContrast = change.oldValue, contrast != oldContrast else {
                return
            }
            runInMainThread {
                self.contrastOffsetField?.stringValue = String(contrast)
            }
        })
    }

    func listenForBrightnessStepChange() {
        brightnessStepObserver = datastore.defaults.observe(\.brightnessStep, options: [.old, .new], changeHandler: { _, change in
            guard let brightness = change.newValue, let oldBrightness = change.oldValue, brightness != oldBrightness else {
                return
            }
            runInMainThread {
                self.brightnessStepField?.stringValue = String(brightness)
            }
        })
    }

    func listenForPollingIntervalChange() {
        pollingIntervalObserver = datastore.defaults.observe(\.syncPollingSeconds, options: [.old, .new], changeHandler: { _, change in
            guard let seconds = change.newValue, let oldSeconds = change.oldValue, seconds != oldSeconds else {
                return
            }
            runInMainThread {
                self.pollingIntervalField?.stringValue = String(seconds)
            }
        })
    }

    func listenForContrastStepChange() {
        contrastStepObserver = datastore.defaults.observe(\.contrastStep, options: [.old, .new], changeHandler: { _, change in
            guard let contrast = change.newValue, let oldContrast = change.oldValue, contrast != oldContrast else {
                return
            }
            runInMainThread {
                self.contrastStepField?.stringValue = String(contrast)
            }
        })
    }

    func listenForVolumeStepChange() {
        volumeStepObserver = datastore.defaults.observe(\.volumeStep, options: [.old, .new], changeHandler: { _, change in
            guard let volume = change.newValue, let oldVolume = change.oldValue, volume != oldVolume else {
                return
            }
            runInMainThread {
                self.volumeStepField?.stringValue = String(volume)
            }
        })
    }

    func listenForBrightnessClipChange() {
        brightnessClipMinObserver = datastore.defaults.observe(\.brightnessClipMin, options: [.old, .new], changeHandler: { _, change in
            guard let brightness = change.newValue, let oldBrightness = change.oldValue, brightness != oldBrightness else {
                return
            }
            runInMainThread {
                self.brightnessClipMinField?.stringValue = String(brightness)
                self.brightnessClipMaxField?.lowerLimit = Double(brightness + 1)
            }
        })
        brightnessClipMaxObserver = datastore.defaults.observe(\.brightnessClipMax, options: [.old, .new], changeHandler: { _, change in
            guard let brightness = change.newValue, let oldBrightness = change.oldValue, brightness != oldBrightness else {
                return
            }
            runInMainThread {
                self.brightnessClipMaxField?.stringValue = String(brightness)
                self.brightnessClipMinField?.upperLimit = Double(brightness - 1)
            }
        })
    }

    func listenForBrightnessLimitChange() {
        brightnessLimitMinObserver = datastore.defaults.observe(\.brightnessLimitMin, options: [.old, .new], changeHandler: { _, change in
            guard let brightness = change.newValue, let oldBrightness = change.oldValue, brightness != oldBrightness else {
                return
            }
            runInMainThread {
                self.brightnessLimitMinField?.stringValue = String(brightness)
                self.brightnessLimitMaxField?.lowerLimit = Double(brightness + 1)
            }
        })
        brightnessLimitMaxObserver = datastore.defaults.observe(\.brightnessLimitMax, options: [.old, .new], changeHandler: { _, change in
            guard let brightness = change.newValue, let oldBrightness = change.oldValue, brightness != oldBrightness else {
                return
            }
            runInMainThread {
                self.brightnessLimitMaxField?.stringValue = String(brightness)
                self.brightnessLimitMinField?.upperLimit = Double(brightness - 1)
            }
        })
    }

    func listenForContrastLimitChange() {
        contrastLimitMinObserver = datastore.defaults.observe(\.contrastLimitMin, options: [.old, .new], changeHandler: { _, change in
            guard let contrast = change.newValue, let oldContrast = change.oldValue, contrast != oldContrast else {
                return
            }
            runInMainThread {
                self.contrastLimitMinField?.stringValue = String(contrast)
                self.contrastLimitMaxField?.lowerLimit = Double(contrast + 1)
            }
        })
        contrastLimitMaxObserver = datastore.defaults.observe(\.contrastLimitMax, options: [.old, .new], changeHandler: { _, change in
            guard let contrast = change.newValue, let oldContrast = change.oldValue, contrast != oldContrast else {
                return
            }
            runInMainThread {
                self.contrastLimitMaxField?.stringValue = String(contrast)
                self.contrastLimitMinField?.upperLimit = Double(contrast - 1)
            }
        })
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = datastore.defaults.observe(\.adaptiveBrightnessMode, options: [.old, .new], changeHandler: { _, change in
            guard let mode = change.newValue, let oldMode = change.oldValue, mode != oldMode else {
                return
            }
            if let adaptiveMode = AdaptiveMode(rawValue: mode) {
                runInMainThread {
                    self.showRelevantSettings(adaptiveMode)
                }
            }
        })
    }

    func setupNoonDuration() {
        guard let field = noonDurationField, let caption = noonDurationCaption else { return }

        // noonDurationLabel?.toolTip = NOON_DURATION_TOOLTIP

        setupScrollableTextField(
            field, caption: caption, settingKey: "noonDurationMinutes", lowerLimit: 0, upperLimit: 300,
            onMouseEnter: { settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, noonDuration: self.noonDurationField.integerValue, withAnimation: true)
            },
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, noonDuration: value)
            }
        )
    }

    func setupDaylightExtension() {
        guard let field = daylightExtensionField, let caption = daylightExtensionCaption else { return }

        // daylightExtensionLabel?.toolTip = DAYLIGHT_EXTENSION_TOOLTIP

        setupScrollableTextField(
            field, caption: caption, settingKey: "daylightExtensionMinutes", lowerLimit: 0, upperLimit: 300,
            onMouseEnter: { settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, daylightExtension: self.daylightExtensionField.integerValue, withAnimation: true)
            },
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, daylightExtension: value)
            }
        )
    }

    func setupCurveFactor() {
        guard let field = curveFactorField, let caption = curveFactorCaption else { return }

        curveFactorField.decimalPoints = 1
        curveFactorField.step = 0.1

        setupScrollableTextField(
            field, caption: caption, settingKey: "curveFactor", lowerLimit: 0.0, upperLimit: 10.0,
            onMouseEnter: { settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, factor: self.curveFactorField.doubleValue, withAnimation: true)
            },
            onValueChangedInstantDouble: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, factor: value)
            }
        )
    }

    func setupBrightnessOffset() {
        guard let field = brightnessOffsetField, let caption = brightnessOffsetCaption else { return }

        setupScrollableTextField(
            field, caption: caption, settingKey: "brightnessOffset", lowerLimit: -100, upperLimit: 90,
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, brightnessOffset: value, brightnessClipMin: brightnessAdapter.brightnessClipMin, brightnessClipMax: brightnessAdapter.brightnessClipMax)
            }
        )
    }

    func setupContrastOffset() {
        guard let field = contrastOffsetField, let caption = contrastOffsetCaption else { return }

        setupScrollableTextField(
            field, caption: caption, settingKey: "contrastOffset", lowerLimit: -100, upperLimit: 90,
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, contrastOffset: value, brightnessClipMin: brightnessAdapter.brightnessClipMin, brightnessClipMax: brightnessAdapter.brightnessClipMax)
            }
        )
    }

    func setupBrightnessStep() {
        guard let field = brightnessStepField, let caption = brightnessStepCaption else { return }

        setupScrollableTextField(
            field, caption: caption, settingKey: "brightnessStep", lowerLimit: 1, upperLimit: 99,
            onMouseEnter: { _ in
            },
            onValueChangedInstant: { _, _ in
            }
        )
    }

    func setupPollingInterval() {
        guard let field = pollingIntervalField, let caption = pollingIntervalCaption else { return }

        setupScrollableTextField(
            field, caption: caption, settingKey: "syncPollingSeconds", lowerLimit: 1, upperLimit: 300,
            onMouseEnter: { _ in
            },
            onValueChangedInstant: { _, _ in
            }
        )
    }

    func setupContrastStep() {
        guard let field = contrastStepField, let caption = contrastStepCaption else { return }

        setupScrollableTextField(
            field, caption: caption, settingKey: "contrastStep", lowerLimit: 1, upperLimit: 99,
            onMouseEnter: { _ in
            },
            onValueChangedInstant: { _, _ in
            }
        )
    }

    func setupVolumeStep() {
        guard let field = volumeStepField, let caption = volumeStepCaption else { return }

        setupScrollableTextField(
            field, caption: caption, settingKey: "volumeStep", lowerLimit: 1, upperLimit: 99,
            onMouseEnter: { _ in
            },
            onValueChangedInstant: { _, _ in
            }
        )
    }

    func setupBrightnessClip() {
        guard let minField = brightnessClipMinField,
            let maxField = brightnessClipMaxField,
            let minCaption = brightnessClipMinCaption,
            let maxCaption = brightnessClipMaxCaption else { return }

        setupScrollableTextField(
            minField, caption: minCaption, settingKey: "brightnessClipMin", lowerLimit: 0, upperLimit: brightnessAdapter.brightnessClipMax - 1,
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, brightnessClipMin: Double(value), brightnessClipMax: brightnessAdapter.brightnessClipMax)
            }
        )
        setupScrollableTextField(
            maxField, caption: maxCaption, settingKey: "brightnessClipMax", lowerLimit: brightnessAdapter.brightnessClipMin + 1, upperLimit: 100,
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, brightnessClipMin: brightnessAdapter.brightnessClipMin, brightnessClipMax: Double(value))
            }
        )
    }

    func setupBrightnessLimit() {
        guard let minField = brightnessLimitMinField,
            let maxField = brightnessLimitMaxField,
            let minCaption = brightnessLimitMinCaption,
            let maxCaption = brightnessLimitMaxCaption else { return }

        setupScrollableTextField(
            minField, caption: minCaption, settingKey: "brightnessLimitMin", lowerLimit: 0, upperLimit: Double(datastore.defaults.brightnessLimitMax - 1),
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, brightnessLimitMin: value)
            }
        )
        setupScrollableTextField(
            maxField, caption: maxCaption, settingKey: "brightnessLimitMax", lowerLimit: Double(datastore.defaults.brightnessLimitMin + 1), upperLimit: 100,
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, brightnessLimitMax: value)
            }
        )
    }

    func setupContrastLimit() {
        guard let minField = contrastLimitMinField,
            let maxField = contrastLimitMaxField,
            let minCaption = contrastLimitMinCaption,
            let maxCaption = contrastLimitMaxCaption else { return }

        setupScrollableTextField(
            minField, caption: minCaption, settingKey: "contrastLimitMin", lowerLimit: 0, upperLimit: Double(datastore.defaults.contrastLimitMax - 1),
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, contrastLimitMin: value)
            }
        )
        setupScrollableTextField(
            maxField, caption: maxCaption, settingKey: "contrastLimitMax", lowerLimit: Double(datastore.defaults.contrastLimitMin + 1), upperLimit: 100,
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, contrastLimitMax: value)
            }
        )
    }

    func setupLocation() {
        guard let latField = locationLatField,
            let lonField = locationLonField,
            let latCaption = locationLatCaption,
            let lonCaption = locationLonCaption else { return }

        latField.decimalPoints = 2
        latField.step = 0.01
        lonField.decimalPoints = 2
        lonField.step = 0.01

        setupScrollableTextField(
            latField, caption: latCaption, settingKey: "locationLat", lowerLimit: -90.00, upperLimit: 90.00,
            onMouseEnter: { _ in },
            onValueChangedDouble: { _, settingsController in
                datastore.defaults.set(true, forKey: "manualLocation")
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay)
            }
        )
        setupScrollableTextField(
            lonField, caption: lonCaption, settingKey: "locationLon", lowerLimit: -180.00, upperLimit: 180.00,
            onMouseEnter: { _ in },
            onValueChangedDouble: { _, settingsController in
                datastore.defaults.set(true, forKey: "manualLocation")
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay)
            }
        )
    }

    func resetScrollableTextField(_ field: ScrollableTextField?) {
        if let field = field {
            field.onValueChanged = nil
            field.onValueChangedDouble = nil
            field.onValueChangedInstant = nil
            field.onValueChangedInstantDouble = nil
            field.onMouseEnter = nil
            field.caption = nil
        }
    }

    func setupScrollableTextField(
        _ field: ScrollableTextField, caption: ScrollableTextFieldCaption, settingKey: String,
        lowerLimit: Double, upperLimit: Double,
        onMouseEnter: ((SettingsPageController?) -> Void)? = nil,
        onValueChangedInstant: ((Int, SettingsPageController?) -> Void)? = nil,
        onValueChangedInstantDouble: ((Double, SettingsPageController?) -> Void)? = nil,
        onValueChanged: ((Int, SettingsPageController?) -> Void)? = nil,
        onValueChangedDouble: ((Double, SettingsPageController?) -> Void)? = nil
    ) {
        field.textFieldColor = scrollableTextFieldColorWhite
        field.textFieldColorHover = scrollableTextFieldColorHoverWhite
        field.textFieldColorLight = scrollableTextFieldColorLightWhite
        caption.textColor = scrollableCaptionColorWhite
        field.caption = caption

        if field.decimalPoints > 0 {
            field.doubleValue = datastore.defaults.double(forKey: settingKey)
            field.onValueChangedDouble = { (value: Double) in
                datastore.defaults.set(value, forKey: settingKey)
            }
        } else {
            field.integerValue = datastore.defaults.integer(forKey: settingKey)
            field.onValueChanged = { (value: Int) in
                datastore.defaults.set(value, forKey: settingKey)
            }
        }
        field.lowerLimit = lowerLimit
        field.upperLimit = upperLimit
        if let handler = onValueChangedInstant {
            field.onValueChangedInstant = { value in
                handler(value, self.settingsController)
            }
        }
        if let handler = onValueChangedInstantDouble {
            field.onValueChangedInstantDouble = { value in
                handler(value, self.settingsController)
            }
        }
        if let handler = onValueChanged {
            field.onValueChanged = { value in
                datastore.defaults.set(value, forKey: settingKey)
                handler(value, self.settingsController)
            }
        }
        if let handler = onValueChangedDouble {
            field.onValueChangedDouble = { value in
                datastore.defaults.set(value, forKey: settingKey)
                handler(value, self.settingsController)
            }
        }
        if let handler = onMouseEnter {
            field.onMouseEnter = {
                handler(self.settingsController)
            }
        } else {
            field.onMouseEnter = {
                if brightnessAdapter.mode == .sync {
                    self.settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, brightnessClipMin: brightnessAdapter.brightnessClipMin, brightnessClipMax: brightnessAdapter.brightnessClipMax, withAnimation: true)
                } else {
                    self.settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, withAnimation: true)
                }
            }
        }
    }

    @IBAction func resetLocation(_: Any?) {
        datastore.defaults.set(false, forKey: "manualLocation")
        appDelegate().startReceivingSignificantLocationChanges()
    }

    func setup() {
        swipeLeftHint?.isHidden = datastore.defaults.didSwipeToHotkeys
        didSwipeToHotkeysObserver = datastore.defaults.observe(\.didSwipeToHotkeys, options: [.new], changeHandler: { _, change in
            self.swipeLeftHint?.isHidden = change.newValue ?? true
        })

        setupNoonDuration()
        setupDaylightExtension()
        setupCurveFactor()
        setupBrightnessOffset()
        setupContrastOffset()
        setupBrightnessStep()
        setupPollingInterval()
        setupContrastStep()
        setupVolumeStep()
        setupBrightnessClip()
        setupBrightnessLimit()
        setupContrastLimit()
        setupLocation()

        smoothTransitionCheckbox.setNeedsDisplay()

        if let mode = AdaptiveMode(rawValue: datastore.defaults.adaptiveBrightnessMode) {
            showRelevantSettings(mode)
        }

        listenForLocationChange()
        listenForCurveFactorChange()
        listenForBrightnessOffsetChange()
        listenForContrastOffsetChange()
        listenForBrightnessStepChange()
        listenForPollingIntervalChange()
        listenForContrastStepChange()
        listenForVolumeStepChange()
        listenForBrightnessClipChange()
        listenForBrightnessLimitChange()
        listenForContrastLimitChange()
        listenForAdaptiveModeChange()
        listenForShowNavigationHintsChange()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        settingsController = parent?.parent as? SettingsPageController
        setup()
    }
}
