//
//  StatusItemButton.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25/11/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Atomics
import Cocoa
import Defaults

class StatusItemButtonController: NSView {
    var statusButton: NSStatusBarButton?
    var menuPopoverOpener: DispatchWorkItem?
    @Atomic var clicked = false

    convenience init(button: NSStatusBarButton) {
        self.init(frame: button.frame)
        statusButton = button
    }

    override func mouseEntered(with event: NSEvent) {
        if !Defaults[.showQuickActions] || displayController.displays.count == 0 || clicked {
            return
        }

        menuPopoverOpener = menuPopoverOpener ?? DispatchWorkItem(name: "menuPopoverOpener") { [unowned self] in
            if let area = event.trackingArea, let button = self.statusButton, !self.clicked {
                POPOVERS["menu"]!!.show(relativeTo: area.rect, of: button, preferredEdge: .maxY)
                POPOVERS["menu"]!!.becomeFirstResponder()
            }
            self.menuPopoverOpener = nil
        }
        let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(500_000_000))

        DispatchQueue.main.asyncAfter(deadline: deadline, execute: menuPopoverOpener!.workItem)
    }

    override func mouseExited(with _: NSEvent) {
        if let opener = menuPopoverOpener {
            opener.cancel()
            menuPopoverOpener = nil
        }
        closeMenuPopover(after: 4000)
    }

    override func mouseDown(with event: NSEvent) {
        clicked = true
        asyncAfter(ms: 3000) { [weak self] in
            self?.clicked = false
        }

        POPOVERS["menu"]!!.close()
        closeMenuPopover(after: 1500)

        if let button = statusButton {
            button.mouseDown(with: event)
        }
    }
}
