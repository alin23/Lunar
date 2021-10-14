//
//  HotkeysChoiceViewController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 01.10.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa

class HotkeysChoiceViewController: NSViewController {
    var cancelled = false

    @IBOutlet var skipButton: Button!

    @objc dynamic var displays: [Display] = []

    override func viewDidAppear() {
        displays = displayController.activeDisplays.values.map { $0 }
        if let wc = view.window?.windowController as? OnboardWindowController {
            wc.setupSkipButton(skipButton) { [weak self] in
                // self?.revert()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func next() {
        guard let wc = view.window?.windowController as? OnboardWindowController else { return }
        wc.pageController?.navigateForward(self)
    }
}
