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
    let interpolationValues = 5
    let maxValuesLocation = 25
    let maxValuesSync = 102

    func zero() {
        for (brightnessEntry, contrastEntry) in zip(brightnessGraph.values, contrastGraph.values) {
            brightnessEntry.y = 0
            contrastEntry.y = 0
        }
        notifyDataSetChanged()
    }

    func clampDataset(display: Display, mode: AdaptiveMode, minBrightness: Double? = nil) {
        switch mode {
        case .location:
            let brightnessChartEntry = brightnessGraph.values
            let contrastChartEntry = contrastGraph.values

            if brightnessChartEntry.isEmpty || contrastChartEntry.isEmpty {
                return
            }

            let minVal = minBrightness ?? display.minBrightness.doubleValue
            let firstIndex = brightnessChartEntry.firstIndex(where: { d in d.y != minVal }) ?? 0
            let lastIndex = brightnessChartEntry.lastIndex(where: { d in d.y != minVal }) ?? (brightnessChartEntry.count - 1)
            fitScreen()
            zoom(
                scaleX: CGFloat(brightnessChartEntry.count) / CGFloat(brightnessChartEntry[firstIndex ... lastIndex].count),
                scaleY: 1.0, x: frame.width / 2.0, y: 0.0
            )
        default:
            break
        }
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

        var brightnessY: Double = 0
        var contrastY: Double = 0
        if display == nil || display?.id == GENERIC_DISPLAY_ID {
            switch adaptiveMode {
            case .location:
                let maxValues = maxValuesLocation
            default:
                let maxValues = maxValuesSync
                brightnessChartEntry = stride(from: 0, to: maxValues, by: 1).map { x in ChartDataEntry(x: Double(x), y: 0.0) }
                contrastChartEntry = stride(from: 0, to: maxValues, by: 1).map { x in ChartDataEntry(x: Double(x), y: 0.0) }
            }
        } else if let display = display {
            switch adaptiveMode {
            case .location:
                brightnessChartEntry.reserveCapacity(maxValuesLocation * interpolationValues)
                contrastChartEntry.reserveCapacity(maxValuesLocation * interpolationValues)
                let step = 60 / interpolationValues
                let steps = Double(interpolationValues)
                let points = brightnessAdapter.getBrightnessContrastBatch(for: display, count: maxValuesLocation, minutesBetween: interpolationValues)
                func computePoints(hour: Int) -> ([ChartDataEntry], [ChartDataEntry]) {
                    let xx = Double(hour)
                    let startIndex = hour * interpolationValues
                    let points = points[startIndex ..< (startIndex + interpolationValues)]
                    let brightnessPoints = points.enumerated().map { arg -> ChartDataEntry in
                        let (i, y) = arg
                        return ChartDataEntry(x: xx + (Double(i) / steps), y: y.0.doubleValue)
                    }
                    let contrastPoints = points.enumerated().map { arg -> ChartDataEntry in
                        let (i, y) = arg
                        return ChartDataEntry(x: xx + (Double(i) / steps), y: y.1.doubleValue)
                    }
                    return (brightnessPoints, contrastPoints)
                }

                for x in 0 ..< (maxValuesLocation - 1) {
                    let (brightnessPoints, contrastPoints) = computePoints(hour: x)
                    brightnessChartEntry.append(contentsOf: brightnessPoints)
                    contrastChartEntry.append(contentsOf: contrastPoints)
                }
                brightnessChartEntry.append(contentsOf: brightnessChartEntry.prefix(interpolationValues).reversed())
                contrastChartEntry.append(contentsOf: contrastChartEntry.prefix(interpolationValues).reversed())
            case .sync:
                let xs = stride(from: 0.0, to: Double(maxValuesSync - 1), by: 1.0)
                let percents = Array(stride(from: 0.0, to: Double(maxValuesSync - 1) / 100.0, by: 0.01))
                brightnessChartEntry.reserveCapacity(maxValuesSync)
                contrastChartEntry.reserveCapacity(maxValuesSync)
                brightnessChartEntry.append(
                    contentsOf: zip(
                        xs, display.computeSIMDValue(from: percents, type: .brightness)
                    ).map { ChartDataEntry(x: $0, y: $1.doubleValue) }
                )
                contrastChartEntry.append(
                    contentsOf: zip(
                        xs, display.computeSIMDValue(from: percents, type: .contrast)
                    ).map { ChartDataEntry(x: $0, y: $1.doubleValue) }
                )
            case .manual:
                let xs = stride(from: 0.0, to: Double(maxValuesSync - 1), by: 1.0)
                let percents = Array(stride(from: 0.0, to: Double(maxValuesSync - 1) / 100.0, by: 0.01))
                brightnessChartEntry.reserveCapacity(maxValuesSync)
                contrastChartEntry.reserveCapacity(maxValuesSync)
                brightnessChartEntry.append(
                    contentsOf: zip(
                        xs, brightnessAdapter.computeSIMDManualValueFromPercent(from: percents, key: "brightness")
                    ).map { ChartDataEntry(x: $0, y: $1) }
                )
                contrastChartEntry.append(
                    contentsOf: zip(
                        xs, brightnessAdapter.computeSIMDManualValueFromPercent(from: percents, key: "contrast")
                    ).map { ChartDataEntry(x: $0, y: $1) }
                )
            }
            brightnessGraph.values = brightnessChartEntry
            contrastGraph.values = contrastChartEntry

            for dataset in graphData.dataSets {
                graphData.removeDataSet(dataset)
            }
            graphData.addDataSet(brightnessGraph)
            graphData.addDataSet(contrastGraph)
            // clampDataset(display: display, mode: adaptiveMode)
        }

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
            xAxis.setLabelCount(7, force: true)
        } else {
            xAxis.valueFormatter = PercentValueFormatter()
            xAxis.drawLabelsEnabled = true
            xAxis.setLabelCount(5, force: true)
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
