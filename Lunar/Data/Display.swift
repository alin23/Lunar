//
//  Display.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Surge
import SwiftDate

let MIN_BRIGHTNESS: UInt8 = 0
let MAX_BRIGHTNESS: UInt8 = 100
let MIN_CONTRAST: UInt8 = 0
let MAX_CONTRAST: UInt8 = 100
let GENERIC_DISPLAY_ID: CGDirectDisplayID = 0
let TEST_DISPLAY_ID: CGDirectDisplayID = 2
let GENERIC_DISPLAY: Display = Display(id: GENERIC_DISPLAY_ID, serial: "GENERIC_SERIAL", name: "No Display", minBrightness: 0, maxBrightness: 100, minContrast: 0, maxContrast: 100, context: datastore.context)
let TEST_DISPLAY: Display = Display(id: TEST_DISPLAY_ID, serial: "TEST_SERIAL", name: "Test Display", active: true, minBrightness: 0, maxBrightness: 100, minContrast: 0, maxContrast: 100, context: datastore.context, adaptive: true)
let MAX_SMOOTH_STEP_TIME_NS: UInt64 = 10 * 1_000_000 // 10ms

enum ValueType {
    case brightness
    case contrast
}

class Display: NSManagedObject {
    @NSManaged var id: CGDirectDisplayID
    @NSManaged var serial: String
    @NSManaged var name: String
    @NSManaged var adaptive: Bool

    @NSManaged var lockedBrightness: Bool
    @NSManaged var lockedContrast: Bool

    @NSManaged var minBrightness: NSNumber
    @NSManaged var maxBrightness: NSNumber

    @NSManaged var minContrast: NSNumber
    @NSManaged var maxContrast: NSNumber

    @NSManaged var brightness: NSNumber
    @NSManaged var contrast: NSNumber

    var active: Bool = false
    var observers: [NSKeyValueObservation] = []
    var datastoreObservers: [NSKeyValueObservation] = []
    var onReadapt: (() -> Void)?
    var smoothStep = 1

    static func printableName(id: CGDirectDisplayID) -> String {
        if var name = DDC.getDisplayName(for: id) {
            name = name.stripped
            let minChars = floor(Double(name.count) * 0.8)
            if name.utf8.map({ c in (0x21 ... 0x7E).contains(c) ? 1 : 0 }).reduce(0, { $0 + $1 }) >= minChars {
                return name
            }
        }
        return lunarDisplayNames[Int(CGDisplayUnitNumber(id)) % lunarDisplayNames.count]
    }

    static func uuid(id: CGDirectDisplayID) -> String {
        if let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() {
            return CFUUIDCreateString(kCFAllocatorDefault, uuid) as String
        }
        if let edid = Display.edid(id: id) {
            return edid
        }
        return String(describing: id)
    }

    static func edid(id: CGDirectDisplayID) -> String? {
        return DDC.getEdidData(displayID: id)?.map { $0 }.str(hex: true)
    }

    convenience init(id: CGDirectDisplayID, serial: String? = nil, name: String? = nil, active: Bool = false, minBrightness: UInt8 = MIN_BRIGHTNESS, maxBrightness: UInt8 = MAX_BRIGHTNESS, minContrast: UInt8 = MIN_CONTRAST, maxContrast: UInt8 = MAX_CONTRAST, context: NSManagedObjectContext? = nil, adaptive: Bool = true) {
        let context = context ?? datastore.context
        let entity = NSEntityDescription.entity(forEntityName: "Display", in: context)!
        if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
            self.init(entity: entity, insertInto: context)
        } else {
            self.init(entity: entity, insertInto: nil)
        }
        self.id = id
        if let name = name, !name.isEmpty {
            self.name = name
        } else {
            self.name = Display.printableName(id: id)
        }
        self.serial = (serial ?? Display.uuid(id: id))
        self.active = active
        self.adaptive = adaptive
        lockedBrightness = false
        lockedContrast = false
        if id != GENERIC_DISPLAY_ID {
            self.minBrightness = NSNumber(value: minBrightness)
            self.maxBrightness = NSNumber(value: maxBrightness)
            self.minContrast = NSNumber(value: minContrast)
            self.maxContrast = NSNumber(value: maxContrast)
        }
    }

    func resetName() {
        name = Display.printableName(id: id)
    }

    func readapt<T>(display: Display, change: NSKeyValueObservedChange<T>) {
        if let readaptListener = onReadapt {
            readaptListener()
        }
        if let newVal = change.newValue as? NSNumber,
            let oldVal = change.oldValue as? NSNumber {
            if display.adaptive, newVal != oldVal {
                switch brightnessAdapter.mode {
                case .location:
                    display.adapt(moment: brightnessAdapter.moment)
                case .sync:
                    if let brightness = brightnessAdapter.getBuiltinDisplayBrightness() {
                        log.verbose("Builtin Display Brightness: \(brightness)")
                        display.adapt(percent: Double(brightness))
                    } else {
                        log.verbose("Can't get Builtin Display Brightness")
                    }
                default:
                    return
                }
            }
        }
    }

    func smoothTransition(from currentValue: UInt8, to value: UInt8, adjust: @escaping ((UInt8) -> Void)) {
        var steps = abs(value.distance(to: currentValue))

        var step: Int
        let minVal: UInt8
        let maxVal: UInt8
        if value < currentValue {
            step = cap(-smoothStep, minVal: -steps, maxVal: -1)
            minVal = value
            maxVal = currentValue
        } else {
            step = cap(smoothStep, minVal: 1, maxVal: steps)
            minVal = currentValue
            maxVal = value
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
            let startTime = DispatchTime.now()
            var elapsedTime: UInt64
            var elapsedSeconds: String

            adjust(UInt8(Int(currentValue) + step))

            elapsedTime = DispatchTime.now().rawValue - startTime.rawValue
            elapsedSeconds = String(format: "%.3f", Double(elapsedTime) / 1_000_000_000.0)
            log.debug("It took \(elapsedTime)ns (\(elapsedSeconds)s) to change brightness by \(step)")

            steps = steps - abs(step)
            if steps <= 0 {
                adjust(value)
                return
            }

            self.smoothStep = cap(Int(elapsedTime / MAX_SMOOTH_STEP_TIME_NS), minVal: 1, maxVal: 100)
            if value < currentValue {
                step = cap(-self.smoothStep, minVal: -steps, maxVal: -1)
            } else {
                step = cap(self.smoothStep, minVal: 1, maxVal: steps)
            }

            for newValue in stride(from: Int(currentValue), through: Int(value), by: step) {
                adjust(cap(UInt8(newValue), minVal: minVal, maxVal: maxVal))
            }
            adjust(value)

            elapsedTime = DispatchTime.now().rawValue - startTime.rawValue
            elapsedSeconds = String(format: "%.3f", Double(elapsedTime) / 1_000_000_000.0)
            log.debug("It took \(elapsedTime)ns (\(elapsedSeconds)s) to change brightness from \(currentValue) to \(value) by \(step)")
        }
    }

    func addObservers() {
        datastoreObservers = [
            datastore.defaults.observe(\UserDefaults.brightnessLimitMin, options: [.new, .old], changeHandler: { _, v in self.readapt(display: self, change: v) }),
            datastore.defaults.observe(\UserDefaults.brightnessLimitMax, options: [.new, .old], changeHandler: { _, v in self.readapt(display: self, change: v) }),
            datastore.defaults.observe(\UserDefaults.contrastLimitMin, options: [.new, .old], changeHandler: { _, v in self.readapt(display: self, change: v) }),
            datastore.defaults.observe(\UserDefaults.contrastLimitMax, options: [.new, .old], changeHandler: { _, v in self.readapt(display: self, change: v) }),
        ]
        observers = [
            observe(\.minBrightness, options: [.new, .old], changeHandler: { _, v in
                self.readapt(display: self, change: v)
                datastore.save()
            }),
            observe(\.maxBrightness, options: [.new, .old], changeHandler: { _, v in
                self.readapt(display: self, change: v)
                datastore.save()
            }),
            observe(\.minContrast, options: [.new, .old], changeHandler: { _, v in
                self.readapt(display: self, change: v)
                datastore.save()
            }),
            observe(\.maxContrast, options: [.new, .old], changeHandler: { _, v in
                self.readapt(display: self, change: v)
                datastore.save()
            }),
            observe(\.brightness, options: [.new, .old], changeHandler: { _, change in
                if let newBrightness = change.newValue, self.id != GENERIC_DISPLAY_ID, self.id != TEST_DISPLAY_ID {
                    var brightness: UInt8
                    if brightnessAdapter.mode == AdaptiveMode.manual {
                        brightness = cap(newBrightness.uint8Value, minVal: 0, maxVal: 100)
                    } else {
                        brightness = cap(newBrightness.uint8Value, minVal: self.minBrightness.uint8Value, maxVal: self.maxBrightness.uint8Value)
                    }
                    let currentValue = change.oldValue!.uint8Value

                    if datastore.defaults.smoothTransition {
                        self.smoothTransition(from: currentValue, to: brightness) { newValue in
                            _ = DDC.setBrightness(for: self.id, brightness: newValue)
                        }
                    } else {
                        _ = DDC.setBrightness(for: self.id, brightness: brightness)
                    }

                    log.debug("\(self.name): Set brightness to \(brightness) for \(self.serial):\(self.id)")
                }
            }),
            observe(\.contrast, options: [.new, .old], changeHandler: { _, change in
                if let newContrast = change.newValue, self.id != GENERIC_DISPLAY_ID, self.id != TEST_DISPLAY_ID {
                    var contrast: UInt8
                    if brightnessAdapter.mode == AdaptiveMode.manual {
                        contrast = cap(newContrast.uint8Value, minVal: 0, maxVal: 100)
                    } else {
                        contrast = cap(newContrast.uint8Value, minVal: self.minContrast.uint8Value, maxVal: self.maxContrast.uint8Value)
                    }
                    let currentValue = change.oldValue!.uint8Value

                    if datastore.defaults.smoothTransition {
                        self.smoothTransition(from: currentValue, to: contrast) { newValue in
                            _ = DDC.setContrast(for: self.id, contrast: newValue)
                        }
                    } else {
                        _ = DDC.setContrast(for: self.id, contrast: contrast)
                    }

                    log.debug("\(self.name): Set contrast to \(contrast)")
                }
            }),
        ]
    }

    func removeObservers() {
        observers.removeAll(keepingCapacity: true)
        datastoreObservers.removeAll(keepingCapacity: true)
    }

    func getMinMaxFactor(type: ValueType, offset: Int? = nil, factor: Double? = nil, minVal: Double? = nil, maxVal: Double? = nil) -> (Double, Double, Double) {
        let minValue: Double
        let maxValue: Double
        let offsetValue: Int
        if type == .brightness {
            maxValue = maxVal ?? maxBrightness.doubleValue
            minValue = minVal ?? minBrightness.doubleValue
            offsetValue = offset ?? datastore.defaults.brightnessOffset
        } else {
            maxValue = maxVal ?? maxContrast.doubleValue
            minValue = minVal ?? minContrast.doubleValue
            offsetValue = offset ?? datastore.defaults.contrastOffset
        }

        guard let factor = factor else {
            var factor = 1.0
            if offsetValue > 0 {
                factor = 1.0 - (Double(offsetValue) / 100.0)
            } else if offsetValue < 0 {
                factor = 1.0 - (Double(offsetValue) / 10.0)
            }
            return (minValue, maxValue, factor)
        }
        return (minValue, maxValue, factor)
    }

    func computeValue(from percent: Double, type: ValueType, offset: Int? = nil, factor: Double? = nil, appOffset: Int = 0, minVal: Double? = nil, maxVal: Double? = nil) -> NSNumber {
        let (minValue, maxValue, factor) = getMinMaxFactor(type: type, offset: offset, factor: factor, minVal: minVal, maxVal: maxVal)

        var value = pow((percent * (maxValue - minValue) + minValue) / 100.0, factor) * 100.0
        value = cap(value, minVal: minValue, maxVal: maxValue)

        if appOffset > 0 {
            value = cap(value + Double(appOffset), minVal: minValue, maxVal: maxValue)
        }
        return NSNumber(value: value)
    }

    func computeSIMDValue(from percent: [Double], type: ValueType, offset: Int? = nil, factor: Double? = nil, appOffset: Int = 0, minVal: Double? = nil, maxVal: Double? = nil) -> [NSNumber] {
        let (minValue, maxValue, factor) = getMinMaxFactor(type: type, offset: offset, factor: factor, minVal: minVal, maxVal: maxVal)

        var value = (percent * (maxValue - minValue) + minValue)
        value /= 100.0
        value = pow(value, factor)

        value = (value * 100.0 + Double(appOffset))
        return value.map {
            b in NSNumber(value: cap(b, minVal: minValue, maxVal: maxValue))
        }
    }

    func getBrightnessContrast(
        moment: Moment,
        hour: Int? = nil,
        minute: Int = 0,
        factor: Double? = nil,
        minBrightness: UInt8? = nil,
        maxBrightness: UInt8? = nil,
        minContrast: UInt8? = nil,
        maxContrast: UInt8? = nil,
        daylightExtension: Int? = nil,
        noonDuration: Int? = nil,
        appBrightnessOffset: Int = 0,
        appContrastOffset: Int = 0
    ) -> (NSNumber, NSNumber) {
        var now = DateInRegion().convertTo(region: Region.local)
        if let hour = hour {
            now = now.dateBySet(hour: hour, min: minute, secs: 0)!
        }
        let seconds = 60.0
        let minBrightness = minBrightness ?? self.minBrightness.uint8Value
        let maxBrightness = maxBrightness ?? self.maxBrightness.uint8Value
        let minContrast = minContrast ?? self.minContrast.uint8Value
        let maxContrast = maxContrast ?? self.maxContrast.uint8Value
        var newBrightness = NSNumber(value: minBrightness)
        var newContrast = NSNumber(value: minContrast)
        let daylightExtension = daylightExtension ?? datastore.defaults.daylightExtensionMinutes
        let noonDuration = noonDuration ?? datastore.defaults.noonDurationMinutes

        let daylightStart = moment.sunrise - daylightExtension.minutes
        let daylightEnd = moment.sunset + daylightExtension.minutes

        let noonStart = moment.solarNoon - (noonDuration / 2).minutes
        let noonEnd = moment.solarNoon + (noonDuration / 2).minutes

        switch now {
        case daylightStart ... noonStart:
            let firstHalfDayMinutes = ((noonStart - daylightStart) / seconds)
            let minutesSinceSunrise = ((now - daylightStart) / seconds)
            let percent = (minutesSinceSunrise / firstHalfDayMinutes)
            newBrightness = computeValue(
                from: percent, type: .brightness,
                factor: factor ?? datastore.defaults.curveFactor, appOffset: appBrightnessOffset,
                minVal: Double(minBrightness), maxVal: Double(maxBrightness)
            )
            newContrast = computeValue(
                from: percent, type: .contrast,
                factor: factor ?? datastore.defaults.curveFactor, appOffset: appContrastOffset,
                minVal: Double(minContrast), maxVal: Double(maxContrast)
            )
        case noonEnd ... daylightEnd:
            let secondHalfDayMinutes = ((daylightEnd - noonEnd) / seconds)
            let minutesSinceNoon = ((now - noonEnd) / seconds)
            let percent = ((secondHalfDayMinutes - minutesSinceNoon) / secondHalfDayMinutes)
            newBrightness = computeValue(
                from: percent, type: .brightness,
                factor: factor ?? datastore.defaults.curveFactor, appOffset: appBrightnessOffset,
                minVal: Double(minBrightness), maxVal: Double(maxBrightness)
            )
            newContrast = computeValue(
                from: percent, type: .contrast,
                factor: factor ?? datastore.defaults.curveFactor, appOffset: appContrastOffset,
                minVal: Double(minContrast), maxVal: Double(maxContrast)
            )
        case noonStart ... noonEnd:
            newBrightness = NSNumber(value: maxBrightness)
            newContrast = NSNumber(value: maxContrast)
        default:
            newBrightness = NSNumber(value: minBrightness)
            newContrast = NSNumber(value: minContrast)
        }

        if appBrightnessOffset > 0 {
            newBrightness = NSNumber(value: min(newBrightness.doubleValue + Double(appBrightnessOffset), Double(MAX_BRIGHTNESS)))
        }
        if appContrastOffset > 0 {
            newContrast = NSNumber(value: min(newContrast.doubleValue + Double(appContrastOffset), Double(MAX_CONTRAST)))
        }
        return (newBrightness, newContrast)
    }

    func getBrightnessContrastBatch(
        moment: Moment,
        minutesBetween: Int = 0,
        factor: Double? = nil,
        minBrightness: UInt8? = nil,
        maxBrightness: UInt8? = nil,
        minContrast: UInt8? = nil,
        maxContrast: UInt8? = nil,
        daylightExtension: Int? = nil,
        noonDuration: Int? = nil,
        appBrightnessOffset: Int = 0,
        appContrastOffset: Int = 0
    ) -> [(NSNumber, NSNumber)] {
        let step = 60 / minutesBetween
        var times = [Double]()
        times.reserveCapacity(24 * minutesBetween)

        let now = DateInRegion().convertTo(region: Region.local)
        for hour in 0 ..< 24 {
            times.append(contentsOf: stride(from: 0, through: 59, by: step).map {
                m in now.dateBySet(hour: hour, min: m, secs: 0)!.timeIntervalSince1970
            })
        }

        let seconds = 60.0

        let minBrightness = minBrightness ?? self.minBrightness.uint8Value
        let maxBrightness = maxBrightness ?? self.maxBrightness.uint8Value
        let minContrast = minContrast ?? self.minContrast.uint8Value
        let maxContrast = maxContrast ?? self.maxContrast.uint8Value
        let daylightExtension = daylightExtension ?? datastore.defaults.daylightExtensionMinutes
        let noonDuration = noonDuration ?? datastore.defaults.noonDurationMinutes

        let daylightStart = moment.sunrise - daylightExtension.minutes
        let daylightEnd = moment.sunset + daylightExtension.minutes
        let daylightStartSeconds = daylightStart.timeIntervalSince1970
        let daylightEndSeconds = daylightEnd.timeIntervalSince1970

        let noonStart = moment.solarNoon - (noonDuration / 2).minutes
        let noonEnd = moment.solarNoon + (noonDuration / 2).minutes
        let noonStartSeconds = noonStart.timeIntervalSince1970
        let noonEndSeconds = noonEnd.timeIntervalSince1970

        let firstHalfDayMinutes = ((noonStartSeconds - daylightStartSeconds) / seconds)
        let secondHalfDayMinutes = ((daylightEndSeconds - noonEndSeconds) / seconds)

        let maxNSBrightness = NSNumber(value: maxBrightness)
        let maxNSContrast = NSNumber(value: maxContrast)
        let minNSBrightness = NSNumber(value: min(minBrightness + UInt8(appBrightnessOffset), MAX_BRIGHTNESS))
        let minNSContrast = NSNumber(value: min(minContrast + UInt8(appContrastOffset), MAX_CONTRAST))

        let maxBrightnessDouble = Double(maxBrightness)
        let maxContrastDouble = Double(maxContrast)
        let minBrightnessDouble = Double(minBrightness)
        let minContrastDouble = Double(minContrast)

        var brightnessContrast = [(NSNumber, NSNumber)](repeating: (minNSBrightness, minNSContrast), count: 25 * minutesBetween)
        let noonStartIndex = times.firstIndex { s in s >= noonStartSeconds }
        let noonEndIndex = times.lastIndex { s in s <= noonEndSeconds }
        if let start = noonStartIndex, let end = noonEndIndex, start < end {
            let noonValues = [(NSNumber, NSNumber)](repeating: (maxNSBrightness, maxNSContrast), count: (end - start) + 1)
            brightnessContrast.replaceSubrange(
                start ... end, with: noonValues
            )
        }

        let daylightStartIndex = times.firstIndex { s in s >= daylightStartSeconds } ?? 0
        let daylightEndIndex = times.lastIndex { s in s <= daylightEndSeconds } ?? (brightnessContrast.count - 1)

        let firstHalf = (daylightStartIndex ..< (noonStartIndex ?? daylightStartIndex))
        var values = Array(times[firstHalf])
        let minutesSinceSunrise = ((values - Double(daylightStartSeconds)) / seconds)
        var percent = (minutesSinceSunrise / firstHalfDayMinutes)

        brightnessContrast.replaceSubrange(
            firstHalf,
            with: zip(
                computeSIMDValue(
                    from: percent, type: .brightness, factor: factor ?? datastore.defaults.curveFactor,
                    appOffset: appBrightnessOffset, minVal: minBrightnessDouble, maxVal: maxBrightnessDouble
                ),
                computeSIMDValue(
                    from: percent, type: .contrast, factor: factor ?? datastore.defaults.curveFactor,
                    appOffset: appContrastOffset, minVal: minContrastDouble, maxVal: maxContrastDouble
                )
            ).map { ($0, $1) }
        )

        let secondHalf = ((noonEndIndex ?? daylightEndIndex) - 1) ..< daylightEndIndex + 1
        values = Array(times[secondHalf])
        let minutesSinceNoon = ((values - noonEndSeconds) / seconds)
        percent = (abs(minutesSinceNoon - secondHalfDayMinutes) / secondHalfDayMinutes)

        brightnessContrast.replaceSubrange(
            secondHalf,
            with: zip(
                computeSIMDValue(
                    from: percent, type: .brightness, factor: factor ?? datastore.defaults.curveFactor,
                    appOffset: appBrightnessOffset, minVal: minBrightnessDouble, maxVal: maxBrightnessDouble
                ),
                computeSIMDValue(
                    from: percent, type: .contrast, factor: factor ?? datastore.defaults.curveFactor,
                    appOffset: appContrastOffset, minVal: minContrastDouble, maxVal: maxContrastDouble
                )
            ).map { ($0, $1) }
        )

        return brightnessContrast
    }

    func adapt(moment: Moment? = nil, app: AppException? = nil, percent: Double? = nil) {
        if !adaptive {
            return
        }

        var newBrightness: NSNumber = 0
        var newContrast: NSNumber = 0
        if let moment = moment {
            (newBrightness, newContrast) = getBrightnessContrast(moment: moment, appBrightnessOffset: app?.brightness.intValue ?? 0, appContrastOffset: app?.contrast.intValue ?? 0)
        } else if let percent = percent {
            let percent = percent / 100.0
            newBrightness = computeValue(from: percent, type: .brightness, appOffset: app?.brightness.intValue ?? 0)
            newContrast = computeValue(from: percent, type: .contrast, appOffset: app?.contrast.intValue ?? 0)
        }

        var changed = false
        if !lockedBrightness, brightness != newBrightness {
            setValue(newBrightness, forKey: "brightness")
            changed = true
        }

        if !lockedContrast, contrast != newContrast {
            setValue(newContrast, forKey: "contrast")
            changed = true
        }
        if changed {
            log.info("\n\(name):\n\tBrightness: \(newBrightness)\n\tContrast: \(newContrast)")
        }
    }
}
