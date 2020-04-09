//
//  ModernWindowController.swift
//  Lunar
//
//  Created by Alin on 04/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import CoreLocation
import Magnet

extension AppDelegate: NSWindowDelegate {
    func windowDidBecomeMain(_: Notification) {
        if #available(OSX 10.15, *) {
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined, .restricted, .denied:
                log.debug("Requesting location permissions")
                locationManager.requestAlwaysAuthorization()
            case .authorizedAlways:
                log.debug("Location authorized")
            @unknown default:
                log.debug("Location status unknown")
            }
        }
    }

    func windowWillClose(_: Notification) {
        log.info("Window closing")

        log.debug("Unregistering up/down hotkeys")
        HotKeyCenter.shared.unregisterHotKey(with: "increaseValue")
        HotKeyCenter.shared.unregisterHotKey(with: "decreaseValue")
        upHotkey?.unregister()
        downHotkey?.unregister()
        upHotkey = nil
        downHotkey = nil

        setupHotkeys(enable: false)
    }
}

class ModernWindowController: NSWindowController {
    func initHelpPopover() {
        if helpPopover.contentViewController == nil, let stb = storyboard,
            let controller = stb.instantiateController(
                withIdentifier: NSStoryboard.SceneIdentifier("HelpPopoverController")
            ) as? HelpPopoverController {
            helpPopover.contentViewController = controller
            helpPopover.contentViewController!.loadView()
        }
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        setupWindow()
        initHelpPopover()
    }

    func setupWindow() {
        if let w = window as? ModernWindow {
            w.delegate = appDelegate()
            w.setup()
        } else {
            log.warning("No window found")
        }
    }
}
