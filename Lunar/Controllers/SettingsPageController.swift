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
        for hour in 0 ..< 24 {
            let (brightness, contrast) = brightnessAdapter.getBrightnessContrast(
                for: display,
                hour: hour,
                daylightExtension: daylightExtension,
                noonDuration: noonDuration,
                brightnessOffset: brightnessOffset,
                contrastOffset: contrastOffset
            )
            brightnessChartEntry[hour].y = brightness.doubleValue
            contrastChartEntry[hour].y = contrast.doubleValue
        }
        brightnessChartEntry[24] = brightnessChartEntry[0]
        contrastChartEntry[24] = contrastChartEntry[0]

        if withAnimation {
            brightnessContrastChart.animate(yAxisDuration: 1.0, easingOption: ChartEasingOption.easeOutExpo)
        } else {
            brightnessContrastChart.notifyDataSetChanged()
        }
    }

    func easeOutExpo(elapsed: TimeInterval, duration: TimeInterval) -> Double {
        return (elapsed == duration) ? 1.0 : (-Double(pow(2.0, -10.0 * elapsed / duration)) + 1.0)
    }

    func transitionDataset(
        display: Display,
        daylightExtension: Int? = nil,
        noonDuration: Int? = nil,
        brightnessOffset: Int = 0,
        contrastOffset: Int = 0,
        duration: TimeInterval = 0.5
    ) {
        let steps = Double(MAX_BRIGHTNESS)
        let delay = duration / steps
        var brightnessChartEntry = brightnessContrastChart.brightnessGraph.values
        var contrastChartEntry = brightnessContrastChart.contrastGraph.values
        var newBrightnessChartEntry = brightnessContrastChart.brightnessGraph.values.map({ value in value.y })
        var newContrastChartEntry = brightnessContrastChart.contrastGraph.values.map({ value in value.y })

        for hour in 0 ..< 24 {
            let (brightness, contrast) = brightnessAdapter.getBrightnessContrast(
                for: display,
                hour: hour,
                daylightExtension: daylightExtension,
                noonDuration: noonDuration,
                brightnessOffset: brightnessOffset,
                contrastOffset: contrastOffset
            )
            newBrightnessChartEntry[hour] = brightness.doubleValue
            newContrastChartEntry[hour] = contrast.doubleValue
        }
        newBrightnessChartEntry[24] = newBrightnessChartEntry[0]
        newContrastChartEntry[24] = newContrastChartEntry[0]

        for step in 0 ..< MAX_BRIGHTNESS {
            let factor = easeOutExpo(elapsed: Double(step), duration: steps)
            for hour in 0 ..< 24 {
                brightnessChartEntry[hour].y = (brightnessChartEntry[hour].y - newBrightnessChartEntry[hour]) * factor + newBrightnessChartEntry[hour]
                contrastChartEntry[hour].y = (contrastChartEntry[hour].y - newContrastChartEntry[hour]) * factor + newContrastChartEntry[hour]
            }
            brightnessContrastChart.notifyDataSetChanged()
            Thread.sleep(forTimeInterval: delay)
        }
    }

    func initGraph(display: Display?) {
        brightnessContrastChart?.initGraph(display: display, brightnessColor: brightnessGraphColorYellow, contrastColor: contrastGraphColorYellow, labelColor: xAxisLabelColorYellow)
    }

    func zeroGraph() {
        initGraph(display: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer!.backgroundColor = settingsBgColor.cgColor
        initGraph(display: nil)
    }
}
