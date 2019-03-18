//
//  SettingsPageController.swift
//  Lunar
//
//  Created by Alin on 21/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Charts
import Cocoa

class SettingsPageController: NSViewController {
    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView!
    var adaptiveModeObserver: NSKeyValueObservation?
    var pageController: NSPageController?

    func updateDataset(
        display: Display,
        factor: Double? = nil,
        daylightExtension: Int? = nil,
        noonDuration: Int? = nil,
        brightnessOffset: Int? = nil,
        contrastOffset: Int? = nil,
        brightnessLimitMin: Int? = nil,
        contrastLimitMin: Int? = nil,
        brightnessLimitMax: Int? = nil,
        contrastLimitMax: Int? = nil,
        appBrightnessOffset: Int = 0,
        appContrastOffset: Int = 0,
        withAnimation: Bool = false
    ) {
        if display.id == GENERIC_DISPLAY_ID {
            return
        }

        var brightnessChartEntry = brightnessContrastChart.brightnessGraph.values
        var contrastChartEntry = brightnessContrastChart.contrastGraph.values

        if brightnessChartEntry.isEmpty || contrastChartEntry.isEmpty {
            return
        }

        switch brightnessAdapter.mode {
        case .location:
            let maxValues = brightnessContrastChart.maxValuesLocation
            let steps = brightnessContrastChart.interpolationValues
            let points = brightnessAdapter.getBrightnessContrastBatch(
                for: display, count: maxValues, minutesBetween: steps, factor: factor,
                daylightExtension: daylightExtension, noonDuration: noonDuration,
                appBrightnessOffset: appBrightnessOffset, appContrastOffset: appContrastOffset
            )
            for x in 0 ..< (maxValues - 1) {
                let startIndex = x * steps
                let xPoints = points[startIndex ..< (startIndex + steps)]
                for (i, y) in xPoints.enumerated() {
                    brightnessChartEntry[x * steps + i].y = y.0.doubleValue
                    contrastChartEntry[x * steps + i].y = y.1.doubleValue
                }
            }
            for (i, point) in brightnessChartEntry.prefix(steps).reversed().enumerated() {
                brightnessChartEntry[(maxValues - 1) * steps + i].y = point.y
            }
            for (i, point) in contrastChartEntry.prefix(steps).reversed().enumerated() {
                contrastChartEntry[(maxValues - 1) * steps + i].y = point.y
            }
        case .sync:
            let maxValues = brightnessContrastChart.maxValuesSync
            let xs = stride(from: 0, to: maxValues - 1, by: 1)
            let percents = Array(stride(from: 0.0, to: Double(maxValues - 1) / 100.0, by: 0.01))
            for (x, b) in zip(xs, display.computeSIMDValue(from: percents, type: .brightness, offset: brightnessOffset, appOffset: appBrightnessOffset)) {
                brightnessChartEntry[x].y = b.doubleValue
            }
            for (x, b) in zip(xs, display.computeSIMDValue(from: percents, type: .contrast, offset: contrastOffset, appOffset: appContrastOffset)) {
                contrastChartEntry[x].y = b.doubleValue
            }
        case .manual:
            let maxValues = brightnessContrastChart.maxValuesSync
            let xs = stride(from: 0, to: maxValues - 1, by: 1)
            let percents = Array(stride(from: 0.0, to: Double(maxValues - 1) / 100.0, by: 0.01))
            for (x, b) in zip(xs, brightnessAdapter.computeSIMDManualValueFromPercent(from: percents, key: "brightness", minVal: brightnessLimitMin, maxVal: brightnessLimitMax)) {
                brightnessChartEntry[x].y = b
            }
            for (x, b) in zip(xs, brightnessAdapter.computeSIMDManualValueFromPercent(from: percents, key: "contrast", minVal: contrastLimitMin, maxVal: contrastLimitMax)) {
                contrastChartEntry[x].y = b
            }
        }

        // brightnessContrastChart.clampDataset(display: display, mode: brightnessAdapter.mode)
        if withAnimation {
            brightnessContrastChart.animate(yAxisDuration: 1.0, easingOption: ChartEasingOption.easeOutExpo)
        } else {
            brightnessContrastChart.notifyDataSetChanged()
        }
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = datastore.defaults.observe(\.adaptiveBrightnessMode, options: [.old, .new], changeHandler: { _, change in
            guard let mode = change.newValue, let oldMode = change.oldValue, mode != oldMode else {
                return
            }
            let adaptiveMode = AdaptiveMode(rawValue: mode)
            if let chart = self.brightnessContrastChart, !chart.visibleRect.isEmpty {
                self.initGraph(display: brightnessAdapter.firstDisplay, mode: adaptiveMode)
            }
        })
    }

    func initGraph(display: Display?, mode: AdaptiveMode? = nil) {
        brightnessContrastChart?.initGraph(display: display, brightnessColor: brightnessGraphColorYellow, contrastColor: contrastGraphColorYellow, labelColor: xAxisLabelColorYellow, mode: mode)
    }

    func zeroGraph() {
        initGraph(display: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = settingsBgColor.cgColor
        initGraph(display: nil)
        listenForAdaptiveModeChange()
    }
}
