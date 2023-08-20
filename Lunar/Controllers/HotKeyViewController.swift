//
//  HotKeyViewController.swift
//  Lunar
//
//  Created by Alin on 24/02/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa
import Defaults
import Magnet

final class HotkeyViewController: NSViewController {
    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            do { log.verbose("END DEINIT") }
        #endif
    }

    @IBOutlet var toggleHotkeyView: HotkeyView?
    @IBOutlet var lunarHotkeyView: HotkeyView?
    @IBOutlet var restartHotkeyView: HotkeyView?
    @IBOutlet var percent0HotkeyView: HotkeyView?
    @IBOutlet var percent25HotkeyView: HotkeyView?
    @IBOutlet var percent50HotkeyView: HotkeyView?
    @IBOutlet var percent75HotkeyView: HotkeyView?
    @IBOutlet var percent100HotkeyView: HotkeyView?
    @IBOutlet var brightnessUpHotkeyView: HotkeyView?
    @IBOutlet var brightnessDownHotkeyView: HotkeyView?
    @IBOutlet var contrastUpHotkeyView: HotkeyView?
    @IBOutlet var contrastDownHotkeyView: HotkeyView?
    @IBOutlet var volumeDownHotkeyView: HotkeyView?
    @IBOutlet var volumeUpHotkeyView: HotkeyView?
    @IBOutlet var muteAudioHotkeyView: HotkeyView?
    @IBOutlet var faceLightHotkeyView: HotkeyView?
    @IBOutlet var blackOutHotkeyView: HotkeyView?

    @IBOutlet var resetButton: ResetButton?
    @IBOutlet var disableButton: ResetButton?

    @IBOutlet var brightnessKeysControlButton: PopUpButton?
    @IBOutlet var brightnessKeysSyncControlButton: PopUpButton?
    @IBOutlet var ctrlBrightnessKeysControlButton: PopUpButton?
    @IBOutlet var ctrlBrightnessKeysSyncControlButton: PopUpButton?
    @IBOutlet var shiftBrightnessKeysControlButton: PopUpButton?
    @IBOutlet var shiftBrightnessKeysSyncControlButton: PopUpButton?

    @IBAction func resetHotkeys(_: Any) {
        HotKeyCenter.shared.unregisterAll()
        CachedDefaults.reset(.hotkeys)
        CachedDefaults.reset(.hotkeysAffectBuiltin)
        CachedDefaults.reset(.brightnessKeysEnabled)
        CachedDefaults.reset(.volumeKeysEnabled)
        CachedDefaults.reset(.useAlternateBrightnessKeys)
        CachedDefaults.reset(.brightnessHotkeysControlAllMonitors)
        CachedDefaults.reset(.contrastHotkeysControlAllMonitors)
        CachedDefaults.reset(.volumeHotkeysControlAllMonitors)

        CachedDefaults.reset(.brightnessKeysSyncControl)
        CachedDefaults.reset(.brightnessKeysControl)
        CachedDefaults.reset(.ctrlBrightnessKeysSyncControl)
        CachedDefaults.reset(.ctrlBrightnessKeysControl)
        CachedDefaults.reset(.shiftBrightnessKeysSyncControl)
        CachedDefaults.reset(.shiftBrightnessKeysControl)

        mainAsyncAfter(ms: 100) { [weak self] in
            CachedDefaults[.hotkeys].forEach {
                $0.unregister()
                if $0.isEnabled { $0.register() }
            }
            self?.setHotkeys()
            appDelegate!.setKeyEquivalents(CachedDefaults[.hotkeys])
        }
    }

    func setHotkeys() {
        let hotkeys = CachedDefaults[.hotkeys]

        toggleHotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.toggle.rawValue }
        lunarHotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.lunar.rawValue }
        restartHotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.restart.rawValue }
        percent0HotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.percent0.rawValue }
        percent25HotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.percent25.rawValue }
        percent50HotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.percent50.rawValue }
        percent75HotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.percent75.rawValue }
        percent100HotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.percent100.rawValue }
        faceLightHotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.faceLight.rawValue }
        blackOutHotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.blackOut.rawValue }

        brightnessUpHotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.brightnessUp.rawValue }
        brightnessDownHotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.brightnessDown.rawValue }
        contrastUpHotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.contrastUp.rawValue }
        contrastDownHotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.contrastDown.rawValue }
        volumeUpHotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.volumeUp.rawValue }
        volumeDownHotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.volumeDown.rawValue }

        muteAudioHotkeyView?.hotkey = hotkeys.first { $0.identifier == HotkeyIdentifier.muteAudio.rawValue }
    }

    @IBAction func disableAll(_ sender: Any) {
        CachedDefaults[.hotkeys] = Set(CachedDefaults[.hotkeys].map { hotkey in
            guard HotkeyIdentifier(rawValue: hotkey.identifier) != nil else {
                return hotkey
            }

            return hotkey.disabled()
        })

        mainAsyncAfter(ms: 100) { [weak self] in
            CachedDefaults[.hotkeys].forEach {
                $0.unregister()
                if $0.isEnabled { $0.register() }
            }
            self?.setHotkeys()
            appDelegate!.setKeyEquivalents(CachedDefaults[.hotkeys])
        }
    }

    @IBAction func howDoHotkeysWork(_: Any) {
        NSWorkspace.shared.open("https://lunar.fyi/faq#hotkeys".asURL()!)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.bg = hotkeysBgColor

        resetButton?.page = .hotkeysReset
        disableButton?.page = .hotkeysReset
        disableButton?.resettingText = "Disabling"

        setHotkeys()

        brightnessKeysControlButton?.page = .hotkeys
        brightnessKeysControlButton?.origin = .left
        brightnessKeysControlButton?.fade()

        ctrlBrightnessKeysControlButton?.page = .hotkeys
        ctrlBrightnessKeysControlButton?.origin = .left
        ctrlBrightnessKeysControlButton?.fade()

        shiftBrightnessKeysControlButton?.page = .hotkeys
        shiftBrightnessKeysControlButton?.origin = .left
        shiftBrightnessKeysControlButton?.fade()

        brightnessKeysSyncControlButton?.page = .hotkeys
        brightnessKeysSyncControlButton?.origin = .left
        brightnessKeysSyncControlButton?.fade()

        ctrlBrightnessKeysSyncControlButton?.page = .hotkeys
        ctrlBrightnessKeysSyncControlButton?.origin = .left
        ctrlBrightnessKeysSyncControlButton?.fade()

        shiftBrightnessKeysSyncControlButton?.page = .hotkeys
        shiftBrightnessKeysSyncControlButton?.origin = .left
        shiftBrightnessKeysSyncControlButton?.fade()
    }

    override func mouseDown(with event: NSEvent) {
        view.window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }
}
