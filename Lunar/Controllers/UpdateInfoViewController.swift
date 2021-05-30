//
//  UpdateInfoViewController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25.04.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa

class UpdateInfoViewController: NSViewController {
    @objc dynamic var editable = false
    @objc dynamic var info: NSAttributedString = "".attributedString
    @IBOutlet var outputScrollView: OutputScrollView!
    @IBOutlet var logo: NSTextField!
    @IBOutlet var extendLicenseButton: Button!
    @IBOutlet var backingTextView: NSTextView!
    @IBOutlet var textView: NSTextView!

    @IBAction func extendLicense(_: Any) {
        showCheckout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.radius = 12.0.ns
        view.bg = white
        logo?.textColor = logoColor

        outputScrollView.scrollsDynamically = true
        outputScrollView.wantsLayer = true
        outputScrollView.appearance = NSAppearance(named: .vibrantLight)
        outputScrollView.radius = 14.0.ns

        textView?.isEditable = false
        textView?.isSelectable = false
        backingTextView.isEditable = false

        extendLicenseButton.bg = green
        extendLicenseButton.radius = 10.ns
        extendLicenseButton.frame = NSRect(origin: extendLicenseButton.frame.origin, size: CGSize(width: extendLicenseButton.frame.width, height: 30))
        extendLicenseButton.attributedTitle = extendLicenseButton.title.withAttribute(.textColor(white))
    }
}
