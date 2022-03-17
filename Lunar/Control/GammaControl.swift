//
//  GammaControl.swift
//  Lunar
//
//  Created by Alin Panaitiu on 18.02.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Defaults
import Foundation
import SwiftDate

let FLUX_IDENTIFIER = "org.herf.Flux"

let NIGHT_SHIFT_TAB_SCRIPT =
    """
    tell application "System Preferences"
        set the current pane to pane id "com.apple.preference.displays"
        reveal anchor "displaysNightShiftTab" of pane id "com.apple.preference.displays"
        activate
    end tell

    tell application "System Events" to tell process "System Preferences"
        click button "Night Shift…" of window 1
    end tell
    """

var fluxPromptTime: Date?

// MARK: - NightShift

enum NightShift {
    static let client = CBBlueLightClient()

    static var strength: Float {
        get {
            var strength: Float = 0
            client.getStrength(&strength)
            return strength
        }

        set {
            client.setStrength(newValue, commit: true)
        }
    }

    static var mode: Int32 {
        get { status.mode }
        set { client.setMode(newValue) }
    }

    static var isEnabled: Bool {
        get { status.enabled.boolValue }
        set { client.setEnabled(newValue) }
    }

    static var isSupported: Bool { CBBlueLightClient.supportsBlueLightReduction() }

    static var status: Status {
        var status = Status()
        client.getBlueLightStatus(&status)
        return status
    }

    static func enable(mode: Int32? = nil, strength: Float? = nil) {
        isEnabled = true
        if let mode = mode {
            self.mode = mode
        }
        if let strength = strength {
            self.strength = strength
        }
    }

    static func disable() {
        isEnabled = false
    }

    static func previewStrength(_ value: Float) {
        if !isEnabled { isEnabled = true }

        client.setStrength(value, commit: false)
    }
}

// MARK: - GammaControl

class GammaControl: Control {
    // MARK: Lifecycle

    init(display: Display) {
        self.display = display
    }

    // MARK: Internal

    @Atomic static var sliderTracking = false

    var displayControl: DisplayControl = .gamma

    weak var display: Display?
    let str = "Gamma Control"

    var isSoftware: Bool { true }

    func fluxChecker(flux: NSRunningApplication) {
        guard let display = display, display.supportsGamma else { return }
        guard !CachedDefaults[.neverAskAboutFlux], !screensSleeping.load(ordering: .relaxed),
              fluxPromptTime == nil || timeSince(fluxPromptTime!) > 10.minutes.timeInterval
        else { return }

        fluxPromptTime = Date()
        let displayID = display.id

        let completionHandler = { (keepFlux: Bool) in
            guard !keepFlux else {
                if let display = displayController.activeDisplays[displayID] {
                    display.useOverlay = true
                }
                return
            }

            if let display = displayController.activeDisplays[displayID] {
                display.useOverlay = false
            }
            flux.terminate()
            if NightShift.isSupported {
                NightShift.enable(mode: 1, strength: 0.5)
            }

            if let url = URL(string: "https://shifty.natethompson.io") {
                NSWorkspace.shared.open(url)
            }

            guard let script = NSAppleScript(source: NIGHT_SHIFT_TAB_SCRIPT) else { return }
            var errorInfo: NSDictionary?
            script.executeAndReturnError(&errorInfo)
            if let errors = errorInfo as? [String: Any], errors.count > 0 {
                log.error("Error while executing Night Shift Tab script", context: errors)
            }
        }

        let window = mainThread { appDelegate!.windowController?.window }

        display.useOverlay = true
        let resp = ask(
            message: "Conflict between F.lux and Lunar detected",
            info: """
            **F.lux** adjusts the colour temperature of your screen using the same method used by Lunar for *Software Dimming*.

            ### Possible fixes:

            1. Set Lunar to dim brightness using a dark overlay
            2. Stop using f.lux, switch to `Night Shift` + `Shifty`

            **Note:** `Night Shift` can also get smarter schedules, app exclusion, keyboard temperature control and more using **[Shifty](https://shifty.natethompson.io)**
            """,
            okButton: "Use dark overlay",
            cancelButton: "Quit f.lux and switch to Night Shift",
            screen: display.screen ?? display.primaryMirrorScreen,
            window: window,
            suppressionText: "Never ask again",
            onSuppression: { shouldStopAsking in
                CachedDefaults[.neverAskAboutFlux] = shouldStopAsking
            },
            onCompletion: completionHandler,
            unique: true,
            waitTimeout: 60.seconds,
            wide: true,
            markdown: true
        )
        if window == nil {
            completionHandler(resp)
        }
    }

    func isAvailable() -> Bool {
        guard let display = display else { return false }
        guard display.active else { return false }
        guard let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay else {
            return display.enabledControls.values.allSatisfy { enabled in !enabled }
        }
        return true
    }

    func isResponsive() -> Bool {
        true
    }

    func resetState() {}

    func setRedGain(_ gain: UInt16) -> Bool { true }
    func setGreenGain(_ gain: UInt16) -> Bool { true }
    func setBlueGain(_ gain: UInt16) -> Bool { true }
    func getRedGain() -> UInt16? { nil }
    func getGreenGain() -> UInt16? { nil }
    func getBlueGain() -> UInt16? { nil }
    func resetColors() -> Bool { true }

    func setBrightness(_ brightness: Brightness, oldValue: Brightness? = nil, onChange: ((Brightness) -> Void)? = nil) -> Bool {
        guard let display = display else { return false }

        guard display.active, let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay else {
            return false
        }

        let brightness = cap(brightness, minVal: 0, maxVal: 100)

        guard display.supportsGamma else {
            display.shade(amount: 1.0 - (brightness.d / 100.0))
            return true
        }

        if let oldValue = oldValue, oldValue != brightness {
            display.setGamma(brightness: brightness, oldBrightness: oldValue, onChange: onChange)
            return true
        }

        display.setGamma(brightness: brightness)
        onChange?(brightness)
        return true
    }

    func setContrast(_ contrast: Contrast, oldValue: Contrast? = nil, onChange: ((Contrast) -> Void)? = nil) -> Bool {
        true
    }

    func setPower(_: PowerState) -> Bool {
        false
    }

    func setVolume(_: UInt16) -> Bool {
        false
    }

    func setMute(_: Bool) -> Bool {
        false
    }

    func setInput(_: InputSource) -> Bool {
        false
    }

    func getBrightness() -> Brightness? {
        nil
    }

    func getContrast() -> Contrast? {
        nil
    }

    func getMaxBrightness() -> Brightness? {
        MAX_BRIGHTNESS
    }

    func getMaxContrast() -> Contrast? {
        MAX_CONTRAST
    }

    func getMaxVolume() -> UInt16? {
        nil
    }

    func getVolume() -> UInt16? {
        nil
    }

    func getMute() -> Bool? {
        nil
    }

    func getInput() -> InputSource? {
        nil
    }

    func reset() -> Bool {
        guard let display = display else { return false }

        display.resetSoftwareControl()
        return true
    }

    func supportsSmoothTransition(for control: ControlID) -> Bool {
        control == .BRIGHTNESS || control == .CONTRAST
    }
}
