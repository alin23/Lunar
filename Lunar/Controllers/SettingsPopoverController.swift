//
//  SettingsPopoverController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 05.04.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Atomics
import Cocoa
import Combine
import Defaults

class SettingsPopoverController: NSViewController {
    let SYNC_MODE_ROLE_HELP_TEXT = """
    ## Description

    `Available only for monitors with a built-in light sensor that are controllable using CoreDisplay`

    This setting allows the user to choose a monitor to be used as the source when a built-in display is not available or can't be used (*e.g. MacBook lid closed, Mac Mini*).

    - `SOURCE`: Sync Mode will read this monitor's brightness/contrast and send it to the other external monitors
    - `TARGET`: Sync Mode will send brightness/contrast to this monitor after detecting a brightness change on the built-in/source monitor
    """
    let ADAPTIVE_HELP_TEXT = """
    ## Description

    `Available only in Sync, Location and Sensor mode`

    This setting allows the user to **pause** the adaptive algorithm on a **per-monitor** basis.

    - `RUNNING` will **allow** Lunar to change the brightness and contrast automatically for this monitor
    - `PAUSED` will **restrict** Lunar from changing the brightness and contrast automatically for this monitor
    """
    let DDC_COLOR_GAIN_HELP_TEXT = """
    ## Description

    These values correspond to the red/green/blue gain values in the monitor OSD.

    The changes will persist even when you change the monitor input.

    You can use them for:
    - **Color Correction**
    - **Warmer/Colder colours**
    """
    let DDC_LIMITS_HELP_TEXT = """
    `Note: these are not soft limits.`

    If your monitor accepts values `up to 100` but looks bad on large values, dont't change these limits. Use the `MAX` limits under the `BRIGHTNESS` and `CONTRAST`.

    ## Description

    Most monitors accept brightness/contrast/volume values between `0` and `100`.

    Some monitors don't abide to this rule and could accept:
    - `Volume` values only up to 50 *(their 100% volume happens on the value 50 instead of 100)*
    - `Brightness` values up to 255 *(these monitors have an extended range and their 100% brightness happens on the value 255 instead of 100)*
    """
    let GAMMA_HELP_TEXT = """
    ## Description

    How these gamma values are applied depends on how the monitor can be controlled:
    - `Software Controls`: the values will be used in computing the gamma table for approximating brightness/contrast changes
    - `Hardware/Native/Network Controls`: the values will be set exactly as they are when `Apply gamma values` is checked
    """
    @IBOutlet var networkControlCheckbox: NSButton!
    @IBOutlet var coreDisplayControlCheckbox: NSButton!
    @IBOutlet var ddcControlCheckbox: NSButton!
    @IBOutlet var gammaControlCheckbox: NSButton!

    @IBOutlet var resetLimitsButton: ResetButton!
    @IBOutlet var resetColorsButton: ResetButton!
    @IBOutlet var resetGammaButton: ResetButton!

    @IBOutlet var brightnessCurveFactorField: ScrollableTextField!
    @IBOutlet var contrastCurveFactorField: ScrollableTextField!

    @IBOutlet var maxDDCBrightnessField: ScrollableTextField!
    @IBOutlet var maxDDCContrastField: ScrollableTextField!
    @IBOutlet var maxDDCVolumeField: ScrollableTextField!

    @IBOutlet var blueGainField: ScrollableTextField!
    @IBOutlet var greenGainField: ScrollableTextField!
    @IBOutlet var redGainField: ScrollableTextField!
    @IBOutlet var gammaRedMin: ScrollableTextField!
    @IBOutlet var gammaRedValue: ScrollableTextField!
    @IBOutlet var gammaRedMax: ScrollableTextField!
    @IBOutlet var gammaGreenMin: ScrollableTextField!
    @IBOutlet var gammaGreenValue: ScrollableTextField!
    @IBOutlet var gammaGreenMax: ScrollableTextField!
    @IBOutlet var gammaBlueMin: ScrollableTextField!
    @IBOutlet var gammaBlueValue: ScrollableTextField!
    @IBOutlet var gammaBlueMax: ScrollableTextField!

    @IBOutlet var adaptAutoToggle: MacToggle!
    @IBOutlet var syncModeRoleToggle: MacToggle!

    @IBOutlet var _ddcLimitsHelpButton: NSButton!
    @IBOutlet var _gammaHelpButton: NSButton!
    @IBOutlet var _adaptAutomaticallyHelpButton: NSButton?
    @IBOutlet var _syncModeRoleHelpButton: NSButton?
    var onClick: (() -> Void)?
    weak var displayViewController: DisplayViewController?
    @Atomic var applySettings = true

    @objc dynamic var manualModeActive = displayController.adaptiveModeKey == .manual
    var displaysObserver: Cancellable?
    var adaptiveModeObserver: Cancellable?

    @IBOutlet var _ddcColorGainHelpButton: NSButton?

    var ddcLimitsHelpButton: HelpButton? {
        _ddcLimitsHelpButton as? HelpButton
    }

    var ddcColorGainHelpButton: HelpButton? {
        _ddcColorGainHelpButton as? HelpButton
    }

    var gammaHelpButton: HelpButton? {
        _gammaHelpButton as? HelpButton
    }

    var adaptAutomaticallyHelpButton: HelpButton? {
        _adaptAutomaticallyHelpButton as? HelpButton
    }

    var syncModeRoleHelpButton: HelpButton? {
        _syncModeRoleHelpButton as? HelpButton
    }

    var lastEnabledCheckbox: NSButton? {
        [networkControlCheckbox, coreDisplayControlCheckbox, ddcControlCheckbox, gammaControlCheckbox]
            .first(where: { checkbox in checkbox!.state == .on })
    }

    weak var display: Display? {
        didSet {
            guard let display = display else { return }

            applySettings = false
            defer {
                applySettings = true
            }

            mainThread {
                networkEnabled = display.enabledControls[.network] ?? true
                coreDisplayEnabled = display.enabledControls[.coreDisplay] ?? true
                ddcEnabled = display.enabledControls[.ddc] ?? true
                gammaEnabled = display.enabledControls[.gamma] ?? true

                adaptAutoToggle.isOn = display.adaptive
                syncModeRoleToggle.isOn = display.isSource
                syncModeRoleToggle.isEnabled = DisplayServicesIsSmartDisplay(display.id) || TEST_MODE

                applyGamma = display.applyGamma
            }
            setupDDCLimits(display)
            setupDDCColorGain(display)
            setupCurveFactors(display)
            setupGamma(display)
        }
    }

    @objc dynamic var brightnessCurveFactor = 1.0 {
        didSet {
            brightnessCurveFactorField.step = brightnessCurveFactor < 1 ? 0.01 : 0.1
            brightnessCurveFactorField.decimalPoints = brightnessCurveFactor < 1 ? 2 : 1

            guard applySettings, let display = display else { return }

            display.brightnessCurveFactor = brightnessCurveFactor
            display.save()
        }
    }

    @objc dynamic var contrastCurveFactor = 1.0 {
        didSet {
            contrastCurveFactorField.step = contrastCurveFactor < 1 ? 0.01 : 0.1
            contrastCurveFactorField.decimalPoints = contrastCurveFactor < 1 ? 2 : 1

            guard applySettings, let display = display else { return }

            display.contrastCurveFactor = contrastCurveFactor
            display.save()
        }
    }

    @objc dynamic var applyGamma = false {
        didSet {
            guard applySettings, let display = display else { return }
            display.applyGamma = applyGamma
            if !(display.control is GammaControl), display.applyGamma || display.gammaChanged {
                display.resetGamma()
            }
            if !display.applyGamma {
                display.gammaChanged = false
            }
            display.save()
        }
    }

    @objc dynamic var adaptive = true {
        didSet {
            guard applySettings, let display = display else { return }
//            if adaptive {
//                display.adaptivePaused = false
//            }
            display.adaptive = adaptive
            display.save()
        }
    }

    @objc dynamic var isSource = false {
        didSet {
            guard applySettings, let display = display else { return }
            display.isSource = isSource
            display.save()
        }
    }

    @objc dynamic var networkEnabled = true {
        didSet {
            guard applySettings, let display = display else { return }
            display.enabledControls[.network] = networkEnabled
            display.save()

            resetControl()
            ensureAtLeastOneControlEnabled()
        }
    }

    @objc dynamic var coreDisplayEnabled = true {
        didSet {
            guard applySettings, let display = display else { return }
            display.enabledControls[.coreDisplay] = coreDisplayEnabled
            display.save()

            resetControl()
            ensureAtLeastOneControlEnabled()
        }
    }

    @objc dynamic var ddcEnabled = true {
        didSet {
            guard applySettings, let display = display else { return }
            display.enabledControls[.ddc] = ddcEnabled
            display.save()

            resetControl()
            ensureAtLeastOneControlEnabled()
        }
    }

    @objc dynamic var gammaEnabled = true {
        didSet {
            guard applySettings, let display = display else { return }
            display.enabledControls[.gamma] = gammaEnabled
            display.save()

            resetControl()
            ensureAtLeastOneControlEnabled()
        }
    }

    @IBAction func resetLimits(_ sender: Any) {
        guard let display = display else {
            return
        }

        display.maxDDCBrightness = 100.ns
        display.maxDDCContrast = 100.ns
        display.maxDDCVolume = 100.ns

        setupDDCLimits(display)
    }

    @IBAction func resetColors(_ sender: Any) {
        guard let display = display, display.hasI2C, let control = display.control, !(control is GammaControl) else {
            return
        }

        control.resetColors()
        if !display.refreshColors() {
            display.redGain = 90
            display.greenGain = 90
            display.blueGain = 90
        }

        setupDDCColorGain(display)
    }

    @IBAction func resetGamma(_ sender: Any) {
        guard let display = display else {
            return
        }

        display.resetDefaultGamma()
        setupGamma(display)
    }

    func resetControl() {
        guard let display = display else { return }
        let control = display.getBestControl()
        display.control = control
        display.onControlChange?(control)

        if !gammaEnabled, display.applyGamma || display.gammaChanged {
            display.resetGamma()
        }
    }

    func ensureAtLeastOneControlEnabled() {
        guard let display = display else { return }
        if display.enabledControls.values.filter({ enabled in enabled }).count <= 1 {
            if let checkbox = lastEnabledCheckbox {
                mainThread {
                    checkbox.isEnabled = false
                    checkbox.needsDisplay = true
                }
            } else {
                applySettings = false
                gammaEnabled = true
                display.enabledControls[.gamma] = gammaEnabled
                applySettings = true

                mainThread {
                    gammaControlCheckbox.isEnabled = false
                    gammaControlCheckbox.needsDisplay = true
                }
            }
        } else {
            mainThread {
                networkControlCheckbox.isEnabled = true
                coreDisplayControlCheckbox.isEnabled = true
                ddcControlCheckbox.isEnabled = true
                gammaControlCheckbox.isEnabled = true

                networkControlCheckbox.needsDisplay = true
                coreDisplayControlCheckbox.needsDisplay = true
                ddcControlCheckbox.needsDisplay = true
                gammaControlCheckbox.needsDisplay = true
            }
        }
    }

    @inline(__always) func toggleWithoutCallback(_ toggle: MacToggle, value: Bool) {
        let callback = toggle.callback
        toggle.callback = nil
        toggle.isOn = value
        toggle.callback = callback
    }

    func setupDDCLimits(_ display: Display? = nil) {
        if let display = display ?? self.display {
            mainThread {
                maxDDCBrightnessField.intValue = display.maxDDCBrightness.int32Value
                maxDDCContrastField.intValue = display.maxDDCContrast.int32Value
                maxDDCVolumeField.intValue = display.maxDDCVolume.int32Value
            }

            maxDDCBrightnessField.onValueChanged = { [weak self] value in self?.display?.maxDDCBrightness = value.ns }
            maxDDCContrastField.onValueChanged = { [weak self] value in self?.display?.maxDDCContrast = value.ns }
            maxDDCVolumeField.onValueChanged = { [weak self] value in self?.display?.maxDDCVolume = value.ns }
        }
    }

    func setupDDCColorGain(_ display: Display? = nil) {
        if let display = display ?? self.display {
            mainThread {
                redGainField.intValue = display.redGain.int32Value
                greenGainField.intValue = display.greenGain.int32Value
                blueGainField.intValue = display.blueGain.int32Value
            }

            redGainField.onValueChanged = { [weak self] value in self?.display?.redGain = value.ns }
            greenGainField.onValueChanged = { [weak self] value in self?.display?.greenGain = value.ns }
            blueGainField.onValueChanged = { [weak self] value in self?.display?.blueGain = value.ns }
        }
    }

    func setupCurveFactors(_ display: Display? = nil) {
        guard let display = display ?? self.display else { return }
        mainThread {
            applySettings = false
            defer { applySettings = true }
            brightnessCurveFactor = display.brightnessCurveFactor
            contrastCurveFactor = display.contrastCurveFactor
        }

        brightnessCurveFactorField.onValueChangedDouble = { [weak self] value in
            self?.display?.brightnessCurveFactor = value
        }
        brightnessCurveFactorField.onValueChangedInstantDouble = { [weak self] value in
            self?.displayViewController?.updateDataset(brightnessFactor: value)
            guard let brightnessField = self?.brightnessCurveFactorField else { return }
            brightnessField.step = value < 1 ? 0.01 : 0.1
            brightnessField.decimalPoints = value < 1 ? 2 : 1
        }

        contrastCurveFactorField.onValueChangedDouble = { [weak self] value in
            self?.display?.contrastCurveFactor = value
        }
        contrastCurveFactorField.onValueChangedInstantDouble = { [weak self] value in
            self?.displayViewController?.updateDataset(contrastFactor: value)
            guard let contrastField = self?.contrastCurveFactorField else { return }
            contrastField.step = value < 1 ? 0.01 : 0.1
            contrastField.decimalPoints = value < 1 ? 2 : 1
        }
    }

    func setupGamma(_ display: Display? = nil) {
        if let display = display ?? self.display {
            mainThread {
                gammaRedMin.floatValue = display.defaultGammaRedMin.floatValue
                gammaRedMax.floatValue = display.defaultGammaRedMax.floatValue
                gammaRedValue.floatValue = display.defaultGammaRedValue.floatValue
                gammaGreenMin.floatValue = display.defaultGammaGreenMin.floatValue
                gammaGreenMax.floatValue = display.defaultGammaGreenMax.floatValue
                gammaGreenValue.floatValue = display.defaultGammaGreenValue.floatValue
                gammaBlueMin.floatValue = display.defaultGammaBlueMin.floatValue
                gammaBlueMax.floatValue = display.defaultGammaBlueMax.floatValue
                gammaBlueValue.floatValue = display.defaultGammaBlueValue.floatValue

                gammaRedMax.lowerLimit = gammaRedMin.doubleValue + 0.01
                gammaRedMin.upperLimit = gammaRedMax.doubleValue - 0.01
                gammaGreenMax.lowerLimit = gammaGreenMin.doubleValue + 0.01
                gammaGreenMin.upperLimit = gammaGreenMax.doubleValue - 0.01
                gammaBlueMax.lowerLimit = gammaBlueMin.doubleValue + 0.01
                gammaBlueMin.upperLimit = gammaBlueMax.doubleValue - 0.01
            }

            gammaRedMin.onValueChangedInstantDouble = { [weak self] value in
                guard let self = self else { return }
                self.display?.defaultGammaRedMin = value.ns
                self.gammaRedMax.lowerLimit = self.gammaRedMin.doubleValue + 0.01
            }
            gammaRedMax.onValueChangedInstantDouble = { [weak self] value in
                guard let self = self else { return }
                self.display?.defaultGammaRedMax = value.ns
                self.gammaRedMin.upperLimit = self.gammaRedMax.doubleValue - 0.01
            }
            gammaRedValue.onValueChangedInstantDouble = { [weak self] value in
                self?.display?.defaultGammaRedValue = value.ns
            }
            gammaGreenMin.onValueChangedInstantDouble = { [weak self] value in
                guard let self = self else { return }
                self.display?.defaultGammaGreenMin = value.ns
                self.gammaGreenMax.lowerLimit = self.gammaGreenMin.doubleValue + 0.01
            }
            gammaGreenMax.onValueChangedInstantDouble = { [weak self] value in
                guard let self = self else { return }
                self.display?.defaultGammaGreenMax = value.ns
                self.gammaGreenMin.upperLimit = self.gammaGreenMax.doubleValue - 0.01
            }
            gammaGreenValue.onValueChangedInstantDouble = { [weak self] value in
                self?.display?.defaultGammaGreenValue = value.ns
            }
            gammaBlueMin.onValueChangedInstantDouble = { [weak self] value in
                guard let self = self else { return }
                self.display?.defaultGammaBlueMin = value.ns
                self.gammaBlueMax.lowerLimit = self.gammaBlueMin.doubleValue + 0.01
            }
            gammaBlueMax.onValueChangedInstantDouble = { [weak self] value in
                guard let self = self else { return }
                self.display?.defaultGammaBlueMax = value.ns
                self.gammaBlueMin.upperLimit = self.gammaBlueMax.doubleValue - 0.01
            }
            gammaBlueValue.onValueChangedInstantDouble = { [weak self] value in
                self?.display?.defaultGammaBlueValue = value.ns
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        syncModeRoleHelpButton?.helpText = SYNC_MODE_ROLE_HELP_TEXT
        adaptAutomaticallyHelpButton?.helpText = ADAPTIVE_HELP_TEXT
        ddcLimitsHelpButton?.helpText = DDC_LIMITS_HELP_TEXT
        ddcColorGainHelpButton?.helpText = DDC_COLOR_GAIN_HELP_TEXT
        gammaHelpButton?.helpText = GAMMA_HELP_TEXT

        resetLimitsButton.page = .hotkeysReset
        resetColorsButton.page = .hotkeysReset
        resetGammaButton.page = .hotkeysReset

        gammaRedMin.decimalPoints = 2
        gammaRedMax.decimalPoints = 2
        gammaRedValue.decimalPoints = 2
        gammaGreenMin.decimalPoints = 2
        gammaGreenMax.decimalPoints = 2
        gammaGreenValue.decimalPoints = 2
        gammaBlueMin.decimalPoints = 2
        gammaBlueMax.decimalPoints = 2
        gammaBlueValue.decimalPoints = 2

        adaptAutoToggle.callback = { [weak self] isOn in
            self?.adaptive = isOn
        }

        syncModeRoleToggle.callback = { [weak self] isOn in
            guard let self = self, let display = self.display else { return }
            self.isSource = isOn
            if isOn {
                for targetDisplay in displayController.displays.values {
                    if display.id != targetDisplay.id {
                        targetDisplay.isSource = false
                    }
                }
                datastore.storeDisplays(displayController.displays.values.map { $0 })
            }
            SyncMode.sourceDisplayID = SyncMode.getSourceDisplay()
        }
        if let id = display?.id {
            syncModeRoleToggle.isEnabled = DisplayServicesIsSmartDisplay(id) || TEST_MODE
        } else {
            syncModeRoleToggle.isEnabled = false
        }
        setupDDCLimits()
        setupDDCColorGain()
        setupCurveFactors()
        setupGamma()

        adaptiveModeObserver = adaptiveModeObserver ?? adaptiveBrightnessModePublisher.sink { [weak self] change in
            guard let self = self, let display = self.display else { return }
            mainThread {
                self.applySettings = false
                defer { self.applySettings = true }

                self.brightnessCurveFactor = display.brightnessCurveFactors[change.newValue] ?? 1.0
                self.contrastCurveFactor = display.contrastCurveFactors[change.newValue] ?? 1.0
                self.manualModeActive = change.newValue == .manual
            }
        }

        displaysObserver = displaysObserver ?? CachedDefaults.displaysPublisher.sink { [weak self] displays in
            guard let self = self, let thisDisplay = self.display,
                  let display = displays.first(where: { d in d.serial == thisDisplay.serial }) else { return }
            self.applySettings = false
            defer {
                self.applySettings = true
            }
            self.networkEnabled = display.enabledControls[.network] ?? true
            self.coreDisplayEnabled = display.enabledControls[.coreDisplay] ?? true
            self.ddcEnabled = display.enabledControls[.ddc] ?? true
            self.gammaEnabled = display.enabledControls[.gamma] ?? true
            mainThread {
                self.toggleWithoutCallback(self.adaptAutoToggle, value: display.adaptive)
                self.toggleWithoutCallback(self.syncModeRoleToggle, value: display.isSource)
            }
            self.applyGamma = display.applyGamma
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        super.mouseDown(with: event)
    }
}
