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

class PageController: NSPageController {
    var pageControl: PageControl!

    override var arrangedObjects: [Any] {
        didSet {
            pageControl?.numberOfPages = arrangedObjects.count
        }
    }

    let hotkeyViewControllerIdentifier = NSPageController.ObjectIdentifier("hotkey")
    let settingsPageControllerIdentifier = NSPageController.ObjectIdentifier("settings")
    var viewControllers: [NSPageController.ObjectIdentifier: NSViewController] = [:]

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            do { log.verbose("END DEINIT") }
        #endif
    }

    private func setupPageControl(size: Int) {
        let width: CGFloat = 300
        let x: CGFloat = (view.frame.width - width) / 2

        let frame = NSRect(x: x, y: 20, width: width, height: 20)
        pageControl = PageControl(
            frame: frame,
            numberOfPages: size,
            hidesForSinglePage: true,
            tintColor: pageIndicatorTintColor,
            currentTintColor: currentPageIndicatorTintColor
        )
        if !view.subviews.contains(pageControl) {
            view.addSubview(pageControl)
        }

        pageControl.setNeedsDisplay(pageControl.frame)
    }

    func setup() {
        delegate = self

        arrangedObjects = [hotkeyViewControllerIdentifier, settingsPageControllerIdentifier]
        let activeDisplays = displayController.activeDisplays
        if !activeDisplays.isEmpty {
            let displays: [Any] = activeDisplays.values.sorted(by: { d1, d2 -> Bool in
                d1.serial < d2.serial
            })
            arrangedObjects.append(contentsOf: displays)
        } else if TEST_MODE {
            let displays: [Any] = displayController.displays.values.sorted(by: { d1, d2 -> Bool in
                d1.serial < d2.serial
            })
            arrangedObjects.append(contentsOf: displays.isEmpty ? [GENERIC_DISPLAY] : displays.map { $0 })
        } else {
            arrangedObjects.append(GENERIC_DISPLAY)
        }

        setupPageControl(size: arrangedObjects.count)
        if let splitViewController = parent as? SplitViewController {
            splitViewController.onLeftButtonPress = { [weak self] in
                self?.navigateBack(nil)
            }
            splitViewController.onRightButtonPress = { [weak self] in
                self?.navigateForward(nil)
            }
            if pageControl.numberOfPages == 3 {
                splitViewController.lastPage()
            }
        }

        selectedIndex = 2

        completeTransition()
        view.setNeedsDisplay(view.rectForPage(selectedIndex))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}

extension PageController: NSPageControllerDelegate {
    func pageControllerWillStartLiveTransition(_: NSPageController) {
        for popover in POPOVERS.values {
            popover?.close()
        }
    }

    func pageControllerDidEndLiveTransition(_ c: NSPageController) {
        guard let c = c as? PageController else { return }

        if let splitViewController = c.parent as? SplitViewController {
            let identifier = pageController(c, identifierFor: c.arrangedObjects[c.selectedIndex])
            let viewController = pageController(c, viewControllerForIdentifier: identifier)
            if c.selectedIndex == 0 {
                splitViewController.mauveBackground()
            } else if c.selectedIndex == 1 {
                splitViewController.yellowBackground()
            } else {
                splitViewController.whiteBackground()
                if c.selectedIndex == c.pageControl.numberOfPages - 1 {
                    splitViewController.lastPage()
                }

                // if let displayController = viewController as? DisplayViewController {
                //     displayController.initGraph()
                // }
            }
            // for object in c.arrangedObjects {
            //     let otherIdentifier = pageController(c, identifierFor: object)
            //     if identifier == otherIdentifier {
            //         continue
            //     }
            //     let viewController = pageController(c, viewControllerForIdentifier: otherIdentifier)
            //     if (viewController as? HotkeyViewController) != nil {
            //         continue
            //     } else if let viewController = viewController as? DisplayViewController {
            //         viewController.zeroGraph()
            //     }
            // }
        }
        c.pageControl?.currentPage = c.selectedIndex
    }

    func pageController(_: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier {
        if let identifier = object as? NSPageController.ObjectIdentifier {
            return identifier
        }
        return NSPageController.ObjectIdentifier(String(describing: (object as! Display).serial))
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
                    .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("hotkeyViewController")) as! HotkeyViewController
            case c.settingsPageControllerIdentifier:
                c.viewControllers[identifier] = c.storyboard!
                    .instantiateController(
                        withIdentifier: NSStoryboard
                            .SceneIdentifier("settingsPageController")
                    ) as! SettingsPageController
            default:
                c.viewControllers[identifier] = c.storyboard!
                    .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("displayViewController")) as! DisplayViewController
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
