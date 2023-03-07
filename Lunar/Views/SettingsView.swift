//
//  SettingsView.swift
//  Lunar
//
//  Created by Alin on 28/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

final class SettingsView: NSSplitView {
    override var dividerThickness: CGFloat {
        1.0
    }

    override func drawDivider(in rect: NSRect) {
        let rect = NSRect(x: frame.width / 2 - 1.0, y: 200.0, width: 2.0, height: 300)
        settingsDividerColor.set()
        rect.fill()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
