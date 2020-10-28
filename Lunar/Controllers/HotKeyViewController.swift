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
        var hotkey: Magnet.HotKey??

        switch sender.tag {
        case 1:
            hotkey = Hotkey.keys[.preciseBrightnessDown]
        case 2:
            hotkey = Hotkey.keys[.preciseBrightnessUp]
        case 3:
            hotkey = Hotkey.keys[.preciseContrastDown]
        case 4:
            hotkey = Hotkey.keys[.preciseContrastUp]
        case 5:
            hotkey = Hotkey.keys[.preciseVolumeDown]
        case 6:
            hotkey = Hotkey.keys[.preciseVolumeUp]
        default:
            log.warning("Unknown tag: \(sender.tag)")
        }

        guard let hkTemp = hotkey, let hk = hkTemp else { return }

        if sender.state == .on {
            hk.register()
        } else {
            hk.unregister()
        }
        if let identifier = HotkeyIdentifier(rawValue: hk.identifier) {
            var hotkeys = Defaults[.hotkeys]
            hotkeys[identifier]?[.enabled] = sender.state.rawValue
            Defaults[.hotkeys] = hotkeys
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = hotkeysBgColor.cgColor
        toggleHotkeyView.hotkey = Hotkey.keys[.toggle] ?? nil
        startHotkeyView.hotkey = Hotkey.keys[.start] ?? nil
        pauseHotkeyView.hotkey = Hotkey.keys[.pause] ?? nil
        lunarHotkeyView.hotkey = Hotkey.keys[.lunar] ?? nil
        percent0HotkeyView.hotkey = Hotkey.keys[.percent0] ?? nil
        percent25HotkeyView.hotkey = Hotkey.keys[.percent25] ?? nil
        percent50HotkeyView.hotkey = Hotkey.keys[.percent50] ?? nil
        percent75HotkeyView.hotkey = Hotkey.keys[.percent75] ?? nil
        percent100HotkeyView.hotkey = Hotkey.keys[.percent100] ?? nil

        brightnessUpHotkeyView.hotkey = Hotkey.keys[.brightnessUp] ?? nil
        brightnessDownHotkeyView.hotkey = Hotkey.keys[.brightnessDown] ?? nil
        contrastUpHotkeyView.hotkey = Hotkey.keys[.contrastUp] ?? nil
        contrastDownHotkeyView.hotkey = Hotkey.keys[.contrastDown] ?? nil
        volumeUpHotkeyView.hotkey = Hotkey.keys[.volumeUp] ?? nil
        volumeDownHotkeyView.hotkey = Hotkey.keys[.volumeDown] ?? nil

        brightnessUpHotkeyView.preciseHotkeyCheckbox = preciseBrightnessUpCheckbox
        brightnessDownHotkeyView.preciseHotkeyCheckbox = preciseBrightnessDownCheckbox
        contrastUpHotkeyView.preciseHotkeyCheckbox = preciseContrastUpCheckbox
        contrastDownHotkeyView.preciseHotkeyCheckbox = preciseContrastDownCheckbox
        volumeUpHotkeyView.preciseHotkeyCheckbox = preciseVolumeUpCheckbox
        volumeDownHotkeyView.preciseHotkeyCheckbox = preciseVolumeDownCheckbox

        muteAudioHotkeyView.hotkey = Hotkey.keys[.muteAudio] ?? nil
    }

    override func mouseDown(with event: NSEvent) {
        view.window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }
}
