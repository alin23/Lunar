//
//  GammaViewController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 18.05.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Foundation

private extension NSView {
    func hide() {
        alphaValue = 0.0
        window?.alphaValue = 0.0
        needsDisplay = true
    }
    func show(opacity: CGFloat) {
        alphaValue = opacity
        window?.alphaValue = 1.0
        needsDisplay = true
    }

    var visible: Bool {
        (window?.isVisible ?? false) && alphaValue > 0.0
    }
}

final class GammaViewController: NSViewController {
    @IBOutlet var dot: NSTextField!

    var hider: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }

    var visible: Bool {
        mainThread { view.window?.isVisible ?? false }
    }

    func change() {
        mainAsync { [weak self] in
            guard let dot = self?.dot else { return }

            if dot.visible {
                dot.show(opacity: 0.1)
                self?.hider = mainAsyncAfter(ms: 500) { [weak self] in
                    self?.dot.hide()
                }
            } else {
                dot.hide()
                self?.hider = nil
            }
            dot.needsDisplay = true
        }
    }

    func hide() {
        mainAsync { [weak self] in
            guard let dot = self?.dot else { return }
            dot.hide()
            self?.hider = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
