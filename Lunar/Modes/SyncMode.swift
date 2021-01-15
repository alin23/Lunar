//
//  SyncMode.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Defaults
import Foundation
import Path

class SyncMode: AdaptiveMode {
    var key = AdaptiveModeKey.sync

    var watcherThread: Thread?
    static var pollingSeconds = Defaults[.syncPollingSeconds]
    static var pollingSecondsObserver = Defaults.observe(.syncPollingSeconds) { change in
        pollingSeconds = change.newValue
    }

    static var builtinBrightnessHistory: UInt64 = 0
    static var lastBuiltinBrightness = 0.0
    static var builtinDisplay = getBuiltinDisplay() {
        didSet {
            lastKnownBuiltinDisplayID = builtinDisplay ?? GENERIC_DISPLAY_ID
        }
    }

    static var lastKnownBuiltinDisplayID: CGDirectDisplayID = GENERIC_DISPLAY_ID
    var available: Bool {
        SyncMode.builtinDisplay != nil && !IsLidClosed()
    }

    static func getBuiltinDisplay() -> CGDirectDisplayID? {
        for screen in NSScreen.screens {
            if let isScreen = screen.deviceDescription[NSDeviceDescriptionKey.isScreen] as? String, isScreen == "YES",
               let nsScreenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            {
                let screenNumber = CGDirectDisplayID(truncating: nsScreenNumber)
                if isBuiltinDisplay(screenNumber) {
                    return screenNumber
                }
            }
        }
        return nil
    }

    static func isBuiltinDisplay(_ id: CGDirectDisplayID) -> Bool {
        return id != GENERIC_DISPLAY_ID && id != TEST_DISPLAY_ID &&
            (CGDisplayIsBuiltin(id) == 1 || id == lastKnownBuiltinDisplayID)
    }

    static func lastValidBuiltinBrightness(_ condition: (UInt8) -> Bool) -> UInt8? {
        var brightnessHistory: UInt64 = builtinBrightnessHistory
        var result: UInt8 = 0
        while brightnessHistory > 0 {
            result = UInt8(brightnessHistory & 0xFF)
            if condition(result) {
                return result
            }
            brightnessHistory >>= 8
        }
        return nil
    }

    static func getBuiltinDisplayBrightness() -> Double? {
        if !IsLidClosed(), let brightness = readBuiltinDisplayBrightness() {
            if brightness >= 0.0, brightness <= 1.0 {
                let percentBrightness = brightness * 100.0
                builtinBrightnessHistory = (builtinBrightnessHistory << 8) | UInt64(UInt8(round(percentBrightness)))
                return percentBrightness
            }
        }
        return nil
    }

    static func readBuiltinDisplayBrightness() -> Double? {
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"))
        var brightness: Float = 0.0
        IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &brightness)
        IOObjectRelease(service)
        return brightness > 0.0 ? Double(brightness) : nil
    }

    func stopWatching() {
        watcherThread?.cancel()
    }

    func watch() -> Bool {
        guard watcherThread?.isCancelled ?? true else {
            return true
        }

        watcherThread = Thread {
            while true {
                if var builtinBrightness = SyncMode.getBuiltinDisplayBrightness(),
                   SyncMode.lastBuiltinBrightness != builtinBrightness
                {
                    displayController.onAdapt?(builtinBrightness)

                    if builtinBrightness == 0 || builtinBrightness == 100, IsLidClosed(),
                       let lastBrightness = SyncMode.lastValidBuiltinBrightness({ b in b > 0 && b < 100 })
                    {
                        builtinBrightness = Double(lastBrightness)
                    }

                    SyncMode.lastBuiltinBrightness = builtinBrightness
                    for display in displayController.activeDisplays.values {
                        self.adapt(brightness: builtinBrightness, display: display)
                    }
                }

                if Thread.current.isCancelled { return }
                Thread.sleep(forTimeInterval: TimeInterval(SyncMode.pollingSeconds))
                if Thread.current.isCancelled { return }
            }
        }
        watcherThread!.start()
        return true
    }

    func adapt(brightness: Double, display: Display) {
        guard display.adaptive else { return }

        let (brightness, contrast) = computeBrightnessContrast(brightness: brightness, display: display)
        display.brightness = brightness.ns
        display.contrast = contrast.ns
    }

    func computeBrightnessContrast(brightness: Double, display: Display) -> (UInt8, UInt8) {
        let brightnessNS = display.computeValue(
            from: brightness / 100.0,
            type: .brightness,
            appOffset: displayController.appBrightnessOffset,
            brightnessClipMin: displayController.brightnessClipMin,
            brightnessClipMax: displayController.brightnessClipMax
        )
        let contrastNS = display.computeValue(
            from: brightness / 100.0,
            type: .contrast,
            appOffset: displayController.appContrastOffset,
            brightnessClipMin: displayController.brightnessClipMin,
            brightnessClipMax: displayController.brightnessClipMax
        )

        // TODO: Curve Fitting algorithm

        return (brightnessNS.uint8Value, contrastNS.uint8Value)
    }

    func adapt(_ display: Display) {
        guard display.adaptive, let brightness = SyncMode.getBuiltinDisplayBrightness() else { return }
        adapt(brightness: brightness, display: display)
    }
}
