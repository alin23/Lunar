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

// MARK: - MenuPopoverController

class MenuPopoverController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    // MARK: Lifecycle

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        listenForPopoverEvents()
//        listenForAdaptiveModeChange()
        listenForDisplaysChange()
        listenForResponsiveDDCChange()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        listenForPopoverEvents()
//        listenForAdaptiveModeChange()
        listenForDisplaysChange()
        listenForResponsiveDDCChange()
    }

    // MARK: Internal

    @IBOutlet var activeModeButton: PopUpButton!

    @IBOutlet var tableView: DisplayValuesView!
    @IBOutlet var arrayController: NSArrayController!
    @IBOutlet var brightnessColumn: NSTableColumn!
    @IBOutlet var contrastColumn: NSTableColumn!
    @IBInspectable dynamic lazy var displays: [Display] = displayController.displays.values.map { $0 }
        .sorted(by: { d1, d2 in d1.active && !d2.active })

    var viewHeight: CGFloat?

    var trackingArea: NSTrackingArea?
    var responsiveDDCObservers = [String: AnyCancellable](minimumCapacity: 10)
    var observers = [String: AnyCancellable](minimumCapacity: 3)

    var pausedAdaptiveModeObserver: Bool = false

    func listenForPopoverEvents() {
        NotificationCenter.default
            .publisher(for: NSPopover.didShowNotification, object: POPOVERS["menu"]!!)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.popoverDidShow() }
            .store(in: &observers, for: "popoverDidShow")

        NotificationCenter.default
            .publisher(for: NSPopover.willShowNotification, object: POPOVERS["menu"]!!)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.popoverWillShow() }
            .store(in: &observers, for: "popoverWillShow")

        NotificationCenter.default
            .publisher(for: NSPopover.didCloseNotification, object: POPOVERS["menu"]!!)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.popoverDidClose() }
            .store(in: &observers, for: "popoverDidClose")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.appearance = NSAppearance(named: .vibrantDark)
        activeModeButton.page = .hotkeys

        tableView.headerView = nil
    }

    func adaptViewSize() {
        #if DEBUG
            log.verbose("Adapting Quick Actions view size")
        #endif

        viewHeight = viewHeight ?? view.frame.size.height

        let neededHeight = 50 + tableView.fittingSize.height
        #if DEBUG
            log.verbose("Needed Height: \(neededHeight)")
        #endif

        if tableView.numberOfRows == 0, view.frame.size.height != viewHeight! {
            POPOVERS["menu"]!!.animates = false
            #if DEBUG
                log.verbose("Zero rows, setting FrameSize to: \(NSSize(width: view.frame.size.width, height: viewHeight!))")
            #endif

            view.setFrameSize(NSSize(width: view.frame.size.width, height: viewHeight!))
            POPOVERS["menu"]!!.contentSize = view.frame.size
            view.setNeedsDisplay(view.frame)

            POPOVERS["menu"]!!.animates = true
        } else if view.frame.size.height != neededHeight {
            POPOVERS["menu"]!!.animates = false
            #if DEBUG
                log
                    .verbose(
                        "\(tableView.numberOfRows) rows, setting FrameSize to: \(NSSize(width: view.frame.size.width, height: neededHeight))"
                    )
            #endif

            view.setFrameSize(NSSize(width: view.frame.size.width, height: neededHeight))
            POPOVERS["menu"]!!.contentSize = view.frame.size
            view.setNeedsDisplay(view.frame)

            POPOVERS["menu"]!!.animates = true
        }
    }

    func popoverWillShow() {
        tableView.resizeInputs()
        #if DEBUG
            log.verbose("Calling adaptViewSize()")
        #endif
        adaptViewSize()
    }

    func popoverDidShow() {
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

    func popoverDidClose() {
        mainThread {
            if let area = trackingArea {
                view.removeTrackingArea(area)
            }
            trackingArea = nil
        }
    }

    override func flagsChanged(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            log.verbose("Fastest scroll threshold")
            scrollDeltaYThreshold = FASTEST_SCROLL_Y_THRESHOLD
        } else if event.modifierFlags.contains(.command) {
            log.verbose("Precise scroll threshold")
            scrollDeltaYThreshold = PRECISE_SCROLL_Y_THRESHOLD
        } else if event.modifierFlags.contains(.option) {
            log.verbose("Fast scroll threshold")
            scrollDeltaYThreshold = FAST_SCROLL_Y_THRESHOLD
        } else if event.modifierFlags.isDisjoint(with: [.command, .option, .control]) {
            log.verbose("Normal scroll threshold")
            scrollDeltaYThreshold = NORMAL_SCROLL_Y_THRESHOLD
        }
    }

    func listenForDisplaysChange() {
        CachedDefaults.displaysPublisher
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] newDisplays in
                guard let self = self else { return }

                let currentDisplayCount = self.displays.count
                let sameDisplayCount = newDisplays.count == currentDisplayCount
                let serial = { (d1: Display, d2: Display) -> Bool in d1.serial < d2.serial }
                let sameDisplays = sameDisplayCount && zip(
                    self.displays.sorted(by: serial),
                    newDisplays.sorted(by: serial)
                )
                .allSatisfy { d1, d2 in
                    d1.serial == d2.serial && d1.adaptive == d2.adaptive && d1.active == d2.active && d1.responsiveDDC == d2.responsiveDDC
                }

                if !sameDisplays {
                    self.setValue(
                        displayController.displays.values.map { $0 }.sorted(by: { d1, d2 in d1.active && !d2.active }),
                        forKey: "displays"
                    )
                    self.tableView.reloadData()
                    self.view.setNeedsDisplay(self.view.frame)

                    #if DEBUG
                        log.verbose("Calling adaptViewSize()")
                    #endif

                    if !sameDisplayCount {
                        if newDisplays.count == 1, currentDisplayCount > 1 {
                            appDelegate.initMenuPopover()
                        }
                        self.adaptViewSize()
                    }
                    self.listenForResponsiveDDCChange()
                }
            }
            .store(in: &observers, for: "displays")
    }

    func listenForResponsiveDDCChange() {
        responsiveDDCObservers.removeAll(keepingCapacity: true)

        for display in displayController.activeDisplays.values {
            display.$responsiveDDC
                .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
                .removeDuplicates()
                .sink { [weak self] _ in
                    mainAsyncAfter(ms: 1000) { [weak self] in
                        guard let self = self else { return }
                        self.setValue(
                            displayController.displays.values.map { $0 }.sorted(by: { d1, d2 in d1.active && !d2.active }),
                            forKey: "displays"
                        )
                        self.tableView.reloadData()
                        self.view.setNeedsDisplay(self.view.frame)
                    }
                }
                .store(in: &observers, for: display.serial)
        }
    }

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
