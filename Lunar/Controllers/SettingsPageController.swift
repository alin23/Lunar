//
//  SettingsPageController.swift
//  Lunar
//
//  Created by Alin on 21/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Charts
import Cocoa
import Combine
import Defaults

class SettingsPageController: NSViewController {
    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView!
    @IBOutlet var settingsContainerView: NSView!
    @IBOutlet var advancedSettingsContainerView: NSView!
    @IBOutlet var advancedSettingsButton: ToggleButton!
    @objc dynamic var advancedSettingsShown = false

    var adaptiveModeObserver: Cancellable?

    @IBAction func toggleAdvancedSettings(_ sender: ToggleButton) {
        advancedSettingsShown = sender.state == .on
    }

    func updateDataset(
        display: Display,
        factor: Double? = nil,
        appBrightnessOffset: Int = 0,
        appContrastOffset: Int = 0,
        withAnimation: Bool = false,
        updateLegend: Bool = false,
        updateLimitLines: Bool = false
    ) {
        guard !advancedSettingsShown, display.id != GENERIC_DISPLAY_ID else { return }

        let brightnessChartEntry = brightnessContrastChart.brightnessGraph.entries
        let contrastChartEntry = brightnessContrastChart.contrastGraph.entries

        if brightnessChartEntry.isEmpty || contrastChartEntry.isEmpty {
            return
        }

        mainThread { [weak self] in
            if updateLegend {
                self?.brightnessContrastChart?.setupLegend()
            }

            if updateLimitLines {
                self?.brightnessContrastChart?.setupLimitLines(display: display)
            }
        }

        switch displayController.adaptiveMode {
        case let mode as SensorMode:
            let maxValues = min(mode.maxChartDataPoints, brightnessChartEntry.count, contrastChartEntry.count)
            let xs = stride(from: 0, to: maxValues, by: 1)
            for (x, b) in zip(
                xs,
                mode.interpolateSIMD(
                    .brightness(0),
                    display: display,
                    offset: appBrightnessOffset.d,
                    factor: factor
                )
            ) {
                brightnessChartEntry[x].y = b
            }
            for (x, b) in zip(
                xs,
                mode.interpolateSIMD(
                    .contrast(0),
                    display: display,
                    offset: appContrastOffset.d,
                    factor: factor
                )
            ) {
                contrastChartEntry[x].y = b
            }
        case let mode as LocationMode:
            let points = mode.getBrightnessContrastBatch(
                display: display, factor: factor,
                appBrightnessOffset: appBrightnessOffset, appContrastOffset: appContrastOffset
            )
            let maxValues = min(mode.maxChartDataPoints, points.brightness.count, points.contrast.count, brightnessChartEntry.count, contrastChartEntry.count)
            let xs = stride(from: 0, to: maxValues, by: 1)

            for (x, y) in zip(xs, points.brightness) {
                brightnessChartEntry[x].y = y
            }
            for (x, y) in zip(xs, points.contrast) {
                contrastChartEntry[x].y = y
            }
        case let mode as SyncMode:
            let maxValues = min(mode.maxChartDataPoints, brightnessChartEntry.count, contrastChartEntry.count)
            let xs = stride(from: 0, to: maxValues, by: 1)

            for (x, b) in zip(
                xs,
                mode.interpolateSIMD(
                    .brightness(0),
                    display: display,
                    offset: appBrightnessOffset.d,
                    factor: factor
                )
            ) {
                brightnessChartEntry[x].y = b
            }
            for (x, b) in zip(
                xs,
                mode.interpolateSIMD(
                    .contrast(0),
                    display: display,
                    offset: appContrastOffset.d,
                    factor: factor
                )
            ) {
                contrastChartEntry[x].y = b
            }
        case let mode as ManualMode:
            let maxValues = min(mode.maxChartDataPoints, brightnessChartEntry.count, contrastChartEntry.count)
            let xs = stride(from: 0, to: maxValues, by: 1)
            let percents = Array(stride(from: 0.0, to: maxValues.d / 100.0, by: 0.01))
            for (x, b) in zip(
                xs,
                mode.computeSIMD(
                    from: percents,
                    minVal: display.minBrightness.doubleValue,
                    maxVal: display.maxBrightness.doubleValue
                )
            ) {
                brightnessChartEntry[x].y = b
            }
            for (x, b) in zip(
                xs,
                mode.computeSIMD(
                    from: percents,
                    minVal: display.minContrast.doubleValue,
                    maxVal: display.maxContrast.doubleValue
                )
            ) {
                contrastChartEntry[x].y = b
            }
        default:
            print("Unknown mode")
        }

        // brightnessContrastChart.clampDataset(display: display, mode: displayController.mode)
        brightnessContrastChart.highlightCurrentValues(adaptiveMode: displayController.adaptiveMode, for: display)

        mainThread { [weak self] in
            if withAnimation {
                self?.brightnessContrastChart?.animate(yAxisDuration: 1.0, easingOption: ChartEasingOption.easeOutExpo)
            } else {
                self?.brightnessContrastChart?.notifyDataSetChanged()
            }
        }
    }

    var pausedAdaptiveModeObserver: Bool = false

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = adaptiveBrightnessModePublisher.sink { [weak self] change in
            guard let self = self, !self.pausedAdaptiveModeObserver else {
                return
            }
            mainThread {
                self.pausedAdaptiveModeObserver = true
                Defaults.withoutPropagation {
                    if let chart = self.brightnessContrastChart, !chart.visibleRect.isEmpty {
                        self.initGraph(display: displayController.firstDisplay, mode: change.newValue.mode)
                    }
                }
                self.pausedAdaptiveModeObserver = false
            }
        }
    }

    func initGraph(display: Display?, mode: AdaptiveMode? = nil) {
        guard !advancedSettingsShown else { return }

        mainThread { [weak self] in
            self?.brightnessContrastChart?.initGraph(
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
        view.bg = settingsBgColor
        initGraph(display: nil)
        listenForAdaptiveModeChange()
        advancedSettingsButton.page = .settings
        advancedSettingsButton.isHidden = false
    }
}
