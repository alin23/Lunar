import Cocoa
import Foundation

// MARK: - ButtonCell

final class ButtonCell: NSButtonCell {
    override func _shouldDrawTextWithDisabledAppearance() -> Bool {
        (controlView as! Button).grayDisabledText
    }
}

final class ClickBox: NSBox {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
}

final class ClickButton: NSButton {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
}

// MARK: - Button

class Button: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var title: String {
        didSet { mainAsync { [self] in
            guard !alternateTitleWhenDisabled else {
                attributedTitle = (isEnabled ? title : alternateTitle).withTextColor(textColor)
                return
            }
            attributedTitle = title.withTextColor(textColor)
        }}
    }

    override var alternateTitle: String {
        didSet { mainAsync { [self] in
            guard !alternateTitleWhenDisabled else {
                attributedTitle = (isEnabled ? title : alternateTitle).withTextColor(textColor)
                return
            }
            attributedTitle = title.withTextColor(textColor)
        }}
    }

    override var frame: NSRect {
        didSet { trackHover(rect: NSRect(origin: .zero, size: max(intrinsicContentSize, bounds.size)), cursor: true) }
    }

    override var isHidden: Bool {
        didSet {
            trackHover(rect: NSRect(origin: .zero, size: max(intrinsicContentSize, bounds.size)), cursor: true)
            defocus()
        }
    }

    override var isEnabled: Bool {
        didSet {
            guard !grayDisabledText else { return }
            mainAsync { [self] in
                alphaValue = isEnabled ? alpha : alpha + disabledAlphaOffset
                if alternateTitleWhenDisabled {
                    attributedTitle = (isEnabled ? title : alternateTitle).withTextColor(textColor)
                }
            }
        }
    }

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += horizontalPadding
        size.height += verticalPadding
        return size
    }

    @IBInspectable dynamic var grayDisabledText = true
    @IBInspectable dynamic var alternateTitleWhenDisabled = false
    var buttonShadow: NSShadow!
    var buttonShadowHover: NSShadow!

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var onClick: (() -> Void)?
    var hover = false

    weak var notice: NSTextField?

    lazy var highlighterKey = "highlighter-\(accessibilityIdentifier())"

    @IBInspectable dynamic var handCursor = true

    var highligherTask: Repeater?

    @IBInspectable dynamic var shadowAlpha: CGFloat = 0 {
        didSet {
            if let shadow = shadow?.copy() as? NSShadow {
                buttonShadow = shadow
                buttonShadow.shadowColor = buttonShadowHover.shadowColor?.withAlphaComponent(shadowAlpha)
            } else {
                buttonShadow = NO_SHADOW
            }
            shadow = (hover || shadowAlpha == 1) ? buttonShadowHover : shadowAlpha > 0 ? buttonShadow : NO_SHADOW
        }
    }

    @IBInspectable var horizontalPadding: CGFloat = 0 { didSet { mainAsync { [self] in invalidateIntrinsicContentSize() }}}
    @IBInspectable var verticalPadding: CGFloat = 0 { didSet { mainAsync { [self] in invalidateIntrinsicContentSize() }}}
    @IBInspectable var color: NSColor = .clear { didSet { mainAsync { [self] in bg = color }}}
    @IBInspectable var textColor: NSColor = .labelColor {
        didSet { mainAsync { [self] in
            guard !alternateTitleWhenDisabled else {
                attributedTitle = (isEnabled ? title : alternateTitle).withTextColor(textColor)
                return
            }
            attributedTitle = title.withTextColor(textColor)
        }}
    }

    @IBInspectable dynamic var disabledAlphaOffset: CGFloat = -0.3 {
        didSet {
            guard !grayDisabledText else { return }
            mainAsync { [self] in
                alphaValue = isEnabled ? alpha : alpha + disabledAlphaOffset
                if alternateTitleWhenDisabled {
                    attributedTitle = (isEnabled ? title : alternateTitle).withTextColor(textColor)
                }
            }
        }
    }

    @IBInspectable var cornerRadius: CGFloat = -1 {
        didSet { setShape() }
    }

    @IBInspectable var circle = true {
        didSet {
            mainAsync { [self] in
                setShape()
            }
        }
    }

    @IBInspectable var alpha: CGFloat = 0.8 {
        didSet {
            if !hover {
                mainAsync { [self] in
                    alphaValue = alpha
                }
            }
        }
    }

    @IBInspectable var hoverAlpha: CGFloat = 1.0 {
        didSet {
            if hover {
                mainAsync { [self] in
                    alphaValue = hoverAlpha
                }
            }
        }
    }

    var highlighting: Bool { highligherTask != nil }

    override func cursorUpdate(with _: NSEvent) {
        if isEnabled, handCursor {
            NSCursor.pointingHand.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        super.mouseDown(with: event)
    }

    override func mouseEntered(with _: NSEvent) {
        guard isEnabled else {
            if highlighting {
                stopHighlighting()
            }
            return
        }

        hover()
        onMouseEnter?()
    }

    override func mouseExited(with _: NSEvent) {
        if !isEnabled { return }
        defocus()
        onMouseExit?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    func highlight() {
        mainAsync { [weak self] in
            guard let self, !self.isHidden, self.window?.isVisible ?? false, self.highligherTask == nil
            else { return }

            self.highligherTask = Repeater(
                every: 5,
                name: self.highlighterKey
            ) { [weak self] in
                guard let self else { return }

                guard self.window?.isVisible ?? false, let notice = self.notice
                else {
                    self.highligherTask = nil
                    return
                }

                if notice.alphaValue <= 0.02 {
                    notice.transition(2)
                    notice.alphaValue = 0.9
                    notice.needsDisplay = true

                    self.hover(fadeDuration: 1)
                    self.needsDisplay = true
                } else {
                    notice.transition(3)
                    notice.alphaValue = 0.01
                    notice.needsDisplay = true

                    self.defocus(fadeDuration: 3)
                    self.needsDisplay = true
                }
            }
        }
    }

    func stopHighlighting() {
        mainAsync { [weak self] in
            guard let self else { return }
            self.highligherTask = nil

            if let notice = self.notice {
                notice.transition(0.8)
                notice.alphaValue = 0.0
                notice.needsDisplay = true
            }

            self.defocus(fadeDuration: 0.8)
            self.needsDisplay = true
        }
    }

    func setShape() {
        mainAsync { [self] in
            let buttonSize = frame
            if cornerRadius >= 0 {
                radius = cornerRadius.ns
            } else if circle, abs(buttonSize.height - buttonSize.width) < 3 {
                setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.width))
                radius = (min(frame.width, frame.height) / 2).ns
            } else if circle {
                radius = (min(frame.width, frame.height) / 2).ns
            } else {
                radius = (min(frame.width, frame.height) / 3).ns
            }
        }
    }

    func setup() {
        wantsLayer = true

        setShape()

        bg = color
        attributedTitle = title.withTextColor(textColor)
        alphaValue = alpha

        buttonShadowHover = shadow
        if let shadow = shadow?.copy() as? NSShadow {
            buttonShadow = shadow
            buttonShadow.shadowColor = buttonShadowHover.shadowColor?.withAlphaComponent(shadowAlpha)
        } else {
            buttonShadow = NO_SHADOW
        }
        shadow = shadowAlpha == 1 ? buttonShadowHover : (shadowAlpha > 0 ? buttonShadow : NO_SHADOW)
        isBordered = false
        trackHover(rect: NSRect(origin: .zero, size: max(intrinsicContentSize, bounds.size)), cursor: true)
    }

    func defocus(fadeDuration: TimeInterval = 0.6) {
        hover = false

        transition(fadeDuration)
        alphaValue = alpha
        shadow = shadowAlpha == 1 ? buttonShadowHover : (shadowAlpha > 0 ? buttonShadow : NO_SHADOW)
    }

    func hover(fadeDuration: TimeInterval = 0.3) {
        hover = true

        transition(fadeDuration)
        alphaValue = hoverAlpha
        shadow = buttonShadowHover
    }

}
