//
//  ResetButton.swift
//  Lunar
//
//  Created by Alin Panaitiu on 07.02.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Foundation

class ResetButton: ToggleButton {
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        state = .off
        hoverState = .noHover

        super.mouseDown(with: event)

        isEnabled = false
        fade()
        mainAsyncAfter(ms: 3000) {
            self.state = .off
            self.hoverState = .noHover
            self.isEnabled = true
            self.fade()
        }
    }
}
