//
//  DDCControl.swift
//  Lunar
//
//  Created by Alin Panaitiu on 18.02.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Defaults
import Foundation

class DDCControl: Control {
    var displayControl: DisplayControl = .ddc

    weak var display: Display!
    let str = "DDC Control"

    init(display: Display) {
        self.display = display
    }

    func isAvailable() -> Bool {
        guard let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay else { return false }
        return display.hasI2C || display.isForTesting
    }

    func isResponsive() -> Bool {
        display.responsiveDDC
    }

    func resetState() {
        Self.resetState(display: display)
    }

    static func resetState(display: Display? = nil) {
        if let display = display {
            DDC.skipWritingPropertyById[display.id]?.removeAll()
            DDC.skipReadingPropertyById[display.id]?.removeAll()
            DDC.writeFaults[display.id]?.removeAll()
            DDC.readFaults[display.id]?.removeAll()
            display.responsiveDDC = true
            display.startI2CDetection()
            display.lastConnectionTime = Date()
        } else {
            DDC.skipWritingPropertyById.removeAll()
            DDC.skipReadingPropertyById.removeAll()
            DDC.writeFaults.removeAll()
            DDC.readFaults.removeAll()
            for display in displayController.activeDisplays.values {
                display.responsiveDDC = true
                display.startI2CDetection()
                display.lastConnectionTime = Date()
            }
        }
    }

    func setPower(_ power: PowerState) -> Bool {
        DDC.setPower(for: display.id, power: power == .on)
    }

    func setBrightness(_ brightness: Brightness, oldValue: Brightness? = nil) -> Bool {
        if CachedDefaults[.smoothTransition], supportsSmoothTransition(for: .BRIGHTNESS), let oldValue = oldValue {
            var faults = 0
            display.smoothTransition(from: oldValue, to: brightness) { brightness in
                if faults > 5 {
                    return
                }

                log.debug(
                    "Writing brightness using \(self)",
                    context: ["name": self.display.name, "id": self.display.id, "serial": self.display.serial]
                )
                if !DDC.setBrightness(for: self.display.id, brightness: brightness) {
                    faults += 1
                }
            }
            return faults > 5
        }

        return DDC.setBrightness(for: display.id, brightness: brightness)
    }

    func setContrast(_ contrast: Contrast, oldValue: Contrast? = nil) -> Bool {
        if CachedDefaults[.smoothTransition], supportsSmoothTransition(for: .CONTRAST), let oldValue = oldValue {
            var faults = 0
            display.smoothTransition(from: oldValue, to: contrast) { contrast in
                if faults > 5 {
                    return
                }

                log.debug(
                    "Writing contrast using \(self)",
                    context: ["name": self.display.name, "id": self.display.id, "serial": self.display.serial]
                )
                if !DDC.setContrast(for: self.display.id, contrast: contrast) {
                    faults += 1
                }
            }
            return faults > 5
        }
        return DDC.setContrast(for: display.id, contrast: contrast)
    }

    func setVolume(_ volume: UInt8) -> Bool {
        DDC.setAudioSpeakerVolume(for: display.id, audioSpeakerVolume: volume)
    }

    func setMute(_ muted: Bool) -> Bool {
        DDC.setAudioMuted(for: display.id, audioMuted: muted)
    }

    func setInput(_ input: InputSource) -> Bool {
        DDC.setInput(for: display.id, input: input)
    }

    func getBrightness() -> Brightness? {
        DDC.getBrightness(for: display.id)
    }

    func getContrast() -> Contrast? {
        DDC.getContrast(for: display.id)
    }

    func getMaxBrightness() -> Brightness? {
        DDC.getMaxValue(for: display.id, controlID: .BRIGHTNESS)
    }

    func getMaxContrast() -> Contrast? {
        DDC.getMaxValue(for: display.id, controlID: .CONTRAST)
    }

    func getVolume() -> UInt8? {
        DDC.getAudioSpeakerVolume(for: display.id)
    }

    func getMute() -> Bool? {
        DDC.isAudioMuted(for: display.id)
    }

    func getInput() -> InputSource? {
        guard let input = DDC.getInput(for: display.id), let inputSource = InputSource(rawValue: input) else { return nil }
        return inputSource
    }

    func reset() -> Bool {
        DDC.reset()
        return DDC.resetBrightnessAndContrast(for: display.id)
    }

    func supportsSmoothTransition(for _: ControlID) -> Bool {
        !display.slowWrite
    }
}
