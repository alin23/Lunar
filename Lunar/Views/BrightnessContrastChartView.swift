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
    let maxValues = 25

    func zero() {
        for (brightnessEntry, contrastEntry) in zip(brightnessGraph.values, contrastGraph.values) {
            brightnessEntry.y = 0
            contrastEntry.y = 0
        }
        notifyDataSetChanged()
    }

    func getInterpolatedValues(minVal: Double, maxVal: Double, count: Int) -> [Double] {
        let span = (maxVal - minVal) / Double(count)
        var values = [Double](repeating: 0.0, count: count)
        for x in 0 ..< count {
            values[x] = minVal + pow((Double(x) * span) / 100.0, 2.0) * 100.0
        }
        return values
    }

    func initGraph(display: Display?, brightnessColor: NSColor, contrastColor: NSColor, labelColor: NSColor, mode: AdaptiveMode? = nil) {
        if display == nil || display?.id == GENERIC_DISPLAY_ID {
            isHidden = true
        } else {
            isHidden = false
        }

        var brightnessChartEntry = brightnessGraph.values
        var contrastChartEntry = contrastGraph.values
        let adaptiveMode = mode ?? brightnessAdapter.mode

        brightnessChartEntry.removeAll(keepingCapacity: false)
        contrastChartEntry.removeAll(keepingCapacity: false)
        brightnessChartEntry.reserveCapacity(maxValues)
        contrastChartEntry.reserveCapacity(maxValues)

        var brightnessY: Double = 0
        var contrastY: Double = 0
        switch adaptiveMode {
        case .location:
            for x in 0 ..< (maxValues - 1) {
                if let display = display, display.id != GENERIC_DISPLAY_ID {
                    let (brightness, contrast) = brightnessAdapter.getBrightnessContrast(for: display, hour: x)
                    brightnessY = brightness.doubleValue
                    contrastY = contrast.doubleValue
                }
                brightnessChartEntry.append(ChartDataEntry(x: Double(x), y: brightnessY))
                contrastChartEntry.append(ChartDataEntry(x: Double(x), y: contrastY))
            }
            brightnessChartEntry.append(brightnessChartEntry[0])
            contrastChartEntry.append(contrastChartEntry[0])
        default:
            for x in 0 ..< maxValues {
                brightnessChartEntry.append(ChartDataEntry(x: Double(x), y: 0))
                contrastChartEntry.append(ChartDataEntry(x: Double(x), y: 0))
            }
        }

        brightnessGraph.values = brightnessChartEntry
        contrastGraph.values = contrastChartEntry

        for dataset in graphData.dataSets {
            graphData.removeDataSet(dataset)
        }
        graphData.addDataSet(brightnessGraph)
        graphData.addDataSet(contrastGraph)

        brightnessGraph.colors = [NSColor.clear]
        brightnessGraph.fillColor = brightnessColor
        brightnessGraph.drawCirclesEnabled = false
        brightnessGraph.drawFilledEnabled = true
        brightnessGraph.drawValuesEnabled = false
        brightnessGraph.mode = .cubicBezier
        brightnessGraph.cubicIntensity = 0.1

        contrastGraph.colors = [NSColor.clear]
        contrastGraph.fillColor = contrastColor
        contrastGraph.drawCirclesEnabled = false
        contrastGraph.drawFilledEnabled = true
        contrastGraph.drawValuesEnabled = false
        contrastGraph.mode = .cubicBezier
        contrastGraph.cubicIntensity = 0.1

        xAxis.labelTextColor = labelColor

        data = graphData
        setup(mode: adaptiveMode)
    }

    func setup(mode: AdaptiveMode? = nil) {
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
        xAxis.labelFont = NSFont.systemFont(ofSize: 12, weight: .bold)
        xAxis.labelPosition = .bottomInside
        xAxis.drawAxisLineEnabled = false

        let mode = mode ?? brightnessAdapter.mode
        if mode == .location {
            xAxis.valueFormatter = HourValueFormatter()
            xAxis.drawLabelsEnabled = true
        } else {
            xAxis.valueFormatter = PercentValueFormatter()
            xAxis.drawLabelsEnabled = false
        }

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
