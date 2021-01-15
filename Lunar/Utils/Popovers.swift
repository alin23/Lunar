//
//  Popovers.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Foundation

enum PopoverKey {
    case help
    case hotkey
    case menu
}

var POPOVERS: [PopoverKey: NSPopover?] = [
    .help: nil,
    .hotkey: nil,
    .menu: NSPopover(),
]
var menuPopoverCloser = DispatchWorkItem {
    POPOVERS[.menu]!!.close()
}

func closeMenuPopover(after ms: Int) {
    menuPopoverCloser.cancel()
    menuPopoverCloser = DispatchWorkItem {
        POPOVERS[.menu]!!.close()
    }
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    DispatchQueue.main.asyncAfter(deadline: deadline, execute: menuPopoverCloser)
}
