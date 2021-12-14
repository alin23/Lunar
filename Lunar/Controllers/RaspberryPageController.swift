//
//  RaspberryPageController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.03.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa

// MARK: - RaspberryPageController

class RaspberryPageController: NSPageController {
    @IBOutlet var logo: NSTextField?

    let sshConnectionViewControllerIdentifier = NSPageController.ObjectIdentifier("sshConnectionViewController")
    let installOutputViewControllerIdentifier = NSPageController.ObjectIdentifier("installOutputViewController")
    var viewControllers: [NSPageController.ObjectIdentifier: NSViewController] = [:]

    func setup() {
        delegate = self
        transitionStyle = .horizontalStrip

        view.wantsLayer = true
        view.radius = 12.0.ns
        view.bg = hotkeysBgColor
        logo?.textColor = logoColor

        arrangedObjects = [sshConnectionViewControllerIdentifier, installOutputViewControllerIdentifier]
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

extension RaspberryPageController: NSPageControllerDelegate {
    func pageController(_: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier {
        object as! NSPageController.ObjectIdentifier
    }

    func pageController(
        _ c: NSPageController,
        viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier
    ) -> NSViewController {
        unowned let c = c as! RaspberryPageController

        guard c.viewControllers[identifier] == nil else {
            return c.viewControllers[identifier]!
        }

        if identifier == c.sshConnectionViewControllerIdentifier, let controller = c.storyboard!
            .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(identifier)) as? SSHConnectionViewController
        {
            c.viewControllers[identifier] = controller
            controller.onInstall = { [weak self] (ssh: SSH) in
                self?.navigateForward(nil)
                if let installOutputController = c
                    .viewControllers[c.installOutputViewControllerIdentifier] as? InstallOutputViewController
                {
                    installOutputController.startInstall(ssh: ssh)
                }
            }
        } else if identifier == c.installOutputViewControllerIdentifier, let controller = c.storyboard!
            .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(identifier)) as? InstallOutputViewController
        {
            c.viewControllers[identifier] = controller
        }

        return c.viewControllers[identifier]!
    }
}
