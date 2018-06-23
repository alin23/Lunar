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
        if value == 0 {
            return "12AM"
        } else if value < 12 {
            return "\(value)AM"
        } else if value == 12 {
            return "12PM"
        }
        return "\(value % 12)PM"
    }
}
