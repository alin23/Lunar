//
//  ProgressViewController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25.04.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa

class ProgressViewController: NSViewController {
    @objc dynamic var operationTitle = ""
    @objc dynamic var operationDescription: NSAttributedString = "".attributedString
    @IBOutlet var progressBar: NSProgressIndicator!
    @IBOutlet var doneButton: Button!

    @objc dynamic var done = false {
        didSet {
            if done {
                progressBar.stopAnimation(nil)
            }
        }
    }

    @IBAction func onDoneClicked(_: Any) {
        view.window?.close()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.radius = 12.0.ns
        view.bg = white
        progressBar?.appearance = NSAppearance(named: .vibrantLight)
        progressBar?.startAnimation(nil)

        doneButton?.bg = blue
        doneButton?.radius = 10.ns
        doneButton?.frame = NSRect(origin: doneButton.frame.origin, size: CGSize(width: doneButton.frame.width, height: 30))
        doneButton?.attributedTitle = doneButton.title.withAttribute(.textColor(white))
    }
}
