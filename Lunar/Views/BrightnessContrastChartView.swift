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
    let brightnessGraph = LineChartDataSet(entries: [ChartDataEntry](), label: "Brightness")
    let contrastGraph = LineChartDataSet(entries: [ChartDataEntry](), label: "Contrast")
    let graphData = LineChartData()
    let interpolationValues = 5
    let maxValuesLocation = 25
    let maxValuesSync = 102

    func zero() {
        for (brightnessEntry, contrastEntry) in zip(brightnessGraph.entries, contrastGraph.entries) {
            brightnessEntry.y = 0
            contrastEntry.y = 0
        }
        notifyDataSetChanged()
    }

    func clampDataset(display: Display, mode: AdaptiveMode, minBrightness: Double? = nil) {
        switch mode {
        case .location:
            let brightnessChartEntry = brightnessGraph.entries
            let contrastChartEntry = contrastGraph.entries

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

        var brightnessChartEntry = brightnessGraph.entries
        var contrastChartEntry = contrastGraph.entries
        let adaptiveMode = mode ?? brightnessAdapter.mode

        brightnessChartEntry.removeAll(keepingCapacity: false)
        contrastChartEntry.removeAll(keepingCapacity: false)

//        var brightnessY: Double = 0
//        var contrastY: Double = 0

        if display == nil || display?.id == GENERIC_DISPLAY_ID {
            if adaptiveMode != .location {
                let maxValues = maxValuesSync
                brightnessChartEntry = stride(from: 0, to: maxValues, by: 1).map { x in ChartDataEntry(x: Double(x), y: 0.0) }
                contrastChartEntry = stride(from: 0, to: maxValues, by: 1).map { x in ChartDataEntry(x: Double(x), y: 0.0) }
            }
        } else if let display = display {
            switch adaptiveMode {
            case .location:
                brightnessChartEntry.reserveCapacity(maxValuesLocation * interpolationValues)
                contrastChartEntry.reserveCapacity(maxValuesLocation * interpolationValues)
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

                let clipMin = brightnessAdapter.brightnessClipMin
                let clipMax = brightnessAdapter.brightnessClipMax

                brightnessChartEntry.append(
                    contentsOf: zip(
                        xs, display.computeSIMDValue(from: percents, type: .brightness, brightnessClipMin: clipMin, brightnessClipMax: clipMax)
                    ).map { ChartDataEntry(x: $0, y: $1.doubleValue) }
                )
                contrastChartEntry.append(
                    contentsOf: zip(
                        xs, display.computeSIMDValue(from: percents, type: .contrast, brightnessClipMin: clipMin, brightnessClipMax: clipMax)
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
            brightnessGraph.replaceEntries(brightnessChartEntry)
            contrastGraph.replaceEntries(contrastChartEntry)

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
        leftAxis.labelTextColor = labelColor
        rightAxis.labelTextColor = labelColor

        setupLegend()

        data = graphData
        setupLimitLines(mode: adaptiveMode)
        setup(mode: adaptiveMode)
    }

    func setupLimitLines(mode: AdaptiveMode) {
        xAxis.removeAllLimitLines()

        switch mode {
        case .location:
            guard let m = brightnessAdapter.moment else { return }

            let sunriseLine = ChartLimitLine(limit: (m.sunrise.timeIntervalSince(m.sunrise.dateAtStartOf(.day)) / 1.days.timeInterval) * Double(maxValuesLocation), label: "Sunrise (\(m.sunrise.toRelative()))")
            let solarNoonLine = ChartLimitLine(limit: (m.solarNoon.timeIntervalSince(m.solarNoon.dateAtStartOf(.day)) / 1.days.timeInterval) * Double(maxValuesLocation), label: "Noon     (\(m.solarNoon.toRelative()))")
            let sunsetLine = ChartLimitLine(limit: (m.sunset.timeIntervalSince(m.sunset.dateAtStartOf(.day)) / 1.days.timeInterval) * Double(maxValuesLocation), label: "Sunset (\(m.sunset.toRelative()))")

            if m.sunset.hour <= 12 {
                sunsetLine.labelPosition = .bottomRight
            } else {
                sunsetLine.labelPosition = .bottomLeft
            }

            if m.sunrise.hour <= 12 {
                sunriseLine.labelPosition = .topRight
            } else {
                sunriseLine.labelPosition = .topLeft
            }

            sunsetLine.yOffset = 30
            solarNoonLine.xOffset = -42
            solarNoonLine.yOffset = 60

            sunriseLine.valueFont = NSFont.systemFont(ofSize: 12, weight: .bold)
            solarNoonLine.valueFont = NSFont.systemFont(ofSize: 12, weight: .bold)
            sunsetLine.valueFont = NSFont.systemFont(ofSize: 12, weight: .bold)

            sunriseLine.valueTextColor = xAxis.labelTextColor.withAlphaComponent(0.4)
            solarNoonLine.valueTextColor = xAxis.labelTextColor.withAlphaComponent(0.4)
            sunsetLine.valueTextColor = xAxis.labelTextColor.withAlphaComponent(0.4)

            sunriseLine.lineColor = contrastGraph.fillColor.withAlphaComponent(0.7)
            solarNoonLine.lineColor = (red.blended(withFraction: 0.5, of: lunarYellow) ?? red).withAlphaComponent(0.7)
            sunsetLine.lineColor = brightnessGraph.fillColor.withAlphaComponent(0.7)

            xAxis.addLimitLine(sunriseLine)
            xAxis.addLimitLine(solarNoonLine)
            xAxis.addLimitLine(sunsetLine)
        default:
            return
        }
    }

    func setupLegend() {
        legend.enabled = true
        legend.drawInside = true
        legend.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        legend.textColor = xAxisLabelColor
        legend.yOffset = 68.0
        legend.xOffset = 36.0
        legend.form = .square
        legend.formSize = 14.0
        legend.orientation = .vertical

        legend.setCustom(entries: [
            LegendEntry(label: "Brightness", form: .square, formSize: 14.0, formLineWidth: 10.0, formLineDashPhase: 10.0, formLineDashLengths: nil, formColor: brightnessGraph.fillColor.withAlphaComponent(0.4)),
            LegendEntry(label: "Contrast", form: .square, formSize: 14.0, formLineWidth: 10.0, formLineDashPhase: 10.0, formLineDashLengths: nil, formColor: contrastGraph.fillColor.withAlphaComponent(0.4)),
        ])
    }

    func setup(mode: AdaptiveMode? = nil) {
        gridBackgroundColor = NSColor.clear
        drawGridBackgroundEnabled = false
        drawBordersEnabled = false
        autoScaleMinMaxEnabled = false

        leftAxis.axisMaximum = 100
        leftAxis.axisMinimum = 0
        leftAxis.drawGridLinesEnabled = false
        leftAxis.drawAxisLineEnabled = false
        leftAxis.drawLabelsEnabled = false

        rightAxis.axisMaximum = 100
        rightAxis.axisMinimum = 0
        rightAxis.drawGridLinesEnabled = true
        rightAxis.drawAxisLineEnabled = false
        rightAxis.drawLabelsEnabled = true
        rightAxis.labelFont = NSFont.systemFont(ofSize: 12, weight: .bold)
        rightAxis.labelPosition = .insideChart
        rightAxis.xOffset = 22.0
        rightAxis.gridColor = white.withAlphaComponent(0.3)
        rightAxis.drawZeroLineEnabled = false
        rightAxis.drawBottomYLabelEntryEnabled = false

        xAxis.drawGridLinesEnabled = true
        xAxis.labelFont = NSFont.systemFont(ofSize: 12, weight: .bold)
        xAxis.labelPosition = .bottomInside
        xAxis.drawAxisLineEnabled = false
        xAxis.gridColor = white.withAlphaComponent(0.3)

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

        setupLegend()

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
