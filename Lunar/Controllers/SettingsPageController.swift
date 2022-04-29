//
//  SettingsPageController.swift
//  Lunar
//
//  Created by Alin on 21/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa
import Combine
import Defaults

extension CALayer {
    func addCircle(x: CGFloat, y: CGFloat, radius: CGFloat, color: CGColor, transform: UnsafePointer<CGAffineTransform>? = nil) {
        let layer = CAShapeLayer()
        layer.fillColor = color
        layer.path = CGPath(ellipseIn: NSRect(x: x, y: y, width: radius * 2, height: radius * 2), transform: transform)
        addSublayer(layer)
    }
}

extension NSViewController {
    func drawMoon(color: NSColor) {
        guard let layer = view.layer else { return }
        let craterColor = color.withAlphaComponent(0.015).cgColor
        layer.addCircle(x: -40, y: -20, radius: 70, color: craterColor)
        layer.addCircle(x: 150, y: 80, radius: 100, color: craterColor)
        layer.addCircle(x: 540, y: 300, radius: 80, color: craterColor)
        layer.addCircle(x: 500, y: -140, radius: 120, color: craterColor)
        layer.addCircle(x: 0, y: 600, radius: 100, color: craterColor)
        layer.addCircle(x: 400, y: 500, radius: 120, color: craterColor)
        var t = CGAffineTransform(scaleX: 0.7, y: 1)
        layer.addCircle(x: 1150, y: 200, radius: 120, color: craterColor, transform: &t)

        let shadeLayer = CAShapeLayer()
        let shadeLayerPath = CGMutablePath()
        let (w, h) = (view.frame.width, view.frame.height)
        let arcStartPoint = CGPoint(x: w * 0.5, y: -200)
        let arcMidPoint = CGPoint(x: w, y: h * 0.25)
        let arcEndPoint = CGPoint(x: w * 0.98, y: h + 800)
        shadeLayerPath.move(to: arcStartPoint)
        shadeLayerPath.addArc(tangent1End: arcStartPoint, tangent2End: arcMidPoint, radius: 500)
        shadeLayerPath.addArc(tangent1End: arcMidPoint, tangent2End: arcEndPoint, radius: 800)
        shadeLayerPath.addArc(tangent1End: arcEndPoint, tangent2End: CGPoint(x: w * 0.9, y: h + 1800), radius: 800)
        shadeLayerPath.addLine(to: CGPoint(x: w + 100, y: h + 200))
        shadeLayerPath.addLine(to: CGPoint(x: w + 100, y: -200))
        shadeLayerPath.addLine(to: arcStartPoint)
        shadeLayerPath.closeSubpath()

        shadeLayer.fillColor = color.withAlphaComponent(0.02).cgColor
        shadeLayer.path = shadeLayerPath
        layer.addSublayer(shadeLayer)
    }
}

// MARK: - SettingsPageController

class SettingsPageController: NSViewController {
    @IBOutlet var settingsContainerView: NSView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.bg = settingsBgColor
        drawMoon(color: darkMauve)
    }

    override func wantsScrollEventsForSwipeTracking(on axis: NSEvent.GestureAxis) -> Bool {
        axis == .horizontal
    }
}
