//
//  ConfigurationViewController.swift
//  Lunar
//
//  Created by Alin on 16/04/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

let CHECKBOX_SIZE = 32

class ConfigurationViewController: NSViewController {
    @IBOutlet var smoothTransitionLabel: NSTextField!
    @IBOutlet var smoothTransitionCheckbox: NSButton!

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
    var brightnessOffsetVisible: Bool = false {
        didSet {
            brightnessOffsetField?.isHidden = !brightnessOffsetVisible
            brightnessOffsetCaption?.isHidden = !brightnessOffsetVisible
            brightnessOffsetLabel?.isHidden = !brightnessOffsetVisible
        }
    }

    @IBOutlet var contrastOffsetField: ScrollableTextField!
    @IBOutlet var contrastOffsetCaption: ScrollableTextFieldCaption!
    @IBOutlet var contrastOffsetLabel: NSTextField!
    var contrastOffsetVisible: Bool = false {
        didSet {
            contrastOffsetField?.isHidden = !contrastOffsetVisible
            contrastOffsetCaption?.isHidden = !contrastOffsetVisible
            contrastOffsetLabel?.isHidden = !contrastOffsetVisible
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

    @IBOutlet var swipeLeftHint: NSTextField!

    var curveFactorObserver: NSKeyValueObservation?
    var brightnessOffsetObserver: NSKeyValueObservation?
    var contrastOffsetObserver: NSKeyValueObservation?
    var brightnessLimitMinObserver: NSKeyValueObservation?
    var contrastLimitMinObserver: NSKeyValueObservation?
    var brightnessLimitMaxObserver: NSKeyValueObservation?
    var contrastLimitMaxObserver: NSKeyValueObservation?
    var didSwipeToHotkeysObserver: NSKeyValueObservation?
    var adaptiveModeObserver: NSKeyValueObservation?

    func showRelevantSettings(_ adaptiveMode: AdaptiveMode) {
        noonDurationVisible = adaptiveMode == .location
        daylightExtensionVisible = adaptiveMode == .location
        curveFactorVisible = adaptiveMode == .location
        brightnessOffsetVisible = adaptiveMode == .sync
        contrastOffsetVisible = adaptiveMode == .sync
        brightnessLimitVisible = adaptiveMode == .manual
        contrastLimitVisible = adaptiveMode == .manual

        var refX: CGFloat
        switch adaptiveMode {
        case .manual:
            let refFrame1 = contrastLimitMinField.frame
            let refFrame2 = contrastLimitMaxField.frame
            let width = refFrame2.maxX - refFrame1.minX
            refX = refFrame2.maxX - (width / 2)
        case .location:
            let refFrame = daylightExtensionField.frame
            refX = refFrame.maxX - (refFrame.width / 2)
        case .sync:
            let refFrame = contrastOffsetField.frame
            refX = refFrame.maxX - (refFrame.width / 2)
        }

        smoothTransitionCheckbox.setFrameOrigin(NSPoint(
            x: refX - CGFloat(CHECKBOX_SIZE / 2),
            y: smoothTransitionCheckbox.frame.origin.y
        ))
    }

    func listenForCurveFactorChange() {
        curveFactorObserver = datastore.defaults.observe(\.curveFactor, options: [.old, .new], changeHandler: { _, change in
            guard let value = change.newValue, let oldValue = change.oldValue, value != oldValue else {
                return
            }
            self.curveFactorField?.doubleValue = value
        })
    }

    func listenForBrightnessOffsetChange() {
        brightnessOffsetObserver = datastore.defaults.observe(\.brightnessOffset, options: [.old, .new], changeHandler: { _, change in
            guard let brightness = change.newValue, let oldBrightness = change.oldValue, brightness != oldBrightness else {
                return
            }
            self.brightnessOffsetField?.stringValue = String(brightness)
        })
    }

    func listenForContrastOffsetChange() {
        contrastOffsetObserver = datastore.defaults.observe(\.contrastOffset, options: [.old, .new], changeHandler: { _, change in
            guard let contrast = change.newValue, let oldContrast = change.oldValue, contrast != oldContrast else {
                return
            }
            self.contrastOffsetField?.stringValue = String(contrast)
        })
    }

    func listenForBrightnessLimitChange() {
        brightnessLimitMinObserver = datastore.defaults.observe(\.brightnessLimitMin, options: [.old, .new], changeHandler: { _, change in
            guard let brightness = change.newValue, let oldBrightness = change.oldValue, brightness != oldBrightness else {
                return
            }
            self.brightnessLimitMinField?.stringValue = String(brightness)
            self.brightnessLimitMaxField?.lowerLimit = Double(brightness + 1)
        })
        brightnessLimitMaxObserver = datastore.defaults.observe(\.brightnessLimitMax, options: [.old, .new], changeHandler: { _, change in
            guard let brightness = change.newValue, let oldBrightness = change.oldValue, brightness != oldBrightness else {
                return
            }
            self.brightnessLimitMaxField?.stringValue = String(brightness)
            self.brightnessLimitMinField?.upperLimit = Double(brightness - 1)
        })
    }

    func listenForContrastLimitChange() {
        contrastLimitMinObserver = datastore.defaults.observe(\.contrastLimitMin, options: [.old, .new], changeHandler: { _, change in
            guard let contrast = change.newValue, let oldContrast = change.oldValue, contrast != oldContrast else {
                return
            }
            self.contrastLimitMinField?.stringValue = String(contrast)
            self.contrastLimitMaxField?.lowerLimit = Double(contrast + 1)
        })
        contrastLimitMaxObserver = datastore.defaults.observe(\.contrastLimitMax, options: [.old, .new], changeHandler: { _, change in
            guard let contrast = change.newValue, let oldContrast = change.oldValue, contrast != oldContrast else {
                return
            }
            self.contrastLimitMaxField?.stringValue = String(contrast)
            self.contrastLimitMinField?.upperLimit = Double(contrast - 1)
        })
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = datastore.defaults.observe(\.adaptiveBrightnessMode, options: [.old, .new], changeHandler: { _, change in
            guard let mode = change.newValue, let oldMode = change.oldValue, mode != oldMode else {
                return
            }
            if let adaptiveMode = AdaptiveMode(rawValue: mode) {
                self.showRelevantSettings(adaptiveMode)
            }
        })
    }

    func setupNoonDuration() {
        guard let field = noonDurationField, let caption = noonDurationCaption else { return }

        noonDurationLabel?.toolTip = """
        The number of minutes for which the daylight in your area is very high
        This keeps the brightness/contrast at its highest value for as much as needed
        """

        setupScrollableTextField(
            field, caption: caption, settingKey: "noonDurationMinutes", lowerLimit: 0, upperLimit: 240,
            onMouseEnter: { settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, noonDuration: self.noonDurationField.integerValue, withAnimation: true)
            },
            onValueChangedInstant: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, noonDuration: value)
            }
        )
    }

    func setupDaylightExtension() {
        guard let field = daylightExtensionField, let caption = daylightExtensionCaption else { return }

        daylightExtensionLabel?.toolTip = """
        The number of minutes for which the daylight in your area is still visible before sunrise and after sunset
        This keeps the brightness/contrast from going to its lowest value too soon
        """

        setupScrollableTextField(
            field, caption: caption, settingKey: "daylightExtensionMinutes", lowerLimit: 0, upperLimit: 240,
            onMouseEnter: { settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, daylightExtension: self.daylightExtensionField.integerValue, withAnimation: true)
            },
            onValueChangedInstant: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, daylightExtension: value)
            }
        )
    }

    func setupCurveFactor() {
        guard let field = curveFactorField, let caption = curveFactorCaption else { return }

        curveFactorLabel?.toolTip = """
        Value for adjusting the brightness/contrast curve
        """
        curveFactorField.decimalPoints = 1
        curveFactorField.step = 0.1

        setupScrollableTextField(
            field, caption: caption, settingKey: "curveFactor", lowerLimit: 0.0, upperLimit: 10.0,
            onMouseEnter: { settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, factor: self.curveFactorField.doubleValue, withAnimation: true)
            },
            onValueChangedInstantDouble: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, factor: value)
            }
        )
    }

    func setupBrightnessOffset() {
        guard let field = brightnessOffsetField, let caption = brightnessOffsetCaption else { return }

        brightnessOffsetLabel?.toolTip = """
        Factor for adjusting the brightness curve of the adaptive algorithm
        """

        setupScrollableTextField(
            field, caption: caption, settingKey: "brightnessOffset", lowerLimit: -100, upperLimit: 90,
            onValueChangedInstant: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, brightnessOffset: value)
            }
        )
    }

    func setupContrastOffset() {
        guard let field = contrastOffsetField, let caption = contrastOffsetCaption else { return }

        contrastOffsetLabel?.toolTip = """
        Factor for adjusting the contrast curve of the adaptive algorithm
        """

        setupScrollableTextField(
            field, caption: caption, settingKey: "contrastOffset", lowerLimit: -100, upperLimit: 90,
            onValueChangedInstant: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, contrastOffset: value)
            }
        )
    }

    func setupBrightnessLimit() {
        guard let minField = brightnessLimitMinField,
            let maxField = brightnessLimitMaxField,
            let minCaption = brightnessLimitMinCaption,
            let maxCaption = brightnessLimitMaxCaption else { return }

        brightnessLimitLabel?.toolTip = """
        Hard limits for brightness percentage adjustments through hotkeys or menu items
        """

        setupScrollableTextField(
            minField, caption: minCaption, settingKey: "brightnessLimitMin", lowerLimit: 0, upperLimit: Double(datastore.defaults.brightnessLimitMax - 1),
            onValueChangedInstant: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, brightnessLimitMin: value)
            }
        )
        setupScrollableTextField(
            maxField, caption: maxCaption, settingKey: "brightnessLimitMax", lowerLimit: Double(datastore.defaults.brightnessLimitMin + 1), upperLimit: 100,
            onValueChangedInstant: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, brightnessLimitMax: value)
            }
        )
    }

    func setupContrastLimit() {
        guard let minField = contrastLimitMinField,
            let maxField = contrastLimitMaxField,
            let minCaption = contrastLimitMinCaption,
            let maxCaption = contrastLimitMaxCaption else { return }

        contrastLimitLabel?.toolTip = """
        Hard limits for contrast percentage adjustments through hotkeys or menu items
        """

        setupScrollableTextField(
            minField, caption: minCaption, settingKey: "contrastLimitMin", lowerLimit: 0, upperLimit: Double(datastore.defaults.contrastLimitMax - 1),
            onValueChangedInstant: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, contrastLimitMin: value)
            }
        )
        setupScrollableTextField(
            maxField, caption: maxCaption, settingKey: "contrastLimitMax", lowerLimit: Double(datastore.defaults.contrastLimitMin + 1), upperLimit: 100,
            onValueChangedInstant: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, contrastLimitMax: value)
            }
        )
    }

    func setupScrollableTextField(
        _ field: ScrollableTextField, caption: ScrollableTextFieldCaption, settingKey: String,
        lowerLimit: Double, upperLimit: Double,
        onMouseEnter: ((SettingsPageController) -> Void)? = nil,
        onValueChangedInstant: ((Int, SettingsPageController) -> Void)? = nil,
        onValueChangedInstantDouble: ((Double, SettingsPageController) -> Void)? = nil
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
        if let settingsController = parent?.parent as? SettingsPageController {
            if let handler = onValueChangedInstant {
                field.onValueChangedInstant = { value in
                    handler(value, settingsController)
                }
            }
            if let handler = onValueChangedInstantDouble {
                field.onValueChangedInstantDouble = { value in
                    handler(value, settingsController)
                }
            }
            if let handler = onMouseEnter {
                field.onMouseEnter = {
                    handler(settingsController)
                }
            } else {
                field.onMouseEnter = {
                    settingsController.updateDataset(display: brightnessAdapter.firstDisplay, withAnimation: true)
                }
            }
        }
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
        setupBrightnessLimit()
        setupContrastLimit()

        smoothTransitionCheckbox.setFrameSize(NSSize(width: CHECKBOX_SIZE, height: CHECKBOX_SIZE))
        smoothTransitionCheckbox.setNeedsDisplay()
        smoothTransitionLabel.toolTip = """
        Allows brightness/contrast to change smoothly from a value to another
        Note: this can make the system lag in transitions if the monitor has a slow response time
        """

        if let mode = AdaptiveMode(rawValue: datastore.defaults.adaptiveBrightnessMode) {
            showRelevantSettings(mode)
        }

        listenForCurveFactorChange()
        listenForBrightnessOffsetChange()
        listenForContrastOffsetChange()
        listenForBrightnessLimitChange()
        listenForContrastLimitChange()
        listenForAdaptiveModeChange()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
}
