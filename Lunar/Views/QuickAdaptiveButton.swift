import Cocoa
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
        layer?.cornerRadius = frame.height / 2

        if let adaptive = display?.adaptive {
            if adaptive {
                state = .on
            } else {
                state = .off
            }
        }

        if state == .on {
            layer?.backgroundColor = buttonBgOn.cgColor
        } else {
            layer?.backgroundColor = buttonBgOff.cgColor
        }
        adaptiveButtonTrackingArea = NSTrackingArea(
            rect: visibleRect,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(adaptiveButtonTrackingArea!)

        adaptiveObserver = { [unowned self] newAdaptive, oldValue in
            if let display = self.display {
                runInMainThread {
                    if newAdaptive {
                        self.layer?.backgroundColor = buttonBgOn.cgColor
                        self.state = .on
                    } else {
                        self.layer?.backgroundColor = buttonBgOff.cgColor
                        self.state = .off
                    }
                    display.readapt(newValue: newAdaptive, oldValue: oldValue)
                }
            }
        }
        display?.setObserver(prop: "adaptive", key: "quickAdaptiveButton-\(accessibilityIdentifier())", action: adaptiveObserver!)
    }

    deinit {
        display?.resetObserver(prop: "adaptive", key: "quickAdaptiveButton-\(self.accessibilityIdentifier())", type: Bool.self)
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
            layer?.backgroundColor = buttonBgOn.cgColor
            display?.adaptive = true
        } else {
            layer?.backgroundColor = buttonBgOff.cgColor
            display?.adaptive = false
        }
    }

    override func mouseEntered(with _: NSEvent) {
        layer?.add(fadeTransition(duration: 0.1), forKey: "transition")

        if state == .on {
            layer?.backgroundColor = buttonBgOnHover.cgColor
        } else {
            layer?.backgroundColor = buttonBgOffHover.cgColor
        }
    }

    override func mouseExited(with _: NSEvent) {
        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")

        if state == .on {
            layer?.backgroundColor = buttonBgOn.cgColor
        } else {
            layer?.backgroundColor = buttonBgOff.cgColor
        }
    }
}
