//
//  Mode.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Accelerate
import Atomics
import Cocoa
import Defaults
import Foundation
import Surge

let STRIDE = vDSP_Stride(1)

enum AdaptiveModeKey: Int, Codable, Defaults.Serializable {
    case location = 1
    case sync = -1
    case manual = 0
    case sensor = 2

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(str)
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
        default:
            return .manual
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

struct DataPoint {
    var min: Int
    var max: Int
    var last: Int
}

var contrastCurveFactor: Double = 1
var brightnessCurveFactor: Double = 1

protocol AdaptiveMode: AnyObject {
    var force: Bool { get set }
    var watching: Bool { get set }
    var brightnessDataPoint: DataPoint { get set }
    var contrastDataPoint: DataPoint { get set }
    var maxChartDataPoints: Int { get set }

    static var shared: AdaptiveMode { get }
    var key: AdaptiveModeKey { get }
    var available: Bool { get }
    var str: String { get }

    func stopWatching()
    func watch() -> Bool
    func adapt(_ display: Display)
}

var datapointLock = NSRecursiveLock()

extension AdaptiveMode {
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

    func adjustCurve(_ value: Double, factor: Double, minVal: Double = MIN_BRIGHTNESS.d, maxVal: Double = MAX_BRIGHTNESS.d) -> Double {
        guard maxVal != minVal else {
            return value
        }

        let diff = maxVal - minVal
        return pow((value - minVal) / diff, factor) * diff + minVal
    }

    @inline(__always) func adjustCurveSIMD(
        _ value: [Double],
        factor: Double,
        minVal: Double = MIN_BRIGHTNESS.d,
        maxVal: Double = MAX_BRIGHTNESS.d
    ) -> [Double] {
        guard maxVal != minVal else {
            return value
        }

        let diff = maxVal - minVal
        return pow((value - minVal) / diff, factor) * diff + minVal
    }

    @inline(__always) func adjustCurveSIMD(
        _ value: [Float],
        factor: Float,
        minVal: Float = MIN_BRIGHTNESS.f,
        maxVal: Float = MAX_BRIGHTNESS.f
    ) -> [Float] {
        guard maxVal != minVal else {
            return value
        }

        let diff = maxVal - minVal
        return pow((value - minVal) / diff, factor) * diff + minVal
    }

    func interpolateSIMD(
        _ monitorValue: MonitorValue,
        display: Display,
        minVal: Double? = nil,
        maxVal: Double? = nil,
        offset: Double? = nil,
        factor: Double? = nil,
        userValues: [Int: Int]? = nil
    ) -> [Double] {
        let (value, minValue, maxValue, displayUserValues) = display.values(monitorValue, modeKey: key)
        var userValues = userValues ?? displayUserValues

        var dataPoint: DataPoint
        var curveFactor: Float

        switch monitorValue {
        case .brightness, .nsBrightness, .preciseBrightness:
            dataPoint = datapointLock.around { brightnessDataPoint }
            curveFactor = factor?.f ?? brightnessCurveFactor.f
        default:
            dataPoint = datapointLock.around { contrastDataPoint }
            curveFactor = factor?.f ?? contrastCurveFactor.f
        }

        let curve = interpolate(
            values: &userValues,
            dataPoint: dataPoint,
            factor: curveFactor > 0 ? curveFactor : 1,
            offset: offset?.f ?? 0.0
        )

        #if DEBUG
            if curve.contains(where: \.isNaN) {
                log.error(
                    "NaN value?? Whyy?? WHAT DID I DO??",
                    context: ["value": value, "minValue": minValue, "maxValue": maxValue, "monitorValue": monitorValue, "offset": offset ?? 1]
                )
            }
        #endif

        let values = mapNumberSIMD(
            curve,
            fromLow: MIN_BRIGHTNESS.d,
            fromHigh: MAX_BRIGHTNESS.d,
            toLow: minVal ?? minValue,
            toHigh: maxVal ?? maxValue
        )
        #if DEBUG
            if values.contains(where: \.isNaN) {
                log.error(
                    "Whaat!? NaN value AGAIN?? Whyy?? WHAT DID I DO??",
                    context: ["value": value, "minValue": minValue, "maxValue": maxValue, "monitorValue": monitorValue, "offset": offset ?? 1]
                )
            }
        #endif
        return values
    }

    func interpolate(_ monitorValue: MonitorValue, display: Display, offset: Float = 0.0, factor: Double? = nil) -> Double {
        let (value, minValue, maxValue, userValues) = display.values(monitorValue, modeKey: key)

        var dataPoint: DataPoint
        var curveFactor: Double

        switch monitorValue {
        case .brightness, .nsBrightness, .preciseBrightness:
            dataPoint = datapointLock.around { brightnessDataPoint }
            curveFactor = factor ?? brightnessCurveFactor
        default:
            dataPoint = datapointLock.around { contrastDataPoint }
            curveFactor = factor ?? contrastCurveFactor
        }

        var newValue: Double

        if let userValue = userValues[value.intround] {
            newValue = userValue.d
        } else {
            let sorted = userValues.sorted(by: { pair1, pair2 in pair1.key <= pair2.key })
            let userValueBefore = (sorted.last(where: { dataPoint, _ in
                dataPoint <= value.intround
            }) ?? (key: dataPoint.min, value: MIN_BRIGHTNESS.i))
            let userValueAfter = (sorted.first(where: { dataPoint, _ in
                dataPoint > value.intround
            }) ?? (key: dataPoint.max, value: MAX_BRIGHTNESS.i))

            let builtinLow = userValueBefore.key.d
            let builtinHigh = userValueAfter.key.d
            let externalLow = userValueBefore.value.d
            let externalHigh = userValueAfter.value.d

            if builtinLow == builtinHigh || externalLow == externalHigh {
                newValue = externalLow
            } else {
                newValue = mapNumber(value, fromLow: builtinLow, fromHigh: builtinHigh, toLow: externalLow, toHigh: externalHigh)
                if key == .sensor {
                    newValue = adjustCurve(newValue, factor: 0.5, minVal: externalLow, maxVal: externalHigh)
                }
                newValue = adjustCurve(newValue, factor: curveFactor > 0 ? curveFactor : 1, minVal: externalLow, maxVal: externalHigh)
            }
            if newValue.isNaN {
                log.error(
                    "NaN value?? Whyy?? WHAT DID I DO??",
                    context: ["value": value, "minValue": minValue, "maxValue": maxValue, "monitorValue": monitorValue, "offset": offset]
                )
                newValue = cap(value, minVal: MIN_BRIGHTNESS.d, maxVal: MAX_BRIGHTNESS.d)
            }
        }

        newValue = cap(newValue + offset.d, minVal: MIN_BRIGHTNESS.d, maxVal: MAX_BRIGHTNESS.d)

        if newValue.isNaN {
            log.error(
                "NaN value?? WHAAT?? AGAIN?!",
                context: ["value": value, "minValue": minValue, "maxValue": maxValue, "monitorValue": monitorValue, "offset": offset]
            )
            newValue = cap(value, minVal: MIN_BRIGHTNESS.d, maxVal: MAX_BRIGHTNESS.d)
        }

        return mapNumber(
            newValue,
            fromLow: MIN_BRIGHTNESS.d,
            fromHigh: MAX_BRIGHTNESS.d,
            toLow: minValue,
            toHigh: maxValue
        )
    }

    func interpolate(
        values: inout [Int: Int],
        dataPoint: DataPoint,
        factor: Float = 1.0,
        offset: Float = 0.0
    ) -> [Double] {
        if values[dataPoint.max] == nil, !values.keys.contains(where: { $0 > dataPoint.max }) {
            values[dataPoint.max] = MAX_BRIGHTNESS.i
        }

        let sorted = values.sorted(by: { pair1, pair2 in pair1.key <= pair2.key })

        var result: [Float] = []
        var lastDataPoint: Float = 0
        var lastTargetValue: Float = 0

        for (dataPoint, targetValue) in sorted.map({ ($0.f, $1.f) }) {
            if dataPoint == 0 {
                lastDataPoint = dataPoint
                lastTargetValue = targetValue
                continue
            }

            let samples = (dataPoint - lastDataPoint).i
            guard samples > 0 else {
                result.append(targetValue)
                lastDataPoint = dataPoint
                lastTargetValue = targetValue
                continue
            }

            var control = ramp(
                targetValue: targetValue,
                lastTargetValue: &lastTargetValue,
                samples: samples
            )
            if key == .sensor {
                control = adjustCurveSIMD(control, factor: 0.4, minVal: lastTargetValue, maxVal: targetValue)
            }
            control = adjustCurveSIMD(control, factor: factor, minVal: lastTargetValue, maxVal: targetValue)
            result.append(contentsOf: control)

            lastDataPoint = dataPoint
            lastTargetValue = targetValue
        }

        if offset != 0 {
            result += offset
        }

        return result.d
    }
}

extension Array where Element == Float {
    @inline(__always) var d: [Double] {
        vDSP.floatToDouble(self)
    }
}

class AdaptiveModeMenuValidator: NSObject, NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let mode = AdaptiveModeKey(rawValue: menuItem.tag) else {
            return false
        }
        return mode.available
    }
}

let adaptiveModeMenuValidator = AdaptiveModeMenuValidator()
