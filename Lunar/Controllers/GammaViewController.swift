//
//  GammaViewController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 18.05.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Foundation

class GammaViewController: NSViewController {
    @IBOutlet var dot: NSTextField!

    var visible: Bool {
        mainThread { view.window?.isVisible ?? false }
    }

    func change() {
        mainThread {
            if dot.alphaValue == 0.0 {
                dot.alphaValue = 0.1
            } else {
                dot.alphaValue = 0.0
            }
            dot.needsDisplay = true
        }
    }

    func hide() {
        mainThread {
            dot.alphaValue = 0.0
            dot.needsDisplay = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
