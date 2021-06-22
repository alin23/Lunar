import Cocoa

class NotConnectedTextField: NSTextField {
    var hover: Bool = false
    var trackingArea: NSTrackingArea?
    var onClick: (() -> Void)?

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
        if isHidden {
            return
        }
        hover = true

        transition(0.2)
        stringValue = "Click to remove"
        textColor = NSColor.labelColor
    }

    override func mouseExited(with _: NSEvent) {
        if isHidden {
            return
        }
        hover = false

        transition(0.3)
        stringValue = "Not connected"
        textColor = NSColor.secondaryLabelColor
    }

    override func mouseDown(with _: NSEvent) {
        if isHidden {
            return
        }

        onClick?()
    }
}
