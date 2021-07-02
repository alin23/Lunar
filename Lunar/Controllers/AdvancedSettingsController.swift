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

    @IBOutlet var whatIsTheYellowDot: ToggleButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        resetButton.page = .settingsReset
        whatIsTheYellowDot.page = .settings
        // Do view setup here.
    }

    @IBAction func resetSettings(_: Any) {
        DataStore.reset()
    }

    @IBAction func whatIsTheYellowDotURL(_: Any) {
        NSWorkspace.shared.open(try! "https://lunar.fyi/faq#yellow-dot".asURL())
    }
}
