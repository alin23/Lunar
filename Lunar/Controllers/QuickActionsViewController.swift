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

let QUICK_ACTIONS_SLIDER_CELL_TAG = 26

// MARK: - SliderValueTextField

class SliderValueTextField: NSTextField {
    @objc dynamic var _hidden = false

    override var isHidden: Bool {
        get { _hidden }
        set {
            _hidden = !CachedDefaults[.showSliderValues] ? true : newValue
        }
    }
}

// MARK: - SliderValueButton

class SliderValueButton: Button {
    var _hidden = false

    override var isHidden: Bool {
        get { _hidden }
        set {
            _hidden = !CachedDefaults[.showSliderValues] ? true : newValue
        }
    }
}

// MARK: - QuickActionsView

class QuickActionsView: NSView {
    override var wantsDefaultClipping: Bool { false }

    override func makeBackingLayer() -> CALayer {
        NoClippingLayer()
    }
}

// MARK: - QuickActionsViewController

class QuickActionsViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    let cellWithDDC = NSUserInterfaceItemIdentifier(rawValue: "cellWithDDC")
    let cellWithoutDDC = NSUserInterfaceItemIdentifier(rawValue: "cellWithoutDDC")

    @IBOutlet var menuButton: Button!
    @IBOutlet var table: NSTableView!

    var observers: Set<AnyCancellable> = []

    @objc dynamic lazy var showOrientation = CachedDefaults[.showOrientationInQuickActions]

//    #if DEBUG
//        @objc dynamic lazy var display: Display? = {
//            guard let display = displayController.externalActiveDisplays.first else { return nil }
//            display.appPreset = CachedDefaults[.appExceptions]?.first
//
//            return display
//        }()
//
//        @objc dynamic lazy var displays: [Display] = displayController.activeDisplayList.filter({ $0.serial != display?.serial }) {
//            didSet { resize() }
//        }
//    #else
    @objc dynamic lazy var display: Display? = displayController.cursorDisplay

    @objc dynamic lazy var displays: [Display] = displayController.activeDisplayList.filter({ $0.serial != display?.serial }) {
        didSet { resize() }
    }

//    #endif

    @IBAction func quit(_ sender: Button) {
        NSApplication.shared.terminate(sender)
    }

    @IBAction func restart(_ sender: Button) {
        appDelegate!.restartApp(sender)
    }

    @IBAction func preferences(_ sender: Button) {
        appDelegate!.showPreferencesWindow(sender: sender)
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
        appDelegate!.menu.popUp(
            positioning: nil,
            at: NSPoint(x: view.frame.width - (POPOVER_PADDING / 2), y: view.frame.height - 4),
            in: view
        )
    }

    func resize() {
        mainAsync { [weak self] in
            guard let self = self else { return }
            self.table.intercellSpacing = NSSize(width: 0, height: !self.displays.isEmpty ? 20 : 0)
            let merged = CachedDefaults[.mergeBrightnessContrast]
            var height = sum(self.displays.map { display in
                guard display.hasDDC else { return 60 }

                let orientationHeight: CGFloat = (display.showOrientation ? 30 : 0)
                let volumeHeight: CGFloat = (display.showVolumeSlider ? 30 : 0)
                #if DEBUG
                    log.info(
                        "QuickActions Height for \(display)",
                        context: ["initial": merged ? 90 : 120, "volumeHeight": volumeHeight, "orientationHeight": orientationHeight]
                    )
                #endif
                return (merged ? 90 : 120) + volumeHeight + orientationHeight
            }) + (self.table.intercellSpacing.height * CGFloat(self.displays.count))

            if let display = self.display {
                let orientationHeight: CGFloat = (display.showOrientation ? 30 : 0)
                let appPresetHeight: CGFloat = (display.appPreset != nil ? 30 : 0)
                let xdrHeight: CGFloat = (display.appPreset != nil ? 30 : 0)
                if display.hasDDC {
                    let volumeHeight: CGFloat = (display.showVolumeSlider ? 30 : 0)
                    let contrastHeight: CGFloat = (merged ? 0 : 30)
                    height += 90 + volumeHeight + orientationHeight + appPresetHeight + contrastHeight + xdrHeight
                    #if DEBUG
                        log.info(
                            "QuickActions Height for \(display)",
                            context: [
                                "initial": 90,
                                "volumeHeight": volumeHeight,
                                "orientationHeight": orientationHeight,
                                "appPresetHeight": appPresetHeight,
                                "contrastHeight": contrastHeight,
                                "xdrHeight": xdrHeight,
                            ]
                        )
                    #endif
                } else {
                    height += 60 + orientationHeight + appPresetHeight + xdrHeight
                    #if DEBUG
                        log.info(
                            "QuickActions Height for \(display)",
                            context: [
                                "initial": 60,
                                "orientationHeight": orientationHeight,
                                "appPresetHeight": appPresetHeight,
                                "xdrHeight": xdrHeight,
                            ]
                        )
                    #endif
                }
            }

            self.view
                .setFrameSize(NSSize(width: self.view.frame.width, height: height + (self.displays.isEmpty ? 144 : 170) + POPOVER_PADDING))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        resize()
    }
}

// MARK: - CellWithDDC

class CellWithDDC: NSTableCellView {
    static let SLIDER_VALUE_TAG = 23

    @IBOutlet var orientationControl: NSSegmentedControl?
    @IBOutlet var volumeSlider: Slider?

    override var objectValue: Any? {
        didSet {
            guard let display = objectValue as? Display else { return }

            if !display.showOrientation {
                orientationControl?.removeFromSuperview()
            }
            if !display.showVolumeSlider {
                volumeSlider?.removeFromSuperview()
            }

            if !CachedDefaults[.showSliderValues] {
                for view in subviews.filter({ $0.tag == Self.SLIDER_VALUE_TAG }) {
                    view.isHidden = true
                }
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
