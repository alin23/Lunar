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

    func updateDataset(
        display: Display,
        daylightExtension: Int? = nil,
        noonDuration: Int? = nil,
        brightnessOffset: Int = 0,
        contrastOffset: Int = 0,
        withAnimation: Bool = false
    ) {
        if display.id == GENERIC_DISPLAY_ID {
            return
        }
        var brightnessChartEntry = brightnessContrastChart.brightnessGraph.values
        var contrastChartEntry = brightnessContrastChart.contrastGraph.values

        let maxValues = brightnessContrastChart.maxValues

        switch brightnessAdapter.mode {
        case .location:
            for x in 0 ..< (maxValues - 1) {
                let (brightness, contrast) = brightnessAdapter.getBrightnessContrast(
                    for: display,
                    hour: x,
                    daylightExtension: daylightExtension,
                    noonDuration: noonDuration,
                    brightnessOffset: brightnessOffset,
                    contrastOffset: contrastOffset
                )
                brightnessChartEntry[x].y = brightness.doubleValue
                contrastChartEntry[x].y = contrast.doubleValue
            }
            brightnessChartEntry[maxValues - 1].y = brightnessChartEntry[0].y
            contrastChartEntry[maxValues - 1].y = contrastChartEntry[0].y
        default:
            break
        }

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
        view.layer!.backgroundColor = settingsBgColor.cgColor
        initGraph(display: nil)
        listenForAdaptiveModeChange()
    }
}
