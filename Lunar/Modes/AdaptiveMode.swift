//
//  Mode.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Foundation

enum AdaptiveModeKey: Int, Codable {
    case location = 1
    case sync = -1
    case manual = 0
    case sensor = 2

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
        }
    }

    var mode: AdaptiveMode {
        switch self {
        case .sensor:
            return SensorMode().ifAvailable() ?? ManualMode()
        case .manual:
            return ManualMode()
        case .location:
            return LocationMode().ifAvailable() ?? ManualMode()
        case .sync:
            return SyncMode().ifAvailable() ?? ManualMode()
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
        }
    }
}

protocol AdaptiveMode {
    var key: AdaptiveModeKey { get }
    var available: Bool { get }
    var str: String { get }

    func stopWatching()
    func watch() -> Bool
    func adapt(_ display: Display)
}

extension AdaptiveMode {
    var str: String {
        return key.str
    }

    func ifAvailable() -> Self? {
        guard available else { return nil }
        return self
    }
}
