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

    var displayControl: DisplayControl = .gamma

    weak var display: Display?
    let str = "Gamma Control"

    func fluxChecker(flux: NSRunningApplication) {
        guard let display = display else { return }
        guard !CachedDefaults[.neverAskAboutFlux], !screensSleeping.load(ordering: .relaxed),
              fluxPromptTime == nil || timeSince(fluxPromptTime!) > 10.minutes.timeInterval
        else { return }

        fluxPromptTime = Date()

        let completionHandler = { (quitFlux: Bool) in
            guard quitFlux else { return }

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
                This display is controlled using gamma tables, the same method that f.lux uses to adjust the colour temperature of your screen.

                Unfortunately, only one app is allowed to change the gamma tables.

                For Lunar to work properly, you have to stop using f.lux.

                \(CBBlueLightClient.supportsBlueLightReduction()
                ?
                "You can switch to macOS Night Shift for a blue light filter that doesn't interfere with Lunar.\n\nDo you want to quit f.lux and activate Night Shift now?"
                : "Do you want to quit f.lux now?")
            """,
            okButton: "Yes",
            cancelButton: "No",
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

    func setBrightness(_ brightness: Brightness, oldValue: Brightness? = nil) -> Bool {
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
            display.setGamma(brightness: brightness, oldBrightness: oldValue)
            return true
        }

        display.setGamma(brightness: brightness)
        return true
    }

    func setContrast(_ contrast: Contrast, oldValue: Contrast? = nil) -> Bool {
        guard let display = display else { return false }

        guard display.active, let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay else {
            return false
        }

        let contrast = cap(contrast, minVal: 0, maxVal: 100)

        guard display.supportsGamma else {
            return true
        }

        // if CachedDefaults[.smoothTransition], supportsSmoothTransition(for: .CONTRAST), let oldValue = oldValue {
        if let oldValue = oldValue, oldValue != contrast {
            display.setGamma(contrast: contrast, oldContrast: oldValue)
            return true
        }

        display.setGamma(contrast: contrast)
        return true
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
