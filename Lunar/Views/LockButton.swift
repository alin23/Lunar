//
//  LockButton.swift
//  Lunar
//
//  Created by Alin on 07/08/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

// MARK: - LockButtonCell

final class LockButtonCell: NSButtonCell {
    override func _shouldDrawTextWithDisabledAppearance() -> Bool {
        (controlView as! LockButton).grayDisabledText
    }
}

// MARK: - LockButton

class LockButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var isEnabled: Bool {
        didSet {
            if isEnabled {
                setAttributedTitleColor(labelOn, alternate: true)
                setAttributedTitleColor(labelOff)
                bg = state == .on ? bgOn : bgOff
            } else {
                setAttributedTitleColor(labelOn.with(alpha: -0.2), alternate: true)
                setAttributedTitleColor(labelOff.with(alpha: -0.2))
                bg = state == .on ? bgOn.with(alpha: -0.2) : bgOff.with(alpha: -0.2)
            }
        }
    }

    override var state: NSControl.StateValue {
        didSet {
            mainAsync { [self] in bg = state == .on ? bgOn : bgOff }
        }
    }

    lazy var frameSize = frame.size
    @IBInspectable dynamic var grayDisabledText = true
    // @IBInspectable dynamic var horizontalPadding: CGFloat = 0.2 {
    //     didSet {
    //         adaptSize()
    //     }
    // }

    @IBInspectable dynamic var bgOn: NSColor = lockButtonBgOn
    @IBInspectable dynamic var bgOff: NSColor = lockButtonBgOff

    @IBInspectable dynamic var monospaced = false {
        didSet {
            setAttributedTitleColor(labelOff)
            setAttributedTitleColor(labelOn, alternate: true)
        }
    }

    @IBOutlet var notice: NSTextField? {
        didSet {
            notice?.alphaValue = 0.0
        }
    }

    @IBInspectable dynamic var verticalPadding: CGFloat = 0.7 {
        didSet {
            adaptSize()
        }
    }

    var bgOnHover: NSColor { bgOn.blended(withFraction: 0.3, of: bgOff) ?? bgOff
        // darkMode ?
        //     bgOn.highlight(withLevel: 0.2) ?? bgOn :
        //     bgOn.highlight(withLevel: 0.2) ?? bgOn
    }

    var bgOffHover: NSColor { bgOff.blended(withFraction: 0.3, of: bgOn) ?? bgOn
        // darkMode ?
        //     bgOn.highlight(withLevel: 0.4) ?? bgOn :
        //     bgOn.highlight(withLevel: 0.4) ?? bgOn
    }

    @IBInspectable dynamic var labelOn: NSColor = lockButtonLabelOn {
        didSet {
            setAttributedTitleColor(labelOff)
            setAttributedTitleColor(labelOn, alternate: true)
        }
    }

    @IBInspectable dynamic var labelOff: NSColor = lockButtonLabelOff {
        didSet {
            setAttributedTitleColor(labelOff)
            setAttributedTitleColor(labelOn, alternate: true)
        }
    }

    @IBInspectable dynamic lazy var cornerRadius: CGFloat = (frame.height / 2) {
        didSet {
            radius = min(frame.height / 2, cornerRadius).ns
        }
    }

    override func cursorUpdate(with _: NSEvent) {
        if isEnabled {
            NSCursor.pointingHand.set()
        }
    }

    override func mouseEntered(with _: NSEvent) {
        guard isEnabled else { return }
        transition(0.2)

        if state == .on {
            bg = bgOnHover
        } else {
            bg = bgOffHover
        }
        notice?.transition(0.4)
        notice?.alphaValue = 1.0
    }

    override func mouseExited(with _: NSEvent) {
        guard isEnabled else { return }
        transition(0.4)

        if state == .on {
            bg = bgOn
        } else {
            bg = bgOff
        }
        notice?.transition(0.4)
        notice?.alphaValue = 0.0
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    func adaptSize() {
        let size = frameSize
        // let width = size.width + (size.width * horizontalPadding)
        let height = size.height + (size.height * verticalPadding)
        setFrameSize(NSSize(width: size.width, height: height))
        cornerRadius = min(height / 2, cornerRadius)
    }

    func setAttributedTitleColor(_ color: NSColor, alternate: Bool = false) {
        var attrTitle = alternate ? attributedAlternateTitle : attributedTitle
        let s = attrTitle.string
        guard let newlineIndex = s.distance(of: "\n") else {
            if alternate {
                attributedAlternateTitle = attrTitle.withTextColor(color)
            } else {
                attributedTitle = attrTitle.withTextColor(color)
            }
            return
        }
        let titleSubrange = 0 ..< newlineIndex
        let subtitleSubrange = newlineIndex ..< (s.count)
        let title = attrTitle.attributedSubstring(from: titleSubrange)
        let subtitle = attrTitle.attributedSubstring(from: subtitleSubrange)

        var font = (title.fontAttributes(in: titleSubrange).first(where: { $0.keyName == .font })?.value as? NSFont)
            ?? NSFont.systemFont(ofSize: 11, weight: .bold)

        if monospaced {
            font = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: font.weight)
        }
        let subtitleStyle = NSMutableParagraphStyle()
        subtitleStyle.lineSpacing = 0
        subtitleStyle.maximumLineHeight = 8
        subtitleStyle.alignment = .center

        attrTitle = title.withTextColor(color) + subtitle
            .withTextColor(color)
            .withFont(font.withSize(max(font.pointSize - 3, 9)))
            .withParagraphStyle(subtitleStyle)

        if alternate {
            attributedAlternateTitle = attrTitle
        } else {
            attributedTitle = attrTitle
        }
    }

    func setup(_ locked: Bool = false) {
        wantsLayer = true

        setAttributedTitleColor(labelOff)
        setAttributedTitleColor(labelOn, alternate: true)

        let size = frameSize
        setFrameSize(NSSize(width: size.width, height: size.height + (size.height * verticalPadding)))
        radius = cornerRadius.ns
        if locked {
            state = .on
            bg = bgOn
        } else {
            state = .off
            bg = bgOff
        }
        trackHover(cursor: true)
        notice?.alphaValue = 0.0
    }

}

// MARK: - EnableButton

final class EnableButton: LockButton {
    override var bgOn: NSColor { get { enableButtonBgOn }
        set {}
    }

    override var bgOff: NSColor { get { enableButtonBgOff }
        set {}
    }

    override var labelOn: NSColor { get { enableButtonLabelOn }
        set {}
    }

    override var labelOff: NSColor { get { enableButtonLabelOff }
        set {}
    }
}
