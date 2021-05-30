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

enum HotkeyIdentifier: String, CaseIterable, Codable {
    case toggle,
         lunar,
         percent0,
         percent25,
         percent50,
         percent75,
         percent100,
         faceLight,
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
            handleRegistration()
        }
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

    init(hotkey: HotKey, isEnabled: Bool = true) {
        self.hotkey = hotkey
        self.isEnabled = isEnabled
        handleRegistration(persist: false)
    }

    func unregister() {
        hotkey.unregister()
    }

    func register() {
        hotkey.register()
    }

    func handleRegistration(persist: Bool = true) {
        if persist {
            Defaults[.hotkeys][hotkey.identifier]?[.enabled] = isEnabled ? 1 : 0
        }

        if isEnabled {
            hotkey.register()
        } else {
            hotkey.unregister()
        }
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
        HotkeyIdentifier.faceLight.rawValue: [
            .enabled: 1,
            .keyCode: kVK_ANSI_5,
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
        case .faceLight:
            return #selector(AppDelegate.faceLightHotkeyHandler)
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
                    let keyChar = (Sauce.shared.character(for: Sauce.shared.keyCode(for: key).i, carbonModifiers: 0) ?? "").uppercased()
                    menuItem.keyEquivalent = keyChar
                }
                menuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags(carbonModifiers: modifiers)
            } else {
                menuItem.keyEquivalent = ""
            }
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

        manager.showImage(
            osdImage.rawValue,
            onDisplayID: display.id,
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
                mediaKeyTapBrightness = MediaKeyTap(
                    delegate: self,
                    for: [.brightnessUp, .brightnessDown],
                    observeBuiltIn: true
                )
                mediaKeyTapBrightness?.start()
            }

            if volumeKeysEnabled ?? Defaults[.volumeKeysEnabled], let audioDevice = simplyCA.defaultOutputDevice,
               !audioDevice.canSetVirtualMasterVolume(scope: .output)
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
            if contrast {
                Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, display: display)
            } else {
                Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, display: display)
            }
        }

        if currentDisplay {
            guard let display = displayController.currentDisplay else { return }
            showOSD(display)
        } else {
            displayController.activeDisplays.values.forEach(showOSD)
        }
    }

    func handleSingleDisplay(
        withLidClosed lidClosed: Bool,
        mediaKey: MediaKey,
        modifiers flags: NSEvent.ModifierFlags,
        event: CGEvent
    ) -> CGEvent? {
        switch flags {
        case [] where lidClosed:
            adjust(mediaKey, currentDisplay: true)
        case [.option, .shift] where lidClosed:
            adjust(mediaKey, by: 1, currentDisplay: true)

        case [], [.option, .shift]:
            return event

        case [.control]:
            adjust(mediaKey, currentDisplay: true)
        case [.control, .option]:
            adjust(mediaKey, by: 1, currentDisplay: true)

        case [.control, .shift]:
            adjust(mediaKey, currentDisplay: true, contrast: true)
        case [.control, .shift, .option]:
            adjust(mediaKey, by: 1, currentDisplay: true, contrast: true)

        default:
            return event
        }

        return nil
    }

    func handleMultipleDisplays(
        withLidClosed lidClosed: Bool,
        mediaKey: MediaKey,
        modifiers flags: NSEvent.ModifierFlags,
        event: CGEvent
    ) -> CGEvent? {
        let allMonitors = Defaults[.mediaKeysControlAllMonitors]

        switch flags {
        case [] where lidClosed:
            adjust(mediaKey, currentDisplay: !allMonitors)
        case [.option, .shift] where lidClosed:
            adjust(mediaKey, by: 1, currentDisplay: !allMonitors)

        case [] where displayController.adaptiveModeKey == .sync,
             [.option, .shift] where displayController.adaptiveModeKey == .sync:
            return event

        case [.control] where lidClosed:
            adjust(mediaKey, currentDisplay: true)
        case [.control, .option] where lidClosed:
            adjust(mediaKey, by: 1, currentDisplay: true)

        case [.control]:
            adjust(mediaKey, currentDisplay: !allMonitors)
        case [.control, .option]:
            adjust(mediaKey, by: 1, currentDisplay: !allMonitors)

        case [.control, .shift]:
            adjust(mediaKey, currentDisplay: !allMonitors, contrast: true)
        case [.control, .shift, .option]:
            adjust(mediaKey, by: 1, currentDisplay: !allMonitors, contrast: true)

        default:
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
            let lidClosed = IsLidClosed() || SyncMode.builtinDisplay == nil
            if displayController.activeDisplays.count == 1 {
                return handleSingleDisplay(withLidClosed: lidClosed, mediaKey: mediaKey, modifiers: flags, event: event)
            } else {
                return handleMultipleDisplays(withLidClosed: lidClosed, mediaKey: mediaKey, modifiers: flags, event: event)
            }
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
        cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        setLightPercent(percent: 0)
        log.debug("0% Hotkey pressed")
    }

    @objc func percent25HotkeyHandler() {
        cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        setLightPercent(percent: 25)
        log.debug("25% Hotkey pressed")
    }

    @objc func percent50HotkeyHandler() {
        cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        setLightPercent(percent: 50)
        log.debug("50% Hotkey pressed")
    }

    @objc func percent75HotkeyHandler() {
        cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        setLightPercent(percent: 75)
        log.debug("75% Hotkey pressed")
    }

    @objc func percent100HotkeyHandler() {
        cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        setLightPercent(percent: 100)
        log.debug("100% Hotkey pressed")
    }

    @objc func faceLightHotkeyHandler() {
        guard lunarProActive else { return }
        cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        faceLight(self)
        log.debug("FaceLight Hotkey pressed")
    }

    func brightnessUpAction(offset: Int? = nil) {
        cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        increaseBrightness(by: offset)

        for (_, display) in displayController.activeDisplays {
            Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, display: display)
        }

        log.debug("Brightness Up Hotkey pressed")
    }

    func brightnessDownAction(offset: Int? = nil) {
        cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        decreaseBrightness(by: offset)

        for (_, display) in displayController.activeDisplays {
            Hotkey.showOsd(osdImage: .brightness, value: display.brightness.uint32Value, display: display)
        }

        log.debug("Brightness Down Hotkey pressed")
    }

    func contrastUpAction(offset: Int? = nil) {
        cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        increaseContrast(by: offset)

        for (_, display) in displayController.activeDisplays {
            Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, display: display)
        }

        log.debug("Contrast Up Hotkey pressed")
    }

    func contrastDownAction(offset: Int? = nil) {
        cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
        decreaseContrast(by: offset)

        for (_, display) in displayController.activeDisplays {
            Hotkey.showOsd(osdImage: .contrast, value: display.contrast.uint32Value, display: display)
        }

        log.debug("Contrast Down Hotkey pressed")
    }

    func volumeUpAction(offset: Int? = nil) {
        increaseVolume(by: offset)
        if let display = displayController.currentDisplay, display.audioMuted {
            toggleAudioMuted()
        }

        if let display = displayController.currentDisplay {
            Hotkey.showOsd(osdImage: volumeOsdImage(display: display), value: display.volume.uint32Value, display: display)
        }

        log.debug("Volume Up Hotkey pressed")
    }

    func volumeDownAction(offset: Int? = nil) {
        decreaseVolume(by: offset)
        if let display = displayController.currentDisplay, display.audioMuted {
            toggleAudioMuted()
        }

        if let display = displayController.currentDisplay {
            Hotkey.showOsd(osdImage: volumeOsdImage(display: display), value: display.volume.uint32Value, display: display)
        }

        log.debug("Volume Down Hotkey pressed")
    }

    @objc func muteAudioHotkeyHandler() {
        toggleAudioMuted()

        if let display = displayController.currentDisplay {
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
}
