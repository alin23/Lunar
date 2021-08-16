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

var upHotkey: Magnet.HotKey?
var downHotkey: Magnet.HotKey?
var leftHotkey: Magnet.HotKey?
var rightHotkey: Magnet.HotKey?

var mediaKeyTapBrightness: MediaKeyTap?
var mediaKeyTapAudio: MediaKeyTap?
let fineAdjustmentDisabledBecauseOfOptionKey = "Fine adjustment can't be enabled when the hotkey uses the Option key"

// MARK: - HotkeyIdentifier

enum HotkeyIdentifier: String, CaseIterable, Codable {
    case toggle,
         lunar,
         percent0,
         percent25,
         percent50,
         percent75,
         percent100,
         faceLight,
         blackOut,
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
         volumeDown
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
}

// MARK: - OSDImage

enum OSDImage: Int64 {
    case brightness = 1
    case contrast = 11
    case volume = 3
    case muted = 4
}

var HOTKEY_HANDLERS = [String: (HotKey) -> Void](minimumCapacity: 10)

// MARK: - PersistentHotkey

class PersistentHotkey: Codable, Hashable, Defaults.Serializable, CustomStringConvertible {
    // MARK: Lifecycle

    init(_ identifier: String, handler: ((HotKey) -> Void)? = nil, dict hk: [HotkeyPart: Int]) {
        let keyCode = hk[.keyCode]!
        let enabled = hk[.enabled]!
        let modifiers = hk[.modifiers]!
        let keyCombo = KeyCombo(QWERTYKeyCode: keyCode, carbonModifiers: modifiers)!

        if let handler = handler {
            hotkey = Magnet.HotKey(
                identifier: identifier,
                keyCombo: keyCombo,
                actionQueue: .main,
                handler: handler
            )
            isEnabled = enabled == 1
            if isEnabled {
                register()
            }
            log.debug("Created hotkey with handler \(identifier)")
            return
        }

        if let hkIdentifier = HotkeyIdentifier(rawValue: identifier) {
            hotkey = Magnet.HotKey(
                identifier: identifier,
                keyCombo: keyCombo,
                target: appDelegate,
                action: Hotkey.handler(identifier: hkIdentifier),
                actionQueue: .main
            )
            isEnabled = enabled == 1
            if isEnabled {
                register()
            }
            log.debug("Created hotkey with action/target \(identifier)")
            return
        }

        hotkey = Magnet.HotKey(
            identifier: identifier,
            keyCombo: keyCombo,
            actionQueue: .main,
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
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT: \(identifier)")
            do { log.verbose("END DEINIT: \(identifier)") }
        #endif
//        hotkey.unregister()
    }

    init(hotkey: HotKey, isEnabled: Bool = true, register: Bool = true) {
        self.hotkey = hotkey
        self.isEnabled = isEnabled
        if register {
            handleRegistration(persist: false)
        }
    }

    required convenience init(from decoder: Decoder) throws {
        log.debug("Initializing hotkey from decoder")
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let identifier = try container.decode(String.self, forKey: .identifier)
        log.debug("Identifier: \(identifier)")
        let enabled = try container.decode(Bool.self, forKey: .enabled)
        log.debug("Enabled: \(enabled)")
        let modifiers = try container.decode(Int.self, forKey: .modifiers)
        let keyCode = try container.decode(Int.self, forKey: .keyCode)

        self.init(identifier, dict: [
            .enabled: enabled ? 1 : 0,
            .keyCode: keyCode,
            .modifiers: modifiers,
        ])
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey, CaseIterable {
        case identifier
        case keyCode
        case enabled
        case modifiers
    }

    @Atomic static var isRecording = false

    var description: String {
        "<PersistentHotkey \(identifier)[\(hotkeyString)]>"
    }

    var hotkeyString: String {
        mainThread {
            let modifiers = keyCombo.keyEquivalentModifierMask.keyEquivalentStrings().map { char -> String in
                switch char {
                case "⌥": return "option"
                case "⌘": return "command"
                case "⌃": return "control"
                case "⇧": return "shift"
                default: return char
                }
            }
            return "\(String(modifiers.joined(by: "+")))-\(keyChar)"
        }
    }

    var hotkey: HotKey {
        didSet {
            HotKeyCenter.shared.unregisterHotKey(with: oldValue.identifier)
            handleRegistration(persist: true)
            if HotkeyIdentifier(rawValue: identifier) != nil {
                appDelegate.setKeyEquivalents(CachedDefaults[.hotkeys])
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

    static func == (lhs: PersistentHotkey, rhs: PersistentHotkey) -> Bool {
        lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    func with(handler: @escaping ((HotKey) -> Void)) -> PersistentHotkey {
        HOTKEY_HANDLERS[identifier] = handler
        return self
    }

    func unregister() {
        log.debug("Unregistered hotkey \(identifier)")
        HotKeyCenter.shared.unregisterHotKey(with: hotkey.identifier)
    }

    func register() {
        log.debug("Registered hotkey \(identifier)")
        #if DEBUG
            mainAsyncAfter(ms: 10) { [weak self] in log.verbose("Registered hotkey \(self?.description ?? "")") }
        #endif
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

    func dict() -> [HotkeyPart: Int] {
        [
            .enabled: isEnabled ? 1 : 0,
            .keyCode: hotkey.keyCombo.QWERTYKeyCode,
            .modifiers: hotkey.keyCombo.modifiers,
        ]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(identifier, forKey: .identifier)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers, forKey: .modifiers)
        try container.encode(isEnabled, forKey: .enabled)
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

    static let defaults: Set<PersistentHotkey> = [
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.toggle.rawValue,
            keyCombo: KeyCombo(
                QWERTYKeyCode: kVK_ANSI_L,
                cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control, .option])
            )!,
            target: appDelegate,
            action: handler(identifier: .toggle),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.lunar.rawValue,
            keyCombo: KeyCombo(
                QWERTYKeyCode: kVK_ANSI_L,
                cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .option, .shift])
            )!,
            target: appDelegate,
            action: handler(identifier: .lunar),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.percent0.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_0, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate,
            action: handler(identifier: .percent0),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.percent25.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_1, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate,
            action: handler(identifier: .percent25),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.percent50.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_2, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate,
            action: handler(identifier: .percent50),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.percent75.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_3, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate,
            action: handler(identifier: .percent75),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.percent100.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_4, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate,
            action: handler(identifier: .percent100),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.faceLight.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_5, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate,
            action: handler(identifier: .faceLight),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.blackOut.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_ANSI_6, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]))!,
            target: appDelegate,
            action: handler(identifier: .blackOut),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.preciseBrightnessUp.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F2, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .option]))!,
            target: appDelegate,
            action: handler(identifier: .preciseBrightnessUp),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.preciseBrightnessDown.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F1, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .option]))!,
            target: appDelegate,
            action: handler(identifier: .preciseBrightnessDown),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.preciseContrastUp.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F2, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .shift, .option]))!,
            target: appDelegate,
            action: handler(identifier: .preciseContrastUp),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.preciseContrastDown.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F1, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .shift, .option]))!,
            target: appDelegate,
            action: handler(identifier: .preciseContrastDown),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.preciseVolumeUp.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F12, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .option]))!,
            target: appDelegate,
            action: handler(identifier: .preciseVolumeUp),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.preciseVolumeDown.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F11, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .option]))!,
            target: appDelegate,
            action: handler(identifier: .preciseVolumeDown),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.brightnessUp.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F2, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command]))!,
            target: appDelegate,
            action: handler(identifier: .brightnessUp),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.brightnessDown.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F1, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command]))!,
            target: appDelegate,
            action: handler(identifier: .brightnessDown),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.contrastUp.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F2, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .shift]))!,
            target: appDelegate,
            action: handler(identifier: .contrastUp),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.contrastDown.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F1, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .shift]))!,
            target: appDelegate,
            action: handler(identifier: .contrastDown),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.muteAudio.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F10, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command]))!,
            target: appDelegate,
            action: handler(identifier: .muteAudio),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.volumeUp.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F12, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command]))!,
            target: appDelegate,
            action: handler(identifier: .volumeUp),
            actionQueue: .main
        )),
        PersistentHotkey(hotkey: Magnet.HotKey(
            identifier: HotkeyIdentifier.volumeDown.rawValue,
            keyCombo: KeyCombo(QWERTYKeyCode: kVK_F11, cocoaModifiers: NSEvent.ModifierFlags(arrayLiteral: [.command]))!,
            target: appDelegate,
            action: handler(identifier: .volumeDown),
            actionQueue: .main
        )),
    ]

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
        }
    }

    static func setKeyEquivalent(_ identifier: String, menuItem: NSMenuItem?, hotkeys: Set<PersistentHotkey>) {
        guard let menuItem = menuItem, let hotkey = hotkeys.first(where: { $0.identifier == identifier }) else { return }
        if hotkey.isEnabled {
            if let keyEquivalent = Hotkey.functionKeyMapping[hotkey.keyCode] {
                menuItem.keyEquivalent = keyEquivalent
            } else {
                menuItem.keyEquivalent = hotkey.keyChar
            }
            menuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags(carbonModifiers: hotkey.modifiers)
        } else {
            menuItem.keyEquivalent = ""
        }
    }

    static func showOsd(osdImage: OSDImage, value: UInt32, display: Display, locked: Bool = false) {
        guard let manager = OSDManager.sharedManager() as? OSDManager else {
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
            controlID = .AUDIO_SPEAKER_VOLUME
        default:
            break
        }

        let locked = display.control is DDCControl && (DDC.skipWritingPropertyById[display.id]?.contains(controlID) ?? false)
        let mirroredID = CGDisplayMirrorsDisplay(display.id)
        let osdID = mirroredID != kCGNullDirectDisplay ? mirroredID : display.id
        manager.showImage(
            osdImage.rawValue,
            onDisplayID: osdID,
            priority: 0x1F4,
            msecUntilFade: 1500,
            filledChiclets: value,
            totalChiclets: 100,
            locked: locked
        )
    }
}

// MARK: - AppDelegate + MediaKeyTapDelegate

extension AppDelegate: MediaKeyTapDelegate {
    func volumeOsdImage(display: Display? = nil) -> OSDImage {
        guard let display = (display ?? displayController.currentDisplay) else {
            return .volume
        }

        if display.audioMuted {
            return .muted
        } else {
            return .volume
        }
    }

    func startOrRestartMediaKeyTap(brightnessKeysEnabled: Bool? = nil, volumeKeysEnabled: Bool? = nil, checkPermissions: Bool = false) {
        if checkPermissions {
            acquirePrivileges()
        } else if let enabled = brightnessKeysEnabled, enabled {
            acquirePrivileges()
        } else if let enabled = volumeKeysEnabled, enabled {
            acquirePrivileges()
        }

        asyncNow(runLoopQueue: mediaKeyStarterQueue) {
            asyncNow(timeout: 5.seconds, queue: concurrentQueue) {
                mediaKeyTapBrightness?.stop()
                mediaKeyTapBrightness = nil

                mediaKeyTapAudio?.stop()
                mediaKeyTapAudio = nil

                if brightnessKeysEnabled ?? CachedDefaults[.brightnessKeysEnabled] {
                    mediaKeyTapBrightness = MediaKeyTap(
                        delegate: self,
                        for: [.brightnessUp, .brightnessDown],
                        observeBuiltIn: true
                    )
                    mediaKeyTapBrightness?.start(tries: 0)
                }

                if volumeKeysEnabled ?? CachedDefaults[.volumeKeysEnabled], let audioDevice = simplyCA.defaultOutputDevice,
                   !audioDevice.canSetVirtualMainVolume(scope: .output)
                {
                    mediaKeyTapAudio = MediaKeyTap(delegate: self, for: [.mute, .volumeUp, .volumeDown], observeBuiltIn: true)
                    mediaKeyTapAudio?.start(tries: 0)
                }
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

    func adjust(_ mediaKey: MediaKey, by value: Int? = nil, currentDisplay: Bool = false, contrast: Bool = false) {
        let affectBuiltin = CachedDefaults[.hotkeysAffectBuiltin]

        switch mediaKey {
        case .brightnessUp where contrast:
            increaseContrast(by: value, currentDisplay: currentDisplay)
        case .brightnessUp:
            increaseBrightness(by: value, currentDisplay: currentDisplay)
        case .brightnessDown where contrast:
            decreaseContrast(by: value, currentDisplay: currentDisplay)
        case .brightnessDown:
            decreaseBrightness(by: value, currentDisplay: currentDisplay)
        default:
            break
        }

        let showOSD = { (display: Display) in
            if contrast, display.isBuiltin { return }

            if contrast {
                Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, display: display)
            } else {
                Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, display: display)
            }
        }

        if currentDisplay {
            guard let display = displayController.currentDisplay, affectBuiltin || !display.isBuiltin else { return }
            showOSD(display)
        } else {
            displayController.activeDisplays.values
                .filter { affectBuiltin || !$0.isBuiltin }
                .forEach(showOSD)
        }
    }

    func handleBrightnessKeys(
        withLidClosed lidClosed: Bool,
        mediaKey: MediaKey,
        modifiers flags: NSEvent.ModifierFlags,
        event: CGEvent
    ) -> CGEvent? {
        let allMonitors = CachedDefaults[.mediaKeysControlAllMonitors]
        let affectBuiltin = CachedDefaults[.hotkeysAffectBuiltin]

        switch flags {
        case [] where lidClosed:
            log.info("No modifiers and lid closed, adjusting \(allMonitors ? "all monitors" : "current display")")
            adjust(mediaKey, currentDisplay: !allMonitors)
        case [.option, .shift] where lidClosed:
            log.info("Option+Shift modifiers and lid closed, adjusting \(allMonitors ? "all monitors" : "current display")")
            adjust(mediaKey, by: 1, currentDisplay: !allMonitors)

        case [] where displayController.adaptiveModeKey == .sync,
             [.option, .shift] where displayController.adaptiveModeKey == .sync:
            log.info("Sync Mode active, ignoring media key event")
            return event

        case [] where allMonitors:
            log.info("No modifiers and all monitors, adjusting all monitors")
            adjust(mediaKey, currentDisplay: false)
            if !affectBuiltin {
                return event
            }
        case [.option, .shift] where allMonitors:
            log.info("Option+Shift and all monitors, adjusting all monitors")
            adjust(mediaKey, by: 1, currentDisplay: false)
            if !affectBuiltin {
                return event
            }
        case []:
            guard let cursorDisplay = displayController.cursorDisplay, affectBuiltin || !cursorDisplay.isBuiltin else {
                log.info("No main display, ignoring media key event")
                return event
            }
            log.info("No modifiers and lid open, adjusting current display")
            adjust(mediaKey, currentDisplay: true)
        case [.option, .shift]:
            guard let cursorDisplay = displayController.cursorDisplay, affectBuiltin || !cursorDisplay.isBuiltin else {
                log.info("No main display, ignoring media key event")
                return event
            }
            log.info("Option+Shift modifiers and lid open, adjusting current display")
            adjust(mediaKey, by: 1, currentDisplay: true)

        case [.control] where lidClosed:
            log.info("Control modifier and lid closed, adjusting current display")
            adjust(mediaKey, currentDisplay: true)
        case [.control, .option] where lidClosed:
            log.info("Control+Option modifiers and lid closed, adjusting current display")
            adjust(mediaKey, by: 1, currentDisplay: true)

        case [.control]:
            guard let cursorDisplay = displayController.cursorDisplay, affectBuiltin || !cursorDisplay.isBuiltin else {
                log.info("No main display, adjusting all external monitors")
                adjust(mediaKey, currentDisplay: false)
                return nil
            }

            log.info("Control modifier and lid opened, adjusting \(allMonitors ? "all monitors" : "current display")")
            adjust(mediaKey, currentDisplay: !allMonitors)
        case [.control, .option]:
            guard let cursorDisplay = displayController.cursorDisplay, affectBuiltin || !cursorDisplay.isBuiltin else {
                log.info("No main display, adjusting all external monitors")
                adjust(mediaKey, currentDisplay: false)
                return nil
            }

            log.info("Control+Option modifiers and lid opened, adjusting \(allMonitors ? "all monitors" : "current display")")
            adjust(mediaKey, by: 1, currentDisplay: !allMonitors)
        case [.control, .shift]:
            log.info("Control+Shift modifiers and lid opened, adjusting \(allMonitors ? "all monitors" : "current display")")
            adjust(mediaKey, currentDisplay: !allMonitors, contrast: true)
        case [.control, .shift, .option]:
            log.info("Control+Shift+Option modifiers and lid opened, adjusting \(allMonitors ? "all monitors" : "current display")")
            adjust(mediaKey, by: 1, currentDisplay: !allMonitors, contrast: true)

        default:
            log.info("Ignoring media key event")
            return event
        }

        return nil
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

        guard displayController.activeDisplays.count > 0 else {
            return event
        }

        guard isVolumeKey(mediaKey) else {
            let lidClosed = displayController.lidClosed || SyncMode.builtinDisplay == nil
            return handleBrightnessKeys(withLidClosed: lidClosed, mediaKey: mediaKey, modifiers: flags, event: event)
        }

        switch mediaKey {
        case .volumeUp:
            guard let display = displayController.currentAudioDisplay else {
                return event
            }

            if flags.isSuperset(of: [.option, .shift]) {
                increaseVolume(by: 1)
            } else {
                increaseVolume()
            }
            if display.audioMuted {
                toggleAudioMuted()
            }

            Hotkey.showOsd(osdImage: volumeOsdImage(), value: display.volume.uint32Value, display: display)
        case .volumeDown:
            guard let display = displayController.currentAudioDisplay else {
                return event
            }

            if flags.isSuperset(of: [.option, .shift]) {
                decreaseVolume(by: 1)
            } else {
                decreaseVolume()
            }
            if display.audioMuted {
                toggleAudioMuted()
            }

            Hotkey.showOsd(osdImage: volumeOsdImage(), value: display.volume.uint32Value, display: display)
        case .mute:
            guard let display = displayController.currentAudioDisplay else {
                return event
            }

            toggleAudioMuted()

            Hotkey.showOsd(osdImage: volumeOsdImage(), value: display.volume.uint32Value, display: display)
        default:
            return event
        }

        return nil
    }

    @objc func toggleHotkeyHandler() {
        displayController.toggle()
        log.debug("Toggle Hotkey pressed")
    }

    @objc func lunarHotkeyHandler() {
        showWindow()
        log.debug("Show Window Hotkey pressed")
    }

    @objc func percent0HotkeyHandler() {
        cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        setLightPercent(percent: 0)
        log.debug("0% Hotkey pressed")
    }

    @objc func percent25HotkeyHandler() {
        cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        setLightPercent(percent: 25)
        log.debug("25% Hotkey pressed")
    }

    @objc func percent50HotkeyHandler() {
        cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        setLightPercent(percent: 50)
        log.debug("50% Hotkey pressed")
    }

    @objc func percent75HotkeyHandler() {
        cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        setLightPercent(percent: 75)
        log.debug("75% Hotkey pressed")
    }

    @objc func percent100HotkeyHandler() {
        cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        setLightPercent(percent: 100)
        log.debug("100% Hotkey pressed")
    }

    @objc func faceLightHotkeyHandler() {
        guard lunarProActive else { return }
        cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        faceLight(self)
        log.debug("FaceLight Hotkey pressed")
    }

    @objc func blackOutHotkeyHandler() {
        guard lunarProActive else { return }
        cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        blackOut(self)
        log.debug("BlackOut Hotkey pressed")
    }

    func brightnessUpAction(offset: Int? = nil) {
        cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        increaseBrightness(by: offset)

        for (_, display) in displayController.activeDisplays {
            guard CachedDefaults[.hotkeysAffectBuiltin] || !display.isBuiltin else { continue }
            Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, display: display)
        }

        log.debug("Brightness Up Hotkey pressed")
    }

    func brightnessDownAction(offset: Int? = nil) {
        cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        decreaseBrightness(by: offset)

        for (_, display) in displayController.activeDisplays {
            guard CachedDefaults[.hotkeysAffectBuiltin] || !display.isBuiltin else { continue }
            Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, display: display)
        }

        log.debug("Brightness Down Hotkey pressed")
    }

    func contrastUpAction(offset: Int? = nil) {
        cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        increaseContrast(by: offset)

        for (_, display) in displayController.activeDisplays {
            guard !display.isBuiltin else { continue }
            Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, display: display)
        }

        log.debug("Contrast Up Hotkey pressed")
    }

    func contrastDownAction(offset: Int? = nil) {
        cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        decreaseContrast(by: offset)

        for (_, display) in displayController.activeDisplays {
            guard !display.isBuiltin else { continue }
            Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, display: display)
        }

        log.debug("Contrast Down Hotkey pressed")
    }

    func volumeUpAction(offset: Int? = nil) {
        increaseVolume(by: offset)
        if let display = displayController.currentDisplay, display.audioMuted {
            toggleAudioMuted()
        }

        if let display = displayController.currentAudioDisplay {
            Hotkey.showOsd(osdImage: volumeOsdImage(display: display), value: display.volume.uint32Value, display: display)
        }

        log.debug("Volume Up Hotkey pressed")
    }

    func volumeDownAction(offset: Int? = nil) {
        decreaseVolume(by: offset)
        if let display = displayController.currentDisplay, display.audioMuted {
            toggleAudioMuted()
        }

        if let display = displayController.currentAudioDisplay {
            Hotkey.showOsd(osdImage: volumeOsdImage(display: display), value: display.volume.uint32Value, display: display)
        }

        log.debug("Volume Down Hotkey pressed")
    }

    @objc func muteAudioHotkeyHandler() {
        toggleAudioMuted()

        if let display = displayController.currentAudioDisplay {
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
