//
//  SettingsPopoverController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 05.04.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Atomics
import Cocoa
import Combine
import Defaults

// MARK: - SettingsPopoverController

class SettingsPopoverController: NSViewController {
    var displayObservers = [String: AnyCancellable]()

    weak var displayViewController: DisplayViewController?

    @objc dynamic weak var display: Display? {
        didSet {
            guard let display = display else { return }
            display.refreshPanel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

// MARK: - SettingsButton

class SettingsButton: PopoverButton<SettingsPopoverController> {
    weak var displayViewController: DisplayViewController? {
        didSet {
            popoverController?.displayViewController = displayViewController
        }
    }

    weak var display: Display? {
        didSet {
            popoverController?.display = display
        }
    }

    override var popoverKey: String {
        "settings"
    }

    override func mouseDown(with event: NSEvent) {
        popoverController?.display = display
        popoverController?.displayViewController = displayViewController
        super.mouseDown(with: event)
    }
}
