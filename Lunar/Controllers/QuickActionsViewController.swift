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

    #if DEBUG
        @objc dynamic lazy var display: Display? = {
            guard let display = displayController.externalActiveDisplays.first else { return nil }
            display.appPreset = CachedDefaults[.appExceptions]?.first

            return display
        }()

        @objc dynamic lazy var displays: [Display] = displayController.activeDisplayList.filter({ $0.serial != display?.serial }) {
            didSet { resize() }
        }
    #else
        @objc dynamic lazy var display: Display? = displayController.cursorDisplay

        @objc dynamic lazy var displays: [Display] = displayController.activeDisplayList.filter({ $0.serial != display?.serial }) {
            didSet { resize() }
        }
    #endif

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
        appDelegate!.menu.popUp(positioning: nil, at: NSPoint(x: view.frame.width, y: view.frame.height - 4), in: view)
    }

    func resize() {
        mainAsync { [weak self] in
            guard let self = self else { return }
            self.table.intercellSpacing = NSSize(width: 0, height: !self.displays.isEmpty ? 20 : 0)
            let merged = CachedDefaults[.mergeBrightnessContrast]
            var height = sum(self.displays.map { $0.hasDDC ? ((merged ? 120 : 150) + ($0.showOrientation ? 30 : 0)) : 80 }) +
                (self.table.intercellSpacing.height * CGFloat(self.displays.count))

            if let display = self.display {
                if display.hasDDC {
                    height += 114 + (display.showOrientation ? 30 : 0) + (display.appPreset != nil ? 20 : 0) + (merged ? 0 : 30)
                } else {
                    height += 60 + (display.showOrientation ? 20 : 0) + (display.appPreset != nil ? 20 : 0)
                }
            }

            self.view.setFrameSize(NSSize(width: self.view.frame.width, height: height + (self.displays.isEmpty ? 50 : 76)))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        resize()
    }
}

// MARK: - CellWithDDC

class CellWithDDC: NSTableCellView {
    @IBOutlet var orientationControl: NSSegmentedControl?

    override var objectValue: Any? {
        didSet {
            guard let display = objectValue as? Display, let orientationControl = orientationControl else { return }

            if !display.showOrientation {
                orientationControl.removeFromSuperview()
            }
        }
    }
}

// MARK: - CellWithoutDDC

class CellWithoutDDC: NSTableCellView {
    @IBOutlet var orientationControl: NSSegmentedControl?

    override var objectValue: Any? {
        didSet {
            guard let display = objectValue as? Display, let orientationControl = orientationControl else { return }

            if !display.showOrientation {
                orientationControl.removeFromSuperview()
            }
        }
    }
}
