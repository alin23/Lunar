//
//  ConfigurationViewController.swift
//  Lunar
//
//  Created by Alin on 16/04/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import AnyCodable
import Cocoa
import Defaults

class ConfigurationViewController: NSViewController {
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
    - Hold Shift and press the up/down arrow keys on your keyboard
    """
    lazy var NOON_DURATION_TOOLTIP = """
    ## Description
    The number of minutes for which the daylight in your area is very high.

    ## Effect
    This keeps the brightness/contrast at its highest value for as much as needed.
    \(ADJUSTING_VALUES_INFO)
    """
    lazy var DAYLIGHT_EXTENSION_TOOLTIP = """
    ## Description
    The number of minutes for which the daylight in your area is still visible before sunrise and after sunset.

    ## Effect
    This keeps the brightness/contrast from going to its lowest value too soon.
    \(ADJUSTING_VALUES_INFO)
    """
    lazy var CURVE_FACTOR_TOOLTIP = """
    ## Description
    Value for adjusting the brightness/contrast curve.

    [How does the curve factor affect brightness?](\(CHART_LINK))
    """
    lazy var BRIGHTNESS_OFFSET_TOOLTIP = """
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
    lazy var BRIGHTNESS_CLIP_TOOLTIP = """
    ## Description
    Limits for mapping the high range of the built-in display brightness to a lower range monitor brightness.

    ## Effect
    When the built-in display brightness is within these limits, the monitor brightness is computed according to the usual rules.

    Otherwise:
      - **if** ` builtinBrightness ≥ clipMax ` **then** ` monitorBrightness = clipMax `
      - **if** ` builtinBrightness ≤ clipMin ` **then** ` monitorBrightness = clipMin `

    \(ADJUSTING_VALUES_INFO)
    """
    lazy var POLLING_INTERVAL_TOOLTIP = """
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
    lazy var HOTKEY_STEP_TOOLTIP = """
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
    lazy var BRIGHTNESS_LIMIT_TOOLTIP = """
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
    lazy var CONTRAST_LIMIT_TOOLTIP = """
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

    var curveFactorObserver: DefaultsObservation?
    var brightnessOffsetObserver: DefaultsObservation?
    var contrastOffsetObserver: DefaultsObservation?
    var pollingIntervalObserver: DefaultsObservation?
    var brightnessStepObserver: DefaultsObservation?
    var contrastStepObserver: DefaultsObservation?
    var volumeStepObserver: DefaultsObservation?
    var brightnessClipMinObserver: DefaultsObservation?
    var brightnessClipMaxObserver: DefaultsObservation?
    var brightnessLimitMinObserver: DefaultsObservation?
    var contrastLimitMinObserver: DefaultsObservation?
    var brightnessLimitMaxObserver: DefaultsObservation?
    var contrastLimitMaxObserver: DefaultsObservation?
    var didSwipeToHotkeysObserver: DefaultsObservation?
    var adaptiveModeObserver: DefaultsObservation?
    var showNavigationHintsObserver: DefaultsObservation?
    var sunriseObserver: DefaultsObservation?
    var sunsetObserver: DefaultsObservation?
    var solarNoonObserver: DefaultsObservation?
    var locationLatObserver: DefaultsObservation?
    var locationLonObserver: DefaultsObservation?

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
        case .sensor:
            log.info("Sensor mode")
            let refFrame1 = contrastLimitMinField.frame
            let refFrame2 = contrastLimitMaxField.frame
            let width = refFrame2.maxX - refFrame1.minX
            refX = refFrame2.maxX - (width / 2)
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
        showNavigationHintsObserver = Defaults.observe(.showNavigationHints) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.swipeLeftHint?.isHidden = !change.newValue
            }
        }
    }

    func listenForCurveFactorChange() {
        curveFactorObserver = Defaults.observe(.curveFactor) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.curveFactorField?.doubleValue = change.newValue
            }
        }
    }

    func listenForLocationChange() {
        let updateDataset = { [weak self] (change: Defaults.KeyChange<String?>) -> Void in
            if change.newValue == change.oldValue {
                return
            }
            self?.settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, updateLimitLines: true)
        }
        sunriseObserver = Defaults.observe(.sunrise, handler: updateDataset)
        sunsetObserver = Defaults.observe(.sunset, handler: updateDataset)
        solarNoonObserver = Defaults.observe(.solarNoon, handler: updateDataset)
        locationLatObserver = Defaults.observe(.locationLat) { [weak self] change in
            guard change.newValue != change.oldValue else {
                return
            }
            runInMainThread { [weak self] in
                self?.locationLatField?.doubleValue = change.newValue
            }
        }
        locationLonObserver = Defaults.observe(.locationLon) { [weak self] change in
            guard change.newValue != change.oldValue else {
                return
            }
            runInMainThread { [weak self] in
                self?.locationLonField?.doubleValue = change.newValue
            }
        }
    }

    func listenForBrightnessOffsetChange() {
        brightnessOffsetObserver = Defaults.observe(.brightnessOffset) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.brightnessOffsetField?.stringValue = String(change.newValue)
            }
        }
    }

    func listenForContrastOffsetChange() {
        contrastOffsetObserver = Defaults.observe(.contrastOffset) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.contrastOffsetField?.stringValue = String(change.newValue)
            }
        }
    }

    func listenForBrightnessStepChange() {
        brightnessStepObserver = Defaults.observe(.brightnessStep) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.brightnessStepField?.stringValue = String(change.newValue)
            }
        }
    }

    func listenForPollingIntervalChange() {
        pollingIntervalObserver = Defaults.observe(.syncPollingSeconds) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.pollingIntervalField?.stringValue = String(change.newValue)
            }
        }
    }

    func listenForContrastStepChange() {
        contrastStepObserver = Defaults.observe(.contrastStep) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.contrastStepField?.stringValue = String(change.newValue)
            }
        }
    }

    func listenForVolumeStepChange() {
        volumeStepObserver = Defaults.observe(.volumeStep) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.volumeStepField?.stringValue = String(change.newValue)
            }
        }
    }

    func listenForBrightnessClipChange() {
        brightnessClipMinObserver = Defaults.observe(.brightnessClipMin) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.brightnessClipMinField?.stringValue = String(change.newValue)
                self?.brightnessClipMaxField?.lowerLimit = Double(change.newValue + 1)
            }
        }
        brightnessClipMaxObserver = Defaults.observe(.brightnessClipMax) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.brightnessClipMaxField?.stringValue = String(change.newValue)
                self?.brightnessClipMinField?.upperLimit = Double(change.newValue - 1)
            }
        }
    }

    func listenForBrightnessLimitChange() {
        brightnessLimitMinObserver = Defaults.observe(.brightnessLimitMin) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.brightnessLimitMinField?.stringValue = String(change.newValue)
                self?.brightnessLimitMaxField?.lowerLimit = Double(change.newValue + 1)
            }
        }
        brightnessLimitMaxObserver = Defaults.observe(.brightnessLimitMax) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.brightnessLimitMaxField?.stringValue = String(change.newValue)
                self?.brightnessLimitMinField?.upperLimit = Double(change.newValue - 1)
            }
        }
    }

    func listenForContrastLimitChange() {
        contrastLimitMinObserver = Defaults.observe(.contrastLimitMin) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.contrastLimitMinField?.stringValue = String(change.newValue)
                self?.contrastLimitMaxField?.lowerLimit = Double(change.newValue + 1)
            }
        }
        contrastLimitMaxObserver = Defaults.observe(.contrastLimitMax) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.contrastLimitMaxField?.stringValue = String(change.newValue)
                self?.contrastLimitMinField?.upperLimit = Double(change.newValue - 1)
            }
        }
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = Defaults.observe(.adaptiveBrightnessMode) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                self?.showRelevantSettings(change.newValue)
            }
        }
    }

    func setupNoonDuration() {
        guard let field = noonDurationField, let caption = noonDurationCaption else { return }

        setupScrollableTextField(
            field, caption: caption,
            settingKeyInt: Defaults.Keys.noonDurationMinutes,
            lowerLimit: 0, upperLimit: 300,
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

        setupScrollableTextField(
            field, caption: caption,
            settingKeyInt: Defaults.Keys.daylightExtensionMinutes,
            lowerLimit: 0, upperLimit: 300,
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
            field, caption: caption,
            settingKeyDouble: Defaults.Keys.curveFactor,
            lowerLimit: 0.0, upperLimit: 10.0,
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
            field, caption: caption,
            settingKeyInt: Defaults.Keys.brightnessOffset,
            lowerLimit: -100, upperLimit: 90,
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, brightnessOffset: value, brightnessClipMin: brightnessAdapter.brightnessClipMin, brightnessClipMax: brightnessAdapter.brightnessClipMax)
            }
        )
    }

    func setupContrastOffset() {
        guard let field = contrastOffsetField, let caption = contrastOffsetCaption else { return }

        setupScrollableTextField(
            field, caption: caption,
            settingKeyInt: Defaults.Keys.contrastOffset,
            lowerLimit: -100, upperLimit: 90,
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, contrastOffset: value, brightnessClipMin: brightnessAdapter.brightnessClipMin, brightnessClipMax: brightnessAdapter.brightnessClipMax)
            }
        )
    }

    func setupBrightnessStep() {
        guard let field = brightnessStepField, let caption = brightnessStepCaption else { return }

        setupScrollableTextField(
            field, caption: caption,
            settingKeyInt: Defaults.Keys.brightnessStep,
            lowerLimit: 1, upperLimit: 99,
            onMouseEnter: { _ in
            },
            onValueChangedInstant: { _, _ in
            }
        )
    }

    func setupPollingInterval() {
        guard let field = pollingIntervalField, let caption = pollingIntervalCaption else { return }

        setupScrollableTextField(
            field, caption: caption,
            settingKeyInt: Defaults.Keys.syncPollingSeconds,
            lowerLimit: 1, upperLimit: 300,
            onMouseEnter: { _ in
            },
            onValueChangedInstant: { _, _ in
            }
        )
    }

    func setupContrastStep() {
        guard let field = contrastStepField, let caption = contrastStepCaption else { return }

        setupScrollableTextField(
            field, caption: caption,
            settingKeyInt: Defaults.Keys.contrastStep,
            lowerLimit: 1, upperLimit: 99,
            onMouseEnter: { _ in
            },
            onValueChangedInstant: { _, _ in
            }
        )
    }

    func setupVolumeStep() {
        guard let field = volumeStepField, let caption = volumeStepCaption else { return }

        setupScrollableTextField(
            field, caption: caption,
            settingKeyInt: Defaults.Keys.volumeStep,
            lowerLimit: 1, upperLimit: 99,
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
            minField, caption: minCaption,
            settingKeyInt: Defaults.Keys.brightnessClipMin,
            lowerLimit: 0, upperLimit: brightnessAdapter.brightnessClipMax - 1,
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, brightnessClipMin: Double(value), brightnessClipMax: brightnessAdapter.brightnessClipMax)
            }
        )
        setupScrollableTextField(
            maxField, caption: maxCaption,
            settingKeyInt: Defaults.Keys.brightnessClipMax,
            lowerLimit: brightnessAdapter.brightnessClipMin + 1, upperLimit: 100,
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
            minField, caption: minCaption,
            settingKeyInt: Defaults.Keys.brightnessLimitMin,
            lowerLimit: 0, upperLimit: Double(Defaults[.brightnessLimitMax] - 1),
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, brightnessLimitMin: value)
            }
        )
        setupScrollableTextField(
            maxField, caption: maxCaption,
            settingKeyInt: Defaults.Keys.brightnessLimitMax,
            lowerLimit: Double(Defaults[.brightnessLimitMin] + 1), upperLimit: 100,
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
            minField, caption: minCaption,
            settingKeyInt: Defaults.Keys.contrastLimitMin,
            lowerLimit: 0, upperLimit: Double(Defaults[.contrastLimitMax] - 1),
            onValueChangedInstant: { value, settingsController in
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, contrastLimitMin: value)
            }
        )
        setupScrollableTextField(
            maxField, caption: maxCaption,
            settingKeyInt: Defaults.Keys.contrastLimitMax,
            lowerLimit: Double(Defaults[.contrastLimitMin] + 1), upperLimit: 100,
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
            latField, caption: latCaption, settingKeyDouble: Defaults.Keys.locationLat, lowerLimit: -90.00, upperLimit: 90.00,
            onMouseEnter: { _ in disableLeftRightHotkeys() },
            onMouseExit: { _ in appDelegate().setupHotkeys() },
            onValueChangedDouble: { _, settingsController in
                Defaults[.manualLocation] = true
                settingsController?.updateDataset(display: brightnessAdapter.firstDisplay)
            }
        )
        setupScrollableTextField(
            lonField, caption: lonCaption, settingKeyDouble: Defaults.Keys.locationLon, lowerLimit: -180.00, upperLimit: 180.00,
            onMouseEnter: { _ in disableLeftRightHotkeys() },
            onMouseExit: { _ in appDelegate().setupHotkeys() },
            onValueChangedDouble: { _, settingsController in
                Defaults[.manualLocation] = true
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
        _ field: ScrollableTextField, caption: ScrollableTextFieldCaption,
        settingKeyInt: Defaults.Key<Int>? = nil,
        settingKeyDouble: Defaults.Key<Double>? = nil,
        lowerLimit: Double, upperLimit: Double,
        onMouseEnter: ((SettingsPageController?) -> Void)? = nil,
        onMouseExit: ((SettingsPageController?) -> Void)? = nil,
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
            field.doubleValue = Defaults[settingKeyDouble!]
            field.onValueChangedDouble = { (value: Double) in
                Defaults[settingKeyDouble!] = value
            }
        } else {
            field.integerValue = Defaults[settingKeyInt!]
            field.onValueChanged = { (value: Int) in
                Defaults[settingKeyInt!] = value
            }
        }
        field.lowerLimit = lowerLimit
        field.upperLimit = upperLimit
        if let handler = onValueChangedInstant {
            field.onValueChangedInstant = { [weak settingsController = self.settingsController] value in
                handler(value, settingsController)
            }
        }
        if let handler = onValueChangedInstantDouble {
            field.onValueChangedInstantDouble = { [weak settingsController = self.settingsController] value in
                handler(value, settingsController)
            }
        }
        if let handler = onValueChanged {
            field.onValueChanged = { [weak settingsController = self.settingsController] value in
                Defaults[settingKeyInt!] = value
                handler(value, settingsController)
            }
        }
        if let handler = onValueChangedDouble {
            field.onValueChangedDouble = { [weak settingsController = self.settingsController] value in
                Defaults[settingKeyDouble!] = value
                handler(value, settingsController)
            }
        }
        if let handler = onMouseExit {
            field.onMouseExit = { [weak settingsController = self.settingsController] in
                handler(settingsController)
            }
        }

        if let handler = onMouseEnter {
            field.onMouseEnter = { [weak settingsController = self.settingsController] in
                handler(settingsController)
            }
        } else {
            field.onMouseEnter = { [weak settingsController = self.settingsController] in
                if brightnessAdapter.mode == .sync {
                    settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, brightnessClipMin: brightnessAdapter.brightnessClipMin, brightnessClipMax: brightnessAdapter.brightnessClipMax, withAnimation: true)
                } else {
                    settingsController?.updateDataset(display: brightnessAdapter.firstDisplay, withAnimation: true)
                }
            }
        }
    }

    @IBAction func resetLocation(_: Any?) {
        Defaults[.manualLocation] = false
        appDelegate().startReceivingSignificantLocationChanges()
    }

    func setup() {
        swipeLeftHint?.isHidden = Defaults[.didSwipeToHotkeys]
        didSwipeToHotkeysObserver = Defaults.observe(.didSwipeToHotkeys) { [weak self] change in
            self?.swipeLeftHint?.isHidden = change.newValue
        }

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

        showRelevantSettings(Defaults[.adaptiveBrightnessMode])

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
