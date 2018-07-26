//
//  ConfigurationViewController.swift
//  Lunar
//
//  Created by Alin on 16/04/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

class ConfigurationViewController: NSViewController {
    @IBOutlet var firstField: ScrollableTextField!
    @IBOutlet var firstFieldCaption: ScrollableTextFieldCaption!

    @IBOutlet var secondField: ScrollableTextField!
    @IBOutlet var secondFieldCaption: ScrollableTextFieldCaption!
    @IBOutlet var firstFieldLabel: NSTextField!
    @IBOutlet var secondFieldLabel: NSTextField!
    var adaptiveModeObserver: NSKeyValueObservation?

    func setupFirstField(mode: AdaptiveMode) {
        switch mode {
        case .location:
            firstFieldLabel?.stringValue = "Noon duration"
            firstField?.integerValue = datastore.defaults.noonDurationMinutes
            firstField?.onValueChanged = { (value: Int) in
                datastore.defaults.set(value, forKey: "noonDurationMinutes")
            }
            firstField?.lowerLimit = 0
            firstField?.upperLimit = 240
            firstFieldCaption?.stringValue = "MINUTES"
            if let settingsController = parent?.parent as? SettingsPageController {
                firstField?.onValueChangedInstant = { value in
                    settingsController.updateDataset(display: brightnessAdapter.firstDisplay, noonDuration: value)
                }
                firstField?.onMouseEnter = {
                    settingsController.updateDataset(display: brightnessAdapter.firstDisplay, noonDuration: self.firstField.integerValue, withAnimation: true)
                }
            }
        default:
            firstFieldLabel?.stringValue = "Brightness offset"
            firstField?.integerValue = datastore.defaults.brightnessOffset
            firstField?.onValueChanged = { (value: Int) in
                datastore.defaults.set(value, forKey: "brightnessOffset")
            }
            firstField?.lowerLimit = -100
            firstField?.upperLimit = 90
            firstField?.onValueChangedInstant = nil
            firstField?.onMouseEnter = nil
            firstFieldCaption?.stringValue = "BRIGHTNESS"
        }
    }

    func setupSecondField(mode: AdaptiveMode) {
        switch mode {
        case .location:
            secondFieldLabel?.stringValue = "Daylight extension"
            secondField?.integerValue = datastore.defaults.daylightExtensionMinutes
            secondField?.onValueChanged = { (value: Int) in
                datastore.defaults.set(value, forKey: "daylightExtensionMinutes")
            }
            secondField?.lowerLimit = 0
            secondField?.upperLimit = 240
            secondFieldCaption?.stringValue = "MINUTES"
            if let settingsController = parent?.parent as? SettingsPageController {
                secondField?.onValueChangedInstant = { value in
                    settingsController.updateDataset(display: brightnessAdapter.firstDisplay, daylightExtension: value)
                }
                secondField?.onMouseEnter = {
                    settingsController.updateDataset(display: brightnessAdapter.firstDisplay, daylightExtension: self.secondField.integerValue, withAnimation: true)
                }
            }
        default:
            secondFieldLabel?.stringValue = "Contrast offset"
            secondField?.integerValue = datastore.defaults.contrastOffset
            secondField?.onValueChanged = { (value: Int) in
                datastore.defaults.set(value, forKey: "contrastOffset")
            }
            secondField?.lowerLimit = -100
            secondField?.upperLimit = 90
            secondField?.onValueChangedInstant = nil
            secondField?.onMouseEnter = nil
            secondFieldCaption?.stringValue = "CONTRAST"
        }
    }

    func setup() {
        firstField?.textFieldColor = scrollableTextFieldColorWhite
        firstField?.textFieldColorHover = scrollableTextFieldColorHoverWhite
        firstField?.textFieldColorLight = scrollableTextFieldColorLightWhite

        secondField?.textFieldColor = scrollableTextFieldColorWhite
        secondField?.textFieldColorHover = scrollableTextFieldColorHoverWhite
        secondField?.textFieldColorLight = scrollableTextFieldColorLightWhite

        firstFieldCaption.textColor = scrollableCaptionColorWhite
        secondFieldCaption.textColor = scrollableCaptionColorWhite

        firstField?.caption = firstFieldCaption
        secondField?.caption = secondFieldCaption

        setupFirstField(mode: brightnessAdapter.mode)
        setupSecondField(mode: brightnessAdapter.mode)
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = datastore.defaults.observe(\.adaptiveBrightnessMode, options: [.old, .new], changeHandler: { _, change in
            guard let mode = change.newValue, let oldMode = change.oldValue, mode != oldMode else {
                return
            }
            let adaptiveMode = AdaptiveMode(rawValue: mode) ?? .location
            self.setupFirstField(mode: adaptiveMode)
            self.setupSecondField(mode: adaptiveMode)
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        listenForAdaptiveModeChange()
    }
}
