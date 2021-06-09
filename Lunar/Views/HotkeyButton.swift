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
    var hotkey: PersistentHotkey?

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

    @objc func handler() {
        guard let display = display, display.hotkeyInput.uint8Value != InputSource.unknown.rawValue else { return }
        let inputBrightness = CachedDefaults[.brightnessOnInputChange]
        let inputContrast = CachedDefaults[.contrastOnInputChange]
        display.withoutSmoothTransition {
            display.withoutDDC {
                display.brightness = inputBrightness.ns
                display.contrast = inputContrast.ns
            }
            _ = display.control.setBrightness(inputBrightness.u8, oldValue: nil)
            _ = display.control.setContrast(inputContrast.u8, oldValue: nil)
            display.input = display.hotkeyInput
        }
    }

    func setup(from display: Display) {
        guard let controller = popoverController else { return }

        self.display = display
        POPOVERS[display.serial] = _popover
        controller.setup(from: display)

        controller.hotkeyLabel.stringValue = "Input Hotkey for \(display.name)"
        controller.onDropdownSelect = { [weak self] dropdown in
            guard let input = InputSource(rawValue: dropdown.selectedTag().u8), let display = self?.display else { return }
            display.hotkeyInput = input.rawValue.ns
        }
        controller.dropdown.removeAllItems()
        controller.dropdown
            .addItems(
                withTitles: InputSource.mostUsed
                    .map { input in input.str } + InputSource.leastUsed
                    .map { input in input.str } + ["Unknown"]
            )

        controller.dropdown.menu?.insertItem(.separator(), at: InputSource.mostUsed.count)
        for item in controller.dropdown.itemArray {
            guard let input = inputSourceMapping[item.title] else { continue }
            item.tag = input.rawValue.i

            if input == .unknown {
                item.isEnabled = false
                item.isHidden = true
                item.title = "Select input"
            }
        }
        controller.dropdown.selectItem(withTag: display.hotkeyInput.intValue)

        let identifier = "toggle-last-input-\(display.serial)"
        log.debug("Setting identifier for \(display.name): \(identifier)")
        hotkey = CachedDefaults[.hotkeys].first(where: { $0.identifier == identifier })?.with(target: self, action: #selector(HotkeyButton.handler)) ??
            PersistentHotkey(
                hotkey: Magnet
                    .HotKey(
                        identifier: identifier,
                        keyCombo: KeyCombo(key: .zero, cocoaModifiers: [.control, .option])!,
                        target: self,
                        action: #selector(HotkeyButton.handler),
                        actionQueue: .main
                    ),
                isEnabled: false
            )
        hotkey?.handleRegistration(persist: false)
        if let hotkeyView = controller.hotkeyView {
            hotkeyView.hotkey = hotkey
            hotkeyView.endRecording()
        }
    }

    deinit {
        guard let display = display else { return }
        POPOVERS.removeValue(forKey: display.serial)
    }

    override func mouseDown(with event: NSEvent) {
        guard let popover = _popover, isEnabled else { return }
        handlePopoverClick(popover, with: event)
        window?.makeFirstResponder(popoverController?.dropdown)
    }
}
