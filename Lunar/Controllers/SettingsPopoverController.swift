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

// MARK: - SettingsPopoverController

final class SettingsPopoverController: NSViewController {
    var displayObservers = [String: AnyCancellable]()

    @objc dynamic var adaptiveBrightnessNotice = ""
    weak var displayViewController: DisplayViewController?

    @IBOutlet var resolutionsDropdown: ModePopupButton?

    @IBOutlet var dimmingModeSelector: NSSegmentedControl? {
        didSet { setDimmingModeSelectorTooltips() }
    }

    @IBOutlet var adaptiveSelector: NSSegmentedControl? {
        didSet { setAdaptiveSelectorTooltips() }
    }

    @objc dynamic weak var display: Display? {
        didSet {
            guard let display else { return }
            display.refreshPanel()
            setAdaptiveNotice()
            setAdaptiveSelectorTooltips()
            setDimmingModeSelectorTooltips()
        }
    }

    override func viewDidAppear() {
        resolutionsDropdown?.setItemStyles()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        adaptiveBrightnessModePublisher.sink { [weak self] change in
            self?.setAdaptiveNotice(mode: change.newValue)
            self?.setAdaptiveSelectorTooltips(mode: change.newValue)
        }.store(in: &displayObservers, for: "adaptiveBrightnessMode")
    }

    func setDimmingModeSelectorTooltips() {
        guard let dimmingModeSelector, let display else {
            return
        }
        dimmingModeSelector.setEnabled(display.supportsGammaByDefault, forSegment: DimmingMode.gamma.rawValue)
        dimmingModeSelector.setToolTip(
            "Dim brightness by altering the RGB Gamma table to make colors appear darker.\(display.supportsGammaByDefault ? "" : "\n\nNot supported on this display.")",
            forSegment: DimmingMode.gamma.rawValue
        )
    }

    func setAdaptiveSelectorTooltips(mode: AdaptiveModeKey? = nil) {
        guard let adaptiveSelector, let display else { return }
        if !display.hasAmbientLightAdaptiveBrightness {
            adaptiveSelector.setEnabled(false, forSegment: AdaptiveController.system.rawValue)
            adaptiveSelector.setToolTip(
                "This display does not support system ambient light adaptation",
                forSegment: AdaptiveController.system.rawValue
            )
            adaptiveSelector.setToolTip(lunarAdaptiveTooltip(mode: mode), forSegment: AdaptiveController.lunar.rawValue)
        } else {
            adaptiveSelector.setEnabled(true, forSegment: AdaptiveController.system.rawValue)
            adaptiveSelector.setToolTip(
                "System adaptive brightness will be enabled and Lunar stop adjusting the brightness of this display automatically",
                forSegment: AdaptiveController.system.rawValue
            )
            adaptiveSelector.setToolTip(
                "\(lunarAdaptiveTooltip(mode: mode)).\n\nSystem adaptive brightness will be disabled.",
                forSegment: AdaptiveController.lunar.rawValue
            )
        }
    }

    func lunarAdaptiveTooltip(mode: AdaptiveModeKey? = nil) -> String {
        switch mode ?? DC.adaptiveModeKey {
        case .sync:
            "Allow Lunar to automatically sync the brightness of this display with the other monitors"
        case .sensor:
            "Allow Lunar to automatically adapt brightness using readings from the ambient light sensor"
        case .location:
            "Allow Lunar to automatically change brightness based on sun elevation"
        case .clock:
            "Allow Lunar to automatically change brightness based on the configured schedule"
        case .manual, .auto:
            "Allow Lunar to automatically adjust the brightness of this display when a non-manual mode is active"
        }
    }

    func setAdaptiveNotice(mode: AdaptiveModeKey? = nil) {
        guard let display else { return }

        guard !display.hasAmbientLightAdaptiveBrightness else {
            adaptiveBrightnessNotice =
                "When \"System\" is deselected, the system setting\n\"Automatically adjust brightness\" will be disabled"
            return
        }
        switch mode ?? DC.adaptiveModeKey {
        case .sync:
            adaptiveBrightnessNotice = "When \"None\" is selected, this monitor will not\nsync its brightness with the other monitors"
        case .sensor:
            adaptiveBrightnessNotice = "When \"None\" is selected, this monitor will not\nreact to the changes in ambient light"
        case .location:
            adaptiveBrightnessNotice = "When \"None\" is selected, this monitor will not\nchange brightness based on sun position"
        case .clock:
            adaptiveBrightnessNotice = "When \"None\" is selected, this monitor will not\nchange brightness based on the schedule"
        case .manual, .auto:
            adaptiveBrightnessNotice = "When \"None\" is selected, this monitor will not\nadapt automatically in non-Manual modes"
        }
    }

}

// MARK: - SettingsButton

final class SettingsButton: PopoverButton<SettingsPopoverController> {
    override var popoverKey: String {
        "settings"
    }

    weak var displayViewController: DisplayViewController? {
        didSet {
            popoverController?.displayViewController = displayViewController
        }
    }

    weak var display: Display? {
        didSet {
            popoverController?.display = display
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let popoverController {
            popoverController.display = display
            popoverController.displayViewController = displayViewController
        }
        super.mouseDown(with: event)
    }
}
