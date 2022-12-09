//
//  PageNavigationControl.swift
//  PageNavigationControl
//
//  Created by Alin Panaitiu on 31.08.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa

class PageNavigationControl: NSSegmentedControl {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    var trackingArea: NSTrackingArea!
    var buttonShadow: NSShadow!
    weak var notice: NSTextField?

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?

    var standardAlpha = 0.5
    var visibleAlpha = 0.8

    func setup() {
        wantsLayer = true

        alphaValue = standardAlpha

        trackingArea = NSTrackingArea(
            rect: visibleRect,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with _: NSEvent) {
        if !isEnabled { return }

        transition(0.2)
        alphaValue = visibleAlpha

        onMouseEnter?()
    }

    override func mouseExited(with _: NSEvent) {
        if !isEnabled { return }

        transition(0.4)
        alphaValue = standardAlpha

        onMouseExit?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
}
