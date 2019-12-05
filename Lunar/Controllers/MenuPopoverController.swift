//
//  MenuPopoverController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25/11/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa

let offColor = gray.withAlphaComponent(0.5).cgColor

func buttonBackgroundColor(mode: AdaptiveMode) -> NSColor {
    return buttonDotColor[mode]!.withAlphaComponent(0.9)
}

class ModeButtonResponder: NSResponder {
    var mode: AdaptiveMode!
    var button: NSButton!
    var trackingArea: NSTrackingArea!

    convenience init(button: NSButton, mode: AdaptiveMode) {
        self.init()
        self.button = button
        self.mode = mode
        initModeButton()
    }

    func initModeButton() {
        let buttonSize = button.frame
        button.wantsLayer = true

        if brightnessAdapter.mode == mode {
            button.state = .on
            button.layer?.backgroundColor = buttonBackgroundColor(mode: mode).cgColor
        } else {
            button.state = .off
            button.layer?.backgroundColor = offColor
        }

        let activeTitle = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
        activeTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: mauve.withAlphaComponent(0.7), range: NSMakeRange(0, activeTitle.length))
        let inactiveTitle = NSMutableAttributedString(attributedString: button.attributedTitle)
        inactiveTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: mauve.withAlphaComponent(0.5), range: NSMakeRange(0, inactiveTitle.length))

        button.attributedTitle = inactiveTitle
        button.attributedAlternateTitle = activeTitle

        button.setFrameSize(NSSize(width: buttonSize.width, height: 20))
        button.layer?.cornerRadius = button.frame.height / 2

        trackingArea = NSTrackingArea(rect: button.visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        button.addTrackingArea(trackingArea)
    }

    override func mouseEntered(with _: NSEvent) {
        button.layer?.add(fadeTransition(duration: 0.1), forKey: "transition")

        if button.state == .on {
            button.layer?.backgroundColor = buttonBackgroundColor(mode: mode).highlight(withLevel: 0.2)!.cgColor
        } else {
            button.layer?.backgroundColor = buttonBackgroundColor(mode: mode).cgColor
        }
    }

    override func mouseExited(with _: NSEvent) {
        button.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")

        if button.state == .on {
            button.layer?.backgroundColor = buttonBackgroundColor(mode: mode).cgColor
        } else {
            button.layer?.backgroundColor = offColor
        }
    }
}

class MenuPopoverController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet var syncModeButton: NSButton!
    @IBOutlet var locationModeButton: NSButton!
    @IBOutlet var manualModeButton: NSButton!

    @IBOutlet var tableView: DisplayValuesView!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var arrayController: NSArrayController!
    @IBOutlet var brightnessColumn: NSTableColumn!
    @IBOutlet var contrastColumn: NSTableColumn!
    @IBInspectable dynamic var displays: [Display] = brightnessAdapter.displays.values.map { $0 }.sorted(by: { d1, d2 in d1.active && !d2.active })

    var viewHeight: CGFloat?
    var syncModeButtonResponder: ModeButtonResponder!
    var locationModeButtonResponder: ModeButtonResponder!
    var manualModeButtonResponder: ModeButtonResponder!

    var trackingArea: NSTrackingArea?
    var adaptiveModeObserver: NSKeyValueObservation?
    var displaysObserver: NSKeyValueObservation!

    func listenForPopoverEvents() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverDidShow(notification:)),
            name: NSPopover.didShowNotification,
            object: menuPopover
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverWillShow(notification:)),
            name: NSPopover.willShowNotification,
            object: menuPopover
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverDidClose(notification:)),
            name: NSPopover.didCloseNotification,
            object: menuPopover
        )
    }

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        listenForPopoverEvents()
        listenForAdaptiveModeChange()
        listenForDisplaysChange()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        listenForPopoverEvents()
        listenForAdaptiveModeChange()
        listenForDisplaysChange()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.headerView = nil
    }

    @objc func popoverWillShow(notification _: Notification) {
        runInMainThread {
            let scrollFrame = scrollView.frame
            viewHeight = viewHeight ?? view.frame.size.height
            let neededHeight = viewHeight! + tableView.frame.size.height
            if tableView.numberOfRows == 0 {
                view.setFrameSize(NSSize(width: view.frame.size.width, height: viewHeight!))
            } else
            if view.frame.size.height != neededHeight {
                view.setFrameSize(NSSize(width: view.frame.size.width, height: neededHeight))
            }
            menuPopover.contentSize = view.frame.size

            scrollView.setFrameSize(tableView.frame.size)
            scrollView.setFrameOrigin(scrollFrame.origin)

            scrollView.setNeedsDisplay(scrollView.frame)
            view.setNeedsDisplay(view.frame)
        }
    }

    @objc func popoverDidShow(notification _: Notification) {
        runInMainThread {
            if let area = trackingArea {
                view.removeTrackingArea(area)
            }
            trackingArea = NSTrackingArea(rect: view.visibleRect, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
            view.addTrackingArea(trackingArea!)

            syncModeButtonResponder = syncModeButtonResponder ?? ModeButtonResponder(button: syncModeButton, mode: .sync)
            locationModeButtonResponder = locationModeButtonResponder ?? ModeButtonResponder(button: locationModeButton, mode: .location)
            manualModeButtonResponder = manualModeButtonResponder ?? ModeButtonResponder(button: manualModeButton, mode: .manual)
        }
    }

    @objc func popoverDidClose(notification _: Notification) {
        runInMainThread {
            if let area = trackingArea {
                view.removeTrackingArea(area)
            }
            trackingArea = nil
        }
    }

    func grayAllButtons() {
        runInMainThread {
            syncModeButton.layer?.backgroundColor = offColor
            locationModeButton.layer?.backgroundColor = offColor
            manualModeButton.layer?.backgroundColor = offColor

            syncModeButton.state = .off
            locationModeButton.state = .off
            manualModeButton.state = .off
        }
    }

    func sameDisplays() -> Bool {
        let newDisplays = brightnessAdapter.displays.values.map { $0 }
        return newDisplays.count == displays.count && zip(displays, newDisplays).allSatisfy { d1, d2 in d1 === d2 }
    }

    func listenForDisplaysChange() {
        displaysObserver = datastore.defaults.observe(\.displays, options: [.new], changeHandler: { _, _ in
            runInMainThreadAsyncAfter(ms: 2000) {
                if !self.sameDisplays() {
                    self.tableView.beginUpdates()
                    self.setValue(brightnessAdapter.displays.values.map { $0 }.sorted(by: { d1, d2 in d1.active && !d2.active }), forKey: "displays")
                    self.tableView.reloadData()
                    self.view.setNeedsDisplay(self.view.visibleRect)
                    self.tableView.endUpdates()
                }
            }
        })
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = datastore.defaults.observe(\.adaptiveBrightnessMode, options: [.old, .new], changeHandler: { _, change in
            runInMainThread {
                guard let mode = change.newValue, let oldMode = change.oldValue, mode != oldMode else {
                    return
                }
                let adaptiveMode = AdaptiveMode(rawValue: mode)!
                self.grayAllButtons()
                switch adaptiveMode {
                case .sync:
                    self.syncModeButton.layer?.backgroundColor = buttonBackgroundColor(mode: adaptiveMode).cgColor
                    self.syncModeButton.state = .on
                    self.tableView.setAdaptiveButtonHidden(false)
                case .location:
                    self.locationModeButton.layer?.backgroundColor = buttonBackgroundColor(mode: adaptiveMode).cgColor
                    self.locationModeButton.state = .on
                    self.tableView.setAdaptiveButtonHidden(false)
                case .manual:
                    self.manualModeButton.layer?.backgroundColor = buttonBackgroundColor(mode: adaptiveMode).cgColor
                    self.manualModeButton.state = .on
                    self.tableView.setAdaptiveButtonHidden(true)
                }
            }
        })
    }

    @IBAction func toggleMode(_ sender: NSButton) {
        let state = sender.state
        grayAllButtons()

        switch state {
        case .on:
            sender.state = .on
            if sender == syncModeButton {
                log.debug("SYNC")
                sender.layer?.backgroundColor = buttonBackgroundColor(mode: .sync).cgColor
                brightnessAdapter.enable(mode: .sync)
            } else if sender == locationModeButton {
                log.debug("LOCATION")
                sender.layer?.backgroundColor = buttonBackgroundColor(mode: .location).cgColor
                brightnessAdapter.enable(mode: .location)
            } else {
                log.debug("MANUAL")
                sender.layer?.backgroundColor = buttonBackgroundColor(mode: .manual).cgColor
                brightnessAdapter.enable(mode: .manual)
            }
        case .off:
            sender.layer?.backgroundColor = offColor
            if sender == manualModeButton {
                brightnessAdapter.enable()
                if brightnessAdapter.mode == .location {
                    locationModeButton.state = .on
                    locationModeButton.layer?.backgroundColor = buttonBackgroundColor(mode: .location).cgColor
                } else if brightnessAdapter.mode == .sync {
                    syncModeButton.state = .on
                    syncModeButton.layer?.backgroundColor = buttonBackgroundColor(mode: .sync).cgColor
                }
            } else {
                brightnessAdapter.disable()
                manualModeButton.state = .on
                manualModeButton.layer?.backgroundColor = buttonBackgroundColor(mode: .manual).cgColor
            }
        default:
            return
        }
    }

    override func mouseEntered(with _: NSEvent) {
        log.debug("Mouse entered menu popover")
        menuPopoverCloser.cancel()
    }

    override func mouseExited(with _: NSEvent) {
        log.debug("Mouse exited menu popover")
        menuPopover.close()
    }
}
