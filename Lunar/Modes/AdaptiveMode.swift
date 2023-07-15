//
//  Mode.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Accelerate
import ArgumentParser
import Atomics
import Cocoa
import Defaults
import Foundation
import Surge

let AUTO_MODE_TAG = 99

// MARK: - AdaptiveModeKey + Codable, ExpressibleByArgument, Nameable

extension AdaptiveModeKey: Codable, ExpressibleByArgument, Nameable {
    var isSeparator: Bool { false }
    init?(argument: String) {
        guard argument.lowercased().stripped != "auto" else {
            CachedDefaults[.overrideAdaptiveMode] = false
            self = DisplayController.autoMode().key
            return
        }
        CachedDefaults[.overrideAdaptiveMode] = true
        self = AdaptiveModeKey.fromstr(argument)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let strValue = try? container.decode(String.self) else {
            let intValue = try container.decode(Int.self)
            self = AdaptiveModeKey(rawValue: intValue) ?? .manual
            return
        }

        self = AdaptiveModeKey.fromstr(strValue)
    }

    var name: String {
        get { "\(str) Mode" }
        set {}
    }

    var tag: Int? { rawValue }
    var enabled: Bool {
        lunarProActive || lunarProOnTrial || self == .manual || self == .auto
    }

    var image: String? {
        str.lowercased() + "mode"
    }

    var str: String {
        switch self {
        case .sensor:
            return "Sensor"
        case .manual:
            return "Manual"
        case .location:
            return "Location"
        case .sync:
            return "Sync"
        case .clock:
            return "Clock"
        case .auto:
            return "Auto"
        }
    }

    var available: Bool {
        switch self {
        case .sensor:
            return SensorMode.shared.available
        case .manual:
            return ManualMode.shared.available
        case .location:
            return LocationMode.shared.available
        case .sync:
            return SyncMode.shared.available
        case .clock:
            return ClockMode.shared.available
        case .auto:
            return DisplayController.autoMode().available
        }
    }

    var mode: AdaptiveMode {
        switch self {
        case .sensor:
            return SensorMode.shared
        case .manual:
            return ManualMode.shared
        case .location:
            return LocationMode.shared
        case .sync:
            return SyncMode.shared
        case .clock:
            return ClockMode.shared
        case .auto:
            return DisplayController.autoMode()
        }
    }

    var helpText: String {
        switch self {
        case .sensor:
            return SENSOR_HELP_TEXT
        case .manual:
            return MANUAL_HELP_TEXT
        case .location:
            return LOCATION_HELP_TEXT
        case .sync:
            return SYNC_HELP_TEXT
        case .clock:
            return CLOCK_HELP_TEXT
        case .auto:
            return ""
        }
    }

    var helpLink: String? {
        switch self {
        case .sensor:
            return nil
        case .manual:
            return nil
        case .location:
            return "https://ipstack.com"
        case .sync:
            return nil
        case .clock:
            return nil
        case .auto:
            return nil
        }
    }

    static func fromstr(_ strValue: String) -> Self {
        switch strValue.lowercased().stripped {
        case "sensor", AdaptiveModeKey.sensor.rawValue.s:
            return .sensor
        case "manual", AdaptiveModeKey.manual.rawValue.s:
            return .manual
        case "location", AdaptiveModeKey.location.rawValue.s:
            return .location
        case "sync", AdaptiveModeKey.sync.rawValue.s:
            return .sync
        case "clock", AdaptiveModeKey.clock.rawValue.s:
            return .clock
        case "auto", AdaptiveModeKey.auto.rawValue.s:
            return .auto
        default:
            return .manual
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(str)
    }
}

// MARK: - DataPoint

struct DataPoint {
    var min: Double
    var max: Double
    var last: Double
}

// MARK: - AdaptiveMode

protocol AdaptiveMode: AnyObject {
    var force: Bool { get set }
    var watching: Bool { get set }
    var brightnessDataPoint: DataPoint { get set }
    var contrastDataPoint: DataPoint { get set }
    var maxChartDataPoints: Int { get set }

    static var shared: AdaptiveMode { get }
    var key: AdaptiveModeKey { get }
    var available: Bool { get }
    var availableForOnboarding: Bool { get }
    var str: String { get }

    func stopWatching()
    func watch()
    func adapt(_ display: Display)
}

var datapointLock = NSRecursiveLock()

extension AdaptiveMode {
    static var sensor: AdaptiveMode { SensorMode.shared }
    static var sync: AdaptiveMode { SyncMode.shared }
    static var location: AdaptiveMode { LocationMode.shared }
    static var clock: AdaptiveMode { ClockMode.shared }
    static var manual: AdaptiveMode { ManualMode.shared }

    var str: String {
        key.str
    }

    @inline(__always) func withForce(_ force: Bool = true, _ block: () -> Void) {
        self.force = force
        block()
        self.force = false
    }

    @inline(__always) func ifAvailable() -> Self? {
        guard available else { return nil }
        return self
    }
}

extension [Float] {
    @inline(__always) var d: [Double] {
        vDSP.floatToDouble(self)
    }
}

// MARK: - AdaptiveModeMenuValidator

final class AdaptiveModeMenuValidator: NSObject, NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let mode = AdaptiveModeKey(rawValue: menuItem.tag) else {
            return false
        }
        return mode.available
    }
}

let adaptiveModeMenuValidator = AdaptiveModeMenuValidator()

@MainActor
final class AdaptiveModeInfo: ObservableObject {
    init() {}

    @Published var lux: Double?
    @Published var nits: Double?
    @Published var sunElevation: Double?
}

@MainActor
let AMI = AdaptiveModeInfo()
