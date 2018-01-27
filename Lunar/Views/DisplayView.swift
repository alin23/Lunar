//
//  DisplayView.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

class DisplayView: NSImageView {
    var deleteButtonTrackingArea: NSTrackingArea?
    var deleteButton: DeleteButton! {
        didSet {
            if let area = deleteButtonTrackingArea {
                removeTrackingArea(area)
            }
            deleteButtonTrackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: deleteButton, userInfo: nil)
            addTrackingArea(deleteButtonTrackingArea!)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
}
