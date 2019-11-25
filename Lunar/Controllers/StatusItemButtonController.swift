//
//  StatusItemButton.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25/11/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa

class StatusItemButtonController: NSView {
    var statusButton: NSStatusBarButton?

    convenience init(button: NSStatusBarButton) {
        self.init(frame: button.frame)
        statusButton = button
    }

    override func mouseEntered(with event: NSEvent) {
        if let area = event.trackingArea, let button = statusButton {
            menuPopover.show(relativeTo: area.rect, of: button, preferredEdge: .maxY)
            menuPopover.becomeFirstResponder()
        }
    }

    override func mouseExited(with _: NSEvent) {
        let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(2_000_000_000))

        DispatchQueue.main.asyncAfter(deadline: deadline, execute: menuPopoverCloser)
    }

    override func mouseDown(with event: NSEvent) {
        menuPopover.close()
        if let button = statusButton {
            button.mouseDown(with: event)
        }
    }
}
