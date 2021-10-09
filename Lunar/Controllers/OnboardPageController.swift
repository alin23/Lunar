//
//  OnboardPageController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 01.10.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Foundation

// MARK: - OnboardPageController

class OnboardPageController: NSPageController {
    @IBOutlet var logo: NSTextField?

    let modeChoiceViewControllerIdentifier = NSPageController.ObjectIdentifier("modeChoiceViewController")
    let controlChoiceViewControllerIdentifier = NSPageController.ObjectIdentifier("controlChoiceViewController")
    let hotkeysChoiceViewControllerIdentifier = NSPageController.ObjectIdentifier("hotkeysChoiceViewController")
    var viewControllers: [NSPageController.ObjectIdentifier: NSViewController] = [:]

    func setup() {
        delegate = self
        transitionStyle = .horizontalStrip

        view.wantsLayer = true
        view.radius = 12.0.ns
        view.bg = blackMauve
        logo?.textColor = logoColor

        arrangedObjects = [modeChoiceViewControllerIdentifier, controlChoiceViewControllerIdentifier, hotkeysChoiceViewControllerIdentifier]
        selectedIndex = 0
        completeTransition()
        view.setNeedsDisplay(view.rectForPage(selectedIndex))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func scrollWheel(with _: NSEvent) {}
}

// MARK: NSPageControllerDelegate

extension OnboardPageController: NSPageControllerDelegate {
    func pageController(_: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier {
        object as! NSPageController.ObjectIdentifier
    }

    func pageController(
        _ c: NSPageController,
        viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier
    ) -> NSViewController {
        unowned let c = c as! OnboardPageController

        guard c.viewControllers[identifier] == nil else {
            return c.viewControllers[identifier]!
        }

        if identifier == c.modeChoiceViewControllerIdentifier, let controller = c.storyboard!
            .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(identifier)) as? ModeChoiceViewController
        {
            c.viewControllers[identifier] = controller
        } else if identifier == c.controlChoiceViewControllerIdentifier, let controller = c.storyboard!
            .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(identifier)) as? ControlChoiceViewController
        {
            c.viewControllers[identifier] = controller
        } else if identifier == c.hotkeysChoiceViewControllerIdentifier, let controller = c.storyboard!
            .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(identifier)) as? HotkeysChoiceViewController
        {
            c.viewControllers[identifier] = controller
        }

        return c.viewControllers[identifier]!
    }
}
