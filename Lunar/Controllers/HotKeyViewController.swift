//
//  HotkeyViewController.swift
//  Lunar
//
//  Created by Alin on 24/02/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa
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
        if var hotkeys = datastore.hotkeys(), let identifier = HotkeyIdentifier(rawValue: hk.identifier) {
            hotkeys[identifier]?[.enabled] = sender.state.rawValue
            datastore.defaults.set(Hotkey.toNSDictionary(hotkeys), forKey: "hotkeys")
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

        // let isHotkeyCheckboxEnabled = { (hk: [HotkeyPart: Int]) in
        //     (hk[.enabled] ?? 1) == 1 && !KeyTransformer.cocoaFlags(from: hk[.modifiers] ?? 0).contains(.option)
        // }

        // let hotkeyCheckboxTooltip = { (hk: [HotkeyPart: Int]) -> String? in
        //     if KeyTransformer.cocoaFlags(from: hk[.modifiers] ?? 0).contains(.option) {
        //         return fineAdjustmentDisabledBecauseOfOptionKey
        //     } else {
        //         return nil
        //     }
        // }

        // let hotkeys = datastore.hotkeys() ?? Hotkey.defaults
        // if let hk = hotkeys[.preciseBrightnessUp], let coarseHk = hotkeys[.brightnessUp] {
        //     preciseBrightnessUpCheckbox.state = NSControl.StateValue(rawValue: hk[.enabled] ?? Hotkey.defaults[.preciseBrightnessUp]?[.enabled] ?? 0)
        //     preciseBrightnessUpCheckbox.isEnabled = isHotkeyCheckboxEnabled(coarseHk)
        //     preciseBrightnessUpCheckbox.toolTip = hotkeyCheckboxTooltip(coarseHk)
        // }
        // if let hk = hotkeys[.preciseBrightnessDown], let coarseHk = hotkeys[.brightnessDown] {
        //     preciseBrightnessDownCheckbox.state = NSControl.StateValue(rawValue: hk[.enabled] ?? Hotkey.defaults[.preciseBrightnessDown]?[.enabled] ?? 0)
        //     preciseBrightnessDownCheckbox.isEnabled = isHotkeyCheckboxEnabled(coarseHk)
        //     preciseBrightnessDownCheckbox.toolTip = hotkeyCheckboxTooltip(coarseHk)
        // }
        // if let hk = hotkeys[.preciseContrastUp], let coarseHk = hotkeys[.contrastUp] {
        //     preciseContrastUpCheckbox.state = NSControl.StateValue(rawValue: hk[.enabled] ?? Hotkey.defaults[.preciseContrastUp]?[.enabled] ?? 0)
        //     preciseContrastUpCheckbox.isEnabled = isHotkeyCheckboxEnabled(coarseHk)
        //     preciseContrastUpCheckbox.toolTip = hotkeyCheckboxTooltip(coarseHk)
        // }
        // if let hk = hotkeys[.preciseContrastDown], let coarseHk = hotkeys[.contrastDown] {
        //     preciseContrastDownCheckbox.state = NSControl.StateValue(rawValue: hk[.enabled] ?? Hotkey.defaults[.preciseContrastDown]?[.enabled] ?? 0)
        //     preciseContrastDownCheckbox.isEnabled = isHotkeyCheckboxEnabled(coarseHk)
        //     preciseContrastDownCheckbox.toolTip = hotkeyCheckboxTooltip(coarseHk)
        // }
        // if let hk = hotkeys[.preciseVolumeUp], let coarseHk = hotkeys[.volumeUp] {
        //     preciseVolumeUpCheckbox.state = NSControl.StateValue(rawValue: hk[.enabled] ?? Hotkey.defaults[.preciseVolumeUp]?[.enabled] ?? 0)
        //     preciseVolumeUpCheckbox.isEnabled = isHotkeyCheckboxEnabled(coarseHk)
        //     preciseVolumeUpCheckbox.toolTip = hotkeyCheckboxTooltip(coarseHk)
        // }
        // if let hk = hotkeys[.preciseVolumeDown], let coarseHk = hotkeys[.volumeDown] {
        //     preciseVolumeDownCheckbox.state = NSControl.StateValue(rawValue: hk[.enabled] ?? Hotkey.defaults[.preciseVolumeDown]?[.enabled] ?? 0)
        //     preciseVolumeDownCheckbox.isEnabled = isHotkeyCheckboxEnabled(coarseHk)
        //     preciseVolumeDownCheckbox.toolTip = hotkeyCheckboxTooltip(coarseHk)
        // }
    }

    override func mouseDown(with event: NSEvent) {
        view.window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }
}
