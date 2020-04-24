//
//  DisplayName.swift
//  Lunar
//
//  Created by Alin Panaitiu on 23/04/2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa

class DisplayName: NSTextField {
    var centerAlign: NSParagraphStyle?
    var trackingArea: NSTrackingArea?

    weak var display: Display?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    func setup() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        centerAlign = paragraphStyle

        usesSingleLineMode = false
        allowsEditingTextAttributes = true
        wantsLayer = true
        layer?.cornerRadius = 8

        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
        setNeedsDisplay()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func mouseEntered(with _: NSEvent) {
        if !isEnabled || !isEditable {
            return
        }
        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        layer?.backgroundColor = lunarYellow.withAlphaComponent(0.3).cgColor
        disableLeftRightHotkeys()
    }

    override func mouseExited(with _: NSEvent) {
        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        layer?.backgroundColor = NSColor.clear.cgColor
        appDelegate().setupHotkeys()
    }

    override func mouseDown(with _: NSEvent) {
        if isEditable {
            becomeFirstResponder()
        }
    }

    override func textDidBeginEditing(_: Notification) {
        log.info("Editing display name", context: ["display": display])
        disableLeftRightHotkeys()
    }

    override func textShouldEndEditing(_ textObject: NSText) -> Bool {
        log.info("Should end editing display name", context: ["display": display])
        return !textObject.string.isEmpty
    }

    override func textDidEndEditing(_: Notification) {
        if let display = self.display {
            log.info("Changing display name from \(display.name) to \(stringValue)")
            display.name = stringValue
        }
        appDelegate().setupHotkeys()
        if let editor = currentEditor() {
            editor.selectedRange = NSMakeRange(0, 0)
            endEditing(editor)
        }
    }
}
