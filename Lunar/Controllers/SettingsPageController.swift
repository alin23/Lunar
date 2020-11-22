//
//  SettingsPageController.swift
//  Lunar
//
//  Created by Alin on 21/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Charts
import Cocoa
import Defaults

class SettingsPageController: NSViewController {
    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView!
    @IBOutlet var settingsContainerView: NSView!
    @IBOutlet var advancedSettingsContainerView: NSView!
    @IBOutlet var advancedSettingsButton: ToggleButton!
    @objc dynamic var advancedSettingsShown = false

    var adaptiveModeObserver: DefaultsObservation?

    @IBAction func toggleAdvancedSettings(_ sender: ToggleButton) {
        advancedSettingsShown = sender.state == .on
    }

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
        brightnessClipMin: Double? = nil,
        brightnessClipMax: Double? = nil,
        appBrightnessOffset: Int = 0,
        appContrastOffset: Int = 0,
        withAnimation: Bool = false,
        updateLegend: Bool = false,
        updateLimitLines: Bool = false
    ) {
        if display.id == GENERIC_DISPLAY_ID {
            return
        }

        let brightnessChartEntry = brightnessContrastChart.brightnessGraph.entries
        let contrastChartEntry = brightnessContrastChart.contrastGraph.entries

        if brightnessChartEntry.isEmpty || contrastChartEntry.isEmpty {
            return
        }

        runInMainThread { [weak brightnessContrastChart] in
            if updateLegend {
                brightnessContrastChart?.setupLegend()
            }

            if updateLimitLines {
                brightnessContrastChart?.setupLimitLines(mode: brightnessAdapter.mode)
            }
        }

        switch brightnessAdapter.mode {
        case .sensor:
            log.info("Sensor mode")
        case .location:
            let maxValues = brightnessContrastChart.maxValuesLocation
            let steps = brightnessContrastChart.interpolationValues
            let points = brightnessAdapter.getBrightnessContrastBatch(
                for: display, count: maxValues, minutesBetween: steps, factor: factor,
                daylightExtension: daylightExtension, noonDuration: noonDuration,
                appBrightnessOffset: appBrightnessOffset, appContrastOffset: appContrastOffset
            )
            var idx: Int
            for x in 0 ..< (maxValues - 1) {
                let startIndex = x * steps
                let xPoints = points[startIndex ..< (startIndex + steps)]
                for (i, y) in xPoints.enumerated() {
                    idx = x * steps + i
                    if idx >= brightnessChartEntry.count || idx >= contrastChartEntry.count {
                        break
                    }
                    brightnessChartEntry[idx].y = y.0.doubleValue
                    contrastChartEntry[idx].y = y.1.doubleValue
                }
            }
            for (i, point) in brightnessChartEntry.prefix(steps).reversed().enumerated() {
                idx = (maxValues - 1) * steps + i
                if idx >= brightnessChartEntry.count {
                    break
                }
                brightnessChartEntry[idx].y = point.y
            }
            for (i, point) in contrastChartEntry.prefix(steps).reversed().enumerated() {
                idx = (maxValues - 1) * steps + i
                if idx >= contrastChartEntry.count {
                    break
                }
                contrastChartEntry[idx].y = point.y
            }
        case .sync:
            let maxValues = brightnessContrastChart.maxValuesSync
            let xs = stride(from: 0, to: maxValues - 1, by: 1)
            let percents = Array(stride(from: 0.0, to: Double(maxValues - 1) / 100.0, by: 0.01))
            for (x, b) in zip(
                xs,
                display
                    .computeSIMDValue(
                        from: percents,
                        type: .brightness,
                        offset: brightnessOffset,
                        appOffset: appBrightnessOffset,
                        brightnessClipMin: brightnessClipMin,
                        brightnessClipMax: brightnessClipMax
                    )
            ) {
                brightnessChartEntry[x].y = b.doubleValue
            }
            for (x, b) in zip(
                xs,
                display
                    .computeSIMDValue(
                        from: percents,
                        type: .contrast,
                        offset: contrastOffset,
                        appOffset: appContrastOffset,
                        brightnessClipMin: brightnessClipMin,
                        brightnessClipMax: brightnessClipMax
                    )
            ) {
                contrastChartEntry[x].y = b.doubleValue
            }
        case .manual:
            let maxValues = brightnessContrastChart.maxValuesSync
            let xs = stride(from: 0, to: maxValues - 1, by: 1)
            let percents = Array(stride(from: 0.0, to: Double(maxValues - 1) / 100.0, by: 0.01))
            for (x, b) in zip(
                xs,
                brightnessAdapter
                    .computeSIMDManualValueFromPercent(
                        from: percents,
                        key: "brightness",
                        minVal: brightnessLimitMin,
                        maxVal: brightnessLimitMax
                    )
            ) {
                brightnessChartEntry[x].y = b
            }
            for (x, b) in zip(
                xs,
                brightnessAdapter
                    .computeSIMDManualValueFromPercent(from: percents, key: "contrast", minVal: contrastLimitMin, maxVal: contrastLimitMax)
            ) {
                contrastChartEntry[x].y = b
            }
        }

        // brightnessContrastChart.clampDataset(display: display, mode: brightnessAdapter.mode)
        runInMainThread { [weak brightnessContrastChart] in
            if withAnimation {
                brightnessContrastChart?.animate(yAxisDuration: 1.0, easingOption: ChartEasingOption.easeOutExpo)
            } else {
                brightnessContrastChart?.notifyDataSetChanged()
            }
        }
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = Defaults
            .observe(.adaptiveBrightnessMode) { [weak self, weak brightnessContrastChart = self.brightnessContrastChart] change in
                guard let self = self, change.newValue != change.oldValue else {
                    return
                }
                if let chart = brightnessContrastChart, !chart.visibleRect.isEmpty {
                    self.initGraph(display: brightnessAdapter.firstDisplay, mode: change.newValue)
                }
            }
    }

    func initGraph(display: Display?, mode: AdaptiveMode? = nil) {
        runInMainThread { [weak brightnessContrastChart] in
            brightnessContrastChart?.initGraph(
                display: display,
                brightnessColor: brightnessGraphColorYellow,
                contrastColor: contrastGraphColorYellow,
                labelColor: xAxisLabelColorYellow,
                mode: mode
            )
        }
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
        advancedSettingsButton.page = .settings
        advancedSettingsButton.isHidden = false
    }
}
