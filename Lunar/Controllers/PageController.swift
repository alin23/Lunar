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

extension AppDelegate: NSPageControllerDelegate {
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
                hideSwipeToHotkeysHint()
                hideSwipeLeftHint(c: c)
                splitViewController.mauveBackground()
            } else if c.selectedIndex == 1 {
                hideSwipeLeftHint(c: c)
                splitViewController.yellowBackground()
                if let settingsController = viewController as? SettingsPageController {
                    settingsController.initGraph(display: brightnessAdapter.firstDisplay)
                }
            } else {
                if c.selectedIndex > 2 {
                    hideSwipeRightHint(c: c)
                }

                splitViewController.whiteBackground()
                if c.selectedIndex == c.pageControl.numberOfPages - 1 {
                    splitViewController.lastPage()
                }

                if let displayController = viewController as? DisplayViewController {
                    displayController.initGraph()
                }
            }
            for object in c.arrangedObjects {
                let otherIdentifier = pageController(c, identifierFor: object)
                if identifier == otherIdentifier {
                    continue
                }
                let viewController = pageController(c, viewControllerForIdentifier: otherIdentifier)
                if (viewController as? HotkeyViewController) != nil {
                    continue
                } else if let viewController = viewController as? SettingsPageController {
                    viewController.zeroGraph()
                } else if let viewController = viewController as? DisplayViewController {
                    viewController.zeroGraph()
                }
            }
        }
        c.pageControl?.currentPage = c.selectedIndex
    }

    func pageController(_: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier {
        if let identifier = object as? NSPageController.ObjectIdentifier {
            return identifier
        }
        return NSPageController.ObjectIdentifier(String(describing: (object as! Display).id))
    }

    func pageController(
        _ c: NSPageController,
        viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier
    ) -> NSViewController {
        unowned let c = c as! PageController

        if c.viewControllers[identifier] == nil {
            if identifier == c.hotkeyViewControllerIdentifier {
                c.viewControllers[identifier] = c.storyboard!
                    .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("hotkeyViewController")) as! HotkeyViewController
            } else if identifier == c.settingsPageControllerIdentifier {
                c.viewControllers[identifier] = c.storyboard!
                    .instantiateController(
                        withIdentifier: NSStoryboard
                            .SceneIdentifier("settingsPageController")
                    ) as! SettingsPageController
            } else {
                c.viewControllers[identifier] = c.storyboard!
                    .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("displayViewController")) as! DisplayViewController
            }
        }

        if let displayController = c.viewControllers[identifier] as? DisplayViewController,
           let displayId = CGDirectDisplayID(identifier)
        {
            if displayId == TEST_DISPLAY_ID {
                displayController.display = TEST_DISPLAY()
            } else if displayId != GENERIC_DISPLAY.id {
                displayController.display = brightnessAdapter.displays[displayId]
            } else {
                displayController.display = GENERIC_DISPLAY
            }
            if let display = c.arrangedObjects[2] as? Display, display.id == displayId {
                displayController.swipeLeftHint?.isHidden = Defaults[.didSwipeLeft]
                displayController.swipeRightHint?.isHidden = Defaults[.didSwipeRight] || c.arrangedObjects.count <= 3
            }
        }

        return c.viewControllers[identifier]!
    }

    func hideSwipeToHotkeysHint() {
        if !Defaults[.didSwipeToHotkeys] {
            Defaults[.didSwipeToHotkeys] = true
        }
    }

    func hideSwipeLeftHint(c: NSPageController) {
        if !Defaults[.didSwipeLeft] {
            Defaults[.didSwipeLeft] = true
            if let display = c.arrangedObjects[2] as? Display {
                let identifier = pageController(c, identifierFor: display)
                if let c = pageController(c, viewControllerForIdentifier: identifier) as? DisplayViewController {
                    c.swipeLeftHint?.isHidden = true
                }
            }
        }
    }

    func hideSwipeRightHint(c: NSPageController) {
        if !Defaults[.didSwipeRight] {
            Defaults[.didSwipeRight] = true
            if let display = c.arrangedObjects[2] as? Display {
                let identifier = pageController(c, identifierFor: display)
                if let c = pageController(c, viewControllerForIdentifier: identifier) as? DisplayViewController {
                    c.swipeRightHint?.isHidden = true
                }
            }
        }
    }
}

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
        delegate = appDelegate()

        arrangedObjects = [hotkeyViewControllerIdentifier, settingsPageControllerIdentifier]
        let activeDisplays = brightnessAdapter.activeDisplays
        if !activeDisplays.isEmpty {
            let displays: [Any] = activeDisplays.values.sorted(by: { (d1, d2) -> Bool in
                d1.serial < d2.serial
            })
            arrangedObjects.append(contentsOf: displays)
        } else {
            if TEST_MODE {
                arrangedObjects.append(TEST_DISPLAY())
            }
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

    func setupHotkeys() {
        log.debug("Setting up left and right arrow keys")

        disableLeftRightHotkeys()
        if let leftKeyCombo = KeyCombo(key: .leftArrow, cocoaModifiers: .shift),
           let rightKeyCombo = KeyCombo(key: .rightArrow, cocoaModifiers: .shift)
        {
            leftHotkey = Magnet.HotKey(
                identifier: "navigateBack",
                keyCombo: leftKeyCombo,
                target: self,
                action: #selector(navigateBack(_:))
            )
            rightHotkey = Magnet.HotKey(
                identifier: "navigateForward",
                keyCombo: rightKeyCombo,
                target: self,
                action: #selector(navigateForward(_:))
            )

            leftHotkey?.register()
            rightHotkey?.register()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupHotkeys()
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}
