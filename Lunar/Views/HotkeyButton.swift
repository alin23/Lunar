//
//  HotkeyButton.swift
//  Lunar
//
//  Created by Alin Panaitiu on 23.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Foundation
import Magnet

class HotkeyButton: PopoverButton<HotkeyPopoverController> {
    var _popover: NSPopover?
    weak var display: Display?
    var hotkey1: PersistentHotkey?
    var hotkey2: PersistentHotkey?
    var hotkey3: PersistentHotkey?

    override var popoverController: HotkeyPopoverController? {
        guard let popover = _popover else {
            _popover = NSPopover()
            if let popover = _popover, popover.contentViewController == nil, let stb = NSStoryboard.main,
               let controller = stb.instantiateController(
                   withIdentifier: NSStoryboard.SceneIdentifier("HotkeyPopoverController")
               ) as? HotkeyPopoverController
            {
                popover.contentViewController = controller
                popover.contentViewController!.loadView()
                popover.appearance = NSAppearance(named: .vibrantDark)
            }

            return _popover?.contentViewController as? HotkeyPopoverController
        }
        return popover.contentViewController as? HotkeyPopoverController
    }

    @objc func handler1() {
        guard let display = display, display.hotkeyInput1.uint8Value != InputSource.unknown.rawValue else { return }

        let inputBrightness = display.brightnessOnInputChange1
        let inputContrast = display.contrastOnInputChange1

        display.withoutSmoothTransition {
            display.withoutDDC {
                display.brightness = inputBrightness
                display.contrast = inputContrast
            }
            _ = display.control.setBrightness(inputBrightness.uint8Value, oldValue: nil)
            _ = display.control.setContrast(inputContrast.uint8Value, oldValue: nil)
            display.input = display.hotkeyInput1
        }
    }

    @objc func handler2() {
        guard let display = display, display.hotkeyInput2.uint8Value != InputSource.unknown.rawValue else { return }

        let inputBrightness = display.brightnessOnInputChange2
        let inputContrast = display.contrastOnInputChange2

        display.withoutSmoothTransition {
            display.withoutDDC {
                display.brightness = inputBrightness
                display.contrast = inputContrast
            }
            _ = display.control.setBrightness(inputBrightness.uint8Value, oldValue: nil)
            _ = display.control.setContrast(inputContrast.uint8Value, oldValue: nil)
            display.input = display.hotkeyInput2
        }
    }

    @objc func handler3() {
        guard let display = display, display.hotkeyInput3.uint8Value != InputSource.unknown.rawValue else { return }

        let inputBrightness = display.brightnessOnInputChange3
        let inputContrast = display.contrastOnInputChange3

        display.withoutSmoothTransition {
            display.withoutDDC {
                display.brightness = inputBrightness
                display.contrast = inputContrast
            }
            _ = display.control.setBrightness(inputBrightness.uint8Value, oldValue: nil)
            _ = display.control.setContrast(inputContrast.uint8Value, oldValue: nil)
            display.input = display.hotkeyInput3
        }
    }

    func setup(from display: Display) {
        guard let controller = popoverController else { return }

        self.display = display
        POPOVERS[display.serial] = _popover
        controller.setup(from: display)

        controller.hotkeyLabel1.title = "Input Hotkey 1 for \(display.name)"
        controller.hotkeyLabel2.title = "Input Hotkey 2 for \(display.name)"
        controller.hotkeyLabel3.title = "Input Hotkey 3 for \(display.name)"

        controller.onDropdownSelect = { [weak self] dropdown in
            guard let input = InputSource(rawValue: dropdown.selectedTag().u8), let display = self?.display else { return }
            switch dropdown.tag {
            case 1:
                display.hotkeyInput1 = input.rawValue.ns
            case 2:
                display.hotkeyInput2 = input.rawValue.ns
            case 3:
                display.hotkeyInput3 = input.rawValue.ns
            default:
                break
            }
        }

        for dropdown in [controller.dropdown1, controller.dropdown2, controller.dropdown3] {
            guard let dropdown = dropdown else { continue }
            dropdown.removeAllItems()
            dropdown.addItems(
                withTitles: InputSource.mostUsed
                    .map { input in input.str } + InputSource.leastUsed
                    .map { input in input.str } + ["Unknown"]
            )

            dropdown.menu?.insertItem(.separator(), at: InputSource.mostUsed.count)
            for item in dropdown.itemArray {
                guard let input = inputSourceMapping[item.title] else { continue }
                item.tag = input.rawValue.i

                if input == .unknown {
                    item.isEnabled = true
                    item.isHidden = true
                    item.title = "Select input"
                }
            }
            switch dropdown.tag {
            case 1:
                dropdown.selectItem(withTag: display.hotkeyInput1.intValue)
            case 2:
                dropdown.selectItem(withTag: display.hotkeyInput2.intValue)
            case 3:
                dropdown.selectItem(withTag: display.hotkeyInput3.intValue)
            default:
                break
            }
        }

        let identifier1 = "toggle-last-input-\(display.serial)"
        log.debug("Setting identifier for \(display.name): \(identifier1)")

        hotkey1 = CachedDefaults[.hotkeys].first(where: { $0.identifier == identifier1 })?.with(target: self, action: #selector(HotkeyButton.handler1)) ??
            PersistentHotkey(
                hotkey: Magnet.HotKey(
                    identifier: identifier1,
                    keyCombo: KeyCombo(key: .zero, cocoaModifiers: [.control, .option])!,
                    target: self,
                    action: #selector(HotkeyButton.handler1),
                    actionQueue: .main
                ),
                isEnabled: false
            )
        hotkey1?.handleRegistration(persist: false)
        if let hotkeyView = controller.hotkeyView1 {
            hotkeyView.hotkey = hotkey1
            hotkeyView.endRecording()
        }

        let identifier2 = "toggle-last-input2-\(display.serial)"
        log.debug("Setting identifier for \(display.name): \(identifier2)")

        hotkey2 = CachedDefaults[.hotkeys].first(where: { $0.identifier == identifier2 })?.with(target: self, action: #selector(HotkeyButton.handler2)) ??
            PersistentHotkey(
                hotkey: Magnet.HotKey(
                    identifier: identifier2,
                    keyCombo: KeyCombo(key: .zero, cocoaModifiers: [.control, .option])!,
                    target: self,
                    action: #selector(HotkeyButton.handler2),
                    actionQueue: .main
                ),
                isEnabled: false
            )
        hotkey2?.handleRegistration(persist: false)
        if let hotkeyView = controller.hotkeyView2 {
            hotkeyView.hotkey = hotkey2
            hotkeyView.endRecording()
        }

        let identifier3 = "toggle-last-input3-\(display.serial)"
        log.debug("Setting identifier for \(display.name): \(identifier3)")

        hotkey3 = CachedDefaults[.hotkeys].first(where: { $0.identifier == identifier3 })?.with(target: self, action: #selector(HotkeyButton.handler3)) ??
            PersistentHotkey(
                hotkey: Magnet.HotKey(
                    identifier: identifier3,
                    keyCombo: KeyCombo(key: .zero, cocoaModifiers: [.control, .option])!,
                    target: self,
                    action: #selector(HotkeyButton.handler3),
                    actionQueue: .main
                ),
                isEnabled: false
            )
        hotkey3?.handleRegistration(persist: false)
        if let hotkeyView = controller.hotkeyView3 {
            hotkeyView.hotkey = hotkey3
            hotkeyView.endRecording()
        }
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        guard let display = display else { return }
        POPOVERS.removeValue(forKey: display.serial)
    }

    override func mouseDown(with event: NSEvent) {
        guard let popover = _popover, isEnabled else { return }
        handlePopoverClick(popover, with: event)
        window?.makeFirstResponder(popoverController?.dropdown1)
    }
}
