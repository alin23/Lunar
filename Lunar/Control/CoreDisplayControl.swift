//
//  CoreDisplayControl.swift
//  Lunar
//
//  Created by Alin Panaitiu on 18.02.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Defaults
import Foundation
import SwiftDate

// MARK: - CoreDisplayMethod

enum CoreDisplayMethod {
    case coreDisplay
    case displayServices
}

// MARK: - CoreDisplayControl

class CoreDisplayControl: Control {
    // MARK: Lifecycle

    init(display: Display) {
        self.display = display
    }

    // MARK: Internal

    var displayControl: DisplayControl = .coreDisplay

    weak var display: Display!
    lazy var responsive: Bool = testReadAndWrite(method: .displayServices) || testReadAndWrite(method: .coreDisplay)
    let str = "CoreDisplay Control"
    var method = CoreDisplayMethod.displayServices

    func testReadAndWrite(method: CoreDisplayMethod) -> Bool {
        switch method {
        case .coreDisplay:
            let currentBrightness = CoreDisplay_Display_GetUserBrightness(display.id)
            let brightnessToSet = currentBrightness < 0.5 ? currentBrightness + 0.01 : currentBrightness - 0.01
            CoreDisplay_Display_SetUserBrightness(display.id, brightnessToSet)
            DisplayServicesBrightnessChanged(display.id, brightnessToSet)

            let newBrightness = CoreDisplay_Display_GetUserBrightness(display.id)

            guard newBrightness == brightnessToSet else {
                return false
            }

            CoreDisplay_Display_SetUserBrightness(display.id, currentBrightness)
            DisplayServicesBrightnessChanged(display.id, currentBrightness)
            self.method = method
            return true
        case .displayServices:
            if DisplayServicesCanChangeBrightness(display.id) {
                self.method = method
                return true
            }

            var currentBrightness: Float = 0.0
            guard DisplayServicesGetBrightness(display.id, &currentBrightness) == KERN_SUCCESS else {
                return false
            }

            let brightnessToSet = currentBrightness < 0.5 ? currentBrightness + 0.01 : currentBrightness - 0.01
            guard DisplayServicesSetBrightness(display.id, brightnessToSet) == KERN_SUCCESS else {
                return false
            }

            var newBrightness: Float = 0.0
            guard DisplayServicesGetBrightness(display.id, &newBrightness) == KERN_SUCCESS else {
                return false
            }

            guard newBrightness == brightnessToSet else {
                return false
            }

            DisplayServicesSetBrightness(display.id, currentBrightness)
            self.method = method
            return true
        }
    }

    func isAvailable() -> Bool {
        guard let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay else { return false }
        return display.isAppleDisplay() || display.isForTesting
    }

    func isResponsive() -> Bool {
        #if DEBUG
            responsive || TEST_IDS.contains(display.id)
        #else
            responsive
        #endif
    }

    func resetState() {
        responsive = testReadAndWrite(method: .displayServices) || testReadAndWrite(method: .coreDisplay)
    }

    func writeBrightness(_ brightness: Brightness) -> Bool {
        switch method {
        case .coreDisplay:
            let br = brightness.d / 100.0
            CoreDisplay_Display_SetUserBrightness(display.id, br)
            DisplayServicesBrightnessChanged(display.id, br)
        case .displayServices:
            return DisplayServicesSetBrightness(display.id, brightness.f / 100.0) == KERN_SUCCESS
        }
        return true
    }

    func setPower(_ power: PowerState) -> Bool {
        guard let control = display.alternativeControlForCoreDisplay else { return false }
        return control.setPower(power)
    }

    func setRedGain(_ gain: UInt8) -> Bool {
        guard let control = display.alternativeControlForCoreDisplay else { return false }
        return control.setRedGain(gain)
    }

    func setGreenGain(_ gain: UInt8) -> Bool {
        guard let control = display.alternativeControlForCoreDisplay else { return false }
        return control.setGreenGain(gain)
    }

    func setBlueGain(_ gain: UInt8) -> Bool {
        guard let control = display.alternativeControlForCoreDisplay else { return false }
        return control.setBlueGain(gain)
    }

    func getRedGain() -> UInt8? {
        guard let control = display.alternativeControlForCoreDisplay else { return nil }
        return control.getRedGain()
    }

    func getGreenGain() -> UInt8? {
        guard let control = display.alternativeControlForCoreDisplay else { return nil }
        return control.getGreenGain()
    }

    func getBlueGain() -> UInt8? {
        guard let control = display.alternativeControlForCoreDisplay else { return nil }
        return control.getBlueGain()
    }

    func resetColors() -> Bool {
        guard let control = display.alternativeControlForCoreDisplay else { return false }
        return control.resetColors()
    }

    func setBrightness(_ brightness: Brightness, oldValue: Brightness? = nil) -> Bool {
        guard !display.isForTesting else { return false }

        if CachedDefaults[.smoothTransition], supportsSmoothTransition(for: .BRIGHTNESS), let oldValue = oldValue, oldValue != brightness {
            var faults = 0
            display.smoothTransition(from: oldValue, to: brightness) { [weak self] brightness in
                guard let self = self else { return }
                if faults > 5 {
                    return
                }

                log.debug(
                    "Writing brightness using \(self)",
                    context: ["name": self.display.name, "id": self.display.id, "serial": self.display.serial]
                )
                if !self.writeBrightness(brightness) {
                    faults += 1
                }
            }
            return faults > 5
        }

        return writeBrightness(brightness)
    }

    func setContrast(_ contrast: Contrast, oldValue: Contrast? = nil) -> Bool {
        guard let control = display.alternativeControlForCoreDisplay else { return false }
        return control.setContrast(contrast, oldValue: oldValue)
    }

    func setVolume(_ volume: UInt8) -> Bool {
        guard let control = display.alternativeControlForCoreDisplay else { return false }
        return control.setVolume(volume)
    }

    func setMute(_ muted: Bool) -> Bool {
        guard let control = display.alternativeControlForCoreDisplay else { return false }
        return control.setMute(muted)
    }

    func setInput(_ input: InputSource) -> Bool {
        guard let control = display.alternativeControlForCoreDisplay else { return false }
        return control.setInput(input)
    }

    func getBrightness() -> Brightness? {
        switch method {
        case .coreDisplay:
            return (CoreDisplay_Display_GetUserBrightness(display.id) * 100.0).u8
        case .displayServices:
            var br = display.brightness.floatValue
            DisplayServicesGetBrightness(display.id, &br)
            return (br * 100.0).u8
        }
    }

    func getContrast() -> Contrast? {
        guard let control = display.alternativeControlForCoreDisplay else { return nil }
        return control.getContrast()
    }

    func getMaxBrightness() -> Brightness? {
        guard let control = display.alternativeControlForCoreDisplay else { return nil }
        return control.getMaxBrightness()
    }

    func getMaxContrast() -> Contrast? {
        guard let control = display.alternativeControlForCoreDisplay else { return nil }
        return control.getMaxContrast()
    }

    func getVolume() -> UInt8? {
        guard let control = display.alternativeControlForCoreDisplay else { return nil }
        return control.getVolume()
    }

    func getMute() -> Bool? {
        guard let control = display.alternativeControlForCoreDisplay else { return nil }
        return control.getMute()
    }

    func getInput() -> InputSource? {
        guard let control = display.alternativeControlForCoreDisplay else { return nil }
        return control.getInput()
    }

    func reset() -> Bool {
        guard let control = display.alternativeControlForCoreDisplay else { return false }
        return control.reset()
    }

    func supportsSmoothTransition(for controlID: ControlID) -> Bool {
        switch controlID {
        case .BRIGHTNESS:
            return true
        default:
            guard let control = display.alternativeControlForCoreDisplay else { return false }
            return control.supportsSmoothTransition(for: controlID)
        }
    }
}
