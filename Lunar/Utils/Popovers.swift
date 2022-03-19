//
//  Popovers.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Foundation

var menuPopover: NSPopover?
var INPUT_HOTKEY_POPOVERS: [String: NSPopover?] = [:]
var POPOVERS: [String: NSPopover?] = [
    "help": nil,
    "settings": nil,
    "colors": nil,
    "ddc": nil,
    "reset": nil,
]
