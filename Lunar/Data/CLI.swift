//
//  CLI.swift
//  Lunar
//
//  Created by Alin Panaitiu on 12.04.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import ArgumentParser
import Cocoa
import Foundation
import Regex

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

// MARK: - LunarCommandError

private enum LunarCommandError: Error, CustomStringConvertible {
    case noDisplay
    case noServer
    case displayNotFound(String)
    case propertyNotValid(String)
    case cantReadProperty(String)
    case controlNotAvailable(String)
    case serializationError(String)
    case invalidValue(String)
    case ddcError(String)
    case gammaError(String)
    case noUUID(CGDirectDisplayID)

    var description: String {
        switch self {
        case .noDisplay:
            "No display available"
        case .noServer:
            "This command needs to be run through the client-server interface with the Lunar app already running"
        case let .displayNotFound(string):
            "Display Not Found: \(string)"
        case let .propertyNotValid(string):
            "Property Not Valid: \(string)"
        case let .cantReadProperty(string):
            "Cant Read Property: \(string)"
        case let .controlNotAvailable(string):
            "Control Not Available: \(string)"
        case let .serializationError(string):
            "Serialization Error: \(string)"
        case let .invalidValue(string):
            "Invalid Value: \(string)"
        case let .ddcError(string):
            "DDC Error: \(string)"
        case let .gammaError(string):
            "Gamma Error: \(string)"
        case let .noUUID(cgDirectDisplayID):
            "No UUID for \(cgDirectDisplayID)"
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
            cliPrint("\(indentation)\(String(describing: value).replacingOccurrences(of: "\n", with: "\n\(indentation)"))")
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
            cliPrint("\(indentation)\(spaced(key, longestKeySize))")
            printDictionary(nestedDict, level: level + 1, longestKeySize: longestKeySize)
        case let nestedArray as [Any]:
            printArray(nestedArray, level: level + 1, longestKeySize: longestKeySize)
        default:
            cliPrint(
                "\(indentation)\(spaced(key, longestKeySize))\(String(describing: value).replacingOccurrences(of: "\n", with: "\n\t"))"
            )
        }
    }
}

let SERIAL_PATTERN = #"[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}.*"#.r!
let ID_PATTERN = #"\d+"#.r!

// MARK: - DisplayFilter

enum DisplayFilter: ExpressibleByArgument, Codable, Equatable, CaseIterable {
    case all
    case first
    case mainExternal
    case external
    case main
    case nonMain
    case cursor
    case withoutCursor
    case bestGuess
    case builtin
    case syncSource
    case syncTargets
    case none
    case serial(String)
    case name(String)
    case id(CGDirectDisplayID)

    init?(argument: String) {
        switch argument {
        case "all":
            self = .all
        case "first":
            self = .first
        case "external":
            self = .external
        case "mainExternal", "main-external":
            self = .mainExternal
        case "main":
            self = .main
        case "nonMain", "non-main":
            self = .nonMain
        case "cursor", "with-cursor", "withCursor":
            self = .cursor
        case "withoutCursor", "without-cursor", "no-cursor":
            self = .withoutCursor
        case "bestGuess", "best-guess":
            self = .bestGuess
        case "syncSource", "sync-source", "source":
            self = .syncSource
        case "syncTargets", "sync-targets", "targets", "syncTarget", "sync-target", "target":
            self = .syncTargets
        case "builtin", "internal":
            self = .builtin
        case SERIAL_PATTERN:
            self = .serial(argument)
        case ID_PATTERN:
            if let id = UInt32(argument) {
                self = .id(id)
            } else {
                self = .name(argument)
            }
        default:
            self = .name(argument)
        }
    }

    static var allCases: [DisplayFilter] = [
        .all,
        .first,
        .external,
        .builtin,
        .cursor,
        .mainExternal,
        .withoutCursor,
        .main,
        .nonMain,
        .syncSource,
        .syncTargets,
    ]

    static var allValueStrings: [String] {
        ["first", "main", "cursor", "external", "builtin", "all", "non-main", "without-cursor", "sync-source", "sync-targets", "best-guess"]
    }

    @available(macOS 13, *)
    var screen: Screen {
        switch self {
        case .all:
            Screen(id: UInt32.max.u32 - 1, name: "All screens", serial: "all", isDynamicFilter: true)
        case .first:
            Screen(id: UInt32.max.u32 - 2, name: "First screen", serial: "first", isDynamicFilter: true)
        case .mainExternal:
            Screen(id: UInt32.max.u32 - 3, name: "Main external screen", serial: "mainExternal", isDynamicFilter: true)
        case .external:
            Screen(id: UInt32.max.u32 - 4, name: "External screens", serial: "external", isDynamicFilter: true)
        case .main:
            Screen(id: UInt32.max.u32 - 5, name: "Main screen", serial: "main", isDynamicFilter: true)
        case .nonMain:
            Screen(id: UInt32.max.u32 - 6, name: "Non-main screens", serial: "nonMain", isDynamicFilter: true)
        case .cursor:
            Screen(id: UInt32.max.u32 - 7, name: "Screen with the cursor", serial: "cursor", isDynamicFilter: true)
        case .withoutCursor:
            Screen(id: UInt32.max.u32 - 8, name: "Screens without the cursor", serial: "withoutCursor", isDynamicFilter: true)
        case .bestGuess:
            Screen(id: UInt32.max.u32 - 9, name: "Best guess", serial: "bestGuess", isDynamicFilter: true)
        case .builtin:
            Screen(id: UInt32.max.u32 - 10, name: "Built-in screen", serial: "builtin", isDynamicFilter: true)
        case .syncSource:
            Screen(id: UInt32.max.u32 - 11, name: "Sync Mode Source", serial: "syncSource", isDynamicFilter: true)
        case .syncTargets:
            Screen(id: UInt32.max.u32 - 12, name: "Sync Mode Targets", serial: "syncTargets", isDynamicFilter: true)
        case .none:
            Screen(id: UInt32.max.u32 - 13, name: "None", serial: "none", isDynamicFilter: true)
        case let .serial(string):
            Screen(id: UInt32.max.u32 - 14, name: string, serial: string)
        case let .name(string):
            Screen(id: UInt32.max.u32 - 15, name: string, serial: string)
        case let .id(id):
            Screen(id: id, name: id.s, serial: id.s)
        }
    }

    var s: String {
        String(describing: self)
    }
}

// MARK: - NSDeviceDescriptionKey + Encodable

extension NSDeviceDescriptionKey: @retroactive Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try! container.encode(rawValue)
    }
}

// MARK: - ForgivingEncodable

struct ForgivingEncodable: Encodable {
    init(_ value: Any?, key: String? = nil) {
        self.value = value
        self.key = key
    }

    var key: String?
    var value: Any?

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let key, let displayKey = Display.CodingKeys(stringValue: key), Display.CodingKeys.bool.contains(displayKey),
           let b = value as? Bool
        {
            try container.encode(b)
            return
        }
        switch value {
        case let value as Float: try value.encode(to: encoder)
        case let value as Double: try value.encode(to: encoder)
        case let value as NSNumber: try value.doubleValue.encode(to: encoder)
        case is NSNull, is Void: try container.encodeNil()
        case let value as Int: try value.encode(to: encoder)
        case let value as Int8: try value.encode(to: encoder)
        case let value as Int16: try value.encode(to: encoder)
        case let value as Int32: try value.encode(to: encoder)
        case let value as Int64: try value.encode(to: encoder)
        case let value as UInt: try value.encode(to: encoder)
        case let value as UInt8: try value.encode(to: encoder)
        case let value as UInt16: try value.encode(to: encoder)
        case let value as UInt32: try value.encode(to: encoder)
        case let value as UInt64: try value.encode(to: encoder)
        case let value as Bool: try value.encode(to: encoder)
        case let value as String: try value.encode(to: encoder)
        case let value as Date: try value.encode(to: encoder)
        case let value as URL: try value.encode(to: encoder)
        case let data as Data:
            try container.encode(data.str(base64: true))
        case let array as [PersistentHotkey]:
            try container.encode(array)
        case let array as [Any?]:
            try container.encode(array.map { ForgivingEncodable($0) })
        case let dictionary as [String: Any?]:
            try container.encode(
                Dictionary(uniqueKeysWithValues: dictionary.map {
                    ($0.key, ForgivingEncodable($0.value, key: $0.key))

                })
            )
        case let dictionary as [NSDeviceDescriptionKey: Any?]:
            try container.encode(
                Dictionary(uniqueKeysWithValues: dictionary.map {
                    ($0.key.rawValue, ForgivingEncodable($0.value, key: $0.key.rawValue))

                })
            )
        default:
            try container.encode("Value is not serializable")
        }
    }
}

func getFilteredDisplays(displays: [Display], filter: DisplayFilter) -> [Display] {
    switch filter {
    case .all:
        return displays.filter { $0.id != ALL_DISPLAYS_ID }
    case .first:
        guard let first = displays.first else { return [] }
        return [first]
    case .mainExternal:
        guard let mainDisplayId = DC.mainExternalDisplay?.id else { return [] }
        return displays.filter { $0.id == mainDisplayId }
    case .main:
        guard let mainDisplayId = DC.mainDisplay?.id else { return [] }
        return displays.filter { $0.id == mainDisplayId }
    case .nonMain:
        guard let mainDisplayId = DC.mainDisplay?.id else { return [] }
        return displays.filter { $0.id != mainDisplayId }
    case .cursor:
        guard let cursorDisplayId = DC.cursorDisplay?.id else { return [] }
        return displays.filter { $0.id == cursorDisplayId }
    case .withoutCursor:
        guard let cursorDisplayId = DC.cursorDisplay?.id else { return [] }
        return displays.filter { $0.id != cursorDisplayId }
    case .bestGuess:
        guard let currentDisplayId = DC.mainExternalOrCGMainDisplay?.id else { return [] }
        return displays.filter { $0.id == currentDisplayId }
    case .builtin:
        return DC.activeDisplayList.filter(\.isBuiltin)
    case .syncSource:
        return displays.filter(\.isSource)
    case .syncTargets:
        return displays.filter { !$0.isSource }
    case let .id(id):
        return displays.filter { $0.id == id }
    case let .serial(serial):
        return displays.filter { $0.serial == serial }
    case let .name(name):
        guard let name = displays.map(\.name).fuzzyFind(name) else { return [] }

        return displays.filter { $0.name == name }
    case .external:
        return displays.filter { !$0.isBuiltin }
    case .none:
        return []
    }
}

// MARK: - Lunar

struct Lunar: ParsableCommand {
    struct GlobalOptions: ParsableArguments {
        @Flag(name: .long, help: "Send the command to an already running instance of Lunar.")
        var remote = false

        @Flag(name: .long, help: "Spawn a new command-line only instance even if the Lunar app is already running.")
        var newInstance = false

        @Option(name: .long, help: "Hostname or IP of the device where to send the command.")
        var host = "localhost"

        @Option(
            name: .long,
            help: "API key of the device where to send the command. The key can be viewed by running `lunar key` on that device. It can be omitted if you want to control the current device."
        )
        var key = ""
    }

    struct Key: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Prints API Key for controlling Lunar remotely using `lunar --remote`."
        )

        func run() throws {
            guard !CachedDefaults[.apiKey].isEmpty else {
                CachedDefaults[.apiKey] = SERIAL_NUMBER_HASH
                cliPrint(CachedDefaults[.apiKey])
                return cliExit(0)
            }
            cliPrint(CachedDefaults[.apiKey])
            return cliExit(0)
        }
    }

    struct Signature: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Prints code signature of the app."
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Flag(help: "If the output should be printed as hex.")
        var hex = false

        func run() throws {
            guard let sig = getCodeSignature(hex: hex) else {
                return cliExit(1)
            }
            cliPrint(sig)
            return cliExit(0)
        }
    }

    struct Lid: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Prints if lid is closed or opened."
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        func run() throws {
            if isLidClosed() {
                cliPrint("closed")
            } else {
                cliPrint("opened")
            }
            return cliExit(0)
        }
    }

    struct RefreshDisplays: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Refreshes display list from the system and restarts DDC detection"
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        func run() throws {
            DC.resetDisplayList()
            appDelegate!.startOrRestartMediaKeyTap()

            return cliExit(0)
        }
    }

    struct Lux: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Prints ambient light in lux (or -1 if the sensor can't be read)."
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Flag(name: .shortAndLong, help: "Listen for changes in ambient light and output the lux values")
        var listen = false

        @Flag(name: .shortAndLong, help: "Get the window average of the last 15 lux readings instead of the last instant reading (can be used with `--listen` as well)")
        var average = false

        @MainActor func run() throws {
            guard listen else {
                if SensorMode.specific.externalSensorAvailable, let lux = SensorMode.specific.lastAmbientLight {
                    cliPrint(lux)
                } else {
                    cliPrint(average ? (SensorMode.computeLuxWindowAverage() ?? -1.0) : (SensorMode.getInternalSensorLux() ?? -1.0))
                }
                return cliExit(0)
            }
            guard isServer, let server = appDelegate?.server else {
                throw LunarCommandError.noServer
            }
            let socketFd = server.currentSocketFD

            let property = average ? AMI.$luxWindowAverage : AMI.$lux
            property.removeDuplicates().sink { lux in
                guard let lux else { return }
                server.write(lux: lux, to: socketFd)
            }.store(in: &server.luxListeners, for: socketFd)
        }
    }

    struct Edid: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Reads and decodes EDID data structure from monitors."
        )

        static let edidDecodeBinary = Bundle.main.path(forResource: "edid-decode", ofType: nil)!

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Argument(
            help: "Display serial or name (without spaces) or one of the following"
        )
        var display: DisplayFilter = .all

        func run() throws {
            cliGetDisplays(
                includeVirtual: false,
                includeAirplay: false,
                includeProjector: false,
                includeDummy: false
            )
            let displays = getFilteredDisplays(displays: DC.activeDisplayList, filter: display)
                .filter(!\.isBuiltin)

            guard !displays.isEmpty else {
                if display == .all || display == .external {
                    throw LunarCommandError.noDisplay
                }
                throw LunarCommandError.displayNotFound(display.s)
            }

            for display in displays {
                cliPrint("\(display)")
                guard let edid = Display.edid(id: display.id) else {
                    cliPrint("\tError reading EDID")
                    continue
                }

                let result = shell(command: "echo \(edid) | \(Self.edidDecodeBinary)")
                if result.success, let decoded = result.o {
                    cliPrint("\t\(decoded.replacingOccurrences(of: "\n", with: "\n\t"))")
                } else {
                    cliPrint("\t\(result.e ?? "Error decoding EDID")")
                }
            }

            return cliExit(0)
        }
    }

    #if arch(arm64)
        struct Nits: ParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Prints luminance mapping data for Sync Mode when nits readings are available."
            )

            @OptionGroup(visibility: .hidden) var globals: GlobalOptions

            func run() throws {
                for d in DC.activeDisplayList {
                    cliPrint("""
                    \(d.name)
                      ID:\t\t\(d.id)
                      UUID:\t\t\(d.serial)
                      minNits:\t\(d.minNits)
                      maxNits:\t\(d.maxNits)
                      nitsMap:\t\(d.nitsBrightnessMapping.json ?? "None")

                    """)
                }

                return cliExit(0)
            }
        }
    #endif

    struct Ddcctl: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Control monitors using the ddcctl utility: https://github.com/kfix/ddcctl"
        )

        @Argument var args: [String] = []

        func run() throws {
            cliExit(0)
        }
    }

    struct Launch: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Launch Lunar app"
        )

        @Argument var args: [String] = []

        func run() throws {
            cliExit(0)
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

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Argument(help: "Method to call")
        var method: AppleNativeMethod

        @Argument(
            help: "Display serial or name (without spaces) or one of the following"
        )
        var display: DisplayFilter

        @Argument(help: "Value for the method's second argument")
        var value = 1.0

        func run() throws {
            cliGetDisplays(
                includeVirtual: false,
                includeAirplay: false,
                includeProjector: false,
                includeDummy: false
            )
            let displays = getFilteredDisplays(displays: DC.activeDisplayList, filter: display)
            guard !displays.isEmpty else {
                throw LunarCommandError.displayNotFound(display.s)
            }
            let displayIDs = displays.map(\.id)

            for id in displayIDs {
                switch method {
                case .GetUserBrightness:
                    cliPrint(CoreDisplay_Display_GetUserBrightness(id))
                case .GetLinearBrightness:
                    cliPrint(CoreDisplay_Display_GetLinearBrightness(id))
                case .GetDynamicLinearBrightness:
                    cliPrint(CoreDisplay_Display_GetDynamicLinearBrightness(id))
                case .SetUserBrightness:
                    cliPrint("Setting UserBrightness to \(value) for ID: \(id)")
                    CoreDisplay_Display_SetUserBrightness(id, value)
                case .SetLinearBrightness:
                    cliPrint("Setting LinearBrightness to \(value) for ID: \(id)")
                    CoreDisplay_Display_SetLinearBrightness(id, value)
                case .SetDynamicLinearBrightness:
                    cliPrint("Setting DynamicLinearBrightness to \(value) for ID: \(id)")
                    CoreDisplay_Display_SetDynamicLinearBrightness(id, value)
                case .SetAutoBrightnessIsEnabled:
                    cliPrint("Setting AutoBrightnessIsEnabled to \(value > 0) for ID: \(id)")
                    CoreDisplay_Display_SetAutoBrightnessIsEnabled(id, value > 0)
                }
            }
            return cliExit(0)
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

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Argument(help: "Method to call")
        var method: DisplayServicesMethod

        @Argument(
            help: "Display serial or name (without spaces) or one of the following"
        )
        var display: DisplayFilter

        @Argument(help: "Value for the method's second argument")
        var value = 1.0

        @Argument(help: "Value for the method's third argument")
        var value2: Double = 0

        func run() throws {
            cliGetDisplays(
                includeVirtual: false,
                includeAirplay: false,
                includeProjector: false,
                includeDummy: false
            )
            let displays = getFilteredDisplays(displays: DC.activeDisplayList, filter: display)
            guard !displays.isEmpty else {
                throw LunarCommandError.displayNotFound(display.s)
            }
            let displayIDs = displays.map(\.id)

            let resultString = { v in v == KERN_SUCCESS ? "Success" : "Failed" }
            var listening = false
            for id in displayIDs {
                var brightness: Float = value.f
                let type: UInt32 = value2.u32
                switch method {
                case .GetLinearBrightness:
                    cliPrint(resultString(DisplayServicesGetLinearBrightness(id, &brightness)))
                    cliPrint(brightness)
                case .SetLinearBrightness:
                    cliPrint("Setting LinearBrightness to \(brightness) for ID: \(id)")
                    cliPrint(resultString(DisplayServicesSetLinearBrightness(id, brightness)))
                case .GetBrightness:
                    cliPrint(resultString(DisplayServicesGetBrightness(id, &brightness)))
                    cliPrint(brightness)
                case .SetBrightness:
                    cliPrint("Setting Brightness to \(brightness) for ID: \(id)")
                    cliPrint(resultString(DisplayServicesSetBrightness(id, brightness)))
                case .SetBrightnessSmooth:
                    cliPrint("Setting BrightnessSmooth to \(brightness) for ID: \(id)")
                    cliPrint(resultString(DisplayServicesSetBrightnessSmooth(id, brightness)))
                case .SetBrightnessWithType:
                    cliPrint("Setting BrightnessWithType to \(brightness) with type \(type) for ID: \(id)")
                    cliPrint(resultString(DisplayServicesSetBrightnessWithType(id, type, brightness)))
                case .CanChangeBrightness:
                    cliPrint(DisplayServicesCanChangeBrightness(id))
                case .IsSmartDisplay:
                    cliPrint(DisplayServicesIsSmartDisplay(id))
                case .GetPowerMode:
                    cliPrint(DisplayServicesGetPowerMode(id))
                case .SetPowerMode:
                    cliPrint(resultString(DisplayServicesSetPowerMode(id, value.u8)))
                case .GetBrightnessIncrement:
                    cliPrint(DisplayServicesGetBrightnessIncrement(id))
                case .NeedsBrightnessSmoothing:
                    cliPrint(DisplayServicesNeedsBrightnessSmoothing(id))
                case .EnableAmbientLightCompensation:
                    cliPrint(resultString(DisplayServicesEnableAmbientLightCompensation(id, value == 1)))
                case .AmbientLightCompensationEnabled:
                    var enabled = false
                    cliPrint(resultString(DisplayServicesAmbientLightCompensationEnabled(id, &enabled)))
                    cliPrint(enabled)
                case .HasAmbientLightCompensation:
                    cliPrint(DisplayServicesHasAmbientLightCompensation(id))
                case .ResetAmbientLight:
                    cliPrint(resultString(DisplayServicesResetAmbientLight(id, id)))
                case .ResetAmbientLightAll:
                    cliPrint(resultString(DisplayServicesResetAmbientLightAll()))
                case .CanResetAmbientLight:
                    cliPrint(DisplayServicesCanResetAmbientLight(id, 1))
                case .GetLinearBrightnessUsableRange:
                    var min: Int32 = 0
                    var max: Int32 = 0
                    cliPrint(resultString(DisplayServicesGetLinearBrightnessUsableRange(id, &min, &max)))
                    cliPrint("\(min) - \(max)")
                case .CreateBrightnessTable:
                    guard let table = DisplayServicesCreateBrightnessTable(id, value.i32) as? [Int] else { return cliExit(0) }
                    cliPrint(table)
                case .RegisterForBrightnessChangeNotifications:
                    let socketFd = appDelegate?.server.currentSocketFD
                    let result = DisplayServicesRegisterForBrightnessChangeNotifications(id, id) { _, observer, _, _, userInfo in
                        guard let value = (userInfo as NSDictionary?)?["value"] as? Double, let id = observer else { return }
                        let displayID = CGDirectDisplayID(UInt(bitPattern: id))
                        log.verbose("DisplayServicesRegisterForBrightnessChangeNotifications \(displayID) -> \(value)")

                        if isServer, let server = appDelegate?.server {
                            let socketFds = storeLock.around {
                                if Swift.Set(server.rawBrightnessListeners.keys).intersection(Swift.Set(server.connectedSockets.keys)).isEmpty {
                                    for id in server.rawBrightnessListeners.values {
                                        DisplayServicesUnregisterForBrightnessChangeNotifications(id, id)
                                    }
                                    server.rawBrightnessListeners.removeAll()
                                }
                                return server.rawBrightnessListeners.filter { $0.value == displayID }.keys
                            }
                            let state = DisplayStateChange(property: "brightness", value: value, display: displayID)
                            for socketFd in socketFds {
                                server.write(state, to: socketFd, json: false)
                            }
                            return
                        }

                        if let display = DC.activeDisplays[displayID] {
                            cliPrint("\(display) => \(value)")
                        } else {
                            cliPrint("\(displayID) => \(value)")
                        }
                    }
                    guard result == 0 else {
                        cliPrint("RegisterForBrightnessChangeNotifications for \(DC.activeDisplays[id]?.description ?? id.s) error: \(result)")
                        continue
                    }
                    listening = true
                    if isServer, let server = appDelegate?.server, let socketFd {
                        storeLock.around { server.rawBrightnessListeners[socketFd] = id }
                    }
                case .RegisterForAmbientLightCompensationNotifications:
                    let socketFd = appDelegate?.server.currentSocketFD
                    let result = DisplayServicesRegisterForAmbientLightCompensationNotifications(id, id) { _, observer, _, _, userInfo in
                        guard let value = (userInfo as NSDictionary?)?["value"] as? Double, let id = observer else { return }
                        let displayID = CGDirectDisplayID(UInt(bitPattern: id))
                        log.verbose("DisplayServicesRegisterForAmbientLightCompensationNotifications \(displayID) -> \(value)")

                        if isServer, let server = appDelegate?.server {
                            let socketFds = storeLock.around {
                                if Swift.Set(server.rawLuxListeners.keys).intersection(Swift.Set(server.connectedSockets.keys)).isEmpty {
                                    for id in server.rawLuxListeners.values {
                                        DisplayServicesUnregisterForBrightnessChangeNotifications(id, id)
                                    }
                                    server.rawLuxListeners.removeAll()
                                }

                                return server.rawLuxListeners.filter { $0.value == displayID }.keys
                            }
                            let state = DisplayStateChange(property: "lux", value: value, display: displayID)
                            for socketFd in socketFds {
                                server.write(state, to: socketFd, json: false)
                            }
                            return
                        }

                        if let display = DC.activeDisplays[displayID] {
                            cliPrint("\(display) => \(value)")
                        } else {
                            cliPrint("\(displayID) => \(value)")
                        }
                    }
                    guard result == 0 else {
                        cliPrint("RegisterForAmbientLightCompensationNotifications for \(DC.activeDisplays[id]?.description ?? id.s) error: \(result)")
                        continue
                    }
                    listening = true
                    if isServer, let server = appDelegate?.server, let socketFd {
                        storeLock.around { server.rawLuxListeners[socketFd] = id }
                    }
                }
            }

            guard !listening else { return }
            return cliExit(0)
        }
    }

    struct Ddc: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Send raw DDC commands to connected monitors."
        )

        static let controlStrings = ControlID.allCases.map { String(describing: $0) }.chunks(ofCount: 2)
        static let longestString = (controlStrings.compactMap(\.first).max(by: { $0.count <= $1.count })?.count ?? 1) + 2

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Option(name: .shortAndLong, help: "I²C source address")
        var sourceAddress = "0x51"

        @Argument(
            help: "Display serial or name (without spaces) or one of the following"
        )
        var display: DisplayFilter

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
            cliGetDisplays(
                includeVirtual: false,
                includeAirplay: false,
                includeProjector: false,
                includeDummy: false
            )

            let displays = getFilteredDisplays(displays: DC.activeDisplayList, filter: display)
            guard !displays.isEmpty else {
                throw LunarCommandError.displayNotFound(display.s)
            }

            if values.isEmpty || values.first!.lowercased() =~ "(read|get|fetch)-?(max|val)?" {
                let max = values.first?.lowercased().hasSuffix("max") ?? false
                for display in displays {
                    if let result = DDC.read(displayID: display.id, controlID: control) {
                        if displays.count == 1 {
                            cliPrint(max ? result.maxValue : result.currentValue)
                        } else {
                            cliPrint("\(display): \(max ? result.maxValue : result.currentValue)")
                        }
                    } else {
                        if displays.count == 1 {
                            throw LunarCommandError.ddcError("Can't read \(control) for display \(display)")
                        }
                        cliPrint("\(display): Can't read \(control)")
                    }
                }
                return cliExit(0)
            }

            guard let sourceAddr = sourceAddress.parseHex(strict: true)?.u8 else {
                throw LunarCommandError.ddcError("Can't parse source address: \(sourceAddress)")
            }

            for display in displays {
                for value in values {
                    guard let value = hex ? value.parseHex() : Int(value) ?? value.parseHex(strict: true) else {
                        cliPrint("Can't parse value \(value) as number")
                        continue
                    }

                    var localSourceAddr = sourceAddr
                    var localControl = control
                    if control == .INPUT_SOURCE, let input = VideoInputSource(rawValue: value.u16), input.isLGSpecific, sourceAddr == 0x51 {
                        localSourceAddr = 0x50
                        localControl = .MANUFACTURER_SPECIFIC_F4
                    }

                    cliPrint("\(display): Writing \(value) for \(control)", terminator: ": ")
                    if DDC.write(displayID: display.id, controlID: localControl, newValue: value.u16, sourceAddr: localSourceAddr) {
                        cliPrint("Ok")
                    } else {
                        cliPrint("Error")
//                        cliPrint("\(display): Error writing \(value) for \(control)")
                    }
                }
            }
            return cliExit(0)
        }
    }

    struct Hotkeys: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Prints information about Lunar hotkeys."
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Flag(name: .shortAndLong, help: "Print response as JSON.")
        var json = false

        func run() throws {
            guard !json else {
                cliPrint((try! prettyEncoder.encode(CachedDefaults[.hotkeys])).str())
                return cliExit(0)
            }

            let hotkeys = [String: String](CachedDefaults[.hotkeys].map { hotkey in
                (hotkey.identifier, hotkey.hotkeyString)
            }, uniquingKeysWith: first(this:other:))
            printDictionary(hotkeys)
            return cliExit(0)
        }
    }

    struct DisplayUuid: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generates UUID for a display ID."
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Flag(name: .shortAndLong, help: "Fall back to EDID if UUID is not possible to generate")
        var fallback = false

        @Argument(help: "Display ID")
        var id: CGDirectDisplayID

        func run() throws {
            if let uuid = CGDisplayCreateUUIDFromDisplayID(id) {
                let uuidValue = uuid.takeRetainedValue()
                let uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuidValue) as String
                if !uuidString.isEmpty {
                    cliPrint(uuidString)
                    return cliExit(0)
                }
            }

            if fallback {
                if let edid = Display.edid(id: id), let uuid = UUID(namespace: .oid, name: edid) {
                    cliPrint(uuid)
                    return cliExit(0)
                }
            }
            throw LunarCommandError.noUUID(id)
        }
    }

    struct Preset: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Applies Lunar presets."
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Argument(help: "Percentage between 0 and 100 or name of custom preset")
        var preset: String

        func validate() throws {
            if let preset = preset.i ?? preset.replacingOccurrences(of: "%", with: "").i {
                guard (0 ... 100).contains(preset) else {
                    throw LunarCommandError
                        .propertyNotValid("Preset percentage must be a number between 0 and 100")
                }
                return
            }
            let p = preset.lowercased().replacingOccurrences(of: " ", with: "")
            if !CachedDefaults[.presets].contains(where: { $0.id.lowercased().replacingOccurrences(of: " ", with: "") == p }) {
                throw LunarCommandError
                    .propertyNotValid(
                        "Custom preset '\(preset)' does not exist. Saved presets: \(CachedDefaults[.presets].map(\.id).joined(separator: ", "))"
                    )
            }
        }

        func run() throws {
            cliGetDisplays()
            DC.disable()
            if !isServer {
                brightnessTransition = .instant
            }

            if let preset = preset.i8 ?? preset.replacingOccurrences(of: "%", with: "").i8 {
                DC.setBrightnessPercent(value: preset, now: true)
                cliSleep(1.0)
                DC.setContrastPercent(value: preset, now: true)
                cliSleep(1.0)
            }

            let p = preset.lowercased().replacingOccurrences(of: " ", with: "")
            if let preset = CachedDefaults[.presets].first(where: { $0.id.lowercased().replacingOccurrences(of: " ", with: "") == p }) {
                preset.apply()
            }

            for display in DC.activeDisplays.values {
                cliPrint(display.name)
                cliPrint("\tBrightness: \(display.brightness)")
                cliPrint("\tContrast: \(display.contrast)\n")
            }
            return cliExit(0)
        }
    }

    struct Mode: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Configures Lunar mode."
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Argument(help: "Adaptive mode. One of (manual, clock, location, sync, sensor, auto)")
        var mode: AdaptiveModeKey

        @Flag(name: .shortAndLong, help: "Print the learnt mapping of the adaptive mode")
        var printMapping = false

        func mappingStr(_ mapping: [AutoLearnMapping]?) -> String {
            guard let mapping, !mapping.isEmpty else { return "{}" }

            return "\n\t" + mapping.map { m in
                "\(m.source.str(decimals: 2)):\t\(m.target.str(decimals: 2))"
            }.joined(separator: "\n\t")
        }

        func run() throws {
            if printMapping {
                for d in DC.activeDisplayList {
                    cliPrint("\(d.name) [ID: \(d.id)] [UUID: \(d.serial)]")

                    switch mode {
                    case .location:
                        cliPrint("""
                          Brightness Mapping: \(mappingStr(d.locationBrightnessMapping))
                          Contrast Mapping: \(mappingStr(d.locationContrastMapping))
                        """)
                    case .sync:
                        cliPrint("""
                          Brightness Mapping: \(mappingStr(d.syncBrightnessMapping[DC.sourceDisplay.serial]))
                          Contrast Mapping: \(mappingStr(d.syncContrastMapping[DC.sourceDisplay.serial]))
                        """)
                    case .sensor:
                        cliPrint("""
                          Brightness Mapping: \(mappingStr(d.sensorBrightnessMapping))
                          Contrast Mapping: \(mappingStr(d.sensorContrastMapping))
                        """)
                    default:
                        break
                    }

                    cliPrint(" ")
                }
                return
            }

            CachedDefaults[.adaptiveBrightnessMode] = mode
            cliSleep(1)

            return cliExit(0)
        }
    }

    struct CleaningMode: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Blackout screens and disable keyboard to allow cleaning.",
            discussion: """
            Activates "Cleaning Mode" to allow cleaning the screens and the keyboard without triggering any actions.

            WARNING: this will make all your screens black and completely disable the keyboard for the duration of its activation.

            Press the ⌘ Command key more than 8 times in a row to force deactivation of this mode.
            """
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Flag(name: .shortAndLong, help: "Keep cleaning mode active until manually deactivated (using ⌘ Command key or the `lunar cleaning-mode off` command)")
        var keepActive = false

        @Option(name: .shortAndLong, help: "Deactivate cleaning mode automatically after a certain amount of time (in seconds)")
        var deactivateAfter = 120

        @Argument(help: "Whether Cleaning Mode should be `on` or `off`")
        var state: PowerState

        func run() throws {
            if state == .toggle {
                if appDelegate!.cleaningMode {
                    deactivateCleaningMode()
                } else {
                    activateCleaningMode(deactivateAfter: keepActive ? nil : deactivateAfter.d)
                }
                return cliExit(0)
            }

            if state == .off {
                deactivateCleaningMode()
                return cliExit(0)
            }

            activateCleaningMode(deactivateAfter: keepActive ? nil : deactivateAfter.d)
            return cliExit(0)
        }
    }

    struct NightMode: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Lower white point and increase contrast to reduce eye strain at night.",
            discussion: """
            Activates "Night Mode" to reduce eye strain at night.

            This will lower the white point and increase the contrast of all screens,
            making white regions appear less bright while still preserving most colors.
            """
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Argument(help: "Whether Night Mode should be `on` or `off`")
        var state: PowerState

        func run() throws {
            if state == .toggle {
                DC.nightMode.toggle()
                return cliExit(0)
            }
            if state == .off {
                DC.nightMode = false
                return cliExit(0)
            }
            DC.nightMode = true
            return cliExit(0)
        }
    }

    struct Listen: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Listen to changes in brightness/contrast/volume of specific displays",
            discussion: """
            In non-JSON mode, each change will be wrote as a line of the following form:

                \("PROPERTY_NAME".magenta().bold()) \("VALUE".green().bold()) \("DISPLAY_ID".blue().bold())

            \("PROPERTY_NAME".magenta().bold()) will be one of "brightness", "contrast", "volume", "mute".

            For `mute`, \("VALUE".green().bold()) will be a `true` or a `false`.

            For `brightness`, \("VALUE".green().bold()) will be a floating-point value between -1.0 and 2.0 where:
              - [0.0, 1.0] represents the normal brightness range
              - [-1.0, 0.0] represents the \("Sub-zero Dimming".red().bold()) brightness range
              - [1.0, 2.0] represents the \("XDR Brightness".cyan().bold()) brightness range

            For `contrast` and `volume`, \("VALUE".green().bold()) will be a floating-point value between 0.0 and 1.0.

            \("DISPLAY_ID".blue().bold()) will be the `id: CGDirectDisplayID` of each screen.

            In JSON mode, each change will be wrote as a JSON line exemplified below:

                {"brightness": 0.9, "display": 1}
                {"volume": 0.5, "display": 3}

            A JSON line will never contain more than one property.

            \("Usage examples:".bold()):
                Listen for changes on all monitors: \("lunar listen".yellow().bold())
                Get changes as JSON for external monitors: \("lunar listen external --json".yellow().bold())
                Listen for changes on Dell monitors: \("lunar listen dell".yellow().bold())
            """
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Flag(name: .shortAndLong, help: "Format output as JSON")
        var json = false

        @Flag(name: .long, help: "Listen only to changes made using the brightness keys")
        var onlyUserAdjustments = false

        @Argument(
            help: "Display serial or name (without spaces) or one of the following"
        )
        var display: DisplayFilter = .all

        static func startListener(for displays: [Display], filter: DisplayFilter, onlyUserAdjustments: Bool, server: LunarServer, json: Bool) throws {
            let displays = getFilteredDisplays(displays: displays, filter: filter)
            guard !displays.isEmpty else {
                throw LunarCommandError.displayNotFound(filter.s)
            }
            let socketFd = server.currentSocketFD

            let brightnessPublishers: [AnyPublisher<DisplayStateChange, Never>] = displays.map { d in
                (onlyUserAdjustments ? d.$fullRangeUserBrightness : d.$fullRangeBrightness)
                    .map { val in DisplayStateChange(property: "brightness", value: val, display: d.id) }
                    .dropFirst(onlyUserAdjustments ? 1 : 0)
                    .eraseToAnyPublisher()
            }
            #if arch(arm64)
                let nitsPublishers: [AnyPublisher<DisplayStateChange, Never>] = displays.map { d in
                    (onlyUserAdjustments ? d.$userNits : d.$nits)
                        .debounce(for: .milliseconds(onlyUserAdjustments ? 100 : 5), scheduler: RunLoop.main)
                        .compactMap { val in val != nil ? DisplayStateChange(property: "nits", value: val!, display: d.id) : nil }
                        .eraseToAnyPublisher()
                }
            #else
                let nitsPublishers = [AnyPublisher<DisplayStateChange, Never>]()
            #endif
            let contrastPublishers: [AnyPublisher<DisplayStateChange, Never>] = displays.map { d in
                (onlyUserAdjustments ? d.$userContrast : d.$preciseContrast)
                    .map { val in DisplayStateChange(property: "contrast", value: val, display: d.id) }
                    .dropFirst(onlyUserAdjustments ? 1 : 0)
                    .eraseToAnyPublisher()
            }
            let volumePublishers: [AnyPublisher<DisplayStateChange, Never>] = displays.map { d in
                (onlyUserAdjustments ? d.$userVolume : d.$preciseVolume)
                    .map { val in DisplayStateChange(property: "volume", value: val, display: d.id) }
                    .dropFirst(onlyUserAdjustments ? 1 : 0)
                    .eraseToAnyPublisher()
            }
            let mutePublishers: [AnyPublisher<DisplayStateChange, Never>] = displays.map { d in
                d.$userMute
                    .map { val in DisplayStateChange(property: "mute", value: val, display: d.id) }
                    .dropFirst(onlyUserAdjustments ? 1 : 0)
                    .eraseToAnyPublisher()
            }
            let mergedPublisher = Publishers.MergeMany(brightnessPublishers + contrastPublishers + volumePublishers + mutePublishers + nitsPublishers)

            mergedPublisher
                .removeDuplicates()
                .sink { db in
                    guard let server = appDelegate?.server else {
                        return
                    }
                    server.write(db, to: socketFd, json: json)
                }
                .store(in: &server.brightnessListeners, for: socketFd)
        }

        func run() throws {
            guard isServer, let server = appDelegate?.server else {
                throw LunarCommandError.noServer
            }

            try Self.startListener(for: DC.activeDisplayList, filter: display, onlyUserAdjustments: onlyUserAdjustments, server: server, json: json)
            let socketFd = server.currentSocketFD
            DC.$activeDisplayList
                .sink { displays in
                    guard let server = appDelegate?.server else {
                        return
                    }
                    do {
                        try Self.startListener(for: displays, filter: display, onlyUserAdjustments: onlyUserAdjustments, server: server, json: json)
                    } catch {
                        log.error("CLI Error listening for brightness changes: \(error.localizedDescription)")
                    }
                }
                .store(in: &server.displayListeners, for: socketFd)
        }
    }

    struct Displays: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Control displays or get data about the current state of the displays.",
            discussion: """
            \("EXAMPLE".bold()):
                Set brightness for monitors named Dell to 60%: \("lunar displays dell brightness 60".yellow().bold())
                Print contrast of monitors with `LG` and `4K` in their name: \("lunar displays lg4k contrast".yellow().bold())
                Rotate main display to portrait mode: \("lunar displays main rotation 90".yellow().bold())
                Print details of all displays: \("lunar displays".yellow().bold())
            """
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Flag(name: .shortAndLong, help: "Format output as JSON")
        var json = false

        @Flag(name: .shortAndLong, help: "Include both connected and disconnected displays")
        var all = false

        @Flag(help: "Don't include virtual displays (e.g. DisplayLink)")
        var noVirtual = false

        @Flag(help: "Include Airplay displays (e.g. iPad Sidecar, AirPlay)")
        var airplay = false

        @Flag(help: "Include displays marked as projectors")
        var projector = false

        @Flag(help: "Include displays marked as dummy (e.g. BetterDummy/BetterDisplay virtual displays or HDMI dongles)")
        var dummy = false

        @Flag(name: .shortAndLong, help: "Include EDID in the output")
        var edid = false

        @Flag(help: "Include system info in the output")
        var systemInfo = false

        @Flag(help: "Include panel data in the output")
        var panelData = false

        @Flag(help: "Include all resolutions for panel data in the output")
        var panelDataAllResolutions = false

        @Flag(name: .shortAndLong, help: "Exit with status code 1 if no displays are found or 0 if any display matches the filter. Don't print anything")
        var quiet = false

        @Flag(
            name: .shortAndLong,
            help: "If <property> is passed, try to actively read the property instead of fetching it from cache. Caution: might cause a kernel panic if DDC is too slow to respond!"
        )
        var read = false

        @Flag(help: "Controls to try for getting/setting display properties. Default: CoreDisplay, DDC, Network")
        var controls: [DisplayControl] = []

        @Argument(
            help: "Display serial or name (without spaces) or one of the following"
        )
        var display: DisplayFilter?

        @Argument(
            help: "Display property to get or set. Common properties: (\(Display.CodingKeys.settableCommon.filter { !$0.isHidden }.map(\.rawValue).joined(separator: ", ")))"
        )
        var property: Display.CodingKeys?

        @Argument(help: "Display property value to set")
        var value: String?

        func run() throws {
            let property = property == .mute ? .audioMuted : property

            cliGetDisplays(
                includeVirtual: !noVirtual || all,
                includeAirplay: airplay || all,
                includeProjector: projector || all,
                includeDummy: dummy || all
            )

            let displays = (all ? DC.displayList : DC.activeDisplayList).filter { $0.id != ALL_DISPLAYS_ID }

            if let displayFilter = display {
                guard !quiet else {
                    return cliExit(getFilteredDisplays(displays: displays, filter: displayFilter).isEmpty ? 1 : 0)
                }

                do {
                    try handleDisplays(
                        displayFilter,
                        displays: displays,
                        property: property,
                        value: value,
                        json: json,
                        controls: controls.isEmpty ? nil : controls,
                        read: read,
                        systemInfo: systemInfo,
                        panelData: panelData,
                        panelDataAllResolutions: panelDataAllResolutions,
                        edid: edid
                    )
                } catch {
                    cliPrint("\(error)")
                    return cliExit(1)
                }
                return cliExit(0)
            }

            guard !quiet else {
                return cliExit(displays.isEmpty ? 1 : 0)
            }

            if json {
                cliPrint("{")
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
                        panelDataAllResolutions: panelDataAllResolutions,
                        edid: edid
                    )
                } else {
                    cliPrint("\(i): \(display.name)")
                    try printDisplay(
                        display,
                        json: json,
                        prefix: "\t",
                        systemInfo: systemInfo,
                        panelData: panelData,
                        panelDataAllResolutions: panelDataAllResolutions,
                        edid: edid
                    )
                    if i < displays.count - 1 {
                        cliPrint("")
                    }
                }
            }

            if json {
                cliPrint("}")
            }
            return cliExit(0)
        }
    }

    struct Get: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Gets a property from the first active display."
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Flag(
            name: .shortAndLong,
            help: "If <property> is passed, try to actively read the property instead of fetching it from cache. Caution: might cause a kernel panic if DDC is too slow to respond!"
        )
        var read = false

        @Flag(help: "Controls to try for getting/setting display properties. Default: CoreDisplay, DDC, Network")
        var controls: [DisplayControl] = []

        @Argument(
            help: "Display property to get. Common properties: (\(Display.CodingKeys.settableCommon.filter { !$0.isHidden }.map(\.rawValue).joined(separator: ", ")))"
        )
        var property: Display.CodingKeys

        func run() throws {
            let property = property == .mute ? .audioMuted : property

            cliGetDisplays(
                includeVirtual: CachedDefaults[.showVirtualDisplays],
                includeAirplay: CachedDefaults[.showAirplayDisplays],
                includeProjector: CachedDefaults[.showProjectorDisplays],
                includeDummy: CachedDefaults[.showDummyDisplays]
            )

            try handleDisplays(
                .bestGuess,
                displays: DC.activeDisplayList,
                property: property,
                controls: controls.isEmpty ? nil : controls,
                read: read
            )
            return cliExit(0)
        }
    }

    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Sets a property to a specific value for the first active display."
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Flag(
            name: .shortAndLong,
            help: "If <property> is passed, try to actively read the property instead of fetching it from cache. Caution: might cause a kernel panic if DDC is too slow to respond!"
        )
        var read = false

        @Flag(help: "Controls to try for getting/setting display properties. Default: CoreDisplay, DDC, Network")
        var controls: [DisplayControl] = []

        @Option(name: .shortAndLong, help: "How many milliseconds to wait for network controls to be ready")
        var waitms = 1000

        @Argument(
            help: "Display property to set. Common properties: (\(Display.CodingKeys.settableCommon.map(\.rawValue).joined(separator: ", ")))"
        )
        var property: Display.CodingKeys

        @Argument(help: "Display property value to set")
        var value: String

        func validate() throws {
            if !Display.CodingKeys.settable.contains(property) {
                throw LunarCommandError
                    .propertyNotValid("Property must be one of (\(Display.CodingKeys.settable.map(\.rawValue).joined(separator: ", ")))")
            }
        }

        func run() throws {
            let property = property == .mute ? .audioMuted : property

            cliGetDisplays(
                includeVirtual: CachedDefaults[.showVirtualDisplays],
                includeAirplay: CachedDefaults[.showAirplayDisplays],
                includeProjector: CachedDefaults[.showProjectorDisplays],
                includeDummy: CachedDefaults[.showDummyDisplays]
            )

            if !isServer, controls.contains(.network) {
                setupNetworkControls(displays: DC.activeDisplayList, waitms: waitms)
            }

            try handleDisplays(
                .bestGuess,
                displays: DC.activeDisplayList,
                property: property,
                value: value,
                controls: controls.isEmpty ? nil : controls,
                read: read
            )
            return cliExit(0)
        }
    }

    struct Gamma: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Sets gamma values. The values can only be persisted while the program is running."
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Option(
            name: .shortAndLong,
            help: "How many seconds to wait until the program exits and the gamma values reset (0 waits indefinitely)"
        )
        var wait = 0

        @Flag(name: .shortAndLong, help: "Force gamma setting.")
        var force = false

        @Option(
            name: .long,
            help: "Display serial or name (without spaces) or one of the following"
        )
        var display: DisplayFilter = .bestGuess

        @Option(name: .long, help: "How often to send the gamma values to the monitor")
        var refreshSeconds: TimeInterval = 1

        @Flag(name: .long, help: "Read Gamma values (the default unless `--write` is passed)")
        var read = false

        @Flag(name: .long, help: "Read the system gamma table instead of Lunar's internal values")
        var readFullTable = false

        @Flag(name: .long, help: "Write Gamma values")
        var write = false

        @Flag(name: .long, help: "Reset Gamma values")
        var reset = false
        @Flag(name: .long, help: "Restore ColorSync Gamma values")
        var restoreColorSync = false

        @Option(name: .shortAndLong, help: "Red gamma value")
        var red = 0.5
        @Option(name: .shortAndLong, help: "Green gamma value")
        var green = 0.5
        @Option(name: .shortAndLong, help: "Blue gamma value")
        var blue = 0.5

        func validate() throws {
            guard !globals.remote else { return }

            cliGetDisplays(
                includeVirtual: CachedDefaults[.showVirtualDisplays],
                includeAirplay: CachedDefaults[.showAirplayDisplays],
                includeProjector: CachedDefaults[.showProjectorDisplays],
                includeDummy: CachedDefaults[.showDummyDisplays]
            )

            guard !isServer else { return }

            let displays = getFilteredDisplays(displays: DC.activeDisplayList, filter: display)
            guard !displays.isEmpty else {
                throw LunarCommandError.displayNotFound(display.s)
            }

            // let alreadyLocked = displays.filter { !$0.gammaLock() }
            // if !alreadyLocked.isEmpty, !force {
            //     throw LunarCommandError
            //         .gammaError(
            //             "Another instance of Lunar is using the gamma tables. Quit that before using this command (or delete [\(alreadyLocked.map(\.gammaLockPath).joined(by: ","))] if you think this is incorrect)."
            //         )
            // }
        }

        func run() throws {
            let displays = getFilteredDisplays(displays: DC.activeDisplayList, filter: display)
            guard !displays.isEmpty else {
                throw LunarCommandError.displayNotFound(display.s)
            }

            for display in displays {
                let printTable = {
                    if readFullTable {
                        let table = GammaTable(for: display.id)
                        cliPrint("""
                        Gamma table for \(display):
                            Red: \(table.red.str(decimals: 3))
                            Green: \(table.green.str(decimals: 3))
                            Blue: \(table.blue.str(decimals: 3))
                        """)
                    } else {
                        cliPrint("""
                        Gamma table for \(display):
                            Red: \(display.red.str(decimals: 3))
                            Green: \(display.green.str(decimals: 3))
                            Blue: \(display.blue.str(decimals: 3))
                        """)
                    }
                }

                guard write || reset || restoreColorSync else {
                    printTable()
                    continue
                }

                if reset {
                    if isServer {
                        display.resetDefaultGamma()
                    } else {
                        restoreColorSyncSettings(reapplyGammaFor: display.otherDisplays.filter(\.gammaSetAPICalled))
                    }
                    cliPrint("Resetting gamma table for \(display)\n")
                    printTable()
                    continue
                }
                if restoreColorSync {
                    restoreColorSyncSettings()
                    cliPrint("Restoring ColorSync settings\n")
                    printTable()
                    continue
                }

                cliPrint(
                    "Setting gamma for \(display):\n\tRed: \(red)\n\tGreen: \(green)\n\tBlue: \(blue)"
                )

                display.applyGamma = true
                guard !isServer else {
                    // display.gammaLock()

                    display.red = red
                    display.green = green
                    display.blue = blue

                    continue
                }

                var stepsDone = 0
                gammaRepeater = Repeater(every: refreshSeconds, name: "CLIGammaRepeater") {
                    // display.gammaLock()

                    display.red = red
                    display.green = green
                    display.blue = blue

                    stepsDone += 1
                    if stepsDone == wait {
                        gammaRepeater = nil
                        return cliExit(0)
                    }
                }
            }
        }
    }

    struct Facelight: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Turns monitors into bright light panels.",
            discussion: "\("EXAMPLE".bold()): \("lunar facelight external enable".yellow().bold())"
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Argument(
            help: "Display serial or name (without spaces) or one of the following"
        )
        var display = DisplayFilter.bestGuess

        @Argument(help: "Whether Facelight should be enabled or disabled")
        var state: FeatureState = .enable

        func run() throws {
            cliGetDisplays(
                includeVirtual: CachedDefaults[.showVirtualDisplays],
                includeAirplay: CachedDefaults[.showAirplayDisplays],
                includeProjector: CachedDefaults[.showProjectorDisplays],
                includeDummy: CachedDefaults[.showDummyDisplays]
            )

            let displays = getFilteredDisplays(displays: DC.activeDisplayList, filter: display)
            guard !displays.isEmpty else {
                throw LunarCommandError.displayNotFound(display.s)
            }

            for (i, display) in displays.enumerated() {
                mainAsyncAfter(ms: i * 1000) {
                    log.info("CLI: \(state == .enable ? "Enabling" : "Disabling") Facelight for \(display)")
                    if state == .enable {
                        display.enableFaceLight()
                    } else {
                        display.disableFaceLight()
                    }
                }
            }
            cliExit(0)
        }
    }

    struct Blackout: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Turns monitors off without cutting power or closing the lid.",
            discussion: "\("EXAMPLE".bold()): \("lunar blackout builtin enable".yellow().bold())"
        )

        @OptionGroup(visibility: .hidden) var globals: GlobalOptions

        @Flag(name: .long, help: "BlackOut without mirroring the screen contents.")
        var noMirror = false

        @Option(name: .long, help: "Display to mirror when turning on BlackOut.")
        var master: DisplayFilter = .none

        @Argument(
            help: "Display serial or name (without spaces) or one of the following"
        )
        var display = DisplayFilter.bestGuess

        @Argument(help: "Whether Blackout should be enabled (monitor turned off) or disabled (turn monitor back on)")
        var state: FeatureState = .enable

        func run() throws {
            cliGetDisplays(
                includeVirtual: CachedDefaults[.showVirtualDisplays],
                includeAirplay: CachedDefaults[.showAirplayDisplays],
                includeProjector: CachedDefaults[.showProjectorDisplays],
                includeDummy: CachedDefaults[.showDummyDisplays]
            )

            let displays = getFilteredDisplays(displays: DC.activeDisplayList, filter: display)
            guard !displays.isEmpty else {
                throw LunarCommandError.displayNotFound(display.s)
            }

            let master: CGDirectDisplayID? = master == .none ? nil : getFilteredDisplays(
                displays: DC.activeDisplayList,
                filter: master
            ).first?.id

            for (i, display) in displays.enumerated() {
                mainAsyncAfter(ms: i * 3000) {
                    log.info("CLI: Turning \(state == .enable ? "off" : "on") \(display)")
                    lastBlackOutToggleDate = .distantPast
                    DC.blackOut(
                        display: display.id,
                        state: state == .enable ? .on : .off,
                        mirroringAllowed: !noMirror,
                        master: master
                    )
                }
            }
            cliExit(0)
        }
    }

    #if arch(arm64)
        @available(macOS 13, *)
        struct Disconnect: ParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Disconnects screens without cutting power or closing the lid.",
                discussion: "\("EXAMPLE".bold()): \("lunar disconnect builtin".yellow().bold())"
            )

            @OptionGroup(visibility: .hidden) var globals: GlobalOptions

            @Argument(
                help: "Display serial, ID or name (without spaces) or one of the following: sidecar or"
            )
            var display = DisplayFilter.builtin

            @Flag(name: .shortAndLong, help: "Force disconnect in single screen scenarios.")
            var force = false

            func run() throws {
                cliGetDisplays(
                    includeVirtual: CachedDefaults[.showVirtualDisplays],
                    includeAirplay: CachedDefaults[.showAirplayDisplays],
                    includeProjector: CachedDefaults[.showProjectorDisplays],
                    includeDummy: CachedDefaults[.showDummyDisplays]
                )

                let displays = getFilteredDisplays(displays: DC.activeDisplayList, filter: display)
                guard !displays.isEmpty else {
                    throw LunarCommandError.displayNotFound(display.s)
                }

                if force, displays.count == 1 {
                    DC.forcedis(displays[0].id, display: displays[0])
                } else {
                    DC.dis(displays.map(\.id))
                }

                guard display != .name("sidecar") else {
                    guard let sdm, let connected = sdm.connectedDevices, let device = connected.first else {
                        cliExit(1)
                        return
                    }

                    Task.init { await sdm.disconnect(from: device) }

                    cliExit(0)
                    return
                }

                cliExit(0)
            }
        }

        @available(macOS 13, *)
        struct Connect: ParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Reconnects screens that were previously disconnected using Lunar.",
                discussion: "\("EXAMPLE".bold()): \("lunar connect builtin".yellow().bold())"
            )

            @OptionGroup(visibility: .hidden) var globals: GlobalOptions

            @Argument(
                help: "Display serial, ID or name (without spaces) or one of the following: sidecar or"
            )
            var display = DisplayFilter.builtin

            func run() throws {
                guard display != .all else {
                    cliPrint("CLI: Reconnecting all displays")
                    DC.en()
                    cliExit(0)
                    return
                }

                guard display != .builtin else {
                    cliPrint("CLI: Reconnecting builtin display")
                    if !NSScreen.onlineDisplayIDs.contains(1) {
                        DC.en(1)
                    }
                    cliExit(0)
                    return
                }

                guard display != .name("sidecar") else {
                    guard let sdm, let connected = sdm.connectedDevices, connected.isEmpty,
                          let device = sdm.recentDevices?.first ?? sdm.devices?.first
                    else {
                        cliPrint("CLI: No sidecar to reconnect")
                        cliExit(1)
                        return
                    }

                    Task.init { await sdm.connect(to: device) }

                    cliPrint("CLI: Connecting sidecar \(device)")
                    cliExit(0)
                    return
                }

                cliGetDisplays(
                    includeVirtual: CachedDefaults[.showVirtualDisplays],
                    includeAirplay: CachedDefaults[.showAirplayDisplays],
                    includeProjector: CachedDefaults[.showProjectorDisplays],
                    includeDummy: CachedDefaults[.showDummyDisplays]
                )

                let displays = getFilteredDisplays(displays: Array(DC.possiblyDisconnectedDisplays.values), filter: display)
                guard !displays.isEmpty else {
                    if case let .id(id) = display {
                        cliPrint("CLI: Reconnecting \(display)")
                        DC.en(id)
                        cliExit(0)
                        return
                    } else {
                        DC.en()
                        throw LunarCommandError.displayNotFound(display.s)
                    }
                }

                cliPrint("CLI: Reconnecting \(displays)")
                for (i, display) in displays.enumerated() {
                    mainAsyncAfter(ms: i * 1000) {
                        log.info("CLI: Reconnecting \(display)")
                        DC.en(display.id)
                    }
                }
                cliExit(0)
            }
        }

        @available(macOS 13, *)
        struct ToggleConnection: ParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Disconnects screens without cutting power or closing the lid, or reconnects screens that were previously disconnected using Lunar.",
                discussion: "\("EXAMPLE".bold()): \("lunar toggle-connection builtin".yellow().bold())"
            )

            @OptionGroup(visibility: .hidden) var globals: GlobalOptions

            @Argument(
                help: "Display serial, ID or name (without spaces) or one of the following: sidecar or"
            )
            var display = DisplayFilter.builtin

            func run() throws {
                cliGetDisplays(
                    includeVirtual: CachedDefaults[.showVirtualDisplays],
                    includeAirplay: CachedDefaults[.showAirplayDisplays],
                    includeProjector: CachedDefaults[.showProjectorDisplays],
                    includeDummy: CachedDefaults[.showDummyDisplays]
                )

                guard display != .all else {
                    if DC.connectedDisplayCount == 0 {
                        DC.en()
                    } else {
                        for id in DC.activeDisplays.keys {
                            DC.dis(id)
                        }
                    }
                    cliExit(0)
                    return
                }

                guard display != .builtin else {
                    if DCPAVServiceExists(location: .embedded) {
                        DC.dis(1)
                    } else {
                        DC.en(1)
                    }
                    cliExit(0)
                    return
                }
                guard display != .name("sidecar") else {
                    guard let sdm, let connected = sdm.connectedDevices else {
                        cliExit(1)
                        return
                    }

                    if connected.isEmpty, let device = sdm.recentDevices?.first ?? sdm.devices?.first {
                        Task.init { await sdm.connect(to: device) }
                    } else if let device = connected.first {
                        Task.init { await sdm.disconnect(from: device) }
                    }

                    cliExit(0)
                    return
                }

                let connectedDisplays = getFilteredDisplays(displays: DC.activeDisplayList, filter: display)
                if !connectedDisplays.isEmpty {
                    DC.dis(connectedDisplays.map(\.id))
                    cliExit(0)
                    return
                }

                let displays = getFilteredDisplays(displays: Array(DC.possiblyDisconnectedDisplays.values), filter: display)
                if displays.isEmpty {
                    DC.en()
                } else {
                    for (i, display) in displays.enumerated() {
                        mainAsyncAfter(ms: i * 1000) {
                            log.info("CLI: Reconnecting \(display)")
                            DC.en(display.id)
                        }
                    }
                }

                cliExit(0)
            }
        }

    #endif

    static let configuration = CommandConfiguration(
        abstract: "Lunar CLI.",
        subcommands: [
            Displays.self,
            Get.self,
            Set.self,
            Preset.self,
            Mode.self,
            Blackout.self,
            Facelight.self,
            Ddc.self,
            Ddcctl.self,
            Lid.self,
            Lux.self,
            Signature.self,
            Key.self,
            Launch.self,
            Gamma.self,
            CoreDisplay.self,
            DisplayServices.self,
            Hotkeys.self,
            DisplayUuid.self,
            RefreshDisplays.self,
            Edid.self,
            Listen.self,
            CleaningMode.self,
            NightMode.self,
        ] + ARCH_SPECIFIC_COMMANDS
    )

    #if arch(arm64)
        static let ARCH_SPECIFIC_COMMANDS: [ParsableCommand.Type] = if #available(macOS 13, *) {
            [Disconnect.self, Connect.self, ToggleConnection.self, Nits.self]
        } else {
            [Nits.self]
        }
    #else
        static let ARCH_SPECIFIC_COMMANDS: [ParsableCommand.Type] = []
    #endif

    @OptionGroup var globals: GlobalOptions

    static func prettyKey(_ key: String) -> String {
        UPPERCASE_LETTER_NAMES.replaceAll(
            in: key.titleCase(),
            using: { $0.matched.uppercased().replacingOccurrences(of: " ", with: "") }
        )
    }

    static func globalOptions(args: [String]) -> GlobalOptions? {
        var args = args
        if !args.contains("--remote") {
            args = ["--remote"] + args
        }
        let command: ParsableCommand
        do {
            command = try Lunar.parseAsRoot(args)
        } catch {
            print(Lunar.fullMessage(for: error))
            cliExit(1)
            return nil
        }

        switch command {
        case let cmd as Set:
            return cmd.globals
        case let cmd as Get:
            return cmd.globals
        case let cmd as Displays:
            return cmd.globals
        case let cmd as Preset:
            return cmd.globals
        case let cmd as Mode:
            return cmd.globals
        case let cmd as Ddc:
            return cmd.globals
        case is Ddcctl:
            return nil
        case let cmd as Lid:
            return cmd.globals
        case let cmd as Lux:
            return cmd.globals
        case let cmd as Edid:
            return cmd.globals
        case let cmd as Signature:
            return cmd.globals
        case is Key:
            return nil
        case is Launch:
            return nil
        case let cmd as Gamma:
            return cmd.globals
        case let cmd as Blackout:
            return cmd.globals
        case let cmd as Facelight:
            return cmd.globals
        case let cmd as CoreDisplay:
            return cmd.globals
        case let cmd as Listen:
            return cmd.globals
        case let cmd as DisplayServices:
            return cmd.globals
        case let cmd as Hotkeys:
            return cmd.globals
        case let cmd as DisplayUuid:
            return cmd.globals
        case let cmd as CleaningMode:
            return cmd.globals
        case let cmd as NightMode:
            return cmd.globals
        #if arch(arm64)
            case let cmd as Nits:
                return cmd.globals
        #endif
        default:
            #if arch(arm64)
                if #available(macOS 13, *) {
                    switch command {
                    case let cmd as Disconnect:
                        return cmd.globals
                    case let cmd as Connect:
                        return cmd.globals
                    case let cmd as ToggleConnection:
                        return cmd.globals
                    default:
                        return nil
                    }
                }
            #endif

            return nil
        }
    }
}

private func setupNetworkControls(displays: [Display], waitms: Int = 2000) {
    for display in displays {
        display.alwaysUseNetworkControl = true
    }

    DispatchQueue.global().async {
//         print("\(Date()) Starting setupNetworkControls")
//         defer { print("\(Date()) Finished setupNetworkControls") }

        NetworkControl.browser = CiaoBrowser()
        NetworkControl.listenForDDCUtilControllers()
    }
    cliSleep(waitms.d / 1000)

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
    panelDataAllResolutions: Bool = false,
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
            throw LunarCommandError.serializationError("Can't serialize display \(display.name)")
        }
        if systemInfo {
            dict["systemInfo"] = display.infoDictionary
        }
        if panelData, let panel = display.panel {
            dict["panelData"] = getMonitorPanelDataJSON(panel, includeModes: panelDataAllResolutions)
        }
        if edid {
            dict["edid"] = edidStr
            dict["edidUUIDPatterns"] = display.possibleEDIDUUIDs()
        }
        let encodableDisplay = ForgivingEncodable(dict)
        cliPrint("\(prefix)\((try! encoder.encode(encodableDisplay)).str())", terminator: terminator)
        return
    }

    guard let displayDict = display.dictionary?.sorted(by: { $0.key <= $1.key })
        .map({ ($0.key, Lunar.prettyKey($0.key), $0.value) })
    else {
        cliPrint("\(prefix)Serialization error!")
        return
    }

    let longestKeySize = displayDict.max(by: { $0.1.count <= $1.1.count })?.1.count ?? 1

    for (originalKey, key, value) in displayDict {
        guard let displayKey = Display.CodingKeys(rawValue: originalKey), !Display.CodingKeys.hidden.contains(displayKey) else {
            continue
        }
        cliPrint("\(prefix)\(spaced(key, longestKeySize))\(encodedValue(key: displayKey, value: value, prefix: prefix))")
    }
    let s = { (k: String) in spaced(k, longestKeySize) }
    cliPrint("\(prefix)\(s("Has I2C"))\(display.hasI2C)")
    cliPrint("\(prefix)\(s("Has Network Control"))\(display.hasNetworkControl)")
    cliPrint("\(prefix)\(s("Has DDC"))\(display.hasDDC)")
    if systemInfo {
        if let dict = display.infoDictionary as? [String: Any], dict.count != 0 {
            cliPrint("\(prefix)\(s("Info Dictionary"))")
            printDictionary(dict, level: 6, longestKeySize: longestKeySize)
        } else {
            cliPrint("\(prefix)\(s("Info Dictionary")){}")
        }
    }

    if panelData, let panel = display.panel {
        let dict = getMonitorPanelDataJSON(panel, includeModes: panelDataAllResolutions)
        if dict.count != 0 {
            cliPrint("\(prefix)\(s("Panel Data"))")
            printDictionary(dict, level: 6, longestKeySize: longestKeySize)
        } else {
            cliPrint("\(prefix)\(s("Panel Data")){}")
        }
    }

    cliPrint("\(prefix)\(s("Red Gamma"))\(display.redMin) - \(display.redGamma) - \(display.redMax)")
    cliPrint("\(prefix)\(s("Green Gamma"))\(display.greenMin) - \(display.greenGamma) - \(display.greenMax)")
    cliPrint("\(prefix)\(s("Blue Gamma"))\(display.blueMin) - \(display.blueGamma) - \(display.blueMax)")

    #if arch(arm64)
        let avService = DDC.AVService(displayID: display.id, ignoreCache: true)
        cliPrint("\(prefix)\(s("AVService"))\(avService == nil ? "NONE" : CFCopyDescription(avService!) as String)")
    #else
        let i2c = DDC.I2CController(displayID: display.id, ignoreCache: true)
        cliPrint("\(prefix)\(s("I2C Controller"))\(i2c == nil ? "NONE" : i2c!.s)")
    #endif

    if edid {
        cliPrint("\(prefix)\(s("EDID"))\(edidStr)")
        cliPrint("\(prefix)\(s("EDID UUID Patterns"))\(display.possibleEDIDUUIDs())")
    }
}

private func handleDisplays(
    _ displayFilter: DisplayFilter,
    displays: [Display],
    property: Display.CodingKeys? = nil,
    value: String? = nil,
    json: Bool = false,
    controls: [DisplayControl]? = nil,
    read: Bool = false,
    systemInfo: Bool = false,
    panelData: Bool = false,
    panelDataAllResolutions: Bool = false,
    edid: Bool = false
) throws {
    let property = property == .mute ? .audioMuted : property
    let displays = getFilteredDisplays(displays: displays, filter: displayFilter)
    guard !displays.isEmpty else {
        throw LunarCommandError.displayNotFound(displayFilter.s)
    }

    if json, property == nil {
        cliPrint("{")
    }
    defer {
        if json, property == nil {
            cliPrint("}")
        }
    }

    for (i, display) in displays.enumerated() {
        do {
            guard let property else {
                if json {
                    try printDisplay(
                        display,
                        json: json,
                        terminator: (i == displays.count - 1) ? "\n" : ",\n",
                        prefix: "  \"\(display.serial)\": ",
                        systemInfo: systemInfo,
                        panelData: panelData,
                        panelDataAllResolutions: panelDataAllResolutions,
                        edid: edid
                    )
                } else {
                    cliPrint("\(i): \(display.name)")
                    try printDisplay(display, json: json, prefix: "\t", systemInfo: systemInfo, edid: edid)
                    if i < displays.count - 1 {
                        cliPrint("")
                    }
                }

                continue
            }

            // Initialize controls
            let oldEnabledControls = display.enabledControls
            if let controls {
                display.enabledControls = [
                    .network: controls.contains(.network),
                    .appleNative: controls.contains(.appleNative),
                    .ddc: controls.contains(.ddc),
                    .gamma: controls.contains(.gamma),
                ]
                if isServer { display.control = display.getBestControl() }
            }
            defer {
                if isServer, controls != nil {
                    display.enabledControls = oldEnabledControls
                    display.control = display.getBestControl()
                }
            }
            if !isServer { display.control = display.getBestControl() }
            // End initialize controls

            if Display.CodingKeys.settableWithControl.contains(property), !display.enabledControls[.gamma]!,
               display.hasSoftwareControl
            {
                throw LunarCommandError.controlNotAvailable((controls ?? []).map(\.str).joined(separator: ", "))
            }

            guard let propertyValue = display.dictionary?[property.rawValue] else {
                throw LunarCommandError.propertyNotValid(property.rawValue)
            }

            // Value setter command?
            guard var value else {
                if !read {
                    log.debug("CLI: Fetching value for \(property.rawValue)")
                    cliPrint("\(i): \(display.name)")
                    cliPrint("\t\(property.stringValue): \(encodedValue(key: property, value: propertyValue))")
                    continue
                }

                log.debug("CLI: Reading value for \(property.rawValue)")
                guard let readValue = display.control?.read(property) else {
                    throw LunarCommandError.cantReadProperty(property.rawValue)
                }

                cliPrint("\(i): \(display.name)")
                cliPrint("\t\(property.stringValue): \(encodedValue(key: property, value: readValue))")
                continue
            }

            log.debug("CLI: Changing \(property.rawValue) from \(propertyValue) to \(value)")
            switch propertyValue {
            case is String:
                display.withForce {
                    display.setValue(value, forKey: property.rawValue)
                }
                display.save(now: true)
            case is NSNumber
                where property == .input || property == .hotkeyInput1 || property == .hotkeyInput2 || property == .hotkeyInput3:
                guard let input = VideoInputSource(rawValue: (value.i ?? 0).u16) ?? VideoInputSource(stringValue: value) else {
                    throw LunarCommandError.invalidValue("Unknown input \(value)")
                }

                display.withForce {
                    display.setValue(input.rawValue.ns, forKey: property.rawValue)
                }

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
                    throw LunarCommandError.invalidValue("\(value) is not a boolean")
                }

                display.withForce {
                    display.setValue(newValue, forKey: property.rawValue)
                }

                display.save(now: true)
                if property == .power {
                    display.control?.write(property, newValue ? PowerState.on : PowerState.off)
                } else {
                    display.control?.write(property, newValue)
                }
            case is NSNumber where property == .rotation:
                guard let rotation = value.i, [0, 90, 180, 270].contains(rotation) else {
                    throw LunarCommandError.invalidValue("Rotation needs to be one of 0, 90, 180 or 270. \(value) is invalid.")
                }
                display.withoutModeChangeAsk {
                    display.rotation = rotation
                }
            case let currentValue as NSNumber:
                var operation = ""
                if let firstChar = value.first?.unicodeScalars.first, !CharacterSet.decimalDigits.contains(firstChar) {
                    operation = String(firstChar)
                    value = String(value.dropFirst())
                }

                guard var value = value.d?.ns else { throw LunarCommandError.invalidValue("\(value) is not a number") }

                switch operation {
                case "+" where !Display.CodingKeys.double.contains(property):
                    value = (currentValue.uint16Value + min(value.uint16Value, UINT16_MAX.u16 - currentValue.uint16Value)).ns
                case "+" where [.defaultGammaBlueValue, .defaultGammaGreenValue, .defaultGammaRedValue].contains(property):
                    value = (currentValue.doubleValue + min(value.doubleValue, 3.0 - currentValue.doubleValue)).ns
                case "+" where Display.CodingKeys.double.contains(property):
                    value = (currentValue.doubleValue + min(value.doubleValue, 1.0 - currentValue.doubleValue)).ns
                case "-" where !Display.CodingKeys.double.contains(property):
                    value = (currentValue.uint16Value - min(value.uint16Value, currentValue.uint16Value)).ns
                case "-" where [.defaultGammaBlueValue, .defaultGammaGreenValue, .defaultGammaRedValue].contains(property):
                    value = max(currentValue.doubleValue - value.doubleValue, 0.01).ns
                case "-" where Display.CodingKeys.double.contains(property):
                    value = (currentValue.doubleValue - min(value.doubleValue, currentValue.doubleValue)).ns
                case "":
                    break
                default:
                    throw LunarCommandError.invalidValue("Unknown operation \(operation) for value \(value)")
                }

                switch property {
                case .brightness:
                    let old = display.brightness
                    display.brightness = value
                    display.control?.write(property, display.limitedBrightness, old.uint16Value)
                    display.insertBrightnessUserDataPoint(
                        DC.adaptiveMode.brightnessDataPoint.last,
                        display.brightness.doubleValue, modeKey: DC.adaptiveModeKey
                    )
                case .contrast:
                    let old = display.contrast
                    display.contrast = value
                    display.control?.write(property, display.limitedContrast, old.uint16Value)
                    display.insertContrastUserDataPoint(
                        DC.adaptiveMode.contrastDataPoint.last,
                        display.contrast.doubleValue, modeKey: DC.adaptiveModeKey
                    )
                case .volume:
                    display.volume = value
                    display.control?.write(property, display.limitedVolume)
                case .normalizedBrightness:
                    let value = value.doubleValue
                    guard value >= 0, value <= 1 else { throw LunarCommandError.invalidValue("Value must be between 0 and 1") }
                    display.preciseBrightness = value
                    display.control?.write(property, display.limitedBrightness)
                    display.insertBrightnessUserDataPoint(
                        DC.adaptiveMode.brightnessDataPoint.last,
                        display.brightness.doubleValue, modeKey: DC.adaptiveModeKey
                    )
                case .normalizedContrast:
                    let value = value.doubleValue
                    guard value >= 0, value <= 1 else { throw LunarCommandError.invalidValue("Value must be between 0 and 1") }
                    display.preciseContrast = value
                    display.control?.write(property, display.limitedContrast)
                    display.insertContrastUserDataPoint(
                        DC.adaptiveMode.contrastDataPoint.last,
                        display.contrast.doubleValue, modeKey: DC.adaptiveModeKey
                    )
                case .normalizedBrightnessContrast:
                    let value = value.doubleValue
                    guard value >= 0, value <= 1 else { throw LunarCommandError.invalidValue("Value must be between 0 and 1") }
                    display.preciseBrightnessContrast = value
                    display.control?.write(property, display.limitedBrightness)
                    display.control?.write(property, display.limitedContrast)
                    display.insertBrightnessUserDataPoint(
                        DC.adaptiveMode.brightnessDataPoint.last,
                        display.brightness.doubleValue, modeKey: DC.adaptiveModeKey
                    )
                    display.insertContrastUserDataPoint(
                        DC.adaptiveMode.contrastDataPoint.last,
                        display.contrast.doubleValue, modeKey: DC.adaptiveModeKey
                    )
                case .softwareBrightness:
                    display.softwareBrightness = value.floatValue
                    if display.adaptiveSubzero {
                        display.insertBrightnessUserDataPoint(
                            DC.adaptiveMode.brightnessDataPoint.last,
                            display.brightness.doubleValue, modeKey: DC.adaptiveModeKey
                        )
                    }
                case .xdrBrightness:
                    display.xdrBrightness = value.floatValue
                default:
                    display.withForce {
                        display.setValue(value, forKey: property.rawValue)
                    }

                    if Display.CodingKeys.settableWithControl.contains(property) {
                        display.control?.write(property, value.uint16Value)
                    }
                }
                display.save(now: true)
            default:
                break
            }

            if display.control is NetworkControl {
                cliSleep(1)
            }
            cliPrint("\(i): \(display.name)")
            cliPrint("\t\(property.stringValue): \(encodedValue(key: property, value: display.dictionary![property.rawValue]!))")
        } catch {
            cliPrint("\(i): \(display.name)")
            cliPrint("\t\(error)")
        }
    }
}

private func spacing(longestKeySize: Int, key: String) -> String {
    String(repeating: " ", count: longestKeySize - key.count)
}

private func spaced(_ key: String, _ longestKeySize: Int) -> String {
    "\(key): \(String(repeating: " ", count: longestKeySize - key.count))"
}

private func encodedValue(key: Display.CodingKeys, value: Any, prefix: String = "") -> String {
    let key = key == .mute ? .audioMuted : key
    switch key {
    case .defaultGammaRedMin, .defaultGammaRedMax, .defaultGammaRedValue,
         .defaultGammaGreenMin, .defaultGammaGreenMax, .defaultGammaGreenValue,
         .defaultGammaBlueMin, .defaultGammaBlueMax, .defaultGammaBlueValue:
        return (value as! NSNumber).floatValue.str(decimals: 2)
    case .enabledControls:
        return (try! encoder.encode(value as! [String: Bool])).str()
    case .input, .hotkeyInput1, .hotkeyInput2, .hotkeyInput3:
        return (VideoInputSource(rawValue: value as! UInt16) ?? .unknown).str
    case .power:
        return (value as! Bool) ? "on" : "off"
    case .schedules:
        return "\n\(prefix)\t" + (value as! [[String: Any]]).map { scheduleDict in
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
        }.joined(separator: "\n\(prefix)\t")
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

import Socket

var cliServerTask: DispatchWorkItem? {
    didSet {
        oldValue?.cancel()
        appDelegate?.server.closeOldSockets()
    }
}

import Combine

// MARK: - LunarServer

final class LunarServer {
    deinit {
        for socket in connectedSockets.values {
            socket.close()
        }
        self.listenSocket?.close()
    }

    static let bufferSize = 4096
    static let queue = DispatchQueue(label: "fyi.lunar.cliServer.queue", qos: .userInitiated)

    @Atomic var continueRunning = true

    var listenSocket: Socket?
    var connectedSockets = [Int32: Socket]()
    var luxListeners: [Int32: AnyCancellable] = [:]
    var brightnessListeners: [Int32: AnyCancellable] = [:]
    var rawBrightnessListeners: [Int32: CGDirectDisplayID] = [:]
    var rawLuxListeners: [Int32: CGDirectDisplayID] = [:]
    var displayListeners: [Int32: AnyCancellable] = [:]
    let socketLockQueue = DispatchQueue(label: "com.kitura.serverSwift.socketLockQueue")

    var currentSocketFD: Int32 = 0

    func run(host: String = "127.0.0.1") {
        Self.queue.async {
            if let cliServerTask, !cliServerTask.isCancelled {
                Self.queue.async {
                    cliServerTask.wait(for: 60.seconds)
                }
            }

            cliServerTask = DispatchWorkItem(name: "cli-server") { [weak self] in
                do {
                    self?.listenSocket = try Socket.create(family: .inet)
                    guard let socket = self?.listenSocket else {
                        log.info("CLI: Unable to unwrap socket...")
                        return
                    }

                    try socket.listen(on: LUNAR_CLI_PORT.i, node: host)
                    log.info("CLI: Listening on port \(socket.listeningPort)")

                    repeat {
                        let newSocket = try socket.acceptClientConnection()

                        #if DEBUG
                            log.info("CLI: Accepted connection from \(newSocket.remoteHostname) on port \(newSocket.remotePort)")
                            log.info("CLI: Socket Signature \(String(describing: newSocket.signature?.description))")
                        #endif

                        self?.addNewConnection(socket: newSocket)

                    } while self?.continueRunning ?? false
                } catch {
                    guard let socketError = error as? Socket.Error else {
                        log.error("CLI: Unexpected error \(error)")
                        return
                    }

                    if let self, continueRunning {
                        log.error("CLI: Error reported\n\t\(socketError.description)")
                    }
                }
            }
            Self.queue.async(execute: cliServerTask!.workItem)
        }
    }

    func onResponse(_ response: String, socket: Socket) throws {
        let lines = response.split(separator: "\r\n")
        let serverHTTP = lines.first?.contains("HTTP") ?? false

        defer {
            serverExitCode = 0
            serverOutput = ""
        }

        do {
            var key = lines
                .first(where: { $0.lowercased().starts(with: "authorization:") })?
                .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                .last?.s.trimmed

            var line = lines.last?.s
            if let l = line, serverHTTP, !l.starts(with: "cmd=") {
                line = try socket.readString()
            }
            if let l = line, l.starts(with: "cmd=") {
                line = l.suffix(l.count - 4).replacingOccurrences(of: "+", with: " ").removingPercentEncoding
            }

            guard var args = line?
                .split(separator: response.contains(CLI_ARG_SEPARATOR) ? CLI_ARG_SEPARATOR.first! : " ")
                .map({ String($0) })
                .without("--remote")
            else { return }
            key = key ?? args.removeFirst()

            guard key == CachedDefaults[.apiKey] else {
                let resp = "Unauthorized\n"
                if serverHTTP {
                    try socket.write(from: "HTTP/1.1 401 Unauthorized\r\nContent-Length: \(resp.count)\r\n\r\n")
                }
                try socket.write(from: resp)
                return
            }

            var command = try Lunar.parseAsRoot(args)
            try mainThreadThrows {
                try command.run()
            }
            let statusCode = serverExitCode == 0 ? "" : "Status-Code: \(serverExitCode)\r\n"

            if !serverOutput.isEmpty {
                let jsonHeader = args.contains("--json") ? "Content-Type: application/json\r\n" : ""
                if serverHTTP {
                    try socket.write(from: "HTTP/1.1 200 OK\r\n\(jsonHeader)\(statusCode)Content-Length: \(serverOutput.count)\r\n\r\n")
                    try socket.write(from: serverOutput)
                } else {
                    try socket.write(from: statusCode + serverOutput)
                }
            } else if serverHTTP {
                try socket.write(from: "HTTP/1.1 204 No Content\r\n\(statusCode)Content-Length: 0\r\n\r\n")
            }
        } catch {
            let statusCode = serverExitCode == 0 ? "" : "Status-Code: \(serverExitCode)\r\n"
            let err = Lunar.fullMessage(for: error) + "\n"

            if serverHTTP {
                try socket.write(from: "HTTP/1.1 400 Bad Request\r\n\(statusCode)Content-Length: \(err.count)\r\n\r\n")
                try socket.write(from: err)
            } else {
                try socket.write(from: statusCode + err)
            }
        }
    }

    func write(lux: Double, to socketFd: Int32) {
        socketLockQueue.async(flags: .barrier) { [weak self] in
            guard let self, let socket = connectedSockets[socketFd] else {
                _ = storeLock.around {
                    self?.luxListeners.removeValue(forKey: socketFd)
                }
                return
            }
            let val = String(format: "%.3f", lux)
            #if DEBUG
                log.debug("CLI: Writing \(val) to \(socketFd)")
            #endif
            _ = try? socket.write(from: "\(val)\n")
        }
    }

    func write(_ change: DisplayStateChange, to socketFd: Int32, json: Bool) {
        socketLockQueue.async(flags: .barrier) { [weak self] in
            guard let self, let socket = connectedSockets[socketFd] else {
                storeLock.around {
                    self?.brightnessListeners.removeValue(forKey: socketFd)
                    self?.displayListeners.removeValue(forKey: socketFd)
                    if let id = self?.rawBrightnessListeners[socketFd] {
                        DisplayServicesUnregisterForBrightnessChangeNotifications(id, id)
                        self?.rawBrightnessListeners.removeValue(forKey: socketFd)
                    }
                    if let id = self?.rawLuxListeners[socketFd] {
                        DisplayServicesUnregisterForAmbientLightCompensationNotifications(id, id)
                        self?.rawLuxListeners.removeValue(forKey: socketFd)
                    }
                }
                return
            }
            let val = change.property == "mute" ? (change.value == 1 ? "true" : "false") : String(format: "%.3f", change.value)

            do {
                if json {
                    #if DEBUG
                        log.debug("CLI: Writing {\"\(change.property)\": \(val), \"display\": \(change.display)}\n to \(socketFd)")
                    #endif
                    _ = try socket.write(from: "{\"\(change.property)\": \(val), \"display\": \(change.display)}\n")
                } else {
                    #if DEBUG
                        log.debug("CLI: Writing \(change.property) \(val) \(change.display) to \(socketFd)")
                    #endif
                    _ = try socket.write(from: "\(change.property) \(val) \(change.display)\n")
                }
            } catch {
                log.error("CLI: Error writing to socket \(socketFd): \(error)")
                connectedSockets.removeValue(forKey: socketFd)
            }
        }
    }

    func addNewConnection(socket: Socket) {
        socketLockQueue.sync { [socket] in
            currentSocketFD = socket.socketfd
            connectedSockets[socket.socketfd] = socket
        }

        DispatchQueue.global(qos: .default).async { [weak self, socket] in
//             print("\(Date()) Starting addNewConnection")
//             defer { print("\(Date()) Finished addNewConnection") }

            var shouldKeepRunning = true
            var readData = Data(capacity: Self.bufferSize)

            do {
                readLoop: repeat {
                    switch try socket.read(into: &readData) {
                    case 1 ... Self.bufferSize:
                        guard let response = String(data: readData, encoding: .utf8)?.trimmed else {
                            log.error("CLI: Error decoding response...")
                            readData.removeAll(keepingCapacity: true)
                            break readLoop
                        }

                        log.info("CLI: Server received from connection at \(socket.remoteHostname):\(socket.remotePort): \(response) ")
                        guard let self else { return }
                        try onResponse(response, socket: socket)
                    case 0:
                        log.info("CLI: Read 0 bytes, closing socket")
                        shouldKeepRunning = false
                        break readLoop
                    default:
                        log.warning("CLI: Read too many bytes!")
                        readData.removeAll(keepingCapacity: true)
                        break readLoop
                    }

                    readData.removeAll(keepingCapacity: true)
                } while shouldKeepRunning

                guard let self else {
                    return
                }
                if storeLock.around({ self.brightnessListeners[socket.socketfd] ?? self.luxListeners[socket.socketfd] }) != nil ||
                    storeLock.around({ self.rawBrightnessListeners[socket.socketfd] ?? self.rawLuxListeners[socket.socketfd] }) != nil
                {
                    log.info("CLI: Socket \(socket.remoteHostname):\(socket.remotePort) still has listeners, not closing...")
                    return
                }
                log.info("CLI: Socket \(socket.remoteHostname):\(socket.remotePort) closed...")
                socket.close()

                socketLockQueue.sync { [socket] in
                    self.connectedSockets[socket.socketfd] = nil
                }
            } catch {
                guard let socketError = error as? Socket.Error else {
                    log.error("CLI: Unexpected error by connection at \(socket.remoteHostname):\(socket.remotePort)...")
                    return
                }
                if let self, continueRunning {
                    log.error("CLI: Error reported by connection at \(socket.remoteHostname):\(socket.remotePort):\n \(socketError.description)")
                }
            }
        }
    }

    func closeOldSockets() {
        socketLockQueue.sync {
            for socket in connectedSockets.values.filter({ $0.socketfd != self.currentSocketFD }) {
                connectedSockets.removeValue(forKey: socket.socketfd)
                socket.close()
            }
        }
    }

    func stop() {
        log.info("CLI Server shutdown in progress...")
        continueRunning = false

        for socket in connectedSockets.values {
            socketLockQueue.sync { [socket] in
                connectedSockets[socket.socketfd] = nil
                socket.close()
            }
        }
        socketLockQueue.sync {
            connectedSockets.removeAll()
        }
    }

    func stopAsync() {
        log.info("CLI Server shutdown in progress...")
        socketLockQueue.async(flags: .barrier) {
            self.continueRunning = false

            for socket in self.connectedSockets.values {
                self.connectedSockets[socket.socketfd] = nil
                socket.close()
            }
            self.connectedSockets.removeAll()
        }
    }
}

struct DisplayStateChange: Equatable {
    var property: String
    var value: Double
    var display: CGDirectDisplayID
}

var isServer = false
var isShortcut = false
var serverOutput = ""
var serverExitCode: Int32 = 0
var serverHTTP = false
func cliSleep(_ time: TimeInterval) {
    guard !isServer else { return }
    Thread.sleep(forTimeInterval: time)
}

func cliExit(_ code: Int32) {
    guard !isServer else {
        if serverOutput.isEmpty {
            serverOutput = "\n"
        }
        serverExitCode = code
        return
    }
    exit(code)
}

func cliPrint(_ s: Any, terminator: String = "\n") {
    guard !isServer || isShortcut else {
        #if DEBUG
            log.debug("CLI: \(s)\(terminator)")
        #endif
        serverOutput += "\(s)\(terminator)"
        return
    }
    print(s, terminator: terminator)
}

func cliGetDisplays(
    includeVirtual: Bool = true,
    includeAirplay: Bool = false,
    includeProjector: Bool = false,
    includeDummy: Bool = false
) {
    guard !isServer else {
        return
    }
    DC.displays = DisplayController.getDisplays(
        includeVirtual: includeVirtual,
        includeAirplay: includeAirplay,
        includeProjector: includeProjector,
        includeDummy: includeDummy
    )
}

func serve(host: String) {
    isServer = true
    guard let appDelegate else { return }
    appDelegate.server = LunarServer()
    appDelegate.server.run(host: host)
}

var gammaRepeater: Repeater?

let LUNAR_CLI_SCRIPT =
    """
    #!/bin/sh
    if [[ "$1" == "ddcctl" ]]; then
        shift 1
        "\(Bundle.main.path(forResource: "ddcctl", ofType: nil)!)" "$@"
    elif [[ "$1" == "launch" ]]; then
        "\(Bundle.main.bundlePath)/Contents/MacOS/Lunar"
    else
        "\(Bundle.main.bundlePath)/Contents/MacOS/Lunar" @ "$@"
    fi
    """

let STATUS_CODE_REGEX = #"Status-Code:\s*(\d+)\r?\n?"#.r!
