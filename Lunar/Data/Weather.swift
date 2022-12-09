//
//  Weather.swift
//  Model Generated using http://www.jsoncafe.com/
//  Created on May 6, 2021

import Defaults
import Foundation

// MARK: - Wttr

struct Wttr: Codable, Defaults.Serializable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        currentCondition = try values.decodeIfPresent([WeatherCurrentCondition].self, forKey: .currentCondition)
        weather = try values.decodeIfPresent([Weather].self, forKey: .weather)
    }

    enum CodingKeys: String, CodingKey {
        case currentCondition = "current_condition"
        case weather
    }

    let currentCondition: [WeatherCurrentCondition]?
    let weather: [Weather]?
}

// MARK: - Weather

struct Weather: Codable, Defaults.Serializable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        date = try values.decodeIfPresent(String.self, forKey: .date)
        hourly = try values.decodeIfPresent([WeatherHourly].self, forKey: .hourly)
    }

    enum CodingKeys: String, CodingKey {
        case date
        case hourly
    }

    let date: String?
    let hourly: [WeatherHourly]?
}

// MARK: - WeatherHourly

struct WeatherHourly: Codable, Defaults.Serializable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        cloudcover = (try? values.decodeIfPresent(UInt8.self, forKey: .cloudcover)) ??
            (try? values.decodeIfPresent(String.self, forKey: .cloudcover))?.u8 ?? 0
        visibility = (try? values.decodeIfPresent(UInt32.self, forKey: .visibility)) ??
            (try? values.decodeIfPresent(String.self, forKey: .visibility))?.u32 ?? 100
        time = (try? values.decodeIfPresent(Int.self, forKey: .time)) ?? (try? values.decodeIfPresent(String.self, forKey: .time)?.i) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case cloudcover
        case time
        case visibility
    }

    let cloudcover: UInt8
    let time: Int
    let visibility: UInt32
    lazy var date: Date = localNow().dateBySet(hour: time / 100, min: 0, secs: 0)?.date ?? Date()
}

// MARK: - WeatherCurrentCondition

struct WeatherCurrentCondition: Codable, Defaults.Serializable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        cloudcover = (try? values.decodeIfPresent(UInt8.self, forKey: .cloudcover)) ??
            (try? values.decodeIfPresent(String.self, forKey: .cloudcover))?.u8 ?? 0
        visibility = (try? values.decodeIfPresent(UInt32.self, forKey: .visibility)) ??
            (try? values.decodeIfPresent(String.self, forKey: .visibility))?.u32 ?? 100
    }

    enum CodingKeys: String, CodingKey {
        case cloudcover
        case visibility
    }

    let cloudcover: UInt8
    let visibility: UInt32
}
