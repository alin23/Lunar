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
    let interpolationValues = 10
    let maxValuesLocation = 25
    let maxValuesSync = 102

    func zero() {
        for (brightnessEntry, contrastEntry) in zip(brightnessGraph.values, contrastGraph.values) {
            brightnessEntry.y = 0
            contrastEntry.y = 0
        }
        notifyDataSetChanged()
    }

    func squared(x: Double) -> Double {
        return (x * x)
    }

    func inverseSquared(x: Double) -> Double {
        return 1 - (1 - x) * (1 - x)
    }

    func interpolateWith(count: Int, interpolationFunction: (Double) -> Double) -> [Double] {
        var values = [Double](repeating: 0.0, count: count)
        let n = Double(count)
        for i in stride(from: 0.0, to: n, by: 1.0) {
            let v = i / n
            values[Int(i)] = interpolationFunction(v)
        }
        return values
    }

    func catmullRom(t: Double, _ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double) -> Double {
        return 0.5 * (
            (2 * p1) +
                (-p0 + p2) * t +
                (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
                (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t
        )
    }

    func spline(x0: Double, x1: Double, x2: Double, x3: Double) -> [Double] {
        if x1 == x2 {
            return [Double](repeating: x1, count: interpolationValues)
        }
        let d = x2 - x1
        let x0 = -15.0 - (x1 - x0) / d
        let x3 = 7.5 + (x3 - x2) / d
        return interpolateWith(count: interpolationValues) { x in
            catmullRom(t: x, x0, 0.0, 1.0, x3) * d + x1
        }
    }

    func getInterpolatedValues(display: Display?) {
        var brightnessChartEntry = brightnessGraph.values
        var contrastChartEntry = contrastGraph.values

        var brightnessPoints = [Double](repeating: 0.0, count: maxValuesLocation)
        var contrastPoints = [Double](repeating: 0.0, count: maxValuesLocation)

        brightnessChartEntry.reserveCapacity(maxValuesLocation * interpolationValues)
        contrastChartEntry.reserveCapacity(maxValuesLocation * interpolationValues)
        for x in 0 ..< (maxValuesLocation - 1) {
            if let display = display, display.id != GENERIC_DISPLAY_ID {
                let (brightness, contrast) = brightnessAdapter.getBrightnessContrast(for: display, hour: x)
                brightnessPoints[x] = brightness.doubleValue
                contrastPoints[x] = contrast.doubleValue
            }
        }
        brightnessChartEntry.append(contentsOf: spline(x0: brightnessPoints[0] - 1.0, x1: brightnessPoints[0], x2: brightnessPoints[1], x3: brightnessPoints[2]).map { y in ChartDataEntry(x: 0.0, y: y) })
        contrastChartEntry.append(contentsOf: spline(x0: contrastPoints[0] - 1.0, x1: contrastPoints[0], x2: contrastPoints[1], x3: contrastPoints[2]).map { y in ChartDataEntry(x: 0.0, y: y) })
        for x in 2 ..< (maxValuesLocation - 2) {
            brightnessChartEntry.append(contentsOf: spline(x0: brightnessPoints[x - 2], x1: brightnessPoints[x - 1], x2: brightnessPoints[x], x3: brightnessPoints[x + 1]).map { y in ChartDataEntry(x: Double(x), y: y) })
            contrastChartEntry.append(contentsOf: spline(x0: contrastPoints[x - 2], x1: contrastPoints[x - 1], x2: contrastPoints[x], x3: contrastPoints[x + 1]).map { y in ChartDataEntry(x: Double(x), y: y) })
        }
        brightnessChartEntry.append(contentsOf: spline(x0: brightnessPoints[maxValuesLocation - 4], x1: brightnessPoints[maxValuesLocation - 3], x2: brightnessPoints[maxValuesLocation - 2], x3: brightnessPoints[maxValuesLocation - 2] - 1.0).map { y in ChartDataEntry(x: Double(maxValuesLocation) - 2.0, y: y) })
        contrastChartEntry.append(contentsOf: spline(x0: contrastPoints[maxValuesLocation - 4], x1: contrastPoints[maxValuesLocation - 3], x2: contrastPoints[maxValuesLocation - 2], x3: contrastPoints[maxValuesLocation - 2] - 1.0).map { y in ChartDataEntry(x: Double(maxValuesLocation) - 2.0, y: y) })
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
        switch adaptiveMode {
        case .location:
            brightnessChartEntry.reserveCapacity(maxValuesLocation)
            contrastChartEntry.reserveCapacity(maxValuesLocation)
            for x in 0 ..< (maxValuesLocation - 1) {
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
        case .sync:
            brightnessChartEntry.reserveCapacity(maxValuesSync)
            contrastChartEntry.reserveCapacity(maxValuesSync)
            for x in 0 ..< (maxValuesSync - 1) {
                let percent = Double(x)
                if let display = display, display.id != GENERIC_DISPLAY_ID {
                    brightnessY = display.computeBrightness(from: percent).doubleValue
                    contrastY = display.computeContrast(from: percent).doubleValue
                }
                brightnessChartEntry.append(ChartDataEntry(x: percent, y: brightnessY))
                contrastChartEntry.append(ChartDataEntry(x: percent, y: contrastY))
            }
        case .manual:
            brightnessChartEntry.reserveCapacity(maxValuesSync)
            contrastChartEntry.reserveCapacity(maxValuesSync)
            for x in 0 ..< (maxValuesSync - 1) {
                let percent = Double(x)
                if let display = display, display.id != GENERIC_DISPLAY_ID {
                    brightnessY = brightnessAdapter.computeManualValueFromPercent(percent: Int8(x), key: "brightness").doubleValue
                    contrastY = brightnessAdapter.computeManualValueFromPercent(percent: Int8(x), key: "contrast").doubleValue
                }
                brightnessChartEntry.append(ChartDataEntry(x: percent, y: brightnessY))
                contrastChartEntry.append(ChartDataEntry(x: percent, y: contrastY))
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
        //  brightnessGraph.mode = .cubicBezier
        //  brightnessGraph.cubicIntensity = 0.1

        contrastGraph.colors = [NSColor.clear]
        contrastGraph.fillColor = contrastColor
        contrastGraph.drawCirclesEnabled = false
        contrastGraph.drawFilledEnabled = true
        contrastGraph.drawValuesEnabled = false
        // contrastGraph.mode = .cubicBezier
        // contrastGraph.cubicIntensity = 0.1

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
