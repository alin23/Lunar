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
    """

var fluxPromptTime: Date?

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

    func fluxChecker(flux: NSRunningApplication) {
        guard let display = display, display.supportsGamma else { return }
        guard !CachedDefaults[.neverAskAboutFlux], !screensSleeping.load(ordering: .relaxed),
              fluxPromptTime == nil || timeSince(fluxPromptTime!) > 10.minutes.timeInterval
        else { return }

        fluxPromptTime = Date()

        let completionHandler = { [weak self] (keepFlux: Bool) in
            guard !keepFlux else {
                self?.display?.useOverlay = true
                return
            }

            flux.terminate()
            if CBBlueLightClient.supportsBlueLightReduction() {
                let client = CBBlueLightClient()
                client.setMode(1)
                client.setStrength(0.5, commit: true)
            }

            guard let script = NSAppleScript(source: NIGHT_SHIFT_TAB_SCRIPT) else { return }
            var errorInfo: NSDictionary?
            script.executeAndReturnError(&errorInfo)
            if let errors = errorInfo as? [String: Any], errors.count > 0 {
                log.error("Error while executing Night Shift Tab script", context: errors)
            }
        }

        let window = mainThread { appDelegate!.windowController?.window }

        let resp = ask(
            message: "F.lux app is conflicting with Lunar",
            info: """
                This display is controlled using gamma tables

                F.lux uses the same method to adjust the colour temperature of your screen.

                Unfortunately, only one app is allowed to change the gamma tables.

                For Lunar to work properly, you can either:

                1. Switch to a dark overlay for brightness dimming
                2. Or stop using f.lux and switch to Night Shift
            """,
            okButton: "Use dark overlay",
            cancelButton: "Quit f.lux",
            screen: display.screen ?? display.primaryMirrorScreen,
            window: window,
            suppressionText: "Never ask again",
            onSuppression: { shouldStopAsking in
                CachedDefaults[.neverAskAboutFlux] = shouldStopAsking
            },
            onCompletion: completionHandler,
            unique: true,
            waitTimeout: 60.seconds,
            wide: true
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

    func setRedGain(_ gain: UInt8) -> Bool { true }
    func setGreenGain(_ gain: UInt8) -> Bool { true }
    func setBlueGain(_ gain: UInt8) -> Bool { true }
    func getRedGain() -> UInt8? { nil }
    func getGreenGain() -> UInt8? { nil }
    func getBlueGain() -> UInt8? { nil }
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

        // if CachedDefaults[.smoothTransition], supportsSmoothTransition(for: .BRIGHTNESS), let oldValue = oldValue {
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
        // guard let display = display else { return false }

        // guard display.active, let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay else {
        //     return false
        // }

        // let contrast = cap(contrast, minVal: 0, maxVal: 100)

        // guard display.supportsGamma else {
        //     return true
        // }

        // // if CachedDefaults[.smoothTransition], supportsSmoothTransition(for: .CONTRAST), let oldValue = oldValue {
        // if let oldValue = oldValue, oldValue != contrast {
        //     display.setGamma(contrast: contrast, oldContrast: oldValue, onChange: onChange)
        //     return true
        // }

        // display.setGamma(contrast: contrast)
        // onChange?(contrast)
        // return true
    }

    func setPower(_: PowerState) -> Bool {
        false
    }

    func setVolume(_: UInt8) -> Bool {
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

    func getMaxVolume() -> UInt8? {
        nil
    }

    func getVolume() -> UInt8? {
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
