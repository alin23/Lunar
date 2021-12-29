//
//  Swizzle.swift
//  Lunar
//
//  Created by Alin Panaitiu on 28.12.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Foundation

let MAIN_MENU_ID = NSUserInterfaceItemIdentifier("MainMenuWindow")
let POPOVER_CORNER_RADIUS: CGFloat = 18

// MARK: - PopoverBackgroundView

class PopoverBackgroundView: NSView {
    override func draw(_ bounds: NSRect) {
        NSColor.clear.set()
        bounds.fill()
    }
}

extension NSVisualEffectView {
    private typealias UpdateLayer = @convention(c) (AnyObject) -> Void

    @objc dynamic
    func replacement() {
        super.updateLayer()
        guard let layer = layer, layer.name == "NSPopoverFrame", let window = window, window.identifier == MAIN_MENU_ID
        else {
            unsafeBitCast(
                updateLayerOriginalIMP, to: Self.UpdateLayer.self
            )(self)
            return
        }
        CATransaction.begin()
        CATransaction.disableActions()

        layer.isOpaque = false
        fixPopoverWindow(window)

        CATransaction.commit()
    }
}

let POPOVER_SHADOW: NSShadow = {
    let s = NSShadow()

    s.shadowColor = .black.withAlphaComponent(0.2)
    s.shadowOffset = .init(width: 0, height: 1)
    s.shadowBlurRadius = 2
    return s
}()

func fixPopoverWindow(_ window: NSWindow) {
    window.backgroundColor = .clear
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isOpaque = false
    window.styleMask = [.fullSizeContentView, .titled]
    window.hasShadow = false
    window.identifier = MAIN_MENU_ID

    if let view = window.contentView {
        view.radius = POPOVER_CORNER_RADIUS.ns
        view.bg = darkMode ? darkMauve : white
        view.layer?.borderColor = NSColor.shadowColor.withAlphaComponent(0.1).cgColor
        view.layer?.borderWidth = 2
    }
}

var updateLayerOriginal: Method?
var updateLayerOriginalIMP: IMP?
var popoverSwizzled = false

func swizzlePopoverBackground() {
    guard !popoverSwizzled else {
        return
    }
    popoverSwizzled = true
    let origMethod = #selector(NSVisualEffectView.updateLayer)
    let replacementMethod = #selector(NSVisualEffectView.replacement)

    updateLayerOriginal = class_getInstanceMethod(NSVisualEffectView.self, origMethod)
    updateLayerOriginalIMP = method_getImplementation(updateLayerOriginal!)

    let swizzleMethod: Method? = class_getInstanceMethod(NSVisualEffectView.self, replacementMethod)
    let swizzleImpl = method_getImplementation(swizzleMethod!)
    method_setImplementation(updateLayerOriginal!, swizzleImpl)
}

func removePopoverBackground(view: NSView, backgroundView: inout PopoverBackgroundView?) {
    if let window = view.window, let frameView = window.contentView?.superview as? NSVisualEffectView {
        fixPopoverWindow(window)

        swizzlePopoverBackground()
        frameView.bg = .clear
    }
}

// MARK: - NoClippingLayer

class NoClippingLayer: CALayer {
    override var masksToBounds: Bool {
        set {}
        get {
            false
        }
    }
}
