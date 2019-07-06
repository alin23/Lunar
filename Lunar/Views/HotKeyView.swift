//
//  HotkeyView.swift
//  Lunar
//
//  Created by Alin on 24/02/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Carbon.HIToolbox
import KeyHolder
import Magnet

class HotkeyView: RecordView, RecordViewDelegate {
    var hoverState: HoverState = .noHover
    var hotkey: HotKey! {
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

    var hotkeyEnabled: Bool {
        if let hotkeys = datastore.hotkeys(), let identifier = HotkeyIdentifier(rawValue: self.hotkey.identifier) {
            return (hotkeys[identifier]?[.enabled] ?? 0) == 1
        }
        return false
    }

    func recordViewShouldBeginRecording(_: RecordView) -> Bool {
        return true
    }

    func recordView(_: RecordView, canRecordKeyCombo combo: KeyCombo) -> Bool {
        if combo.keyCode == kVK_Space {
            return false
        }
        return !combo.doubledModifiers
    }

    func recordViewDidClearShortcut(_: RecordView) {
        hotkey.unregister()
        if var hotkeys = datastore.hotkeys(), let identifier = HotkeyIdentifier(rawValue: self.hotkey.identifier) {
            hotkeys[identifier]?[.enabled] = 0
            datastore.defaults.set(Hotkey.toNSDictionary(hotkeys), forKey: "hotkeys")
        }
    }

    func recordViewDidEndRecording(_: RecordView) {}

    func recordView(_: RecordView, didChangeKeyCombo keyCombo: KeyCombo) {
        hotkey.unregister()
        hotkey = HotKey(identifier: hotkey.identifier, keyCombo: keyCombo, target: hotkey.target!, action: hotkey.action!)
        hotkey.register()
        if var hotkeys = datastore.hotkeys(), let identifier = HotkeyIdentifier(rawValue: self.hotkey.identifier) {
            Hotkey.keys[identifier] = hotkey
            hotkeys[identifier]?[.enabled] = 1
            hotkeys[identifier]?[.modifiers] = keyCombo.modifiers
            hotkeys[identifier]?[.keyCode] = keyCombo.keyCode
            datastore.defaults.set(Hotkey.toNSDictionary(hotkeys), forKey: "hotkeys")
        }
    }

    open override func mouseDown(with theEvent: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: theEvent)
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
}
