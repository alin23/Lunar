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
        guard let layer, layer.name == "NSPopoverFrame", let window, identifier == MAIN_MENU_ID
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
    s.shadowOffset = .init(width: 0, height: -6)
    s.shadowBlurRadius = 8
    return s
}()

func fixPopoverWindow(_ window: NSWindow) {
    window.backgroundColor = .clear
    window.isOpaque = false
    window.styleMask = [.borderless]
    window.hasShadow = false
}

// MARK: - PopoverClearView

class PopoverClearView: NSView {
    override func makeBackingLayer() -> CALayer {
        NoClippingLayer()
    }
}

let POPOVER_BLUR_VIEW_ID = NSUserInterfaceItemIdentifier("POPOVER_BLUR_VIEW_ID")
let POPOVER_BACKING_VIEW_ID = NSUserInterfaceItemIdentifier("POPOVER_BACKING_VIEW_ID")
func fixPopoverView(_ view: NSView?, backgroundColor: NSColor? = nil) {
    if let view {
        view.layer = nil
        let backView = NSVisualEffectView(frame: NSRect(
            x: POPOVER_PADDING / 2,
            y: POPOVER_PADDING - 10,
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
        backView.identifier = POPOVER_BLUR_VIEW_ID

        let backViewBackground = PopoverClearView(frame: NSRect(
            x: POPOVER_PADDING / 2,
            y: POPOVER_PADDING - 10,
            width: view.frame.width - POPOVER_PADDING,
            height: view.frame.height - POPOVER_PADDING
        ))
        backViewBackground.identifier = POPOVER_BACKING_VIEW_ID
        backViewBackground.wantsLayer = true
        if let l = backViewBackground.layer {
            l.cornerCurve = .continuous
            l.backgroundColor = backgroundColor?.cgColor
            l.cornerRadius = POPOVER_CORNER_RADIUS
        }
        view.addSubview(backViewBackground, positioned: .below, relativeTo: view.subviews.first)
        view.addSubview(backView, positioned: .below, relativeTo: view.subviews.first)
    }
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

func removePopoverBackground(view: NSView) {
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

import SwiftUI

// MARK: - HostingView

class HostingView: NSHostingView<QuickActionsView> {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removePopoverBackground(view: self)
    }
}

extension NSVisualEffectView.Material {
    static let osd = NSVisualEffectView.Material(rawValue: 26) ?? .hudWindow
}

// MARK: - VisualEffectBlur

public struct VisualEffectBlur: View {
    public init(
        material: NSVisualEffectView.Material = .headerView,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        state: NSVisualEffectView.State = .followsWindowActiveState,
        maskImage: NSImage? = nil
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.maskImage = maskImage
    }

    public var body: some View {
        Representable(
            material: material,
            blendingMode: blendingMode,
            state: state,
            maskImage: maskImage
        ).accessibility(hidden: true)
    }

    private var material: NSVisualEffectView.Material
    private var blendingMode: NSVisualEffectView.BlendingMode
    private var state: NSVisualEffectView.State
    private var maskImage: NSImage?
}

extension VisualEffectBlur {
    struct Representable: NSViewRepresentable {
        var material: NSVisualEffectView.Material
        var blendingMode: NSVisualEffectView.BlendingMode
        var state: NSVisualEffectView.State
        var maskImage: NSImage?

        func makeNSView(context: Context) -> NSVisualEffectView {
            context.coordinator.visualEffectView
        }

        func updateNSView(_: NSVisualEffectView, context: Context) {
            context.coordinator.update(material: material)
            context.coordinator.update(blendingMode: blendingMode)
            context.coordinator.update(state: state)
            context.coordinator.update(maskImage: maskImage)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }
    }

    class Coordinator {
        init() {
            visualEffectView.blendingMode = .withinWindow
        }

        let visualEffectView = NSVisualEffectView()

        func update(material: NSVisualEffectView.Material) {
            visualEffectView.material = material
        }

        func update(blendingMode: NSVisualEffectView.BlendingMode) {
            visualEffectView.blendingMode = blendingMode
        }

        func update(state: NSVisualEffectView.State) {
            visualEffectView.state = state
        }

        func update(maskImage: NSImage?) {
            visualEffectView.maskImage = maskImage
        }
    }
}
