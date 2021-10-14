import Cocoa
import Combine
import Foundation

let buttonBgOn = sunYellow
let buttonBgOnHover = buttonBgOn.blended(withFraction: 0.2, of: red) ?? buttonBgOn
let buttonLabelOn = darkMauve
let buttonBgOff = gray
let buttonBgOffHover = buttonBgOn
let buttonLabelOff = darkMauve
let buttonBgDisabled = gray.shadow(withLevel: 0.3)

// MARK: - QuickAdaptiveButton

class QuickAdaptiveButton: NSButton {
    // MARK: Lifecycle

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        for observer in displayObservers.values {
            observer.cancel()
        }
    }

    // MARK: Internal

    var adaptiveButtonTrackingArea: NSTrackingArea?
    var adaptiveObserver: ((Bool, Bool) -> Void)?
    var displayID: CGDirectDisplayID?
    var displayObservers = [String: AnyCancellable]()

    weak var display: Display? {
        guard let id = displayID else { return nil }
        return displayController.displays[id]
    }

    func setup(displayID: CGDirectDisplayID) {
        self.displayID = displayID

        let buttonSize = frame
        wantsLayer = true

        let activeTitle = NSMutableAttributedString(attributedString: attributedAlternateTitle)
        activeTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: buttonLabelOn, range: NSMakeRange(0, activeTitle.length))
        let inactiveTitle = NSMutableAttributedString(attributedString: attributedTitle)
        inactiveTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: buttonLabelOff,
            range: NSMakeRange(0, inactiveTitle.length)
        )

        attributedTitle = inactiveTitle
        attributedAlternateTitle = activeTitle

        setFrameSize(NSSize(width: buttonSize.width, height: 18))
        radius = (frame.height / 2).ns

        if let adaptive = display?.adaptive {
            if adaptive {
                state = .on
            } else {
                state = .off
            }
        }

        if !isEnabled {
            bg = buttonBgDisabled
        } else if state == .on {
            bg = buttonBgOn
        } else {
            bg = buttonBgOff
        }
        adaptiveButtonTrackingArea = NSTrackingArea(
            rect: visibleRect,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(adaptiveButtonTrackingArea!)

        display?.$adaptive
            .receive(on: dataPublisherQueue)
            .sink { [unowned self] newAdaptive in
                guard let display = self.display else { return }
                mainThread {
                    if !isEnabled {
                        self.bg = buttonBgDisabled
                        self.state = newAdaptive ? .on : .off
                    } else if newAdaptive {
                        self.bg = buttonBgOn
                        self.state = .on
                    } else {
                        self.bg = buttonBgOff
                        self.state = .off
                    }
                }
                display.readapt(newValue: newAdaptive, oldValue: display.adaptive)
            }
            .store(in: &displayObservers, for: "adaptive")
    }

    override func mouseDown(with _: NSEvent) {
        guard isEnabled else { return }
        switch state {
        case .on:
            refresh(adaptive: false)
        case .off:
            refresh(adaptive: true)
        default:
            return
        }
    }

    func refresh(adaptive: Bool) {
        guard isEnabled else {
            bg = buttonBgDisabled
            return
        }

        if adaptive {
            bg = buttonBgOn
            display?.adaptive = true
        } else {
            bg = buttonBgOff
            display?.adaptive = false
        }
    }

    override func mouseEntered(with _: NSEvent) {
        guard isEnabled else { return }
        transition(0.2)

        if state == .on {
            bg = buttonBgOnHover
        } else {
            bg = buttonBgOffHover
        }
    }

    override func mouseExited(with _: NSEvent) {
        setColor()
    }

    func setColor() {
        transition(0.4)
        guard isEnabled else {
            bg = buttonBgDisabled
            return
        }

        if state == .on {
            bg = buttonBgOn
        } else {
            bg = buttonBgOff
        }
    }
}
