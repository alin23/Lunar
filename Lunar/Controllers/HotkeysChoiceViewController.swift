//
//  HotkeysChoiceViewController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 01.10.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Defaults
import UserNotifications

// MARK: - OnboardingDisplayCellView

class OnboardingDisplayCellView: NSTableCellView {
    @IBOutlet var syncButton: LockButton!
    @IBOutlet var _controlButton: NSButton!

    override var objectValue: Any? {
        didSet {
            setup()
        }
    }

    var display: Display? { objectValue as? Display }

    var controlButton: HelpButton? { _controlButton as? HelpButton }

    func setup() {
        mainThread {
            guard let display = display, let button = controlButton, let syncButton = syncButton else { return }

            syncButton.isHidden = CachedDefaults[.adaptiveBrightnessMode] != .sync

            button.bg = .clear
            switch display.controlResult.type {
            case .appleNative:
                button.attributedTitle = "Supports Apple Native Protocol".withTextColor(green)
                button.helpText = NATIVE_CONTROLS_HELP_TEXT
            case .ddc:
                // button.bg = peach
                button.attributedTitle = "Supports DDC Protocol".withTextColor(peach)
                button.helpText = HARDWARE_CONTROLS_HELP_TEXT
            case .network:
                // button.bg = blue.highlight(withLevel: 0.2)
                button.attributedTitle = "Supports DDC-over-Network Protocol".withTextColor(blue.highlight(withLevel: 0.2) ?? blue)
                button.helpText = NETWORK_CONTROLS_HELP_TEXT
            case .gamma:
                // button.bg = red
                if display.supportsGamma {
                    button.attributedTitle = "Supports Gamma Dimming".withTextColor(red)
                    button.helpText = SOFTWARE_CONTROLS_HELP_TEXT
                } else {
                    button.attributedTitle = "Supports Overlay Dimming".withTextColor(red)
                    button.helpText = SOFTWARE_OVERLAY_HELP_TEXT
                }
            default:
                break
            }

            button.isEnabled = true
            button.isHidden = false
        }
    }
}

// MARK: - HotkeysChoiceViewController

class HotkeysChoiceViewController: NSViewController {
    var cancelled = false

    @IBOutlet var skipButton: Button!

    @objc dynamic var displays: [Display] = []
    var didAppear = false

    override func viewDidAppear() {
        guard !didAppear else { return }
        didAppear = true

        uiCrumb("\(useOnboardingForDiagnostics ? "Diagnostics" : "Onboarding") Summary")
        displays = displayController.activeDisplays.values.map { $0 }
        if let wc = view.window?.windowController as? OnboardWindowController {
            wc.setupSkipButton(skipButton, color: peach, text: useOnboardingForDiagnostics ? "Complete Diagnostics" : nil) {
                guard useOnboardingForDiagnostics else { return }

                mainAsync {
                    self.view.window?.close()
                    if adaptiveModeDisabledByDiagnostics {
                        displayController.enable()
                    }
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func next() {
        guard let wc = view.window?.windowController as? OnboardWindowController else { return }
        wc.pageController?.navigateForward(self)
    }

    @IBAction func requestAccessibilityPermissions(_: Any) {
        guard !CachedDefaults[.brightnessKeysEnabled], !CachedDefaults[.volumeKeysEnabled] else {
            appDelegate!.startOrRestartMediaKeyTap(checkPermissions: true)
            return
        }
        acquirePrivileges(
            notificationTitle: "Lunar got Accessibility Permissions",
            notificationBody: "Brightness/volume keys and app presets are now available to be used in Lunar"
        )
    }

    @IBAction func requestNotificationPermissions(_: Any) {
        let nc = UNUserNotificationCenter.current()
        nc.requestAuthorization(options: [.alert, .provisional], completionHandler: { granted, _ in
            mainAsync { Defaults[.notificationsPermissionsGranted] = granted }
        })
    }

    @IBAction func installCLI(_ sender: Button) {
        do {
            try installCLIBinary()
        } catch let error as InstallCLIError {
            sender.alternateTitle = error.message
            sender.isEnabled = false
        } catch {
            sender.alternateTitle = "Installation failed"
            sender.isEnabled = false
        }
    }
}
