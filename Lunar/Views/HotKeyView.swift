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
    var hotkey: PersistentHotkey? {
        didSet {
            mainThread {
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
    }

    var preciseHotkeyCheckbox: NSButton? {
        didSet {
            guard let checkbox = preciseHotkeyCheckbox,
                  let hk = hotkey
            else { return }

            let hotkeys = CachedDefaults[.hotkeys]
            guard let preciseIdentifier = preciseHotkeysMapping[hk.identifier],
                  let preciseHotkey = hotkeys.first(where: { $0.identifier == preciseIdentifier })
            else {
                return
            }
            checkbox.state = NSControl.StateValue(rawValue: preciseHotkey.isEnabled.i)
            checkbox.isEnabled = isHotkeyCheckboxEnabled(hk)
            checkbox.toolTip = hotkeyCheckboxTooltip(hk)
        }
    }

    var hotkeyEnabled: Bool {
        hotkey?.isEnabled ?? false
    }

    func recordViewShouldBeginRecording(_: RecordView) -> Bool {
        log.debug("Begin hotkey recording: \(hotkey?.identifier ?? "")")
        PersistentHotkey.isRecording = true
        transition()
        return true
    }

    func recordView(_: RecordView, canRecordKeyCombo combo: KeyCombo) -> Bool {
        log.debug("Can record combo: \(combo.QWERTYKeyCode) doubledMod: \(combo.doubledModifiers)")
        PersistentHotkey.isRecording = true
        if combo.QWERTYKeyCode == Key.space.QWERTYKeyCode {
            return false
        }
        return !combo.doubledModifiers
    }

    func recordViewDidEndRecording(_: RecordView) {
        log.debug("End hotkey recording: \(hotkey?.identifier ?? "")")
        PersistentHotkey.isRecording = false
        transition()
    }

    func recordView(_: RecordView, didChangeKeyCombo keyCombo: KeyCombo?) {
        log.debug("Changed hotkey for \(hotkey?.identifier ?? "")")

        guard let hotkey = hotkey else { return }
        guard let keyCombo = keyCombo else {
            hotkey.isEnabled = false
            preciseHotkeyCheckbox?.isEnabled = false

            return
        }

        hotkey.unregister()
        if let oldHotkey = CachedDefaults[.hotkeys].first(where: {
            $0.identifier != hotkey.identifier &&
                $0.keyCombo == hotkey.keyCombo &&
                $0.modifiers == hotkey.modifiers
        }) {
            log.info("Found another hotkey with the same combo, removing it: \(oldHotkey.identifier)")
            oldHotkey.unregister()
            CachedDefaults[.hotkeys] = CachedDefaults[.hotkeys].filter { $0.identifier != oldHotkey.identifier }
        }

        if let target = hotkey.target, let action = hotkey.action {
            hotkey.hotkey = HotKey(identifier: hotkey.identifier, keyCombo: keyCombo, target: target, action: action, actionQueue: .main)
        } else {
            hotkey.hotkey = HotKey(identifier: hotkey.identifier, keyCombo: keyCombo, actionQueue: .main, handler: hotkey.handler!)
        }
        hotkey.isEnabled = true

        guard let checkbox = preciseHotkeyCheckbox else {
            return
        }

        if NSEvent.ModifierFlags(carbonModifiers: keyCombo.modifiers).contains(.option) {
            checkbox.isEnabled = false
            checkbox.toolTip = fineAdjustmentDisabledBecauseOfOptionKey
        } else {
            checkbox.isEnabled = true
            checkbox.toolTip = nil
            if let preciseIdentifier = preciseHotkeysMapping[hotkey.identifier],
               let hotkey = CachedDefaults[.hotkeys].first(where: { $0.identifier == preciseIdentifier }),
               let kc = KeyCombo(
                   QWERTYKeyCode: keyCombo.QWERTYKeyCode,
                   cocoaModifiers: keyCombo.keyEquivalentModifierMask.union([.option])
               )
            {
                hotkey.unregister()
                if let target = hotkey.target, let action = hotkey.action {
                    hotkey.hotkey = HotKey(identifier: preciseIdentifier, keyCombo: kc, target: target, action: action, actionQueue: .main)
                } else if let handler = hotkey.handler {
                    hotkey.hotkey = HotKey(identifier: preciseIdentifier, keyCombo: kc, actionQueue: .main, handler: handler)
                }
                hotkey.isEnabled = true
                hotkey.register()
            }
        }
    }

    override open func mouseDown(with _: NSEvent) {
        log.debug("Clicked on hotkey view: \(hotkey?.identifier ?? "")")
        beginRecording()
        transition()
    }

    override func didChangeValue(forKey key: String) {
        if key == "recording" {
            transition()
            if isRecording {
                hotkey?.unregister()
            } else if hotkeyEnabled {
                hotkey?.register()
            }
        }
    }

    func isHotkeyCheckboxEnabled(_ hk: PersistentHotkey) -> Bool {
        hk.isEnabled && !NSEvent.ModifierFlags(carbonModifiers: hk.modifiers).contains(.option)
    }

    func hotkeyCheckboxTooltip(_ hk: PersistentHotkey) -> String? {
        if NSEvent.ModifierFlags(carbonModifiers: hk.modifiers).contains(.option) {
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
        transition(0.2)
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
        radius = 8.ns
        super.draw(dirtyRect)
    }
}
