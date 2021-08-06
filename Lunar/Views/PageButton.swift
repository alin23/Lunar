//
//  HelpButton.swift
//  Lunar
//
//  Created by Alin on 14/06/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa

class PageButton: NSButton {
    // MARK: Lifecycle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Internal

    var trackingArea: NSTrackingArea!
    var buttonShadow: NSShadow!
    weak var notice: NSTextField?

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?

    var standardAlpha = 0.5
    var visibleAlpha = 0.8

    @AtomicLock var highlighterTask: CFRunLoopTimer?

    func disable() {
        stopHighlighting()
        transition(0.1)

        isHidden = true
        isEnabled = false
        alphaValue = 0.0
    }

    func enable(color _: NSColor? = nil) {
        transition(0.1)

        isHidden = false
        isEnabled = true
        if alphaValue == 0.0 {
            alphaValue = standardAlpha
        }
    }

    func setup() {
        let buttonSize = frame
        wantsLayer = true

        setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.width))
        radius = (frame.width / 2).ns
        layer?.backgroundColor = .clear
        alphaValue = 0.2

        buttonShadow = shadow
        shadow = nil

        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    func highlight() {
        guard !isHidden else { return }

        let windowVisible = mainThread { window?.isVisible ?? false }

        guard highlighterTask == nil || !realtimeQueue.isValid(timer: highlighterTask!), windowVisible
        else {
            return
        }

        highlighterTask = realtimeQueue.async(every: 5.seconds) { [weak self] (_: CFRunLoopTimer?) in
            guard let s = self else {
                if let timer = self?.highlighterTask { realtimeQueue.cancel(timer: timer) }
                return
            }

            let windowVisible: Bool = mainThread { s.window?.isVisible ?? false }
            guard windowVisible, let notice = s.notice else {
                if let timer = self?.highlighterTask { realtimeQueue.cancel(timer: timer) }
                return
            }

            mainThread {
                if notice.alphaValue <= 0.02 {
                    notice.transition(1)
                    notice.alphaValue = 0.9
                    notice.needsDisplay = true

                    s.transition(1)
                    s.alphaValue = s.visibleAlpha
                    s.needsDisplay = true
                } else {
                    notice.transition(3)
                    notice.alphaValue = 0.01
                    notice.needsDisplay = true

                    s.transition(3)
                    s.alphaValue = s.standardAlpha
                    s.needsDisplay = true
                }
            }
        }
    }

    func stopHighlighting() {
        if let timer = highlighterTask {
            realtimeQueue.cancel(timer: timer)
        }
        highlighterTask = nil

        mainThread {
            if let notice = notice {
                notice.transition(0.3)
                notice.alphaValue = 0.0
                notice.needsDisplay = true
            }

            transition(0.3)
            alphaValue = 0.0
            needsDisplay = true
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with _: NSEvent) {
        if !isEnabled { return }

        transition(0.1)
        alphaValue = 0.8
        shadow = buttonShadow

        onMouseEnter?()
    }

    override func mouseExited(with _: NSEvent) {
        if !isEnabled { return }

        transition(0.2)
        alphaValue = standardAlpha
        shadow = nil

        onMouseExit?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
