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

let offColor = gray.withAlphaComponent(0.5).cgColor
let disabledColor = gray.withAlphaComponent(0.25).cgColor

func getOffColor(_ button: NSButton) -> CGColor {
    if button.isEnabled {
        return offColor
    } else {
        return disabledColor
    }
}

func buttonBackgroundColor(mode: AdaptiveModeKey) -> NSColor {
    buttonDotColor[mode]!.withAlphaComponent(0.9)
}

class ModeButtonResponder: NSResponder {
    var mode: AdaptiveModeKey!
    var button: NSButton!
    var trackingArea: NSTrackingArea!

    convenience init(button: NSButton, mode: AdaptiveModeKey) {
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

        if displayController.adaptiveModeKey == mode {
            button.state = .on
            button.bg = buttonBackgroundColor(mode: mode)
        } else {
            button.state = .off
            button.layer?.backgroundColor = getOffColor(button)
        }

        let activeTitle = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
        activeTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: NSColor.black.withAlphaComponent(0.8),
            range: NSMakeRange(0, activeTitle.length)
        )
        let inactiveTitle = NSMutableAttributedString(attributedString: button.attributedTitle)
        inactiveTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: NSColor.black.withAlphaComponent(0.8),
            range: NSMakeRange(0, inactiveTitle.length)
        )

        button.attributedTitle = inactiveTitle
        button.attributedAlternateTitle = activeTitle

        button.setFrameSize(NSSize(width: buttonSize.width, height: 20))
        button.radius = (button.frame.height / 2).ns

        log.debug("Adding tracking area for quick actions: \(button.frame)")
        trackingArea = NSTrackingArea(
            rect: button.frame,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)
    }

    override func mouseEntered(with _: NSEvent) {
        if !button.isEnabled {
            return
        }

        button.layer?.add(fadeTransition(duration: 0.1), forKey: "transition")

        if button.state == .on {
            button.layer?
                .backgroundColor = (buttonBackgroundColor(mode: mode).highlight(withLevel: 0.2) ?? buttonBackgroundColor(mode: mode))
                .cgColor
        } else {
            button.bg = buttonBackgroundColor(mode: mode)
        }
    }

    override func mouseExited(with _: NSEvent) {
        if !button.isEnabled {
            return
        }

        button.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")

        if button.state == .on {
            button.bg = buttonBackgroundColor(mode: mode)
        } else {
            button.layer?.backgroundColor = getOffColor(button)
        }
    }
}

class MenuPopoverController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet var activeModeButton: PopUpButton!

    @IBOutlet var tableView: DisplayValuesView!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var arrayController: NSArrayController!
    @IBOutlet var brightnessColumn: NSTableColumn!
    @IBOutlet var contrastColumn: NSTableColumn!
    @IBInspectable dynamic var displays: [Display] = displayController.displays.values.map { $0 }
        .sorted(by: { d1, d2 in !d1.active && d2.active })

    var viewHeight: CGFloat?

    var trackingArea: NSTrackingArea?
    var adaptiveModeObserver: Cancellable?
    var displaysObserver: Cancellable!
    var responsiveDDCObservers: [CGDirectDisplayID: NSKeyValueObservation] = [:]

    func listenForPopoverEvents() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverDidShow(notification:)),
            name: NSPopover.didShowNotification,
            object: POPOVERS["menu"]!!
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverWillShow(notification:)),
            name: NSPopover.willShowNotification,
            object: POPOVERS["menu"]!!
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverDidClose(notification:)),
            name: NSPopover.didCloseNotification,
            object: POPOVERS["menu"]!!
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
        view.appearance = NSAppearance(named: .vibrantDark)
        activeModeButton.page = .hotkeys

        tableView.headerView = nil
    }

    func adaptViewSize() {
        POPOVERS["menu"]!!.animates = false

        let scrollFrame = scrollView.frame
        viewHeight = viewHeight ?? view.frame.size.height
        let neededHeight = viewHeight! + tableView.fittingSize.height
        if tableView.numberOfRows == 0 {
            view.setFrameSize(NSSize(width: view.frame.size.width, height: viewHeight!))
        } else if view.frame.size.height != neededHeight {
            view.setFrameSize(NSSize(width: view.frame.size.width, height: neededHeight))
        }
        POPOVERS["menu"]!!.contentSize = view.frame.size

        scrollView.setFrameSize(NSSize(width: scrollFrame.size.width, height: tableView.fittingSize.height))
        scrollView.setFrameOrigin(scrollFrame.origin)

        scrollView.setNeedsDisplay(scrollView.frame)
        view.setNeedsDisplay(view.frame)

        POPOVERS["menu"]!!.animates = true
    }

    @objc func popoverWillShow(notification _: Notification) {
        mainThread {
            adaptViewSize()
        }
    }

    @objc func popoverDidShow(notification _: Notification) {
        mainThread {
            if let area = trackingArea {
                view.removeTrackingArea(area)
            }
            trackingArea = NSTrackingArea(
                rect: view.visibleRect,
                options: [.mouseEnteredAndExited, .activeAlways],
                owner: self,
                userInfo: nil
            )
            view.addTrackingArea(trackingArea!)
        }
    }

    @objc func popoverDidClose(notification _: Notification) {
        mainThread {
            if let area = trackingArea {
                view.removeTrackingArea(area)
            }
            trackingArea = nil
        }
    }

    func sameDisplays() -> Bool {
        let newDisplays = displayController.displays.values.map { $0 }
        return newDisplays.count == displays.count && zip(displays, newDisplays).allSatisfy { d1, d2 in d1 === d2 }
    }

    func listenForDisplaysChange() {
        displaysObserver = CachedDefaults.displaysPublisher.sink { [unowned self] _ in
            mainAsyncAfter(ms: 2000) { [weak self] in
                guard let self = self else { return }
                if !self.sameDisplays() {
                    self.tableView.beginUpdates()
                    self.setValue(
                        displayController.displays.values.map { $0 }.sorted(by: { d1, d2 in !d1.active && d2.active }),
                        forKey: "displays"
                    )
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
        for (id, display) in displayController.activeDisplays {
            responsiveDDCObservers[id] = display.observe(\.responsiveDDC, options: [.new], changeHandler: { [unowned self] _, _ in
                mainAsyncAfter(ms: 1000) { [weak self] in
                    guard let self = self else { return }
                    self.tableView.beginUpdates()
                    self.setValue(
                        displayController.displays.values.map { $0 }.sorted(by: { d1, d2 in !d1.active && d2.active }),
                        forKey: "displays"
                    )
                    self.tableView.reloadData()
                    self.view.setNeedsDisplay(self.view.visibleRect)
                    self.tableView.endUpdates()

                    self.adaptViewSize()
//                    if CachedDefaults[.showQuickActions], displayController.displays.count > 1,
//                       let statusButton = appDelegate().statusItem.button
//                    {
//                        POPOVERS["menu"]!!.show(relativeTo: NSRect(), of: statusButton, preferredEdge: .maxY)
//                        closeMenuPopover(after: 2500)
//                    }
                }
            })
        }
    }

    var pausedAdaptiveModeObserver: Bool = false

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = adaptiveBrightnessModePublisher.sink { [unowned self] change in
            mainThread { [weak self] in
                guard let self = self, !self.pausedAdaptiveModeObserver, let tableView = self.tableView else {
                    return
                }

                self.pausedAdaptiveModeObserver = true
                Defaults.withoutPropagation {
                    let adaptiveMode = change.newValue

                    switch adaptiveMode {
                    case .sensor:
                        tableView.setAdaptiveButtonHidden(false)
                    case .sync:
                        tableView.setAdaptiveButtonHidden(false)
                    case .location:
                        tableView.setAdaptiveButtonHidden(false)
                    case .manual:
                        tableView.setAdaptiveButtonHidden(true)
                    }
                }
                self.pausedAdaptiveModeObserver = false
            }
        }
    }

//
//    @IBAction func toggleMode(_ sender: PopUpButton) {
//        let state = sender.state
//        grayAllButtons()

//        switch state {
//        case .on:
//            sender.state = .on
//            if sender == syncModeButton {
//                log.debug("SYNC")
//                sender.bg = buttonBackgroundColor(mode: .sync)
//                displayController.enable(mode: .sync)
//            } else if sender == locationModeButton {
//                log.debug("LOCATION")
//                sender.bg = buttonBackgroundColor(mode: .location)
//                displayController.enable(mode: .location)
//            } else {
//                log.debug("MANUAL")
//                sender.bg = buttonBackgroundColor(mode: .manual)
//                displayController.enable(mode: .manual)
//            }
//        case .off:
//            guard let syncModeButton = syncModeButton, let locationModeButton = locationModeButton,
//                  let manualModeButton = manualModeButton
//            else {
//                return
//            }
//            sender.layer?.backgroundColor = getOffColor(sender)
//            if sender == manualModeButton {
//                displayController.enable()
//                if displayController.adaptiveModeKey == .location {
//                    locationModeButton.state = .on
//                    locationModeButton.bg = buttonBackgroundColor(mode: .location)
//                } else if displayController.adaptiveModeKey == .sync {
//                    syncModeButton.state = .on
//                    syncModeButton.bg = buttonBackgroundColor(mode: .sync)
//                }
//            } else {
//                displayController.disable()
//                manualModeButton.state = .on
//                manualModeButton.bg = buttonBackgroundColor(mode: .manual)
//            }
//        default:
//            return
//        }
//    }

    override func mouseEntered(with _: NSEvent) {
        log.verbose("Mouse entered menu popover")
        menuPopoverCloser.cancel()
    }

    override func mouseExited(with _: NSEvent) {
        log.verbose("Mouse exited menu popover")
        mainAsyncAfter(ms: 1500) {
            POPOVERS["menu"]!!.close()
        }
    }
}
