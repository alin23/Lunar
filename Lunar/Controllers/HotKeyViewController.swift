//
//  HotkeyViewController.swift
//  Lunar
//
//  Created by Alin on 24/02/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa
import Defaults
import Magnet

class HotkeyViewController: NSViewController {
    @IBOutlet var toggleHotkeyView: HotkeyView!
    @IBOutlet var startHotkeyView: HotkeyView!
    @IBOutlet var pauseHotkeyView: HotkeyView!
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

    @IBOutlet var preciseBrightnessUpCheckbox: NSButton!
    @IBOutlet var preciseBrightnessDownCheckbox: NSButton!
    @IBOutlet var preciseContrastUpCheckbox: NSButton!
    @IBOutlet var preciseContrastDownCheckbox: NSButton!
    @IBOutlet var preciseVolumeUpCheckbox: NSButton!
    @IBOutlet var preciseVolumeDownCheckbox: NSButton!

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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = hotkeysBgColor.cgColor
        toggleHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.toggle.rawValue] ?? nil
        startHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.start.rawValue] ?? nil
        pauseHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.pause.rawValue] ?? nil
        lunarHotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.lunar.rawValue] ?? nil
        percent0HotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.percent0.rawValue] ?? nil
        percent25HotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.percent25.rawValue] ?? nil
        percent50HotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.percent50.rawValue] ?? nil
        percent75HotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.percent75.rawValue] ?? nil
        percent100HotkeyView.hotkey = Hotkey.keys[HotkeyIdentifier.percent100.rawValue] ?? nil

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

    override func mouseDown(with event: NSEvent) {
        view.window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }
}
