//
//  PaddedTextField.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.03.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa

class PaddedTextField: NSTextField {
    override func draw(_ dirtyRect: NSRect) {
        appearance = appearance ?? NSAppearance(named: .aqua)
        super.draw(dirtyRect)
        wantsLayer = true
        if effectiveAppearance.name == NSAppearance.Name.darkAqua {
            radius = 12.0.ns
        } else {
            radius = 8.0.ns
        }
    }
}

class PaddedSecureTextField: NSSecureTextField {
    override class var cellClass: AnyClass? {
        get {
            PaddedSecureTextFieldCell.self
        }
        set {}
    }

    override func draw(_ dirtyRect: NSRect) {
        appearance = appearance ?? NSAppearance(named: .aqua)
        super.draw(dirtyRect)
        wantsLayer = true
        if effectiveAppearance.name == NSAppearance.Name.darkAqua {
            radius = 12.0.ns
        } else {
            radius = 8.0.ns
        }
    }
}

class PaddedTextFieldCell: PlainTextFieldCell {
    @IBInspectable var padding = CGSize(width: 8.0, height: 4.0)

    override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)
        size.height += (padding.height * 2)
        return size
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        rect.insetBy(dx: padding.width, dy: padding.height)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        let insetRect = rect.insetBy(dx: padding.width, dy: padding.height)
        super.edit(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let insetRect = rect.insetBy(dx: padding.width, dy: padding.height)
        super.select(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let insetRect = cellFrame.insetBy(dx: padding.width, dy: padding.height)
        super.drawInterior(withFrame: insetRect, in: controlView)
    }
}

class PaddedSecureTextFieldCell: NSSecureTextFieldCell {
    @IBInspectable var padding = CGSize(width: 8.0, height: 4.0)

    override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)
        size.height += (padding.height * 2)
        return size
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        rect.insetBy(dx: padding.width, dy: padding.height)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        let insetRect = rect.insetBy(dx: padding.width, dy: padding.height)
        super.edit(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let insetRect = rect.insetBy(dx: padding.width, dy: padding.height)
        super.select(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let insetRect = cellFrame.insetBy(dx: padding.width, dy: padding.height)
        super.drawInterior(withFrame: insetRect, in: controlView)
    }
}
