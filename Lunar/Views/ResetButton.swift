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
    var resettingText = "Resetting"

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        let text = attributedTitle.string
        attributedTitle = resettingText.withAttribute(.textColor(labelColor))
        state = .off
        hoverState = .noHover

        super.mouseDown(with: event)

        isEnabled = false
        fade()
        mainAsyncAfter(ms: 3000) { [weak self] in
            guard let self = self else { return }
            self.attributedTitle = text.withAttribute(.textColor(self.labelColor))
            self.state = .off
            self.hoverState = .noHover
            self.isEnabled = true
            self.fade()
        }
    }
}
