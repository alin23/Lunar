import Cocoa

class NonResponsiveTextField: NSTextField {
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

    var hover: Bool = false
    var trackingArea: NSTrackingArea?
    var onClick: (() -> Void)?

    override var isHidden: Bool {
        didSet {
            mainThread {
                if let dvc = superview?.nextResponder as? DisplayViewController,
                   let inputDropdown = superview?.subviews.first(
                       where: { v in (v as? PopUpButton) != nil }
                   ) as? PopUpButton,
                   let inputDropdownHotkeyButton = superview?.subviews.first(
                       where: { v in (v as? HotkeyButton) != nil }
                   ) as? HotkeyButton
                {
                    log.debug("Non-responsive text hidden: \(isHidden)")
                    inputDropdown.isHidden = !self.isHidden || displayController.activeDisplays.isEmpty || dvc.inputHidden
                    inputDropdownHotkeyButton.isHidden = !self.isHidden || displayController.activeDisplays.isEmpty || dvc.inputHidden
                }
            }
        }
    }

    func setup() {
        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
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

            transition(0.2)
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

            transition(0.3)
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
