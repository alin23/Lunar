import Atomics
import Cocoa

class StatusItemButtonController: NSView, NSPopoverDelegate {
    // MARK: Lifecycle

    convenience init(button: NSStatusBarButton) {
        self.init(frame: button.frame)
        statusButton = button
    }

    // MARK: Internal

    var statusButton: NSStatusBarButton?

    func popoverDidClose(_: Notification) {
        let positioningView = statusButton?.subviews.first {
            $0.identifier == NSUserInterfaceItemIdentifier(rawValue: "positioningView")
        }
        positioningView?.removeFromSuperview()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let button = statusButton else { return }
        appDelegate!.menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.frame.height + 6), in: button)
    }

    override func mouseDown(with event: NSEvent) {
        if let menuPopover = menuPopover, menuPopover.isShown {
            menuPopover.close()
            return
        }
        let menuPopover = appDelegate!.initMenuPopover()

        guard let button = statusButton, (menuPopover.contentViewController as? QuickActionsViewController) != nil
        else {
            return
        }
        button.menu = nil
        menuPopover.delegate = self

        let positioningView = NSView(frame: button.bounds)
        positioningView.identifier = NSUserInterfaceItemIdentifier(rawValue: "positioningView")
        button.addSubview(positioningView)

        menuPopover.show(relativeTo: positioningView.bounds, of: positioningView, preferredEdge: .maxY)
        positioningView.bounds = positioningView.bounds.offsetBy(dx: 0, dy: positioningView.bounds.height)
        if let popoverWindow = menuPopover.contentViewController?.view.window {
            popoverWindow.setFrame(popoverWindow.frame.offsetBy(dx: 0, dy: 12), display: false)
        }
        super.mouseDown(with: event)
    }
}
