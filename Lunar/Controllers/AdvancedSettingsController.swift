//
//  AdvancedSettingsController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 07.02.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Defaults

class AdvancedSettingsController: NSViewController {
    @IBOutlet var resetButton: ResetButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        resetButton.page = .settingsReset
        // Do view setup here.
    }

    @IBAction func resetSettings(_: Any) {
        DataStore.reset()
    }
}
