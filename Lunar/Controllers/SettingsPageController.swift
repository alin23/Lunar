//
//  SettingsPageController.swift
//  Lunar
//
//  Created by Alin on 21/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa
import Combine
import Defaults

class SettingsPageController: NSViewController {
    @IBOutlet var settingsContainerView: NSView!
    @IBOutlet var advancedSettingsContainerView: NSView!
    @IBOutlet var advancedSettingsButton: ToggleButton!
    @objc dynamic var advancedSettingsShown = false

    var adaptiveModeObserver: Cancellable?

    @IBAction func toggleAdvancedSettings(_ sender: ToggleButton) {
        advancedSettingsShown = sender.state == .on
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.bg = settingsBgColor
        advancedSettingsButton.page = .settings
        advancedSettingsButton.isHidden = false
    }
}
