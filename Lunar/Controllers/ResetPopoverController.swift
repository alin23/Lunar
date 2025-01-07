//
//  ResetPopoverController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 05.04.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Atomics
import Cocoa
import Combine
import Defaults

// MARK: - ResetPopoverController

final class ResetPopoverController: NSViewController {
    var displayObservers = [String: AnyCancellable]()

    @objc dynamic weak var display: Display?
    @objc dynamic weak var displayViewController: DisplayViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

// MARK: - ResetPopoverButton

final class ResetPopoverButton: PopoverButton<ResetPopoverController> {
    override var popoverKey: String {
        "reset"
    }

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

    override func mouseDown(with event: NSEvent) {
        popoverController?.display = display
        popoverController?.displayViewController = displayViewController
        super.mouseDown(with: event)
    }
}
