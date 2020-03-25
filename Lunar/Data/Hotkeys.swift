//
//  Hotkeys.swift
//  Lunar
//
//  Created by Alin on 25/02/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import AMCoreAudio
import Carbon.HIToolbox
import Magnet
import MediaKeyTap

var mediaKeyTap: MediaKeyTap?
let fineAdjustmentDisabledBecauseOfOptionKey = "Fine adjustment can't be enabled when the hotkey uses the Option key"

enum HotkeyIdentifier: String, CaseIterable {
    case toggle,
        start,
        pause,
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

let preciseHotkeys: Set<HotkeyIdentifier> = [.preciseBrightnessUp, .preciseBrightnessDown, .preciseContrastUp, .preciseContrastDown, .preciseVolumeUp, .preciseVolumeDown]
let coarseHotkeysMapping: [HotkeyIdentifier: HotkeyIdentifier] = [
    .preciseBrightnessUp: .brightnessUp,
    .preciseBrightnessDown: .brightnessDown,
    .preciseContrastUp: .contrastUp,
    .preciseContrastDown: .contrastDown,
    .preciseVolumeUp: .volumeUp,
    .preciseVolumeDown: .volumeDown,
]
let preciseHotkeysMapping: [HotkeyIdentifier: HotkeyIdentifier] = [
    .brightnessUp: .preciseBrightnessUp,
    .brightnessDown: .preciseBrightnessDown,
    .contrastUp: .preciseContrastUp,
    .contrastDown: .preciseContrastDown,
    .volumeUp: .preciseVolumeUp,
    .volumeDown: .preciseVolumeDown,
]

enum HotkeyPart: String, CaseIterable {
    case modifiers, keyCode, enabled
}

enum OSDImage: Int64 {
    case brightness = 1
    case contrast = 11
    case volume = 3
    case muted = 4
}

class Hotkey {
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
    static var keys: [HotkeyIdentifier: Magnet.HotKey?] = [:]

    static let defaults: [HotkeyIdentifier: [HotkeyPart: Int]] = [
        .toggle: [
            .enabled: 1,
            .keyCode: kVK_ANSI_L,
            .modifiers: KeyTransformer.carbonFlags(from: [.command, .control]),
        ],
        .start: [
            .enabled: 1,
            .keyCode: kVK_ANSI_L,
            .modifiers: KeyTransformer.carbonFlags(from: [.command, .control, .option]),
        ],
        .pause: [
            .enabled: 1,
            .keyCode: kVK_ANSI_L,
            .modifiers: KeyTransformer.carbonFlags(from: [.command, .control, .option, .shift]),
        ],
        .lunar: [
            .enabled: 1,
            .keyCode: kVK_ANSI_L,
            .modifiers: KeyTransformer.carbonFlags(from: [.command, .option, .shift]),
        ],
        .percent0: [
            .enabled: 1,
            .keyCode: kVK_ANSI_0,
            .modifiers: KeyTransformer.carbonFlags(from: [.command, .control]),
        ],
        .percent25: [
            .enabled: 1,
            .keyCode: kVK_ANSI_1,
            .modifiers: KeyTransformer.carbonFlags(from: [.command, .control]),
        ],
        .percent50: [
            .enabled: 1,
            .keyCode: kVK_ANSI_2,
            .modifiers: KeyTransformer.carbonFlags(from: [.command, .control]),
        ],
        .percent75: [
            .enabled: 1,
            .keyCode: kVK_ANSI_3,
            .modifiers: KeyTransformer.carbonFlags(from: [.command, .control]),
        ],
        .percent100: [
            .enabled: 1,
            .keyCode: kVK_ANSI_4,
            .modifiers: KeyTransformer.carbonFlags(from: [.command, .control]),
        ],
        .preciseBrightnessUp: [
            .enabled: 1,
            .keyCode: kVK_F2,
            .modifiers: KeyTransformer.carbonFlags(from: [.control, .option]),
        ],
        .preciseBrightnessDown: [
            .enabled: 1,
            .keyCode: kVK_F1,
            .modifiers: KeyTransformer.carbonFlags(from: [.control, .option]),
        ],
        .preciseContrastUp: [
            .enabled: 1,
            .keyCode: kVK_F2,
            .modifiers: KeyTransformer.carbonFlags(from: [.control, .shift, .option]),
        ],
        .preciseContrastDown: [
            .enabled: 1,
            .keyCode: kVK_F1,
            .modifiers: KeyTransformer.carbonFlags(from: [.control, .shift, .option]),
        ],
        .preciseVolumeUp: [
            .enabled: 1,
            .keyCode: kVK_F12,
            .modifiers: KeyTransformer.carbonFlags(from: [.control, .option]),
        ],
        .preciseVolumeDown: [
            .enabled: 1,
            .keyCode: kVK_F11,
            .modifiers: KeyTransformer.carbonFlags(from: [.control, .option]),
        ],
        .brightnessUp: [
            .enabled: 1,
            .keyCode: kVK_F2,
            .modifiers: KeyTransformer.carbonFlags(from: [.control]),
        ],
        .brightnessDown: [
            .enabled: 1,
            .keyCode: kVK_F1,
            .modifiers: KeyTransformer.carbonFlags(from: [.control]),
        ],
        .contrastUp: [
            .enabled: 1,
            .keyCode: kVK_F2,
            .modifiers: KeyTransformer.carbonFlags(from: [.control, .shift]),
        ],
        .contrastDown: [
            .enabled: 1,
            .keyCode: kVK_F1,
            .modifiers: KeyTransformer.carbonFlags(from: [.control, .shift]),
        ],
        .muteAudio: [
            .enabled: 1,
            .keyCode: kVK_F10,
            .modifiers: KeyTransformer.carbonFlags(from: [.control]),
        ],
        .volumeUp: [
            .enabled: 1,
            .keyCode: kVK_F12,
            .modifiers: KeyTransformer.carbonFlags(from: [.control]),
        ],
        .volumeDown: [
            .enabled: 1,
            .keyCode: kVK_F11,
            .modifiers: KeyTransformer.carbonFlags(from: [.control]),
        ],
    ]

    static var defaultHotkeys: NSDictionary = Hotkey.toNSDictionary(Hotkey.defaults)

    static func toDictionary(_ hotkeys: [String: Any]) -> [HotkeyIdentifier: [HotkeyPart: Int]] {
        var hotkeySettings: [HotkeyIdentifier: [HotkeyPart: Int]] = [:]
        for (k, v) in hotkeys {
            guard let identifier = HotkeyIdentifier(rawValue: k), let hotkeyDict = v as? [String: Int] else { continue }
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

    static func toNSDictionary(_ hotkeys: [HotkeyIdentifier: [HotkeyPart: Int]]) -> NSDictionary {
        let keyDict: NSMutableDictionary = [:]
        for (identifier, hotkey) in hotkeys {
            let key: NSMutableDictionary = [:]
            for (part, value) in hotkey {
                key[part.rawValue] = value
            }
            keyDict[identifier.rawValue] = key
        }
        return keyDict
    }

    static func handler(identifier: HotkeyIdentifier) -> Selector {
        switch identifier {
        case .toggle:
            return #selector(AppDelegate.toggleHotkeyHandler)
        case .start:
            return #selector(AppDelegate.startHotkeyHandler)
        case .pause:
            return #selector(AppDelegate.pauseHotkeyHandler)
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

    static func setKeyEquivalent(_ identifier: HotkeyIdentifier, menuItem: NSMenuItem?, hotkeys: [HotkeyIdentifier: [HotkeyPart: Int]]) {
        guard let menuItem = menuItem else { return }
        if let hk = hotkeys[identifier], let keyCode = hk[.keyCode], let enabled = hk[.enabled], let modifiers = hk[.modifiers] {
            if enabled == 1 {
                if let keyEquivalent = Hotkey.functionKeyMapping[keyCode] {
                    menuItem.keyEquivalent = keyEquivalent
                } else {
                    menuItem.keyEquivalent = KeyCodeTransformer.shared.transformValue(keyCode, carbonModifiers: 0)
                }
                menuItem.keyEquivalentModifierMask = KeyTransformer.cocoaFlags(from: modifiers)
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
        guard let display = (display ?? brightnessAdapter.currentDisplay) else {
            return .volume
        }

        if display.audioMuted {
            return .muted
        } else {
            return .volume
        }
    }

    func startOrRestartMediaKeyTap(_ mediaKeysEnabled: Bool? = nil) {
        concurrentQueue.async {
            var keys: [MediaKey]

            mediaKeyTap?.stop()
            mediaKeyTap = nil
            if mediaKeysEnabled ?? datastore.defaults.mediaKeysEnabled {
                keys = [.brightnessUp, .brightnessDown, .mute, .volumeUp, .volumeDown]

                if let audioDevice = AudioDevice.defaultOutputDevice(), audioDevice.canSetVirtualMasterVolume(direction: .playback) {
                    let keysToDelete: [MediaKey] = [.volumeUp, .volumeDown, .mute]
                    keys.removeAll { keysToDelete.contains($0) }
                }
                mediaKeyTap = MediaKeyTap(delegate: self, for: keys, observeBuiltIn: false)
                mediaKeyTap?.start()
            }
        }
    }

    func handle(mediaKey: MediaKey, event _: KeyEvent?, modifiers flags: NSEvent.ModifierFlags?) {
        guard let display = brightnessAdapter.currentDisplay else {
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
        brightnessAdapter.toggle()
        log.debug("Toggle Hotkey pressed")
    }

    @objc func pauseHotkeyHandler() {
        brightnessAdapter.disable()
        log.debug("Pause Hotkey pressed")
    }

    @objc func startHotkeyHandler() {
        brightnessAdapter.enable()
        log.debug("Start Hotkey pressed")
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

        for (id, display) in brightnessAdapter.activeDisplays {
            Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, displayID: id)
        }

        log.debug("Brightness Up Hotkey pressed")
    }

    func brightnessDownAction(offset: Int? = nil) {
        decreaseBrightness(by: offset)

        for (id, display) in brightnessAdapter.activeDisplays {
            Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, displayID: id)
        }

        log.debug("Brightness Down Hotkey pressed")
    }

    func contrastUpAction(offset: Int? = nil) {
        increaseContrast(by: offset)

        for (id, display) in brightnessAdapter.activeDisplays {
            Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, displayID: id)
        }

        log.debug("Contrast Up Hotkey pressed")
    }

    func contrastDownAction(offset: Int? = nil) {
        decreaseContrast(by: offset)

        for (id, display) in brightnessAdapter.activeDisplays {
            Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, displayID: id)
        }

        log.debug("Contrast Down Hotkey pressed")
    }

    func volumeUpAction(offset: Int? = nil) {
        increaseVolume(by: offset, currentDisplay: true)
        if let display = brightnessAdapter.currentDisplay, display.audioMuted {
            toggleAudioMuted()
        }

        if let display = brightnessAdapter.currentDisplay {
            Hotkey.showOsd(osdImage: volumeOsdImage(display: display), value: display.volume.uint32Value, displayID: display.id)
        }

        log.debug("Volume Up Hotkey pressed")
    }

    func volumeDownAction(offset: Int? = nil) {
        decreaseVolume(by: offset, currentDisplay: true)
        if let display = brightnessAdapter.currentDisplay, display.audioMuted {
            toggleAudioMuted()
        }

        if let display = brightnessAdapter.currentDisplay {
            Hotkey.showOsd(osdImage: volumeOsdImage(display: display), value: display.volume.uint32Value, displayID: display.id)
        }

        log.debug("Volume Down Hotkey pressed")
    }

    @objc func muteAudioHotkeyHandler() {
        toggleAudioMuted()

        if let display = brightnessAdapter.currentDisplay {
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
