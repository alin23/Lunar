//
//  MenuPopoverController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25/11/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa
import Combine
import Defaults
import Surge

// MARK: - QuickActionsViewController

class QuickActionsViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    let cellWithDDC = NSUserInterfaceItemIdentifier(rawValue: "cellWithDDC")
    let cellWithoutDDC = NSUserInterfaceItemIdentifier(rawValue: "cellWithoutDDC")

    @IBOutlet var menuButton: Button!
    @IBOutlet var table: NSTableView!

    var observers: Set<AnyCancellable> = []

    @objc dynamic lazy var showOrientation = CachedDefaults[.showOrientationInQuickActions]

    @objc dynamic lazy var display: Display? = displayController.cursorDisplay

    @objc dynamic lazy var displays: [Display] = displayController.activeDisplayList.filter({ $0.serial != display?.serial }) {
        didSet { resize() }
    }

    @IBAction func setPercent(_ sender: Button) {
        appDelegate!.setLightPercent(percent: sender.tag.i8)
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard let display = displays[safe: row],
              let cell = tableView.makeView(withIdentifier: display.hasDDC ? cellWithDDC : cellWithoutDDC, owner: self)
        else { return nil }

        return cell
    }

    @IBAction func showMenu(_: Button) {
        appDelegate!.menu.popUp(positioning: nil, at: NSPoint(x: view.frame.width, y: view.frame.height), in: view)
    }

    func resize() {
        mainThread {
            table.intercellSpacing = NSSize(width: 0, height: showOrientation ? 20 : 0)
            var height = sum(displays.map { $0.hasDDC ? 150 : 80 }) + (table.intercellSpacing.height * CGFloat(displays.count))
            if let display = display {
                if display.hasDDC {
                    height += 114 + (display.showOrientation ? 30 : 0)
                } else {
                    height += 60 + (display.showOrientation ? 20 : 0)
                }
            }
            view.setFrameSize(NSSize(width: view.frame.width, height: height + 60))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        resize()
    }
}
