//
//  SettingsPageController.swift
//  Lunar
//
//  Created by Alin on 21/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

class SettingsPageController: NSViewController {
    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView!

    func updateDataset(display: Display, minBrightness: UInt8? = nil, maxBrightness: UInt8? = nil, minContrast: UInt8? = nil, maxContrast: UInt8? = nil, daylightExtension: Int? = nil, noonDuration: Int? = nil, brightnessOffset: Int = 0,
                       contrastOffset: Int = 0) {
        var brightnessChartEntry = brightnessContrastChart.brightnessGraph.values
        var contrastChartEntry = brightnessContrastChart.contrastGraph.values
        for hour in 0 ..< 24 {
            let (brightness, contrast) = brightnessAdapter.getBrightnessContrast(
                for: display, hour: hour,
                minBrightness: minBrightness,
                maxBrightness: maxBrightness,
                minContrast: minContrast,
                maxContrast: maxContrast,
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

        brightnessContrastChart.notifyDataSetChanged()
    }

    func initGraph(display: Display?) {
        brightnessContrastChart.initGraph(display: display, brightnessColor: brightnessGraphColorYellow, contrastColor: contrastGraphColorYellow, labelColor: xAxisLabelColorYellow)
    }

    func zeroGraph() {
        initGraph(display: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer!.backgroundColor = logoColor.cgColor
        initGraph(display: nil)
    }
}
