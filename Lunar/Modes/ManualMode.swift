//
//  ManualMode.swift
//  Lunar
//
//  Created by Alin Panaitiu on 30.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Foundation
import Surge

class ManualMode: AdaptiveMode {
    var force = false
    var brightnessDataPoint = DataPoint(min: 0, max: 100, last: 0)
    var contrastDataPoint = DataPoint(min: 0, max: 100, last: 0)
    var maxChartDataPoints: Int = 101

    static let shared: AdaptiveMode = ManualMode()
    static var specific = shared as! ManualMode

    var key = AdaptiveModeKey.manual

    var available: Bool { true }
    var watching = false

    func stopWatching() {
        guard watching else { return }
        for display in displayController.displays.values {
            display.resetObserver(prop: .brightness, key: "manual-mode", type: NSNumber.self)
            display.resetObserver(prop: .contrast, key: "manual-mode", type: NSNumber.self)
        }
        watching = false
    }

    func watch() -> Bool {
        guard !watching else { return false }
        for display in displayController.displays.values {
            display.setObserver(prop: .brightness, key: "manual-mode", action: { (value: NSNumber, _: NSNumber) in
                NotificationCenter.default.post(name: currentDataPointChanged, object: display, userInfo: ["brightness": value])
            })
            display.setObserver(prop: .contrast, key: "manual-mode", action: { (value: NSNumber, _: NSNumber) in
                NotificationCenter.default.post(name: currentDataPointChanged, object: display, userInfo: ["contrast": value])
            })
        }
        watching = true
        return true
    }

    func adapt(_ display: Display) {
        display.withForce(force || display.force.load(ordering: .relaxed)) {
            display.brightness = display.brightness.uint8Value.ns
            display.contrast = display.contrast.uint8Value.ns
        }
    }

    func compute(percent: Int8, minVal: Int, maxVal: Int) -> NSNumber {
        let percent = cap(percent, minVal: 0, maxVal: 100).d / 100.0
        let value = round(percent * (maxVal - minVal).d).i + minVal
        return (cap(value, minVal: minVal, maxVal: maxVal)).ns
    }

    func computeSIMD(from percent: [Double], minVal: Double, maxVal: Double) -> [Double] {
        percent * (maxVal - minVal) + minVal
    }
}
