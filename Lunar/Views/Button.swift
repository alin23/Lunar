import Cocoa
import Foundation

// MARK: - ButtonCell

class ButtonCell: NSButtonCell {
    override func _shouldDrawTextWithDisabledAppearance() -> Bool {
        (controlView as! Button).grayDisabledText
    }
}

// MARK: - Button

class Button: NSButton {
    // MARK: Lifecycle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Internal

    @IBInspectable dynamic var grayDisabledText: Bool = true
    @IBInspectable dynamic var alternateTitleWhenDisabled: Bool = false

    var buttonShadow: NSShadow!

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var onClick: (() -> Void)?
    var hover = false

    weak var notice: NSTextField?

    lazy var highlighterKey: String = "highlighter-\(accessibilityIdentifier())"

    @IBInspectable dynamic var handCursor = true

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

    @IBInspectable var cornerRadius: CGFloat = -1 {
        didSet { setShape() }
    }

    @IBInspectable var circle: Bool = true {
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

    var highlighting: Bool { taskIsRunning(highlighterKey) }

    func highlight() {
        mainAsync { [weak self] in
            guard let self = self, !self.isHidden, self.window?.isVisible ?? false
            else { return }

            asyncEvery(
                5.seconds,
                uniqueTaskKey: self.highlighterKey,
                skipIfExists: true,
                eager: true,
                queue: DispatchQueue.main
            ) { [weak self] in
                guard let self = self else { return }

                guard self.window?.isVisible ?? false, let notice = self.notice
                else {
                    cancelTask(self.highlighterKey)
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
            guard let self = self else { return }
            cancelTask(self.highlighterKey)

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

        buttonShadow = shadow
        shadow = NO_SHADOW
        isBordered = false
        trackHover(rect: NSRect(origin: .zero, size: max(intrinsicContentSize, bounds.size)), cursor: true)
    }

    override func cursorUpdate(with _: NSEvent) {
        if isEnabled, handCursor {
            NSCursor.pointingHand.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        super.mouseDown(with: event)
    }

    func defocus(fadeDuration: TimeInterval = 0.6) {
        hover = false

        transition(fadeDuration)
        alphaValue = alpha
        shadow = NO_SHADOW
    }

    func hover(fadeDuration: TimeInterval = 0.3) {
        hover = true

        transition(fadeDuration)
        alphaValue = hoverAlpha
        shadow = buttonShadow
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
}
