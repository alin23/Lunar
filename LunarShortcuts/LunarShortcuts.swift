//
//  LunarShortcuts.swift
//  LunarShortcuts
//
//  Created by Alin Panaitiu on 10.12.2022.
//  Copyright © 2022 Alin. All rights reserved.
//

import AppIntents
import CoreGraphics
import Defaults
import Foundation
import Socket

@available(iOS 16, macOS 13, *)
extension Display {
    var screen: Screen { Screen(id: id, name: name, serial: serial, display: self) }
}

// MARK: - Screen

@available(iOS 16, macOS 13, *)
final class Screen: NSObject, AppEntity {
    init(id: CGDirectDisplayID, name: String, serial: String, display: Display? = nil, isDynamicFilter: Bool = false) {
        self.isDynamicFilter = isDynamicFilter

        super.init()
        self.id = id.i
        self.name = name
        self.serial = serial
        let display = display ?? displayController.activeDisplaysBySerial[serial]

        guard let display else {
            self.display = nil

            return
        }

        self.display = display
        isExternal = display.isExternal
        isBuiltin = display.isBuiltin
        isSidecar = display.isSidecar
        isAirplay = display.isAirplay
        isVirtual = display.isVirtual
        isProjector = display.isProjector
        rotation = display.rotation
        supportsHDR = display.panel?.hasHDRModes ?? false
        supportsXDR = display.supportsEnhance
        hdr = display.hdr
        xdr = display.xdr
        subzero = display.subzero
        blackout = display.blackout
        facelight = display.facelight
        adaptive = display.adaptive

        brightness = display.preciseBrightness
        contrast = display.preciseContrast
        brightnessContrast = display.preciseBrightnessContrast
        subzeroDimming = display.subzeroDimming.d
        xdrBrightness = display.xdrBrightness.d
    }

    static var defaultQuery = ScreenQuery()

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Screen", numericFormat: "\(placeholder: .int) screens")
    }

    lazy var panelModes: [PanelMode] = display?.panelModes.compactMap(\.panelMode) ?? []

    let isDynamicFilter: Bool
    @Property(title: "ID")
    @objc var id: Int
    @Property(title: "Name")
    @objc var name: String
    @Property(title: "Serial")
    @objc var serial: String

    weak var display: Display?

    @Property(title: "Brightness")
    @objc var brightness: Double
    @Property(title: "Contrast")
    @objc var contrast: Double
    @Property(title: "Brightness & Contrast")
    @objc var brightnessContrast: Double
    @Property(title: "Sub-zero Dimming")
    @objc var subzeroDimming: Double
    @Property(title: "XDR Brightness")
    @objc var xdrBrightness: Double

    @Property(title: "is External")
    @objc var isExternal: Bool
    @Property(title: "is Builtin")
    @objc var isBuiltin: Bool
    @Property(title: "is Sidecar")
    @objc var isSidecar: Bool
    @Property(title: "is Airplay")
    @objc var isAirplay: Bool
    @Property(title: "is Virtual")
    @objc var isVirtual: Bool
    @Property(title: "is Projector")
    @objc var isProjector: Bool
    @Property(title: "Rotation")
    @objc var rotation: Int

    @Property(title: "supports HDR")
    @objc var supportsHDR: Bool
    @Property(title: "supports XDR")
    @objc var supportsXDR: Bool
    @Property(title: "HDR enabled")
    @objc var hdr: Bool
    @Property(title: "XDR enabled")
    @objc var xdr: Bool
    @Property(title: "Sub-zero enabled")
    @objc var subzero: Bool
    @Property(title: "BlackOut enabled")
    @objc var blackout: Bool
    @Property(title: "Facelight enabled")
    @objc var facelight: Bool
    @Property(title: "Adaptive enabled")
    @objc var adaptive: Bool

    var displays: [Display] {
        guard let displayFilter = DisplayFilter(argument: serial) else {
            return []
        }
        return getFilteredDisplays(displays: displayController.activeDisplayList, filter: displayFilter)
    }
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: isDynamicFilter ? nil : "\(serial)")
    }

    override var hash: Int {
        var h = Hasher()
        h.combine(id)
        h.combine(serial)
        return h.finalize()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Screen else {
            return false
        }
        return id == other.id && serial == other.serial
    }
}

// MARK: - ScreenQuery

@available(iOS 16, macOS 13, *)
struct ScreenQuery: EntityPropertyQuery {
    init() {}
    init(filter: ((Display) -> Bool)? = nil, single: Bool = false, additionalScreens: [Screen]? = nil, noDefault: Bool = false) {
        self.filter = filter
        self.single = single
        self.additionalScreens = additionalScreens
        self.noDefault = noDefault
    }

    typealias Entity = Screen

    static var properties = EntityQueryProperties<Screen, NSPredicate> {
        Property(\.$name) {
            EqualToComparator { NSPredicate(format: "name = %@", $0) }
            NotEqualToComparator { NSPredicate(format: "name != %@", $0) }
            ContainsComparator { NSPredicate(format: "name CONTAINS %@", $0) }
            HasPrefixComparator { NSPredicate(format: "name BEGINSWITH[cd] %@", $0) }
            HasSuffixComparator { NSPredicate(format: "name ENDSWITH[cd] %@", $0) }
        }
        Property(\.$serial) {
            EqualToComparator { NSPredicate(format: "serial = %@", $0) }
            NotEqualToComparator { NSPredicate(format: "serial != %@", $0) }
        }
        Property(\.$id) {
            EqualToComparator { NSPredicate(format: "id = %d", $0) }
            NotEqualToComparator { NSPredicate(format: "id != %d", $0) }
            GreaterThanOrEqualToComparator { NSPredicate(format: "id >= %d", $0) }
            LessThanOrEqualToComparator { NSPredicate(format: "id <= %d", $0) }
            GreaterThanComparator { NSPredicate(format: "id > %d", $0) }
            LessThanComparator { NSPredicate(format: "id < %d", $0) }
        }
        Property(\.$isExternal) {
            EqualToComparator { _ in NSPredicate(format: "isExternal = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "isExternal = NO") }
        }
        Property(\.$isBuiltin) {
            EqualToComparator { _ in NSPredicate(format: "isBuiltin = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "isBuiltin = NO") }
        }
        Property(\.$isSidecar) {
            EqualToComparator { _ in NSPredicate(format: "isSidecar = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "isSidecar = NO") }
        }
        Property(\.$isAirplay) {
            EqualToComparator { _ in NSPredicate(format: "isAirplay = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "isAirplay = NO") }
        }
        Property(\.$isVirtual) {
            EqualToComparator { _ in NSPredicate(format: "isVirtual = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "isVirtual = NO") }
        }
        Property(\.$isProjector) {
            EqualToComparator { _ in NSPredicate(format: "isProjector = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "isProjector = NO") }
        }
        Property(\.$rotation) {
            EqualToComparator { NSPredicate(format: "rotation = %d", $0) }
            NotEqualToComparator { NSPredicate(format: "rotation != %d", $0) }
        }

        Property(\.$supportsHDR) {
            EqualToComparator { _ in NSPredicate(format: "supportsHDR = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "supportsHDR = NO") }
        }
        Property(\.$supportsXDR) {
            EqualToComparator { _ in NSPredicate(format: "supportsXDR = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "supportsXDR = NO") }
        }
        Property(\.$hdr) {
            EqualToComparator { _ in NSPredicate(format: "hdr = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "hdr = NO") }
        }
        Property(\.$xdr) {
            EqualToComparator { _ in NSPredicate(format: "xdr = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "xdr = NO") }
        }
        Property(\.$subzero) {
            EqualToComparator { _ in NSPredicate(format: "subzero = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "subzero = NO") }
        }
        Property(\.$blackout) {
            EqualToComparator { _ in NSPredicate(format: "blackout = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "blackout = NO") }
        }
        Property(\.$facelight) {
            EqualToComparator { _ in NSPredicate(format: "facelight = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "facelight = NO") }
        }
        Property(\.$adaptive) {
            EqualToComparator { _ in NSPredicate(format: "adaptive = YES") }
            NotEqualToComparator { _ in NSPredicate(format: "adaptive = NO") }
        }

        Property(\.$brightness) {
            EqualToComparator { NSPredicate(format: "brightness = %f", $0 / 100.0) }
            NotEqualToComparator { NSPredicate(format: "brightness != %f", $0 / 100.0) }
            GreaterThanOrEqualToComparator { NSPredicate(format: "brightness >= %f", $0 / 100.0) }
            LessThanOrEqualToComparator { NSPredicate(format: "brightness <= %f", $0 / 100.0) }
            GreaterThanComparator { NSPredicate(format: "brightness > %f", $0 / 100.0) }
            LessThanComparator { NSPredicate(format: "brightness < %f", $0 / 100.0) }
        }
        Property(\.$contrast) {
            EqualToComparator { NSPredicate(format: "contrast = %f", $0 / 100.0) }
            NotEqualToComparator { NSPredicate(format: "contrast != %f", $0 / 100.0) }
            GreaterThanOrEqualToComparator { NSPredicate(format: "contrast >= %f", $0 / 100.0) }
            LessThanOrEqualToComparator { NSPredicate(format: "contrast <= %f", $0 / 100.0) }
            GreaterThanComparator { NSPredicate(format: "contrast > %f", $0 / 100.0) }
            LessThanComparator { NSPredicate(format: "contrast < %f", $0 / 100.0) }
        }
        Property(\.$brightnessContrast) {
            EqualToComparator { NSPredicate(format: "brightnessContrast = %f", $0 / 100.0) }
            NotEqualToComparator { NSPredicate(format: "brightnessContrast != %f", $0 / 100.0) }
            GreaterThanOrEqualToComparator { NSPredicate(format: "brightnessContrast >= %f", $0 / 100.0) }
            LessThanOrEqualToComparator { NSPredicate(format: "brightnessContrast <= %f", $0 / 100.0) }
            GreaterThanComparator { NSPredicate(format: "brightnessContrast > %f", $0 / 100.0) }
            LessThanComparator { NSPredicate(format: "brightnessContrast < %f", $0 / 100.0) }
        }
        Property(\.$subzeroDimming) {
            EqualToComparator { NSPredicate(format: "subzeroDimming = %f", $0 / 100.0) }
            NotEqualToComparator { NSPredicate(format: "subzeroDimming != %f", $0 / 100.0) }
            GreaterThanOrEqualToComparator { NSPredicate(format: "subzeroDimming >= %f", $0 / 100.0) }
            LessThanOrEqualToComparator { NSPredicate(format: "subzeroDimming <= %f", $0 / 100.0) }
            GreaterThanComparator { NSPredicate(format: "subzeroDimming > %f", $0 / 100.0) }
            LessThanComparator { NSPredicate(format: "subzeroDimming < %f", $0 / 100.0) }
        }
        Property(\.$xdrBrightness) {
            EqualToComparator { NSPredicate(format: "xdrBrightness = %f", $0 / 100.0) }
            NotEqualToComparator { NSPredicate(format: "xdrBrightness != %f", $0 / 100.0) }
            GreaterThanOrEqualToComparator { NSPredicate(format: "xdrBrightness >= %f", $0 / 100.0) }
            LessThanOrEqualToComparator { NSPredicate(format: "xdrBrightness <= %f", $0 / 100.0) }
            GreaterThanComparator { NSPredicate(format: "xdrBrightness > %f", $0 / 100.0) }
            LessThanComparator { NSPredicate(format: "xdrBrightness < %f", $0 / 100.0) }
        }

    }

    static var sortingOptions = SortingOptions {
        SortableBy(\.$name)
        SortableBy(\.$id)
        SortableBy(\.$isExternal)
        SortableBy(\.$brightness)
        SortableBy(\.$contrast)
        SortableBy(\.$brightnessContrast)
    }

    static let dynamicFilterScreens = DisplayFilter.allCases.map(\.screen)
    static let dynamicFilterScreenMapping = dynamicFilterScreens.dict { ($0.id, $0) }

    var filter: ((Display) -> Bool)?
    var single = false
    var additionalScreens: [Screen]?
    var noDefault = false

    func entities(
        matching comparators: [NSPredicate],
        mode: ComparatorMode,
        sortedBy: [Sort<Screen>],
        limit: Int?
    ) async throws -> [Screen] {
        let predicate = NSCompoundPredicate(type: mode == .and ? .and : .or, subpredicates: comparators)
        return displayController.activeDisplayList
            .map(\.screen)
            .filter { predicate.evaluate(with: $0) }
            .sorted(by: { this, other in
                var increasing = 1
                for sorter in sortedBy {
                    switch (this[keyPath: sorter.by], other[keyPath: sorter.by]) {
                    case let (x as String, y as String):
                        increasing += x > y ? 1 : -1
                    case let (x as Int, y as Int):
                        increasing += x > y ? 1 : -1
                    case let (x as Bool, y as Bool):
                        increasing += x && !y ? 1 : (y && !x ? -1 : 0)
                    default:
                        continue
                    }
                }

                return increasing > 0
            })
    }

    func defaultResult() async -> Screen? {
        guard !noDefault else { return nil }

        if let additionalScreens, !additionalScreens.isEmpty {
            return additionalScreens.first
        }

        let screens: [Screen]
        if let filter {
            screens = displayController.activeDisplayList.filter(filter).map(\.screen)
        } else {
            screens = displayController.activeDisplayList.map(\.screen)
        }

        return screens.first
    }

    func suggestedEntities() async throws -> Result<[Screen], Error> {
        .success(try await results())
    }

    func results() async throws -> [Screen] {
        let screens: [Screen]
        if let filter {
            screens = displayController.activeDisplayList.filter(filter).map(\.screen)
        } else {
            screens = displayController.activeDisplayList.map(\.screen)
        }

        guard !single else {
            return (additionalScreens ?? []) + screens + [DisplayFilter.cursor.screen]
        }

        return (additionalScreens ?? []) + screens + Self.dynamicFilterScreens
    }

    func entities(matching query: String) async throws -> [Screen] {
        let matches = displayController.activeDisplayList.filter {
            $0.name == query || $0.serial == query
        }.map(\.screen)

        guard !matches.isEmpty else {
            return [Screen(id: 0, name: query, serial: "")]
        }

        return matches
    }

    func entities(for identifiers: [Int]) async throws -> [Screen] {
        guard !identifiers.isEmpty else {
            return displayController.activeDisplayList.map(\.screen)
        }

        return identifiers.compactMap { id in
            displayController.activeDisplays[id.u32]?.screen ??
                Self.dynamicFilterScreenMapping[id] ??
                (additionalScreens ?? []).first(where: { $0.id == id })
        }
    }
}

// MARK: - IntentError

@available(iOS 16, macOS 13, *)
enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case general
    case message(_ message: String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .message(message): return "Error: \(message)"
        case .general: return "Error"
        }
    }
}

@available(iOS 16, macOS 13, *)
func controlScreen(screen: IntentParameter<Screen>, property: Display.CodingKeys, value: String) throws -> some IntentResult {
    let scr = screen.wrappedValue
    guard !(scr.serial + scr.name).isEmpty else {
        throw screen.needsValueError()
    }

    let command = try Lunar.Displays
        .parse([scr.serial.isEmpty ? scr.name : scr.serial, property.rawValue, value])

    try mainThreadThrows {
        isShortcut = true
        try command.run()
        isShortcut = false
    }

    return .result()
}

// MARK: - SetBrightnessValue

@available(iOS 16, macOS 13, *)
struct SetBrightnessIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Set Brightness"
    static var description = IntentDescription("Sets the Brightness of a screen to a specific value. The percentage will compute a value between the Min and Max Brightness of the screen.", categoryName: "Brightness")

    static var parameterSummary: some ParameterSummary { Summary("Set \(\.$screen) brightness to \(\.$value)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery())
    var screen: Screen

    @Parameter(title: "Value", controlStyle: .slider, inclusiveRange: (0.0, 1.0))
    var value: Double

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: .normalizedBrightness, value: value.str(decimals: 3))
    }
}

@available(iOS 16, macOS 13, *)
struct SetContrastIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Set Contrast"
    static var description = IntentDescription("Sets the Contrast of a screen to a specific value. The percentage will compute a value between the Min and Max Contrast of the screen.", categoryName: "Brightness")

    static var parameterSummary: some ParameterSummary { Summary("Set \(\.$screen) contrast to \(\.$value)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.hasDDC }))
    var screen: Screen

    @Parameter(title: "Value", controlStyle: .slider, inclusiveRange: (0.0, 1.0))
    var value: Double

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: .normalizedContrast, value: value.str(decimals: 3))
    }
}

@available(iOS 16, macOS 13, *)
struct SetBrightnessContrastIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Set Brightness & Contrast"
    static var description = IntentDescription(
        "Sets the Brightness and Contrast of a screen to specific values. The percentage will compute a value between the Min and Max Brightness and Contrast of the screen.",
        categoryName: "Brightness"
    )

    static var parameterSummary: some ParameterSummary { Summary("Set \(\.$screen) combined brightness & contrast to \(\.$value)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery())
    var screen: Screen

    @Parameter(title: "Value", controlStyle: .slider, inclusiveRange: (0.0, 1.0))
    var value: Double

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: .normalizedBrightnessContrast, value: value.str(decimals: 3))
    }
}

@available(iOS 16, macOS 13, *)
struct SetSubZeroDimmingIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Set Sub-zero Dimming"
    static var description = IntentDescription("Sets the Sub-zero Dimming of a screen to specific value. 0% means as black as possible while 100% means no dimming is applied.", categoryName: "Brightness")

    static var parameterSummary: some ParameterSummary { Summary("Set \(\.$screen) Sub-zero Dimming to \(\.$value)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery())
    var screen: Screen

    @Parameter(title: "Value", controlStyle: .slider, inclusiveRange: (0.0, 1.0))
    var value: Double

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: .softwareBrightness, value: value.str(decimals: 3))
    }
}

@available(iOS 16, macOS 13, *)
struct SetXDRBrightnessIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Set XDR Brightness"
    static var description = IntentDescription("Sets the XDR Brightness of a screen to specific value if it supports brightness higher than 500 nits.", categoryName: "Brightness")

    static var parameterSummary: some ParameterSummary { Summary("Set \(\.$screen) XDR Brightness to \(\.$value)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.supportsEnhance }))
    var screen: Screen

    @Parameter(title: "Value", controlStyle: .slider, inclusiveRange: (0.0, 1.0))
    var value: Double

    @MainActor
    func perform() async throws -> some IntentResult {
        guard lunarProActive else {
            throw IntentError.message("A Lunar Pro license is needed for this feature.")
        }
        return try controlScreen(screen: $screen, property: .xdrBrightness, value: value.str(decimals: 3))
    }
}

@available(iOS 16, macOS 13, *)
struct SetVolumeIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Set Volume"
    static var description = IntentDescription("Sets the Volume of a screen to specific value if it supports the volume control.", categoryName: "DDC")

    static var parameterSummary: some ParameterSummary { Summary("Set \(\.$screen) volume to \(\.$value)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.canChangeVolume }))
    var screen: Screen

    @Parameter(title: "Value", controlStyle: .slider, inclusiveRange: (0.0, 1.0))
    var value: Double

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: .volume, value: (value * 100).rounded().u16.s)
    }
}

@available(iOS 16, macOS 13, *)
enum ScreenToggleState: String, AppEnum, CaseDisplayRepresentable, TypeDisplayRepresentable {
    case on
    case off
    case toggle

    static var caseDisplayRepresentations: [ScreenToggleState: DisplayRepresentation] = [
        .on: "On",
        .off: "Off",
        .toggle: "Toggle",
    ]

    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "State") }

    var inverted: ScreenToggleState {
        switch self {
        case .on:
            return .off
        case .off:
            return .on
        case .toggle:
            return .toggle
        }
    }

}

@available(iOS 16, macOS 13, *)
struct ToggleAudioMuteIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Toggle Audio Mute"
    static var description = IntentDescription("Toggles audio mute on a screen if it supports audio control.", categoryName: "DDC")

    static var parameterSummary: some ParameterSummary { Summary("Toggle audio mute of \(\.$screen) to \(\.$state)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.canChangeVolume }))
    var screen: Screen

    @Parameter(title: "State")
    var state: ScreenToggleState

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: .mute, value: state.rawValue)
    }
}

@available(iOS 16, macOS 13, *)
struct ToggleSystemAdaptiveBrightnessIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Toggle System Adaptive Brightness"
    static var description = IntentDescription("Toggles the \"Automatically adjust brightness\" checkbox in System Settings for a specific screen.", categoryName: "Toggles")

    static var parameterSummary: some ParameterSummary { Summary("Toggle system adaptive brightness for \(\.$screen) to \(\.$state)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.hasAmbientLightAdaptiveBrightness }))
    var screen: Screen

    @Parameter(title: "State")
    var state: ScreenToggleState

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: .systemAdaptiveBrightness, value: state.rawValue)
    }
}

@available(iOS 16, macOS 13, *)
struct ToggleHDRIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Toggle HDR"
    static var description = IntentDescription("Toggles HDR on/off for a screen if it supports high dynamic range.", categoryName: "Toggles")

    static var parameterSummary: some ParameterSummary { Summary("Toggle HDR for \(\.$screen) to \(\.$state)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.panel?.hasHDRModes ?? false }))
    var screen: Screen

    @Parameter(title: "State")
    var state: ScreenToggleState

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: .hdr, value: state.rawValue)
    }
}

@available(iOS 16, macOS 13, *)
struct ToggleXDRIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Toggle XDR Brightness"
    static var description = IntentDescription("Toggles XDR Brightness on/off for a screen if it supports brightness higher than 500 nits.", categoryName: "Toggles")

    static var parameterSummary: some ParameterSummary { Summary("Toggle XDR Brightness for \(\.$screen) to \(\.$state)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.supportsEnhance }))
    var screen: Screen

    @Parameter(title: "State")
    var state: ScreenToggleState

    @MainActor
    func perform() async throws -> some IntentResult {
        guard lunarProActive else {
            throw IntentError.message("A Lunar Pro license is needed for this feature.")
        }
        return try controlScreen(screen: $screen, property: .xdr, value: state.rawValue)
    }
}

@available(iOS 16, macOS 13, *)
struct ToggleSubZeroIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Toggle Sub-zero Dimming"
    static var description = IntentDescription("Toggles Sub-zero Dimming on/off for a screen.", categoryName: "Toggles")

    static var parameterSummary: some ParameterSummary { Summary("Toggle Sub-zero Dimming to \(\.$screen) to \(\.$state)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.supportsEnhance }))
    var screen: Screen

    @Parameter(title: "State")
    var state: ScreenToggleState

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: .subzero, value: state.rawValue)
    }
}

@available(iOS 16, macOS 13, *)
struct ToggleFacelightIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Toggle Facelight"
    static var description = IntentDescription("Toggles Facelight on/off for a screen.", categoryName: "Toggles")

    static var parameterSummary: some ParameterSummary { Summary("Toggle Facelight for \(\.$screen) to \(\.$state)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery())
    var screen: Screen

    @Parameter(title: "State")
    var state: ScreenToggleState

    @MainActor
    func perform() async throws -> some IntentResult {
        guard lunarProActive else {
            throw IntentError.message("A Lunar Pro license is needed for this feature.")
        }
        return try controlScreen(screen: $screen, property: .facelight, value: state.rawValue)
    }
}

@available(iOS 16, macOS 13, *)
struct PowerOffSoftwareIntent: AppIntent {
    init() {}

    // swiftformat:disable all
    static var title: LocalizedStringResource = "Power off screen (in software)"
    static var description = IntentDescription(
    """
Power off a screen by:
  - setting its brightness and contrast to 0
  - altering the Gamma curve so all the colors become pitch black
  - (optional) mirroring the screen so that it becomes disabled
    - also moves windows away to other visible screens
  - spawning a background task to keep the above conditions in check
""", categoryName: "Power")

    // swiftformat:enable all

    static var parameterSummary: some ParameterSummary {
        When(\.$disableScreen, .equalTo, true, {
            Summary("Power off \(\.$screen) and \(\.$disableScreen) by mirroring from \(\.$visibleScreen)")
        }, otherwise: {
            Summary("Power off \(\.$screen) and \(\.$disableScreen) (only make it black without mirroring)")
        })
    }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery())
    var screen: Screen

    @Parameter(title: "Visible Screen", optionsProvider: ScreenQuery(single: true, additionalScreens: [Screen(id: UInt32.max.u32 - 30, name: "a remaining visible screen", serial: "visibleScreen", isDynamicFilter: true)]))
    var visibleScreen: Screen?

    @Parameter(title: "Disable Screen", default: true, displayName: Bool.IntentDisplayName(true: "disable screen", false: "keep screen enabled"))
    var disableScreen: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        guard lunarProActive else {
            throw IntentError.message("A Lunar Pro license is needed for this feature.")
        }

        let displays = screen.displays

        guard !displays.isEmpty else {
            throw $screen.needsValueError()
        }

        let displayIDs = Set(displays.map(\.id))

        if disableScreen {
            if let master = screen.display {
                if displays.contains(master) {
                    throw $visibleScreen.needsValueError("Screen to mirror from should not be in the list of displays to be powered off")
                }
                if master.blackOutEnabled {
                    throw $visibleScreen.needsValueError("Screen to mirror from should not be powered off")
                }
            } else if displayController.activeDisplayList.filter(
                { !displayIDs.contains($0.id) && !$0.blackOutEnabled }
            ).first == nil {
                throw $visibleScreen.needsValueError("No visible screen remaining to mirror from")
            }
        }

        var master: Display?
        if disableScreen, let masterD = screen.display ?? displayController.activeDisplayList.filter(
            { !displayIDs.contains($0.id) && !$0.blackOutEnabled }
        ).first {
            master = masterD
        }

        let ms = disableScreen ? 3000 : 200
        for (i, display) in displays.enumerated() {
            mainAsyncAfter(ms: i * ms) {
                log.info("Turning off \(display)")
                lastBlackOutToggleDate = .distantPast
                displayController.blackOut(
                    display: display.id,
                    state: .on,
                    mirroringAllowed: disableScreen,
                    master: master?.id
                )
            }
        }
        try await Task.sleep(for: .milliseconds(displays.count * ms))

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct PowerOnSoftwareIntent: AppIntent {
    init() {}

    // swiftformat:disable all
    static var title: LocalizedStringResource = "Power on screen (in software)"
    static var description = IntentDescription("Power on a screen if it was previously powered off using BlackOut.", categoryName: "Power")

    // swiftformat:enable all

    static var parameterSummary: some ParameterSummary {
        Summary("Power on \(\.$screen)")
    }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery())
    var screen: Screen

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        let displays = screen.displays

        guard !displays.isEmpty else {
            throw $screen.needsValueError()
        }

        var ms = 0
        var lastDisplayWasMirrored = false
        for (i, display) in displays.enumerated() {
            let afterMS = i * (lastDisplayWasMirrored ? 200 : 3000)
            ms += afterMS

            mainAsyncAfter(ms: afterMS) {
                log.info("Turning on \(display)")
                lastBlackOutToggleDate = .distantPast
                lastDisplayWasMirrored = display.blackOutEnabled && display.isInMirrorSet && !display.mirroredBeforeBlackOut

                displayController.blackOut(
                    display: display.id,
                    state: .off,
                    mirroringAllowed: false
                )
            }
        }
        try await Task.sleep(for: .milliseconds(ms))

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct ToggleBlackOutIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Toggle Power (BlackOut)"
    static var description = IntentDescription("Toggles Power on/off for a screen using Lunar's BlackOut function.", categoryName: "Power")

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle power of \(\.$screen) to \(\.$state)") {
            \.$allowMirroring
        }
    }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery())
    var screen: Screen

    @Parameter(title: "State")
    var state: ScreenToggleState

    @Parameter(title: "Allow mirroring", default: false)
    var allowMirroring: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        guard lunarProActive else {
            throw IntentError.message("A Lunar Pro license is needed for this feature.")
        }

        let displays = screen.displays

        let oldAllowMirroring = displays.map(\.blackOutMirroringAllowed)
        displays.forEach {
            $0.blackOutMirroringAllowed = allowMirroring
        }

        defer {
            for (i, display) in displays.enumerated() {
                display.blackOutMirroringAllowed = oldAllowMirroring[i]
            }
        }

        return try controlScreen(screen: $screen, property: .blackout, value: state.inverted.rawValue)
    }
}

@available(iOS 16, macOS 13, *)
enum ScreenRotationDegrees: Int, AppEnum, CaseDisplayRepresentable, TypeDisplayRepresentable {
    case normal = 0
    case portraitToLeft = 90
    case upsideDown = 180
    case portraitToRight = 270

    static var caseDisplayRepresentations: [ScreenRotationDegrees: DisplayRepresentation] = [
        .normal: "No rotation (0°)",
        .portraitToLeft: "Portrait to left (90°)",
        .upsideDown: "Upside down (180°)",
        .portraitToRight: "Portrait to right (270°)",
    ]

    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Rotation Degrees") }
}

@available(iOS 16, macOS 13, *)
struct RotateScreenIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Rotate Screen"
    static var description = IntentDescription("Sets screen rotation/orientation to 0°/90°/180°/270°.", categoryName: "Arrangement")

    static var parameterSummary: some ParameterSummary { Summary("Rotate \(\.$screen) to \(\.$rotation)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery())
    var screen: Screen

    @Parameter(title: "Degrees")
    var rotation: ScreenRotationDegrees

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: .rotation, value: rotation.rawValue.s)
    }
}

@available(iOS 16, macOS 13, *)
enum AdaptiveModeKeyForIntent: Int, AppEnum {
    case location = 1
    case sync = -1
    case manual = 0
    case sensor = 2
    case clock = 3
    case auto = 99

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Adaptive Mode")
    }

    static var caseDisplayRepresentations: [AdaptiveModeKeyForIntent: DisplayRepresentation] {
        [
            .manual: "Manual Mode",
            .sync: "Sync Mode",
            .sensor: "Sensor Mode",
            .location: "Location Mode",
            .clock: "Clock Mode",
            .auto: "Auto (let Lunar choose the best mode)",
        ]
    }

    var description: String { AdaptiveModeKeyForIntent.caseDisplayRepresentations[self]!.title.key }

    var adaptiveModeKey: AdaptiveModeKey {
        AdaptiveModeKey(rawValue: rawValue)!
    }
}

@available(iOS 16, macOS 13, *)
struct ChangeAdaptiveModeIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Change Adaptive Mode"
    static var description = IntentDescription("Changes adaptive mode to Sync/Sensor/Location/Clock/Manual.", categoryName: "Global")

    static var parameterSummary: some ParameterSummary { Summary("Change Adaptive Mode to \(\.$mode)") }

    @Parameter(title: "Mode")
    var mode: AdaptiveModeKeyForIntent

    @MainActor
    func perform() async throws -> some IntentResult {
        guard mode == .manual || mode == .auto || lunarProActive else {
            throw IntentError.message("A Lunar Pro license is needed for \(mode.description).")
        }

        CachedDefaults[.adaptiveBrightnessMode] = mode.adaptiveModeKey
        if mode == .auto {
            CachedDefaults[.overrideAdaptiveMode] = false
        }
        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct ApplyPresetIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Apply Lunar Preset"
    static var description = IntentDescription("Applies a custom preset from the ones saved through the Lunar UI.", categoryName: "Global")

    static var parameterSummary: some ParameterSummary { Summary("Apply Preset \(\.$preset)") }

    @Parameter(title: "Preset", optionsProvider: PresetProvider())
    var preset: String

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        if let percent = preset.i8 ?? preset.replacingOccurrences(of: "%", with: "").i8 {
            displayController.setBrightnessPercent(value: percent, now: true)
            displayController.setContrastPercent(value: percent, now: true)
            return .result()
        }

        guard let preset = CachedDefaults[.presets].first(where: { $0.id == preset }) else {
            throw $preset.needsValueError()
        }
        preset.apply()
        return .result()
    }

    private struct PresetProvider: DynamicOptionsProvider {
        func results() async throws -> ItemCollection<String> {
            ItemCollection {
                ItemSection(title: "Custom", items: CachedDefaults[.presets].map(
                    { IntentItem($0.id, title: "\($0.id)") }
                ))
                ItemSection("Percentage") {
                    "0%"
                    "25%"
                    "50%"
                    "75%"
                    "100%"
                }
            }
        }
    }
}

@available(iOS 16, macOS 13, *)
struct PowerOffIntent: AppIntent {
    init() {}

    // swiftformat:disable all
    static var title: LocalizedStringResource = "Power off screen (in hardware)"
    static var description = IntentDescription("""
Powers off the screen using DDC. This is equivalent to pressing the screen's physical power button"

Note: a screen can't also be powered on using this method because a powered off screen is disconnected and doesn't accept DDC commands.
""", categoryName: "Power")

    // swiftformat:enable all

    static var parameterSummary: some ParameterSummary { Summary("Power off \(\.$screen)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.hasDDC }))
    var screen: Screen

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: .power, value: "off")
    }
}

@available(iOS 16, macOS 13, *)
struct ResetColorGainIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Reset Color Adjustments (in hardware)"
    static var description = IntentDescription("Resets the adjusted color gain values using DDC. This is equivalent to resetting the screen's colors from its OSD menu.", categoryName: "Colors")

    static var parameterSummary: some ParameterSummary { Summary("Reset color gain adjustments on \(\.$screen)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.hasDDC }))
    var screen: Screen

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        screen.displays.forEach {
            $0.resetColors()
        }

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct ResetColorGammaIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Reset Color Adjustments (in software)"
    static var description = IntentDescription("Resets the Gamma color adjustments for a specific screen. This is equivalent to resetting Gamma from the Lunar preferences.", categoryName: "Colors")

    static var parameterSummary: some ParameterSummary { Summary("Reset Gamma color adjustments on \(\.$screen)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.supportsGammaByDefault }))
    var screen: Screen

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        screen.displays.forEach {
            $0.resetDefaultGamma()
            $0.applyGamma = false
        }

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct ToggleGammaIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Toggle Color Adjustments (in software)"
    static var description = IntentDescription("Toggles on/off the Gamma color adjustments while keeping the red/green/blue values stored in settings.", categoryName: "Colors")

    static var parameterSummary: some ParameterSummary { Summary("Toggle Gamma color adjustments on \(\.$screen) to \(\.$state)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.supportsGammaByDefault }))
    var screen: Screen

    @Parameter(title: "State")
    var state: ScreenToggleState

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        screen.displays.forEach {
            $0.applyGamma = state == .toggle ? (!$0.applyGamma) : (state == .on)
        }

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct SetInputIntent: AppIntent {
    init() {}

    // swiftformat:disable all
    static var title: LocalizedStringResource = "Change Video Input Source"
    static var description = IntentDescription(
    """
Changes screen input to a specific value (HDMI/DP/USB-C).

Note: Not all inputs are supported by all monitors, and some monitors may use non-standard input values.
""", categoryName: "DDC")

    // swiftformat:enable all

    static var parameterSummary: some ParameterSummary { Summary("Change \(\.$screen) input to \(\.$input)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.hasDDC }))
    var screen: Screen

    @Parameter(title: "Input", optionsProvider: InputProvider())
    var input: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: .input, value: input.s)
    }

    private struct InputProvider: DynamicOptionsProvider {
        func results() async throws -> ItemCollection<Int> {
            ItemCollection {
                ItemSection(title: "Common", items: VideoInputSource.mostUsed.map(
                    { IntentItem($0.rawValue.i, title: "\($0.description)", image: .init(named: $0.image ?? "input", isTemplate: true)) }
                ))
                ItemSection(title: "Less used", items: VideoInputSource.leastUsed.map(
                    { IntentItem($0.rawValue.i, title: "\($0.description)", image: .init(named: $0.image ?? "input", isTemplate: true)) }
                ))
            }
        }
    }
}

@available(iOS 16, macOS 13, *)
struct WriteDDCIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "DDC Write Value to Screen"
    static var description = IntentDescription("Sends a DDC write command to a specific screen.", categoryName: "DDC")

    static var parameterSummary: some ParameterSummary { Summary("Write DDC \(\.$vcp) \(\.$value) to \(\.$screen)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.hasDDC }))
    var screen: Screen

    @Parameter(title: "VCP", optionsProvider: VCPProvider())
    var vcp: Int

    @Parameter(title: "Value")
    var value: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        guard let control = ControlID(rawValue: vcp.u8) else {
            throw $vcp.needsValueError()
        }

        screen.displays.filter(\.hasDDC).forEach { display in
            let _ = DDC.write(displayID: display.id, controlID: control, newValue: value.u16)
        }

        return .result()
    }

    private struct VCPProvider: DynamicOptionsProvider {
        func results() async throws -> ItemCollection<Int> {
            ItemCollection {
                ItemSection(title: "Common", items: ControlID.common.map { vcp in
                    IntentItem(vcp.rawValue.i, title: .init(stringLiteral: "\(vcp)"))
                })
                ItemSection(title: "Reset", items: ControlID.reset.map { vcp in
                    IntentItem(vcp.rawValue.i, title: .init(stringLiteral: "\(vcp)"))
                })
                ItemSection(title: "Other", items: Set(ControlID.allCases).subtracting(ControlID.common).subtracting(ControlID.reset).sorted(by: \.rawValue).map { vcp in
                    IntentItem(vcp.rawValue.i, title: .init(stringLiteral: "\(vcp)"))
                })
            }
        }
    }
}

@available(iOS 16, macOS 13, *)
struct ReadDDCIntent: AppIntent {
    init() {}

    // swiftformat:disable all
    static var title: LocalizedStringResource = "DDC Read Value from Screen"
    static var description = IntentDescription(
    """
Sends a DDC read command to a specific screen and returns the value read.

Note: DDC reads rarely work and can return wrong values.
""", categoryName: "DDC")

    // swiftformat:enable all

    static var parameterSummary: some ParameterSummary { Summary("Read DDC \(\.$vcp) from \(\.$screen)") }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.hasDDC }))
    var screen: Screen

    @Parameter(title: "VCP", optionsProvider: VCPProvider())
    var vcp: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        guard let control = ControlID(rawValue: vcp.u8) else {
            throw $vcp.needsValueError()
        }

        let result = screen.displays.filter(\.hasDDC).dict { display in
            (display.serial, DDC.read(displayID: display.id, controlID: control)?.currentValue)
        }

        return .result(value: (try? encoder.encode(result).s) ?? "")
    }

    private struct VCPProvider: DynamicOptionsProvider {
        func results() async throws -> ItemCollection<Int> {
            ItemCollection {
                ItemSection(title: "Common", items: ControlID.common.map { vcp in
                    IntentItem(vcp.rawValue.i, title: .init(stringLiteral: "\(vcp)"))
                })
                ItemSection(title: "Reset", items: ControlID.reset.map { vcp in
                    IntentItem(vcp.rawValue.i, title: .init(stringLiteral: "\(vcp)"))
                })
                ItemSection(title: "Other", items: Set(ControlID.allCases).subtracting(ControlID.common).subtracting(ControlID.reset).sorted(by: \.rawValue).map { vcp in
                    IntentItem(vcp.rawValue.i, title: .init(stringLiteral: "\(vcp)"))
                })
            }
        }
    }
}

@available(iOS 16, macOS 13, *)
struct ControlScreenValueFloatNumeric: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Control a floating point Screen Value"
    static var description = IntentDescription("Configure any screen property that supports a numeric value with a floating point.", categoryName: "Scripting")

    static var parameterSummary: some ParameterSummary { Summary("Set \(\.$property) of \(\.$screen) to \(\.$value)") }

    @Parameter(title: "Property", optionsProvider: DisplayFloatNumericPropertyQuery())
    var property: DisplayProperty

    @Parameter(title: "Screen", optionsProvider: ScreenQuery())
    var screen: Screen

    @Parameter(title: "Value", controlStyle: .slider, inclusiveRange: (0.0, 1.0))
    var value: Double

    @MainActor
    func perform() async throws -> some IntentResult {
        guard !Display.CodingKeys.needsLunarPro.contains(property.id) || lunarProActive else {
            throw IntentError.message("A Lunar Pro license is needed for controlling \"\(property.name)\".")
        }
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: property.id, value: value.str(decimals: 3))
    }
}

@available(iOS 16, macOS 13, *)
struct ControlScreenValueNumeric: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Control an integer Screen Value"
    static var description = IntentDescription("Configure any screen property that supports an integer numeric value.", categoryName: "Scripting")

    static var parameterSummary: some ParameterSummary { Summary("Set \(\.$property) of \(\.$screen) to \(\.$value)") }

    @Parameter(title: "Property", optionsProvider: DisplayNumericPropertyQuery())
    var property: DisplayProperty

    @Parameter(title: "Screen", optionsProvider: ScreenQuery())
    var screen: Screen

    @Parameter(title: "Value", controlStyle: .field, inclusiveRange: (0, 65535))
    var value: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        guard !Display.CodingKeys.needsLunarPro.contains(property.id) || lunarProActive else {
            throw IntentError.message("A Lunar Pro license is needed for controlling \"\(property.name)\".")
        }
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: property.id, value: value.s)
    }
}

@available(iOS 16, macOS 13, *)
struct ControlScreenValueBool: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Control a boolean Screen Value"
    static var description = IntentDescription("Configure any screen property that supports a boolean value.", categoryName: "Scripting")

    static var parameterSummary: some ParameterSummary { Summary("Set \(\.$property) of \(\.$screen) to \(\.$state)") }

    @Parameter(title: "Property", optionsProvider: DisplayBoolPropertyQuery())
    var property: DisplayProperty

    @Parameter(title: "Screen", optionsProvider: ScreenQuery())
    var screen: Screen

    @Parameter(title: "State")
    var state: ScreenToggleState

    @MainActor
    func perform() async throws -> some IntentResult {
        guard !Display.CodingKeys.needsLunarPro.contains(property.id) || lunarProActive else {
            throw IntentError.message("A Lunar Pro license is needed for controlling \"\(property.name)\".")
        }
        try checkShortcutsLimit()
        return try controlScreen(screen: $screen, property: property.id, value: state.rawValue)
    }
}

@available(iOS 16, macOS 13, *)
struct AdjustSoftwareColorsIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Adjust Colors of a Screen (in software)"
    static var description =
        IntentDescription(
            "Adjusts screen colors by changing the Gamma curve for Red, Green and Blue. The adjustments stick as long as Lunar is running (not persistent), but they are re-applied when Lunar is relaunched.",
            categoryName: "Colors"
        )

    static var parameterSummary: some ParameterSummary {
        Summary("Adjust Gamma to（\(\.$red) Red｜\(\.$green) Green｜\(\.$blue) Blue）for \(\.$screen)")
    }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.supportsGammaByDefault }))
    var screen: Screen

    // swiftformat:disable all
    @Parameter(
        title: "Red",
        description: """
The red component of the Gamma curve
    at 0.5: no adjustment
    below 0.5: decrease red
    above 0.5: add more red
""",
        default: 0.5,
        controlStyle: .field,
        inclusiveRange: (0.0, 1.0)
    )
    var red: Double

    @Parameter(
        title: "Green",
        description: """
The green component of the Gamma curve
    at 0.5: no adjustment
    below 0.5: decrease green
    above 0.5: add more green
""",
        default: 0.5,
        controlStyle: .field,
        inclusiveRange: (0.0, 1.0)
    )
    var green: Double

    @Parameter(
        title: "Blue",
        description: """
The blue component of the Gamma curve
    at 0.5: no adjustment
    below 0.5: decrease blue
    above 0.5: add more blue
""",
        default: 0.5,
        controlStyle: .field,
        inclusiveRange: (0.0, 1.0)
    )
    var blue: Double


    // swiftformat:enable all

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        screen.displays.forEach { display in
            display.applyGamma = true
            display.red = red
            display.green = green
            display.blue = blue
        }

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct AdjustHardwareColorsIntent: AppIntent {
    init() {}

    // swiftformat:disable all
    static var title: LocalizedStringResource = "Adjust Colors of a Screen (in hardware)"
    static var description =
        IntentDescription(
            """
Adjusts screen colors by changing the Color Gain values for Red, Green and Blue using DDC. The adjustments are stored in the monitor memory and should persist over different ports.

On most monitors, 50 is the default value, but this can vary and is not easily detectable. Use the "Reset Color Adjustments (in hardware)" action if you need to reset these values to default.

Note: not all monitors support color gain control through DDC and value effect can vary a lot.
""",
            categoryName: "Colors"
        )

    // swiftformat:enable all
    static var parameterSummary: some ParameterSummary {
        Summary("Adjust color gain to（\(\.$red) Red｜\(\.$green) Green｜\(\.$blue) Blue）for \(\.$screen)")
    }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.hasDDC }))
    var screen: Screen

    @Parameter(
        title: "Red",
        description: "The red color gain value.",
        default: 50,
        controlStyle: .field,
        inclusiveRange: (0, 255)
    )
    var red: Int

    @Parameter(
        title: "Green",
        description: "The green color gain value.",
        default: 50,
        controlStyle: .field,
        inclusiveRange: (0, 255)
    )
    var green: Int

    @Parameter(
        title: "Blue",
        description: "The blue color gain value.",
        default: 50,
        controlStyle: .field,
        inclusiveRange: (0, 255)
    )
    var blue: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        screen.displays.forEach { display in
            display.redGain = red.ns
            display.greenGain = green.ns
            display.blueGain = blue.ns
        }

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct ReadHardwareColorsIntent: AppIntent {
    init() {}

    // swiftformat:disable all
    static var title: LocalizedStringResource = "Read Color Gain Values (in hardware)"
    static var description =
        IntentDescription(
            """
Tries to read the Red, Green and Blue color gain values from the monitor memory using DDC.

Note: very few monitors implement this functionality
""",
            categoryName: "Colors"
        )

    // swiftformat:enable all
    static var parameterSummary: some ParameterSummary {
        Summary("Read color gain values from \(\.$screen)")
    }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.hasDDC }, single: true))
    var screen: Screen

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        guard let display = screen.displays.first else {
            throw $screen.needsValueError()
        }

        let readWorked = await display.refreshColors()

        guard readWorked else {
            throw IntentError.message("DDC read failed")
        }

        return .result(value: ScreenColorGain(red: display.redGain.intValue, green: display.greenGain.intValue, blue: display.blueGain.intValue))
    }
}

@available(iOS 16, macOS 13, *)
struct ReadSoftwareColorsIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Read Color Gamma Tables (in software)"
    static var description =
        IntentDescription(
            "Reads the Red, Green and Blue gamma color values from the system.",
            categoryName: "Colors"
        )

    static var parameterSummary: some ParameterSummary {
        Summary("Read color Gamma values from \(\.$screen)")
    }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(filter: { $0.supportsGammaByDefault }, single: true))
    var screen: Screen

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        guard let display = screen.displays.first else {
            throw $screen.needsValueError()
        }

        return .result(value: ScreenGammaTable(red: display.red, green: display.green, blue: display.blue))
    }
}

@available(iOS 16, macOS 13, *)
struct MirrorSetIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Mirror Screens"
    static var description =
        IntentDescription(
            "Set up mirror sets of any combination of screens.",
            categoryName: "Arrangement"
        )

    static var parameterSummary: some ParameterSummary {
        Summary("Mirror \(\.$mirrorMaster) onto \(\.$mirrors)")
    }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(single: true))
    var mirrorMaster: Screen

    @Parameter(title: "Screens", optionsProvider: ScreenQuery())
    var mirrors: [Screen]

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        guard let mirrorMaster = mirrorMaster.displays.first else {
            throw $mirrorMaster.needsValueError()
        }
        mirrorMaster.refreshPanel()

        guard let panel = mirrorMaster.panel, let mgr = DisplayController.panelManager else {
            throw IntentError.message("System error when setting up mirror set.")
        }

        mirrorMaster.resolutionBlackoutResetterTask = nil
        let others: [Display] = Array(mirrors.map(\.displays).joined().uniqued())
        let mode = panel.currentMode
        Display.reconfigure(panel: panel) { panel in
            mgr.createMirrorSet([panel] + others.without(mirrorMaster).compactMap(\.panel))
        }

        guard let mode, let panel = DisplayController.panel(with: mirrorMaster.id) else {
            return .result()
        }

        mirrorMaster.resolutionBlackoutResetterTask = Repeater(
            every: 1, times: 5, name: "master-resolution-blackout-on",
            onFinish: { mirrorMaster.refreshPanel() }
        ) {
            Display.reconfigure(panel: panel) { panel in
                panel.setModeNumber(mode.modeNumber)
            }
        }

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct StopMirroringIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Stop Mirroring"
    static var description =
        IntentDescription(
            "Disable mirroring for specific screens.",
            categoryName: "Arrangement"
        )

    static var parameterSummary: some ParameterSummary {
        Summary("Stop mirroring for \(\.$mirrorMaster).")
    }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(single: true, additionalScreens: [
        Screen(id: UInt32.max - 40, name: "All screens", serial: "allScreens", isDynamicFilter: true),
    ]))
    var mirrorMaster: Screen

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        if mirrorMaster.id == UInt32.max - 40 {
            Display.reconfigure { mgr in
                mgr.stopAllMirroring()
            }

            return .result()
        }

        guard let mirrorMaster = mirrorMaster.displays.first else {
            throw $mirrorMaster.needsValueError()
        }
        mirrorMaster.refreshPanel()

        guard let panel = mirrorMaster.panel else {
            throw IntentError.message("System error when stopping mirroring.")
        }

        mirrorMaster.resolutionBlackoutResetterTask = nil
        let mode = panel.currentMode
        Display.reconfigure { mgr in
            if panel.isMirrorMaster, let mirrors = mgr.mirrorSet(forDisplay: panel) as? [MPDisplay] {
                for mirror in mirrors {
                    mgr.stopMirroring(forDisplay: mirror)
                }
            } else {
                mgr.stopMirroring(forDisplay: panel)
            }
        }

        guard let mode, let panel = DisplayController.panel(with: mirrorMaster.id) else {
            return .result()
        }

        mirrorMaster.resolutionBlackoutResetterTask = Repeater(
            every: 1, times: 5, name: "master-resolution-blackout-on",
            onFinish: { mirrorMaster.refreshPanel() }
        ) {
            Display.reconfigure(panel: panel) { panel in
                panel.setModeNumber(mode.modeNumber)
            }
        }

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct SetPanelModeIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Change Screen Resolution"
    static var description =
        IntentDescription(
            "Change the current resolution and/or frame rate of a specific screen.",
            categoryName: "Global"
        )

    static var parameterSummary: some ParameterSummary {
        Summary("Change resolution to \(\.$mode)")
    }

    @Parameter(title: "Screen Mode")
    var mode: PanelMode

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()

        mode.screen.display?.reconfigure { panel in
            panel.setModeNumber((mode.id & ((1 << 32) - 1)).i32)
        }

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct SetPanelPresetIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Change Screen Preset"
    static var description =
        IntentDescription(
            "Change the current preset of a specific screen.",
            categoryName: "Global"
        )

    static var parameterSummary: some ParameterSummary {
        Summary("Change preset to \(\.$preset)")
    }

    @Parameter(title: "Screen Preset")
    var preset: PanelPreset

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()

        let presetIndex = (preset.id & ((1 << 32) - 1)).i64
        guard let display = preset.screen.display,
              let preset = display.panelPresets.first(where: { $0.presetIndex == presetIndex })
        else { return .result() }
        display.reconfigure { panel in
            panel.setActivePreset(preset)
        }
        return .result()
    }
}

struct SortablePanelMode: Comparable, Equatable, Hashable {
    let isHiDPI: Bool
    let refreshRate: Int32

    static func < (lhs: SortablePanelMode, rhs: SortablePanelMode) -> Bool {
        lhs.refreshRate < rhs.refreshRate
    }
}

@available(iOS 16, macOS 13, *)
extension MPDisplayPreset {
    var panelPreset: PanelPreset? {
        guard let screen = displayController.activeDisplays[displayID]?.screen else { return nil }

        return PanelPreset(screen: screen, id: (screen.id << 32) + presetIndex.i, title: presetName, subtitle: presetDescription)
    }

    static func groupName(_ group: Int64) -> String {
        switch group {
        case 1:
            return "Default"
        case 2:
            return "Reference"
        default:
            return "Custom"
        }
    }

    var groupName: String { Self.groupName(presetGroup) }
}

@available(iOS 16, macOS 13, *)
struct PanelPreset: AppEntity {
    struct PanelPresetQuery: EntityQuery {
        func entities(for identifiers: [Int]) async throws -> [PanelPreset] {
            await DisplayController.panelManager?.withLock { _ in
                identifiers.compactMap { id -> PanelPreset? in
                    let screenID = CGDirectDisplayID(id >> 32)
                    guard let display = displayController.activeDisplays[screenID],
                          let panel = display.panel
                    else {
                        return nil
                    }

                    let index = id & ((1 << 32) - 1)
                    guard let preset = (panel.presets as? [MPDisplayPreset])?.first(where: { $0.presetIndex == index }) else {
                        return nil
                    }

                    return preset.panelPreset
                }
            } ?? []
        }
        func suggestedEntities() async throws -> ItemCollection<PanelPreset> {
            try await results()
        }
        func results() async throws -> ItemCollection<PanelPreset> {
            await DisplayController.panelManager?.withLock { _ in
                let sections: [(Display, Int64)] = Array(
                    displayController.activeDisplayList
                        .filter { $0.panel?.hasPresets ?? false }
                        .map { d in
                            let modes = Set(d.panelPresets.filter(\.isValid).map(\.presetGroup)).sorted()
                            return modes.map { p in (d, p) }
                        }.joined()
                )

                return ItemCollection(
                    sections: sections
                        .map { display, group in
                            ItemSection(
                                title: "\(display.name) \(MPDisplayPreset.groupName(group)) presets",
                                items: display.panelPresets
                                    .filter { $0.isValid && $0.presetGroup == group }
                                    .compactMap(\.panelPreset)
                                    .map { preset in
                                        IntentItem(
                                            preset,
                                            title: "\(preset.title)", subtitle: "\(preset.subtitle)"
                                        )
                                    }
                            )
                        }
                )
            } ?? ItemCollection(items: [])
        }
    }
    typealias DefaultQuery = PanelPresetQuery

    static var defaultQuery = PanelPresetQuery()

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Screen Preset")
    }

    let screen: Screen
    let id: Int
    let title: String
    let subtitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title) on \(screen.name)", subtitle: "\(subtitle.wordWrap(columns: 60))\n"
        )
    }
}

@available(iOS 16, macOS 13, *)
extension MPDisplayMgr {
    func withLock<T>(refreshBefore: Bool = true, _ action: (MPDisplayMgr) -> T) async -> T? {
        while !tryLockAccess() {
            do {
                try await Task.sleep(nanoseconds: 10)
            } catch {
                return nil
            }
        }
        let result = action(self)
        unlockAccess()

        return result
    }
}

@available(iOS 16, macOS 13, *)
struct PanelMode: AppEntity {
    struct PanelModeQuery: EntityQuery {
        func entities(for identifiers: [Int]) async throws -> [PanelMode] {
            await DisplayController.panelManager?.withLock { _ in
                identifiers.compactMap { id -> PanelMode? in
                    let screenID = CGDirectDisplayID(id >> 32)
                    guard let display = displayController.activeDisplays[screenID],
                          let panel = display.panel
                    else {
                        return nil
                    }

                    let modeID = id & ((1 << 32) - 1)
                    guard let mode = panel.mode(withNumber: modeID.i32) as? MPDisplayMode else {
                        return nil
                    }

                    return mode.panelMode
                }
            } ?? []
        }
        func suggestedEntities() async throws -> ItemCollection<PanelMode> {
            try await results()
        }
        func results() async throws -> ItemCollection<PanelMode> {
            await DisplayController.panelManager?.withLock { _ in
                let sections: [(Display, SortablePanelMode)] = Array(displayController.activeDisplayList.map { d in
                    let modes = Set(d.panelModes.map { SortablePanelMode(isHiDPI: $0.isHiDPI, refreshRate: $0.refreshRate) }).sorted().reversed()
                    return modes.filter(\.isHiDPI).map { p in (d, p) } + modes.filter(!\.isHiDPI).map { p in (d, p) }
                }.joined())

                return ItemCollection(sections: sections.map { display, sortableMode in
                    ItemSection(
                        title: "\(display.name) \(sortableMode.isHiDPI ? "HiDPI" : "lowDPI") modes @ \(sortableMode.refreshRate)Hz",
                        items: display.panelModes
                            .filter { $0.isHiDPI == sortableMode.isHiDPI && $0.refreshRate == sortableMode.refreshRate }
                            .compactMap(\.panelMode)
                            .map { mode in
                                IntentItem(
                                    mode,
                                    title: "\(mode.title)", subtitle: "\(mode.subtitle)",
                                    image: DisplayRepresentation.Image(systemName: mode.image)
                                )
                            }
                    )
                })
            } ?? ItemCollection(items: [])
        }
    }
    typealias DefaultQuery = PanelModeQuery

    static var defaultQuery = PanelModeQuery()

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Screen Mode")
    }

    let screen: Screen
    let id: Int
    let title: String
    let subtitle: String
    let image: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title) on \(screen.name)", subtitle: "\(subtitle)",
            image: DisplayRepresentation.Image(systemName: image)
        )
    }
}

@available(iOS 16, macOS 13, *)
struct SwapMonitorsIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Swap Screen Positions"
    static var description =
        IntentDescription(
            "Swap 2 screens between each other. Useful for when the system confuses the screens and positions them wrongly.",
            categoryName: "Arrangement"
        )

    static var parameterSummary: some ParameterSummary {
        Summary("Swap screen \(\.$screen1) with \(\.$screen2)") {
            \.$swapOrientations
        }
    }

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screen1: Screen

    @Parameter(title: "Screen", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screen2: Screen

    @Parameter(title: "Swap orientations", default: true)
    var swapOrientations: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        guard let display1 = screen1.display, let display2 = screen2.display, display1 != display2 else {
            throw IntentError.message("Two different screens are needed to perform swapping.")
        }
        displayController.swap(firstDisplay: display1.id, secondDisplay: display2.id, rotation: swapOrientations)
        notify(identifier: "fyi.lunar.Lunar.Shortcuts", title: "Swapped monitors", body: "\"\(display1.name)\" swapped positions with \"\(display2.name)\"")
        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct VerticalMonitorLayoutIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Arrange 2 Screens Vertically ■̳̲"
    static var description =
        IntentDescription(
            "Arrange screens in a vertical layout, one above the other. Helpful for a MacBook with one external monitor.",
            categoryName: "Arrangement"
        )

    static var parameterSummary: some ParameterSummary {
        Summary("Arrange \(\.$screenTop) at the top and \(\.$screenBottom) at the bottom")
    }

    @Parameter(title: "Top Screen", description: "The screen that will be placed at the top.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenTop: Screen

    @Parameter(title: "Bottom Screen", description: "The screen that will be placed at the bottom.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenBottom: Screen

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        guard let display1 = screenTop.display, let display2 = screenBottom.display, display1 != display2 else {
            throw IntentError.message("Two different screens are needed to perform arrangement.")
        }

        Display.configure { config in
            let topScreenBounds = CGDisplayBounds(display1.id)
            let bottomScreenBounds = CGDisplayBounds(display2.id)

            let topScreenX = bottomScreenBounds.midX - topScreenBounds.width / 2
            let topScreenY = bottomScreenBounds.minY - topScreenBounds.height

            CGConfigureDisplayOrigin(config, display1.id, Int32(topScreenX.rounded()), Int32(topScreenY.rounded()))
            return true
        }

        notify(identifier: "fyi.lunar.Lunar.Shortcuts", title: "Arranged monitors", body: "\"\(display1.name)\" was positioned above \"\(display2.name)\"")

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct HorizontalMonitorLayoutIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Arrange 2 Screens Horizontally ⫍⃮݄⫎⃯"
    static var description =
        IntentDescription(
            "Arrange screens in a horizontal layout, one beside the other. Helpful for setups with exactly two external monitors.",
            categoryName: "Arrangement"
        )

    static var parameterSummary: some ParameterSummary {
        Summary("Arrange \(\.$screenLeft) to the left and \(\.$screenRight) to the right")
    }

    @Parameter(title: "Left Screen", description: "The screen that will be placed at the left.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenLeft: Screen

    @Parameter(title: "Right Screen", description: "The screen that will be placed at the right.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenRight: Screen

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        guard let display1 = screenLeft.display, let display2 = screenRight.display, display1 != display2 else {
            throw IntentError.message("Two different screens are needed to perform arrangement.")
        }

        Display.configure { config in
            let leftScreenBounds = CGDisplayBounds(display1.id)
            let rightScreenBounds = CGDisplayBounds(display2.id)

            let leftScreenX = rightScreenBounds.minX - leftScreenBounds.width
            let leftScreenY = rightScreenBounds.midY - leftScreenBounds.height / 2

            CGConfigureDisplayOrigin(config, display1.id, Int32(leftScreenX.rounded()), Int32(leftScreenY.rounded()))
            return true
        }

        notify(identifier: "fyi.lunar.Lunar.Shortcuts", title: "Arranged monitors", body: "\"\(display1.name)\" was positioned to the left of \"\(display2.name)\"")

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct ThreeAboveOneMonitorLayoutIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Arrange 4 Screens in a 3-above-1 configuration ⫍⃮■̳̻⫎⃯"
    static var description =
        IntentDescription(
            "Arrange 4 screens with 3 in a horizontal layout [left|middle|right] and one in the middle below the other three. Helpful for a MacBook with three external monitors.",
            categoryName: "Arrangement"
        )

    static var parameterSummary: some ParameterSummary {
        Summary("Arrange \(\.$screenLeft) to the left, \(\.$screenMiddle) in the middle, \(\.$screenRight) to the right and \(\.$screenBottom) at the bottom")
    }

    @Parameter(title: "Left Screen", description: "The screen that will be placed at the left.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenLeft: Screen

    @Parameter(title: "Middle Screen", description: "The screen that will be placed in the middle.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenMiddle: Screen

    @Parameter(title: "Right Screen", description: "The screen that will be placed at the right.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenRight: Screen

    @Parameter(title: "Bottom Screen", description: "The screen that will be placed at the bottom.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenBottom: Screen

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        guard let display1 = screenLeft.display, let display2 = screenMiddle.display,
              let display3 = screenRight.display, let display4 = screenBottom.display,
              Set([display1.id, display2.id, display3.id, display4.id]).count == 4
        else {
            throw IntentError.message("Four different screens are needed to perform arrangement.")
        }

        Display.configure { config in
            let leftScreenBounds = CGDisplayBounds(display1.id)
            let middleScreenBounds = CGDisplayBounds(display2.id)
            let rightScreenBounds = CGDisplayBounds(display3.id)
            let bottomScreenBounds = CGDisplayBounds(display4.id)

            let middleScreenX = bottomScreenBounds.midX - middleScreenBounds.width / 2
            let middleScreenY = bottomScreenBounds.minY - middleScreenBounds.height

            CGConfigureDisplayOrigin(config, display2.id, Int32(middleScreenX.rounded()), Int32(middleScreenY.rounded()))

            let leftScreenX = middleScreenX - leftScreenBounds.width
            let leftScreenY = bottomScreenBounds.minY - leftScreenBounds.height

            CGConfigureDisplayOrigin(config, display1.id, Int32(leftScreenX.rounded()), Int32(leftScreenY.rounded()))

            let rightScreenX = middleScreenX + middleScreenBounds.width + rightScreenBounds.width
            let rightScreenY = bottomScreenBounds.minY - rightScreenBounds.height

            CGConfigureDisplayOrigin(config, display3.id, Int32(rightScreenX.rounded()), Int32(rightScreenY.rounded()))
            return true
        }

        notify(
            identifier: "fyi.lunar.Lunar.Shortcuts",
            title: "Arranged monitors",
            body: "A 3-above-1 screen layout was arranged with \(display4.name) at the bottom and, at the top, from left to right: \"\(display1.name)\" -> \"\(display2.name)\" -> \"\(display3.name)\""
        )

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct TwoAboveOneMonitorLayoutIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Arrange 3 Screens in a 2-above-1 configuration ⫍‗⫎"
    static var description =
        IntentDescription(
            "Arrange 3 screens with 2 in a horizontal layout [left|right] and one in the middle below the other two. Helpful for a MacBook with two external monitors.",
            categoryName: "Arrangement"
        )

    static var parameterSummary: some ParameterSummary {
        Summary("Arrange \(\.$screenLeft) to the left, \(\.$screenMiddle) at the bottom and \(\.$screenRight) to the right")
    }

    @Parameter(title: "Left Screen", description: "The screen that will be placed at the left.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenLeft: Screen

    @Parameter(title: "Middle Screen", description: "The screen that will be placed in the middle at the bottom.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenMiddle: Screen

    @Parameter(title: "Right Screen", description: "The screen that will be placed at the right.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenRight: Screen

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        guard let display1 = screenLeft.display, let display2 = screenMiddle.display, let display3 = screenRight.display,
              Set([display1.id, display2.id, display3.id]).count == 3
        else {
            throw IntentError.message("Three different screens are needed to perform arrangement.")
        }

        Display.configure { config in
            let leftScreenBounds = CGDisplayBounds(display1.id)
            let middleScreenBounds = CGDisplayBounds(display2.id)
            let rightScreenBounds = CGDisplayBounds(display3.id)

            let leftScreenX = middleScreenBounds.minX - (leftScreenBounds.width - middleScreenBounds.width / 2)
            let leftScreenY = middleScreenBounds.minY - leftScreenBounds.height

            CGConfigureDisplayOrigin(config, display1.id, Int32(leftScreenX.rounded()), Int32(leftScreenY.rounded()))

            let rightScreenX = middleScreenBounds.midX
            let rightScreenY = middleScreenBounds.minY - rightScreenBounds.height

            CGConfigureDisplayOrigin(config, display3.id, Int32(rightScreenX.rounded()), Int32(rightScreenY.rounded()))
            return true
        }

        notify(
            identifier: "fyi.lunar.Lunar.Shortcuts",
            title: "Arranged monitors",
            body: "A 2-above-1 screen layout was arranged with \(display2.name) at the bottom and, at the top, from left to right: \"\(display1.name)\" -> \"\(display3.name)\""
        )

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct HorizontalMonitorThreeLayoutIntent: AppIntent {
    init() {}

    static var title: LocalizedStringResource = "Arrange 3 Screens Horizontally ⫍⃮▬̲⫎⃯"
    static var description =
        IntentDescription(
            "Arrange 3 screens in a horizontal layout, one on the left, one in the middle and one to the right. Helpful for setups with exactly three external monitors.",
            categoryName: "Arrangement"
        )

    static var parameterSummary: some ParameterSummary {
        Summary("Arrange \(\.$screenLeft) to the left, \(\.$screenMiddle) in the middle and \(\.$screenRight) to the right")
    }

    @Parameter(title: "Left Screen", description: "The screen that will be placed at the left.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenLeft: Screen

    @Parameter(title: "Middle Screen", description: "The screen that will be placed in the middle.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenMiddle: Screen

    @Parameter(title: "Right Screen", description: "The screen that will be placed at the right.", optionsProvider: ScreenQuery(single: true, noDefault: true))
    var screenRight: Screen

    @MainActor
    func perform() async throws -> some IntentResult {
        try checkShortcutsLimit()
        guard let display1 = screenLeft.display, let display2 = screenMiddle.display, let display3 = screenRight.display,
              Set([display1.id, display2.id, display3.id]).count == 3
        else {
            throw IntentError.message("Three different screens are needed to perform arrangement.")
        }

        Display.configure { config in
            let leftScreenBounds = CGDisplayBounds(display1.id)
            let middleScreenBounds = CGDisplayBounds(display2.id)
            let rightScreenBounds = CGDisplayBounds(display3.id)

            let leftScreenX = middleScreenBounds.minX - leftScreenBounds.width
            let leftScreenY = middleScreenBounds.midY - leftScreenBounds.height / 2

            CGConfigureDisplayOrigin(config, display1.id, Int32(leftScreenX.rounded()), Int32(leftScreenY.rounded()))

            let rightScreenX = middleScreenBounds.maxX + rightScreenBounds.width
            let rightScreenY = middleScreenBounds.midY - rightScreenBounds.height / 2

            CGConfigureDisplayOrigin(config, display3.id, Int32(rightScreenX.rounded()), Int32(rightScreenY.rounded()))
            return true
        }

        notify(
            identifier: "fyi.lunar.Lunar.Shortcuts",
            title: "Arranged monitors",
            body: "A horizontal screen layout was arranged in the following order, from left to right: \"\(display1.name)\" -> \"\(display2.name)\" -> \"\(display3.name)\""
        )

        return .result()
    }
}

@available(iOS 16, macOS 13, *)
struct ScreenColorGain: Equatable, Hashable, AppEntity {
    init(red: Int, green: Int, blue: Int) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    typealias DefaultQuery = ColorGainQuery

    struct ColorGainQuery: EntityQuery {
        func entities(for identifiers: [Int]) async throws -> [ScreenColorGain] {
            []
        }
    }

    static var defaultQuery = ColorGainQuery()

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Color Gain", numericFormat: "\(placeholder: .int) Color Gain tables")
    }

    @Property(title: "Red")
    var red: Int
    @Property(title: "Green")
    var green: Int
    @Property(title: "Blue")
    var blue: Int

    var id: Int { red * 100 + green * 10 + blue }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "[red:\(red) green:\(green) blue:\(blue)]")
    }

    static func == (lhs: ScreenColorGain, rhs: ScreenColorGain) -> Bool {
        lhs.red == rhs.red &&
            lhs.green == rhs.green &&
            lhs.blue == rhs.blue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(red)
        hasher.combine(green)
        hasher.combine(blue)
    }
}

@available(iOS 16, macOS 13, *)
struct ScreenGammaTable: Equatable, Hashable, AppEntity {
    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    typealias DefaultQuery = GammaTableQuery

    struct GammaTableQuery: EntityQuery {
        func entities(for identifiers: [Float]) async throws -> [ScreenGammaTable] {
            []
        }
    }

    static var defaultQuery = GammaTableQuery()

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Gamma Table", numericFormat: "\(placeholder: .int) Gamma tables")
    }

    @Property(title: "Red")
    var red: Double
    @Property(title: "Green")
    var green: Double
    @Property(title: "Blue")
    var blue: Double

    var id: Float { (red * 100 + green * 10 + blue).f }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "[red:\(red) green:\(green) blue:\(blue)]")
    }

    static func == (lhs: ScreenGammaTable, rhs: ScreenGammaTable) -> Bool {
        lhs.red == rhs.red &&
            lhs.green == rhs.green &&
            lhs.blue == rhs.blue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(red)
        hasher.combine(green)
        hasher.combine(blue)
    }
}

// MARK: - Display.CodingKeys + EntityIdentifierConvertible

@available(iOS 16, macOS 13, *)
extension Display.CodingKeys: EntityIdentifierConvertible {
    var entityIdentifierString: String {
        rawValue
    }

    static func entityIdentifier(for entityIdentifierString: String) -> Display.CodingKeys? {
        .init(rawValue: entityIdentifierString)
    }
}

// MARK: - DisplayNumericPropertyQuery

@available(iOS 16, macOS 13, *)
struct DisplayFloatNumericPropertyQuery: EntityQuery {
    typealias Entity = DisplayProperty

    func suggestedEntities() async throws -> ItemCollection<DisplayProperty> {
        ItemCollection {
            ItemSection(
                title: "Common",
                items: DisplayProperty.commonFloat.map { .init($0, title: "\($0.name)") }
            )
        }
    }

    func defaultResult() async -> Entity? {
        DisplayProperty.commonFloat.first
    }

    func entities(for identifiers: [Display.CodingKeys]) async throws -> [DisplayProperty] {
        identifiers.compactMap {
            DisplayProperty.allByID[$0]
        }
    }

    func results() async throws -> ItemCollection<DisplayProperty> {
        ItemCollection {
            ItemSection(
                title: "Common",
                items: DisplayProperty.commonFloat.map { .init($0, title: "\($0.name)") }
            )
        }
    }
}

@available(iOS 16, macOS 13, *)
struct DisplayNumericPropertyQuery: EntityQuery {
    typealias Entity = DisplayProperty

    func suggestedEntities() async throws -> ItemCollection<DisplayProperty> {
        ItemCollection {
            ItemSection(
                title: "Common",
                items: DisplayProperty.commonNumeric.map { .init($0, title: "\($0.name)") }
            )
        }
    }

    func defaultResult() async -> Entity? {
        DisplayProperty.commonNumeric.first
    }

    func entities(for identifiers: [Display.CodingKeys]) async throws -> [DisplayProperty] {
        identifiers.compactMap {
            DisplayProperty.allByID[$0]
        }
    }

    func results() async throws -> ItemCollection<DisplayProperty> {
        ItemCollection {
            ItemSection(
                title: "Common",
                items: DisplayProperty.commonNumeric.map { .init($0, title: "\($0.name)") }
            )
            ItemSection(
                title: "Less common",
                items: DisplayProperty.lessCommonNumeric.map { .init($0, title: "\($0.name)") }
            )
            ItemSection(
                title: "Settings",
                items: DisplayProperty.settingsNumeric.map { .init($0, title: "\($0.name)") }
            )
            ItemSection(
                title: "DDC dettings",
                items: DisplayProperty.ddcSettingsNumeric.map { .init($0, title: "\($0.name)") }
            )
        }
    }
}

// MARK: - DisplayBoolPropertyQuery

@available(iOS 16, macOS 13, *)
struct DisplayBoolPropertyQuery: EntityQuery {
    typealias Entity = DisplayProperty

    func suggestedEntities() async throws -> ItemCollection<DisplayProperty> {
        try await results()
    }

    func defaultResult() async -> Entity? {
        DisplayProperty.commonBool.first
    }

    func entities(for identifiers: [Display.CodingKeys]) async throws -> [DisplayProperty] {
        identifiers.compactMap {
            DisplayProperty.allByID[$0]
        }
    }

    func results() async throws -> ItemCollection<DisplayProperty> {
        ItemCollection {
            ItemSection(
                title: "Common",
                items: DisplayProperty.commonBool.map { IntentItem($0, title: "\($0.name)") }
            )
            ItemSection(
                title: "Less common",
                items: DisplayProperty.lessCommonBool.map { IntentItem($0, title: "\($0.name)") }
            )
            ItemSection(
                title: "Settings",
                items: DisplayProperty.settingsBool.map { IntentItem($0, title: "\($0.name)") }
            )
        }
    }
}

// MARK: - DisplayProperty

@available(iOS 16, macOS 13, *)
struct DisplayProperty: Equatable, Hashable, AppEntity, CustomStringConvertible {
    static var defaultQuery = DisplayFloatNumericPropertyQuery()
    static let commonNumeric: [DisplayProperty] = [
        DisplayProperty(id: .brightness, name: "Brightness"),
        DisplayProperty(id: .contrast, name: "Contrast"),
        DisplayProperty(id: .volume, name: "Volume"),
        DisplayProperty(id: .input, name: "Input"),
    ]
    static let lessCommonNumeric: [DisplayProperty] = [
        DisplayProperty(id: .redGain, name: "Red Color Gain"),
        DisplayProperty(id: .greenGain, name: "Green Color Gain"),
        DisplayProperty(id: .blueGain, name: "Blue Color Gain"),
        DisplayProperty(id: .cornerRadius, name: "Rounded Corners Radius"),
    ]
    static let settingsNumeric: [DisplayProperty] = [
        DisplayProperty(id: .minBrightness, name: "Minimum Brightness"),
        DisplayProperty(id: .maxBrightness, name: "Maximum Brightness"),
        DisplayProperty(id: .minContrast, name: "Minimum Contrast"),
        DisplayProperty(id: .maxContrast, name: "Maximum Contrast"),
        DisplayProperty(id: .faceLightBrightness, name: "Facelight Brightness"),
        DisplayProperty(id: .faceLightContrast, name: "Facelight Contrast"),
    ]
    static let ddcSettingsNumeric: [DisplayProperty] = [
        DisplayProperty(id: .minDDCBrightness, name: "Minimum DDC Value supported for Brightness"),
        DisplayProperty(id: .maxDDCBrightness, name: "Maximum DDC Value supported for Brightness"),
        DisplayProperty(id: .minDDCContrast, name: "Minimum DDC Value supported for Contrast"),
        DisplayProperty(id: .maxDDCContrast, name: "Maximum DDC Value supported for Contrast"),
        DisplayProperty(id: .minDDCVolume, name: "Minimum DDC Value supported for Volume"),
        DisplayProperty(id: .maxDDCVolume, name: "Maximum DDC Value supported for Volume"),
    ]
    static let commonFloat: [DisplayProperty] = [
        DisplayProperty(id: .normalizedBrightnessContrast, name: "Combined Brightness & Contrast"),
        DisplayProperty(id: .normalizedBrightness, name: "Brightness"),
        DisplayProperty(id: .normalizedContrast, name: "Contrast"),
        DisplayProperty(id: .volume, name: "Volume"),
        DisplayProperty(id: .subzeroDimming, name: "Sub-zero Dimming"),
        DisplayProperty(id: .xdrBrightness, name: "XDR Brightness"),
    ]
    static let commonBool: [DisplayProperty] = [
        DisplayProperty(id: .subzero, name: "Sub-zero Dimming"),
        DisplayProperty(id: .blackout, name: "BlackOut"),
        DisplayProperty(id: .facelight, name: "Facelight"),
        DisplayProperty(id: .xdr, name: "XDR Brightness"),
        DisplayProperty(id: .mute, name: "Mute"),
    ]
    static let lessCommonBool: [DisplayProperty] = [
        DisplayProperty(id: .power, name: "Power"),
        DisplayProperty(id: .hdr, name: "HDR"),
        DisplayProperty(id: .adaptive, name: "Adaptive Brightness"),
        DisplayProperty(id: .systemAdaptiveBrightness, name: "System Adaptive Brightness"),
    ]
    static let settingsBool: [DisplayProperty] = [
        DisplayProperty(id: .lockedBrightness, name: "Lock Brightness"),
        DisplayProperty(id: .lockedContrast, name: "Lock Contrast"),
        DisplayProperty(id: .lockedBrightnessCurve, name: "Lock Brightness Curve (disable auto-learning)"),
        DisplayProperty(id: .lockedContrastCurve, name: "Lock Contrast Curve (disable auto-learning)"),
        DisplayProperty(id: .useOverlay, name: "Use Overlay instead of Gamma for software dimming"),
        DisplayProperty(id: .isSource, name: "Sync Mode Source"),
        DisplayProperty(id: .showVolumeOSD, name: "Show Volume OSD"),
        DisplayProperty(id: .forceDDC, name: "Enforce DDC"),
        DisplayProperty(id: .applyGamma, name: "Apply Gamma Color Adjustments"),
    ]

    static let all = commonFloat + commonBool + lessCommonBool + settingsBool + commonNumeric + lessCommonNumeric + settingsNumeric + ddcSettingsNumeric
    static let allByID = all.dict { ($0.id, $0) }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Screen Property"

    let id: Display.CodingKeys
    let name: String

    var description: String { name }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}
