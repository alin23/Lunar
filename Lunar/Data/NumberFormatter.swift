//
//  HourValueFormatter.swift
//  Lunar
//
//  Created by Alin on 18/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Charts
import Foundation
class HourValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        let value = value.i
        switch value {
        case 0 ... 2:
            return ""
        case 22 ... 25:
            return ""
        case 3 ..< 12:
            return "\(value)AM"
        case 12:
            return "12PM"
        default:
            return "\(value % 12)PM"
        }
    }
}

class ElevationValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        guard LocationMode.specific.moment != nil, let chartEntry = LocationMode.specific.lastChartEntry
        else { return "" }

        if value.i > chartEntry.noonIndex {
            return "\(chartEntry.noonIndex - (value.i - chartEntry.noonIndex) - LocationMode.specific.chartPadding)°"
        }
        return "\(value.i - LocationMode.specific.chartPadding)°"
    }
}

class PercentValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        if value == 100.0 || value == 0.0 {
            return ""
        }
        return "\(value.i)%"
    }
}

class LuxValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        if value == 0.0 {
            return ""
        }
        return "\(value.i) lux"
    }
}
