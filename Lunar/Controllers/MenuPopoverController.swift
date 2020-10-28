//
//  MenuPopoverController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25/11/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa
import Defaults

let offColor = gray.withAlphaComponent(0.5).cgColor
let disabledColor = gray.withAlphaComponent(0.25).cgColor

func getOffColor(_ button: NSButton) -> CGColor {
    if button.isEnabled {
        return offColor
    } else {
        return disabledColor
    }
}

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

    func disable(tooltipMessage: String) {
        button.isEnabled = false
        button.toolTip = tooltipMessage
        button.layer?.backgroundColor = disabledColor
        button.state = .off
    }

    func enable() {
        button.isEnabled = true
        button.toolTip = nil
    }

    func initModeButton() {
        let buttonSize = button.frame
        button.wantsLayer = true

        if brightnessAdapter.mode == mode {
            button.state = .on
            button.layer?.backgroundColor = buttonBackgroundColor(mode: mode).cgColor
        } else {
            button.state = .off
            button.layer?.backgroundColor = getOffColor(button)
        }

        let activeTitle = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
        activeTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor.black.withAlphaComponent(0.8), range: NSMakeRange(0, activeTitle.length))
        let inactiveTitle = NSMutableAttributedString(attributedString: button.attributedTitle)
        inactiveTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor.black.withAlphaComponent(0.8), range: NSMakeRange(0, inactiveTitle.length))

        button.attributedTitle = inactiveTitle
        button.attributedAlternateTitle = activeTitle

        button.setFrameSize(NSSize(width: buttonSize.width, height: 20))
        button.layer?.cornerRadius = button.frame.height / 2

        trackingArea = NSTrackingArea(rect: button.visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        button.addTrackingArea(trackingArea)
    }

    override func mouseEntered(with _: NSEvent) {
        if !button.isEnabled {
            return
        }

        button.layer?.add(fadeTransition(duration: 0.1), forKey: "transition")

        if button.state == .on {
            button.layer?.backgroundColor = (buttonBackgroundColor(mode: mode).highlight(withLevel: 0.2) ?? buttonBackgroundColor(mode: mode)).cgColor
        } else {
            button.layer?.backgroundColor = buttonBackgroundColor(mode: mode).cgColor
        }
    }

    override func mouseExited(with _: NSEvent) {
        if !button.isEnabled {
            return
        }

        button.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")

        if button.state == .on {
            button.layer?.backgroundColor = buttonBackgroundColor(mode: mode).cgColor
        } else {
            button.layer?.backgroundColor = getOffColor(button)
        }
    }
}

class MenuPopoverController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet var syncModeButton: NSButton?
    @IBOutlet var locationModeButton: NSButton?
    @IBOutlet var manualModeButton: NSButton?

    @IBOutlet var tableView: DisplayValuesView!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var arrayController: NSArrayController!
    @IBOutlet var brightnessColumn: NSTableColumn!
    @IBOutlet var contrastColumn: NSTableColumn!
    @IBInspectable dynamic var displays: [Display] = brightnessAdapter.displays.values.map { $0 }.sorted(by: { d1, d2 in !d1.active && d2.active })

    var viewHeight: CGFloat?
    var syncModeButtonResponder: ModeButtonResponder!
    var locationModeButtonResponder: ModeButtonResponder!
    var manualModeButtonResponder: ModeButtonResponder!

    var trackingArea: NSTrackingArea?
    var adaptiveModeObserver: DefaultsObservation?
    var displaysObserver: DefaultsObservation!
    var responsiveDDCObservers: [CGDirectDisplayID: NSKeyValueObservation] = [:]

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
        listenForResponsiveDDCChange()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        listenForPopoverEvents()
        listenForAdaptiveModeChange()
        listenForDisplaysChange()
        listenForResponsiveDDCChange()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.headerView = nil
    }

    func adaptViewSize() {
        menuPopover.animates = false

        let scrollFrame = scrollView.frame
        viewHeight = viewHeight ?? view.frame.size.height
        let neededHeight = viewHeight! + tableView.fittingSize.height
        if tableView.numberOfRows == 0 {
            view.setFrameSize(NSSize(width: view.frame.size.width, height: viewHeight!))
        } else if view.frame.size.height != neededHeight {
            view.setFrameSize(NSSize(width: view.frame.size.width, height: neededHeight))
        }
        menuPopover.contentSize = view.frame.size

        scrollView.setFrameSize(NSSize(width: scrollFrame.size.width, height: tableView.fittingSize.height))
        scrollView.setFrameOrigin(scrollFrame.origin)

        scrollView.setNeedsDisplay(scrollView.frame)
        view.setNeedsDisplay(view.frame)

        menuPopover.animates = true
    }

    @objc func popoverWillShow(notification _: Notification) {
        runInMainThread {
            adaptViewSize()
        }
    }

    @objc func popoverDidShow(notification _: Notification) {
        runInMainThread {
            guard let syncModeButton = syncModeButton, let locationModeButton = locationModeButton, let manualModeButton = manualModeButton else {
                return
            }
            if let area = trackingArea {
                view.removeTrackingArea(area)
            }
            trackingArea = NSTrackingArea(rect: view.visibleRect, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
            view.addTrackingArea(trackingArea!)

            syncModeButtonResponder = syncModeButtonResponder ?? ModeButtonResponder(button: syncModeButton, mode: .sync)
            locationModeButtonResponder = locationModeButtonResponder ?? ModeButtonResponder(button: locationModeButton, mode: .location)
            manualModeButtonResponder = manualModeButtonResponder ?? ModeButtonResponder(button: manualModeButton, mode: .manual)

            if brightnessAdapter.clamshellMode {
                syncModeButtonResponder?.disable(tooltipMessage: "Sync mode can't be activated in clamshell mode")
            } else {
                syncModeButtonResponder?.enable()
            }
        }
    }

    @objc func popoverDidClose(notification _: Notification) {
        runInMainThread {
            if let area = trackingArea {
                view.removeTrackingArea(area)
            }
            trackingArea = nil
            disableUpDownHotkeys()
        }
    }

    func grayAllButtons() {
        runInMainThread {
            guard let syncModeButton = syncModeButton, let locationModeButton = locationModeButton, let manualModeButton = manualModeButton else {
                return
            }

            syncModeButton.layer?.backgroundColor = getOffColor(syncModeButton)
            locationModeButton.layer?.backgroundColor = getOffColor(locationModeButton)
            manualModeButton.layer?.backgroundColor = getOffColor(manualModeButton)

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
        displaysObserver = Defaults.observe(.displays) { [unowned self] _ in
            runInMainThreadAsyncAfter(ms: 2000) { [weak self] in
                guard let self = self else { return }
                if !self.sameDisplays() {
                    self.tableView.beginUpdates()
                    self.setValue(brightnessAdapter.displays.values.map { $0 }.sorted(by: { d1, d2 in !d1.active && d2.active }), forKey: "displays")
                    self.tableView.reloadData()
                    self.view.setNeedsDisplay(self.view.visibleRect)
                    self.tableView.endUpdates()

                    self.adaptViewSize()
                    self.listenForResponsiveDDCChange()
                }
            }
        }
    }

    func listenForResponsiveDDCChange() {
        responsiveDDCObservers.removeAll()
        for (id, display) in brightnessAdapter.activeDisplays {
            responsiveDDCObservers[id] = display.observe(\.responsive, options: [.new], changeHandler: { [unowned self] _, _ in
                runInMainThreadAsyncAfter(ms: 1000) { [weak self] in
                    guard let self = self else { return }
                    self.tableView.beginUpdates()
                    self.setValue(brightnessAdapter.displays.values.map { $0 }.sorted(by: { d1, d2 in !d1.active && d2.active }), forKey: "displays")
                    self.tableView.reloadData()
                    self.view.setNeedsDisplay(self.view.visibleRect)
                    self.tableView.endUpdates()

                    self.adaptViewSize()
                    if Defaults[.showQuickActions], brightnessAdapter.displays.count > 1,
                        let statusButton = appDelegate().statusItem.button {
                        menuPopover.show(relativeTo: NSRect(), of: statusButton, preferredEdge: .maxY)
                        closeMenuPopover(after: 2500)
                    }
                }
            })
        }
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = Defaults.observe(.adaptiveBrightnessMode) { [unowned self] change in
            runInMainThread { [weak self] in
                guard change.newValue != change.oldValue, let self = self else {
                    return
                }
                guard let syncModeButton = self.syncModeButton, let locationModeButton = self.locationModeButton, let manualModeButton = self.manualModeButton else {
                    return
                }
                let adaptiveMode = change.newValue
                self.grayAllButtons()
                switch adaptiveMode {
                case .sensor:
                    log.info("Sensor mode")
                case .sync:
                    syncModeButton.layer?.backgroundColor = buttonBackgroundColor(mode: adaptiveMode).cgColor
                    syncModeButton.state = .on
                    self.tableView.setAdaptiveButtonHidden(false)
                case .location:
                    locationModeButton.layer?.backgroundColor = buttonBackgroundColor(mode: adaptiveMode).cgColor
                    locationModeButton.state = .on
                    self.tableView.setAdaptiveButtonHidden(false)
                case .manual:
                    manualModeButton.layer?.backgroundColor = buttonBackgroundColor(mode: adaptiveMode).cgColor
                    manualModeButton.state = .on
                    self.tableView.setAdaptiveButtonHidden(true)
                }
            }
        }
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
            guard let syncModeButton = syncModeButton, let locationModeButton = locationModeButton, let manualModeButton = manualModeButton else {
                return
            }
            sender.layer?.backgroundColor = getOffColor(sender)
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
