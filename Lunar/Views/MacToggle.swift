//
//  MacToggle.swift
//  RichAppz
//
//  Copyright © 2016-2017 RichAppz Limited. All rights reserved.
//  richappz.com - (rich@richappz.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Cocoa

// @IBDesignable
class MacToggle: NSView {
    //================================================================================

    // MARK: Properties

    //================================================================================

    public var isEnabled: Bool = true {
        didSet {
            mainThread {
                if isEnabled {
                    alphaValue = 1.0
                    backVw.bg = backColor
                    circle.bg = toggleColor
                    circle.layer?.borderColor = white.cgColor
                } else {
                    alphaValue = 0.6
                    backVw.bg = darkMauve
                    circle.bg = .darkGray
                    circle.layer?.borderColor = NSColor.darkGray.cgColor
                }
            }
        }
    }

    fileprivate var height: CGFloat = 26
    fileprivate var width: CGFloat { height + (height * 0.6) }

    fileprivate var leftConstraint: NSLayoutConstraint?
    fileprivate var heightConstraint: NSLayoutConstraint?
    fileprivate var widthConstraint: NSLayoutConstraint?

    fileprivate let backVw: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        return view
    }()

    fileprivate let circle: NSView = {
        let view = NSView()

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow.shadowOffset = CGSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 2

        view.bg = .white
        view.wantsLayer = true
        view.shadow = shadow
        view.layer?.borderWidth = 2
        view.layer?.borderColor = NSColor.white.cgColor
        return view
    }()

    fileprivate var _radius: CGFloat?
    fileprivate var backRadius: CGFloat {
        if let r = _radius { return r }
        return height / 2
    }

    fileprivate var circleRadius: CGFloat {
        if let r = _radius { return r - outlineWidth }
        return (height - (outlineWidth * 2)) / 2
    }

    fileprivate var toggleSize: CGFloat { height - (outlineWidth * 2) }

    //================================================================================

    // MARK: Callback

    //================================================================================

    var callback: ((_ isOn: Bool) -> Void)?

    //================================================================================

    // MARK: Public Parameters

    //================================================================================

    @IBInspectable public var isOn = false {
        didSet { animate() }
    }

    /// Change the toggle border on and off
    @IBInspectable public var hasToggleBorder = true {
        didSet { circle.layer?.borderWidth = hasToggleBorder ? toggleBorderWidth : 0 }
    }

    /// Change the width of the outline border
    @IBInspectable public var outlineWidth: CGFloat = 2 {
        didSet {
            backVw.layer?.borderWidth = outlineWidth
            layoutSwitch(resetingLayout: true)
        }
    }

    /// Change the width of the border on the toggle
    @IBInspectable public var toggleBorderWidth: CGFloat = 2 {
        didSet { circle.layer?.borderWidth = hasToggleBorder ? toggleBorderWidth : 0 }
    }

    /// Change the radius of the complete toggle
    @IBInspectable public var toggleRadius: CGFloat {
        get {
            if let r = _radius { return r }
            return (height - (outlineWidth * 2)) / 2
        }
        set {
            _radius = newValue
            layoutSwitch()
        }
    }

    /// Change the color of the outline border
    @IBInspectable public var outlineColor: NSColor = .lightGray {
        didSet { backVw.layer?.borderColor = outlineColor.cgColor }
    }

    /// Change the color of the fill when the toggle is on
    @IBInspectable public var fillColor: NSColor = .lightGray {
        didSet { if isOn { backVw.layer?.borderColor = fillColor.cgColor } }
    }

    /// Change the color of the toggle center
    @IBInspectable public var toggleColor: NSColor = .white {
        didSet { circle.bg = toggleColor }
    }

    /// Change the background color of the complete toggle (visible when switch is off)
    @IBInspectable public var backColor: NSColor = .white {
        didSet { backVw.bg = backColor }
    }

    //================================================================================

    // MARK: Initialization

    //================================================================================

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        drawView()
    }

    required init(height: CGFloat = 44) {
        self.height = height
        super.init(frame: .zero)
        drawView()
    }

    override func mouseDown(with _: NSEvent) {
        guard isEnabled else { return }
        let push = Double(outlineWidth + width) - Double(height)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true

            let adjustment = (toggleSize / 4)
            widthConstraint?.isActive = false
            widthConstraint = circle.widthAnchor.constraint(equalToConstant: toggleSize + adjustment)
            widthConstraint?.isActive = true

            if isOn {
                leftConstraint?.constant = CGFloat(push) - adjustment
            }
            animator().layoutSubtreeIfNeeded()
        }
    }

    override func mouseUp(with _: NSEvent) {
        guard isEnabled else { return }

        isOn = !isOn
    }

    //================================================================================

    // MARK: Helpers

    //================================================================================

    fileprivate func drawView() {
        backVw.bg = backColor

        addSubview(backVw)
        backVw.translatesAutoresizingMaskIntoConstraints = false
        backVw.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        backVw.widthAnchor.constraint(equalToConstant: width).isActive = true
        backVw.heightAnchor.constraint(equalToConstant: height).isActive = true

        addSubview(circle)
        circle.translatesAutoresizingMaskIntoConstraints = false
        leftConstraint = circle.leftAnchor.constraint(equalTo: backVw.leftAnchor, constant: outlineWidth)
        circle.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        widthConstraint = circle.widthAnchor.constraint(equalToConstant: height - (outlineWidth * 2))
        heightConstraint = circle.heightAnchor.constraint(equalToConstant: height - (outlineWidth * 2))

        leftConstraint?.isActive = true
        widthConstraint?.isActive = true
        heightConstraint?.isActive = true

        translatesAutoresizingMaskIntoConstraints = false
        rightAnchor.constraint(equalTo: backVw.rightAnchor).isActive = true
        heightAnchor.constraint(equalToConstant: height).isActive = true

        layoutSwitch()
    }

    fileprivate func layoutSwitch(resetingLayout: Bool = false) {
        if resetingLayout {
            leftConstraint?.constant = outlineWidth

            widthConstraint?.isActive = false
            widthConstraint = circle.widthAnchor.constraint(equalToConstant: height - (outlineWidth * 2))
            widthConstraint?.isActive = true

            heightConstraint?.isActive = false
            heightConstraint = circle.heightAnchor.constraint(equalToConstant: height - (outlineWidth * 2))
            heightConstraint?.isActive = true
            layoutSubtreeIfNeeded()
        }

        backVw.radius = backRadius.ns
        backVw.layer?.borderWidth = isOn ? (height / 2) : outlineWidth
        backVw.layer?.borderColor = outlineColor.cgColor

        circle.radius = circleRadius.ns
    }

    fileprivate func animate() {
        allowedTouchTypes = []
        let push = Double(outlineWidth + width) - Double(height)

        let callback = self.callback
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true

            backVw.animator().layer?.borderWidth = isOn ? (height / 2) : outlineWidth
            backVw.animator().layer?.borderColor = isOn ? fillColor.cgColor : outlineColor.cgColor

            widthConstraint?.isActive = false
            widthConstraint = circle.widthAnchor.constraint(equalToConstant: toggleSize)
            widthConstraint?.isActive = true

            leftConstraint?.constant = isOn ? CGFloat(push) : outlineWidth
            animator().layoutSubtreeIfNeeded()
        }) { [weak self] in
            guard let self = self else { return }
            self.allowedTouchTypes = [.direct, .indirect]
            callback?(self.isOn)
        }
    }
}
