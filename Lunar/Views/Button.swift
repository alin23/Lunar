import Cocoa
import Foundation

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

    var buttonShadow: NSShadow!

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var onClick: (() -> Void)?
    var hover = false

    @IBInspectable var horizontalPadding: CGFloat = 0 { didSet { mainThread { invalidateIntrinsicContentSize() }}}
    @IBInspectable var verticalPadding: CGFloat = 0 { didSet { mainThread { invalidateIntrinsicContentSize() }}}
    @IBInspectable var color: NSColor = .clear { didSet { mainThread { bg = color }}}
    @IBInspectable var textColor: NSColor = .labelColor {
        didSet { mainThread { attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: textColor]) }}
    }

    override var frame: NSRect {
        didSet { trackHover(rect: NSRect(origin: .zero, size: max(intrinsicContentSize, bounds.size)), cursor: true) }
    }

    override var isHidden: Bool {
        didSet { trackHover(rect: NSRect(origin: .zero, size: max(intrinsicContentSize, bounds.size)), cursor: true) }
    }

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += horizontalPadding
        size.height += verticalPadding
        return size
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

    func setShape() {
        mainThread {
            let buttonSize = frame
            if circle, abs(buttonSize.height - buttonSize.width) < 3 {
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
        attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: textColor])
        alphaValue = alpha

        buttonShadow = shadow
        shadow = NO_SHADOW
        isBordered = false
        trackHover(rect: NSRect(origin: .zero, size: max(intrinsicContentSize, bounds.size)), cursor: true)
    }

    override func cursorUpdate(with event: NSEvent) {
        if isEnabled {
            NSCursor.pointingHand.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        super.mouseDown(with: event)
    }

    override func mouseEntered(with _: NSEvent) {
        if !isEnabled { return }
        hover = true

        transition(0.3)
        alphaValue = hoverAlpha
        shadow = buttonShadow

        onMouseEnter?()
    }

    override func mouseExited(with _: NSEvent) {
        if !isEnabled { return }
        hover = false

        transition(0.6)
        alphaValue = alpha
        shadow = NO_SHADOW

        onMouseExit?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
