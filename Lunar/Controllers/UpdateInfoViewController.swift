//
//  UpdateInfoViewController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25.04.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Sparkle

class UpdateInfoViewController: NSViewController {
    @objc dynamic var editable = false
    @objc dynamic var info: NSAttributedString = "".attributedString
    @IBOutlet var outputScrollView: OutputScrollView!
    @IBOutlet var logo: NSTextField!
    @IBOutlet var skipUpdateButton: Button!
    @IBOutlet var extendLicenseButton: Button!
    @IBOutlet var updateAnywayButton: Button!
    @IBOutlet var backingTextView: NSTextView!
    @IBOutlet var textView: NSTextView!

    weak var appcastItem: SUAppcastItem? {
        didSet {
            guard let item = appcastItem else { return }

            let info = MD.attributedString(from: """
            # Lunar v\(item.displayVersionString ?? item.versionString) is now available:

            """)

            guard let description = item.itemDescription?.data(using: .utf8),
                  let updateInfo = try? NSAttributedString(
                      data: description,
                      options: [.documentType: NSAttributedString.DocumentType.html],
                      documentAttributes: nil
                  )
            else { return }

            self.info = info.appending(updateInfo)
        }
    }

    @IBAction func extendLicense(_: Any) {
        showCheckout()
    }

    @IBAction func updateAnyway(_: Any) {}

    @IBAction func skipUpdate(_: Any) {
//        guard let appcastItem = appcastItem else { return }
//        SPUSkippedUpdate.skip(appcastItem, host: appDelegate.updater.host)
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

        skipUpdateButton.bg = red
        skipUpdateButton.radius = 10.ns
        skipUpdateButton.frame = NSRect(
            origin: skipUpdateButton.frame.origin,
            size: CGSize(width: skipUpdateButton.frame.width, height: 30)
        )
        skipUpdateButton.attributedTitle = skipUpdateButton.title.withAttribute(.textColor(white))

        extendLicenseButton.bg = green
        extendLicenseButton.radius = 10.ns
        extendLicenseButton.frame = NSRect(
            origin: extendLicenseButton.frame.origin,
            size: CGSize(width: extendLicenseButton.frame.width, height: 30)
        )
        extendLicenseButton.attributedTitle = extendLicenseButton.title.withAttribute(.textColor(white))

        updateAnywayButton.bg = lunarYellow
        updateAnywayButton.radius = 10.ns
        updateAnywayButton.frame = NSRect(
            origin: updateAnywayButton.frame.origin,
            size: CGSize(width: updateAnywayButton.frame.width, height: 30)
        )
        updateAnywayButton.attributedTitle = updateAnywayButton.title.withAttribute(.textColor(white))
    }
}
