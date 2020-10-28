//
//  StatusItemButton.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25/11/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa
import Defaults

class StatusItemButtonController: NSView {
    var statusButton: NSStatusBarButton?
    var menuPopoverOpener: DispatchWorkItem?

    convenience init(button: NSStatusBarButton) {
        self.init(frame: button.frame)
        statusButton = button
    }

    override func mouseEntered(with event: NSEvent) {
        if !Defaults[.showQuickActions] || brightnessAdapter.displays.count == 0 {
            return
        }

        menuPopoverOpener = menuPopoverOpener ?? DispatchWorkItem { [unowned self] in
            if let area = event.trackingArea, let button = self.statusButton {
                menuPopover.show(relativeTo: area.rect, of: button, preferredEdge: .maxY)
                menuPopover.becomeFirstResponder()
            }
            self.menuPopoverOpener = nil
        }
        let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(500_000_000))

        DispatchQueue.main.asyncAfter(deadline: deadline, execute: menuPopoverOpener!)
    }

    override func mouseExited(with _: NSEvent) {
        if let opener = menuPopoverOpener {
            opener.cancel()
            menuPopoverOpener = nil
        }
        closeMenuPopover(after: 2500)
    }

    override func mouseDown(with event: NSEvent) {
        menuPopover.close()
        closeMenuPopover(after: 1500)
        if let button = statusButton {
            button.mouseDown(with: event)
        }
    }
}
