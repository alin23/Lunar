//
//  HotkeyView.swift
//  Lunar
//
//  Created by Alin on 24/02/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa
import Defaults
import KeyHolder
import Magnet
import Sauce

class HotkeyView: RecordView, RecordViewDelegate {
    var hoverState: HoverState = .noHover
    var hotkey: PersistentHotkey! {
        didSet {
            if let h = hotkey {
                keyCombo = h.keyCombo
                if hotkeyEnabled {
                    tintColor = hotkeyColor[hoverState]!["tint"]!
                } else {
                    tintColor = hotkeyColor[hoverState]!["tintDisabled"]!
                }
            } else {
                keyCombo = nil
                tintColor = hotkeyColor[hoverState]!["tintDisabled"]!
            }
        }
    }

    var preciseHotkeyCheckbox: NSButton? {
        didSet {
            guard let checkbox = preciseHotkeyCheckbox,
                  let hk = hotkey
            else { return }

            let hotkeys = Defaults[.hotkeys]
            if let coarseHk = hotkeys[hk.identifier], let preciseIdentifier = preciseHotkeysMapping[hk.identifier],
               let preciseHk = hotkeys[preciseIdentifier]
            {
                checkbox.state = NSControl.StateValue(rawValue: preciseHk[.enabled] ?? Hotkey.defaults[hk.identifier]?[.enabled] ?? 0)
                checkbox.isEnabled = isHotkeyCheckboxEnabled(coarseHk)
                checkbox.toolTip = hotkeyCheckboxTooltip(coarseHk)
            }
        }
    }

    var hotkeyEnabled: Bool {
        let hotkeys = Defaults[.hotkeys]
        if let hk = hotkey,
           let hotkey = (hotkeys[hk.identifier] ?? Hotkey.defaults[hk.identifier])
        {
            return (hotkey[.enabled] ?? 0) == 1
        }
        return false
    }

    func recordViewShouldBeginRecording(_: RecordView) -> Bool {
        log.debug("Begin hotkey recording: \(hotkey?.identifier ?? "")")
        return true
    }

    func recordView(_: RecordView, canRecordKeyCombo combo: KeyCombo) -> Bool {
        log.debug("Can record combo: \(combo.QWERTYKeyCode) doubledMod: \(combo.doubledModifiers)")
        if combo.QWERTYKeyCode == Key.space.QWERTYKeyCode {
            return false
        }
        return !combo.doubledModifiers
    }

    func recordViewDidEndRecording(_: RecordView) {
        log.debug("End hotkey recording: \(hotkey?.identifier ?? "")")
    }

    func recordView(_: RecordView, didChangeKeyCombo keyCombo: KeyCombo?) {
        log.debug("Changed hotkey for \(hotkey?.identifier ?? "") with \(keyCombo?.keyEquivalent ?? "no hotkey")")

        hotkey.unregister()
        guard let keyCombo = keyCombo else {
            hotkey.isEnabled = false
            preciseHotkeyCheckbox?.isEnabled = false

            return
        }
        if let target = hotkey.target, let action = hotkey.action {
            hotkey.hotkey = HotKey(identifier: hotkey.identifier, keyCombo: keyCombo, target: target, action: action)
        } else {
            hotkey.hotkey = HotKey(identifier: hotkey.identifier, keyCombo: keyCombo, handler: hotkey.handler!)
        }
        hotkey.isEnabled = true

        if let checkbox = preciseHotkeyCheckbox {
            if keyCombo.modifiers.convertSupportCocoaModifiers().contains(.option) {
                checkbox.isEnabled = false
                checkbox.toolTip = fineAdjustmentDisabledBecauseOfOptionKey
            } else {
                checkbox.isEnabled = true
                checkbox.toolTip = nil
            }
        }
    }

    override open func mouseDown(with _: NSEvent) {
        log.debug("Clicked on hotkey view: \(hotkey?.identifier ?? "")")
        beginRecording()
    }

    override func didChangeValue(forKey key: String) {
        if key == "recording" {
            transition()
            if isRecording {
                hotkey.unregister()
            } else if hotkeyEnabled {
                hotkey.register()
            }
        }
    }

    func isHotkeyCheckboxEnabled(_ hk: [HotkeyPart: Int]) -> Bool {
        (hk[.enabled] ?? 1) == 1 && !(hk[.modifiers] ?? 0).convertSupportCocoaModifiers().contains(.option)
    }

    func hotkeyCheckboxTooltip(_ hk: [HotkeyPart: Int]) -> String? {
        if (hk[.modifiers] ?? 0).convertSupportCocoaModifiers().contains(.option) {
            return fineAdjustmentDisabledBecauseOfOptionKey
        } else {
            return nil
        }
    }

    func setup() {
        delegate = self
        borderColor = NSColor.clear
        backgroundColor = hotkeyColor[hoverState]!["background"]!
        tintColor = hotkeyColor[hoverState]!["tint"]!
        cornerRadius = 8
        addTrackingRect(visibleRect, owner: self, userData: nil, assumeInside: false)
    }

    func transition() {
        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        backgroundColor = hotkeyColor[hoverState]!["background"]!
        if isRecording {
            tintColor = hotkeyColor[hoverState]!["tintRecording"]!
        } else if !hotkeyEnabled {
            tintColor = hotkeyColor[hoverState]!["tintDisabled"]!
        } else {
            tintColor = hotkeyColor[hoverState]!["tint"]!
        }
    }

    override func mouseEntered(with _: NSEvent) {
        hoverState = .hover
        transition()
    }

    override func mouseExited(with _: NSEvent) {
        hoverState = .noHover
        transition()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func draw(_ dirtyRect: NSRect) {
        layer?.cornerRadius = 8
        super.draw(dirtyRect)
    }
}
