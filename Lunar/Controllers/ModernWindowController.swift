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
                locationManager?.requestAlwaysAuthorization()
            case .authorizedAlways:
                log.debug("Location authorized")
            @unknown default:
                log.debug("Location status unknown")
            }
        }
    }

    func windowWillClose(_ n: Notification) {
        log.info("Window closing")

        disableUIHotkeys()

        if let window = n.object as? ModernWindow {
            log.debug("Got window while closing: \(window)")
            guard let pageController = window.contentView?.subviews[0].subviews[0].nextResponder as? PageController,
                  let settingsPageController = pageController.viewControllers["settings"] as? SettingsPageController,
                  let settingsViewController = settingsPageController.view.subviews[2].subviews[0].nextResponder as? SettingsViewController,
                  let configurationViewController = settingsViewController.splitViewItems[0].viewController as? ConfigurationViewController,
                  let exceptionsViewController = settingsViewController.splitViewItems[1].viewController as? ExceptionsViewController,
                  let tableView = exceptionsViewController.tableView
            else {
                log.debug("No window found while closing")
                return
            }

            configurationViewController.view.subviews.removeAll()
            tableView.removeRows(at: .init(integersIn: 0 ..< tableView.numberOfRows), withAnimation: [])
            exceptionsViewController.view.subviews.removeAll()

            settingsViewController.splitViewItems.removeAll()
            settingsViewController.view.subviews.removeAll()
            for subview in settingsPageController.view.subviews {
                subview.subviews.removeAll()
            }
            settingsPageController.view.subviews.removeAll()

            for (key, controller) in pageController.viewControllers {
                log.verbose("Removing subviews for \(key) controller")
                controller.view.subviews.removeAll()
            }
            pageController.pageControl = nil
            pageController.viewControllers.removeAll()
            pageController.view.subviews.removeAll()

            window.contentViewController = nil
            window.contentView?.subviews.removeAll()
            windowController?.window = nil
            windowController = nil
        }
    }
}

class ModernWindowController: NSWindowController {
    func initPopover<T: NSViewController>(
        _ popoverKey: PopoverKey,
        identifier: String,
        controllerType _: T.Type,
        appearance: NSAppearance.Name = .vibrantLight
    ) {
        if POPOVERS[popoverKey]! == nil {
            POPOVERS[popoverKey] = NSPopover()
        }

        guard let popover = POPOVERS[popoverKey]! else { return }

        if popover.contentViewController == nil, let stb = storyboard,
           let controller = stb.instantiateController(
               withIdentifier: NSStoryboard.SceneIdentifier(identifier)
           ) as? T
        {
            popover.contentViewController = controller
            popover.contentViewController!.loadView()
            popover.appearance = NSAppearance(named: appearance)
        }
    }

    func initPopovers() {
        initPopover(.help, identifier: "HelpPopoverController", controllerType: HelpPopoverController.self)
        initPopover(.hotkey, identifier: "HotkeyPopoverController", controllerType: HotkeyPopoverController.self, appearance: .vibrantDark)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        setupWindow()
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
