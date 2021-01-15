//
//  Hotkeys.swift
//  Lunar
//
//  Created by Alin on 25/02/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import AMCoreAudio
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

func disableUpDownHotkeys() {
    log.debug("Unregistering up/down hotkeys")
    HotKeyCenter.shared.unregisterHotKey(with: "increaseValue")
    HotKeyCenter.shared.unregisterHotKey(with: "decreaseValue")
    upHotkey?.unregister()
    downHotkey?.unregister()
    upHotkey = nil
    downHotkey = nil
}

func disableLeftRightHotkeys() {
    log.debug("Unregistering left/right hotkeys")
    HotKeyCenter.shared.unregisterHotKey(with: "navigateBack")
    HotKeyCenter.shared.unregisterHotKey(with: "navigateForward")
    leftHotkey?.unregister()
    rightHotkey?.unregister()
    leftHotkey = nil
    rightHotkey = nil
}

func disableUIHotkeys() {
    disableUpDownHotkeys()
    disableLeftRightHotkeys()
}

class AudioEventSubscriber: EventSubscriber {
    func eventReceiver(_ event: AMCoreAudio.Event) {
        guard let hwEvent = event as? AudioHardwareEvent else {
            return
        }

        switch hwEvent {
        case .defaultOutputDeviceChanged, .defaultSystemOutputDeviceChanged:
            runInMainThread {
                appDelegate().startOrRestartMediaKeyTap()
            }
        default:
            return
        }
    }

    var hashValue: Int = 100
}

var mediaKeyTapBrightness: MediaKeyTap?
var mediaKeyTapAudio: MediaKeyTap?
let fineAdjustmentDisabledBecauseOfOptionKey = "Fine adjustment can't be enabled when the hotkey uses the Option key"

enum HotkeyIdentifier: String, CaseIterable, Codable {
    case toggle,
         lunar,
         percent0,
         percent25,
         percent50,
         percent75,
         percent100,
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

enum HotkeyPart: String, CaseIterable, Codable {
    case modifiers, keyCode, enabled
}

enum OSDImage: Int64 {
    case brightness = 1
    case contrast = 11
    case volume = 3
    case muted = 4
}

struct PersistentHotkey {
    var hotkey: HotKey {
        didSet {
            Defaults[.hotkeys][hotkey.identifier] = dict()
        }
    }

    var isEnabled: Bool {
        didSet {
            Defaults[.hotkeys][hotkey.identifier]?[.enabled] = isEnabled ? 1 : 0

            if isEnabled {
                hotkey.register()
            } else {
                hotkey.unregister()
            }
        }
    }

    var keyCombo: KeyCombo {
        return hotkey.keyCombo
    }

    var identifier: String {
        return hotkey.identifier
    }

    var target: AnyObject? {
        return hotkey.target
    }

    var action: Selector? {
        return hotkey.action
    }

    var handler: ((HotKey) -> Void)? {
        return hotkey.callback
    }

    func unregister() {
        hotkey.unregister()
    }

    func register() {
        hotkey.register()
    }

    func dict() -> [HotkeyPart: Int] {
        [
            .enabled: isEnabled ? 1 : 0,
            .keyCode: hotkey.keyCombo.QWERTYKeyCode,
            .modifiers: hotkey.keyCombo.modifiers,
        ]
    }
}

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
    static var keys: [String: PersistentHotkey?] = [:]

    static let defaults: [String: [HotkeyPart: Int]] = [
        HotkeyIdentifier.toggle.rawValue: [
            .enabled: 1,
            .keyCode: kVK_ANSI_L,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control, .option]).carbonModifiers(),
        ],
        HotkeyIdentifier.lunar.rawValue: [
            .enabled: 1,
            .keyCode: kVK_ANSI_L,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .option, .shift]).carbonModifiers(),
        ],
        HotkeyIdentifier.percent0.rawValue: [
            .enabled: 1,
            .keyCode: kVK_ANSI_0,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]).carbonModifiers(),
        ],
        HotkeyIdentifier.percent25.rawValue: [
            .enabled: 1,
            .keyCode: kVK_ANSI_1,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]).carbonModifiers(),
        ],
        HotkeyIdentifier.percent50.rawValue: [
            .enabled: 1,
            .keyCode: kVK_ANSI_2,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]).carbonModifiers(),
        ],
        HotkeyIdentifier.percent75.rawValue: [
            .enabled: 1,
            .keyCode: kVK_ANSI_3,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]).carbonModifiers(),
        ],
        HotkeyIdentifier.percent100.rawValue: [
            .enabled: 1,
            .keyCode: kVK_ANSI_4,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.command, .control]).carbonModifiers(),
        ],
        HotkeyIdentifier.preciseBrightnessUp.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F2,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control, .option]).carbonModifiers(),
        ],
        HotkeyIdentifier.preciseBrightnessDown.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F1,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control, .option]).carbonModifiers(),
        ],
        HotkeyIdentifier.preciseContrastUp.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F2,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control, .shift, .option]).carbonModifiers(),
        ],
        HotkeyIdentifier.preciseContrastDown.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F1,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control, .shift, .option]).carbonModifiers(),
        ],
        HotkeyIdentifier.preciseVolumeUp.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F12,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control, .option]).carbonModifiers(),
        ],
        HotkeyIdentifier.preciseVolumeDown.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F11,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control, .option]).carbonModifiers(),
        ],
        HotkeyIdentifier.brightnessUp.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F2,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control]).carbonModifiers(),
        ],
        HotkeyIdentifier.brightnessDown.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F1,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control]).carbonModifiers(),
        ],
        HotkeyIdentifier.contrastUp.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F2,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control, .shift]).carbonModifiers(),
        ],
        HotkeyIdentifier.contrastDown.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F1,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control, .shift]).carbonModifiers(),
        ],
        HotkeyIdentifier.muteAudio.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F10,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control]).carbonModifiers(),
        ],
        HotkeyIdentifier.volumeUp.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F12,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control]).carbonModifiers(),
        ],
        HotkeyIdentifier.volumeDown.rawValue: [
            .enabled: 1,
            .keyCode: kVK_F11,
            .modifiers: NSEvent.ModifierFlags(arrayLiteral: [.control]).carbonModifiers(),
        ],
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

    static func setKeyEquivalent(_ identifier: String, menuItem: NSMenuItem?, hotkeys: [String: [HotkeyPart: Int]]) {
        guard let menuItem = menuItem else { return }
        if let hk = hotkeys[identifier], let keyCode = hk[.keyCode], let enabled = hk[.enabled], let modifiers = hk[.modifiers] {
            if enabled == 1 {
                if let keyEquivalent = Hotkey.functionKeyMapping[keyCode] {
                    menuItem.keyEquivalent = keyEquivalent
                } else if let key = Key(QWERTYKeyCode: keyCode) {
                    let keyChar = (Sauce.shared.character(by: Int(Sauce.shared.keyCode(by: key)), carbonModifiers: 0) ?? "").uppercased()
                    menuItem.keyEquivalent = keyChar
                }
                menuItem.keyEquivalentModifierMask = modifiers.convertSupportCocoaModifiers()
            } else {
                menuItem.keyEquivalent = ""
            }
        } else {
            menuItem.keyEquivalent = ""
        }
    }

    static func showOsd(osdImage: OSDImage, value: UInt32, displayID: CGDirectDisplayID, locked: Bool = false) {
        guard let manager = OSDManager.sharedManager() as? OSDManager else {
            log.warning("No OSDManager available")
            return
        }

        manager.showImage(
            osdImage.rawValue,
            onDisplayID: displayID,
            priority: 0x1F4,
            msecUntilFade: 1500,
            filledChiclets: value,
            totalChiclets: 100,
            locked: locked
        )
    }
}

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

    func startOrRestartMediaKeyTap(_ brightnessKeysEnabled: Bool? = nil, volumeKeysEnabled: Bool? = nil) {
        let workItem = DispatchWorkItem {
            mediaKeyTapBrightness?.stop()
            mediaKeyTapBrightness = nil

            mediaKeyTapAudio?.stop()
            mediaKeyTapAudio = nil

            if brightnessKeysEnabled ?? Defaults[.brightnessKeysEnabled] {
                mediaKeyTapBrightness = MediaKeyTap(delegate: self, for: [.brightnessUp, .brightnessDown], observeBuiltIn: false)
                mediaKeyTapBrightness?.start()
            }

            if volumeKeysEnabled ?? Defaults[.volumeKeysEnabled], let audioDevice = AudioDevice.defaultOutputDevice(),
               !audioDevice.canSetVirtualMasterVolume(direction: .playback)
            {
                mediaKeyTapAudio = MediaKeyTap(delegate: self, for: [.mute, .volumeUp, .volumeDown], observeBuiltIn: true)
                mediaKeyTapAudio?.start()
            }
        }
        concurrentQueue.async(execute: workItem)
        switch workItem.wait(timeout: DispatchTime.now() + 5) {
        case .timedOut:
            workItem.cancel()
        default:
            return
        }
    }

    func handle(mediaKey: MediaKey, event _: KeyEvent?, modifiers flags: NSEvent.ModifierFlags?) {
        guard let display = displayController.currentDisplay else {
            return
        }

        var locked = false

        switch mediaKey {
        case .brightnessUp:
            if let flags = flags, flags.contains(.option), flags.intersection([.control, .command, .shift]).isEmpty {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Displays.prefPane"))
            } else if let flags = flags, flags.contains(.control) {
                locked = DDC.skipWritingPropertyById[display.id]?.contains(.CONTRAST) ?? false
                if !locked {
                    if flags.isSuperset(of: [.option, .shift]) {
                        increaseContrast(by: 1, currentDisplay: true)
                    } else {
                        increaseContrast(currentDisplay: true)
                    }
                }
                Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, displayID: display.id, locked: locked)
            } else {
                locked = DDC.skipWritingPropertyById[display.id]?.contains(.BRIGHTNESS) ?? false
                if !locked {
                    if flags?.isSuperset(of: [.option, .shift]) ?? false {
                        increaseBrightness(by: 1, currentDisplay: true)
                    } else {
                        increaseBrightness(currentDisplay: true)
                    }
                }
                Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, displayID: display.id, locked: locked)
            }
        case .brightnessDown:
            if let flags = flags, flags.contains(.option), flags.intersection([.control, .command, .shift]).isEmpty {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Displays.prefPane"))
            } else if let flags = flags, flags.contains(.control) {
                locked = DDC.skipWritingPropertyById[display.id]?.contains(.CONTRAST) ?? false
                if !locked {
                    if flags.isSuperset(of: [.option, .shift]) {
                        decreaseContrast(by: 1, currentDisplay: true)
                    } else {
                        decreaseContrast(currentDisplay: true)
                    }
                }
                Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, displayID: display.id, locked: locked)
            } else {
                locked = DDC.skipWritingPropertyById[display.id]?.contains(.BRIGHTNESS) ?? false
                if !locked {
                    if flags?.isSuperset(of: [.option, .shift]) ?? false {
                        decreaseBrightness(by: 1, currentDisplay: true)
                    } else {
                        decreaseBrightness(currentDisplay: true)
                    }
                }
                Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, displayID: display.id, locked: locked)
            }
        case .volumeUp:
            if let flags = flags, flags.contains(.option), flags.intersection([.control, .command, .shift]).isEmpty {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Sound.prefPane"))
                break
            }

            guard let display = displayController.currentAudioDisplay else {
                break
            }

            locked = DDC.skipWritingPropertyById[display.id]?.isSuperset(of: [.AUDIO_SPEAKER_VOLUME, .AUDIO_MUTE]) ?? false
            if !locked {
                if flags?.isSuperset(of: [.option, .shift]) ?? false {
                    increaseVolume(by: 1, currentDisplay: true)
                } else {
                    increaseVolume(currentDisplay: true)
                }
                if display.audioMuted {
                    toggleAudioMuted()
                }
            }

            Hotkey.showOsd(osdImage: volumeOsdImage(), value: display.volume.uint32Value, displayID: display.id, locked: locked)
        case .volumeDown:
            if let flags = flags, flags.contains(.option), flags.intersection([.control, .command, .shift]).isEmpty {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Sound.prefPane"))
                break
            }

            guard let display = displayController.currentAudioDisplay else {
                break
            }

            locked = DDC.skipWritingPropertyById[display.id]?.isSuperset(of: [.AUDIO_SPEAKER_VOLUME, .AUDIO_MUTE]) ?? false
            if !locked {
                if flags?.isSuperset(of: [.option, .shift]) ?? false {
                    decreaseVolume(by: 1, currentDisplay: true)
                } else {
                    decreaseVolume(currentDisplay: true)
                }
                if display.audioMuted {
                    toggleAudioMuted()
                }
            }

            Hotkey.showOsd(osdImage: volumeOsdImage(), value: display.volume.uint32Value, displayID: display.id, locked: locked)
        case .mute:
            if let flags = flags, flags.contains(.option), flags.intersection([.control, .command, .shift]).isEmpty {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Sound.prefPane"))
                break
            }

            guard let display = displayController.currentAudioDisplay else {
                break
            }

            locked = DDC.skipWritingPropertyById[display.id]?.isSuperset(of: [.AUDIO_SPEAKER_VOLUME, .AUDIO_MUTE]) ?? false
            if !locked {
                toggleAudioMuted()
            }
            Hotkey.showOsd(osdImage: volumeOsdImage(), value: display.volume.uint32Value, displayID: display.id, locked: locked)
        default:
            log.info("Media key pressed")
        }
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
        setLightPercent(percent: 0)
        log.debug("0% Hotkey pressed")
    }

    @objc func percent25HotkeyHandler() {
        setLightPercent(percent: 25)
        log.debug("25% Hotkey pressed")
    }

    @objc func percent50HotkeyHandler() {
        setLightPercent(percent: 50)
        log.debug("50% Hotkey pressed")
    }

    @objc func percent75HotkeyHandler() {
        setLightPercent(percent: 75)
        log.debug("75% Hotkey pressed")
    }

    @objc func percent100HotkeyHandler() {
        setLightPercent(percent: 100)
        log.debug("100% Hotkey pressed")
    }

    func brightnessUpAction(offset: Int? = nil) {
        increaseBrightness(by: offset)

        for (id, display) in displayController.activeDisplays {
            Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, displayID: id)
        }

        log.debug("Brightness Up Hotkey pressed")
    }

    func brightnessDownAction(offset: Int? = nil) {
        decreaseBrightness(by: offset)

        for (id, display) in displayController.activeDisplays {
            Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, displayID: id)
        }

        log.debug("Brightness Down Hotkey pressed")
    }

    func contrastUpAction(offset: Int? = nil) {
        increaseContrast(by: offset)

        for (id, display) in displayController.activeDisplays {
            Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, displayID: id)
        }

        log.debug("Contrast Up Hotkey pressed")
    }

    func contrastDownAction(offset: Int? = nil) {
        decreaseContrast(by: offset)

        for (id, display) in displayController.activeDisplays {
            Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, displayID: id)
        }

        log.debug("Contrast Down Hotkey pressed")
    }

    func volumeUpAction(offset: Int? = nil) {
        increaseVolume(by: offset, currentDisplay: true)
        if let display = displayController.currentDisplay, display.audioMuted {
            toggleAudioMuted()
        }

        if let display = displayController.currentDisplay {
            Hotkey.showOsd(osdImage: volumeOsdImage(display: display), value: display.volume.uint32Value, displayID: display.id)
        }

        log.debug("Volume Up Hotkey pressed")
    }

    func volumeDownAction(offset: Int? = nil) {
        decreaseVolume(by: offset, currentDisplay: true)
        if let display = displayController.currentDisplay, display.audioMuted {
            toggleAudioMuted()
        }

        if let display = displayController.currentDisplay {
            Hotkey.showOsd(osdImage: volumeOsdImage(display: display), value: display.volume.uint32Value, displayID: display.id)
        }

        log.debug("Volume Down Hotkey pressed")
    }

    @objc func muteAudioHotkeyHandler() {
        toggleAudioMuted()

        if let display = displayController.currentDisplay {
            Hotkey.showOsd(osdImage: volumeOsdImage(display: display), value: display.volume.uint32Value, displayID: display.id)
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
}

extension AppDelegate: EventSubscriber {
    /**
     Fires off when the default audio device changes.
     */
    func eventReceiver(_ event: Event) {
        if case let .defaultOutputDeviceChanged(audioDevice)? = event as? AudioHardwareEvent {
            log.debug("Default output device changed to \(audioDevice.name).")
            if audioDevice.canSetVirtualMasterVolume(direction: .playback) {
                log.debug("The device can set its own volume")
            } else {
                log.debug("The device can't set its own volume")
            }

            self.startOrRestartMediaKeyTap()
        }
    }
}
