//
//  CLI.swift
//  Lunar
//
//  Created by Alin Panaitiu on 12.04.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import AnyCodable
import ArgumentParser
import Cocoa
import Dispatch
import Foundation
import FuzzyFind
import Regex
import SwiftyJSON

let globalExit = exit

private let UPPERCASE_LETTER_NAMES = #"e\s?d\s?i\s?d|id|d\s?d\s?c"#.r!
var encoder: JSONEncoder = {
    var encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
}()

var decoder = JSONDecoder()

private var prettyEncoder: JSONEncoder = {
    var encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
}()

// MARK: - CommandError

private enum CommandError: Error, CustomStringConvertible {
    case displayNotFound(String)
    case propertyNotValid(String)
    case cantReadProperty(String)
    case controlNotAvailable(String)
    case serializationError(String)
    case invalidValue(String)
    case ddcError(String)
    case gammaError(String)
    case noUUID(CGDirectDisplayID)

    // MARK: Internal

    var description: String {
        switch self {
        case let .displayNotFound(string):
            return "Display Not Found: \(string)"
        case let .propertyNotValid(string):
            return "Property Not Valid: \(string)"
        case let .cantReadProperty(string):
            return "Cant Read Property: \(string)"
        case let .controlNotAvailable(string):
            return "Control Not Available: \(string)"
        case let .serializationError(string):
            return "Serialization Error: \(string)"
        case let .invalidValue(string):
            return "Invalid Value: \(string)"
        case let .ddcError(string):
            return "DDC Error: \(string)"
        case let .gammaError(string):
            return "Gamma Error: \(string)"
        case let .noUUID(cgDirectDisplayID):
            return "No UUID for \(cgDirectDisplayID)"
        }
    }
}

private func printArray(_ array: [Any], level: Int = 0, longestKeySize: Int = 0) {
    let indentation = level > 0 ? String(repeating: "  ", count: level) : ""
    for value in array {
        switch value {
        case let nestedDict as [String: Any]:
            printDictionary(nestedDict, level: level + 1, longestKeySize: longestKeySize)
        case let nestedArray as [Any]:
            printArray(nestedArray, level: level + 1, longestKeySize: longestKeySize)
        default:
            print("\(indentation)\(String(describing: value).replacingOccurrences(of: "\n", with: "\n\(indentation)"))")
        }
    }
}

private func printDictionary(_ dict: [String: Any], level: Int = 0, longestKeySize: Int = 0) {
    let indentation = level > 0 ? String(repeating: "  ", count: level) : ""
    let dict = dict.sorted(by: { $0.key <= $1.key })
    let longestKeySize = max(longestKeySize, dict.max(by: { $0.key.count <= $1.key.count })?.key.count ?? 1)

    for (key, value) in dict {
        switch value {
        case let nestedDict as [String: Any]:
            print("\(indentation)\(spaced(key, longestKeySize))")
            printDictionary(nestedDict, level: level + 1, longestKeySize: longestKeySize)
        case let nestedArray as [Any]:
            printArray(nestedArray, level: level + 1, longestKeySize: longestKeySize)
        default:
            print("\(indentation)\(spaced(key, longestKeySize))\(String(describing: value).replacingOccurrences(of: "\n", with: "\n\t"))")
        }
    }
}

// MARK: - NSDeviceDescriptionKey + Encodable

extension NSDeviceDescriptionKey: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try! container.encode(rawValue)
    }
}

// MARK: - ForgivingEncodable

struct ForgivingEncodable: Encodable {
    // MARK: Lifecycle

    init(_ value: Any?) {
        self.value = value
    }

    // MARK: Internal

    var value: Any?

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNumber, is NSNull, is Void, is Bool, is Int, is Int8, is Int16, is Int32, is Int64, is UInt, is UInt8, is UInt16,
             is UInt32, is UInt64, is Float, is Double, is String, is Date, is URL:
            try AnyEncodable(value).encode(to: encoder)
        case let data as Data:
            try container.encode(data.str(base64: true))
        case let array as [PersistentHotkey]:
            print(array)
            try container.encode(array)
        case let array as [Any?]:
            try container.encode(array.map { ForgivingEncodable($0) })
        case let dictionary as [String: Any?]:
            try container.encode(dictionary.mapValues { ForgivingEncodable($0) })
        case let dictionary as [NSDeviceDescriptionKey: Any?]:
            try container.encode(dictionary.mapValues { ForgivingEncodable($0) })
        default:
            try container.encode("Value is not serializable")
        }
    }
}

private func getDisplay(displays: [Display], filter: String) -> Display? {
    switch filter {
    case "first":
        return displays.first
    case "main":
        guard let mainDisplayId = displayController.mainExternalDisplay?.id else { return nil }
        return displays.first(where: { $0.id == mainDisplayId })
    case "best-guess":
        guard let currentDisplayId = displayController.mainExternalOrCGMainDisplay?.id else { return nil }
        return displays.first(where: { $0.id == currentDisplayId })
    case "builtin":
        return displayController.activeDisplays.values.first(where: { $0.isBuiltin })
    default:
        if let id = filter.u32 {
            return displays.first(where: { $0.id == id })
        } else if let display = displays.first(where: { $0.serial == filter }) {
            return display
        } else {
            let alignments = fuzzyFind(queries: [filter], inputs: displays.map(\.name))
            guard let name = alignments.first?.result.asString else { return nil }

            return displays.first(where: { $0.name == name })
        }
    }
}

// MARK: - Lunar

struct Lunar: ParsableCommand {
    struct GlobalOptions: ParsableArguments {
        @Flag(name: .shortAndLong, help: "Log errors and warnings.")
        var log = false

        @Flag(name: .shortAndLong, help: "Enable debug logging.")
        var debug = false

        @Flag(name: .shortAndLong, help: "Enable verbose logging.")
        var verbose = false
    }

    struct Signature: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Prints code signature of the app."
        )

        @OptionGroup var globals: GlobalOptions

        @Flag(help: "If the output should be printed as hex.")
        var hex = false

        func run() throws {
            Lunar.configureLogging(options: globals)

            guard let sig = getCodeSignature(hex: hex) else {
                globalExit(1)
            }
            print(sig)
            globalExit(0)
        }
    }

    struct Lid: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Prints if lid is closed or opened."
        )

        @OptionGroup var globals: GlobalOptions

        func run() throws {
            Lunar.configureLogging(options: globals)

            if isLidClosed() {
                print("closed")
            } else {
                print("opened")
            }
            globalExit(0)
        }
    }

    struct Lux: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Prints ambient light in lux (or -1 if the sensor can't be read)."
        )

        @OptionGroup var globals: GlobalOptions

        func run() throws {
            Lunar.configureLogging(options: globals)
            print(SensorMode.getInternalSensorLux() ?? -1)
            globalExit(0)
        }
    }

    struct Ddcctl: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Control monitors using the ddcctl utility: https://github.com/kfix/ddcctl"
        )

        @Argument var args: [String] = []

        func run() throws {
            globalExit(0)
        }
    }

    struct Launch: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Launch Lunar app"
        )

        @Argument var args: [String] = []

        func run() throws {
            globalExit(0)
        }
    }

    struct CoreDisplay: ParsableCommand {
        enum AppleNativeMethod: String, ExpressibleByArgument, CaseIterable {
            case GetUserBrightness
            case GetLinearBrightness
            case GetDynamicLinearBrightness
            case SetUserBrightness
            case SetLinearBrightness
            case SetDynamicLinearBrightness
            case SetAutoBrightnessIsEnabled
        }

        static let configuration = CommandConfiguration(
            abstract: "Use CoreDisplay methods on monitors."
        )

        @OptionGroup var globals: GlobalOptions

        @Argument(help: "Method to call. One of (\(AppleNativeMethod.allCases.map(\.rawValue).joined(separator: ", ")))")
        var method: AppleNativeMethod

        @Argument(help: "Display serial/name/id or one of (first, main, all, builtin, source)")
        var display: String

        @Argument(help: "Value for the method's second argument")
        var value = 1.0

        func run() throws {
            Lunar.configureLogging(options: globals)

            displayController.displays = DisplayController.getDisplays(
                includeVirtual: false,
                includeAirplay: false,
                includeProjector: false,
                includeDummy: false
            )
            let displays = displayController.activeDisplays.values.map { $0 }
            var displayIDs: [CGDirectDisplayID] = []

            switch display {
            case "all":
                displayIDs = displays.map(\.id)
            case "builtin":
                guard let id = displayController.builtinDisplay?.id else {
                    throw CommandError.displayNotFound(display)
                }
                displayIDs = [id]
            case "source":
                guard let id = displayController.sourceDisplay?.id else {
                    throw CommandError.displayNotFound(display)
                }
                displayIDs = [id]
            default:
                guard let display = getDisplay(displays: displays, filter: display) else {
                    throw CommandError.displayNotFound(display)
                }
                displayIDs = [display.id]
            }

            for id in displayIDs {
                switch method {
                case .GetUserBrightness:
                    print(CoreDisplay_Display_GetUserBrightness(id))
                case .GetLinearBrightness:
                    print(CoreDisplay_Display_GetLinearBrightness(id))
                case .GetDynamicLinearBrightness:
                    print(CoreDisplay_Display_GetDynamicLinearBrightness(id))
                case .SetUserBrightness:
                    print("Setting UserBrightness to \(value) for ID: \(id)")
                    CoreDisplay_Display_SetUserBrightness(id, value)
                case .SetLinearBrightness:
                    print("Setting LinearBrightness to \(value) for ID: \(id)")
                    CoreDisplay_Display_SetLinearBrightness(id, value)
                case .SetDynamicLinearBrightness:
                    print("Setting DynamicLinearBrightness to \(value) for ID: \(id)")
                    CoreDisplay_Display_SetDynamicLinearBrightness(id, value)
                case .SetAutoBrightnessIsEnabled:
                    print("Setting AutoBrightnessIsEnabled to \(value > 0) for ID: \(id)")
                    CoreDisplay_Display_SetAutoBrightnessIsEnabled(id, value > 0)
                }
            }
            globalExit(0)
        }
    }

    struct DisplayServices: ParsableCommand {
        enum DisplayServicesMethod: String, ExpressibleByArgument, CaseIterable {
            case GetLinearBrightness
            case SetLinearBrightness
            case GetBrightness
            case SetBrightness
            case SetBrightnessSmooth
            case CanChangeBrightness
            case IsSmartDisplay
            case BrightnessChanged

            case GetPowerMode
            case SetPowerMode

            case GetBrightnessIncrement
            case NeedsBrightnessSmoothing
            case EnableAmbientLightCompensation
            case AmbientLightCompensationEnabled
            case HasAmbientLightCompensation
            case ResetAmbientLight
            case ResetAmbientLightAll
            case CanResetAmbientLight
            case GetLinearBrightnessUsableRange
            case CreateBrightnessTable
            case RegisterForBrightnessChangeNotifications
            case RegisterForAmbientLightCompensationNotifications
            case SetBrightnessWithType
        }

        static let configuration = CommandConfiguration(
            abstract: "Use DisplayServices methods on monitors."
        )

        @OptionGroup var globals: GlobalOptions

        @Argument(help: "Method to call. One of (\(DisplayServicesMethod.allCases.map(\.rawValue).joined(separator: ", ")))")
        var method: DisplayServicesMethod

        @Argument(help: "Display serial/name/id or one of (first, main, all, builtin, source)")
        var display: String

        @Argument(help: "Value for the method's second argument")
        var value = 1.0

        @Argument(help: "Value for the method's third argument")
        var value2: Double = 0

        func run() throws {
            Lunar.configureLogging(options: globals)

            displayController.displays = DisplayController.getDisplays(
                includeVirtual: false,
                includeAirplay: false,
                includeProjector: false,
                includeDummy: false
            )
            let displays = displayController.activeDisplays.values.map { $0 }
            var displayIDs: [CGDirectDisplayID] = []

            switch display {
            case "all":
                displayIDs = displays.map(\.id)
            case "builtin":
                guard let id = displayController.builtinDisplay?.id else {
                    throw CommandError.displayNotFound(display)
                }
                displayIDs = [id]
            case "source":
                guard let id = displayController.sourceDisplay?.id else {
                    throw CommandError.displayNotFound(display)
                }
                displayIDs = [id]
            default:
                guard let display = getDisplay(displays: displays, filter: display) else {
                    throw CommandError.displayNotFound(display)
                }
                displayIDs = [display.id]
            }

            for id in displayIDs {
                var brightness: Float = value.f
                let type: UInt32 = value2.u32
                switch method {
                case .GetLinearBrightness:
                    DisplayServicesGetLinearBrightness(id, &brightness)
                    print(value)
                case .SetLinearBrightness:
                    print("Setting LinearBrightness to \(brightness) for ID: \(id)")
                    DisplayServicesSetLinearBrightness(id, brightness)
                case .GetBrightness:
                    DisplayServicesGetBrightness(id, &brightness)
                    print(brightness)
                case .SetBrightness:
                    print("Setting Brightness to \(brightness) for ID: \(id)")
                    DisplayServicesSetBrightness(id, brightness)
                case .SetBrightnessSmooth:
                    print("Setting BrightnessSmooth to \(brightness) for ID: \(id)")
                    DisplayServicesSetBrightnessSmooth(id, brightness)
                case .SetBrightnessWithType:
                    print("Setting BrightnessWithType to \(brightness) with type \(type) for ID: \(id)")
                    DisplayServicesSetBrightnessWithType(id, type, brightness)
                case .CanChangeBrightness:
                    print(DisplayServicesCanChangeBrightness(id))
                case .IsSmartDisplay:
                    print(DisplayServicesIsSmartDisplay(id))
                case .BrightnessChanged:
                    print("Sending brightness change notification")
                    DisplayServicesBrightnessChanged(id, value)

                case .GetPowerMode:
                    print(DisplayServicesGetPowerMode(id))
                case .SetPowerMode:
                    print(DisplayServicesSetPowerMode(id, value.u8))

                case .GetBrightnessIncrement:
                    print(DisplayServicesGetBrightnessIncrement(id))
                case .NeedsBrightnessSmoothing:
                    print(DisplayServicesNeedsBrightnessSmoothing(id))
                case .EnableAmbientLightCompensation:
                    print(DisplayServicesEnableAmbientLightCompensation(id, value == 1))
                case .AmbientLightCompensationEnabled:
                    var enabled = false
                    print(DisplayServicesAmbientLightCompensationEnabled(id, &enabled))
                    print(enabled)
                case .HasAmbientLightCompensation:
                    print(DisplayServicesHasAmbientLightCompensation(id))
                case .ResetAmbientLight:
                    print(DisplayServicesResetAmbientLight(id, id))
                case .ResetAmbientLightAll:
                    print(DisplayServicesResetAmbientLightAll())
                case .CanResetAmbientLight:
                    print(DisplayServicesCanResetAmbientLight(id, 1))
                case .GetLinearBrightnessUsableRange:
                    var min: Int32 = 0
                    var max: Int32 = 0
                    print(DisplayServicesGetLinearBrightnessUsableRange(id, &min, &max))
                    print("\(min) - \(max)")
                case .CreateBrightnessTable:
                    guard let table = DisplayServicesCreateBrightnessTable(id, value.i32) as? [Int] else { globalExit(0) }
                    print(table)
                case .RegisterForBrightnessChangeNotifications:
                    let result = DisplayServicesRegisterForBrightnessChangeNotifications(id, id) { _, observer, _, _, userInfo in
                        guard let value = (userInfo as NSDictionary?)?["value"] as? Double, let id = observer else { return }
                        let displayID = CGDirectDisplayID(UInt(bitPattern: id))

                        if let display = displayController.activeDisplays[displayID] {
                            print("\(display) => \(value)")
                        } else {
                            print("\(displayID) => \(value)")
                        }
                    }
                    print("RegisterForBrightnessChangeNotifications result: \(result)")
                case .RegisterForAmbientLightCompensationNotifications:
                    let result = DisplayServicesRegisterForAmbientLightCompensationNotifications(id, id) { _, observer, _, _, userInfo in
                        guard let value = (userInfo as NSDictionary?)?["value"] as? Double, let id = observer else { return }
                        let displayID = CGDirectDisplayID(UInt(bitPattern: id))

                        if let display = displayController.activeDisplays[displayID] {
                            print("\(display) => \(value)")
                        } else {
                            print("\(displayID) => \(value)")
                        }
                    }
                    print("RegisterForAmbientLightCompensationNotifications result: \(result)")
                }
            }
            guard method != .RegisterForAmbientLightCompensationNotifications,
                  method != .RegisterForBrightnessChangeNotifications
            else {
                return
            }
            globalExit(0)
        }
    }

    struct Ddc: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Send DDC messages to connected monitors."
        )

        static let controlStrings = ControlID.allCases.map { String(describing: $0) }.chunks(ofCount: 2)
        static let longestString = (controlStrings.compactMap(\.first).max(by: { $0.count <= $1.count })?.count ?? 1) + 2

        @OptionGroup var globals: GlobalOptions

        @Argument(help: "Display serial/name/id or one of (first, main, all)")
        var display: String

        @Argument(
            help: "DDC control ID (VCP)\n\tCan be passed as hex VCP values (e.g. 0x10, E1) or constants\n\tPossible constants:\n\t\t\(controlStrings.map { $0.joined(separator: String(repeating: " ", count: longestString - ($0.first?.count ?? 0))) }.joined(separator: "\n\t\t"))"
        )
        var control: ControlID

        @Flag(name: .long, help: "Parse values as hex")
        var hex = false

        @Argument(
            help: "Value(s) to set for the control. Pass the value 'read' to fetch the current value from the monitor. Pass 'readmax' to fetch the max value for the control."
        )
        var values: [String]

        func run() throws {
            Lunar.configureLogging(options: globals)

            displayController.displays = DisplayController.getDisplays(
                includeVirtual: false,
                includeAirplay: false,
                includeProjector: false,
                includeDummy: false
            )
            var displays = displayController.activeDisplays.values.map { $0 }
            if display != "all" {
                guard let display = getDisplay(displays: displays, filter: display) else {
                    throw CommandError.displayNotFound(display)
                }
                displays = [display]
            }

            if values.isEmpty || values.first!.lowercased() =~ "(read|get|fetch)-?(max|val)?" {
                let max = values.first?.lowercased().hasSuffix("max") ?? false
                for display in displays {
                    if let result = DDC.read(displayID: display.id, controlID: control) {
                        if displays.count == 1 {
                            print(max ? result.maxValue : result.currentValue)
                        } else {
                            print("\(display): \(max ? result.maxValue : result.currentValue)")
                        }
                    } else {
                        if displays.count == 1 {
                            throw CommandError.ddcError("Can't read \(control) for display \(display)")
                        }
                        print("\(display): Can't read \(control)")
                    }
                }
                globalExit(0)
            }

            for display in displays {
                for value in values {
                    guard let value = hex ? value.parseHex() : Int(value) ?? value.parseHex(strict: true) else {
                        print("Can't parse value \(value) as number")
                        continue
                    }
                    print("\(display): Writing \(value) for \(control)", terminator: ": ")
                    if DDC.write(displayID: display.id, controlID: control, newValue: value.u8) {
                        print("Ok")
                    } else {
                        print("Error")
//                        print("\(display): Error writing \(value) for \(control)")
                    }
                }
            }
            globalExit(0)
        }
    }

    struct Hotkeys: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Prints information about Lunar hotkeys."
        )

        @OptionGroup var globals: GlobalOptions

        @Flag(name: .shortAndLong, help: "Print response as JSON.")
        var json = false

        func run() throws {
            Lunar.configureLogging(options: globals)

            guard !json else {
                print((try! prettyEncoder.encode(CachedDefaults[.hotkeys])).str())
                globalExit(0)
            }

            let hotkeys = [String: String](CachedDefaults[.hotkeys].map { hotkey in
                (hotkey.identifier, hotkey.hotkeyString)
            }, uniquingKeysWith: first(this:other:))
            printDictionary(hotkeys)
            globalExit(0)
        }
    }

    struct Builtin: ParsableCommand {
        enum BuiltinDisplayProperty: String, ExpressibleByArgument, CaseIterable {
            case id
            case brightness
            case contrast
            case all
        }

        static let configuration = CommandConfiguration(
            abstract: "Prints information about the built-in display (if it exists)."
        )

        @OptionGroup var globals: GlobalOptions

        @Flag(name: .shortAndLong, help: "Print raw values returned by the system.")
        var raw = false

        @Flag(name: .shortAndLong, help: "Print response as JSON.")
        var json = false

        @Argument(help: "Property to print. One of (\(BuiltinDisplayProperty.allCases.map(\.rawValue).joined(separator: ", ")))")
        var property: BuiltinDisplayProperty

        func run() throws {
            Lunar.configureLogging(options: globals)

            if raw {
                guard let props = SyncMode.getArmBuiltinDisplayProperties() else {
                    throw CommandError.displayNotFound("builtin")
                }

                switch property {
                case .id:
                    print(displayController.builtinDisplay?.id.s ?? "None")
                case .brightness:
                    print(props["property"] ?? "nil")
                case .contrast:
                    print(props["IOMFBContrastEnhancerStrength"] ?? "nil")
                case .all:
                    if json {
                        let encodableProps = ForgivingEncodable(props)
                        print((try! prettyEncoder.encode(encodableProps)).str())
                    } else {
                        printDictionary(props)
                    }
                }
                globalExit(0)
            }

            guard let (brightness, contrast) = SyncMode.getSourceBrightnessContrast() else {
                throw CommandError.displayNotFound("builtin")
            }
            switch property {
            case .id:
                print(displayController.builtinDisplay?.id.s ?? "None")
            case .brightness:
                print(brightness.str(decimals: 2))
            case .contrast:
                print(contrast.str(decimals: 2))
            case .all:
                if json {
                    print((try! prettyEncoder.encode([
                        "id": displayController.builtinDisplay?.id.d ?? 0,
                        "brightness": brightness,
                        "contrast": contrast,
                    ])).str())
                } else {
                    print("ID: \(displayController.builtinDisplay?.id.s ?? "None")")
                    print("Brightness: \(brightness.str(decimals: 2))")
                    print("Contrast: \(contrast.str(decimals: 2))")
                }
            }
            globalExit(0)
        }
    }

    struct DisplayUuid: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generates UUID for a display ID."
        )

        @OptionGroup var globals: GlobalOptions

        @Flag(name: .shortAndLong, help: "Fall back to EDID if UUID is not possible to generate")
        var fallback = false

        @Argument(help: "Display ID")
        var id: CGDirectDisplayID

        func run() throws {
            Lunar.configureLogging(options: globals)

            if let uuid = CGDisplayCreateUUIDFromDisplayID(id) {
                let uuidValue = uuid.takeRetainedValue()
                let uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuidValue) as String
                if !uuidString.isEmpty {
                    print(uuidString)
                    globalExit(0)
                }
            }

            if fallback {
                if let edid = Display.edid(id: id), let uuid = UUID(namespace: .oid, name: edid) {
                    print(uuid)
                    globalExit(0)
                }
            }
            throw CommandError.noUUID(id)
        }
    }

    struct Preset: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Applies Lunar presets."
        )

        @OptionGroup var globals: GlobalOptions

        @Argument(help: "Number between 0 and 100")
        var preset: Int8

        func validate() throws {
            if !(0 ... 100).contains(preset) {
                throw CommandError
                    .propertyNotValid("Preset must be a number between 0 and 100")
            }
        }

        func run() throws {
            Lunar.configureLogging(options: globals)

            displayController.displays = DisplayController.getDisplays()
            displayController.disable()
            brightnessTransition = .instant

            displayController.setBrightnessPercent(value: preset, now: true)
            Thread.sleep(forTimeInterval: 1.0)
            displayController.setContrastPercent(value: preset, now: true)
            Thread.sleep(forTimeInterval: 1.0)

            globalExit(0)
        }
    }

    struct Mode: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Configures Lunar mode."
        )

        @OptionGroup var globals: GlobalOptions

        @Argument(help: "Adaptive mode. One of (manual, clock, location, sync, sensor, auto)")
        var mode: AdaptiveModeKey

        func run() throws {
            Lunar.configureLogging(options: globals)

            CachedDefaults[.adaptiveBrightnessMode] = mode
            sleep(1)

            globalExit(0)
        }
    }

    struct Displays: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Lists currently active displays and allows for more granular setting/getting of values."
        )

        @OptionGroup var globals: GlobalOptions

        @Flag(name: .shortAndLong, help: "If the output should be printed as JSON.")
        var json = false

        @Flag(name: .shortAndLong, help: "If both active and inactive displays should be printed.")
        var all = false

        @Flag(help: "If virtual displays (e.g. DisplayLink) should be included.")
        var virtual = true

        @Flag(help: "If Airplay displays (e.g. iPad Sidecar, AirPlay) should be included.")
        var airplay = false

        @Flag(help: "If projectors should be included.")
        var projector = false

        @Flag(help: "If dummy displays should be included.")
        var dummy = false

        @Flag(name: .shortAndLong, help: "Include EDID in the output.")
        var edid = false

        @Flag(help: "Include system info in the output.")
        var systemInfo = false

        @Flag(help: "Include panel data in the output.")
        var panelData = false

        @Flag(
            name: .shortAndLong,
            help: "If <property> is passed, try to actively read the property instead of fetching it from cache. Caution: might cause a kernel panic if DDC is too slow to respond!"
        )
        var read = false

        @Flag(help: "Controls to try for getting/setting display properties. Default: CoreDisplay, DDC, Network")
        var controls: [DisplayControl] = [.appleNative, .ddc, .network]

        @Argument(help: "Display serial or name or one of (first, main, all, builtin, source)")
        var display: String?

        @Argument(
            help: "Display property to get or set. One of (\(Display.CodingKeys.allCases.filter { !$0.isHidden }.map(\.rawValue).joined(separator: ", ")))"
        )
        var property: Display.CodingKeys?

        @Argument(help: "Display property value to set")
        var value: String?

        func run() throws {
            Lunar.configureLogging(options: globals)

            displayController.displays = DisplayController.getDisplays(
                includeVirtual: virtual || all,
                includeAirplay: airplay || all,
                includeProjector: projector || all,
                includeDummy: dummy || all
            )

            let displays = (all ? displayController.displays : displayController.activeDisplays).sorted(by: { d1, d2 in
                d1.key <= d2.key
            }).map(\.value)

            if let displayFilter = display {
                let filters = displayFilter != "all" ? [displayFilter] : displays.map(\.serial)
                for filter in filters {
                    do {
                        try handleDisplay(
                            filter,
                            displays: displays,
                            property: property,
                            value: value,
                            json: json,
                            controls: controls,
                            read: read,
                            systemInfo: systemInfo,
                            panelData: panelData,
                            edid: edid
                        )
                    } catch {
                        print("\(filter): \(error)")
                    }
                }
                globalExit(0)
            }

            if json {
                print("{")
            }

            for (i, display) in displays.enumerated() {
                if json {
                    try printDisplay(
                        display,
                        json: json,
                        terminator: (i == displays.count - 1) ? "\n" : ",\n",
                        prefix: "  \"\(display.serial)\": ",
                        systemInfo: systemInfo,
                        panelData: panelData,
                        edid: edid
                    )
                } else {
                    print("\(i): \(display.name)")
                    try printDisplay(display, json: json, prefix: "\t", systemInfo: systemInfo, panelData: panelData, edid: edid)
                    print("")
                }
            }

            if json {
                print("}")
            }
            globalExit(0)
        }
    }

    struct Get: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Gets a property from the first active display."
        )

        @OptionGroup var globals: GlobalOptions

        @Flag(
            name: .shortAndLong,
            help: "If <property> is passed, try to actively read the property instead of fetching it from cache. Caution: might cause a kernel panic if DDC is too slow to respond!"
        )
        var read = false

        @Flag(help: "Controls to try for getting/setting display properties. Default: CoreDisplay, DDC, Network")
        var controls: [DisplayControl] = [.appleNative, .ddc, .network]

        @Argument(
            help: "Display property to get. One of (\(Display.CodingKeys.allCases.filter { !$0.isHidden }.map(\.rawValue).joined(separator: ", ")))"
        )
        var property: Display.CodingKeys

        func run() throws {
            Lunar.configureLogging(options: globals)

            displayController.displays = DisplayController.getDisplays(
                includeVirtual: CachedDefaults[.showVirtualDisplays],
                includeAirplay: CachedDefaults[.showAirplayDisplays],
                includeProjector: CachedDefaults[.showProjectorDisplays],
                includeDummy: CachedDefaults[.showDummyDisplays]
            )

            let displays = displayController.activeDisplays.sorted(by: { d1, d2 in
                d1.key <= d2.key
            }).map(\.value)

            try handleDisplay("first", displays: displays, property: property, controls: controls, read: read)
            globalExit(0)
        }
    }

    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Sets a property to a specific value for the first active display."
        )

        @OptionGroup var globals: GlobalOptions

        @Flag(
            name: .shortAndLong,
            help: "If <property> is passed, try to actively read the property instead of fetching it from cache. Caution: might cause a kernel panic if DDC is too slow to respond!"
        )
        var read = false

        @Flag(help: "Controls to try for getting/setting display properties. Default: CoreDisplay, DDC, Network")
        var controls: [DisplayControl] = [.appleNative, .ddc, .network]

        @Option(name: .shortAndLong, help: "How many milliseconds to wait for network controls to be ready")
        var waitms = 1000

        @Argument(
            help: "Display property to set. One of (\(Display.CodingKeys.settable.map(\.rawValue).joined(separator: ", ")))"
        )
        var property: Display.CodingKeys

        @Argument(help: "Display property value to set")
        var value: String

        func validate() throws {
            if !Display.CodingKeys.settable.contains(property) {
                throw CommandError
                    .propertyNotValid("Property must be one of (\(Display.CodingKeys.settable.map(\.rawValue).joined(separator: ", ")))")
            }
        }

        func run() throws {
            Lunar.configureLogging(options: globals)

            displayController.displays = DisplayController.getDisplays(
                includeVirtual: CachedDefaults[.showVirtualDisplays],
                includeAirplay: CachedDefaults[.showAirplayDisplays],
                includeProjector: CachedDefaults[.showProjectorDisplays],
                includeDummy: CachedDefaults[.showDummyDisplays]
            )

            let displays = displayController.activeDisplays.sorted(by: { d1, d2 in
                d1.key <= d2.key
            }).map(\.value)

            if controls.contains(.network) {
                setupNetworkControls(displays: displays, waitms: waitms)
            }

            try handleDisplay("first", displays: displays, property: property, value: value, controls: controls, read: read)
            globalExit(0)
        }
    }

    struct Gamma: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Sets gamma values. The values can only be persisted while the program is running."
        )

        @OptionGroup var globals: GlobalOptions

        @Option(
            name: .shortAndLong,
            help: "How many seconds to wait until the program exits and the gamma values reset (0 waits indefinitely)"
        )
        var wait = 0

        @Flag(name: .shortAndLong, help: "Force gamma setting.")
        var force = false

        @Option(name: .shortAndLong, help: "Display serial/name/id or one of (first, main, all, builtin, source)")
        var display = "best-guess"

        @Option(name: .long, help: "How often to send the gamma values to the monitor")
        var refreshSeconds = 1

        @Option(name: .long, help: "Minimum red gamma value")
        var redMin: Float = 0.0
        @Option(name: .long, help: "Maximum red gamma value")
        var redMax: Float = 1.0
        @Option(name: .shortAndLong, help: "Red gamma value")
        var red: Float = 1.0

        @Option(name: .long, help: "Minimum green gamma value")
        var greenMin: Float = 0.0
        @Option(name: .long, help: "Maximum green gamma value")
        var greenMax: Float = 1.0
        @Option(name: .shortAndLong, help: "Green gamma value")
        var green: Float = 1.0

        @Option(name: .long, help: "Minimum blue gamma value")
        var blueMin: Float = 0.0
        @Option(name: .long, help: "Maximum blue gamma value")
        var blueMax: Float = 1.0
        @Option(name: .shortAndLong, help: "Blue gamma value")
        var blue: Float = 1.0

        var foundDisplay: Display!

        mutating func validate() throws {
            Lunar.configureLogging(options: globals)
            displayController.displays = DisplayController.getDisplays(
                includeVirtual: CachedDefaults[.showVirtualDisplays],
                includeAirplay: CachedDefaults[.showAirplayDisplays],
                includeProjector: CachedDefaults[.showProjectorDisplays],
                includeDummy: CachedDefaults[.showDummyDisplays]
            )

            let displays = displayController.activeDisplays.sorted(by: { d1, d2 in
                d1.key <= d2.key
            }).map(\.value)

            guard let display = getDisplay(displays: displays, filter: display) else {
                throw CommandError.displayNotFound(display)
            }

            let alreadyLocked = !display.gammaLock()
            if alreadyLocked, !force {
                throw CommandError
                    .gammaError(
                        "Another instance of Lunar is using the gamma tables. Quit that before using this command (or delete \(display.gammaLockPath) if you think this is incorrect)."
                    )
            }

            foundDisplay = display
        }

        func run() throws {
            Lunar.configureLogging(options: globals)

            guard let display = foundDisplay else {
                globalExit(0)
            }

            guard redMin != 0 || redMax != 1 || red != 1 ||
                greenMin != 0 || greenMax != 1 || green != 1 ||
                blueMin != 0 || blueMax != 1 || blue != 1
            else {
                print("""
                    Gamma table for \(display):
                        Red: \(display.defaultGammaTable.red)
                        Green: \(display.defaultGammaTable.green)
                        Blue: \(display.defaultGammaTable.blue)
                """)
                return
            }

            print(
                "Setting gamma for '\(display.name)':\n\tredMin: \(redMin)\n\tred: \(red)\n\tredMax: \(redMax)\n\tgreenMin: \(greenMin)\n\tgreen: \(green)\n\tgreenMax: \(greenMax)\n\tblueMin: \(blueMin)\n\tblue: \(blue)\n\tblueMax: \(blueMax)"
            )

            var stepsDone = 0
            _ = asyncEvery(refreshSeconds.seconds, queue: realtimeQueue) { timer in
                display.gammaLock()

                let table = GammaTable(
                    redMin: redMin,
                    redMax: redMax,
                    redValue: red,
                    greenMin: greenMin,
                    greenMax: greenMax,
                    greenValue: green,
                    blueMin: blueMin,
                    blueMax: blueMax,
                    blueValue: blue
                )
                display.apply(gamma: table, force: true)

                stepsDone += 1
                if stepsDone == wait {
                    display.gammaUnlock()
                    if let timer = timer {
                        realtimeQueue.cancel(timer: timer)
                    }
                    globalExit(0)
                }
            }
        }
    }

    static let configuration = CommandConfiguration(
        abstract: "Lunar CLI.",
        subcommands: [
            Set.self,
            Get.self,
            Displays.self,
            Preset.self,
            Mode.self,
            Builtin.self,
            Ddc.self,
            Ddcctl.self,
            Lid.self,
            Lux.self,
            Signature.self,
            Launch.self,
            Gamma.self,
            CoreDisplay.self,
            DisplayServices.self,
            Hotkeys.self,
            DisplayUuid.self,
        ]
    )

    @OptionGroup var globals: GlobalOptions

    static func configureLogging(options globals: GlobalOptions) {
        if !globals.log, !globals.debug, !globals.verbose {
            log.disable()
        } else {
            log.setMinLevel(
                debug: globals.debug,
                verbose: globals.verbose,
                cloud: false,
                cli: true
            )
        }
    }

    static func prettyKey(_ key: String) -> String {
        UPPERCASE_LETTER_NAMES.replaceAll(
            in: key.titleCase(),
            using: { $0.matched.uppercased().replacingOccurrences(of: " ", with: "") }
        )
    }
}

private func setupNetworkControls(displays: [Display], waitms: Int = 2000) {
    for display in displays {
        display.alwaysUseNetworkControl = true
    }

    asyncNow(runLoopQueue: realtimeQueue) {
        NetworkControl.browser = CiaoBrowser()
        NetworkControl.listenForDDCUtilControllers()
    }
    Thread.sleep(forTimeInterval: waitms.d / 1000)

    for display in displays {
        display.control = display.getBestControl()
    }
}

private func printDisplay(
    _ display: Display,
    json: Bool = false,
    terminator: String = "\n",
    prefix: String = "",
    systemInfo: Bool = false,
    panelData: Bool = false,
    edid: Bool = false
) throws {
    var edidStr = ""
    if edid {
        let data = DDC.getEdidData(displayID: display.id)
        if data == nil || data!.allSatisfy({ $0 == 0 }) {
            edidStr = "Can't read EDID"
        } else {
            edidStr = data!.str(hex: true)
        }
    }

    if json {
        guard var dict = display.dictionary else {
            throw CommandError.serializationError("Can't serialize display \(display.name)")
        }
        if systemInfo {
            dict["systemInfo"] = display.infoDictionary
        }
        if panelData, let panel = display.panel {
            dict["panelData"] = getMonitorPanelDataJSON(panel)
        }
        if edid {
            dict["edid"] = edidStr
            dict["edidUUIDPatterns"] = display.possibleEDIDUUIDs()
        }
        let encodableDisplay = ForgivingEncodable(dict)
        print("\(prefix)\((try! encoder.encode(encodableDisplay)).str())", terminator: terminator)
        return
    }

    guard let displayDict = display.dictionary?.sorted(by: { $0.key <= $1.key })
        .map({ ($0.key, Lunar.prettyKey($0.key), $0.value) })
    else {
        print("\(prefix)Serialization error!")
        return
    }

    let longestKeySize = displayDict.max(by: { $0.1.count <= $1.1.count })?.1.count ?? 1

    for (originalKey, key, value) in displayDict {
        guard let displayKey = Display.CodingKeys(rawValue: originalKey) else { continue }
        print("\(prefix)\(spaced(key, longestKeySize))\(encodedValue(key: displayKey, value: value))")
    }
    let s = { (k: String) in spaced(k, longestKeySize) }
    print("\(prefix)\(s("Has I2C"))\(display.hasI2C)")
    print("\(prefix)\(s("Has Network Control"))\(display.hasNetworkControl)")
    print("\(prefix)\(s("Has DDC"))\(display.hasDDC)")
    if systemInfo {
        if let dict = display.infoDictionary as? [String: Any], dict.count != 0 {
            print("\(prefix)\(s("Info Dictionary"))")
            printDictionary(dict, level: 6, longestKeySize: longestKeySize)
        } else {
            print("\(prefix)\(s("Info Dictionary")){}")
        }
    }

    if panelData, let panel = display.panel {
        let dict = getMonitorPanelDataJSON(panel)
        if dict.count != 0 {
            print("\(prefix)\(s("Panel Data"))")
            printDictionary(dict, level: 6, longestKeySize: longestKeySize)
        } else {
            print("\(prefix)\(s("Panel Data")){}")
        }
    }

    print("\(prefix)\(s("Red Gamma"))\(display.redMin) - \(display.redGamma) - \(display.redMax)")
    print("\(prefix)\(s("Green Gamma"))\(display.greenMin) - \(display.greenGamma) - \(display.greenMax)")
    print("\(prefix)\(s("Blue Gamma"))\(display.blueMin) - \(display.blueGamma) - \(display.blueMax)")

    #if arch(arm64)
        let avService = DDC.AVService(displayID: display.id, ignoreCache: true)
        print("\(prefix)\(s("AVService"))\(avService == nil ? "NONE" : CFCopyDescription(avService!) as String)")
    #else
        let i2c = DDC.I2CController(displayID: display.id, ignoreCache: true)
        print("\(prefix)\(s("I2C Controller"))\(i2c == nil ? "NONE" : i2c!.s)")
    #endif

    if edid {
        print("\(prefix)\(s("EDID"))\(edidStr)")
        print("\(prefix)\(s("EDID UUID Patterns"))\(display.possibleEDIDUUIDs())")
    }
}

private func handleDisplay(
    _ displayFilter: String,
    displays: [Display],
    property: Display.CodingKeys? = nil,
    value: String? = nil,
    json: Bool = false,
    controls: [DisplayControl] = [.appleNative, .ddc, .network, .gamma],
    read: Bool = false,
    systemInfo: Bool = false,
    panelData _: Bool = false,
    edid: Bool = false
) throws {
    // MARK: - Apply display filter to get single display

    guard let display = getDisplay(displays: displays, filter: displayFilter) else {
        throw CommandError.displayNotFound(displayFilter)
    }

    guard let property = property else {
        try printDisplay(display, json: json, systemInfo: systemInfo, edid: edid)
        return
    }

    // MARK: - Enable command-line specified controls

    display.enabledControls = [
        .network: controls.contains(.network),
        .appleNative: controls.contains(.appleNative),
        .ddc: controls.contains(.ddc),
        .gamma: controls.contains(.gamma),
    ]
    display.control = display.getBestControl()
    if Display.CodingKeys.settableWithControl.contains(property), !display.enabledControls[.gamma]!, display.control is GammaControl {
        throw CommandError.controlNotAvailable(controls.map(\.str).joined(separator: ", "))
    }

    guard let propertyValue = display.dictionary?[property.rawValue] else {
        throw CommandError.propertyNotValid(property.rawValue)
    }

    guard var value = value else {
        // MARK: - Get display property

        if !read {
            log.debug("Fetching value for \(property.rawValue)")
            print(encodedValue(key: property, value: propertyValue))
            return
        }

        // MARK: - Read display property

        log.debug("Reading value for \(property.rawValue)")
        guard let readValue = display.control?.read(property) else {
            throw CommandError.cantReadProperty(property.rawValue)
        }

        print(encodedValue(key: property, value: readValue))
        return
    }

    // MARK: - Set display property

    log.debug("Changing \(property.rawValue) from \(propertyValue) to \(value)")
    switch propertyValue {
    case is String:
        display.setValue(value, forKey: property.rawValue)
        display.save(now: true)
    case is NSNumber where property == .input || property == .hotkeyInput1 || property == .hotkeyInput2 || property == .hotkeyInput3:
        guard let input = InputSource(stringValue: value) else {
            throw CommandError.invalidValue("Unknown input \(value)")
        }
        display.setValue(input.rawValue.ns, forKey: property.rawValue)
        display.save(now: true)
        display.control?.write(property, input)
    case let currentValue as Bool where Display.CodingKeys.bool.contains(property):
        var newValue = currentValue
        switch value {
        case "on", "1", "true", "yes", "t", "y":
            newValue = true
        case "off", "0", "false", "no", "f", "n":
            newValue = false
        case "toggle", "switch":
            newValue = !currentValue
        default:
            throw CommandError.invalidValue("\(value) is not a boolean")
        }
        display.setValue(newValue, forKey: property.rawValue)
        display.save(now: true)
        if property == .power {
            display.control?.write(property, newValue ? PowerState.on : PowerState.off)
        } else {
            display.control?.write(property, newValue)
        }
    case let currentValue as NSNumber:
        var operation = ""
        if let firstChar = value.first?.unicodeScalars.first, !CharacterSet.decimalDigits.contains(firstChar) {
            operation = String(firstChar)
            value = String(value.dropFirst())
        }

        guard var value = value.d?.ns else { throw CommandError.invalidValue("\(value) is not a number") }

        switch operation {
        case "+":
            value = (currentValue.uint8Value + min(value.uint8Value, UINT8_MAX.u8 - currentValue.uint8Value)).ns
        case "-":
            value = (currentValue.uint8Value - min(value.uint8Value, currentValue.uint8Value)).ns
        case "":
            break
        default:
            throw CommandError.invalidValue("Unknown operation \(operation) for value \(value)")
        }

        switch property {
        case .brightness:
            display.brightness = value
            display.control?.write(property, display.limitedBrightness)
        case .contrast:
            display.contrast = value
            display.control?.write(property, display.limitedContrast)
        case .volume:
            display.volume = value
            display.control?.write(property, display.limitedVolume)
        default:
            display.setValue(value, forKey: property.rawValue)
            display.control?.write(property, value.uint8Value)
        }
        display.save(now: true)
    default:
        break
    }

    if display.control is NetworkControl {
        Thread.sleep(forTimeInterval: 1)
    }
    print(encodedValue(key: property, value: display.dictionary![property.rawValue]!))
}

private func spacing(longestKeySize: Int, key: String) -> String {
    String(repeating: " ", count: longestKeySize - key.count)
}

private func spaced(_ key: String, _ longestKeySize: Int) -> String {
    "\(key): \(String(repeating: " ", count: longestKeySize - key.count))"
}

private func encodedValue(key: Display.CodingKeys, value: Any) -> String {
    switch key {
    case .defaultGammaRedMin, .defaultGammaRedMax, .defaultGammaRedValue,
         .defaultGammaGreenMin, .defaultGammaGreenMax, .defaultGammaGreenValue,
         .defaultGammaBlueMin, .defaultGammaBlueMax, .defaultGammaBlueValue:
        return (value as! NSNumber).floatValue.str(decimals: 2)
    case .userBrightness, .userContrast:
        return (try! encoder.encode(value as! [String: [String: Int]])).str()
    case .enabledControls:
        return (try! encoder.encode(value as! [String: Bool])).str()
    case .brightnessCurveFactors, .contrastCurveFactors:
        return (try! encoder.encode(value as! [String: Double])).str()
    case .input, .hotkeyInput1, .hotkeyInput2, .hotkeyInput3:
        return (InputSource(rawValue: value as! UInt8) ?? .unknown).str
    case .power:
        return (value as! Bool) ? "on" : "off"
    case .schedules:
        return "\n\t" + (value as! [[String: Any]]).map { scheduleDict in
            let schedule = BrightnessSchedule.from(dict: scheduleDict)
            switch schedule.type {
            case .disabled:
                return "Disabled"
            case .time:
                return "\(schedule.hour.d.str(decimals: 0, padding: 2)):\(schedule.minute.d.str(decimals: 0, padding: 2)) -> Brightness: \(schedule.brightness) | Contrast: \(schedule.contrast)"
            case .sunrise:
                return "Sunrise \(schedule.hour > 0 ? "+" : "")\(schedule.hour.d.str(decimals: 0, padding: 2)):\(schedule.minute.d.str(decimals: 0, padding: 2)) -> Brightness: \(schedule.brightness) | Contrast: \(schedule.contrast)"
            case .sunset:
                return "Sunset \(schedule.hour > 0 ? "+" : "")\(schedule.hour.d.str(decimals: 0, padding: 2)):\(schedule.minute.d.str(decimals: 0, padding: 2)) -> Brightness: \(schedule.brightness) | Contrast: \(schedule.contrast)"
            case .noon:
                return "Noon \(schedule.hour > 0 ? "+" : "")\(schedule.hour.d.str(decimals: 0, padding: 2)):\(schedule.minute.d.str(decimals: 0, padding: 2)) -> Brightness: \(schedule.brightness) | Contrast: \(schedule.contrast)"
            }
        }.joined(separator: "\n\t")
    default:
        if let v = value as? Bool, Display.CodingKeys.bool.contains(key) {
            return "\(v)"
        } else if let v = value as? NSNumber {
            return "\(v)"
        } else {
            return "\(value)"
        }
    }
}

let LUNAR_CLI_SCRIPT =
    """
    #!/bin/sh
    if [[ "$1" == "ddcctl" ]]; then
        shift 1
        "\(Bundle.main.path(forResource: "ddcctl", ofType: nil)!)" $@
    elif [[ "$1" == "launch" ]]; then
        "\(Bundle.main.bundlePath)/Contents/MacOS/Lunar"
    else
        "\(Bundle.main.bundlePath)/Contents/MacOS/Lunar" @ $@
    fi
    """
