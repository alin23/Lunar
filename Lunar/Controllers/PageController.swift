//
//  PageController.swift
//  Lunar
//
//  Created by Alin on 30/11/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Carbon.HIToolbox
import Cocoa
import Foundation
import Magnet

class PageController: NSPageController, NSPageControllerDelegate {
    var pageControl: PageControl!

    override var arrangedObjects: [Any] {
        didSet {
            pageControl?.numberOfPages = arrangedObjects.count
        }
    }

    let hotkeyViewControllerIdentifier: NSPageController.ObjectIdentifier = NSPageController.ObjectIdentifier("hotkey")
    let settingsPageControllerIdentifier: NSPageController.ObjectIdentifier = NSPageController.ObjectIdentifier("settings")
    var viewControllers: [NSPageController.ObjectIdentifier: NSViewController] = [:]

    private func setupPageControl(size: Int) {
        let width: CGFloat = 300
        let x: CGFloat = (view.frame.width - width) / 2

        let frame = NSRect(x: x, y: 20, width: width, height: 20)
        pageControl = PageControl(frame: frame, numberOfPages: size, hidesForSinglePage: true, tintColor: pageIndicatorTintColor, currentTintColor: currentPageIndicatorTintColor)
        if !view.subviews.contains(pageControl) {
            view.addSubview(pageControl)
        }

        pageControl.setNeedsDisplay(pageControl.frame)
    }

    func setup() {
        delegate = self

        arrangedObjects = [hotkeyViewControllerIdentifier, settingsPageControllerIdentifier]
        if !brightnessAdapter.displays.isEmpty {
            let displays: [Any] = brightnessAdapter.displays.values.sorted(by: { (d1, d2) -> Bool in
                d1.active && !d2.active
            })
            arrangedObjects.append(contentsOf: displays)
        } else {
            if TEST_MODE {
                arrangedObjects.append(TEST_DISPLAY)
            }
            arrangedObjects.append(GENERIC_DISPLAY)
        }

        setupPageControl(size: arrangedObjects.count)
        selectedIndex = 2
        completeTransition()
        view.setNeedsDisplay(view.rectForPage(selectedIndex))
    }

    func setupHotkeys(enable: Bool) {
        log.debug("Setting up left and right arrow keys")

        if enable {
            leftHotkey?.unregister()
            rightHotkey?.unregister()

            leftHotkey = Magnet.HotKey(identifier: "navigateBack", keyCombo: KeyCombo(keyCode: kVK_LeftArrow, carbonModifiers: 0)!, target: self, action: #selector(navigateBack(_:)))
            rightHotkey = Magnet.HotKey(identifier: "navigateForward", keyCombo: KeyCombo(keyCode: kVK_RightArrow, carbonModifiers: 0)!, target: self, action: #selector(navigateForward(_:)))

            leftHotkey?.register()
            rightHotkey?.register()
        } else {
            leftHotkey?.unregister()
            rightHotkey?.unregister()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupHotkeys(enable: true)
    }

    func hideSwipeToHotkeysHint() {
        if !datastore.defaults.didSwipeToHotkeys {
            datastore.defaults.set(true, forKey: "didSwipeToHotkeys")
        }
    }

    func hideSwipeLeftHint() {
        if !datastore.defaults.didSwipeLeft {
            datastore.defaults.set(true, forKey: "didSwipeLeft")
            if let display = arrangedObjects[2] as? Display {
                let identifier = pageController(self, identifierFor: display)
                if let controller = pageController(self, viewControllerForIdentifier: identifier) as? DisplayViewController {
                    controller.swipeLeftHint?.isHidden = true
                }
            }
        }
    }

    func hideSwipeRightHint() {
        if !datastore.defaults.didSwipeRight {
            datastore.defaults.set(true, forKey: "didSwipeRight")
            if let display = arrangedObjects[2] as? Display {
                let identifier = pageController(self, identifierFor: display)
                if let controller = pageController(self, viewControllerForIdentifier: identifier) as? DisplayViewController {
                    controller.swipeRightHint?.isHidden = true
                }
            }
        }
    }

    func pageControllerWillStartLiveTransition(_: NSPageController) {
        helpPopover.close()
    }

    func pageControllerDidEndLiveTransition(_: NSPageController) {
        if let splitViewController = parent as? SplitViewController {
            let identifier = pageController(self, identifierFor: arrangedObjects[selectedIndex])
            let viewController = pageController(self, viewControllerForIdentifier: identifier)
            if selectedIndex == 0 {
                hideSwipeToHotkeysHint()
                hideSwipeLeftHint()
                splitViewController.mauveBackground()
            } else if selectedIndex == 1 {
                hideSwipeLeftHint()
                splitViewController.yellowBackground()
                if let settingsController = viewController as? SettingsPageController {
                    settingsController.initGraph(display: brightnessAdapter.firstDisplay)
                }
            } else {
                if selectedIndex > 2 {
                    hideSwipeRightHint()
                }
                splitViewController.whiteBackground()
                if let displayController = viewController as? DisplayViewController {
                    displayController.initGraph()
                }
            }
            for object in arrangedObjects {
                let otherIdentifier = pageController(self, identifierFor: object)
                if identifier == otherIdentifier {
                    continue
                }
                let controller = pageController(self, viewControllerForIdentifier: otherIdentifier)
                if (controller as? HotkeyViewController) != nil {
                    continue
                } else if let c = controller as? SettingsPageController {
                    c.zeroGraph()
                } else {
                    (controller as! DisplayViewController).zeroGraph()
                }
            }
        }
        pageControl?.currentPage = selectedIndex
    }

    func pageController(_: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier {
        if let identifier = object as? NSPageController.ObjectIdentifier {
            return identifier
        }
        return NSPageController.ObjectIdentifier(String(describing: (object as! Display).id))
    }

    func pageController(_: NSPageController, viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier) -> NSViewController {
        if viewControllers[identifier] == nil {
            if identifier == hotkeyViewControllerIdentifier {
                viewControllers[identifier] = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("hotkeyViewController")) as! HotkeyViewController
            } else if identifier == settingsPageControllerIdentifier {
                let settingsPageController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("settingsPageController")) as! SettingsPageController
                settingsPageController.pageController = self
                viewControllers[identifier] = settingsPageController
            } else {
                viewControllers[identifier] = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("displayViewController")) as! DisplayViewController
            }
        }

        if let controller = viewControllers[identifier] as? DisplayViewController,
            let displayId = CGDirectDisplayID(identifier) {
            if displayId == TEST_DISPLAY.id {
                controller.display = TEST_DISPLAY
            } else if displayId != GENERIC_DISPLAY.id {
                controller.display = brightnessAdapter.displays[displayId]
            } else {
                controller.display = GENERIC_DISPLAY
            }
            if let display = arrangedObjects[2] as? Display, display.id == displayId {
                controller.swipeLeftHint?.isHidden = datastore.defaults.didSwipeLeft
                controller.swipeRightHint?.isHidden = datastore.defaults.didSwipeRight || arrangedObjects.count <= 3
            }
        }

        return viewControllers[identifier]!
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}
