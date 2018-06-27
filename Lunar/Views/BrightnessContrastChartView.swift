//
//  BrightnessContrastChartView.swift
//  Lunar
//
//  Created by Alin on 19/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Charts
import Cocoa

class BrightnessContrastChartView: LineChartView {
    let brightnessGraph = LineChartDataSet(values: [ChartDataEntry](), label: "Brightness")
    let contrastGraph = LineChartDataSet(values: [ChartDataEntry](), label: "Contrast")
    let graphData = LineChartData()

    func zero() {
        var brightnessChartEntry = brightnessGraph.values
        var contrastChartEntry = contrastGraph.values
        for hour in 0 ... 24 {
            brightnessChartEntry[hour].y = 0
            contrastChartEntry[hour].y = 0
        }
        notifyDataSetChanged()
    }

    func initGraph(display: Display?, brightnessColor: NSColor, contrastColor: NSColor, labelColor: NSColor) {
        if display == nil || display?.id == GENERIC_DISPLAY_ID {
            isHidden = true
        } else {
            isHidden = false
        }

        var brightnessChartEntry = brightnessGraph.values
        var contrastChartEntry = contrastGraph.values

        brightnessChartEntry.reserveCapacity(25)
        contrastChartEntry.reserveCapacity(25)
        brightnessChartEntry.removeAll(keepingCapacity: true)
        contrastChartEntry.removeAll(keepingCapacity: true)

        var brightnessY: Double = 0
        var contrastY: Double = 0
        for hour in 0 ..< 24 {
            if let display = display, display.id != GENERIC_DISPLAY_ID {
                let (brightness, contrast) = brightnessAdapter.getBrightnessContrast(for: display, hour: hour)
                brightnessY = brightness.doubleValue
                contrastY = contrast.doubleValue
            }
            brightnessChartEntry.append(ChartDataEntry(x: Double(hour), y: brightnessY))
            contrastChartEntry.append(ChartDataEntry(x: Double(hour), y: contrastY))
        }
        brightnessChartEntry.append(brightnessChartEntry[0])
        contrastChartEntry.append(contrastChartEntry[0])

        brightnessGraph.values = brightnessChartEntry
        contrastGraph.values = contrastChartEntry

        graphData.addDataSet(brightnessGraph)
        graphData.addDataSet(contrastGraph)

        brightnessGraph.colors = [NSColor.clear]
        brightnessGraph.fillColor = brightnessColor
        brightnessGraph.drawCirclesEnabled = false
        brightnessGraph.drawFilledEnabled = true
        brightnessGraph.drawValuesEnabled = false

        contrastGraph.colors = [NSColor.clear]
        contrastGraph.fillColor = contrastColor
        contrastGraph.drawCirclesEnabled = false
        contrastGraph.drawFilledEnabled = true
        contrastGraph.drawValuesEnabled = false

        xAxis.labelTextColor = labelColor

        data = graphData
        setup()
    }

    func setup() {
        gridBackgroundColor = NSColor.clear
        drawGridBackgroundEnabled = false
        drawBordersEnabled = false
        autoScaleMinMaxEnabled = false

        leftAxis.axisMaximum = 130
        leftAxis.axisMinimum = 0
        leftAxis.drawGridLinesEnabled = false
        leftAxis.drawLabelsEnabled = false
        leftAxis.drawAxisLineEnabled = false

        rightAxis.axisMaximum = 130
        rightAxis.axisMinimum = 0
        rightAxis.drawGridLinesEnabled = false
        rightAxis.drawLabelsEnabled = false
        rightAxis.drawAxisLineEnabled = false

        xAxis.drawGridLinesEnabled = false
        xAxis.drawLabelsEnabled = true
        xAxis.labelFont = NSFont.systemFont(ofSize: 12, weight: .bold)
        xAxis.labelPosition = .bottomInside
        xAxis.valueFormatter = HourValueFormatter()
        xAxis.drawAxisLineEnabled = false

        chartDescription = nil
        legend.enabled = false
        noDataText = ""
        noDataTextColor = .clear
        animate(yAxisDuration: 1.5, easingOption: ChartEasingOption.easeOutExpo)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
