//
//  Hotkeys.swift
//  Lunar
//
//  Created by Alin on 25/02/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import AnyCodable
import AppKit
import Carbon.HIToolbox
import Defaults
import Magnet
import MediaKeyTap
import Sauce
import SwiftUI

var upHotkey: Magnet.HotKey?
var downHotkey: Magnet.HotKey?
var leftHotkey: Magnet.HotKey?
var rightHotkey: Magnet.HotKey?

var mediaKeyTapBrightness = MediaKeyTap(delegate: appDelegate!, for: [.brightnessUp, .brightnessDown], observeBuiltIn: true)
var mediaKeyTapAudio = MediaKeyTap(delegate: appDelegate!, for: [.mute, .volumeUp, .volumeDown], observeBuiltIn: true)
let fineAdjustmentDisabledBecauseOfOptionKey = "Fine adjustment can't be enabled when the hotkey uses the Option key"

// MARK: - HotkeyIdentifier

enum HotkeyIdentifier: String, CaseIterable, Codable {
    case toggle,
         lunar,
         restart,
         percent0,
         percent25,
         percent50,
         percent75,
         percent100,
         faceLight,
         blackOut,
         blackOutPowerOff,
         blackOutNoMirroring,
         blackOutOthers,
         preciseBrightnessUp,
         preciseBrightnessDown,
         preciseContrastUp,
         preciseContrastDown,
         preciseVolumeUp,
         preciseVolumeDown,
         brightnessUp,
         brightnessDown,
         contrastUp,
         contrastDown,
         muteAudio,
         volumeUp,
         volumeDown,
         orientation0,
         orientation90,
         orientation180,
         orientation270
}

// MARK: - NSEvent.ModifierFlags + Hashable

extension NSEvent.ModifierFlags: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

let preciseHotkeys: Set<String> = [
    HotkeyIdentifier.preciseBrightnessUp.rawValue,
    HotkeyIdentifier.preciseBrightnessDown.rawValue,
    HotkeyIdentifier.preciseContrastUp.rawValue,
    HotkeyIdentifier.preciseContrastDown.rawValue,
    HotkeyIdentifier.preciseVolumeUp.rawValue,
    HotkeyIdentifier.preciseVolumeDown.rawValue,
]
let coarseHotkeysMapping: [String: String] = [
    HotkeyIdentifier.preciseBrightnessUp.rawValue: HotkeyIdentifier.brightnessUp.rawValue,
    HotkeyIdentifier.preciseBrightnessDown.rawValue: HotkeyIdentifier.brightnessDown.rawValue,
    HotkeyIdentifier.preciseContrastUp.rawValue: HotkeyIdentifier.contrastUp.rawValue,
    HotkeyIdentifier.preciseContrastDown.rawValue: HotkeyIdentifier.contrastDown.rawValue,
    HotkeyIdentifier.preciseVolumeUp.rawValue: HotkeyIdentifier.volumeUp.rawValue,
    HotkeyIdentifier.preciseVolumeDown.rawValue: HotkeyIdentifier.volumeDown.rawValue,
]
let alternateHotkeysMapping: [String: [NSEvent.ModifierFlags: String]] = [
    HotkeyIdentifier.blackOut.rawValue: [
        .option: HotkeyIdentifier.blackOutPowerOff.rawValue,
        .shift: HotkeyIdentifier.blackOutNoMirroring.rawValue,
        [.shift, .option]: HotkeyIdentifier.blackOutOthers.rawValue,
    ],
]
let preciseHotkeysMapping: [String: String] = [
    HotkeyIdentifier.brightnessUp.rawValue: HotkeyIdentifier.preciseBrightnessUp.rawValue,
    HotkeyIdentifier.brightnessDown.rawValue: HotkeyIdentifier.preciseBrightnessDown.rawValue,
    HotkeyIdentifier.contrastUp.rawValue: HotkeyIdentifier.preciseContrastUp.rawValue,
    HotkeyIdentifier.contrastDown.rawValue: HotkeyIdentifier.preciseContrastDown.rawValue,
    HotkeyIdentifier.volumeUp.rawValue: HotkeyIdentifier.preciseVolumeUp.rawValue,
    HotkeyIdentifier.volumeDown.rawValue: HotkeyIdentifier.preciseVolumeDown.rawValue,
]

// MARK: - HotkeyPart

enum HotkeyPart: String, CaseIterable, Defaults.Serializable {
    case modifiers
    case keyCode
    case enabled
    case allowsHold
}

// MARK: - OSDImage

enum OSDImage: Int64 {
    case brightness = 1
    case contrast = 11
    case volume = 3
    case muted = 4
}

var HOTKEY_HANDLERS = [String: (HotKey) -> Void](minimumCapacity: 10)

extension String {
    var hk: HotkeyIdentifier? {
        HotkeyIdentifier(rawValue: self)
    }
}

// MARK: - PersistentHotkey

final class PersistentHotkey: Codable, Hashable, Defaults.Serializable, CustomStringConvertible {
    init(_ identifier: String, dict hk: [HotkeyPart: Int], handler: ((HotKey) -> Void)? = nil) {
        let keyCode = hk[.keyCode]!
        let enabled = hk[.enabled]!
        let modifiers = hk[.modifiers]!
        var allowsHold = false
        if let hold = hk[.allowsHold] {
            allowsHold = hold == 1
        } else {
            allowsHold = Hotkey.allowHold(for: identifier.hk)
        }
        let keyCombo = KeyCombo(QWERTYKeyCode: keyCode, carbonModifiers: modifiers)!

        if let handler {
            hotkey = Magnet.HotKey(
                identifier: identifier,
                keyCombo: keyCombo,
                actionQueue: .main,
                detectKeyHold: allowsHold,
                handler: handler
            )
            isEnabled = enabled == 1
            if isEnabled {
                register()
            }
//            hotkey.detectKeyHold = allowsHold
            // log.debug("Created hotkey with handler \(identifier)")
            return
        }

        if let hkIdentifier = HotkeyIdentifier(rawValue: identifier) {
            hotkey = Magnet.HotKey(
                identifier: identifier,
                keyCombo: keyCombo,
                target: appDelegate!,
                action: Hotkey.handler(identifier: hkIdentifier),
                actionQueue: .main,
                detectKeyHold: allowsHold
            )
            isEnabled = enabled == 1
            if isEnabled {
                register()
            }
//            hotkey.detectKeyHold = allowsHold
            // log.debug("Created hotkey with action/target \(identifier)")
            return
        }

        hotkey = Magnet.HotKey(
            identifier: identifier,
            keyCombo: keyCombo,
            actionQueue: .main,
            detectKeyHold: allowsHold,
            handler: { hk in
                #if DEBUG
                    log.verbose("Pressed hotkey \(hk.identifier)")
                #endif
                guard let handler = HOTKEY_HANDLERS[hk.identifier] else {
                    if PersistentHotkey.isRecording {
                        log.info("We're in the handler of another hotkey with the same combo, removing it: \(hk.identifier)")
                        HotKeyCenter.shared.unregisterHotKey(with: hk.identifier)
                        CachedDefaults[.hotkeys] = CachedDefaults[.hotkeys].filter { $0.identifier != hk.identifier }
                    }
                    return
                }
                handler(hk)
            }
        )
        isEnabled = enabled == 1
        //            hotkey.detectKeyHold = allowsHold
    }

    // deinit {
    //     #if DEBUG
    //         log.verbose("START DEINIT: \(identifier)")
    //         do { log.verbose("END DEINIT: \(identifier)") }
    //     #endif
    // }

    init(hotkey: HotKey, isEnabled: Bool = true, register: Bool = true) {
        hotkey.detectKeyHold = Hotkey.allowHold(for: hotkey.identifier.hk)
        self.hotkey = hotkey
        self.isEnabled = isEnabled
        if register {
            handleRegistration(persist: false)
        }
    }

    required convenience init(from decoder: Decoder) throws {
        // log.debug("Initializing hotkey from decoder")
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let identifier = try container.decode(String.self, forKey: .identifier)
        // log.debug("Identifier: \(identifier)")
        let enabled = try container.decode(Bool.self, forKey: .enabled)
        // log.debug("Enabled: \(enabled)")
        let modifiers = try container.decode(Int.self, forKey: .modifiers)
        let keyCode = try container.decode(Int.self, forKey: .keyCode)
        let allowsHold = Hotkey.allowHold(for: identifier.hk)

        self.init(identifier, dict: [
            .enabled: enabled ? 1 : 0,
            .keyCode: keyCode,
            .modifiers: modifiers,
            .allowsHold: allowsHold ? 1 : 0,
        ])
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case identifier
        case keyCode
        case enabled
        case modifiers
        case allowsHold
    }

    @Atomic static var isRecording = false

    static let PRESET_PREFIX = "preset-"

    var allowsHold: Bool {
        get { hotkey.detectKeyHold }
        set { hotkey.detectKeyHold = newValue }
    }

    var description: String {
        "<PersistentHotkey \(identifier)[\(hotkeyString)]>"
    }

    var hotkeyString: String {
        mainThread {
            let modifiers = keyCombo.keyEquivalentModifierMask.keyEquivalentStrings().map { char -> String in
                switch char {
                case "⌥": return "Option"
                case "⌘": return "Command"
                case "⌃": return "Control"
                case "⇧": return "Shift"
                default: return char
                }
            }
            return "\(String(modifiers.joined(by: "-")))-\(keyChar)"
        }
    }

    var hotkey: HotKey {
        didSet {
            HotKeyCenter.shared.unregisterHotKey(with: oldValue.identifier)
            handleRegistration(persist: true)
            if let hkID = identifier.hk {
                appDelegate!.setKeyEquivalent(hkID)
            }
        }
    }

    var isEnabled: Bool {
        didSet {
            if isEnabled {
                log.debug("Enabled hotkey \(identifier)")
            } else {
                log.debug("Disabled hotkey \(identifier)")
            }
            handleRegistration()
            if let hkID = identifier.hk {
                appDelegate!.setKeyEquivalent(hkID)
            }
        }
    }

    var key: Key {
        hotkey.keyCombo.key
    }

    var keyChar: String {
        mainThread {
            (
                Sauce.shared.character(
                    for: Sauce.shared.keyCode(for: key).i,
                    carbonModifiers: 0
                ) ?? ""
            ).uppercased()
        }
    }

    var keyCode: Int {
        hotkey.keyCombo.QWERTYKeyCode
    }

    var modifiers: Int {
        hotkey.keyCombo.modifiers
    }

    var keyCombo: KeyCombo {
        hotkey.keyCombo
    }

    var identifier: String {
        hotkey.identifier
    }

    var target: AnyObject? {
        hotkey.target
    }

    var action: Selector? {
        hotkey.action
    }

    var handler: ((HotKey) -> Void)? {
        hotkey.callback
    }

    var isPresetHotkey: Bool { identifier.starts(with: Self.PRESET_PREFIX) }
    var preset: Preset? {
        guard isPresetHotkey else { return nil }
        let presetID = identifier.suffix(identifier.count - Self.PRESET_PREFIX.count)
        return CachedDefaults[.presets].first { $0.id == presetID }
    }

    static func == (lhs: PersistentHotkey, rhs: PersistentHotkey) -> Bool {
        lhs.identifier == rhs.identifier
    }

    func alternates(in hotkeys: Set<PersistentHotkey>? = nil) -> [PersistentHotkey] {
        guard let alternates = alternateHotkeysMapping[hotkey.identifier] else { return [] }
        return alternates.values.compactMap { altID in (hotkeys ?? CachedDefaults[.hotkeys]).first(where: { $0.identifier == altID }) }
    }

    func disabled() -> PersistentHotkey {
        PersistentHotkey(hotkey: hotkey, isEnabled: false)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    func with(handler: @escaping ((HotKey) -> Void)) -> PersistentHotkey {
        HOTKEY_HANDLERS[identifier] = handler
        return self
    }

    func unregister() {
        // log.debug("Unregistered hotkey \(identifier)")
        HotKeyCenter.shared.unregisterHotKey(with: hotkey.identifier)
    }

    func register() {
        // log.debug("Registered hotkey \(identifier)")
        // #if DEBUG
        //     mainAsyncAfter(ms: 10) { [weak self] in log.verbose("Registered hotkey \(self?.description ?? "")") }
        // #endif
        hotkey.register()
    }

    func handleRegistration(persist: Bool = true) {
        if isEnabled {
            register()
        } else {
            unregister()
        }

        if persist {
            save()
        }
    }

    func save() {
        var hotkeys = CachedDefaults[.hotkeys]
        hotkeys.remove(self)
        hotkeys.insert(self)
        CachedDefaults[.hotkeys] = hotkeys
    }

    func delete() {
        var hotkeys = CachedDefaults[.hotkeys]
        hotkeys.remove(self)
        unregister()
        CachedDefaults[.hotkeys] = hotkeys
    }

    func dict() -> [HotkeyPart: Int] {
        [
            .enabled: isEnabled ? 1 : 0,
            .keyCode: hotkey.keyCombo.QWERTYKeyCode,
            .modifiers: hotkey.keyCombo.modifiers,
            .allowsHold: allowsHold ? 1 : 0,
        ]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(identifier, forKey: .identifier)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers, forKey: .modifiers)
        try container.encode(isEnabled, forKey: .enabled)
        try container.encode(allowsHold, forKey: .allowsHold)
    }
}

// MARK: - Hotkey

enum Hotkey {
    static let functionKeyMapping: [Int: String] = [
        kVK_F1: String(Unicode.Scalar(NSF1FunctionKey)!),
        kVK_F2: String(Unicode.Scalar(NSF2FunctionKey)!),
        kVK_F3: String(Unicode.Scalar(NSF3FunctionKey)!),
        kVK_F4: String(Unicode.Scalar(NSF4FunctionKey)!),
        kVK_F5: String(Unicode.Scalar(NSF5FunctionKey)!),
        kVK_F6: String(Unicode.Scalar(NSF6FunctionKey)!),
        kVK_F7: String(Unicode.Scalar(NSF7FunctionKey)!),
        kVK_F8: String(Unicode.Scalar(NSF8FunctionKey)!),
        kVK_F9: String(Unicode.Scalar(NSF9FunctionKey)!),
        kVK_F10: String(Unicode.Scalar(NSF10FunctionKey)!),
        kVK_F11: String(Unicode.Scalar(NSF11FunctionKey)!),
        kVK_F12: String(Unicode.Scalar(NSF12FunctionKey)!),
        kVK_F13: String(Unicode.Scalar(NSF13FunctionKey)!),
        kVK_F14: String(Unicode.Scalar(NSF14FunctionKey)!),
        kVK_F15: String(Unicode.Scalar(NSF15FunctionKey)!),
        kVK_F16: String(Unicode.Scalar(NSF16FunctionKey)!),
        kVK_F17: String(Unicode.Scalar(NSF17FunctionKey)!),
        kVK_F18: String(Unicode.Scalar(NSF18FunctionKey)!),
        kVK_F19: String(Unicode.Scalar(NSF19FunctionKey)!),
        kVK_F20: String(Unicode.Scalar(NSF20FunctionKey)!),
    ]

    static let orientationIdentifiers: Set<String> = [
        HotkeyIdentifier.orientation0.rawValue,
        HotkeyIdentifier.orientation90.rawValue,
        HotkeyIdentifier.orientation180.rawValue,
        HotkeyIdentifier.orientation270.rawValue,
    ]

    static let hotkeysAllowingHold: Set<HotkeyIdentifier> = [
        HotkeyIdentifier.preciseBrightnessUp,
        HotkeyIdentifier.preciseBrightnessDown,
        HotkeyIdentifier.preciseContrastUp,
        HotkeyIdentifier.preciseContrastDown,
        HotkeyIdentifier.preciseVolumeUp,
        HotkeyIdentifier.preciseVolumeDown,
        HotkeyIdentifier.brightnessUp,
        HotkeyIdentifier.brightnessDown,
        HotkeyIdentifier.contrastUp,
        HotkeyIdentifier.contrastDown,
        HotkeyIdentifier.volumeUp,
        HotkeyIdentifier.volumeDown,
    ]

    static let defaults: Set<PersistentHotkey> = [
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.toggle.rawValue,
            keyCombo: KeyCombo(
                QWERTYKeyCode: kVK_ANSI_L,
                cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control, .option])
            )!,
            target: appDelegate!,
            action: handler(identifier: .toggle),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.lunar.rawValue,
            keyCombo: KeyCombo(
                QWERTYKeyCode: kVK_ANSI_L,
                cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .option, .shift])
            )!,
            target: appDelegate!,
            action: handler(identifier: .lunar),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.restart.rawValue,
            keyCombo: KeyCombo(
                QWERTYKeyCode: kVK_ANSI_L,
                cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control, .option, .shift])
            )!,
            target: appDelegate!,
            action: handler(identifier: .restart),
            actionQueue: .main,
            detectKeyHold: false
        ), isEnabled: false, register: false),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.orientation0.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_0, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.control]))!,
            target: appDelegate!,
            action: handler(identifier: .orientation0),
            actionQueue: .main,
            detectKeyHold: false
        ), isEnabled: false, register: false),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.orientation90.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_9, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.control]))!,
            target: appDelegate!,
            action: handler(identifier: .orientation90),
            actionQueue: .main,
            detectKeyHold: false
        ), isEnabled: false, register: false),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.orientation180.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_8, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.control]))!,
            target: appDelegate!,
            action: handler(identifier: .orientation180),
            actionQueue: .main,
            detectKeyHold: false
        ), isEnabled: false, register: false),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.orientation270.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_7, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.control]))!,
            target: appDelegate!,
            action: handler(identifier: .orientation270),
            actionQueue: .main,
            detectKeyHold: false
        ), isEnabled: false, register: false),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.percent0.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_0, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate!,
            action: handler(identifier: .percent0),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.percent25.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_1, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate!,
            action: handler(identifier: .percent25),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.percent50.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_2, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate!,
            action: handler(identifier: .percent50),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.percent75.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_3, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate!,
            action: handler(identifier: .percent75),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.percent100.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_4, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate!,
            action: handler(identifier: .percent100),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.faceLight.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_5, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate!,
            action: handler(identifier: .faceLight),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.blackOut.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_6, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate!,
            action: handler(identifier: .blackOut),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.blackOutPowerOff.rawValue,
            keyCombo: KeyCombo(
                QWERTYKeyCode: kVK_ANSI_6,
                cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control, .option])
            )!,
            target: appDelegate!,
            action: handler(identifier: .blackOutPowerOff),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.blackOutNoMirroring.rawValue,
            keyCombo: KeyCombo(
                QWERTYKeyCode: kVK_ANSI_6,
                cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control, .shift])
            )!,
            target: appDelegate!,
            action: handler(identifier: .blackOutNoMirroring),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.blackOutOthers.rawValue,
            keyCombo: KeyCombo(
                QWERTYKeyCode: kVK_ANSI_6,
                cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control, .shift, .option])
            )!,
            target: appDelegate!,
            action: handler(identifier: .blackOutOthers),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.preciseBrightnessUp.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F2, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .option]))!,
            target: appDelegate!,
            action: handler(identifier: .preciseBrightnessUp),
            actionQueue: .main,
            detectKeyHold: true
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.preciseBrightnessDown.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F1, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .option]))!,
            target: appDelegate!,
            action: handler(identifier: .preciseBrightnessDown),
            actionQueue: .main,
            detectKeyHold: true
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.preciseContrastUp.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F2, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .shift, .option]))!,
            target: appDelegate!,
            action: handler(identifier: .preciseContrastUp),
            actionQueue: .main,
            detectKeyHold: true
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.preciseContrastDown.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F1, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .shift, .option]))!,
            target: appDelegate!,
            action: handler(identifier: .preciseContrastDown),
            actionQueue: .main,
            detectKeyHold: true
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.preciseVolumeUp.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F12, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .option]))!,
            target: appDelegate!,
            action: handler(identifier: .preciseVolumeUp),
            actionQueue: .main,
            detectKeyHold: true
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.preciseVolumeDown.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F11, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .option]))!,
            target: appDelegate!,
            action: handler(identifier: .preciseVolumeDown),
            actionQueue: .main,
            detectKeyHold: true
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.brightnessUp.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F2, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command]))!,
            target: appDelegate!,
            action: handler(identifier: .brightnessUp),
            actionQueue: .main,
            detectKeyHold: true
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.brightnessDown.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F1, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command]))!,
            target: appDelegate!,
            action: handler(identifier: .brightnessDown),
            actionQueue: .main,
            detectKeyHold: true
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.contrastUp.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F2, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .shift]))!,
            target: appDelegate!,
            action: handler(identifier: .contrastUp),
            actionQueue: .main,
            detectKeyHold: true
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.contrastDown.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F1, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .shift]))!,
            target: appDelegate!,
            action: handler(identifier: .contrastDown),
            actionQueue: .main,
            detectKeyHold: true
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.muteAudio.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F10, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command]))!,
            target: appDelegate!,
            action: handler(identifier: .muteAudio),
            actionQueue: .main,
            detectKeyHold: false
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.volumeUp.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F12, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command]))!,
            target: appDelegate!,
            action: handler(identifier: .volumeUp),
            actionQueue: .main,
            detectKeyHold: true
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.volumeDown.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F11, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command]))!,
            target: appDelegate!,
            action: handler(identifier: .volumeDown),
            actionQueue: .main,
            detectKeyHold: true
        )),
    ]

    static func allowHold(for identifier: HotkeyIdentifier?) -> Bool {
        guard let identifier else {
            return false
        }

        return hotkeysAllowingHold.contains(identifier)
    }

    static func toggleOrientationHotkeys(enabled: Bool? = nil) {
        CachedDefaults[.hotkeys] = Set(CachedDefaults[.hotkeys].map { hotkey in
            if Hotkey.orientationIdentifiers.contains(hotkey.identifier) {
                hotkey.isEnabled = enabled ?? CachedDefaults[.enableOrientationHotkeys]
            }
            return hotkey
        })
    }

    static func toDictionary(_ hotkeys: [String: Any]) -> [HotkeyIdentifier: [HotkeyPart: Int]] {
        var hotkeySettings: [HotkeyIdentifier: [HotkeyPart: Int]] = [:]
        for (k, v) in hotkeys {
            guard let identifier = HotkeyIdentifier(rawValue: k), let hotkeyDict = v as? [String: Int] else {
                log.warning("Unknown Hotkey identifier: \(k): \(v)")
                continue
            }
            var hotkey: [HotkeyPart: Int] = [:]
            for (hk, hv) in hotkeyDict {
                guard let part = HotkeyPart(rawValue: hk) else { continue }
                hotkey[part] = hv
            }
            if hotkey.count == HotkeyPart.allCases.count {
                hotkeySettings[identifier] = hotkey
            }
        }

        return hotkeySettings
    }

    static func handler(identifier: HotkeyIdentifier) -> Selector {
        switch identifier {
        case .toggle:
            return #selector(AppDelegate.toggleHotkeyHandler)
        case .lunar:
            return #selector(AppDelegate.lunarHotkeyHandler)
        case .restart:
            return #selector(AppDelegate.restartHotkeyHandler)
        case .percent0:
            return #selector(AppDelegate.percent0HotkeyHandler)
        case .percent25:
            return #selector(AppDelegate.percent25HotkeyHandler)
        case .percent50:
            return #selector(AppDelegate.percent50HotkeyHandler)
        case .percent75:
            return #selector(AppDelegate.percent75HotkeyHandler)
        case .percent100:
            return #selector(AppDelegate.percent100HotkeyHandler)
        case .faceLight:
            return #selector(AppDelegate.faceLightHotkeyHandler)
        case .blackOut:
            return #selector(AppDelegate.blackOutHotkeyHandler)
        case .blackOutPowerOff:
            return #selector(AppDelegate.blackOutPowerOffHotkeyHandler)
        case .blackOutNoMirroring:
            return #selector(AppDelegate.blackOutNoMirroringHotkeyHandler)
        case .blackOutOthers:
            return #selector(AppDelegate.blackOutOthersHotkeyHandler)
        case .preciseBrightnessUp:
            return #selector(AppDelegate.preciseBrightnessUpHotkeyHandler)
        case .preciseBrightnessDown:
            return #selector(AppDelegate.preciseBrightnessDownHotkeyHandler)
        case .preciseContrastUp:
            return #selector(AppDelegate.preciseContrastUpHotkeyHandler)
        case .preciseContrastDown:
            return #selector(AppDelegate.preciseContrastDownHotkeyHandler)
        case .preciseVolumeUp:
            return #selector(AppDelegate.preciseVolumeUpHotkeyHandler)
        case .preciseVolumeDown:
            return #selector(AppDelegate.preciseVolumeDownHotkeyHandler)
        case .brightnessUp:
            return #selector(AppDelegate.brightnessUpHotkeyHandler)
        case .brightnessDown:
            return #selector(AppDelegate.brightnessDownHotkeyHandler)
        case .contrastUp:
            return #selector(AppDelegate.contrastUpHotkeyHandler)
        case .contrastDown:
            return #selector(AppDelegate.contrastDownHotkeyHandler)
        case .muteAudio:
            return #selector(AppDelegate.muteAudioHotkeyHandler)
        case .volumeUp:
            return #selector(AppDelegate.volumeUpHotkeyHandler)
        case .volumeDown:
            return #selector(AppDelegate.volumeDownHotkeyHandler)
        case .orientation0:
            return #selector(AppDelegate.orientation0Handler)
        case .orientation90:
            return #selector(AppDelegate.orientation90Handler)
        case .orientation180:
            return #selector(AppDelegate.orientation180Handler)
        case .orientation270:
            return #selector(AppDelegate.orientation270Handler)
        }
    }

    static func setKeyEquivalent(_ identifier: String, menuItem: NSMenuItem?, hotkeys: Set<PersistentHotkey>) {
        guard let menuItem, let hotkey = hotkeys.first(where: { $0.identifier == identifier }) else { return }
        if hotkey.isEnabled {
            if menuItem.isAlternate {
                menuItem.isHidden = false
                menuItem.isEnabled = true
            }
            if let keyEquivalent = Hotkey.functionKeyMapping[hotkey.keyCode] {
                menuItem.keyEquivalent = keyEquivalent
            } else {
                menuItem.keyEquivalent = hotkey.keyChar
            }
            menuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags(carbonModifiers: hotkey.modifiers)
        } else {
            menuItem.keyEquivalent = ""
            if menuItem.isAlternate {
                menuItem.isHidden = true
                menuItem.isEnabled = false
            }
        }
    }

    static func showOsd(osdImage: OSDImage, value: UInt32, display: Display) {
        guard !display.isAllDisplays, !display.isForTesting else { return }
        guard osdImage != .contrast else {
            display.showSoftwareOSD(
                image: "circle.lefthalf.filled",
                value: value.f / 100,
                text: "Contrast",
                color: .white.opacity(0.6),
                glowRadius: 0
            )
            return
        }
        guard !display.blackOutEnabled, display.softwareBrightness == 1.0, let manager = OSDManager.sharedManager() as? OSDManager else {
            log.warning("No OSDManager available")
            return
        }
        var controlID = ControlID.BRIGHTNESS
        switch osdImage {
        case .brightness:
            controlID = .BRIGHTNESS
        case .contrast:
            controlID = .CONTRAST
        case .volume:
            guard display.showVolumeOSD else { return }
            controlID = .AUDIO_SPEAKER_VOLUME
        case .muted:
            guard display.showVolumeOSD else { return }
        }

        let locked = (display.control is DDCControl && (DDC.skipWritingPropertyById[display.id]?.contains(controlID) ?? false))
            || display.noControls
            || (display.lockedBrightness && display.hasDDC)
        let mirroredID = CGDisplayMirrorsDisplay(display.id)
        let osdID = (mirroredID != kCGNullDirectDisplay && mirroredID != UINT32_MAX) ? mirroredID : display.id

        manager.showImage(
            osdImage.rawValue,
            onDisplayID: osdID,
            priority: 0x1F4,
            msecUntilFade: 1500,
            filledChiclets: value.d.map(from: (0, 100), to: (0, 240)).u32,
            totalChiclets: 240,
            locked: locked
        )
    }
}

// MARK: - AppDelegate + MediaKeyTapDelegate

extension AppDelegate: MediaKeyTapDelegate {
    func volumeOsdImage(display: Display? = nil) -> OSDImage {
        guard let display = (display ?? DC.mainExternalOrCGMainDisplay) else {
            return .volume
        }

        if display.audioMuted {
            return .muted
        } else {
            return .volume
        }
    }

    func startOrRestartMediaKeyTap(brightnessKeysEnabled: Bool? = nil, volumeKeysEnabled: Bool? = nil, checkPermissions: Bool = false) {
        mediaKeyTapStartingFinishTask = mainAsyncAfter(ms: 300) {
            DC.currentAudioDisplay = DC.getCurrentAudioDisplay()

            if checkPermissions || brightnessKeysEnabled ?? false || volumeKeysEnabled ?? false {
                acquirePrivileges()
            }

            if !self.mediaKeyTapBrightnessStarting {
                self.mediaKeyTapBrightnessStarting = true

                if brightnessKeysEnabled ?? CachedDefaults[.brightnessKeysEnabled] {
                    mediaKeyTapBrightness.restart()
                } else {
                    mediaKeyTapBrightness.stop()
                }

                self.mediaKeyTapBrightnessStarting = false
            }

            if !self.mediaKeyTapAudioStarting {
                self.mediaKeyTapAudioStarting = true

                if volumeKeysEnabled ?? CachedDefaults[.volumeKeysEnabled], let audioDevice = simplyCA.defaultOutputDevice, !audioDevice.canSetVirtualMainVolume(scope: .output) {
                    mediaKeyTapAudio.restart()
                } else {
                    mediaKeyTapAudio.stop()
                }

                self.mediaKeyTapAudioStarting = false
            }
        }
    }

    func openPreferences(_ mediaKey: MediaKey, event: CGEvent) -> CGEvent? {
        switch mediaKey {
        case .brightnessUp, .brightnessDown:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Displays.prefPane"))
        case .volumeUp, .volumeDown, .mute:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Sound.prefPane"))
        default:
            return event
        }
        return nil
    }

    func adjust(
        _ mediaKey: MediaKey,
        by value: Int? = nil,
        contrast: Bool = false,
        currentDisplay: Bool = false,
        builtinDisplay: Bool = false,
        sourceDisplay: Bool = false,
        mainDisplay: Bool = false,
        nonMainDisplays: Bool = false,
        allDisplays: Bool = false
    ) {
        let builtinDisplay = builtinDisplay || (mainDisplay && (DC.mainDisplay?.isBuiltin ?? false))
        if contrast && builtinDisplay && !(allDisplays || nonMainDisplays || currentDisplay || sourceDisplay) {
            return
        }

        switch mediaKey {
        case .brightnessUp where contrast:
            DC.pressedContrastKey.true(for: 0.5)
            increaseContrast(
                by: value,
                currentDisplay: currentDisplay,
                sourceDisplay: sourceDisplay,
                mainDisplay: mainDisplay,
                nonMainDisplays: nonMainDisplays
            )
        case .brightnessUp where allDisplays:
            DC.pressedBrightnessKey.true(for: 0.5)
            if builtinDisplay {
                increaseBrightness(by: value, builtinDisplay: builtinDisplay)
            }
            increaseBrightness(by: value)
        case .brightnessUp:
            DC.pressedBrightnessKey.true(for: 0.5)
            increaseBrightness(
                by: value,
                currentDisplay: currentDisplay,
                builtinDisplay: builtinDisplay,
                sourceDisplay: sourceDisplay,
                mainDisplay: mainDisplay,
                nonMainDisplays: nonMainDisplays
            )
        case .brightnessDown where contrast:
            DC.pressedContrastKey.true(for: 0.5)
            decreaseContrast(
                by: value,
                currentDisplay: currentDisplay,
                sourceDisplay: sourceDisplay,
                mainDisplay: mainDisplay,
                nonMainDisplays: nonMainDisplays
            )
        case .brightnessDown where allDisplays:
            DC.pressedBrightnessKey.true(for: 0.5)
            if builtinDisplay {
                decreaseBrightness(by: value, builtinDisplay: builtinDisplay)
            }
            decreaseBrightness(by: value)
        case .brightnessDown:
            DC.pressedBrightnessKey.true(for: 0.5)
            decreaseBrightness(
                by: value,
                currentDisplay: currentDisplay,
                builtinDisplay: builtinDisplay,
                sourceDisplay: sourceDisplay,
                mainDisplay: mainDisplay,
                nonMainDisplays: nonMainDisplays
            )
        default:
            break
        }

        let showOSD = { (display: Display) in
            if contrast {
                guard !display.isBuiltin else {
                    log.warning("Contrast can't be adjusted on builtin")
                    return
                }
                log.info("Showing OSD for \(display) on contrast=\(display.contrast.uint32Value)")
                Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, display: display)
            } else {
                log.info("Showing OSD for \(display) on brightness=\(display.brightness.uint32Value)")
                Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, display: display)
            }
        }

        guard sourceDisplay || builtinDisplay || currentDisplay || allDisplays || mainDisplay || nonMainDisplays else {
            log.info("showOSD()")
            if CachedDefaults[.workaroundBuiltinDisplay] {
                DC.externalActiveDisplays.forEach(showOSD)
            } else {
                DC.activeDisplayList.forEach(showOSD)
            }

            return
        }

        if mainDisplay, let display = DC.mainDisplay {
            log.info("showOSD(mainDisplay)")
            showOSD(display)
        }
        if sourceDisplay, !DC.sourceDisplay.isAllDisplays {
            log.info("showOSD(sourceDisplay)")
            showOSD(DC.sourceDisplay)
        }
        if builtinDisplay, let display = DC.builtinDisplay, !mainDisplay {
            log.info("showOSD(builtinDisplay)")
            showOSD(display)
        }
        if currentDisplay, let display = DC.cursorDisplay {
            log.info("showOSD(cursorDisplay)")
            showOSD(display)
        }
        if nonMainDisplays {
            log.info("showOSD(nonMainDisplays)")
            DC.nonMainDisplays.forEach(showOSD)
        }
        if allDisplays {
            log.info("showOSD(allDisplays)")
            DC.externalActiveDisplays.forEach(showOSD)
        }
    }

    func handleBrightnessKeyAction(
        _ action: BrightnessKeyAction,
        mediaKey: MediaKey,
        by offset: Int? = nil,
        contrast: Bool = false,
        lidClosed: Bool,
        event: CGEvent
    ) -> CGEvent? {
        let lidOpened = !lidClosed

        log.info("\(action) (lidClosed: \(lidClosed))")

        switch action {
        case .all:
            if CachedDefaults[.workaroundBuiltinDisplay], lidOpened, let builtin = DC.builtinDisplay, builtin.active {
                log.info("Adjusting external displays and then forwarding media key to system")
                adjust(mediaKey, by: offset, contrast: contrast, allDisplays: true)
                if !contrast, !builtin.blackOutEnabled {
                    event.flags = event.flags.subtracting([.maskShift, .maskAlternate, .maskCommand, .maskControl])
                    if offset == 1 {
                        event.flags = event.flags.union([.maskShift, .maskAlternate])
                    }
                    log.info("Forwarding media key to system using flags=\(offset == 1 ? "[.maskShift, .maskAlternate]" : "[]")")
                    return event
                }
                log
                    .info(
                        "Not forwarding media key to system because of contrast=\(contrast) builtin.blackOutEnabled=\(builtin.blackOutEnabled)"
                    )
                return nil
            }
            adjust(mediaKey, by: offset, contrast: contrast, builtinDisplay: true, allDisplays: true)
        case .external:
            adjust(mediaKey, by: offset, contrast: contrast, allDisplays: true)
        case .main:
            adjust(mediaKey, by: offset, contrast: contrast, mainDisplay: true)
        case .nonMain:
            adjust(mediaKey, by: offset, contrast: contrast, nonMainDisplays: true)
        case .cursor:
            if CachedDefaults[.workaroundBuiltinDisplay], !contrast, let cursor = DC.cursorDisplay, cursor.isBuiltin {
                event.flags = event.flags.subtracting([.maskShift, .maskAlternate, .maskCommand, .maskControl])
                if offset == 1 {
                    event.flags = event.flags.union([.maskShift, .maskAlternate])
                }
                log.info("Forwarding media key to system using flags=\(offset == 1 ? "[.maskShift, .maskAlternate]" : "[]")")
                return event
            }
            adjust(mediaKey, by: offset, contrast: contrast, currentDisplay: true)
        case .builtin:
            if CachedDefaults[.workaroundBuiltinDisplay], !contrast, lidOpened {
                event.flags = event.flags.subtracting([.maskShift, .maskAlternate, .maskCommand, .maskControl])
                if offset == 1 {
                    event.flags = event.flags.union([.maskShift, .maskAlternate])
                }
                log.info("Forwarding media key to system using flags=\(offset == 1 ? "[.maskShift, .maskAlternate]" : "[]")")
                return event
            }
            adjust(mediaKey, by: offset, contrast: contrast, currentDisplay: lidClosed, builtinDisplay: lidOpened)
        case .source:
            if CachedDefaults[.workaroundBuiltinDisplay], !contrast, DC.sourceDisplay.isBuiltin {
                event.flags = event.flags.subtracting([.maskShift, .maskAlternate, .maskCommand, .maskControl])
                if offset == 1 {
                    event.flags = event.flags.union([.maskShift, .maskAlternate])
                }
                log.info("Forwarding media key to system using flags=\(offset == 1 ? "[.maskShift, .maskAlternate]" : "[]")")
                return event
            }
            adjust(mediaKey, by: offset, contrast: contrast, sourceDisplay: true)
        }
        return nil
    }

    func handleBrightnessKeys(
        withLidClosed lidClosed: Bool,
        mediaKey: MediaKey,
        modifiers flags: NSEvent.ModifierFlags,
        event: CGEvent
    ) -> CGEvent? {
        guard checkRemainingAdjustments() else { return event }

        let flags = flags.intersection([.command, .option, .control, .shift])
        switch flags {
        case [] where DC.adaptiveModeKey == .sync:
            log.info("\(mediaKey) + [] where DC.adaptiveModeKey == .sync")
            return handleBrightnessKeyAction(
                CachedDefaults[.brightnessKeysSyncControl],
                mediaKey: mediaKey,
                lidClosed: lidClosed,
                event: event
            )
        case [.option, .shift] where DC.adaptiveModeKey == .sync:
            log.info("\(mediaKey) + [.option, .shift] where DC.adaptiveModeKey == .sync")
            return handleBrightnessKeyAction(
                CachedDefaults[.brightnessKeysSyncControl],
                mediaKey: mediaKey,
                by: 1,
                lidClosed: lidClosed,
                event: event
            )

        case []:
            log.info("\(mediaKey) + []")
            return handleBrightnessKeyAction(CachedDefaults[.brightnessKeysControl], mediaKey: mediaKey, lidClosed: lidClosed, event: event)
        case [.option, .shift]:
            log.info("\(mediaKey) + [.option, .shift]")
            return handleBrightnessKeyAction(
                CachedDefaults[.brightnessKeysControl],
                mediaKey: mediaKey,
                by: 1,
                lidClosed: lidClosed,
                event: event
            )

        case [.shift] where DC.adaptiveModeKey == .sync:
            log.info("\(mediaKey) + [.shift] where DC.adaptiveModeKey == .sync")
            return handleBrightnessKeyAction(
                CachedDefaults[.shiftBrightnessKeysSyncControl],
                mediaKey: mediaKey,
                lidClosed: lidClosed,
                event: event
            )
        case [.shift]:
            log.info("\(mediaKey) + [.shift]")
            return handleBrightnessKeyAction(
                CachedDefaults[.shiftBrightnessKeysControl],
                mediaKey: mediaKey,
                lidClosed: lidClosed,
                event: event
            )

        case [.control] where DC.adaptiveModeKey == .sync:
            log.info("\(mediaKey) + [.control] where DC.adaptiveModeKey == .sync")
            return handleBrightnessKeyAction(
                CachedDefaults[.ctrlBrightnessKeysSyncControl],
                mediaKey: mediaKey,
                lidClosed: lidClosed,
                event: event
            )
        case [.control]:
            log.info("\(mediaKey) + [.control]")
            return handleBrightnessKeyAction(
                CachedDefaults[.ctrlBrightnessKeysControl],
                mediaKey: mediaKey,
                lidClosed: lidClosed,
                event: event
            )

        case [.control, .option] where DC.adaptiveModeKey == .sync:
            log.info("\(mediaKey) + [.control, .option] where DC.adaptiveModeKey == .sync")
            return handleBrightnessKeyAction(
                CachedDefaults[.ctrlBrightnessKeysSyncControl],
                mediaKey: mediaKey,
                by: 1,
                lidClosed: lidClosed,
                event: event
            )
        case [.control, .option]:
            log.info("\(mediaKey) + [.control, .option]")
            return handleBrightnessKeyAction(
                CachedDefaults[.ctrlBrightnessKeysControl],
                mediaKey: mediaKey,
                by: 1,
                lidClosed: lidClosed,
                event: event
            )

        case [.control, .shift]:
            log.info("\(mediaKey) + [.control, .shift]")
            return handleBrightnessKeyAction(
                CachedDefaults[.brightnessKeysControl],
                mediaKey: mediaKey,
                contrast: true,
                lidClosed: lidClosed,
                event: event
            )
        case [.control, .shift, .option]:
            log.info("\(mediaKey) + [.control, .shift, .option]")
            return handleBrightnessKeyAction(
                CachedDefaults[.brightnessKeysControl],
                mediaKey: mediaKey,
                by: 1,
                contrast: true,
                lidClosed: lidClosed,
                event: event
            )
        default:
            log.info("Ignoring media key event")
            log.info("lidClosed: \(lidClosed)")
            log.info("mediaKey: \(mediaKey)")
            log.info("flags: \(flags) (\(flags.keyEquivalentStrings())")
            log.info("event: \(event.type)")
            return event
        }
    }

    func isVolumeKey(_ mediaKey: MediaKey) -> Bool {
        switch mediaKey {
        case .volumeUp, .volumeDown, .mute:
            return true
        default:
            return false
        }
    }

    func handle(mediaKey: MediaKey, event _: KeyEvent?, modifiers flags: NSEvent.ModifierFlags?, event: CGEvent) -> CGEvent? {
        let flags = flags?.filterUnsupportModifiers() ?? NSEvent.ModifierFlags(rawValue: 0)
        guard flags != [.option] else {
            return event
        }

        guard DC.activeDisplays.count > 0 else {
            return event
        }

        guard isVolumeKey(mediaKey) else {
            let lidClosed = DC.lidClosed || DC.builtinDisplay == nil
            let event = handleBrightnessKeys(withLidClosed: lidClosed, mediaKey: mediaKey, modifiers: flags, event: event)
            if event != nil { log.debug("Forwarding brightness key event to the system") }
            DC.lastTimeBrightnessKeyPressed = Date()
            return event
        }

        switch mediaKey {
        case .volumeUp:
            if Defaults[.volumeKeysControlAllMonitors] {
                let displays = DC.activeDisplayList.filter(\.supportsVolumeControl)
                guard !displays.isEmpty else { return event }

                increaseVolume(by: flags.isSuperset(of: [.option, .shift]) ? 1 : nil, for: displays, currentAudioDisplay: false)

                let mutedDisplays = displays.filter(\.audioMuted)
                if !mutedDisplays.isEmpty {
                    toggleAudioMuted(for: mutedDisplays, currentAudioDisplay: false)
                }

                displays.forEach { display in
                    Hotkey.showOsd(osdImage: volumeOsdImage(), value: display.volume.uint32Value, display: display)
                }

                if (Defaults[.beepFeedback] && !flags.contains(.shift)) || (!Defaults[.beepFeedback] && flags.contains(.shift)) {
                    playVolumeChangedSound()
                }

                return nil
            }

            guard let display = DC.currentAudioDisplay, display.supportsVolumeControl else {
                return event
            }

            increaseVolume(by: flags.isSuperset(of: [.option, .shift]) ? 1 : nil)
            if display.audioMuted {
                toggleAudioMuted()
            }

            Hotkey.showOsd(osdImage: volumeOsdImage(), value: display.volume.uint32Value, display: display)

            if (Defaults[.beepFeedback] && !flags.contains(.shift)) || (!Defaults[.beepFeedback] && flags.contains(.shift)) {
                playVolumeChangedSound()
            }
        case .volumeDown:
            if Defaults[.volumeKeysControlAllMonitors] {
                let displays = DC.activeDisplayList.filter(\.supportsVolumeControl)
                guard !displays.isEmpty else { return event }

                decreaseVolume(by: flags.isSuperset(of: [.option, .shift]) ? 1 : nil, for: displays, currentAudioDisplay: false)

                let mutedDisplays = displays.filter(\.audioMuted)
                if !mutedDisplays.isEmpty {
                    toggleAudioMuted(for: mutedDisplays, currentAudioDisplay: false)
                }

                displays.forEach { display in
                    Hotkey.showOsd(osdImage: volumeOsdImage(), value: display.volume.uint32Value, display: display)
                }

                if (Defaults[.beepFeedback] && !flags.contains(.shift)) || (!Defaults[.beepFeedback] && flags.contains(.shift)) {
                    playVolumeChangedSound()
                }

                return nil
            }

            guard let display = DC.currentAudioDisplay, display.supportsVolumeControl else {
                return event
            }

            decreaseVolume(by: flags.isSuperset(of: [.option, .shift]) ? 1 : nil)
            if display.audioMuted {
                toggleAudioMuted()
            }

            Hotkey.showOsd(osdImage: volumeOsdImage(), value: display.volume.uint32Value, display: display)

            if (Defaults[.beepFeedback] && !flags.contains(.shift)) || (!Defaults[.beepFeedback] && flags.contains(.shift)) {
                playVolumeChangedSound()
            }
        case .mute:
            if Defaults[.volumeKeysControlAllMonitors] {
                let displays = DC.activeDisplayList.filter(\.supportsVolumeControl)
                guard !displays.isEmpty else { return event }

                toggleAudioMuted(for: displays, currentAudioDisplay: false)

                displays.forEach { display in
                    Hotkey.showOsd(osdImage: volumeOsdImage(), value: display.volume.uint32Value, display: display)
                }

                if (Defaults[.beepFeedback] && !flags.contains(.shift)) || (!Defaults[.beepFeedback] && flags.contains(.shift)) {
                    playVolumeChangedSound()
                }

                return nil
            }

            guard let display = DC.currentAudioDisplay, display.supportsVolumeControl else {
                return event
            }

            toggleAudioMuted()

            Hotkey.showOsd(osdImage: volumeOsdImage(), value: display.volume.uint32Value, display: display)

            if (Defaults[.beepFeedback] && !flags.contains(.shift)) || (!Defaults[.beepFeedback] && flags.contains(.shift)) {
                playVolumeChangedSound()
            }
        default:
            return event
        }

        return nil
    }

    @objc func toggleHotkeyHandler() {
        DC.toggle()
        if DC.adaptiveModeKey != .manual, DC.activeDisplayList.contains(where: \.adaptivePaused) {
            DC.activeDisplayList.filter(\.adaptivePaused).forEach {
                $0.adaptivePaused = false
            }
        }
        log.debug("Toggle Hotkey pressed")
    }

    @objc func lunarHotkeyHandler() {
        showWindow()
        log.debug("Show Window Hotkey pressed")
    }

    @objc func restartHotkeyHandler() {
        log.debug("Restart Hotkey pressed")
        restartApp(self)
    }

    @objc func percent0HotkeyHandler() {
        cancelScreenWakeAdapterTask()
        setLightPercent(percent: 0)
        log.debug("0% Hotkey pressed")
    }

    @objc func percent25HotkeyHandler() {
        cancelScreenWakeAdapterTask()
        setLightPercent(percent: 25)
        log.debug("25% Hotkey pressed")
    }

    @objc func percent50HotkeyHandler() {
        cancelScreenWakeAdapterTask()
        setLightPercent(percent: 50)
        log.debug("50% Hotkey pressed")
    }

    @objc func percent75HotkeyHandler() {
        cancelScreenWakeAdapterTask()
        setLightPercent(percent: 75)
        log.debug("75% Hotkey pressed")
    }

    @objc func percent100HotkeyHandler() {
        cancelScreenWakeAdapterTask()
        setLightPercent(percent: 100)
        log.debug("100% Hotkey pressed")
    }

    @objc func faceLightHotkeyHandler() {
        guard lunarProActive else { return }
        cancelScreenWakeAdapterTask()
        faceLight(self)
        log.debug("FaceLight Hotkey pressed")
    }

    @objc func blackOutHotkeyHandler() {
        guard lunarProActive else { return }
        cancelScreenWakeAdapterTask()
        blackOut(self)
        log.debug("BlackOut Hotkey pressed")
    }

    @objc func blackOutPowerOffHotkeyHandler() {
        guard let display = DC.mainExternalDisplay else { return }
        _ = display.control?.setPower(.off)
        log.debug("BlackOut Power Off Hotkey pressed")
    }

    @objc func blackOutNoMirroringHotkeyHandler() {
        guard lunarProActive else { return }
        cancelScreenWakeAdapterTask()
        blackOutNoMirroring(self)
        log.debug("BlackOut No Mirroring Hotkey pressed")
    }

    @objc func blackOutOthersHotkeyHandler() {
        guard lunarProActive else { return }
        cancelScreenWakeAdapterTask()
        blackOutOthers(self)
        log.debug("BlackOut Other Displays Hotkey pressed")
    }

    @objc func orientation0Handler() {
        guard let display = DC.cursorDisplay else {
            log.warning("Orientation 0 Hotkey pressed but no display with cursor found")
            return
        }
        display.rotation = 0
        log.debug("Orientation 0 Hotkey pressed")
    }

    @objc func orientation90Handler() {
        guard let display = DC.cursorDisplay else {
            log.warning("Orientation 90 Hotkey pressed but no display with cursor found")
            return
        }
        display.rotation = 90
        log.debug("Orientation 90 Hotkey pressed")
    }

    @objc func orientation180Handler() {
        guard let display = DC.cursorDisplay else {
            log.warning("Orientation 180 Hotkey pressed but no display with cursor found")
            return
        }
        display.rotation = 180
        log.debug("Orientation 180 Hotkey pressed")
    }

    @objc func orientation270Handler() {
        guard let display = DC.cursorDisplay else {
            log.warning("Orientation 270 Hotkey pressed but no display with cursor found")
            return
        }
        display.rotation = 270
        log.debug("Orientation 270 Hotkey pressed")
    }

    func brightnessUpAction(offset: Int? = nil) {
        defer { DC.lastTimeBrightnessKeyPressed = Date() }

        let allMonitors = CachedDefaults[.brightnessHotkeysControlAllMonitors]
        cancelScreenWakeAdapterTask()
        increaseBrightness(by: offset, currentDisplay: !allMonitors)
        if CachedDefaults[.hotkeysAffectBuiltin], allMonitors {
            increaseBrightness(by: offset, builtinDisplay: true)
        }

        if allMonitors {
            for (_, display) in DC.activeDisplays {
                guard CachedDefaults[.hotkeysAffectBuiltin] || !display.isBuiltin else { continue }
                Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, display: display)
            }
        } else if let display = DC.cursorDisplay {
            Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, display: display)
        }

        log.debug("Brightness Up Hotkey pressed")
    }

    func brightnessDownAction(offset: Int? = nil) {
        defer { DC.lastTimeBrightnessKeyPressed = Date() }

        let allMonitors = CachedDefaults[.brightnessHotkeysControlAllMonitors]
        cancelScreenWakeAdapterTask()
        decreaseBrightness(by: offset, currentDisplay: !allMonitors)
        if CachedDefaults[.hotkeysAffectBuiltin], allMonitors {
            decreaseBrightness(by: offset, builtinDisplay: true)
        }

        if allMonitors {
            for (_, display) in DC.activeDisplays {
                guard CachedDefaults[.hotkeysAffectBuiltin] || !display.isBuiltin else { continue }
                Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, display: display)
            }
        } else if let display = DC.cursorDisplay {
            Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, display: display)
        }

        log.debug("Brightness Down Hotkey pressed")
    }

    func contrastUpAction(offset: Int? = nil) {
        let allMonitors = CachedDefaults[.contrastHotkeysControlAllMonitors]
        cancelScreenWakeAdapterTask()
        increaseContrast(by: offset, currentDisplay: !allMonitors)

        if allMonitors {
            for (_, display) in DC.activeDisplays {
                guard !display.isBuiltin else { continue }
                Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, display: display)
            }
        } else if let display = DC.cursorDisplay, !display.isBuiltin {
            Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, display: display)
        }

        log.debug("Contrast Up Hotkey pressed")
    }

    func contrastDownAction(offset: Int? = nil) {
        let allMonitors = CachedDefaults[.contrastHotkeysControlAllMonitors]
        cancelScreenWakeAdapterTask()
        decreaseContrast(by: offset, currentDisplay: !allMonitors)

        if allMonitors {
            for (_, display) in DC.activeDisplays {
                guard !display.isBuiltin else { continue }
                Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, display: display)
            }
        } else if let display = DC.cursorDisplay, !display.isBuiltin {
            Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, display: display)
        }

        log.debug("Contrast Down Hotkey pressed")
    }

    func volumeUpAction(offset: Int? = nil) {
        let allMonitors = CachedDefaults[.volumeHotkeysControlAllMonitors]

        let hasAudioDisplay = DC.currentAudioDisplay != nil
        increaseVolume(by: offset, currentDisplay: !allMonitors && !hasAudioDisplay, currentAudioDisplay: !allMonitors && hasAudioDisplay)

        if allMonitors {
            let muted = DC.externalActiveDisplays.filter(\.audioMuted)
            if !muted.isEmpty {
                toggleAudioMuted(for: muted, currentAudioDisplay: false)
            }

            DC.externalActiveDisplays.forEach { d in
                Hotkey.showOsd(osdImage: volumeOsdImage(display: d), value: d.volume.uint32Value, display: d)
            }
        } else if let display = DC.currentAudioDisplay ?? DC.cursorDisplay, !display.isBuiltin {
            if display.audioMuted { toggleAudioMuted(for: [display], currentAudioDisplay: false) }
            Hotkey.showOsd(osdImage: volumeOsdImage(display: display), value: display.volume.uint32Value, display: display)
        }

        log.debug("Volume Up Hotkey pressed")
    }

    func volumeDownAction(offset: Int? = nil) {
        let allMonitors = CachedDefaults[.volumeHotkeysControlAllMonitors]

        let hasAudioDisplay = DC.currentAudioDisplay != nil
        decreaseVolume(by: offset, currentDisplay: !allMonitors && !hasAudioDisplay, currentAudioDisplay: !allMonitors && hasAudioDisplay)

        if allMonitors {
            let muted = DC.externalActiveDisplays.filter(\.audioMuted)
            if !muted.isEmpty {
                toggleAudioMuted(for: muted, currentAudioDisplay: false)
            }

            DC.externalActiveDisplays.forEach { d in
                Hotkey.showOsd(osdImage: volumeOsdImage(display: d), value: d.volume.uint32Value, display: d)
            }
        } else if let display = DC.currentAudioDisplay ?? DC.cursorDisplay, !display.isBuiltin {
            if display.audioMuted { toggleAudioMuted(for: [display], currentAudioDisplay: false) }
            Hotkey.showOsd(osdImage: volumeOsdImage(display: display), value: display.volume.uint32Value, display: display)
        }

        log.debug("Volume Down Hotkey pressed")
    }

    @objc func muteAudioHotkeyHandler() {
        let allMonitors = CachedDefaults[.volumeHotkeysControlAllMonitors]

        let hasAudioDisplay = DC.currentAudioDisplay != nil
        toggleAudioMuted(currentDisplay: !allMonitors && !hasAudioDisplay, currentAudioDisplay: !allMonitors && hasAudioDisplay)

        if allMonitors {
            DC.externalActiveDisplays.forEach { d in
                Hotkey.showOsd(osdImage: volumeOsdImage(display: d), value: d.volume.uint32Value, display: d)
            }
        } else if let display = DC.currentAudioDisplay ?? DC.cursorDisplay, !display.isBuiltin {
            Hotkey.showOsd(osdImage: volumeOsdImage(display: display), value: display.volume.uint32Value, display: display)
        }

        log.debug("Audio Mute Hotkey pressed")
    }

    @objc func brightnessUpHotkeyHandler() {
        brightnessUpAction()
    }

    @objc func brightnessDownHotkeyHandler() {
        brightnessDownAction()
    }

    @objc func contrastUpHotkeyHandler() {
        contrastUpAction()
    }

    @objc func contrastDownHotkeyHandler() {
        contrastDownAction()
    }

    @objc func volumeUpHotkeyHandler() {
        volumeUpAction()
    }

    @objc func volumeDownHotkeyHandler() {
        volumeDownAction()
    }

    @objc func preciseBrightnessUpHotkeyHandler() {
        brightnessUpAction(offset: 1)
    }

    @objc func preciseBrightnessDownHotkeyHandler() {
        brightnessDownAction(offset: 1)
    }

    @objc func preciseContrastUpHotkeyHandler() {
        contrastUpAction(offset: 1)
    }

    @objc func preciseContrastDownHotkeyHandler() {
        contrastDownAction(offset: 1)
    }

    @objc func preciseVolumeUpHotkeyHandler() {
        volumeUpAction(offset: 1)
    }

    @objc func preciseVolumeDownHotkeyHandler() {
        volumeDownAction(offset: 1)
    }

    @objc func doNothing() {
        #if DEBUG
            log.debug("Doing precisely nothing.")
        #endif
    }
}
