import Atomics
import Cocoa
import Defaults

// MARK: - StatusItemButtonControllerDelegate

final class StatusItemButtonControllerDelegate: NSObject, NSWindowDelegate {
    convenience init(statusItemButtonController: StatusItemButtonController) {
        self.init()
        self.statusItemButtonController = statusItemButtonController
    }

    var statusItemButtonController: StatusItemButtonController!

    func windowDidMove(_ notification: Notification) {
        guard let menuWindow, menuWindow.isVisible else { return }

        statusItemButtonController.repositionWindow(animate: true)
    }
}

class MenuWindowManager: ObservableObject {
    @Published var focused = true
}

let WM = MenuWindowManager()

// MARK: - StatusItemButtonController

final class StatusItemButtonController: NSView, NSWindowDelegate, ObservableObject {
    convenience init(button: NSStatusBarButton) {
        self.init(frame: button.frame)
        statusButton = button
        delegate = StatusItemButtonControllerDelegate(statusItemButtonController: self)
        statusButton?.window?.delegate = delegate
    }

    var statusButton: NSStatusBarButton?
    var delegate: StatusItemButtonControllerDelegate?
    var backgroundView: PopoverBackgroundView?

    @Published var storedPosition: CGPoint = .zero

    var position: CGPoint? {
        guard let statusButton, let menuBarIconPosition = statusButton.window?.convertPoint(toScreen: statusButton.frame.origin),
              let screen = NSScreen.cursor, let menuWindow
        else {
            return nil
        }

        let width = MENU_WIDTH / 2 + OPTIONS_MENU_WIDTH / 2 + (CachedDefaults[.showOptionsMenu] ? MENU_HORIZONTAL_PADDING * 2 : 0)
        var middle = CGPoint(
            x: menuBarIconPosition.x - width,
            y: screen.frame.maxY - display_manager_menu_bar_rect(screen.displayID ?? DC.cursorDisplay?.id ?? CGMainDisplayID()).height - (menuWindow.frame.height + 1)
        )

        let fullWidth = MENU_WIDTH + OPTIONS_MENU_WIDTH / 2 + (CachedDefaults[.showOptionsMenu] ? MENU_HORIZONTAL_PADDING * 2 : 0) + 12
        if middle.x + fullWidth > screen.visibleFrame.maxX {
            middle = CGPoint(x: screen.visibleFrame.maxX - fullWidth, y: middle.y)
        } else if middle.x < screen.visibleFrame.minX {
            middle = CGPoint(x: screen.visibleFrame.minX, y: middle.y)
        }

        if storedPosition != middle {
            storedPosition = middle
        }
        return middle
    }

    var willCloseTask: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }

    override func rightMouseDown(with _: NSEvent) {
        guard let button = statusButton else { return }
        appDelegate!.menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.frame.height + 8), in: button)
    }

    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.control, .command, .shift, .option]) != [.control] else {
            guard let button = statusButton else { return }
            appDelegate!.menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.frame.height + 8), in: button)
            return
        }
        toggleMenuBar()
        super.mouseDown(with: event)
    }

    func windowWillClose(_ notification: Notification) {
        postEndMenuTrackingNotification()
        willCloseTask = mainAsyncAfter(ms: 50) {
            Defaults[.menuBarClosed] = true
            if Defaults[.showOptionsMenu], !Defaults[.keepOptionsMenu] {
                Defaults[.showOptionsMenu] = false
            }
        }
    }

//    func windowDidResignKey(_ notification: Notification) {
//        WM.focused = false
//    }
//    func windowDidBecomeKey(_ notification: Notification) {
//        WM.focused = true
//    }

    func windowDidBecomeMain(_ notification: Notification) {
        willCloseTask = nil
        displayHideTask?.cancel()
        displayHideTask = nil
        Defaults[.menuBarClosed] = false
    }

    func toggleMenuBar() {
        if let menuWindow, menuWindow.isVisible {
            closeMenuBar()
        } else {
            showMenuBar()
        }
    }

    func closeMenuBar() {
        menuWindow?.forceClose()
    }

    func showMenuBar() {
        postBeginMenuTrackingNotification()
//        WM.focused = true
        willCloseTask = nil
        displayHideTask?.cancel()
        displayHideTask = nil

        guard let menuWindow = appDelegate?.initMenuWindow(), !menuWindow.isVisible else { return }

        Defaults[.menuBarClosed] = false
        guard let button = statusButton, menuWindow.contentViewController != nil else { return }
        button.menu = nil

        menuWindow.delegate = self
        repositionWindow()
    }

    func repositionWindow(animate: Bool = false) {
        guard let menuWindow, let screen = NSScreen.cursor, let appd = appDelegate else { return }
        displayHideTask?.cancel()
        displayHideTask = nil
        guard let position else {
            menuWindow.show()
            return
        }

        if Defaults[.showOptionsMenu] {
            if position.x + appd.env.menuWidth + appd.env.menuWidth / 2 + FULL_OPTIONS_MENU_WIDTH >= screen.visibleFrame.maxX {
                menuWindow.show(at: position.applying(.init(translationX: -FULL_OPTIONS_MENU_WIDTH / 2, y: 1)), animate: animate)
            } else {
                menuWindow.show(at: position.applying(.init(translationX: FULL_OPTIONS_MENU_WIDTH / 2, y: 1)), animate: animate)
            }
        } else {
            menuWindow.show(at: position, animate: animate)
        }
    }

}

/// Posting this notification causes the system Menu Bar to stay put when the cursor leaves its area while over a full screen app.
private func postBeginMenuTrackingNotification() {
    DistributedNotificationCenter.default().post(name: .init("com.apple.HIToolbox.beginMenuTrackingNotification"), object: nil)
}

/// Posting this notification reverses the effect of the notification above.
private func postEndMenuTrackingNotification() {
    DistributedNotificationCenter.default().post(name: .init("com.apple.HIToolbox.endMenuTrackingNotification"), object: nil)
}
