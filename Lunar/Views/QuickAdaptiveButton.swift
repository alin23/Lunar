import Cocoa
import Combine
import Foundation

let buttonBgOn = sunYellow
let buttonBgOnHover = buttonBgOn.blended(withFraction: 0.2, of: red) ?? buttonBgOn
let buttonLabelOn = darkMauve
let buttonBgOff = gray
let buttonBgOffHover = buttonBgOn
let buttonLabelOff = darkMauve

class QuickAdaptiveButton: NSButton {
    var adaptiveButtonTrackingArea: NSTrackingArea?
    var adaptiveObserver: ((Bool, Bool) -> Void)?
    var displayID: CGDirectDisplayID?
    weak var display: Display? {
        guard let id = displayID else { return nil }
        return displayController.displays[id]
    }

    var displayObservers = Set<AnyCancellable>()

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

        if state == .on {
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

        display?.$adaptive.sink { [unowned self] newAdaptive in
            if let display = self.display {
                mainThread {
                    if newAdaptive {
                        self.bg = buttonBgOn
                        self.state = .on
                    } else {
                        self.bg = buttonBgOff
                        self.state = .off
                    }
                    display.readapt(newValue: newAdaptive, oldValue: display.adaptive)
                }
            }
        }.store(in: &displayObservers)
    }

    deinit {
        for observer in displayObservers {
            observer.cancel()
        }
    }

    override func mouseDown(with _: NSEvent) {
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
        if adaptive {
            bg = buttonBgOn
            display?.adaptive = true
        } else {
            bg = buttonBgOff
            display?.adaptive = false
        }
    }

    override func mouseEntered(with _: NSEvent) {
        layer?.add(fadeTransition(duration: 0.1), forKey: "transition")

        if state == .on {
            bg = buttonBgOnHover
        } else {
            bg = buttonBgOffHover
        }
    }

    override func mouseExited(with _: NSEvent) {
        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")

        if state == .on {
            bg = buttonBgOn
        } else {
            bg = buttonBgOff
        }
    }
}
