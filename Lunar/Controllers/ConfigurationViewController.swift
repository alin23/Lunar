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
            self.brightnessLimitMaxField?.lowerLimit = brightness + 1
        })
        brightnessLimitMaxObserver = datastore.defaults.observe(\.brightnessLimitMax, options: [.old, .new], changeHandler: { _, change in
            guard let brightness = change.newValue, let oldBrightness = change.oldValue, brightness != oldBrightness else {
                return
            }
            self.brightnessLimitMaxField?.stringValue = String(brightness)
            self.brightnessLimitMinField?.upperLimit = brightness - 1
        })
    }

    func listenForContrastLimitChange() {
        contrastLimitMinObserver = datastore.defaults.observe(\.contrastLimitMin, options: [.old, .new], changeHandler: { _, change in
            guard let contrast = change.newValue, let oldContrast = change.oldValue, contrast != oldContrast else {
                return
            }
            self.contrastLimitMinField?.stringValue = String(contrast)
            self.contrastLimitMaxField?.lowerLimit = contrast + 1
        })
        contrastLimitMaxObserver = datastore.defaults.observe(\.contrastLimitMax, options: [.old, .new], changeHandler: { _, change in
            guard let contrast = change.newValue, let oldContrast = change.oldValue, contrast != oldContrast else {
                return
            }
            self.contrastLimitMaxField?.stringValue = String(contrast)
            self.contrastLimitMinField?.upperLimit = contrast - 1
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

    func setupBrightnessOffset() {
        guard let field = brightnessOffsetField, let caption = brightnessOffsetCaption else { return }

        setupScrollableTextField(
            field, caption: caption, settingKey: "brightnessOffset", lowerLimit: -100, upperLimit: 90,
            onValueChangedInstant: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, brightnessOffset: value)
            }
        )
    }

    func setupContrastOffset() {
        guard let field = contrastOffsetField, let caption = contrastOffsetCaption else { return }

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

        setupScrollableTextField(
            minField, caption: minCaption, settingKey: "brightnessLimitMin", lowerLimit: 0, upperLimit: datastore.defaults.brightnessLimitMax - 1,
            onValueChangedInstant: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, brightnessLimitMin: value)
            }
        )
        setupScrollableTextField(
            maxField, caption: maxCaption, settingKey: "brightnessLimitMax", lowerLimit: datastore.defaults.brightnessLimitMin + 1, upperLimit: 100,
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

        setupScrollableTextField(
            minField, caption: minCaption, settingKey: "contrastLimitMin", lowerLimit: 0, upperLimit: datastore.defaults.contrastLimitMax - 1,
            onValueChangedInstant: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, contrastLimitMin: value)
            }
        )
        setupScrollableTextField(
            maxField, caption: maxCaption, settingKey: "contrastLimitMax", lowerLimit: datastore.defaults.contrastLimitMin + 1, upperLimit: 100,
            onValueChangedInstant: { value, settingsController in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, contrastLimitMax: value)
            }
        )
    }

    func setupScrollableTextField(
        _ field: ScrollableTextField, caption: ScrollableTextFieldCaption, settingKey: String,
        lowerLimit: Int, upperLimit: Int,
        onMouseEnter: ((SettingsPageController) -> Void)? = nil,
        onValueChangedInstant: ((Int, SettingsPageController) -> Void)? = nil
    ) {
        field.textFieldColor = scrollableTextFieldColorWhite
        field.textFieldColorHover = scrollableTextFieldColorHoverWhite
        field.textFieldColorLight = scrollableTextFieldColorLightWhite
        caption.textColor = scrollableCaptionColorWhite
        field.caption = caption

        field.integerValue = datastore.defaults.integer(forKey: settingKey)
        field.onValueChanged = { (value: Int) in
            datastore.defaults.set(value, forKey: settingKey)
        }
        field.lowerLimit = lowerLimit
        field.upperLimit = upperLimit
        if let settingsController = parent?.parent as? SettingsPageController {
            if let handler = onValueChangedInstant {
                field.onValueChangedInstant = { value in
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
        setupBrightnessOffset()
        setupContrastOffset()
        setupBrightnessLimit()
        setupContrastLimit()

        smoothTransitionCheckbox.setFrameSize(NSSize(width: CHECKBOX_SIZE, height: CHECKBOX_SIZE))

        if let mode = AdaptiveMode(rawValue: datastore.defaults.adaptiveBrightnessMode) {
            showRelevantSettings(mode)
        }

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
