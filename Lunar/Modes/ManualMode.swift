//
//  ManualMode.swift
//  Lunar
//
//  Created by Alin Panaitiu on 30.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Combine
import Foundation
import Surge

class ManualMode: AdaptiveMode {
    static let shared: AdaptiveMode = ManualMode()
    static var specific = shared as! ManualMode

    @Atomic var force = false
    var brightnessDataPoint = DataPoint(min: 0, max: 100, last: 0)
    var contrastDataPoint = DataPoint(min: 0, max: 100, last: 0)
    var maxChartDataPoints: Int = 101

    var key = AdaptiveModeKey.manual

    @Atomic var watching = false

    var displayObservers = Set<AnyCancellable>()

    var available: Bool { true }

    func stopWatching() {
        guard watching else { return }
        log.verbose("Stop watching \(str)")

        for observer in displayObservers {
            observer.cancel()
        }
        displayObservers.removeAll()

        watching = false
    }

    func watch() {
        guard !watching else { return }
        log.verbose("Start watching \(str)")

        watching = true
    }

    func adapt(_ display: Display) {
        // display.withoutDDCLimits {
        display.withForce(force || display.force) {
            #if DEBUG
                log.debug("Setting brightness to \(display.brightness) for \(display)")
            #endif
            display.brightness = display.brightness.uint8Value.ns

            #if DEBUG
                log.debug("Setting contrast to \(display.contrast) for \(display)")
            #endif
            display.contrast = display.contrast.uint8Value.ns
        }
        // }
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
