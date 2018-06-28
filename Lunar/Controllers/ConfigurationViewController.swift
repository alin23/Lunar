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

    @IBOutlet var daylightExtensionField: ScrollableTextField!
    @IBOutlet var daylightExtensionCaption: ScrollableTextFieldCaption!

    func setup() {
        noonDurationField?.integerValue = datastore.defaults.noonDurationMinutes
        daylightExtensionField?.integerValue = datastore.defaults.daylightExtensionMinutes

        noonDurationField?.textFieldColor = scrollableTextFieldColorWhite
        noonDurationField?.textFieldColorHover = scrollableTextFieldColorHoverWhite
        noonDurationField?.textFieldColorLight = scrollableTextFieldColorLightWhite

        daylightExtensionField?.textFieldColor = scrollableTextFieldColorWhite
        daylightExtensionField?.textFieldColorHover = scrollableTextFieldColorHoverWhite
        daylightExtensionField?.textFieldColorLight = scrollableTextFieldColorLightWhite

        noonDurationCaption.textColor = scrollableCaptionColorWhite
        daylightExtensionCaption.textColor = scrollableCaptionColorWhite

        noonDurationField?.onValueChanged = { (value: Int) in
            datastore.defaults.set(value, forKey: "noonDurationMinutes")
        }
        daylightExtensionField?.onValueChanged = { (value: Int) in
            datastore.defaults.set(value, forKey: "daylightExtensionMinutes")
        }

        noonDurationField?.caption = noonDurationCaption
        daylightExtensionField?.caption = daylightExtensionCaption

        if let settingsController = parent?.parent as? SettingsPageController {
            noonDurationField?.onValueChangedInstant = { value in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, noonDuration: value)
            }
            daylightExtensionField?.onValueChangedInstant = { value in
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, daylightExtension: value)
            }
            noonDurationField?.onMouseEnter = {
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, noonDuration: self.noonDurationField.integerValue, withAnimation: true)
            }
            daylightExtensionField?.onMouseEnter = {
                settingsController.updateDataset(display: brightnessAdapter.firstDisplay, daylightExtension: self.daylightExtensionField.integerValue, withAnimation: true)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
}
