import Atomics
import Cocoa
import Defaults

// MARK: - StatusItemButtonController

class StatusItemButtonController: NSView, NSWindowDelegate {
    // MARK: Lifecycle

    convenience init(button: NSStatusBarButton) {
        self.init(frame: button.frame)
        statusButton = button
    }

    // MARK: Internal

    var statusButton: NSStatusBarButton?
    var backgroundView: PopoverBackgroundView?

    var position: CGPoint? {
        guard let statusButton, let menuBarIconPosition = statusButton.window?.convertPoint(toScreen: statusButton.frame.origin),
              let screen = NSScreen.main, let menuWindow
        else {
            return nil
        }

        var middle = CGPoint(
            x: menuBarIconPosition.x - MENU_WIDTH / 2 - OPTIONS_MENU_WIDTH / 2,
            y: screen.visibleFrame.maxY - (menuWindow.frame.height + 1)
        )

        if middle.x + FULL_MENU_WIDTH > screen.visibleFrame.maxX {
            middle = CGPoint(x: screen.visibleFrame.maxX - FULL_MENU_WIDTH, y: middle.y)
        } else if middle.x < screen.visibleFrame.minX {
            middle = CGPoint(x: screen.visibleFrame.minX, y: middle.y)
        }

        return middle
    }

    func windowWillClose(_ notification: Notification) {
        mainAsyncAfter(ms: 50) {
            Defaults[.menuBarClosed] = true
            if Defaults[.showOptionsMenu], !Defaults[.keepOptionsMenu] {
                Defaults[.showOptionsMenu] = false
            }
        }
    }

    func windowDidBecomeMain(_ notification: Notification) {
        Defaults[.menuBarClosed] = false
    }

    override func rightMouseDown(with _: NSEvent) {
        guard let button = statusButton else { return }
        appDelegate!.menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.frame.height + 8), in: button)
    }

    func toggleMenuBar() {
        if let menuWindow = menuWindow, menuWindow.isVisible {
            closeMenuBar()
        } else {
            showMenuBar()
        }
    }

    func closeMenuBar() {
        menuWindow?.forceClose()
//        menuWindow = nil
    }

    func showMenuBar() {
        guard let menuWindow = appDelegate?.initMenuWindow(), !menuWindow.isVisible else { return }

        Defaults[.menuBarClosed] = false
        guard let button = statusButton, menuWindow.contentViewController != nil else { return }
        button.menu = nil

        menuWindow.delegate = self
        repositionWindow()
    }

    func repositionWindow() {
        guard let menuWindow, let screen = NSScreen.main, let appd = appDelegate else { return }
        guard let position else {
            menuWindow.show()
            return
        }

        if Defaults[.showOptionsMenu] {
            if position.x + appd.env.menuWidth + appd.env.menuWidth / 2 + FULL_OPTIONS_MENU_WIDTH >= screen.visibleFrame.maxX {
                menuWindow.show(at: position.applying(.init(translationX: -FULL_OPTIONS_MENU_WIDTH / 2, y: 1)))
            } else {
                menuWindow.show(at: position.applying(.init(translationX: FULL_OPTIONS_MENU_WIDTH / 2, y: 1)))
            }
        } else {
            menuWindow.show(at: position)
        }
    }

    override func mouseDown(with event: NSEvent) {
        toggleMenuBar()
        super.mouseDown(with: event)
    }
}
