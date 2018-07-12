//
//  HourValueFormatter.swift
//  Lunar
//
//  Created by Alin on 18/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Charts
import Foundation
class HourValueFormatter: IAxisValueFormatter {
    func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        let value = Int(value)
        switch value {
        case 0:
            return "12AM"
        case 1 ..< 12:
            return "\(value)AM"
        case 12:
            return "12PM"
        default:
            return "\(value % 12)PM"
        }
    }
}

class PercentValueFormatter: IAxisValueFormatter {
    func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        if value == 100.0 || value == 0.0 {
            return ""
        }
        return "\(Int(value))%"
    }
}
