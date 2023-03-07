import Atomics
import Cocoa
import Combine
import Defaults

// MARK: - ColorsPopoverController

final class ColorsPopoverController: NSViewController {
    @objc dynamic weak var display: Display?
}

// MARK: - ColorsButton

final class ColorsButton: PopoverButton<ColorsPopoverController> {
    weak var display: Display? {
        didSet {
            popoverController?.display = display
        }
    }

    override var popoverKey: String {
        "colors"
    }

    override func mouseDown(with event: NSEvent) {
        popoverController?.display = display
        super.mouseDown(with: event)
    }
}
