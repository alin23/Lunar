//
//  ConfigurationViewController.swift
//  Lunar
//
//  Created by Alin on 16/04/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

class ConfigurationViewController: NSViewController {
    @IBOutlet var noonDurationField: ScrollableTextField!
    @IBOutlet var noonDurationCaption: ScrollableTextFieldCaption!
    @IBOutlet var noonDurationLabel: NSTextField!

    @IBOutlet var daylightExtensionField: ScrollableTextField!
    @IBOutlet var daylightExtensionCaption: ScrollableTextFieldCaption!
    @IBOutlet var daylightExtensionLabel: NSTextField!

    @IBOutlet var brightnessOffsetField: ScrollableTextField!
    @IBOutlet var brightnessOffsetCaption: ScrollableTextFieldCaption!
    @IBOutlet var brightnessOffsetLabel: NSTextField!

    @IBOutlet var contrastOffsetField: ScrollableTextField!
    @IBOutlet var contrastOffsetCaption: ScrollableTextFieldCaption!
    @IBOutlet var contrastOffsetLabel: NSTextField!

    var brightnessOffsetObserver: NSKeyValueObservation?
    var contrastOffsetObserver: NSKeyValueObservation?

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

    func setupNoonDuration() {
        noonDurationField?.integerValue = datastore.defaults.noonDurationMinutes
        noonDurationField?.onValueChanged = { (value: Int) in
            datastore.defaults.set(value, forKey: "noonDurationMinutes")
        }
        noonDurationField?.lowerLimit = 0
        noonDurationField?.upperLimit = 240
        if let settingsController = parent?.parent as? SettingsPageController {
            noonDurationField?.onValueChangedInstant = { value in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, noonDuration: value)
            }
            noonDurationField?.onMouseEnter = {
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, noonDuration: self.noonDurationField.integerValue, withAnimation: true)
            }
        }
    }

    func setupBrightnessOffset() {
        brightnessOffsetField?.integerValue = datastore.defaults.brightnessOffset
        brightnessOffsetField?.onValueChanged = { (value: Int) in
            datastore.defaults.set(value, forKey: "brightnessOffset")
        }
        brightnessOffsetField?.lowerLimit = -100
        brightnessOffsetField?.upperLimit = 90
        if let settingsController = parent?.parent as? SettingsPageController {
            brightnessOffsetField?.onValueChangedInstant = { value in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, brightnessOffset: value)
            }
            brightnessOffsetField?.onMouseEnter = {
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, withAnimation: true)
            }
        }
    }

    func setupContrastOffset() {
        contrastOffsetField?.integerValue = datastore.defaults.contrastOffset
        contrastOffsetField?.onValueChanged = { (value: Int) in
            datastore.defaults.set(value, forKey: "contrastOffset")
        }
        contrastOffsetField?.lowerLimit = -100
        contrastOffsetField?.upperLimit = 90
        if let settingsController = parent?.parent as? SettingsPageController {
            contrastOffsetField?.onValueChangedInstant = { value in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, contrastOffset: value)
            }
            contrastOffsetField?.onMouseEnter = {
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, withAnimation: true)
            }
        }
    }

    func setupDaylightExtension() {
        daylightExtensionField?.integerValue = datastore.defaults.daylightExtensionMinutes
        daylightExtensionField?.onValueChanged = { (value: Int) in
            datastore.defaults.set(value, forKey: "daylightExtensionMinutes")
        }
        daylightExtensionField?.lowerLimit = 0
        daylightExtensionField?.upperLimit = 240
        if let settingsController = parent?.parent as? SettingsPageController {
            daylightExtensionField?.onValueChangedInstant = { value in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, daylightExtension: value)
            }
            daylightExtensionField?.onMouseEnter = {
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, daylightExtension: self.daylightExtensionField.integerValue, withAnimation: true)
            }
        }
    }

    @IBAction func goToHotkeys(_: Any?) {
        if let settingsController = parent?.parent as? SettingsPageController {
            settingsController.pageController?.navigateBack(nil)
        }
    }

    func setup() {
        noonDurationField?.textFieldColor = scrollableTextFieldColorWhite
        noonDurationField?.textFieldColorHover = scrollableTextFieldColorHoverWhite
        noonDurationField?.textFieldColorLight = scrollableTextFieldColorLightWhite

        daylightExtensionField?.textFieldColor = scrollableTextFieldColorWhite
        daylightExtensionField?.textFieldColorHover = scrollableTextFieldColorHoverWhite
        daylightExtensionField?.textFieldColorLight = scrollableTextFieldColorLightWhite

        noonDurationCaption.textColor = scrollableCaptionColorWhite
        daylightExtensionCaption.textColor = scrollableCaptionColorWhite

        noonDurationField?.caption = noonDurationCaption
        daylightExtensionField?.caption = daylightExtensionCaption

        setupNoonDuration()
        setupDaylightExtension()

        brightnessOffsetField?.textFieldColor = scrollableTextFieldColorWhite
        brightnessOffsetField?.textFieldColorHover = scrollableTextFieldColorHoverWhite
        brightnessOffsetField?.textFieldColorLight = scrollableTextFieldColorLightWhite

        contrastOffsetField?.textFieldColor = scrollableTextFieldColorWhite
        contrastOffsetField?.textFieldColorHover = scrollableTextFieldColorHoverWhite
        contrastOffsetField?.textFieldColorLight = scrollableTextFieldColorLightWhite

        brightnessOffsetCaption.textColor = scrollableCaptionColorWhite
        contrastOffsetCaption.textColor = scrollableCaptionColorWhite

        brightnessOffsetField?.caption = noonDurationCaption
        contrastOffsetField?.caption = daylightExtensionCaption

        setupBrightnessOffset()
        setupContrastOffset()

        listenForBrightnessOffsetChange()
        listenForContrastOffsetChange()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
}
