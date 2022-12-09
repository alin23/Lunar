//
//  Schedule.swift
//  Lunar
//
//  Created by Alin Panaitiu on 18.09.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Combine
import Defaults
import SwiftDate

// MARK: - ScheduleType

enum ScheduleType: Int, CaseIterable, Codable, Defaults.Serializable {
    case disabled = -1
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
    let brightness: PreciseBrightness
    let contrast: PreciseContrast
    let negative: Bool

    var enabled: Bool { type != .disabled }

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
            brightness: dict["brightness"] as! Double,
            contrast: dict["contrast"] as! Double,
            negative: dict["negative"] as! Bool
        )
    }

    func getHourMinute(withOffset: Bool = true) -> (UInt8, UInt8)? {
        var hour: UInt8
        var minute: UInt8

        switch type {
        case .disabled:
            return nil
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
        brightness: Double? = nil,
        contrast: Double? = nil,
        negative: Bool? = nil
    ) -> Self {
        BrightnessSchedule(
            type: type ?? self.type,
            hour: hour ?? self.hour,
            minute: minute ?? self.minute,
            brightness: brightness ?? self.brightness,
            contrast: contrast ?? self.contrast,
            negative: negative ?? self.negative
        )
    }
}

// MARK: - Schedule

// @IBDesignable
class Schedule: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

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
    @IBOutlet var signButton: ToggleButton!
    @IBOutlet var box: NSBox!

    @IBOutlet var dropdown: NSPopUpButton!
    @IBInspectable dynamic var title = "Schedule 1"
    @IBInspectable dynamic var number = 1
    @objc dynamic lazy var isTimeSchedule = type == ScheduleType.time.rawValue
    @objc dynamic lazy var enabled: Bool = type != ScheduleType.disabled.rawValue

    var lastType: Int = ScheduleType.time.rawValue
    var observers: Set<AnyCancellable> = []

    var hover = false

    var schedule: BrightnessSchedule? {
        get { display?.schedules[number - 1] }
        set {
            guard let display, let newValue else { return }
            display.schedules[number - 1] = newValue
            display.save()
        }
    }

    @objc dynamic var preciseBrightnessContrast: Double {
        get {
            guard let display, let schedule else {
                return 0.5
            }

            return display.brightnessToSliderValue(schedule.brightness.ns)
        }
        set {
            guard let display, let schedule else {
                return
            }
            let (brightness, contrast) = display.sliderValueToBrightnessContrast(newValue)
            self.schedule = schedule.with(brightness: brightness.d, contrast: contrast.d)
            display.save()
        }
    }

    @objc dynamic var preciseBrightness: Double {
        get {
            guard let display, let schedule else {
                return 0.5
            }

            return display.brightnessToSliderValue(schedule.brightness.ns)
        }
        set {
            guard let display, let schedule else {
                return
            }
            let brightness = display.sliderValueToBrightness(newValue)
            self.schedule = schedule.with(brightness: brightness.doubleValue)
            display.save()
        }
    }

    @objc dynamic var preciseContrast: Double {
        get {
            guard let display, let schedule else {
                return 0.5
            }

            return display.contrastToSliderValue(schedule.contrast.ns, merged: CachedDefaults[.mergeBrightnessContrast])
        }
        set {
            guard let display, let schedule else {
                return
            }

            let contrast = display.sliderValueToContrast(newValue)
            self.schedule = schedule.with(contrast: contrast.doubleValue)
            display.save()
        }
    }

    @objc dynamic var negativeState = NSControl.StateValue.off {
        didSet {
            guard let display, let schedule = display.schedules.prefix(number).last
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
            guard let display, let schedule = display.schedules.prefix(number).last
            else {
                return
            }
            lastType = oldValue
            enabled = type != ScheduleType.disabled.rawValue

            isTimeSchedule = type == ScheduleType.time.rawValue

            let scheduleType = ScheduleType(rawValue: type) ?? .time
            var hour: UInt8 = schedule.hour
            var minute: UInt8 = schedule.minute

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
            case .disabled:
                break
            }
            box?.alphaValue = (scheduleType == .disabled) ? 0.8 : 1.0

            let newSchedule = schedule.with(type: scheduleType, hour: hour, minute: minute)
            display.schedules[number - 1] = newSchedule
            display.save()
            setTimeValues(from: newSchedule)
        }
    }

    weak var display: Display? {
        didSet {
            guard let display else {
                return
            }

            guard let schedule = display.schedules.prefix(number).last else {
                return
            }

            setTempValues(from: schedule)

            if CachedDefaults[.mergeBrightnessContrast] {
                preciseBrightnessContrast = display.brightnessToSliderValue(schedule.brightness.ns)
            } else {
                preciseBrightness = display.brightnessToSliderValue(schedule.brightness.ns)
                preciseContrast = display.contrastToSliderValue(schedule.contrast.ns, merged: CachedDefaults[.mergeBrightnessContrast])
            }

            hour.integerValue = schedule.hour.i
            minute.integerValue = schedule.minute.i
            type = schedule.type.rawValue
            negativeState = schedule.negative ? .on : .off
            dropdown.selectItem(withTag: schedule.type.rawValue)

            hour.onValueChanged = { [weak self] value in
                guard let self, let display = self.display,
                      let schedule = display.schedules.prefix(self.number).last,
                      schedule.enabled
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
                case .disabled:
                    break
                }
            }
            minute.onValueChanged = { [weak self] value in
                guard let self, let display = self.display,
                      let schedule = display.schedules.prefix(self.number).last,
                      schedule.enabled
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
                case .disabled:
                    break
                }
            }
        }
    }

    @IBInspectable var alpha: CGFloat = 0.1 {
        didSet {
            fade()
        }
    }

    @IBInspectable var hoverAlpha: CGFloat = 0.3 {
        didSet {
            fade()
        }
    }

    override var frame: NSRect {
        didSet { trackHover() }
    }

    override var isHidden: Bool {
        didSet {
            trackHover()
            hover = false
            fade()
        }
    }

    @objc dynamic var isEnabled = true {
        didSet { fade() }
    }

    @objc func useCurrentBrightness() {
        guard let display else {
            return
        }
        if CachedDefaults[.mergeBrightnessContrast] {
            preciseBrightnessContrast = display.brightnessToSliderValue(display.brightness)
        } else {
            preciseBrightness = display.brightnessToSliderValue(display.brightness)
            preciseContrast = display.contrastToSliderValue(display.contrast, merged: CachedDefaults[.mergeBrightnessContrast])
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
        case .disabled:
            break
        }
    }

    func addObservers() {
        mergeBrightnessContrastPublisher.sink { [weak self] change in
            guard let self, let display = self.display else { return }
            if change.newValue {
                self.preciseBrightnessContrast = display.brightnessToSliderValue(display.brightness)
            } else {
                self.preciseBrightness = display.brightnessToSliderValue(display.brightness)
                self.preciseContrast = display.contrastToSliderValue(display.contrast, merged: change.newValue)
            }
        }.store(in: &observers)

        showTwoSchedulesPublisher.sink { [weak self] change in
            guard let self else { return }
            if self.number == 2 {
                self.isEnabled = change.newValue
            }
        }.store(in: &observers)
        showThreeSchedulesPublisher.sink { [weak self] change in
            guard let self else { return }
            if self.number == 3 {
                self.isEnabled = change.newValue
            }
        }.store(in: &observers)
        showFourSchedulesPublisher.sink { [weak self] change in
            guard let self else { return }
            if self.number == 4 {
                self.isEnabled = change.newValue
            }
        }.store(in: &observers)
        showFiveSchedulesPublisher.sink { [weak self] change in
            guard let self else { return }
            if self.number == 5 {
                self.isEnabled = change.newValue
            }
        }.store(in: &observers)
    }

    func setup() {
        let view: NSView?
        view = NSView.loadFromNib(withName: nibName, for: self)

        guard let view else { return }

        addObservers()

        alphaValue = isEnabled ? 1.0 : alpha
        trackHover()

        view.frame = bounds
        addSubview(view)
        signButton?.page = darkMode ? .hotkeys : .display
//        dropdown?.page = darkMode ? .hotkeys : .display
        for item in dropdown.itemArray {
            guard let type = ScheduleType(rawValue: item.tag) else { continue }
            switch type {
            case .noon:
                guard let moment = LocationMode.specific.moment?.solarNoon else { continue }
                let momentString = moment.toString(.time(.short))
                item.title = "Noon (\(momentString))"
            case .sunrise:
                guard let moment = LocationMode.specific.moment?.sunrise else { continue }
                let momentString = moment.toString(.time(.short))
                item.title = "Sunrise (\(momentString))"
            case .sunset:
                guard let moment = LocationMode.specific.moment?.sunset else { continue }
                let momentString = moment.toString(.time(.short))
                item.title = "Sunset (\(momentString))"
            default:
                break
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    func fade() {
        mainThread {
            if isHidden || isEnabled {
                transition(0.4)
                alphaValue = 1.0
                return
            }

            if hover {
                transition(0.4)
                alphaValue = hoverAlpha
            } else {
                transition(0.8)
                alphaValue = alpha
            }
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if isHidden || isEnabled { return }
        hover = true

        fade()
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        if isHidden || isEnabled {
            hover = false
            return
        }
        hover = false

        fade()
        super.mouseExited(with: event)
    }
}
