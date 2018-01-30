//
//  SettingsViewController.swift
//  Lunar
//
//  Created by Alin on 28/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

class SettingsViewController: NSSplitViewController {

    override func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        return NSRect()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.delegate = self
        splitView.wantsLayer = true
        splitView.layer!.backgroundColor = logoColor.cgColor
    }
    
}
