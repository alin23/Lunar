//
//  HotkeyViewController.swift
//  Lunar
//
//  Created by Alin on 24/02/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa
import Defaults
import Down
import Magnet

class HotkeyViewController: NSViewController {
    @IBOutlet var toggleHotkeyView: HotkeyView!
    @IBOutlet var lunarHotkeyView: HotkeyView!
    @IBOutlet var percent0HotkeyView: HotkeyView!
    @IBOutlet var percent25HotkeyView: HotkeyView!
    @IBOutlet var percent50HotkeyView: HotkeyView!
    @IBOutlet var percent75HotkeyView: HotkeyView!
    @IBOutlet var percent100HotkeyView: HotkeyView!
    @IBOutlet var brightnessUpHotkeyView: HotkeyView!
    @IBOutlet var brightnessDownHotkeyView: HotkeyView!
    @IBOutlet var contrastUpHotkeyView: HotkeyView!
    @IBOutlet var contrastDownHotkeyView: HotkeyView!
    @IBOutlet var volumeDownHotkeyView: HotkeyView!
    @IBOutlet var volumeUpHotkeyView: HotkeyView!
    @IBOutlet var muteAudioHotkeyView: HotkeyView!
    @IBOutlet var faceLightHotkeyView: HotkeyView!

    @IBOutlet var preciseBrightnessUpCheckbox: NSButton!
    @IBOutlet var preciseBrightnessDownCheckbox: NSButton!
    @IBOutlet var preciseContrastUpCheckbox: NSButton!
    @IBOutlet var preciseContrastDownCheckbox: NSButton!
    @IBOutlet var preciseVolumeUpCheckbox: NSButton!
    @IBOutlet var preciseVolumeDownCheckbox: NSButton!

    @IBOutlet var hotkeysInfoButton: ResetButton!
    @IBOutlet var resetButton: ResetButton!
    @IBOutlet var fnKeysNotice: NSTextField!

    var cachedFnState = false

    @IBAction func resetHotkeys(_: Any) {
        Defaults.reset(.hotkeys)
        setHotkeys()
    }

    @IBAction func toggleFineAdjustments(_ sender: NSButton) {
        var hotkey: PersistentHotkey??

        switch sender.tag {
        case 1:
            hotkey = Hotkey.keys[HotkeyIdentifier.preciseBrightnessDown.rawValue]
        case 2:
            hotkey = Hotkey.keys[HotkeyIdentifier.preciseBrightnessUp.rawValue]
        case 3:
            hotkey = Hotkey.keys[HotkeyIdentifier.preciseContrastDown.rawValue]
        case 4:
            hotkey = Hotkey.keys[HotkeyIdentifier.preciseContrastUp.rawValue]
        case 5:
            hotkey = Hotkey.keys[HotkeyIdentifier.preciseVolumeDown.rawValue]
        case 6:
            hotkey = Hotkey.keys[HotkeyIdentifier.preciseVolumeUp.rawValue]
        default:
            log.warning("Unknown tag: \(sender.tag)")
        }

        guard let hkTemp = hotkey, let hk = hkTemp else { return }

        if sender.state == .on {
            hk.register()
        } else {
            hk.unregister()
        }

        var hotkeys = Defaults[.hotkeys]
        hotkeys[hk.identifier]?[.enabled] = sender.state.rawValue
        Defaults[.hotkeys] = hotkeys
    }

    func setHotkeys() {
        toggleHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.toggle.rawValue] ?? nil
        lunarHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.lunar.rawValue] ?? nil
        percent0HotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.percent0.rawValue] ?? nil
        percent25HotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.percent25.rawValue] ?? nil
        percent50HotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.percent50.rawValue] ?? nil
        percent75HotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.percent75.rawValue] ?? nil
        percent100HotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.percent100.rawValue] ?? nil
        faceLightHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.faceLight.rawValue] ?? nil

        brightnessUpHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.brightnessUp.rawValue] ?? nil
        brightnessDownHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.brightnessDown.rawValue] ?? nil
        contrastUpHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.contrastUp.rawValue] ?? nil
        contrastDownHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.contrastDown.rawValue] ?? nil
        volumeUpHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.volumeUp.rawValue] ?? nil
        volumeDownHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.volumeDown.rawValue] ?? nil

        brightnessUpHotkeyView.preciseHotkeyCheckbox = preciseBrightnessUpCheckbox
        brightnessDownHotkeyView.preciseHotkeyCheckbox = preciseBrightnessDownCheckbox
        contrastUpHotkeyView.preciseHotkeyCheckbox = preciseContrastUpCheckbox
        contrastDownHotkeyView.preciseHotkeyCheckbox = preciseContrastDownCheckbox
        volumeUpHotkeyView.preciseHotkeyCheckbox = preciseVolumeUpCheckbox
        volumeDownHotkeyView.preciseHotkeyCheckbox = preciseVolumeDownCheckbox

        muteAudioHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.muteAudio.rawValue] ?? nil
    }

    func setupFKeysNotice(asFunctionKeys: Bool? = nil) {
        let notice: String
        if asFunctionKeys ?? Defaults[.fKeysAsFunctionKeys] {
            notice = """
            Your F keys are configured as **function keys**.
            You have to **hold `Fn`** while pressing:
            * `F1`/`F2` for Brightness
            * `Ctrl+F1`/`Ctrl+F2` for Contrast
            * `F10`/`F11`/`F12` for Volume/Mute
            """
        } else {
            notice = """
            Your F keys are configured as **media keys**.

            You have to **hold `Fn`** to be able to activate any of the hotkeys containing keys like `F1,` `F2,` `F10` etc.
            """
        }
        let down = Down(markdownString: notice)
        fnKeysNotice.attributedStringValue = (try? down.toAttributedString(.smart, stylesheet: DARK_STYLESHEET)) ?? notice.attributedString
        fnKeysNotice.isEnabled = false
    }

    var fkeysSettingWatcher: Timer?

    @IBAction func howDoHotkeysWork(_: Any) {
        NSWorkspace.shared.open(try! "https://lunar.fyi/faq#hotkeys".asURL())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.bg = hotkeysBgColor

        resetButton.page = .hotkeysReset
        hotkeysInfoButton.page = .hotkeys

        setHotkeys()
        setupFKeysNotice()
    }

    override func viewDidAppear() {
        let handler = { [weak self] in
            guard let self = self, self.cachedFnState != Defaults[.fKeysAsFunctionKeys] else { return }
            self.cachedFnState = Defaults[.fKeysAsFunctionKeys]
            self.setupFKeysNotice(asFunctionKeys: self.cachedFnState)
        }
        handler()
        fkeysSettingWatcher = asyncEvery(5.seconds, handler)
    }

    deinit {
        log.verbose("")
        fkeysSettingWatcher?.invalidate()
        fkeysSettingWatcher = nil
    }

    override func viewDidDisappear() {
        fkeysSettingWatcher?.invalidate()
        fkeysSettingWatcher = nil
    }

    override func mouseDown(with event: NSEvent) {
        view.window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }
}
