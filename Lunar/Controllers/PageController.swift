//
//  PageController.swift
//  Lunar
//
//  Created by Alin on 30/11/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Carbon.HIToolbox
import Cocoa
import Defaults
import Foundation
import Magnet

// MARK: - PageController

final class PageController: NSPageController {
    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            do { log.verbose("END DEINIT") }
        #endif
    }

    let hotkeyViewControllerIdentifier = NSPageController.ObjectIdentifier("Hotkeys")
    let settingsPageControllerIdentifier = NSPageController.ObjectIdentifier("Configuration")
    var viewControllers: [NSPageController.ObjectIdentifier: NSViewController] = [:]

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    func select(index: Int) {
        NSAnimationContext.runAnimationGroup({ _ in animator().selectedIndex = index }) { [weak self] in
            self?.completeTransition()
        }
    }

    func setup() {
        delegate = self

        arrangedObjects = [hotkeyViewControllerIdentifier, settingsPageControllerIdentifier]
        if CachedDefaults[.showDisconnectedDisplays], !displayController.displays.isEmpty {
            let builtinActiveDisplays: [Any] = displayController.builtinActiveDisplays
                .sorted(by: { d1, d2 -> Bool in d1.serial < d2.serial })
            let externalActiveDisplays: [Any] = displayController.externalActiveDisplays
                .sorted(by: { d1, d2 -> Bool in d1.serial < d2.serial })
            let builtinDisconnectedDisplays: [Any] = displayController.builtinDisplays
                .filter { !$0.active }
                .sorted(by: { d1, d2 -> Bool in d1.serial < d2.serial })
            let externalDisconnectedDisplays: [Any] = displayController.externalDisplays
                .filter { !$0.active }
                .sorted(by: { d1, d2 -> Bool in d1.serial < d2.serial })
            arrangedObjects
                .append(
                    contentsOf: externalActiveDisplays + builtinActiveDisplays + externalDisconnectedDisplays +
                        builtinDisconnectedDisplays
                )
        } else if !displayController.activeDisplays.isEmpty {
            let builtinDisplays: [Any] = displayController.builtinActiveDisplays
                .sorted(by: { d1, d2 -> Bool in d1.serial < d2.serial })
            let externalDisplays: [Any] = displayController.externalActiveDisplays
                .sorted(by: { d1, d2 -> Bool in d1.serial < d2.serial })
            arrangedObjects.append(contentsOf: externalDisplays + builtinDisplays)
            // } else if TEST_MODE {
            //     let builtinDisplays: [Any] = displayController.builtinDisplays
            //         .sorted(by: { d1, d2 -> Bool in d1.serial < d2.serial })
            //     let externalDisplays: [Any] = displayController.externalDisplays
            //         .sorted(by: { d1, d2 -> Bool in d1.serial < d2.serial })
            //     let displays = externalDisplays + builtinDisplays
            //     arrangedObjects.append(contentsOf: displays.isEmpty ? [GENERIC_DISPLAY] : displays.map { $0 })
        } else {
            arrangedObjects.append(GENERIC_DISPLAY)
        }

        selectedIndex = appDelegate!.currentPage

        if let splitViewController = parent as? SplitViewController {
            splitViewController.pageController = self

            switch selectedIndex {
            case 0:
                splitViewController.hotkeysPage()
            case 1:
                splitViewController.configurationPage()
            case arrangedObjects.count - 1:
                splitViewController.lastPage()
            default:
                splitViewController.displayPage()
            }

            splitViewController.onLeftButtonPress = { [weak self] in
                self?.navigateBack(nil)
            }
            splitViewController.onRightButtonPress = { [weak self] in
                self?.navigateForward(nil)
            }
        }

        completeTransition()
        view.setNeedsDisplay(view.rectForPage(selectedIndex))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
}

// MARK: NSPageControllerDelegate

extension PageController: NSPageControllerDelegate {
    func pageControllerWillStartLiveTransition(_: NSPageController) {
        #if DEBUG
//            log.verbose("Will start live transition")
        #endif
        for popover in POPOVERS.values {
            popover?.close()
        }
    }

    func pageControllerDidEndLiveTransition(_ c: NSPageController) {
        #if DEBUG
            log.verbose("Did end live transition")
        #endif
        guard let c = c as? PageController else { return }

        c.completeTransition()

        guard let splitViewController = c.parent as? SplitViewController else {
            return
        }

        appDelegate!.currentPage = c.selectedIndex

        switch c.selectedIndex {
        case 0:
            splitViewController.hotkeysPage()
        case 1:
            splitViewController.configurationPage()
        case arrangedObjects.count - 1:
            splitViewController.lastPage()
        default:
            splitViewController.displayPage()
        }
    }

    func pageController(_: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier {
        if let identifier = object as? NSPageController.ObjectIdentifier {
            return identifier
        }
        return NSPageController.ObjectIdentifier((object as! Display).serial)
    }

    func pageController(
        _ c: NSPageController,
        viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier
    ) -> NSViewController {
        unowned let c = c as! PageController

        if c.viewControllers[identifier] == nil {
            switch identifier {
            case c.hotkeyViewControllerIdentifier:
                c.viewControllers[identifier] = c.storyboard!
                    .instantiateController(
                        withIdentifier: NSStoryboard.SceneIdentifier("hotkeyViewController")
                    ) as! HotkeyViewController
            case c.settingsPageControllerIdentifier:
                c.viewControllers[identifier] = c.storyboard!
                    .instantiateController(
                        withIdentifier: NSStoryboard.SceneIdentifier("settingsPageController")
                    ) as! SettingsPageController
            default:
                c.viewControllers[identifier] = c.storyboard!
                    .instantiateController(
                        withIdentifier: NSStoryboard.SceneIdentifier("displayViewController")
                    ) as! DisplayViewController
            }
        }

        if let displayViewController = c.viewControllers[identifier] as? DisplayViewController {
            if displayViewController.display == nil {
                #if DEBUG
                    switch identifier {
                    case TEST_DISPLAY.serial:
                        displayViewController.display = TEST_DISPLAY
                    case TEST_DISPLAY_PERSISTENT.serial:
                        displayViewController.display = TEST_DISPLAY_PERSISTENT
                    case TEST_DISPLAY_PERSISTENT2.serial:
                        displayViewController.display = TEST_DISPLAY_PERSISTENT2
                    case TEST_DISPLAY_PERSISTENT3.serial:
                        displayViewController.display = TEST_DISPLAY_PERSISTENT3
                    case TEST_DISPLAY_PERSISTENT4.serial:
                        displayViewController.display = TEST_DISPLAY_PERSISTENT4
                    case GENERIC_DISPLAY.serial:
                        displayViewController.display = GENERIC_DISPLAY
                    default:
                        displayViewController.display = displayController.displays.values.first(where: { $0.serial == identifier })
                    }
                #else
                    if !isGeneric(serial: identifier) {
                        displayViewController.display = displayController.displays.values.first(where: { $0.serial == identifier })
                    } else {
                        displayViewController.display = GENERIC_DISPLAY
                    }
                #endif
            }
        }

        return c.viewControllers[identifier]!
    }
}
