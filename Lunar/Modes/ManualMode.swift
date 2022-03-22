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
    var maxChartDataPoints = 101

    var key = AdaptiveModeKey.manual

    @Atomic var watching = false

    var displayObservers = Set<AnyCancellable>()

    var available: Bool { true }
    var availableForOnboarding: Bool { true }

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
        guard displayController.adaptiveModeKey == .manual else { return }

        let lastAppPreset = display.appPreset
        var (brightness, contrast) = (display.brightness.intValue, display.contrast.intValue)

        if let (br, cr) = displayController.appBrightnessContrastOffset(for: display) {
            (brightness, contrast) = (br, cr)

            if lastAppPreset == nil {
                if CachedDefaults[.mergeBrightnessContrast] {
                    display.preciseBrightnessContrastBeforeAppPreset = display.preciseBrightnessContrast
                } else {
                    display.preciseBrightnessBeforeAppPreset = display.preciseBrightness
                    display.preciseContrastBeforeAppPreset = display.preciseContrast
                }
            }

            if display.ambientLightAdaptiveBrightnessEnabled {
                display.ambientLightAdaptiveBrightnessEnabled = false
            }
        } else if let lastAppPreset = lastAppPreset {
            if display.hasAmbientLightAdaptiveBrightness, !display.ambientLightAdaptiveBrightnessEnabled {
                display.ambientLightAdaptiveBrightnessEnabled = true
            }
            if lastAppPreset.reapplyPreviousBrightness {
                let br: Brightness
                let cr: Contrast
                if CachedDefaults[.mergeBrightnessContrast] {
                    (br, cr) = display.sliderValueToBrightnessContrast(display.preciseBrightnessContrastBeforeAppPreset)
                } else {
                    br = display.sliderValueToBrightness(display.preciseBrightnessBeforeAppPreset).uint16Value
                    cr = display.sliderValueToContrast(display.preciseContrastBeforeAppPreset).uint16Value
                }
                (brightness, contrast) = (br.i, cr.i)
            }
        }

        display.withForce(force || display.force) {
            #if DEBUG
                log.debug("Setting brightness to \(brightness) for \(display)")
                log.debug("Setting contrast to \(contrast) for \(display)")
            #endif
            mainThread {
                display.brightness = cap(brightness, minVal: display.minBrightness.intValue, maxVal: display.maxBrightness.intValue).ns
                display.contrast = cap(contrast, minVal: display.minContrast.intValue, maxVal: display.maxContrast.intValue).ns
            }
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
