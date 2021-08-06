//
//  PageControl.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

// MARK: - PageControl

public class PageControl: NSView {
    // MARK: Lifecycle

    init(
        frame: NSRect,
        numberOfPages: Int = 0,
        hidesForSinglePage: Bool = true,
        tintColor: NSColor = NSColor.darkGray,
        currentTintColor: NSColor = NSColor.white,
        animationDuration: CFTimeInterval = 0.04,
        dotLength: CGFloat = 8.0,
        dotMargin: CGFloat = 12.0
    ) {
        super.init(frame: frame)
        self.numberOfPages = numberOfPages
        self.hidesForSinglePage = hidesForSinglePage
        pageIndicatorTintColor = tintColor
        currentPageIndicatorTintColor = currentTintColor
        self.animationDuration = animationDuration
        self.dotLength = dotLength
        self.dotMargin = dotMargin
    }

    public required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    // MARK: Public

    public var numberOfPages: Int = 0
    public var hidesForSinglePage: Bool = true
    public var pageIndicatorTintColor = NSColor.darkGray
    public var currentPageIndicatorTintColor = NSColor.white
    public var animationDuration: CFTimeInterval = 0.04
    public var dotLength: CGFloat = 8.0
    public var dotMargin: CGFloat = 12.0

    public var currentPage: Int = 2 {
        didSet(oldValue) {
            if currentPage < 0 {
                currentPage = 0
            }
            if currentPage > numberOfPages - 1 {
                currentPage = numberOfPages - 1
            }
            didSetCurrentPage(oldValue, newlySelectedPage: currentPage)
        }
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let dotWidthSum: CGFloat = dotLength * CGFloat(numberOfPages)
        let marginWidthSum: CGFloat = dotMargin * CGFloat(numberOfPages - 1)
        let minimumRequiredWidth: CGFloat = dotWidthSum + marginWidthSum

        let hasEnoughHeight: Bool = dirtyRect.height >= dotLength
        let hasEnoughWidth: Bool = dirtyRect.width >= minimumRequiredWidth
        if !hasEnoughWidth || !hasEnoughHeight {
            Swift.print("dirtyRect doesn't have enough space to draw all dots")
            Swift.print("current Rect :\(dirtyRect)")
            Swift.print("required Size:\(CGSize(width: minimumRequiredWidth, height: dotLength))")
        }

        for layer in dotLayers {
            layer.removeFromSuperlayer()
        }
        dotLayers = []
        layer = CALayer()
        wantsLayer = true

        for i: Int in 0 ..< numberOfPages {
            let minX: CGFloat = (dirtyRect.width - minimumRequiredWidth) / 2
            let indexOffset: CGFloat = (dotLength + dotMargin) * CGFloat(i)
            let x: CGFloat = minX + indexOffset
            let verticalCenter: CGFloat = (dirtyRect.height - dotLength) / 2
            let y: CGFloat = verticalCenter - dotLength / 2
            let rect: CGRect = NSRect(x: x, y: y, width: dotLength, height: dotLength)
            let cgPath = CGMutablePath()
            cgPath.addEllipse(in: rect)

            let fillColor: NSColor = (i == currentPage) ? currentPageIndicatorTintColor : pageIndicatorTintColor
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = cgPath
            shapeLayer.fillColor = fillColor.cgColor

            layer?.addSublayer(shapeLayer)
            dotLayers.append(shapeLayer)
        }
    }

    // MARK: Private

    private var dotLayers: [CAShapeLayer] = []

    private func didSetCurrentPage(_ selectedPage: Int, newlySelectedPage: Int) {
        if selectedPage == newlySelectedPage {
            return
        }

        let oldPageAnimation: CABasicAnimation = fillColorAnimation(with: pageIndicatorTintColor)
        dotLayers[selectedPage].add(oldPageAnimation, forKey: "oldPageAnimation")
        let newPageAnimation: CABasicAnimation = fillColorAnimation(with: currentPageIndicatorTintColor)
        dotLayers[newlySelectedPage].add(newPageAnimation, forKey: "newPageAnimation")
    }

    private func fillColorAnimation(with color: NSColor) -> CABasicAnimation {
        let fillColorAnimation = CABasicAnimation(keyPath: "fillColor")
        fillColorAnimation.toValue = color.cgColor
        fillColorAnimation.duration = animationDuration
        fillColorAnimation.fillMode = convertToCAMediaTimingFillMode(convertFromCAMediaTimingFillMode(CAMediaTimingFillMode.forwards))
        fillColorAnimation.isRemovedOnCompletion = false
        return fillColorAnimation
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToCAMediaTimingFillMode(_ input: String) -> CAMediaTimingFillMode {
    CAMediaTimingFillMode(rawValue: input)
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromCAMediaTimingFillMode(_ input: CAMediaTimingFillMode) -> String {
    input.rawValue
}
