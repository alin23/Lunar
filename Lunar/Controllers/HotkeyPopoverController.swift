//
//  HotkeyPopoverController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 23.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Defaults
import Foundation
import Magnet

// MARK: - NoFrameView

final class NoFrameView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removePopoverBackground(view: self)
        fixPopoverView(self, backgroundColor: popoverBackgroundColor)
    }
}

// MARK: - HotkeyPopoverController

final class HotkeyPopoverController: NSViewController {
//
//    deinit {
//        #if DEBUG
//            log.verbose("START DEINIT: \(display?.description ?? "no display")")
//            do { log.verbose("END DEINIT: \(display?.description ?? "no display")") }
//        #endif
//
//        hotkey1?.unregister()
//        hotkey2?.unregister()
//        hotkey3?.unregister()
//    }

    @IBOutlet var hotkeyView1: HotkeyView!
    @IBOutlet var dropdown1: NSPopUpButton!

    @IBOutlet var hotkeyView2: HotkeyView!
    @IBOutlet var dropdown2: NSPopUpButton!

    @IBOutlet var hotkeyView3: HotkeyView!
    @IBOutlet var dropdown3: NSPopUpButton!

    @IBOutlet var backingView: NSView!

    var onClick: (() -> Void)?
    var onDropdownSelect: ((NSPopUpButton) -> Void)?
    @objc dynamic weak var display: Display?

    var hotkey1: PersistentHotkey?
    var hotkey2: PersistentHotkey?
    var hotkey3: PersistentHotkey?

    override func viewDidLoad() {
        backingView.radius = 8.ns

        if let display {
            setup(from: display)
        }

        super.viewDidLoad()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        view.window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }

    @objc func handler1() {
        guard let display else { return }
        switchInput(
            to: display.hotkeyInput1,
            brightness: display.brightnessOnInputChange1,
            contrast: display.contrastOnInputChange1,
            applyBrightnessContrast: display.applyBrightnessOnInputChange1
        )
    }

    @objc func handler2() {
        guard let display else { return }
        switchInput(
            to: display.hotkeyInput2,
            brightness: display.brightnessOnInputChange2,
            contrast: display.contrastOnInputChange2,
            applyBrightnessContrast: display.applyBrightnessOnInputChange2
        )
    }

    @objc func handler3() {
        guard let display else { return }
        switchInput(
            to: display.hotkeyInput3,
            brightness: display.brightnessOnInputChange3,
            contrast: display.contrastOnInputChange3,
            applyBrightnessContrast: display.applyBrightnessOnInputChange3
        )
    }

    func switchInput(to input: NSNumber, brightness: Double, contrast: Double, applyBrightnessContrast: Bool) {
        // #if DEBUG
        //     log.verbose("TRYING CHANGE TO INPUT \(input) ON DISPLAY \(display)")
        // #endif
        guard let display, input.uint16Value != VideoInputSource.unknown.rawValue else { return }

        // #if DEBUG
        //     log.verbose("CHANGING TO INPUT \(input) ON DISPLAY \(display)")
        //     return
        // #endif

        display.withoutSmoothTransition {
            if applyBrightnessContrast {
                display.adaptivePaused = true
                display.withoutDDC {
                    display.brightness = brightness.ns
                    display.contrast = contrast.ns
                }

                _ = display.control?.setBrightness(
                    display.limitedBrightness,
                    oldValue: nil,
                    force: false,
                    transition: .instant,
                    onChange: nil
                )
                _ = display.control?.setContrast(display.limitedContrast, oldValue: nil, transition: .instant, onChange: nil)
                mainAsyncAfter(ms: 1000) {
                    display.input = input
                }
                return
            }
            display.input = input
        }
    }

    func setup(from display: Display) {
        #if DEBUG
            log.info("Trying to setup \(self) from \(display)")
        #endif

        mainThread {
            self.display = display
        }

        let identifier1 = display.hotkeyIdentifiers[0]
        // log.debug("Setting identifier for \(display): \(identifier1)")

        hotkey1 = CachedDefaults[.hotkeys].first(where: { $0.identifier == identifier1 })?
            .with(handler: { [weak self] _ in self?.handler1() }) ??
            PersistentHotkey(
                hotkey: Magnet.HotKey(
                    identifier: identifier1,
                    keyCombo: KeyCombo(key: .one, cocoaModifiers: [.control, .option])!,
                    target: self,
                    action: #selector(HotkeyPopoverController.handler1),
                    actionQueue: .main
                ),
                isEnabled: false
            )
        hotkey1?.handleRegistration(persist: false)
        mainThread {
            if let hotkeyView = hotkeyView1 {
                hotkeyView.hotkey = hotkey1
                hotkeyView.endRecording()
            }
        }

        let identifier2 = display.hotkeyIdentifiers[1]
        // log.debug("Setting identifier for \(display): \(identifier2)")

        hotkey2 = CachedDefaults[.hotkeys].first(where: { $0.identifier == identifier2 })?
            .with(handler: { [weak self] _ in self?.handler2() }) ??
            PersistentHotkey(
                hotkey: Magnet.HotKey(
                    identifier: identifier2,
                    keyCombo: KeyCombo(key: .two, cocoaModifiers: [.control, .option])!,
                    target: self,
                    action: #selector(HotkeyPopoverController.handler2),
                    actionQueue: .main
                ),
                isEnabled: false
            )
        hotkey2?.handleRegistration(persist: false)

        mainThread {
            if let hotkeyView = hotkeyView2 {
                hotkeyView.hotkey = hotkey2
                hotkeyView.endRecording()
            }
        }
        let identifier3 = display.hotkeyIdentifiers[2]
        // log.debug("Setting identifier for \(display): \(identifier3)")

        hotkey3 = CachedDefaults[.hotkeys].first(where: { $0.identifier == identifier3 })?
            .with(handler: { [weak self] _ in self?.handler3() }) ??
            PersistentHotkey(
                hotkey: Magnet.HotKey(
                    identifier: identifier3,
                    keyCombo: KeyCombo(key: .three, cocoaModifiers: [.control, .option])!,
                    target: self,
                    action: #selector(HotkeyPopoverController.handler3),
                    actionQueue: .main
                ),
                isEnabled: false
            )
        hotkey3?.handleRegistration(persist: false)
        mainThread {
            if let hotkeyView = hotkeyView3 {
                hotkeyView.hotkey = hotkey3
                hotkeyView.endRecording()
            }
        }
    }

    @IBAction func selectItem(_ sender: NSPopUpButton) {
        onDropdownSelect?(sender)
    }
}
