//
//  ModernWindow.swift
//  Lunar
//
//  Created by Alin on 18/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Carbon.HIToolbox
import Cocoa
import WAYWindow

var navigationHotkeysEnabled = true
var scrollableAdjustHotkeysEnabled = true

extension NSView {
    func mask(withRect maskRect: CGRect, cornerRadius: CGFloat, inverse: Bool = false, rasterScale: CGFloat? = nil) {
        let maskLayer = CAShapeLayer()
        maskLayer.cornerCurve = .continuous
        maskLayer.allowsEdgeAntialiasing = true
        maskLayer.edgeAntialiasingMask = [.layerBottomEdge, .layerTopEdge, .layerLeftEdge, .layerRightEdge]
        if let rasterScale {
            maskLayer.shouldRasterize = true
            maskLayer.rasterizationScale = rasterScale
        }
        let path = CGMutablePath()
        if inverse {
            path.addPath(CGPath(rect: bounds, transform: nil))
        }
        path.addPath(CGPath(roundedRect: maskRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))

        maskLayer.path = path
        if inverse {
            maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        }

        wantsLayer = true
        layer?.mask = maskLayer
        layer?.cornerCurve = .continuous
        layer?.allowsEdgeAntialiasing = true
        layer?.edgeAntialiasingMask = [.layerBottomEdge, .layerTopEdge, .layerLeftEdge, .layerRightEdge]
        if let rasterScale, let layer {
            layer.shouldRasterize = true
            layer.rasterizationScale = rasterScale
        }
    }
}

// MARK: - CornerWindowController

final class CornerWindowController: NSWindowController {
    var corner: ScreenCorner?

    weak var display: Display? {
        didSet {
            mainAsync { [self] in
                guard let display, let screen = display.nsScreen ?? display.primaryMirrorScreen,
                      let w = window as? CornerWindow, let view = w.contentView
                else { return }

                view.bg = .black
                switch corner {
                case .bottomLeft:
                    w.setFrame(
                        NSRect(origin: NSPoint(x: screen.frame.minX, y: screen.frame.minY), size: NSSize(width: 50, height: 50)),
                        display: false
                    )
                    view.mask(
                        withRect: NSRect(x: 0, y: 0, width: 70, height: 70),
                        cornerRadius: CGFloat(display.cornerRadius.floatValue),
                        inverse: true, rasterScale: screen.backingScaleFactor
                    )
                case .bottomRight:
                    w.setFrame(
                        NSRect(origin: NSPoint(x: screen.frame.maxX - 50, y: screen.frame.minY), size: NSSize(width: 50, height: 50)),
                        display: false
                    )
                    view.mask(
                        withRect: NSRect(x: -20, y: 0, width: 70, height: 70),
                        cornerRadius: CGFloat(display.cornerRadius.floatValue),
                        inverse: true, rasterScale: screen.backingScaleFactor
                    )
                case .topLeft:
                    w.setFrame(
                        NSRect(origin: NSPoint(x: screen.frame.minX, y: screen.frame.maxY - 50), size: NSSize(width: 50, height: 50)),
                        display: false
                    )
                    view.mask(
                        withRect: NSRect(x: 0, y: -20, width: 70, height: 70),
                        cornerRadius: CGFloat(display.cornerRadius.floatValue),
                        inverse: true, rasterScale: screen.backingScaleFactor
                    )
                case .topRight:
                    w.setFrame(
                        NSRect(origin: NSPoint(x: screen.frame.maxX - 50, y: screen.frame.maxY - 50), size: NSSize(width: 50, height: 50)),
                        display: false
                    )
                    view.mask(
                        withRect: NSRect(x: -20, y: -20, width: 70, height: 70),
                        cornerRadius: CGFloat(display.cornerRadius.floatValue),
                        inverse: true, rasterScale: screen.backingScaleFactor
                    )
                default:
                    break
                }
            }
        }
    }

    override func windowDidLoad() {
        mainAsync { [self] in
            if let w = window as? CornerWindow {
                w.isOpaque = false
                w.backgroundColor = .clear
                w.contentView?.bg = .clear
                w.contentView?.radius = 0
            }
        }
    }
}

// MARK: - CornerWindow

final class CornerWindow: NSWindow {}

// MARK: - ModernWindow

final class ModernWindow: WAYWindow {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        log.verbose("Created window '\(title)'")
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            do { log.verbose("END DEINIT") }
        #endif
    }

    var pageController: PageController? {
        guard let contentView,
              !contentView.subviews.isEmpty, !contentView.subviews[0].subviews.isEmpty,
              let controller = contentView.subviews[0].subviews[0].nextResponder as? PageController else { return nil }
        return controller
    }

    override func mouseDown(with event: NSEvent) {
        for popover in POPOVERS.values {
            popover?.close()
            if let c = popover?.contentViewController as? HelpPopoverController {
                c.onClick = nil
            }
        }
        for display in DC.activeDisplayList {
            if let popover = display._hotkeyPopover, popover.isShown {
                popover.close()
            }
        }
        if let menuWindow, menuWindow.isVisible {
            menuWindow.forceClose()
        }

        endEditing(for: nil)

        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.isDisjoint(with: [.option, .command, .control, .shift]) else { return }
        guard event.keyCode != kVK_Escape.u16 else {
            undoManager?.undo()
            endEditing(for: nil)
            return
        }

        guard navigationHotkeysEnabled, title == "Settings" else {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case kVK_ANSI_H.u16:
            appDelegate!.currentPage = 0
            appDelegate!.goToPage(ignoreUIElement: true)
        case kVK_ANSI_C.u16:
            appDelegate!.currentPage = 1
            appDelegate!.goToPage(ignoreUIElement: true)
        case kVK_ANSI_B.u16:
            if let index = pageController?.arrangedObjects.firstIndex(where: { obj in
                guard let d = obj as? Display else {
                    return false
                }
                return d.isBuiltin && d.active
            }) {
                appDelegate!.currentPage = index
                appDelegate!.goToPage(ignoreUIElement: true)
            }
        case kVK_ANSI_0.u16:
            appDelegate!.currentPage = (pageController?.arrangedObjects.count ?? 3) - 1
            appDelegate!.goToPage(ignoreUIElement: true)
        case kVK_ANSI_1.u16, kVK_ANSI_D.u16:
            appDelegate!.currentPage = 2
            appDelegate!.goToPage(ignoreUIElement: true)
        case kVK_ANSI_2.u16:
            appDelegate!.currentPage = min(3, (pageController?.arrangedObjects.count ?? 3) - 1)
            appDelegate!.goToPage(ignoreUIElement: true)
        case kVK_ANSI_3.u16:
            appDelegate!.currentPage = min(4, (pageController?.arrangedObjects.count ?? 3) - 1)
            appDelegate!.goToPage(ignoreUIElement: true)
        case kVK_ANSI_4.u16:
            appDelegate!.currentPage = min(5, (pageController?.arrangedObjects.count ?? 3) - 1)
            appDelegate!.goToPage(ignoreUIElement: true)
        case kVK_ANSI_5.u16:
            appDelegate!.currentPage = min(6, (pageController?.arrangedObjects.count ?? 3) - 1)
            appDelegate!.goToPage(ignoreUIElement: true)
        case kVK_ANSI_6.u16:
            appDelegate!.currentPage = min(7, (pageController?.arrangedObjects.count ?? 3) - 1)
            appDelegate!.goToPage(ignoreUIElement: true)
        case kVK_ANSI_7.u16:
            appDelegate!.currentPage = min(8, (pageController?.arrangedObjects.count ?? 3) - 1)
            appDelegate!.goToPage(ignoreUIElement: true)
        case kVK_ANSI_8.u16:
            appDelegate!.currentPage = min(9, (pageController?.arrangedObjects.count ?? 3) - 1)
            appDelegate!.goToPage(ignoreUIElement: true)
        case kVK_ANSI_9.u16:
            appDelegate!.currentPage = min(10, (pageController?.arrangedObjects.count ?? 3) - 1)
            appDelegate!.goToPage(ignoreUIElement: true)
        case kVK_LeftArrow.u16:
            pageController?.navigateBack(nil)
        case kVK_RightArrow.u16:
            pageController?.navigateForward(nil)
        default:
            super.keyDown(with: event)
        }
    }

    func setup() {
        titleBarHeight = 50
        verticallyCenterTitle = true
        centerTrafficLightButtons = true
        hidesTitle = true
        trafficLightButtonsLeftMargin = 20
        trafficLightButtonsTopMargin = 0
        hideTitleBarInFullScreen = false
        isMovableByWindowBackground = true
        if let titlebarViews = titlebarAccessoryViewControllers[0].parent?.view.subviews {
            let matchingViews = titlebarViews
                .filter { $0.frame.origin.x == 0 && $0.frame.origin.y == 0 && $0.frame.width == 950 && $0.frame.height == 28 }
            if let v = matchingViews.last {
                v.frame = NSRect(x: 0, y: 0, width: 100, height: v.frame.height)
            }
        }

        setContentBorderThickness(0.0, for: NSRectEdge.minY)
        setAutorecalculatesContentBorderThickness(false, for: NSRectEdge.minY)
        isOpaque = false
        backgroundColor = NSColor.clear
        makeKeyAndOrderFront(self)
        orderFrontRegardless()
    }
}
