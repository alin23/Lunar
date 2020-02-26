import Cocoa

class NonResponsiveDDCTextField: NSTextField {
    var hover: Bool = false
    var trackingArea: NSTrackingArea?
    var onClick: (() -> Void)?

    func setup() {
        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // setup()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func mouseEntered(with _: NSEvent) {
        if isHidden {
            return
        }
        hover = true

        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        stringValue = "Click to remove"
        textColor = NSColor.labelColor
    }

    override func mouseExited(with _: NSEvent) {
        if isHidden {
            return
        }
        hover = false

        layer?.add(fadeTransition(duration: 0.3), forKey: "transition")
        stringValue = "Non-responsive DDC"
        textColor = NSColor.secondaryLabelColor
    }

    override func mouseDown(with _: NSEvent) {
        if isHidden {
            return
        }

        onClick?()
    }
}
