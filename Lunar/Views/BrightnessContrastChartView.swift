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

final class BrightnessContrastChartView: LineChartView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    let brightnessGraph = LineChartDataSet(entries: [ChartDataEntry](), label: "Brightness")
    let contrastGraph = LineChartDataSet(entries: [ChartDataEntry](), label: "Contrast")
    let graphData = LineChartData()

    static func brightnessGradient(values: [Double], mode: AdaptiveModeKey) -> CGGradient? {
        let brColor = (darkMode ? white.withAlphaComponent(0.5) : violet).cgColor
        let subColor = (darkMode ? subzeroColor : subzeroColorDarker).cgColor

        let allSubZero = values.allSatisfy { $0 <= 0 }
        var locations: [CGFloat] = [0]
        var colors: [CGColor] = [allSubZero ? subColor : brColor]

        if !allSubZero {
            switch mode {
            case .sync:
                if let subzero = values.lastIndex(where: { $0 < 0 }) {
                    let loc = subzero.f / values.count.f
                    locations = [0, pow(loc, 2).cg, 1]
                    colors = [subColor, subColor, brColor]
                }
            case .sensor:
                if let subzero = values.lastIndex(where: { $0 < 0 }) {
                    let loc = (subzero.f + 1) / values.count.f
                    locations = [0, loc.cg]
                    colors = [subColor, brColor]
                }
            case .location:
                if let subzeroStart = values.firstIndex(where: { $0 >= 0 }), subzeroStart > 0,
                   let subzeroEnd = values.suffix(from: subzeroStart).firstIndex(where: { $0 < 0 })
                {
                    let start = (subzeroStart.f + 1) / values.count.f
                    let end = (subzeroEnd.f - 1) / values.count.f
                    locations = [0, start.cg, end.cg, 1]
                    colors = [subColor, brColor, brColor, subColor]
                }
            default:
                break
            }
        }

        guard let g = CGGradient(colorsSpace: .init(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: &locations) else {
            return nil
        }

        return g
    }

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

//    func highlightCurrentValues(
//        adaptiveMode: AdaptiveMode,
//        for display: Display?,
//        brightness: Double? = nil,
//        contrast: Double? = nil,
//        now: Date? = nil
//    ) {
//        mainAsync { [self] in
//            guard let data, data.dataSetCount >= 2 else { return }
//
//            guard CachedDefaults[.moreGraphData] else {
//                highlightValues(nil)
//                return
//            }
//
//            switch adaptiveMode {
//            case let mode as SensorMode:
//                guard let lux = mode.lastAmbientLight?.rounded() else { return }
//                var highlights: [Highlight] = []
//
//                let maxBr = datapointLock.around { mode.brightnessDataPoint.max.i }
//                let maxCr = datapointLock.around { mode.contrastDataPoint.max.i }
//
//                if (30 ... (maxBr - 30)).contains(lux.i) {
//                    highlights.append(Highlight(x: lux, dataSetIndex: 0, stackIndex: 0))
//                }
//                if (30 ... (maxCr - 30)).contains(lux.i) {
//                    highlights.append(Highlight(x: lux, dataSetIndex: 1, stackIndex: 1))
//                }
//                if highlights.isEmpty {
//                    highlightValues(nil)
//                } else {
//                    highlightValues(highlights)
//                }
//            case is SyncMode:
//                highlightValues([
//                    Highlight(x: SyncMode.lastSourceBrightness.rounded(), dataSetIndex: 0, stackIndex: 0),
//                    Highlight(x: SyncMode.lastSourceContrast.rounded(), dataSetIndex: 1, stackIndex: 1),
//                ])
//            case let mode as LocationMode:
//                guard let moment = mode.moment,
//                      let sunPosition = mode.geolocation?.sun(date: now),
//                      let solarNoonPosition = mode.geolocation?.solar?.solarNoonPosition,
//                      let chartEntry = mode.lastChartEntry
//                else { return }
//
//                let now = now?.in(region: .local) ?? DateInRegion().convertTo(region: .local)
//                let x: Double
//                if now < moment.solarNoon {
//                    x = cap(
//                        sunPosition.elevation.rounded(.down) + chartEntry.sunriseIndex.d,
//                        minVal: chartEntry.sunriseIndex.d,
//                        maxVal: chartEntry.noonIndex.d
//                    )
//                } else {
//                    x = cap(
//                        (solarNoonPosition.elevation.rounded(.down) - sunPosition.elevation.rounded(.down)) + chartEntry.noonIndex.d,
//                        minVal: chartEntry.noonIndex.d,
//                        maxVal: chartEntry.sunsetIndex.d
//                    )
//                }
//                highlightValues([
//                    Highlight(x: x, dataSetIndex: 0, stackIndex: 0),
//                    Highlight(x: x, dataSetIndex: 1, stackIndex: 1),
//                ])
//            case is ManualMode:
//                guard let display else { return }
//                highlightValues([
//                    Highlight(x: brightness ?? display.brightness.doubleValue, dataSetIndex: 0, stackIndex: 0),
//                    Highlight(x: contrast ?? display.contrast.doubleValue, dataSetIndex: 1, stackIndex: 1),
//                ])
//            default:
//                return
//            }
//        }
//    }

    func initGraph(display: Display?, mode: AdaptiveMode? = nil) {
        mainAsync { [self] in
            if display == nil || display?.id == GENERIC_DISPLAY_ID {
                isHidden = true
            } else {
                isHidden = false
            }
        }

        var brightnessChartEntry = brightnessGraph.entries
        var contrastChartEntry = contrastGraph.entries
        let adaptiveMode = mode ?? DC.adaptiveMode

        brightnessChartEntry.removeAll(keepingCapacity: false)
        contrastChartEntry.removeAll(keepingCapacity: false)
//        xAxis.removeAllLimitLines()

        let brColor = darkMode ? white.withAlphaComponent(0.5) : violet
        var gradient: CGGradient?

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

                let brcrs = xs.map { lux in
                    mode.computeBrightnessContrast(ambientLight: lux, display: display)
                }

                brightnessChartEntry.append(
                    contentsOf: zip(xs, brcrs.map(\.0)).map { ChartDataEntry(x: $0, y: $1) }
                )
                contrastChartEntry.append(
                    contentsOf: zip(xs, brcrs.map(\.1)).map { ChartDataEntry(x: $0, y: $1) }
                )
                gradient = BrightnessContrastChartView.brightnessGradient(values: brcrs.map(\.0), mode: .sensor)
            case let mode as LocationMode:
                brightnessChartEntry.reserveCapacity(mode.maxChartDataPoints)
                contrastChartEntry.reserveCapacity(mode.maxChartDataPoints)

                if let moment = mode.moment {
                    let xs = stride(from: moment.astronomicalSunrise, to: moment.astronomicalSunset, by: 40)
                    let brcrs = xs.map { datetime in
                        mode.getBrightnessContrast(
                            display: display,
                            hour: datetime.hour,
                            minute: datetime.minute
                        )
                    }

                    brightnessChartEntry.append(
                        contentsOf: zip(xs, brcrs.map(\.0)).map { ChartDataEntry(x: $0.timeIntervalSince(moment.astronomicalSunrise), y: $1) }
                    )
                    contrastChartEntry.append(
                        contentsOf: zip(xs, brcrs.map(\.1)).map { ChartDataEntry(x: $0.timeIntervalSince(moment.astronomicalSunrise), y: $1) }
                    )
                    gradient = BrightnessContrastChartView.brightnessGradient(values: brcrs.map(\.0), mode: .location)
                }
            case let mode as SyncMode:
//                if mode.isSyncingNits, let d = SyncMode.sourceDisplay {
//                    let xs = stride(from: display.adaptiveSubzero ? -100.0 : 0.0, to: d.maxNits, by: 20.0)
//                    brightnessChartEntry.reserveCapacity(mode.maxChartDataPoints)
//                    contrastChartEntry.reserveCapacity(mode.maxChartDataPoints)
//
//                    let brcrs = xs.map { sourceNits in
//                        mode.computeBrightnessContrast(nits: sourceNits, display: display)
//                    }
//                    brightnessChartEntry.append(
//                        contentsOf: zip(xs, brcrs.map(\.0)).map { ChartDataEntry(x: $0, y: $1) }
//                    )
//                    contrastChartEntry.append(
//                        contentsOf: zip(xs, brcrs.map(\.1)).map { ChartDataEntry(x: $0, y: $1) }
//                    )
//                } else {
                let xs = stride(from: display.adaptiveSubzero ? -100.0 : 0.0, to: 100.0, by: 12.0)
                brightnessChartEntry.reserveCapacity(mode.maxChartDataPoints)
                contrastChartEntry.reserveCapacity(mode.maxChartDataPoints)

                let brs = xs.map { sourceBrightness in
                    mode.interpolate(sourceBrightness, display: display)
                }

                brightnessChartEntry.append(
                    contentsOf: zip(xs, brs).map { ChartDataEntry(x: $0, y: $1) }
                )

                let crs = xs.map { sourceContrast in
                    mode.interpolate(sourceContrast, display: display, contrast: true)
                }
                contrastChartEntry.append(
                    contentsOf: zip(xs, crs).map { ChartDataEntry(x: $0, y: $1) }
                )
                gradient = BrightnessContrastChartView.brightnessGradient(values: brs, mode: .sync)
            case is ManualMode:
                brightnessChartEntry = [ChartDataEntry(x: 0, y: display.minBrightness.doubleValue), ChartDataEntry(x: 100, y: display.maxBrightness.doubleValue)]
                contrastChartEntry = [ChartDataEntry(x: 0, y: display.minContrast.doubleValue), ChartDataEntry(x: 100, y: display.maxContrast.doubleValue)]
            default:
                log.error("Unknown mode")
            }
            brightnessGraph.replaceEntries(brightnessChartEntry)
            contrastGraph.replaceEntries(contrastChartEntry)

//            highlightValue(nil)
            for dataset in graphData.dataSets {
                graphData.removeDataSet(dataset)
            }
            graphData.append(brightnessGraph)
            graphData.append(contrastGraph)
        }

        brightnessGraph.colors = [NSColor.clear]
        if let gradient {
            brightnessGraph.fill = LinearGradientFill(gradient: gradient)
        } else {
            brightnessGraph.fill = nil
            brightnessGraph.fillColor = brColor
        }
        brightnessGraph.cubicIntensity = 0.15
        brightnessGraph.circleColors = darkMode ? [white] : [darkMauve.withAlphaComponent(0.6)]
        brightnessGraph.circleHoleColor = darkMode ? lunarYellow : white
        brightnessGraph.circleRadius = 4.0
        brightnessGraph.circleHoleRadius = darkMode ? 2.5 : 1.5
        brightnessGraph.drawCirclesEnabled = CachedDefaults[.moreGraphData] && adaptiveMode.key != .manual
        brightnessGraph.drawFilledEnabled = true
        brightnessGraph.fillFormatter = DefaultFillFormatter(block: { dataSet, _ in
            CGFloat(dataSet.yMin - 200)
        })
        brightnessGraph.drawValuesEnabled = false
        brightnessGraph.highlightColor = violet.withAlphaComponent(0.3)
        brightnessGraph.highlightLineWidth = 2
        brightnessGraph.highlightLineDashPhase = 3
        brightnessGraph.highlightLineDashLengths = [10, 6]
        brightnessGraph.mode = .cubicBezier

        contrastGraph.colors = [NSColor.clear]
        contrastGraph.fillColor = lunarYellow
        contrastGraph.cubicIntensity = 0.15
        contrastGraph.circleColors = [lunarYellow.withAlphaComponent(0.9)]
        contrastGraph.circleRadius = 4.0
        contrastGraph.circleHoleRadius = 1.5
        contrastGraph.drawCirclesEnabled = CachedDefaults[.moreGraphData] && adaptiveMode.key != .manual
        contrastGraph.drawFilledEnabled = true
        contrastGraph.fillFormatter = DefaultFillFormatter(block: { dataSet, _ in
            CGFloat(dataSet.yMin - 200)
        })
        contrastGraph.drawValuesEnabled = false
        contrastGraph.highlightColor = lunarYellow.withAlphaComponent(0.9)
        contrastGraph.highlightLineWidth = 2
        contrastGraph.highlightLineDashPhase = 10
        contrastGraph.highlightLineDashLengths = [10, 6]
        contrastGraph.mode = .cubicBezier

        if let display {
            contrastGraph.visible = !display.lockedContrast && display.hasDDC
        }

        if CachedDefaults[.moreGraphData] {
            xAxis.labelTextColor = xAxisLabelColor
            leftAxis.labelTextColor = xAxisLabelColor
            rightAxis.labelTextColor = xAxisLabelColor
        } else {
            xAxis.labelTextColor = .clear
            leftAxis.labelTextColor = .clear
            rightAxis.labelTextColor = .clear
        }

//        mainThread {
//            setupLegend(display: display)
//        }

        data = graphData

//        highlightCurrentValues(adaptiveMode: adaptiveMode, for: display)
        setup(mode: adaptiveMode.key, display: display)
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

    func setupLegend(display: Display? = nil) {
        let lockedContrast = display?.lockedContrast ?? true
        let hasDDC = display?.hasDDC ?? false

        legend.enabled = !lockedContrast
        legend.drawInside = !lockedContrast
        legend.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        legend.textColor = xAxisLabelColor
        legend.yOffset = 68.0
        legend.xOffset = 36.0
        legend.form = .square
        legend.formSize = 18.0
        legend.orientation = .vertical

        if !lockedContrast, hasDDC {
            legend.setCustom(entries: [
                valueLegend("Brightness", color: (darkMode ? white : violet).withAlphaComponent(0.4)),
                valueLegend("Contrast", color: contrastGraph.fillColor.withAlphaComponent(0.4)),
            ])
        } else {
            legend.setCustom(entries: [])
        }
    }
    func setup(mode: AdaptiveModeKey? = nil, display: Display? = nil) {
        gridBackgroundColor = NSColor.clear
        drawGridBackgroundEnabled = false
        drawBordersEnabled = false
        autoScaleMinMaxEnabled = false

        let adaptiveSubzero = (mode == .manual || display == nil) ? false : (display!.adaptiveSubzero)
        leftAxis.axisMaximum = 100
        leftAxis.axisMinimum = adaptiveSubzero ? -100 : 0
        leftAxis.drawGridLinesEnabled = false
        leftAxis.drawAxisLineEnabled = false
        leftAxis.drawLabelsEnabled = false

        let moreData = CachedDefaults[.moreGraphData]
        rightAxis.axisMaximum = 100
        rightAxis.axisMinimum = adaptiveSubzero ? -100 : 0
        rightAxis.drawGridLinesEnabled = moreData
        rightAxis.drawAxisLineEnabled = false
        rightAxis.drawLabelsEnabled = moreData
        rightAxis.labelFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        rightAxis.labelPosition = .insideChart
        rightAxis.xOffset = 22.0
        rightAxis.gridColor = white.withAlphaComponent(0.3)
        rightAxis.drawZeroLineEnabled = false
        rightAxis.drawBottomYLabelEntryEnabled = false
        rightAxis.setLabelCount(7, force: true)

        xAxis.drawGridLinesEnabled = moreData
        xAxis.labelFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        xAxis.labelPosition = .bottomInside
        xAxis.drawAxisLineEnabled = false
        xAxis.gridColor = white.withAlphaComponent(0.3)
        xAxis.drawLabelsEnabled = moreData

        switch mode ?? DC.adaptiveModeKey {
        case .location:
            xAxis.valueFormatter = DateValueFormatter()
            xAxis.setLabelCount(7, force: true)
        case .sensor:
            xAxis.valueFormatter = LuxValueFormatter()
            xAxis.setLabelCount(7, force: true)
//        case .sync where SyncMode.specific.isSyncingNits:
//            xAxis.valueFormatter = NitsValueFormatter()
//            xAxis.setLabelCount(7, force: true)
        default:
            xAxis.valueFormatter = PercentValueFormatter()
            xAxis.setLabelCount(5, force: true)
        }

        setupLegend(display: display)

        noDataText = ""
        noDataTextColor = .clear
        animate(yAxisDuration: 1.5, easingOption: ChartEasingOption.easeOutExpo)
    }
}

extension DateInRegion: Strideable { // @retroactive Strideable {
    public func advanced(by n: Int) -> DateInRegion {
        dateByAdding(n, .minute)
    }

    public func distance(to other: DateInRegion) -> Int {
        other.difference(in: .minute, from: self) ?? 0
    }

}
