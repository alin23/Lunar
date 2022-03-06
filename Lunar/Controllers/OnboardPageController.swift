//
//  OnboardPageController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 01.10.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Combine
import Defaults
import Foundation
import Paddle
import UserNotifications

let ONBOARDING_TASK_KEY = "onboarding-task"

// MARK: - OnboardWindowController

class OnboardWindowController: ModernWindowController, NSWindowDelegate {
    var changes: [() -> Void] = []
    weak var pageController: OnboardPageController?

    var clickedSkipButton = false

    var skip: (() -> Void)?

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
    }

    func applyChanges() {
        for change in changes {
            change()
        }
        changes = []
    }

    func windowWillClose(_: Notification) {
        displayController.displays.values.forEach { d in
            d.testWindowController?.close()
            d.testWindowController = nil
        }
        cancelTask(ONBOARDING_TASK_KEY)
        applyChanges()
        appDelegate!.onboardWindowController = nil
        appDelegate!.wakeObserver?.cancel()
        appDelegate!.wakeObserver = nil
        appDelegate!.screenObserver?.cancel()
        appDelegate!.screenObserver = nil

        guard !clickedSkipButton else { return }
        skip?()

        guard !useOnboardingForDiagnostics else { return }
        completeOnboarding()
    }

    func completeOnboarding() {
        completedOnboarding = true
        appDelegate!.showWindow(after: 100)

        mainAsyncAfter(ms: 1000) {
            let nc = UNUserNotificationCenter.current()
            nc.requestAuthorization(options: [.alert, .provisional], completionHandler: { granted, _ in
                mainAsync { Defaults[.notificationsPermissionsGranted] = granted }
            })
        }
        mainAsyncAfter(ms: 3000) {
            if CachedDefaults[.brightnessKeysEnabled] || CachedDefaults[.volumeKeysEnabled] {
                appDelegate!.startOrRestartMediaKeyTap(checkPermissions: true)
            } else if let apps = CachedDefaults[.appExceptions], !apps.isEmpty {
                acquirePrivileges(
                    notificationTitle: "Lunar can now watch for app exceptions",
                    notificationBody: "Whenever an app in the exception list is focused or visible on a screen, Lunar will apply its offsets."
                )
            }
        }
    }

    func setupSkipButton(_ button: Button, color: NSColor? = nil, text: String? = nil, skip: @escaping (() -> Void)) {
        button.bg = color ?? red
        button.attributedTitle = (text ?? button.title).withTextColor(.black)
        button.hoverAlpha = 0.8
        button.trackHover()
        self.skip = skip
        button.onClick = { [weak self] in
            self?.clickedSkipButton = true

            self?.skip?()
            guard !useOnboardingForDiagnostics else { return }
            self?.window?.close()
            self?.completeOnboarding()
        }
    }
}

var useOnboardingForDiagnostics = false
var adaptiveModeDisabledByDiagnostics = false

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
        selectedIndex = useOnboardingForDiagnostics ? 1 : 0
        completeTransition()
        view.setNeedsDisplay(view.rectForPage(selectedIndex))
    }

    override func viewDidAppear() {
        (view.window?.windowController as? OnboardWindowController)?.pageController = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func scrollWheel(with _: NSEvent) {}
    func select(index: Int) {
        NSAnimationContext.runAnimationGroup({ _ in animator().selectedIndex = index }) { [weak self] in
            self?.completeTransition()
        }
    }
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
