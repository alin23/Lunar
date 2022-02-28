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
    // MARK: Lifecycle

    init(display: Display) {
        self.display = display
    }

    // MARK: Internal

    struct ValueRange: Equatable {
        let value: UInt16
        let oldValue: UInt16?
    }

    static var sliderTracking = false

    var displayControl: DisplayControl = .ddc

    weak var display: Display?
    let str = "DDC Control"

    var smoothTransitionBrightnessTask: DispatchWorkItem?
    var smoothTransitionContrastTask: DispatchWorkItem?

    @Atomic var ignoreFaults = false

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

    static func isAvailable(for display: Display) -> Bool {
        display.active && display.hasI2C || display.isForTesting
    }

    func isAvailable() -> Bool {
        guard let display = display else { return false }

        guard display.active else { return false }
        guard let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay else { return false }
        return display.hasI2C || display.isForTesting
    }

    func isResponsive() -> Bool {
        guard let display = display else { return false }

        return display.responsiveDDC
    }

    func resetState() {
        guard let display = display else { return }

        Self.resetState(display: display)
    }

    func setPower(_ power: PowerState) -> Bool {
        guard let display = display else { return false }

        return DDC.setPower(for: display.id, power: power == .on)
    }

    func setRedGain(_ gain: UInt16) -> Bool {
        guard let display = display else { return false }

        return DDC.setRedGain(for: display.id, redGain: gain)
    }

    func setGreenGain(_ gain: UInt16) -> Bool {
        guard let display = display else { return false }

        return DDC.setGreenGain(for: display.id, greenGain: gain)
    }

    func setBlueGain(_ gain: UInt16) -> Bool {
        guard let display = display else { return false }

        return DDC.setBlueGain(for: display.id, blueGain: gain)
    }

    func getRedGain() -> UInt16? {
        guard let display = display else { return nil }
        return DDC.getRedGain(for: display.id)
    }

    func getGreenGain() -> UInt16? {
        guard let display = display else { return nil }
        return DDC.getGreenGain(for: display.id)
    }

    func getBlueGain() -> UInt16? {
        guard let display = display else { return nil }
        return DDC.getBlueGain(for: display.id)
    }

    func resetColors() -> Bool {
        guard let display = display else { return false }
        return DDC.resetColors(for: display.id)
    }

    func setBrightnessDebounced(_ brightness: Brightness, oldValue: Brightness? = nil) -> Bool {
        guard let display = display else {
            log.warning("No display for DDCControl?", context: ["brightness": brightness, "oldBrightness": oldValue])
            return false
        }

        let key = display.preciseBrightnessKey
        let id = display.id

        let value = ValueRange(value: brightness, oldValue: oldValue)

//        print("SETTING BRIGHTNESS TO \(brightness)")
        debounce(
            ms: 3,
            uniqueTaskKey: key,
            value: value,
            subscriberKey: key
        ) { [weak self] range in
            guard let self = self else {
//                log.warning("No `self` for DDCControl?", context: ["values": range])
                cancelTask(key, subscriberKey: key)
                if let display = displayController.activeDisplays[id], let control = display.control as? DDCControl {
                    _ = control.setBrightnessDebounced(range.value, oldValue: range.oldValue)
                }
                return
            }
//            if let oldValue = range.oldValue {
//                print("SETTING BRIGHTNESS FROM \(oldValue) TO \(range.value)")
//            } else {
//                print("SETTING BRIGHTNESS TO \(range.value)")
//            }

            _ = self.setBrightness(range.value, oldValue: range.oldValue, onChange: nil)
        }
        return true
    }

    func setContrastDebounced(_ contrast: Contrast, oldValue: Contrast? = nil) -> Bool {
        guard let display = display else { return false }

        let key = display.preciseContrastKey
        let id = display.id

        let value = ValueRange(value: contrast, oldValue: oldValue)

        debounce(
            ms: 3,
            uniqueTaskKey: key,
            value: value,
            subscriberKey: key
        ) { [weak self] range in
            guard let self = self else {
                cancelTask(key, subscriberKey: key)
                if let display = displayController.activeDisplays[id], let control = display.control as? DDCControl {
                    _ = control.setContrastDebounced(range.value, oldValue: range.oldValue)
                }
                return
            }
            _ = self.setContrast(range.value, oldValue: range.oldValue, onChange: nil)
        }
        return true
    }

    func setBrightness(_ brightness: Brightness, oldValue: Brightness? = nil, onChange: ((Brightness) -> Void)? = nil) -> Bool {
        guard let display = display else { return false }
        if brightnessTransition != .instant, !Self.sliderTracking, supportsSmoothTransition(for: .BRIGHTNESS), var oldValue = oldValue,
           oldValue != brightness
        {
            if display.inSmoothTransition {
                display.shouldStopBrightnessTransition = true
                oldValue = display.lastWrittenBrightness
            }

            var faults = 0
            let delay = brightnessTransition == .smooth ? nil : 0.01

            smoothTransitionBrightnessTask?.cancel()
            smoothTransitionBrightnessTask = display.smoothTransition(
                from: oldValue, to: brightness, delay: delay,
                onStart: { display.shouldStopBrightnessTransition = false }
            ) { [weak self] brightness in
                guard let self = self, faults <= 5 || self.ignoreFaults, let display = self.display,
                      !display.shouldStopBrightnessTransition
                else {
                    log.debug(
                        "Stopping smooth transition to brightness=\(brightness) for \(display)",
                        context: [
                            "faults": faults,
                            "ignoreFaults": self?.ignoreFaults ?? false,
                            "display.shouldStopBrightnessTransition": display.shouldStopBrightnessTransition,
                        ]
                    )
                    return
                }

                log.debug("Writing brightness=\(brightness) using \(self) for \(display)")

                if DDC.setBrightness(for: display.id, brightness: brightness) {
                    display.lastWrittenBrightness = brightness
                } else {
                    faults += 1
                }
                onChange?(brightness)
            }
            return faults <= 5
        }

        defer { onChange?(brightness) }
        return DDC.setBrightness(for: display.id, brightness: brightness)
    }

    func setContrast(_ contrast: Contrast, oldValue: Contrast? = nil, onChange: ((Contrast) -> Void)? = nil) -> Bool {
        guard let display = display else { return false }

        if brightnessTransition != .instant, !Self.sliderTracking, supportsSmoothTransition(for: .CONTRAST), var oldValue = oldValue,
           oldValue != contrast
        {
            if display.inSmoothTransition {
                display.shouldStopContrastTransition = true
                oldValue = display.lastWrittenContrast
            }

            var faults = 0
            let delay = brightnessTransition == .smooth ? nil : 0.01

            smoothTransitionContrastTask?.cancel()
            smoothTransitionContrastTask = display.smoothTransition(
                from: oldValue, to: contrast, delay: delay,
                onStart: { display.shouldStopContrastTransition = false }
            ) { [weak self] contrast in
                guard let self = self, faults <= 5 || self.ignoreFaults, let display = self.display,
                      !display.shouldStopContrastTransition
                else {
                    log.debug(
                        "Stopping smooth transition to contrast=\(contrast) for \(display)",
                        context: [
                            "faults": faults,
                            "ignoreFaults": self?.ignoreFaults ?? false,
                            "display.shouldStopContrastTransition": display.shouldStopContrastTransition,
                        ]
                    )
                    return
                }

                log.debug("Writing contrast=\(contrast) using \(self) for \(display)")

                if DDC.setContrast(for: display.id, contrast: contrast) {
                    display.lastWrittenContrast = contrast
                } else {
                    faults += 1
                }
                onChange?(contrast)
            }
            return faults <= 5
        }
        defer { onChange?(contrast) }
        return DDC.setContrast(for: display.id, contrast: contrast)
    }

    func setVolume(_ volume: UInt16) -> Bool {
        guard let display = display else { return false }

        return DDC.setAudioSpeakerVolume(for: display.id, audioSpeakerVolume: volume)
    }

    func setMute(_ muted: Bool) -> Bool {
        guard let display = display else { return false }

        return DDC.setAudioMuted(for: display.id, audioMuted: muted)
    }

    func setInput(_ input: InputSource) -> Bool {
        guard let display = display else { return false }

        return DDC.setInput(for: display.id, input: input)
    }

    func getBrightness() -> Brightness? {
        guard let display = display else { return nil }
        return DDC.getBrightness(for: display.id)
    }

    func getContrast() -> Contrast? {
        guard let display = display else { return nil }
        return DDC.getContrast(for: display.id)
    }

    func getMaxBrightness() -> Brightness? {
        guard let display = display else { return nil }
        return DDC.getMaxValue(for: display.id, controlID: .BRIGHTNESS)
    }

    func getMaxContrast() -> Contrast? {
        guard let display = display else { return nil }
        return DDC.getMaxValue(for: display.id, controlID: .CONTRAST)
    }

    func getMaxVolume() -> UInt16? {
        guard let display = display else { return nil }
        return DDC.getMaxValue(for: display.id, controlID: .AUDIO_SPEAKER_VOLUME)
    }

    func getVolume() -> UInt16? {
        guard let display = display else { return nil }
        return DDC.getAudioSpeakerVolume(for: display.id)
    }

    func getMute() -> Bool? {
        guard let display = display else { return nil }
        return DDC.isAudioMuted(for: display.id)
    }

    func getInput() -> InputSource? {
        guard let display = display else { return nil }
        guard let input = DDC.getInput(for: display.id), let inputSource = InputSource(rawValue: input) else { return nil }
        return inputSource
    }

    func reset() -> Bool {
        guard let display = display else { return false }

        DDC.reset()
        return DDC.resetBrightnessAndContrast(for: display.id)
    }

    func supportsSmoothTransition(for _: ControlID) -> Bool {
        guard let display = display else { return false }

        return !display.slowWrite
    }
}
