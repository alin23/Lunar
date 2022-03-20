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
    var backgroundView: PopoverBackgroundView?

    func popoverDidClose(_: Notification) {
        if let window = menuPopover?.contentViewController?.view.window {
            window.identifier = nil
        }
        let positioningView = statusButton?.subviews.first {
            $0.identifier == NSUserInterfaceItemIdentifier(rawValue: "positioningView")
        }
        positioningView?.removeFromSuperview()
    }

    override func rightMouseDown(with _: NSEvent) {
        guard let button = statusButton else { return }
        appDelegate!.menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.frame.height + 8), in: button)
    }

    func togglePopover() {
        if let menuPopover = menuPopover, menuPopover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func resize(_ size: NSSize) {
        guard let menuPopover = menuPopover else { return }

        menuPopover.contentSize = size
        guard let positioningView = statusButton?.subviews.first(where: {
            $0.identifier == NSUserInterfaceItemIdentifier(rawValue: "positioningView")
        }) else { return }
        menuPopover.positioningRect = positioningView.bounds
    }

    func closePopover() {
        guard let menuPopover = menuPopover, menuPopover.isShown else {
            return
        }
        menuPopover.close()
    }

    func showPopover() {
        let menuPopover = appDelegate!.initMenuPopover()

        guard !menuPopover.isShown else { return }

        guard let button = statusButton, menuPopover.contentViewController != nil
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
        if let view = menuPopover.contentViewController?.view, let popoverWindow = view.window {
            popoverWindow.setFrame(popoverWindow.frame.offsetBy(dx: 0, dy: 12), display: false)
        }
        menuPopover.contentViewController?.view.window?.makeKeyAndOrderFront(self)
    }

    override func mouseDown(with event: NSEvent) {
        togglePopover()
        super.mouseDown(with: event)
    }
}
