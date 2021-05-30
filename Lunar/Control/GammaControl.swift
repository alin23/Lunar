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

let FLUX_IDENTIFIER = "org.herf.Flux"

let NIGHT_SHIFT_TAB_SCRIPT =
    """
    tell application "System Preferences"
        set the current pane to pane id "com.apple.preference.displays"
        reveal anchor "displaysNightShiftTab" of pane id "com.apple.preference.displays"
        activate
    end tell
    """

struct GammaControl: Control {
    var displayControl: DisplayControl = .gamma

    weak var display: Display!
    let str = "Gamma Control"

    func fluxChecker(flux: NSRunningApplication) {
        guard !Defaults[.neverAskAboutFlux] else { return }

        let completionHandler = { (quitFlux: Bool) in
            if quitFlux {
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
        }

        let window = mainThread { appDelegate().windowController?.window }

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
            screen: display.screen,
            window: window,
            suppressionText: "Never ask again",
            onSuppression: { shouldStopAsking in
                Defaults[.neverAskAboutFlux] = shouldStopAsking
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
        guard let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay else {
            return display.enabledControls.values.allSatisfy { enabled in !enabled }
        }
        return true
    }

    func isResponsive() -> Bool {
        true
    }

    func resetState() {}

    func setBrightness(_ brightness: Brightness, oldValue: Brightness? = nil) -> Bool {
        guard let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay else {
            return false
        }

        // if Defaults[.smoothTransition], supportsSmoothTransition(for: .BRIGHTNESS), let oldValue = oldValue {
        if let oldValue = oldValue {
            display.setGamma(brightness: brightness, oldBrightness: oldValue)
            return true
        }

        display.setGamma(brightness: brightness)
        return true
    }

    func setContrast(_ contrast: Contrast, oldValue: Contrast? = nil) -> Bool {
        guard let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay else {
            return false
        }

        // if Defaults[.smoothTransition], supportsSmoothTransition(for: .CONTRAST), let oldValue = oldValue {
        if let oldValue = oldValue {
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
        CGDisplayRestoreColorSyncSettings()
        display.resetGamma()
        return true
    }

    func supportsSmoothTransition(for control: ControlID) -> Bool {
        control == .BRIGHTNESS || control == .CONTRAST
    }
}
