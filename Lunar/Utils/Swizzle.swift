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
let POPOVER_PADDING: CGFloat = 50

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
        guard let layer = layer, layer.name == "NSPopoverFrame", let window = window, identifier == MAIN_MENU_ID
        else {
            unsafeBitCast(
                updateLayerOriginalIMP, to: Self.UpdateLayer.self
            )(self)
            return
        }
        CATransaction.begin()
        CATransaction.disableActions()

        layer.isOpaque = false
        if let sublayer = layer.sublayers?.first, sublayer.name == "_NSPopoverFrameAXBackgroundView" {
            sublayer.opacity = 0
        }
        fixPopoverWindow(window)

        CATransaction.commit()
    }
}

let POPOVER_SHADOW: NSShadow = {
    let s = NSShadow()

    s.shadowColor = NSColor.shadowColor.withAlphaComponent(0.2)
    s.shadowOffset = .init(width: 0, height: -4)
    s.shadowBlurRadius = 10
    return s
}()

func fixPopoverWindow(_ window: NSWindow) {
    window.backgroundColor = .clear
    window.isOpaque = false
    window.styleMask = [.borderless]
    window.hasShadow = false
//    window.identifier = MAIN_MENU_ID
}

extension NSImage {
    static func mask(withCornerRadius radius: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: radius * 2, height: radius * 2), flipped: false) {
            NSBezierPath(roundedRect: $0, xRadius: radius, yRadius: radius).fill()
            NSColor.black.set()
            return true
        }

        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch

        return image
    }
}

func fixPopoverView(_ view: NSView?) {
    if let view = view {
        view.layer = nil
        let backView = NSVisualEffectView(frame: NSRect(
            x: POPOVER_PADDING / 2,
            y: POPOVER_PADDING,
            width: view.frame.width - POPOVER_PADDING,
            height: view.frame.height - POPOVER_PADDING
        ))
        backView.material = .hudWindow
        backView.blendingMode = .behindWindow
        backView.state = .active
        backView.wantsLayer = true
        backView.layer?.cornerCurve = .continuous
        backView.maskImage = .mask(withCornerRadius: POPOVER_CORNER_RADIUS)
        backView.shadow = POPOVER_SHADOW

        let backViewBackground = QuickActionsView(frame: NSRect(
            x: POPOVER_PADDING / 2,
            y: POPOVER_PADDING,
            width: view.frame.width - POPOVER_PADDING,
            height: view.frame.height - POPOVER_PADDING
        ))
        backViewBackground.wantsLayer = true
        if let l = backViewBackground.layer {
            l.cornerCurve = .continuous
            l.backgroundColor = (darkMode ? darkMauve : white).withAlphaComponent(0.4).cgColor
            l.cornerRadius = POPOVER_CORNER_RADIUS
        }
        view.addSubview(backViewBackground, positioned: .below, relativeTo: view.subviews.first)
        view.addSubview(backView, positioned: .below, relativeTo: view.subviews.first)
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
        frameView.identifier = MAIN_MENU_ID
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
