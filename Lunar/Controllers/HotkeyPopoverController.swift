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

class HotkeyPopoverController: NSViewController {
    @IBOutlet var hotkeyLabel1: NSBox!
    @IBOutlet var hotkeyView1: HotkeyView!
    @IBOutlet var dropdown1: NSPopUpButton!
    @IBOutlet var scrollableBrightnessField1: ScrollableTextField!
    @IBOutlet var scrollableContrastField1: ScrollableTextField!
    @IBOutlet var scrollableBrightnessCaption1: ScrollableTextFieldCaption!
    @IBOutlet var scrollableContrastCaption1: ScrollableTextFieldCaption!

    @IBOutlet var hotkeyLabel2: NSBox!
    @IBOutlet var hotkeyView2: HotkeyView!
    @IBOutlet var dropdown2: NSPopUpButton!
    @IBOutlet var scrollableBrightnessField2: ScrollableTextField!
    @IBOutlet var scrollableContrastField2: ScrollableTextField!
    @IBOutlet var scrollableBrightnessCaption2: ScrollableTextFieldCaption!
    @IBOutlet var scrollableContrastCaption2: ScrollableTextFieldCaption!

    @IBOutlet var hotkeyLabel3: NSBox!
    @IBOutlet var hotkeyView3: HotkeyView!
    @IBOutlet var dropdown3: NSPopUpButton!
    @IBOutlet var scrollableBrightnessField3: ScrollableTextField!
    @IBOutlet var scrollableContrastField3: ScrollableTextField!
    @IBOutlet var scrollableBrightnessCaption3: ScrollableTextFieldCaption!
    @IBOutlet var scrollableContrastCaption3: ScrollableTextFieldCaption!

    @IBOutlet var backingView: NSView!

    var onClick: (() -> Void)?
    var onDropdownSelect: ((NSPopUpButton) -> Void)?
    weak var display: Display?

    var hotkey1: PersistentHotkey?
    var hotkey2: PersistentHotkey?
    var hotkey3: PersistentHotkey?

    @objc func handler1() {
        // #if DEBUG
        //     log.verbose("TRYING CHANGE TO INPUT 1 ON DISPLAY \(display)")
        // #endif
        guard let display = display, display.hotkeyInput1.uint8Value != InputSource.unknown.rawValue else { return }

        let inputBrightness = display.brightnessOnInputChange1
        let inputContrast = display.contrastOnInputChange1

        // #if DEBUG
        //     log.verbose("CHANGING TO INPUT 1 ON DISPLAY \(display)")
        //     return
        // #endif

        display.withoutSmoothTransition {
            display.withoutDDC {
                display.brightness = inputBrightness
                display.contrast = inputContrast
            }
            _ = display.control?.setBrightness(inputBrightness.uint8Value, oldValue: nil)
            _ = display.control?.setContrast(inputContrast.uint8Value, oldValue: nil)
            display.input = display.hotkeyInput1
        }
    }

    @objc func handler2() {
        // #if DEBUG
        //     log.verbose("TRYING CHANGE TO INPUT 2 ON DISPLAY \(display)")
        // #endif
        guard let display = display, display.hotkeyInput2.uint8Value != InputSource.unknown.rawValue else { return }

        let inputBrightness = display.brightnessOnInputChange2
        let inputContrast = display.contrastOnInputChange2

        // #if DEBUG
        //     log.verbose("CHANGING TO INPUT 2 ON DISPLAY \(display)")
        //     return
        // #endif

        display.withoutSmoothTransition {
            display.withoutDDC {
                display.brightness = inputBrightness
                display.contrast = inputContrast
            }
            _ = display.control?.setBrightness(inputBrightness.uint8Value, oldValue: nil)
            _ = display.control?.setContrast(inputContrast.uint8Value, oldValue: nil)
            display.input = display.hotkeyInput2
        }
    }

    @objc func handler3() {
        // #if DEBUG
        //     log.verbose("TRYING CHANGE TO INPUT 3 ON DISPLAY \(display)")
        // #endif
        guard let display = display, display.hotkeyInput3.uint8Value != InputSource.unknown.rawValue else { return }

        let inputBrightness = display.brightnessOnInputChange3
        let inputContrast = display.contrastOnInputChange3

        // #if DEBUG
        //     log.verbose("CHANGING TO INPUT 3 ON DISPLAY \(display)")
        //     return
        // #endif

        display.withoutSmoothTransition {
            display.withoutDDC {
                display.brightness = inputBrightness
                display.contrast = inputContrast
            }
            _ = display.control?.setBrightness(inputBrightness.uint8Value, oldValue: nil)
            _ = display.control?.setContrast(inputContrast.uint8Value, oldValue: nil)
            display.input = display.hotkeyInput3
        }
    }

    func setup(from display: Display) {
        #if DEBUG
            log.info("Trying to setup \(self) from \(display)")
        #endif
        self.display = display

        mainThread {
            scrollableBrightnessField1?.integerValue = display.brightnessOnInputChange1.intValue
            scrollableContrastField1?.integerValue = display.contrastOnInputChange1.intValue
            scrollableBrightnessField1?.onValueChanged = { [weak self] value in
                guard let self = self else { return }
                self.display?.brightnessOnInputChange1 = value.ns
            }
            scrollableContrastField1?.onValueChanged = { [weak self] value in
                guard let self = self else { return }
                self.display?.contrastOnInputChange1 = value.ns
            }

            scrollableBrightnessField2?.integerValue = display.brightnessOnInputChange2.intValue
            scrollableContrastField2?.integerValue = display.contrastOnInputChange2.intValue
            scrollableBrightnessField2?.onValueChanged = { [weak self] value in
                guard let self = self else { return }
                self.display?.brightnessOnInputChange2 = value.ns
            }
            scrollableContrastField2?.onValueChanged = { [weak self] value in
                guard let self = self else { return }
                self.display?.contrastOnInputChange2 = value.ns
            }

            scrollableBrightnessField3?.integerValue = display.brightnessOnInputChange3.intValue
            scrollableContrastField3?.integerValue = display.contrastOnInputChange3.intValue
            scrollableBrightnessField3?.onValueChanged = { [weak self] value in
                guard let self = self else { return }
                self.display?.brightnessOnInputChange3 = value.ns
            }
            scrollableContrastField3?.onValueChanged = { [weak self] value in
                guard let self = self else { return }
                self.display?.contrastOnInputChange3 = value.ns
            }

            hotkeyLabel1?.title = "Input Hotkey 1 for \(display.name)"
            hotkeyLabel2?.title = "Input Hotkey 2 for \(display.name)"
            hotkeyLabel3?.title = "Input Hotkey 3 for \(display.name)"
        }

        let identifier1 = display.hotkeyIdentifiers[0]
        log.debug("Setting identifier for \(display): \(identifier1)")

        hotkey1 = CachedDefaults[.hotkeys].first(where: { $0.identifier == identifier1 })?
            .with(handler: { [weak self] _ in self?.handler1() }) ??
            PersistentHotkey(
                hotkey: Magnet.HotKey(
                    identifier: identifier1,
                    keyCombo: KeyCombo(key: .zero, cocoaModifiers: [.control, .option])!,
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
        log.debug("Setting identifier for \(display): \(identifier2)")

        hotkey2 = CachedDefaults[.hotkeys].first(where: { $0.identifier == identifier2 })?
            .with(handler: { [weak self] _ in self?.handler2() }) ??
            PersistentHotkey(
                hotkey: Magnet.HotKey(
                    identifier: identifier2,
                    keyCombo: KeyCombo(key: .zero, cocoaModifiers: [.control, .option])!,
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
        log.debug("Setting identifier for \(display): \(identifier3)")

        hotkey3 = CachedDefaults[.hotkeys].first(where: { $0.identifier == identifier3 })?
            .with(handler: { [weak self] _ in self?.handler3() }) ??
            PersistentHotkey(
                hotkey: Magnet.HotKey(
                    identifier: identifier3,
                    keyCombo: KeyCombo(key: .zero, cocoaModifiers: [.control, .option])!,
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

    deinit {
        #if DEBUG
            log.verbose("START DEINIT: \(display?.description ?? "no display")")
            do { log.verbose("END DEINIT: \(display?.description ?? "no display")") }
        #endif

        hotkey1?.unregister()
        hotkey2?.unregister()
        hotkey3?.unregister()
    }

    override func viewDidLoad() {
        backingView.radius = 8.ns

        scrollableBrightnessField1.caption = scrollableBrightnessCaption1
        scrollableContrastField1.caption = scrollableContrastCaption1

        scrollableBrightnessField2.caption = scrollableBrightnessCaption2
        scrollableContrastField2.caption = scrollableContrastCaption2

        scrollableBrightnessField3.caption = scrollableBrightnessCaption3
        scrollableContrastField3.caption = scrollableContrastCaption3

        scrollableBrightnessField1.onValueChanged = { [weak self] in self?.display?.brightnessOnInputChange1 = $0.ns }
        scrollableContrastField1.onValueChanged = { [weak self] in self?.display?.contrastOnInputChange1 = $0.ns }

        scrollableBrightnessField2.onValueChanged = { [weak self] in self?.display?.brightnessOnInputChange2 = $0.ns }
        scrollableContrastField2.onValueChanged = { [weak self] in self?.display?.contrastOnInputChange2 = $0.ns }

        scrollableBrightnessField3.onValueChanged = { [weak self] in self?.display?.brightnessOnInputChange3 = $0.ns }
        scrollableContrastField3.onValueChanged = { [weak self] in self?.display?.contrastOnInputChange3 = $0.ns }

        if let display = display {
            scrollableBrightnessField1.integerValue = display.brightnessOnInputChange1.intValue
            scrollableContrastField1.integerValue = display.contrastOnInputChange1.intValue

            scrollableBrightnessField2.integerValue = display.brightnessOnInputChange2.intValue
            scrollableContrastField2.integerValue = display.contrastOnInputChange2.intValue

            scrollableBrightnessField3.integerValue = display.brightnessOnInputChange3.intValue
            scrollableContrastField3.integerValue = display.contrastOnInputChange3.intValue
        }

        for field in [
            scrollableBrightnessField1, scrollableContrastField1,
            scrollableBrightnessField2, scrollableContrastField2,
            scrollableBrightnessField3, scrollableContrastField3,
        ] {
            field!.textFieldColor = scrollableTextFieldColorOnBlack
            field!.textFieldColorHover = scrollableTextFieldColorHoverOnBlack
            field!.textFieldColorLight = scrollableTextFieldColorLightOnBlack
            field!.caption!.textColor = scrollableCaptionColorOnBlack
        }

        if let display = display {
            setup(from: display)
        }

        super.viewDidLoad()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        view.window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }

    @IBAction func selectItem(_ sender: NSPopUpButton) {
        onDropdownSelect?(sender)
    }
}
