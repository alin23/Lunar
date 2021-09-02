//
//  Popovers.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Foundation

var POPOVERS: [String: NSPopover?] = [
    "help": nil,
    "hotkey": nil,
    "menu": {
        mainThread {
            let p = NSPopover()
            p.appearance = NSAppearance(named: .vibrantDark)
            return p
        }
    }(),
    "settings": nil,
]
var menuPopoverCloser = DispatchWorkItem(name: "menuPopoverCloser") {
    POPOVERS["menu"]!!.close()
}

func closeMenuPopover(after ms: Int) {
    log.debug("Closing QuickActions in \(ms)ms")
    menuPopoverCloser.cancel()
    menuPopoverCloser = DispatchWorkItem(name: "menuPopoverCloser") {
        POPOVERS["menu"]!!.close()
    }
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    DispatchQueue.main.asyncAfter(deadline: deadline, execute: menuPopoverCloser.workItem)
}
