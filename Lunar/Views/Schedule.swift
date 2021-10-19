//
//  Schedule.swift
//  Lunar
//
//  Created by Alin Panaitiu on 18.09.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Defaults
import SwiftDate

// MARK: - ScheduleTransition

enum ScheduleTransition: Int, CaseIterable, Defaults.Serializable {
    case none
    case minutes30
    case full
}

// MARK: - ScheduleType

enum ScheduleType: Int, CaseIterable, Codable, Defaults.Serializable {
    case time = 0
    case sunrise = 1
    case sunset = 2
    case noon = 3
}

// MARK: - BrightnessSchedule

struct BrightnessSchedule: Codable, Defaults.Serializable, Comparable {
    let type: ScheduleType
    let hour: UInt8
    let minute: UInt8
    let brightness: Brightness
    let contrast: Contrast
    let negative: Bool
    let enabled: Bool

    var dateInRegion: DateInRegion? {
        guard let (hour, minute) = getHourMinute() else { return nil }
        return DateInRegion().convertTo(region: Region.local).dateBySet(hour: hour.i, min: minute.i, secs: 0)
    }

    static func < (lhs: BrightnessSchedule, rhs: BrightnessSchedule) -> Bool {
        guard let date1 = lhs.dateInRegion, let date2 = rhs.dateInRegion else {
            return lhs.dateInRegion == nil
        }
        return date1 < date2
    }

    static func from(dict: [String: Any]) -> Self {
        BrightnessSchedule(
            type: ScheduleType(rawValue: dict["type"] as! Int) ?? .time,
            hour: dict["hour"] as! UInt8,
            minute: dict["minute"] as! UInt8,
            brightness: dict["brightness"] as! UInt8,
            contrast: dict["contrast"] as! UInt8,
            negative: dict["negative"] as! Bool,
            enabled: dict["enabled"] as! Bool
        )
    }

    func getHourMinute(withOffset: Bool = true) -> (UInt8, UInt8)? {
        var hour: UInt8
        var minute: UInt8

        switch type {
        case .time:
            hour = self.hour
            minute = self.minute
        case .sunrise, .sunset, .noon:
            guard let moment = LocationMode.specific.moment else {
                log.debug("Day moments aren't fetched yet")
                return nil
            }
            if withOffset {
                let momentWithOffset = moment.offset(type, with: self)
                hour = momentWithOffset.hour.u8
                minute = momentWithOffset.minute.u8
            } else {
                let momentWithoutOffset = moment.moment(type)
                hour = momentWithoutOffset.hour.u8
                minute = momentWithoutOffset.minute.u8
            }
        }
        return (hour, minute)
    }

    func with(
        type: ScheduleType? = nil,
        hour: UInt8? = nil,
        minute: UInt8? = nil,
        brightness: UInt8? = nil,
        contrast: UInt8? = nil,
        negative: Bool? = nil,
        enabled: Bool? = nil
    ) -> Self {
        BrightnessSchedule(
            type: type ?? self.type,
            hour: hour ?? self.hour,
            minute: minute ?? self.minute,
            brightness: brightness ?? self.brightness,
            contrast: contrast ?? self.contrast,
            negative: negative ?? self.negative,
            enabled: enabled ?? self.enabled
        )
    }
}

// MARK: - Schedule

// @IBDesignable
class Schedule: NSView {
    // MARK: Lifecycle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Internal

    var sunriseOffsetHour: UInt8 = 0
    var sunriseOffsetMinute: UInt8 = 0
    var sunsetOffsetHour: UInt8 = 0
    var sunsetOffsetMinute: UInt8 = 0
    var noonOffsetHour: UInt8 = 0
    var noonOffsetMinute: UInt8 = 0
    var timeHour: UInt8 = 12
    var timeMinute: UInt8 = 0

    let nibName = "Schedule"
    @IBOutlet var hour: ScrollableTextField!
    @IBOutlet var minute: ScrollableTextField!
    @IBOutlet var brightness: ScrollableTextField!
    @IBOutlet var contrast: ScrollableTextField!
    @IBOutlet var signButton: ToggleButton!
    @IBOutlet var box: NSBox!
    @IBOutlet var enableButton: LockButton!

    @IBOutlet var dropdown: PopUpButton!
    @IBInspectable dynamic var title = "Schedule 1"
    @IBInspectable dynamic var number = 1
    @objc dynamic lazy var isTimeSchedule = type == ScheduleType.time.rawValue

    @objc dynamic var enabled = false {
        didSet {
            guard let display = display, let schedule = display.schedules.prefix(number).last
            else {
                return
            }

            let newSchedule = schedule.with(enabled: enabled)
            display.schedules[number - 1] = newSchedule
            display.save()
            box?.alphaValue = enabled ? 1.0 : 0.2
            enableButton.layer?.shadowOpacity = enabled ? 0.7 : 0
        }
    }

    @objc dynamic var negativeState = NSControl.StateValue.off {
        didSet {
            guard let display = display, let schedule = display.schedules.prefix(number).last
            else {
                return
            }

            let newSchedule = schedule.with(negative: negativeState == .on)
            display.schedules[number - 1] = newSchedule
            display.save()
        }
    }

    @objc dynamic var type: Int = ScheduleType.time.rawValue {
        didSet {
            guard let display = display, let schedule = display.schedules.prefix(number).last
            else {
                return
            }

            isTimeSchedule = type == ScheduleType.time.rawValue

            let scheduleType = ScheduleType(rawValue: type) ?? .time
            var hour: UInt8
            var minute: UInt8

            switch scheduleType {
            case .time:
                hour = timeHour
                minute = timeMinute
            case .sunrise:
                hour = sunriseOffsetHour
                minute = sunriseOffsetMinute
            case .sunset:
                hour = sunsetOffsetHour
                minute = sunsetOffsetMinute
            case .noon:
                hour = noonOffsetHour
                minute = noonOffsetMinute
            }

            let newSchedule = schedule.with(type: scheduleType, hour: hour, minute: minute)
            display.schedules[number - 1] = newSchedule
            display.save()
            setTimeValues(from: newSchedule)
        }
    }

    weak var display: Display? {
        didSet {
            guard let display = display else {
                return
            }

            brightness.upperLimit = display.maxBrightness.doubleValue
            brightness.lowerLimit = display.minBrightness.doubleValue

            contrast.upperLimit = display.maxContrast.doubleValue
            contrast.lowerLimit = display.minContrast.doubleValue

            guard let schedule = display.schedules.prefix(number).last else {
                return
            }

            setTempValues(from: schedule)

            hour.integerValue = schedule.hour.i
            minute.integerValue = schedule.minute.i
            brightness.integerValue = schedule.brightness.i
            contrast.integerValue = schedule.contrast.i
            type = schedule.type.rawValue
            negativeState = schedule.negative ? .on : .off
            enabled = schedule.enabled
            dropdown.selectItem(withTag: schedule.type.rawValue)
            dropdown.resizeToFitTitle()

            hour.onValueChanged = { [weak self] value in
                guard let self = self, let display = self.display,
                      let schedule = display.schedules.prefix(self.number).last
                else { return }

                display.schedules[self.number - 1] = schedule.with(hour: value.u8)
                switch schedule.type {
                case .time:
                    self.timeHour = value.u8
                case .sunrise:
                    self.sunriseOffsetHour = value.u8
                case .sunset:
                    self.sunsetOffsetHour = value.u8
                case .noon:
                    self.noonOffsetHour = value.u8
                }
            }
            minute.onValueChanged = { [weak self] value in
                guard let self = self, let display = self.display,
                      let schedule = display.schedules.prefix(self.number).last
                else { return }

                display.schedules[self.number - 1] = schedule.with(minute: value.u8)
                switch schedule.type {
                case .time:
                    self.timeMinute = value.u8
                case .sunrise:
                    self.sunriseOffsetMinute = value.u8
                case .sunset:
                    self.sunsetOffsetMinute = value.u8
                case .noon:
                    self.noonOffsetMinute = value.u8
                }
            }
            brightness.onValueChanged = { [weak self] value in
                guard let self = self, let display = self.display,
                      let schedule = display.schedules.prefix(self.number).last
                else { return }

                display.schedules[self.number - 1] = schedule.with(brightness: value.u8)
            }
            contrast.onValueChanged = { [weak self] value in
                guard let self = self, let display = self.display,
                      let schedule = display.schedules.prefix(self.number).last
                else { return }

                display.schedules[self.number - 1] = schedule.with(contrast: value.u8)
            }
        }
    }

    func setTimeValues(from schedule: BrightnessSchedule) {
        hour.integerValue = schedule.hour.i
        minute.integerValue = schedule.minute.i
    }

    func setTempValues(from schedule: BrightnessSchedule) {
        switch schedule.type {
        case .time:
            timeHour = schedule.hour
            timeMinute = schedule.minute
        case .sunrise:
            sunriseOffsetHour = schedule.hour
            sunriseOffsetMinute = schedule.minute
        case .sunset:
            sunsetOffsetHour = schedule.hour
            sunsetOffsetMinute = schedule.minute
        case .noon:
            noonOffsetHour = schedule.hour
            noonOffsetMinute = schedule.minute
        }
    }

    func setup() {
        let view: NSView?
        view = NSView.loadFromNib(withName: nibName, for: self)

        guard let view = view else { return }

        view.frame = bounds
        addSubview(view)
        signButton?.page = darkMode ? .hotkeys : .display
        dropdown?.page = darkMode ? .hotkeys : .display
        for item in dropdown.itemArray {
            guard let type = ScheduleType(rawValue: item.tag) else { continue }
            switch type {
            case .noon:
                guard let moment = LocationMode.specific.moment?.solarNoon else { continue }
                item.title = "Noon (\(moment.toString(.time(.short))))"
            case .sunrise:
                guard let moment = LocationMode.specific.moment?.sunrise else { continue }
                item.title = "Sunrise (\(moment.toString(.time(.short))))"
            case .sunset:
                guard let moment = LocationMode.specific.moment?.sunset else { continue }
                item.title = "Sunset (\(moment.toString(.time(.short))))"
            default:
                break
            }
        }
        dropdown?.resizeToFitTitle()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
