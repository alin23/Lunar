//
//  SensorMode.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import EonilFSEvents
import Foundation
import Path
import Regex

class SensorMode: AdaptiveMode {
    let key = AdaptiveModeKey.sensor

    static let volume = Path.root.Volumes / "LunarController"
    static let ambientLightPath = volume / "ambient-light"
    static let brightnessPath = volume / "brightness"
    static let contrastPath = volume / "contrast"
    static let brightnessPathRegex = try! Regex(pattern: "^brightness-(?:([\\w\\d]+)-)?([\\w\\d\\-]+)$", groupNames: "name", "shorthash")
    static let contrastPathRegex = try! Regex(pattern: "^contrast-(?:([\\w\\d]+)-)?([\\w\\d\\-]+)$", groupNames: "name", "shorthash")

    var available: Bool {
        SensorMode.ambientLightPath.exists ||
            SensorMode.brightnessPath.exists ||
            SensorMode.contrastPath.exists
    }

    var watching = false

    static func read(path: String = SensorMode.ambientLightPath.string) -> UInt8? {
        guard let path = Path(path) else { return nil }
        return read(path: path)
    }

    static func read(path: Path = SensorMode.ambientLightPath) -> UInt8? {
        guard let valueString = fm.contents(atPath: path.string) else { return nil }
        return UInt8(valueString.str())
    }

    func stopWatching() {
        EonilFSEvents.stopWatching(for: ObjectIdentifier(self))
        watching = false
    }

    func watch() -> Bool {
        guard !watching else { return true }
        do {
            try EonilFSEvents.startWatching(
                paths: [SensorMode.volume.string],
                for: ObjectIdentifier(self),
                with: { event in
                    guard let flags = event.flag, flags.contains(.itemModified) else {
                        return
                    }
                    if event.path == SensorMode.ambientLightPath.string,
                       let ambientLight = SensorMode.read(path: SensorMode.ambientLightPath)
                    {
                        displayController.onAdapt?(ambientLight)
                        for display in displayController.activeDisplays.values {
                            self.adapt(ambientLight: ambientLight, display: display)
                        }
                    }

                    if event.path == SensorMode.brightnessPath.string, let brightness = SensorMode.read(path: SensorMode.brightnessPath) {
                        displayController.setBrightness(brightness: brightness.ns)
                    }
                    if event.path == SensorMode.contrastPath.string, let contrast = SensorMode.read(path: SensorMode.contrastPath) {
                        displayController.setContrast(contrast: contrast.ns)
                    }

                    if let match = SensorMode.brightnessPathRegex.findFirst(in: event.path),
                       let displayID = match.group(named: "shorthash"),
                       let display = displayController.activeDisplaysByReadableID[displayID],
                       let brightness = SensorMode.read(path: event.path)
                    {
                        display.brightness = brightness.ns
                    }
                    if let match = SensorMode.contrastPathRegex.findFirst(in: event.path),
                       let displayID = match.group(named: "shorthash"),
                       let display = displayController.activeDisplaysByReadableID[displayID],
                       let contrast = SensorMode.read(path: event.path)
                    {
                        display.contrast = contrast.ns
                    }
                }
            )
        } catch {
            log.error("Error watching \(SensorMode.volume.string) for changes")
            return false
        }
        watching = true
        return true
    }

    func computeBrightnessContrast(ambientLight _: UInt8, display _: Display) -> (UInt8, UInt8) {
        return (0, 0)
    }

    func adapt(ambientLight: UInt8, display: Display) {
        let (brightness, contrast) = computeBrightnessContrast(ambientLight: ambientLight, display: display)
        display.brightness = brightness.ns
        display.contrast = contrast.ns
    }

    func adapt(_ display: Display) {
        guard let ambientLight = SensorMode.read(path: SensorMode.ambientLightPath) else { return }
        adapt(ambientLight: ambientLight, display: display)
    }
}
