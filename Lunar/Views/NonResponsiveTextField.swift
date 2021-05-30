import Cocoa

class NonResponsiveTextField: NSTextField {
    var hover: Bool = false
    var trackingArea: NSTrackingArea?
    var onClick: (() -> Void)?
    override var isHidden: Bool {
        didSet {
            mainThread {
                if let adaptiveButton = superview?.subviews.first(
                    where: { v in (v as? QuickAdaptiveButton) != nil }
                ) as? QuickAdaptiveButton {
                    adaptiveButton.isHidden = !self.isHidden
                }
            }
        }
    }

    func setup() {
        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func mouseEntered(with _: NSEvent) {
        mainThread {
            if isHidden {
                return
            }
            hover = true

            layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
            stringValue = "Click to reset"
            textColor = NSColor.systemRed.blended(withFraction: 0.3, of: .systemOrange) ?? NSColor.systemRed
        }
    }

    override func mouseExited(with _: NSEvent) {
        mainThread {
            if isHidden {
                return
            }
            hover = false

            layer?.add(fadeTransition(duration: 0.3), forKey: "transition")
            stringValue = "Non-responsive"
            textColor = NSColor.systemRed
        }
    }

    override func mouseDown(with _: NSEvent) {
        mainThread {
            if isHidden {
                return
            }

            onClick?()
        }
    }
}
