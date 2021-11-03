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

class SettingsPopoverController: NSViewController {
    var displayObservers = [String: AnyCancellable]()

    @objc dynamic var adaptiveBrightnessNotice: String = ""
    weak var displayViewController: DisplayViewController?

    @objc dynamic weak var display: Display? {
        didSet {
            guard let display = display else { return }
            display.refreshPanel()
            setAdaptiveNotice()
        }
    }

    func setAdaptiveNotice(mode: AdaptiveModeKey? = nil) {
        guard let display = display else { return }

        guard !display.isBuiltin else {
            adaptiveBrightnessNotice = "When this is enabled, the system setting for\n\"Automatically adjust brightness\" will be disabled"
            return
        }
        switch mode ?? displayController.adaptiveModeKey {
        case .sync:
            adaptiveBrightnessNotice = "When this is disabled, this monitor will not\nsync its brightness with the other monitors"
        case .sensor:
            adaptiveBrightnessNotice = "When this is disabled, this monitor will not\nreact to the changes in ambient light"
        case .location:
            adaptiveBrightnessNotice = "When this is disabled, this monitor will not\nchange brightness based on sun position"
        case .clock:
            adaptiveBrightnessNotice = "When this is disabled, this monitor will not\nchange brightness based on the schedule"
        case .manual:
            adaptiveBrightnessNotice = ""
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        adaptiveBrightnessModePublisher.sink { [weak self] change in
            self?.setAdaptiveNotice(mode: change.newValue)
        }.store(in: &displayObservers, for: "adaptiveBrightnessMode")
    }
}

// MARK: - SettingsButton

class SettingsButton: PopoverButton<SettingsPopoverController> {
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

    override var popoverKey: String {
        "settings"
    }

    override func mouseDown(with event: NSEvent) {
        popoverController?.display = display
        popoverController?.displayViewController = displayViewController
        super.mouseDown(with: event)
    }
}
