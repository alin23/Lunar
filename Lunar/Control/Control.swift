//
//  Control.swift
//  Lunar
//
//  Created by Alin Panaitiu on 18.02.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import ArgumentParser
import Foundation

// MARK: - FeatureState

enum FeatureState: String, ExpressibleByArgument {
    case disable
    case enable
}

// MARK: - PowerState

enum PowerState: String, ExpressibleByArgument {
    case on
    case off
}

// MARK: - DisplayControl

enum DisplayControl: Int, Codable, EnumerableFlag {
    case network
    case appleNative
    case ddc
    case gamma
    case ddcctl

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let strValue = try? container.decode(String.self) else {
            let intValue = try container.decode(Int.self)
            self = DisplayControl(rawValue: intValue) ?? .ddc
            return
        }

        self = DisplayControl.fromstr(strValue)
    }

    var str: String {
        switch self {
        case .network:
            return "Network"
        case .appleNative:
            return "AppleNative"
        case .ddc:
            return "DDC"
        case .gamma:
            return "Gamma"
        case .ddcctl:
            return "ddcctl"
        }
    }

    static func fromstr(_ strValue: String) -> Self {
        switch strValue.lowercased().stripped {
        case "network", DisplayControl.network.rawValue.s:
            return .network
        case "appleNative", "coreDisplay", DisplayControl.appleNative.rawValue.s:
            return .appleNative
        case "ddc", DisplayControl.ddc.rawValue.s:
            return .ddc
        case "gamma", DisplayControl.gamma.rawValue.s:
            return .gamma
        case "ddcctl", DisplayControl.ddcctl.rawValue.s:
            return .ddcctl
        default:
            return .ddc
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(str)
    }
}

// MARK: - Control

protocol Control {
    var display: Display? { get set }
    var str: String { get }
    var displayControl: DisplayControl { get }
    var isSoftware: Bool { get }
    var isDDC: Bool { get }

    func setBrightness(
        _ brightness: Brightness,
        oldValue: Brightness?,
        force: Bool,
        transition: BrightnessTransition?,
        onChange: ((Brightness) -> Void)?
    ) -> Bool
    func setContrast(_ contrast: Contrast, oldValue: Contrast?, transition: BrightnessTransition?, onChange: ((Contrast) -> Void)?) -> Bool
    func setVolume(_ volume: UInt16) -> Bool
    func setInput(_ input: VideoInputSource) -> Bool
    func setMute(_ muted: Bool) -> Bool
    func setPower(_ power: PowerState) -> Bool

    func setRedGain(_ gain: UInt16) -> Bool
    func setGreenGain(_ gain: UInt16) -> Bool
    func setBlueGain(_ gain: UInt16) -> Bool

    func getRedGain() -> UInt16?
    func getGreenGain() -> UInt16?
    func getBlueGain() -> UInt16?

    func getBrightness() -> Brightness?
    func getContrast() -> Contrast?
    func getVolume() -> UInt16?
    func getMute() -> Bool?
    func getInput() -> VideoInputSource?

    func getMaxBrightness() -> Brightness?
    func getMaxContrast() -> Contrast?
    func getMaxVolume() -> UInt16?

    func reset() -> Bool
    func resetState()
    func resetColors() -> Bool

    func isAvailable() -> Bool
    func isResponsive() -> Bool
    func supportsSmoothTransition(for controlID: ControlID) -> Bool
}

extension Control {
    func reapply() {
        guard let display else { return }
        _ = setBrightness(display.limitedBrightness, oldValue: nil, force: false, transition: brightnessTransition, onChange: nil)
        _ = setContrast(display.limitedContrast, oldValue: nil, transition: brightnessTransition, onChange: nil)
    }

    func read(_ key: Display.CodingKeys) -> Any? {
        switch key {
        case .brightness:
            return getBrightness()
        case .contrast:
            return getContrast()
        case .maxBrightness, .maxDDCBrightness:
            return getMaxBrightness()
        case .maxContrast, .maxDDCContrast:
            return getMaxContrast()
        case .maxDDCVolume:
            return getMaxVolume()
        case .volume:
            return getVolume()
        case .input:
            return getInput()
        case .audioMuted:
            return getMute()
        case .redGain:
            return getRedGain()
        case .greenGain:
            return getGreenGain()
        case .blueGain:
            return getBlueGain()
        default:
            log.warning("\(key) is not readable")
            return nil
        }
    }

    @discardableResult func write(_ key: Display.CodingKeys, _ value: Any, _ oldValue: UInt16? = nil) -> Any? {
        switch key {
        case .brightness:
            return setBrightness(
                value as! Brightness,
                oldValue: oldValue,
                force: false,
                transition: brightnessTransition,
                onChange: nil
            )
        case .contrast:
            return setContrast(value as! Contrast, oldValue: oldValue, transition: brightnessTransition, onChange: nil)
        case .volume:
            return setVolume(value as! UInt16)
        case .input:
            return setInput(value as! VideoInputSource)
        case .audioMuted:
            return setMute(value as! Bool)
        case .power:
            return setPower(value as! PowerState)
        default:
            log.warning("\(key) is not writable")
            return nil
        }
    }
}
