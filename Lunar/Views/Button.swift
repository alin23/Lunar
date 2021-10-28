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
    @AtomicLock var highlighterTask: CFRunLoopTimer?

    @IBInspectable var horizontalPadding: CGFloat = 0 { didSet { mainThread { invalidateIntrinsicContentSize() }}}
    @IBInspectable var verticalPadding: CGFloat = 0 { didSet { mainThread { invalidateIntrinsicContentSize() }}}
    @IBInspectable var color: NSColor = .clear { didSet { mainThread { bg = color }}}
    @IBInspectable var textColor: NSColor = .labelColor {
        didSet { mainThread {
            guard !alternateTitleWhenDisabled else {
                attributedTitle = (isEnabled ? title : alternateTitle).withTextColor(textColor)
                return
            }
            attributedTitle = title.withTextColor(textColor)
        }}
    }

    override var title: String {
        didSet { mainThread {
            guard !alternateTitleWhenDisabled else {
                attributedTitle = (isEnabled ? title : alternateTitle).withTextColor(textColor)
                return
            }
            attributedTitle = title.withTextColor(textColor)
        }}
    }

    override var alternateTitle: String {
        didSet { mainThread {
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
            mainThread {
                alphaValue = isEnabled ? alpha : alpha - 0.3
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
            mainThread {
                setShape()
            }
        }
    }

    @IBInspectable var alpha: CGFloat = 0.8 {
        didSet {
            if !hover {
                mainThread {
                    alphaValue = alpha
                }
            }
        }
    }

    @IBInspectable var hoverAlpha: CGFloat = 1.0 {
        didSet {
            if hover {
                mainThread {
                    alphaValue = hoverAlpha
                }
            }
        }
    }

    func highlight() {
        guard !isHidden else { return }

        let windowVisible = mainThread { window?.isVisible ?? false }

        guard highlighterTask == nil || !realtimeQueue.isValid(timer: highlighterTask!), windowVisible
        else {
            return
        }

        highlighterTask = realtimeQueue.async(every: 5.seconds) { [weak self] (_: CFRunLoopTimer?) in
            guard let s = self else {
                if let timer = self?.highlighterTask { realtimeQueue.cancel(timer: timer) }
                return
            }

            let windowVisible: Bool = mainThread { s.window?.isVisible ?? false }
            guard windowVisible, let notice = s.notice else {
                if let timer = self?.highlighterTask { realtimeQueue.cancel(timer: timer) }
                return
            }

            mainThread {
                if notice.alphaValue <= 0.02 {
                    notice.transition(1)
                    notice.alphaValue = 0.9
                    notice.needsDisplay = true

                    s.hover(fadeDuration: 1)
                    s.needsDisplay = true
                } else {
                    notice.transition(3)
                    notice.alphaValue = 0.01
                    notice.needsDisplay = true

                    s.defocus(fadeDuration: 3)
                    s.needsDisplay = true
                }
            }
        }
    }

    func stopHighlighting() {
        if let timer = highlighterTask {
            realtimeQueue.cancel(timer: timer)
        }
        highlighterTask = nil

        mainThread {
            if let notice = notice {
                notice.transition(0.3)
                notice.alphaValue = 0.0
                notice.needsDisplay = true
            }

            defocus(fadeDuration: 0.3)
            needsDisplay = true
        }
    }

    func setShape() {
        mainThread {
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
        if isEnabled {
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
            if highlighterTask != nil {
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
