//
//  BrightnessContrastChartView.swift
//  Lunar
//
//  Created by Alin on 19/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Charts
import Cocoa
import SwiftDate

class BrightnessContrastChartView: LineChartView {
    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: Internal

    let brightnessGraph = LineChartDataSet(entries: [ChartDataEntry](), label: "Brightness")
    let contrastGraph = LineChartDataSet(entries: [ChartDataEntry](), label: "Contrast")
    let graphData = LineChartData()

    func zero() {
        for (brightnessEntry, contrastEntry) in zip(brightnessGraph.entries, contrastGraph.entries) {
            brightnessEntry.y = 0
            contrastEntry.y = 0
        }
        notifyDataSetChanged()
    }

    func clampDataset(display: Display, mode: AdaptiveModeKey, minBrightness: Double? = nil) {
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

    func highlightCurrentValues(
        adaptiveMode: AdaptiveMode,
        for display: Display?,
        brightness: Double? = nil,
        contrast: Double? = nil,
        now: Date? = nil
    ) {
        mainAsync { [self] in
            guard let data, data.dataSetCount >= 2 else { return }

            guard CachedDefaults[.moreGraphData] else {
                highlightValues(nil)
                return
            }

            switch adaptiveMode {
            case let mode as SensorMode:
                let lux = mode.lastAmbientLight.rounded()
                var highlights: [Highlight] = []

                let maxBr = datapointLock.around { mode.brightnessDataPoint.max.i }
                let maxCr = datapointLock.around { mode.contrastDataPoint.max.i }

                if (30 ... (maxBr - 30)).contains(lux.i) {
                    highlights.append(Highlight(x: lux, dataSetIndex: 0, stackIndex: 0))
                }
                if (30 ... (maxCr - 30)).contains(lux.i) {
                    highlights.append(Highlight(x: lux, dataSetIndex: 1, stackIndex: 1))
                }
                if highlights.isEmpty {
                    highlightValues(nil)
                } else {
                    highlightValues(highlights)
                }
            case is SyncMode:
                highlightValues([
                    Highlight(x: SyncMode.lastSourceBrightness.rounded(), dataSetIndex: 0, stackIndex: 0),
                    Highlight(x: SyncMode.lastSourceContrast.rounded(), dataSetIndex: 1, stackIndex: 1),
                ])
            case let mode as LocationMode:
                guard let moment = mode.moment,
                      let sunPosition = mode.geolocation?.sun(date: now),
                      let solarNoonPosition = mode.geolocation?.solar?.solarNoonPosition,
                      let chartEntry = mode.lastChartEntry
                else { return }

                let now = now?.in(region: .local) ?? DateInRegion().convertTo(region: .local)
                let x: Double
                if now < moment.solarNoon {
                    x = cap(
                        sunPosition.elevation.rounded(.down) + chartEntry.sunriseIndex.d,
                        minVal: chartEntry.sunriseIndex.d,
                        maxVal: chartEntry.noonIndex.d
                    )
                } else {
                    x = cap(
                        (solarNoonPosition.elevation.rounded(.down) - sunPosition.elevation.rounded(.down)) + chartEntry.noonIndex.d,
                        minVal: chartEntry.noonIndex.d,
                        maxVal: chartEntry.sunsetIndex.d
                    )
                }
                highlightValues([
                    Highlight(x: x, dataSetIndex: 0, stackIndex: 0),
                    Highlight(x: x, dataSetIndex: 1, stackIndex: 1),
                ])
            case is ManualMode:
                guard let display else { return }
                highlightValues([
                    Highlight(x: brightness ?? display.brightness.doubleValue, dataSetIndex: 0, stackIndex: 0),
                    Highlight(x: contrast ?? display.contrast.doubleValue, dataSetIndex: 1, stackIndex: 1),
                ])
            default:
                return
            }
        }
    }

    func initGraph(display: Display?, brightnessColor: NSColor, contrastColor: NSColor, labelColor: NSColor, mode: AdaptiveMode? = nil) {
        mainAsync { [self] in
            if display == nil || display?.id == GENERIC_DISPLAY_ID {
                isHidden = true
            } else {
                isHidden = false
            }
        }

        var brightnessChartEntry = brightnessGraph.entries
        var contrastChartEntry = contrastGraph.entries
        let adaptiveMode = mode ?? displayController.adaptiveMode

        brightnessChartEntry.removeAll(keepingCapacity: false)
        contrastChartEntry.removeAll(keepingCapacity: false)
        xAxis.removeAllLimitLines()

        if display == nil || display?.id == GENERIC_DISPLAY_ID {
            if adaptiveMode is LocationMode {
                brightnessChartEntry = stride(from: 0, to: adaptiveMode.maxChartDataPoints, by: 1)
                    .map { x in ChartDataEntry(x: x.d, y: 0.0) }
                contrastChartEntry = stride(from: 0, to: adaptiveMode.maxChartDataPoints, by: 1).map { x in ChartDataEntry(x: x.d, y: 0.0) }
            }
        } else if let display {
            switch adaptiveMode {
            case let mode as SensorMode:
                let xs = stride(from: 0.0, to: (mode.maxChartDataPoints - 1).d, by: 30.0)
                brightnessChartEntry.reserveCapacity(mode.maxChartDataPoints)
                contrastChartEntry.reserveCapacity(mode.maxChartDataPoints)

                var values = mode.interpolateSIMD(.brightness(0), display: display, factor: display.brightnessCurveFactors[mode.key])
                if values.count < mode.maxChartDataPoints {
                    values += [Double](repeating: values.last!, count: mode.maxChartDataPoints - values.count)
                }
                let curveAdjustedBrightness = mode.adjustCurveSIMD(
                    [Double](values.striding(by: 30)),
                    factor: mode.visualCurveFactor,
                    minVal: display.minBrightness.doubleValue,
                    maxVal: display.maxBrightness.doubleValue
                )
                brightnessChartEntry.append(
                    contentsOf: zip(
                        xs, curveAdjustedBrightness
                    ).map { ChartDataEntry(x: $0, y: $1) }
                )

                values = mode.interpolateSIMD(.contrast(0), display: display, factor: display.contrastCurveFactors[mode.key])
                if values.count < mode.maxChartDataPoints {
                    values += [Double](repeating: values.last!, count: mode.maxChartDataPoints - values.count)
                }
                let curveAdjustedContrast = mode.adjustCurveSIMD(
                    [Double](values.striding(by: 30)),
                    factor: mode.visualCurveFactor,
                    minVal: display.minContrast.doubleValue,
                    maxVal: display.maxContrast.doubleValue
                )
                contrastChartEntry.append(
                    contentsOf: zip(
                        xs, curveAdjustedContrast
                    ).map { ChartDataEntry(x: $0, y: $1) }
                )
            case let mode as LocationMode:
                brightnessChartEntry.reserveCapacity(mode.maxChartDataPoints)
                contrastChartEntry.reserveCapacity(mode.maxChartDataPoints)
                let points = mode.getBrightnessContrastBatch(
                    display: display,
                    brightnessFactor: display.brightnessCurveFactors[mode.key],
                    contrastFactor: display.contrastCurveFactors[mode.key]
                )

                let xs = stride(from: 0.0, to: (points.brightness.count - 1).d, by: 9.0)
                brightnessChartEntry.append(
                    contentsOf: zip(
                        xs, points.brightness.striding(by: 9)
                    ).map { ChartDataEntry(x: $0, y: $1) }
                )
                contrastChartEntry.append(
                    contentsOf: zip(
                        xs, points.contrast.striding(by: 9)
                    ).map { ChartDataEntry(x: $0, y: $1) }
                )
                mode.maxChartDataPoints = points.brightness.count
                setupLimitLines(mode, display: display, chartEntry: points)
            case let mode as SyncMode:
                let xs = stride(from: 0.0, to: (mode.maxChartDataPoints - 1).d, by: 6.0)
                brightnessChartEntry.reserveCapacity(mode.maxChartDataPoints)
                contrastChartEntry.reserveCapacity(mode.maxChartDataPoints)

                var values = mode.interpolateSIMD(.brightness(0), display: display, factor: display.brightnessCurveFactors[mode.key])
                if values.count < mode.maxChartDataPoints {
                    values += [Double](repeating: values.last!, count: mode.maxChartDataPoints - values.count)
                }
                brightnessChartEntry.append(
                    contentsOf: zip(
                        xs, values.striding(by: 6)
                    ).map { ChartDataEntry(x: $0, y: $1) }
                )

                values = mode.interpolateSIMD(.contrast(0), display: display, factor: display.contrastCurveFactors[mode.key])
                if values.count < mode.maxChartDataPoints {
                    values += [Double](repeating: values.last!, count: mode.maxChartDataPoints - values.count)
                }
                contrastChartEntry.append(
                    contentsOf: zip(
                        xs, values.striding(by: 6)
                    ).map { ChartDataEntry(x: $0, y: $1) }
                )
            case let mode as ManualMode:
                let xs = stride(from: 0.0, to: (mode.maxChartDataPoints - 1).d, by: 1.0)
                let percents = Array(stride(from: 0.0, to: (mode.maxChartDataPoints - 1).d / 100.0, by: 0.01))
                brightnessChartEntry.reserveCapacity(mode.maxChartDataPoints)
                contrastChartEntry.reserveCapacity(mode.maxChartDataPoints)
                brightnessChartEntry.append(
                    contentsOf: zip(
                        xs, mode.computeSIMD(
                            from: percents,
                            minVal: display.minBrightness.doubleValue,
                            maxVal: display.maxBrightness.doubleValue
                        )
                    ).map { ChartDataEntry(x: $0, y: $1) }
                )
                contrastChartEntry.append(
                    contentsOf: zip(
                        xs, mode.computeSIMD(
                            from: percents,
                            minVal: display.minContrast.doubleValue,
                            maxVal: display.maxContrast.doubleValue
                        )
                    ).map { ChartDataEntry(x: $0, y: $1) }
                )
            default:
                log.error("Unknown mode")
            }
            brightnessGraph.replaceEntries(brightnessChartEntry)
            contrastGraph.replaceEntries(contrastChartEntry)

            highlightValue(nil)
            for dataset in graphData.dataSets {
                graphData.removeDataSet(dataset)
            }
            graphData.append(brightnessGraph)
            graphData.append(contrastGraph)
        }

        brightnessGraph.colors = [NSColor.clear]
        brightnessGraph.fillColor = darkMode ? white.withAlphaComponent(0.5) : brightnessColor
        brightnessGraph.cubicIntensity = 0.15
        brightnessGraph.circleColors = darkMode ? [white] : [darkMauve.withAlphaComponent(0.6)]
        brightnessGraph.circleHoleColor = darkMode ? lunarYellow : white
        brightnessGraph.circleRadius = 4.0
        brightnessGraph.circleHoleRadius = darkMode ? 2.5 : 1.5
        brightnessGraph.drawCirclesEnabled = CachedDefaults[.moreGraphData] && adaptiveMode.key != .manual
        brightnessGraph.drawFilledEnabled = true
        brightnessGraph.drawValuesEnabled = false
        brightnessGraph.highlightColor = brightnessColor.withAlphaComponent(0.3)
        brightnessGraph.highlightLineWidth = 2
        brightnessGraph.highlightLineDashPhase = 3
        brightnessGraph.highlightLineDashLengths = [10, 6]
        brightnessGraph.mode = .cubicBezier

        contrastGraph.colors = [NSColor.clear]
        contrastGraph.fillColor = contrastColor
        contrastGraph.cubicIntensity = 0.15
        contrastGraph.circleColors = [lunarYellow.withAlphaComponent(0.9)]
        contrastGraph.circleRadius = 4.0
        contrastGraph.circleHoleRadius = 1.5
        contrastGraph.drawCirclesEnabled = CachedDefaults[.moreGraphData] && adaptiveMode.key != .manual
        contrastGraph.drawFilledEnabled = true
        contrastGraph.drawValuesEnabled = false
        contrastGraph.highlightColor = contrastColor.withAlphaComponent(0.9)
        contrastGraph.highlightLineWidth = 2
        contrastGraph.highlightLineDashPhase = 10
        contrastGraph.highlightLineDashLengths = [10, 6]
        contrastGraph.mode = .cubicBezier

        if CachedDefaults[.moreGraphData] {
            xAxis.labelTextColor = labelColor
            leftAxis.labelTextColor = labelColor
            rightAxis.labelTextColor = labelColor
        } else {
            xAxis.labelTextColor = .clear
            leftAxis.labelTextColor = .clear
            rightAxis.labelTextColor = .clear
        }

        mainThread { setupLegend() }

        data = graphData

        highlightCurrentValues(adaptiveMode: adaptiveMode, for: display)
        setup(mode: adaptiveMode.key)
    }

    func setupLimitLines(_: LocationMode? = nil, display _: Display, chartEntry _: LocationModeChartEntry? = nil) {
        xAxis.removeAllLimitLines()
        //        let mode = mode ?? LocationMode.specific
//        guard mode.moment != nil else { return }
//
//        let chartEntry = chartEntry ?? mode.lastChartEntry ?? mode.getBrightnessContrastBatch(display: display)
//        let sunriseLine = ChartLimitLine(
//            limit: chartEntry.sunriseIndex.d,
//            label: "Sunrise"
//        )
//        let solarNoonLine = ChartLimitLine(
//            limit: chartEntry.noonIndex.d,
//            label: "No on"
//        )
//        let sunsetLine = ChartLimitLine(
//            limit: chartEntry.sunsetIndex.d,
//            label: "Sunset"
//        )
//
//        sunsetLine.labelPosition = .leftTop
//        solarNoonLine.xOffset = -20
//
//        sunriseLine.yOffset = 75
//        sunsetLine.yOffset = 75
//        solarNoonLine.yOffset = 75
//
//        sunriseLine.lineDashPhase = 3.0
//        sunriseLine.lineDashLengths = [3.0, 1.0]
//        solarNoonLine.lineDashPhase = 2.0
//        solarNoonLine.lineDashLengths = [3.0, 1.0]
//        sunsetLine.lineDashPhase = 2.0
//        sunsetLine.lineDashLengths = [3.0, 1.0]
//
//        sunriseLine.valueFont = NSFont.systemFont(ofSize: 12, weight: .bold)
//        solarNoonLine.valueFont = NSFont.systemFont(ofSize: 12, weight: .bold)
//        sunsetLine.valueFont = NSFont.systemFont(ofSize: 12, weight: .bold)
//
//        sunriseLine.valueTextColor = xAxis.labelTextColor.withAlphaComponent(0.4)
//        solarNoonLine.valueTextColor = xAxis.labelTextColor.withAlphaComponent(0.4)
//        sunsetLine.valueTextColor = xAxis.labelTextColor.withAlphaComponent(0.4)
//
//        sunriseLine.lineColor = contrastGraph.fillColor.withAlphaComponent(0.7)
//        solarNoonLine.lineColor = (red.blended(withFraction: 0.5, of: lunarYellow) ?? red).withAlphaComponent(0.7)
//        solarNoonLine.valueTextColor = solarNoonLine.lineColor
//        sunsetLine.lineColor = brightnessGraph.fillColor.withAlphaComponent(0.7)
//
//        xAxis.addLimitLine(sunriseLine)
//        xAxis.addLimitLine(solarNoonLine)
//        xAxis.addLimitLine(sunsetLine)
    }

    func valueLegend(_ label: String, color: NSColor) -> LegendEntry {
        let valueLegend = LegendEntry(label: label)
        valueLegend.form = .square
        valueLegend.formSize = 14.0
        valueLegend.formLineWidth = 10.0
        valueLegend.formLineDashPhase = 10.0
        valueLegend.formLineDashLengths = nil
        valueLegend.formColor = color

        return valueLegend
    }

    func setupLegend() {
        legend.enabled = true
        legend.drawInside = true
        legend.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        legend.textColor = xAxisLabelColor
        legend.yOffset = 68.0
        legend.xOffset = 36.0
        legend.form = .square
        legend.formSize = 18.0
        legend.orientation = .vertical

        legend.setCustom(entries: [
            valueLegend("Brightness", color: brightnessGraph.fillColor.withAlphaComponent(0.4)),
            valueLegend("Contrast", color: contrastGraph.fillColor.withAlphaComponent(0.4)),
        ])
    }

    func setup(mode: AdaptiveModeKey? = nil) {
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
        rightAxis.drawGridLinesEnabled = CachedDefaults[.moreGraphData]
        rightAxis.drawAxisLineEnabled = false
        rightAxis.drawLabelsEnabled = CachedDefaults[.moreGraphData]
        rightAxis.labelFont = NSFont.systemFont(ofSize: 12, weight: .bold)
        rightAxis.labelPosition = .insideChart
        rightAxis.xOffset = 22.0
        rightAxis.gridColor = white.withAlphaComponent(0.3)
        rightAxis.drawZeroLineEnabled = false
        rightAxis.drawBottomYLabelEntryEnabled = false

        xAxis.drawGridLinesEnabled = CachedDefaults[.moreGraphData]
        xAxis.labelFont = NSFont.systemFont(ofSize: 12, weight: .bold)
        xAxis.labelPosition = .bottomInside
        xAxis.drawAxisLineEnabled = false
        xAxis.gridColor = white.withAlphaComponent(0.3)
        xAxis.drawLabelsEnabled = CachedDefaults[.moreGraphData]

        switch mode ?? displayController.adaptiveModeKey {
        case .location:
            xAxis.valueFormatter = ElevationValueFormatter()
            xAxis.setLabelCount(7, force: true)
        case .sensor:
            xAxis.valueFormatter = LuxValueFormatter()
            xAxis.setLabelCount(8, force: true)
        default:
            xAxis.valueFormatter = PercentValueFormatter()
            xAxis.setLabelCount(5, force: true)
        }

        chartDescription = Description()
        chartDescription.font = NSFont.systemFont(ofSize: 11.0, weight: .semibold)
        chartDescription.textColor = CachedDefaults[.moreGraphData] ? (red.blended(withFraction: 0.5, of: lunarYellow) ?? red)
            .withAlphaComponent(0.9) : .clear
        chartDescription.position = CGPoint(x: 920, y: 130)

        switch mode ?? displayController.adaptiveModeKey {
        case .location:
            chartDescription.text = "Brightness based on sun elevation"
        case .sync:
            chartDescription.text = ""
        case .sensor:
            chartDescription.text = ""
        case .manual, .clock, .auto:
            chartDescription.text = ""
        }

        setupLegend()

        noDataText = ""
        noDataTextColor = .clear
        animate(yAxisDuration: 1.5, easingOption: ChartEasingOption.easeOutExpo)
    }
}
