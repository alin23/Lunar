//
//  DDCCTLControl.swift
//  Lunar
//
//  Created by Alin Panaitiu on 20.05.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Foundation

struct DDCCTLControl: Control {
    static let ddcctlBinary = Bundle.main.path(forResource: "ddcctl", ofType: nil)!

    var display: Display!

    var str: String = "ddcctl"

    var displayControl: DisplayControl = .ddcctl

    var displayIndex: Int? {
        display.screen != nil ? NSScreen.screens.filter { !$0.isBuiltin }.firstIndex(of: display.screen!) : nil
    }

    func propertyArg(_ property: ControlID) -> String {
        switch property {
        case .BRIGHTNESS:
            return "-b"
        case .CONTRAST:
            return "-c"
        case .AUDIO_MUTE:
            return "-m"
        case .INPUT_SOURCE:
            return "-i"
        case .AUDIO_SPEAKER_VOLUME:
            return "-v"
        case .DPMS:
            return "-p"
        case .RESET_BRIGHTNESS_AND_CONTRAST:
            return "-rbc"
        default:
            return ""
        }
    }

    func ddcctlSet(_ property: ControlID, value: UInt8) -> Bool {
        guard let index = displayIndex else { return false }
        let ddcctlSemaphore = DispatchSemaphore(value: 0, name: "ddcctlSemaphore")
        var command = "ddcctl "
        let process: Process
        do {
            var args = ["-d", index.s, propertyArg(property)]
            if property != .RESET_BRIGHTNESS_AND_CONTRAST {
                args.append(value.s)
            }

            command += args.joined(separator: " ")

            process = try Process.run(
                DDCCTLControl.ddcctlBinary.url,
                arguments: args,
                terminationHandler: { process in
                    log.info("`\(command)` status: \(process.terminationStatus)")
                    ddcctlSemaphore.signal()
                }
            )
        } catch {
            return false
        }

        guard ddcctlSemaphore.wait(for: 20) != .timedOut else {
            log.error("Timed out on command `\(command)`")
            process.terminate()
            return false
        }

        return process.terminationStatus == 0
    }

    func setBrightness(_ value: Brightness, oldValue _: Brightness? = nil) -> Bool {
        ddcctlSet(.BRIGHTNESS, value: value)
    }

    func setContrast(_ value: Contrast, oldValue _: Brightness?) -> Bool {
        ddcctlSet(.CONTRAST, value: value)
    }

    func setVolume(_ value: UInt8) -> Bool {
        ddcctlSet(.AUDIO_SPEAKER_VOLUME, value: value)
    }

    func setInput(_ value: InputSource) -> Bool {
        ddcctlSet(.INPUT_SOURCE, value: value.rawValue)
    }

    func setMute(_ value: Bool) -> Bool {
        ddcctlSet(.AUDIO_MUTE, value: value ? 1 : 2)
    }

    func setPower(_ value: PowerState) -> Bool {
        ddcctlSet(.DPMS, value: value == .on ? 1 : 5)
    }

    func getBrightness() -> Brightness? {
        nil
    }

    func getContrast() -> Contrast? {
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

    func getMaxBrightness() -> Brightness? {
        nil
    }

    func getMaxContrast() -> Contrast? {
        nil
    }

    func reset() -> Bool {
        ddcctlSet(.RESET_BRIGHTNESS_AND_CONTRAST, value: 1)
    }

    func resetState() {}

    func isAvailable() -> Bool {
        true
    }

    func isResponsive() -> Bool {
        true
    }

    func supportsSmoothTransition(for _: ControlID) -> Bool {
        false
    }
}
