//
//  ManualMode.swift
//  Lunar
//
//  Created by Alin Panaitiu on 30.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Foundation

class ManualMode: AdaptiveMode {
    var key = AdaptiveModeKey.manual

    var available: Bool { true }

    func stopWatching() {}

    func watch() -> Bool {
        return true
    }

    func adapt(_: Display) {}
}
