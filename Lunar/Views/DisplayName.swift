//
//  DisplayName.swift
//  Lunar
//
//  Created by Alin Panaitiu on 23/04/2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa

class DisplayName: NSTextField, NSTextFieldDelegate {
    var centerAlign: NSParagraphStyle?
    var trackingArea: NSTrackingArea?

    weak var display: Display? {
        didSet {
            stringValue = display?.name ?? "No display"
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    func setup() {
        delegate = self
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        centerAlign = paragraphStyle

        usesSingleLineMode = false
        allowsEditingTextAttributes = false
        wantsLayer = true
        radius = 8.ns

        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
        needsDisplay = true
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
        bg = lunarYellow.withAlphaComponent(0.3)
    }

    override func mouseExited(with _: NSEvent) {
        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        bg = NSColor.clear
    }

    override func mouseDown(with _: NSEvent) {
        if isEditable {
            refusesFirstResponder = false
            becomeFirstResponder()
        }
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(insertNewline(_:)):
            window?.makeFirstResponder(nil)
            return true
        default:
            return false
        }
    }

    override func cancelOperation(_: Any?) {
        abortEditing()
        refusesFirstResponder = true
    }

    override func textDidBeginEditing(_: Notification) {
        log.info("Editing display name", context: ["display": display])
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
        if let editor = currentEditor() {
            editor.selectedRange = NSMakeRange(0, 0)
            endEditing(editor)
        }
        refusesFirstResponder = true
    }
}
