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

extension BrightnessSystemClient {
    static var shared = BrightnessSystemClient()

    func sunriseSunsetData() -> [String: Any]? {
        if let sunriseSunsetProperty = copyProperty(forKey: "BlueLightSunSchedule" as CFString),
           let sunriseSunsetDict = sunriseSunsetProperty as? [String: Any]
        {
            return sunriseSunsetDict
        }
        return nil
    }

    private func sunriseSunsetProperty(forKey key: String) -> Any? {
        if let data = sunriseSunsetData(),
           let property = data[key]
        {
            return property
        }
        return nil
    }

    var sunrise: Date? {
        sunriseSunsetProperty(forKey: "sunrise") as? Date
    }

    var sunset: Date? {
        sunriseSunsetProperty(forKey: "sunset") as? Date
    }

    var nextSunrise: Date? {
        sunriseSunsetProperty(forKey: "nextSunrise") as? Date
    }

    var nextSunset: Date? {
        sunriseSunsetProperty(forKey: "nextSunset") as? Date
    }

    var previousSunrise: Date? {
        sunriseSunsetProperty(forKey: "previousSunrise") as? Date
    }

    var previousSunset: Date? {
        sunriseSunsetProperty(forKey: "previousSunset") as? Date
    }

    var isDaylight: Bool? {
        sunriseSunsetProperty(forKey: "isDaylight") as? Bool
    }
}

// MARK: - Time + Equatable, Comparable

extension Time: Equatable, Comparable {
    public static func < (lhs: Time, rhs: Time) -> Bool {
        lhs.hour < rhs.hour || (lhs.hour == rhs.hour && lhs.minute < rhs.minute)
    }

    public static func == (lhs: Time, rhs: Time) -> Bool {
        lhs.hour == rhs.hour && lhs.minute == rhs.minute
    }

    init(_ date: Date) {
        self = Time(hour: date.hour.i32, minute: date.minute.i32)
    }
}

// MARK: - NightShiftScheduleType

enum NightShiftScheduleType: Equatable {
    case off
    case solar
    case custom(start: Time, end: Time)

    static func == (lhs: NightShiftScheduleType, rhs: NightShiftScheduleType) -> Bool {
        switch (lhs, rhs) {
        case (.off, .off), (.solar, .solar):
            true
        case (let .custom(leftStart, leftEnd), let custom(rightStart, rightEnd)):
            leftStart == rightStart && leftEnd == rightEnd
        default:
            false
        }
    }
}

// MARK: - NightShift

enum NightShift {
    static let client = CBBlueLightClient()

    static var darkMode: Bool {
        get { SLSGetAppearanceThemeLegacy() }
        set { SLSSetAppearanceThemeLegacy(newValue) }
    }

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

    static var schedule: NightShiftScheduleType {
        get {
            switch mode {
            case 0:
                return .off
            case 1:
                return .solar
            case 2:
                return .custom(start: status.schedule.fromTime, end: status.schedule.toTime)
            default:
                log.error("Unknown NightShift mode")
                return .off
            }
        }
        set {
            switch newValue {
            case .off:
                mode = 0
            case .solar:
                mode = 1
            case let .custom(start: start, end: end):
                mode = 2
                var schedule = CBSchedule(fromTime: start, toTime: end)
                client.setSchedule(&schedule)
            }
        }
    }

    static var scheduledState: Bool {
        switch schedule {
        case .off:
            return false
        case let .custom(start: startTime, end: endTime):
            let now = Time(Date())
            if endTime > startTime {
                // startTime and endTime are on the same day
                let scheduledState = now >= startTime && now < endTime
                return scheduledState
            } else {
                // endTime is on the day following startTime
                let scheduledState = now >= startTime || now < endTime
                return scheduledState
            }
        case .solar:
            guard let sunrise = BrightnessSystemClient.shared?.sunrise, let sunset = BrightnessSystemClient.shared?.sunrise
            else {
                return false
            }
            let now = Date()

            // For some reason, BrightnessSystemClient.isDaylight doesn't track perfectly with sunrise and sunset
            // Should return true when not daylight
            let scheduledState: Bool
            let order = NSCalendar.current.compare(sunrise, to: sunset, toGranularity: .day)
            switch order {
            case .orderedSame, .orderedAscending:
                scheduledState = now >= sunset || now <= sunrise
            case .orderedDescending:
                scheduledState = now >= sunset && now <= sunrise
            }
            return scheduledState
        }
    }

    static func enable(mode: Int32? = nil, strength: Float? = nil) {
        isEnabled = true

        if let mode {
            self.mode = mode
        }
        if let strength {
            self.strength = strength
        }

        if scheduledState {
            let savedSchedule = schedule
            schedule = .off
            schedule = savedSchedule
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

final class GammaControl: Control {
    init(display: Display) {
        self.display = display
    }

    @Atomic static var sliderTracking = false

    var displayControl: DisplayControl = .gamma

    weak var display: Display?
    let str = "Gamma Control"

    var isSoftware: Bool { true }
    var isDDC: Bool { false }

    static func fluxChecker(flux: NSRunningApplication) {
        let gammaDisplays = DC.activeDisplayList.filter {
            $0.hasSoftwareControl && $0.dimmingMode == .gamma && $0.gammaEnabled
        }
        guard let display = gammaDisplays.first else {
            DC.activeDisplayList.filter(\.applyGamma).forEach { $0.applyGamma = false }
            return
        }

        guard !CachedDefaults[.neverAskAboutFlux], !DC.screensSleeping, !DC.locked,
              fluxPromptTime == nil || timeSince(fluxPromptTime!) > 10.minutes.timeInterval
        else { return }

        fluxPromptTime = Date()

        let gammaNames = gammaDisplays.map(\.name).joined(separator: "\n- ")
        let gammaIDs = gammaDisplays.map(\.id)

        let completionHandler = { (keepFlux: NSApplication.ModalResponse) in
            let gammaDisplays = gammaIDs.compactMap { DC.activeDisplays[$0] }

            switch keepFlux {
            case .alertFirstButtonReturn:
                gammaDisplays.forEach { display in
                    display.useOverlay = true
                    display.gammaEnabled = true
                }
            case .alertSecondButtonReturn:
                flux.terminate()
                gammaDisplays.forEach { display in
                    display.gammaEnabled = true
                }

                if NightShift.isSupported {
                    NightShift.enable(mode: 1, strength: 1.0)
                }

                if let url = URL(string: "https://shifty.natethompson.io") {
                    NSWorkspace.shared.open(url)
                }

                if #available(macOS 13, *) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension?nightShiftSection") {
                        NSWorkspace.shared.open(url)
                    }
                } else {
                    guard let script = NSAppleScript(source: NIGHT_SHIFT_TAB_SCRIPT) else { return }
                    var errorInfo: NSDictionary?
                    script.executeAndReturnError(&errorInfo)
                    if let errors = errorInfo as? [String: Any], errors.count > 0 {
                        log.error("Error while executing Night Shift Tab script", context: errors)
                    }
                }
            case .alertThirdButtonReturn:
                return
            default:
                break
            }
        }

        let window = mainThread { appDelegate!.windowController?.window }

        gammaDisplays.forEach { display in
            display.gammaEnabled = false
        }

        let resp = askMultiButton(
            message: "Conflict between F.lux and Lunar detected",
            info: """
            **F.lux** adjusts the colour temperature of your screen using the same method used by Lunar for *Software Dimming*.

            The following displays don't support hardware brightness control and are forced to use *Software Dimming*:

            - \(gammaNames)

            ### Possible solutions:

            1. Set Lunar to dim brightness using a *dark overlay*
            2. Stop using f.lux, switch to `Night Shift` + `Shifty`
            3. Disable *Software Dimming* for affected displays

            **Note:** `Night Shift` can also get smarter schedules, app exclusion, keyboard temperature control and more using **[Shifty](https://shifty.natethompson.io)**
            """,
            okButton: "Dim using an overlay instead of Gamma",
            cancelButton: "Quit f.lux and switch to Night Shift",
            thirdButton: "Disable Software Dimming",
            screen: display.nsScreen ?? display.primaryMirrorScreen,
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

    static func fluxCheckerXDR(display: Display, fromAutoXDR: Bool = true, enableXDR: @escaping () -> Void) {
        guard !CachedDefaults[.neverAskAboutFlux], !DC.screensSleeping, !DC.locked,
              fluxPromptTime == nil || timeSince(fluxPromptTime!) > 10.minutes.timeInterval,
              DC.fluxRunning, let flux = fluxApp()
        else {
            enableXDR()
            return
        }

        guard !CachedDefaults[.disableNightShiftXDR] else {
            flux.terminate()
            enableXDR()
            return
        }

        fluxPromptTime = Date()

        let completionHandler = { (keepFlux: NSApplication.ModalResponse) in
            switch keepFlux {
            case .alertFirstButtonReturn:
                flux.terminate()
                enableXDR()
            case .alertSecondButtonReturn:
                DC.xdrPausedBecauseOfFlux = true
                DC.activeDisplayList
                    .filter(\.enhanced)
                    .forEach { $0.enhanced = false }
            case .alertThirdButtonReturn:
                Defaults[.autoXdr] = false
                Defaults[.autoXdrSensor] = false
                Defaults[.showXDRSelector] = false
            default:
                break
            }
        }

        let window = mainThread { appDelegate!.windowController?.window }

        let disableXDRMessage = !fromAutoXDR
            ? ""
            :
            "\n\nIf you wish to keep using f.lux, you can **Pause XDR** until f.lux is quit *(or until Lunar is relaunched)*.\n\nYou can also disable the XDR feature completely if you don't have a need for it (it can be reenabled later from the **Options** menu)."
        let resp = askMultiButton(
            message: "Conflict between F.lux and Lunar detected",
            info: """
            **F.lux** adjusts the colour temperature of your screen using the same method used by Lunar for **[XDR Brightness](https://lunar.fyi/#xdr)**.

            Because of a system limitation, XDR Brightness and f.lux can't coexist.\(disableXDRMessage)
            """,
            okButton: "Quit f.lux",
            cancelButton: fromAutoXDR ? "Pause XDR" : "Don't enable XDR",
            thirdButton: fromAutoXDR ? "Disable XDR" : nil,
            screen: display.nsScreen ?? display.primaryMirrorScreen,
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
        guard let display else { return false }
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

    func setBrightness(
        _ brightness: Brightness,
        oldValue: Brightness? = nil,
        force: Bool = false,
        transition: BrightnessTransition? = nil,
        onChange: ((Brightness) -> Void)? = nil
    ) -> Bool {
        guard let display else { return false }

        guard force || display.active, let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay else {
            return true
        }

        let brightness = cap(brightness, minVal: 0, maxVal: 100)

        guard display.supportsGamma else {
            display.shade(amount: 1.0 - (brightness.d / 100.0), force: force, transition: transition)
            return true
        }

        display.setGamma(brightness: brightness, force: force, transition: transition, onChange: onChange)
        onChange?(brightness)
        return true
    }

    func setContrast(
        _ contrast: Contrast,
        oldValue: Contrast? = nil,
        transition: BrightnessTransition? = nil,
        onChange: ((Contrast) -> Void)? = nil
    ) -> Bool {
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

    func setInput(_: VideoInputSource) -> Bool {
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

    func getInput() -> VideoInputSource? {
        nil
    }

    func reset() -> Bool {
        guard let display else { return false }

        display.resetSoftwareControl()
        return true
    }

    func supportsSmoothTransition(for control: ControlID) -> Bool {
        control == .BRIGHTNESS || control == .CONTRAST
    }
}
