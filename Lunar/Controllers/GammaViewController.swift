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

    @AtomicLock var highlighterTask: CFRunLoopTimer?
    var highlighterLock = NSRecursiveLock()

    var highlighting: Bool {
        dot.alphaValue > 0
    }

    func highlight() {
        // return
        let windowVisible = mainThread { view.window?.isVisible ?? false }
        guard highlighterTask == nil, dot != nil, windowVisible
        else {
            return
        }

        highlighterTask = operationHighlightQueue.async(every: 200.milliseconds) { [weak self] (_: CFRunLoopTimer?) in
            self?.highlighterLock.around {
                guard let s = self else {
                    if let timer = self?.highlighterTask {
                        operationHighlightQueue.cancel(timer: timer)
                        self?.highlighterTask = nil
                    }
                    return
                }

                let windowVisible: Bool = mainThread {
                    s.view.window?.isVisible ?? false
                }
                guard windowVisible, let dot = s.dot
                else {
                    if let timer = self?.highlighterTask {
                        operationHighlightQueue.cancel(timer: timer)
                    }
                    return
                }

                mainThread {
                    if dot.alphaValue == 0.0 {
                        dot.transition(0.25)
                        dot.alphaValue = 0.8
                        dot.needsDisplay = true
                    } else {
                        dot.transition(0.35)
                        dot.alphaValue = 0.0
                        dot.needsDisplay = true
                    }
                }
            }
        }

        let key = "stopHighlighting"
        let subscriberKey = "\(key)-\(view.accessibilityIdentifier())"
        debounce(ms: 3000, uniqueTaskKey: key, subscriberKey: subscriberKey) { [weak self] in
            guard let self = self else {
                cancelTask(key, subscriberKey: subscriberKey)
                return
            }
            self.stopHighlighting()
        }
    }

    func stopHighlighting() {
        // return
        if let timer = highlighterTask {
            operationHighlightQueue.cancel(timer: timer)
        }
        highlighterTask = nil

        mainThread { [weak self] in
            guard let dot = self?.dot else { return }
            dot.transition(0.2)
            dot.alphaValue = 0.0
            dot.needsDisplay = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
