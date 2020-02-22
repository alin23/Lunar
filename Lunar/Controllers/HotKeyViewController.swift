//
//  HotkeyViewController.swift
//  Lunar
//
//  Created by Alin on 24/02/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa

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
    }

    override func mouseDown(with event: NSEvent) {
        view.window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }
}
