//
//  PageController.swift
//  Lunar
//
//  Created by Alin on 30/11/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Foundation
import HotKey

class PageController: NSPageController, NSPageControllerDelegate {
    var pageControl: PageControl!
    var lastSelectedIndex = 0

    override var arrangedObjects: [Any] {
        didSet {
            pageControl?.numberOfPages = arrangedObjects.count
        }
    }

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

    func deleteDisplay() {
        if selectedIndex == 0 {
            if selectedIndex < arrangedObjects.count {
                navigateForward(nil)
            }
        } else {
            navigateBack(nil)
        }
        let displayToDelete = arrangedObjects[selectedIndex] as! Display
        let identifier = NSPageController.ObjectIdentifier(String(describing: displayToDelete.id))
        viewControllers.removeValue(forKey: identifier)
        arrangedObjects.remove(at: selectedIndex)
        datastore.context.delete(displayToDelete)
        datastore.save()
    }

    func setup() {
        delegate = self

        let settingsViewController = viewControllers.values.first
        if settingsViewController != nil {
            viewControllers[settingsPageControllerIdentifier] = settingsViewController!
        }

        arrangedObjects = [datastore]
        if !brightnessAdapter.displays.isEmpty {
            let displays: [Any] = brightnessAdapter.displays.values.sorted(by: { (d1, d2) -> Bool in
                d1.active && !d2.active
            })
            arrangedObjects.append(contentsOf: displays)
        } else {
            arrangedObjects.append(GENERIC_DISPLAY)
        }

        setupPageControl(size: arrangedObjects.count)
        selectedIndex = 1
        completeTransition()
        view.setNeedsDisplay(view.rectForPage(1))
    }

    func setupHotkeys() {
        leftHotkey = HotKey(
            key: .leftArrow,
            modifiers: [],
            keyDownHandler: {
                self.navigateBack(nil)
            }
        )
        rightHotkey = HotKey(
            key: .rightArrow,
            modifiers: [],
            keyDownHandler: {
                self.navigateForward(nil)
            }
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupHotkeys()
    }

    func pageControllerDidEndLiveTransition(_: NSPageController) {
        if let splitViewController = parent as? SplitViewController {
            let identifier = pageController(self, identifierFor: arrangedObjects[selectedIndex])
            let viewController = pageController(self, viewControllerForIdentifier: identifier)
            if selectedIndex == 0 {
                splitViewController.yellowBackground()
                if let settingsController = viewController as? SettingsPageController {
                    settingsController.initGraph(display: brightnessAdapter.firstDisplay)
                }
            } else {
                if !splitViewController.hasWhiteBackground() {
                    splitViewController.whiteBackground()
                }
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
                if let c = controller as? SettingsPageController {
                    c.zeroGraph()
                } else {
                    (controller as! DisplayViewController).zeroGraph()
                }
            }
        }
        pageControl?.currentPage = selectedIndex
    }

    func pageController(_: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier {
        if (object as? DataStore) == datastore {
            return settingsPageControllerIdentifier
        }
        return NSPageController.ObjectIdentifier(String(describing: (object as! Display).id))
    }

    func pageController(_: NSPageController, viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier) -> NSViewController {
        if viewControllers[identifier] == nil {
            if identifier == settingsPageControllerIdentifier {
                viewControllers[identifier] = NSStoryboard.main!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("settingsPageController")) as! SettingsPageController
            } else {
                viewControllers[identifier] = NSStoryboard.main!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("displayViewController")) as! DisplayViewController
            }
        }

        if let controller = viewControllers[identifier] as? DisplayViewController,
            let displayId = CGDirectDisplayID(identifier) {
            if displayId != GENERIC_DISPLAY.id {
                controller.display = brightnessAdapter.displays[displayId]
            } else {
                controller.display = GENERIC_DISPLAY
            }
        }

        return viewControllers[identifier]!
    }

    override func scrollWheel(with event: NSEvent) {
        let lastIndex = arrangedObjects.count - 1
        if arrangedObjects.count > 1 && ((selectedIndex < lastIndex && event.scrollingDeltaX < 0) || (selectedIndex == lastIndex && event.scrollingDeltaX > 0)) {
            super.scrollWheel(with: event)
        }
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}
