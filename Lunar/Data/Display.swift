//
//  Display.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import AnyCodable
import ArgumentParser
import Atomics
import Cocoa
import Combine
import CoreGraphics
import DataCompression
import Defaults
import Foundation
import OSLog
import Sentry
import Surge
import SwiftDate

let MIN_VOLUME: Int = 0
let MAX_VOLUME: Int = 100
let MIN_BRIGHTNESS: UInt8 = 0
let MAX_BRIGHTNESS: UInt8 = 100
let MIN_CONTRAST: UInt8 = 0
let MAX_CONTRAST: UInt8 = 100

let DEFAULT_MIN_BRIGHTNESS: UInt8 = 0
let DEFAULT_MAX_BRIGHTNESS: UInt8 = 100
let DEFAULT_MIN_CONTRAST: UInt8 = 50
let DEFAULT_MAX_CONTRAST: UInt8 = 75

let GENERIC_DISPLAY_ID: CGDirectDisplayID = UINT32_MAX
#if DEBUG
    let TEST_DISPLAY_ID: CGDirectDisplayID = UINT32_MAX / 2
    let TEST_DISPLAY_PERSISTENT_ID: CGDirectDisplayID = UINT32_MAX / 3
    let TEST_DISPLAY_PERSISTENT2_ID: CGDirectDisplayID = UINT32_MAX / 4
    let TEST_DISPLAY_PERSISTENT3_ID: CGDirectDisplayID = UINT32_MAX / 5
    let TEST_DISPLAY_PERSISTENT4_ID: CGDirectDisplayID = UINT32_MAX / 6
    let TEST_IDS = Set(
        arrayLiteral: GENERIC_DISPLAY_ID,
        TEST_DISPLAY_ID,
        TEST_DISPLAY_PERSISTENT_ID,
        TEST_DISPLAY_PERSISTENT2_ID,
        TEST_DISPLAY_PERSISTENT3_ID,
        TEST_DISPLAY_PERSISTENT4_ID
    )
#endif

let GENERIC_DISPLAY = Display(
    id: GENERIC_DISPLAY_ID,
    serial: "GENERIC_SERIAL",
    name: "No Display",
    minBrightness: 0,
    maxBrightness: 100,
    minContrast: 0,
    maxContrast: 100
)
#if DEBUG
    var TEST_DISPLAY: Display = {
        let d = Display(
            id: TEST_DISPLAY_ID,
            serial: "TEST_DISPLAY_SERIAL",
            name: "Test Display",
            active: true,
            minBrightness: 0,
            maxBrightness: 60,
            minContrast: 50,
            maxContrast: 75,
            adaptive: true,
            userBrightness: [.sync: [71: 55]]
        )
        d.hasI2C = true
        return d
    }()

    var TEST_DISPLAY_PERSISTENT: Display = {
        let d = datastore.displays(serials: ["TEST_DISPLAY_PERSISTENT_SERIAL"])?.first ?? Display(
            id: TEST_DISPLAY_PERSISTENT_ID,
            serial: "TEST_DISPLAY_PERSISTENT_SERIAL_PERSISTENT",
            name: "Persistent",
            active: true,
            minBrightness: 0,
            maxBrightness: 100,
            minContrast: 0,
            maxContrast: 100,
            adaptive: true
        )
        d.hasI2C = true
        return d
    }()

    var TEST_DISPLAY_PERSISTENT2: Display = {
        let d = datastore.displays(serials: ["TEST_DISPLAY_PERSISTENT2_SERIAL"])?.first ?? Display(
            id: TEST_DISPLAY_PERSISTENT2_ID,
            serial: "TEST_DISPLAY_PERSISTENT2_SERIAL_PERSISTENT_TWO",
            name: "Persistent v2",
            active: true,
            minBrightness: 0,
            maxBrightness: 100,
            minContrast: 0,
            maxContrast: 100,
            adaptive: true
        )
        d.hasI2C = true
        return d
    }()

    var TEST_DISPLAY_PERSISTENT3: Display = {
        let d = datastore.displays(serials: ["TEST_DISPLAY_PERSISTENT3_SERIAL"])?.first ?? Display(
            id: TEST_DISPLAY_PERSISTENT3_ID,
            serial: "TEST_DISPLAY_PERSISTENT3_SERIAL_PERSISTENT_THREE",
            name: "Persistent v3",
            active: true,
            minBrightness: 0,
            maxBrightness: 100,
            minContrast: 0,
            maxContrast: 100,
            adaptive: true
        )
        d.hasI2C = true
        return d
    }()

    var TEST_DISPLAY_PERSISTENT4: Display = {
        let d = datastore.displays(serials: ["TEST_DISPLAY_PERSISTENT4_SERIAL"])?.first ?? Display(
            id: TEST_DISPLAY_PERSISTENT4_ID,
            serial: "TEST_DISPLAY_PERSISTENT4_SERIAL_PERSISTENT_FOUR",
            name: "Persistent v4",
            active: true,
            minBrightness: 0,
            maxBrightness: 100,
            minContrast: 0,
            maxContrast: 100,
            adaptive: true
        )
        d.hasI2C = true
        return d
    }()
#endif

let MAX_SMOOTH_STEP_TIME_NS: UInt64 = 70 * 1_000_000 // 70ms

let ULTRAFINE_NAME = "LG UltraFine"
let THUNDERBOLT_NAME = "Thunderbolt"
let LED_CINEMA_NAME = "LED Cinema"
let CINEMA_NAME = "Cinema"
let CINEMA_HD_NAME = "Cinema HD"
let COLOR_LCD_NAME = "Color LCD"
let APPLE_DISPLAY_VENDOR_ID = 0x05AC

var INITIAL_GAMMA_VALUES = [CGDirectDisplayID: Gamma]()
var INITIAL_MAX_VALUES = [CGDirectDisplayID: Gamma]()
var INITIAL_MIN_VALUES = [CGDirectDisplayID: Gamma]()

struct Transport: Equatable {
    var upstream: String
    var downstream: String
}

struct Gamma: Equatable {
    var red: CGGammaValue
    var green: CGGammaValue
    var blue: CGGammaValue
    var contrast: CGGammaValue

    func stride(to gamma: Gamma, samples: Int) -> [Gamma] {
        guard gamma != self, samples > 0 else { return [gamma] }

        var (red, green, blue, contrast) = (red, green, blue, contrast)
        let ramps = (
            ramp(targetValue: gamma.red, lastTargetValue: &red, samples: samples, step: 0.01),
            ramp(targetValue: gamma.green, lastTargetValue: &green, samples: samples, step: 0.01),
            ramp(targetValue: gamma.blue, lastTargetValue: &blue, samples: samples, step: 0.01),
            ramp(targetValue: gamma.contrast, lastTargetValue: &contrast, samples: samples, step: 0.01)
        )
        return zip4(ramps.0, ramps.1, ramps.2, ramps.3).map { Gamma(red: $0, green: $1, blue: $2, contrast: $3) }
    }
}

enum ValueType {
    case brightness
    case contrast
}

// MARK: Display Class

@objc class Display: NSObject, Codable, Defaults.Serializable {
    override var description: String {
        "\(name)[\(serial): \(id)]"
    }

    // MARK: Stored Properties

    var _idLock = NSRecursiveLock()
    var _id: CGDirectDisplayID
    var id: CGDirectDisplayID {
        get { _idLock.around { _id } }
        set { _idLock.around { _id = newValue } }
    }

    // @AtomicLock @objc dynamic var id: CGDirectDisplayID {
    //     didSet {
    //         save()
    //     }
    // }

    var transport: Transport? = nil

    @objc dynamic var serial: String {
        didSet {
            save()
        }
    }

    var edidName: String
    @objc dynamic var name: String {
        didSet {
            context = getContext()
            save()
        }
    }

    @Published var adaptivePaused: Bool = false {
        didSet {
            readapt(newValue: adaptivePaused, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var adaptive: Bool {
        didSet {
            save()
            readapt(newValue: adaptive, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var defaultGammaRedMin: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaRedMax: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaRedValue: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaGreenMin: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaGreenMax: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaGreenValue: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaBlueMin: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaBlueMax: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaBlueValue: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var maxDDCBrightness: NSNumber {
        didSet {
            save()
            readapt(newValue: maxDDCBrightness, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var maxDDCContrast: NSNumber {
        didSet {
            save()
            readapt(newValue: maxDDCContrast, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var maxDDCVolume: NSNumber {
        didSet {
            save()
            readapt(newValue: maxDDCVolume, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var lockedBrightness: Bool {
        didSet {
            save()
        }
    }

    @Published @objc dynamic var lockedContrast: Bool {
        didSet {
            save()
        }
    }

    @Published @objc dynamic var minBrightness: NSNumber {
        didSet {
            save()
            readapt(newValue: minBrightness, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var maxBrightness: NSNumber {
        didSet {
            save()
            readapt(newValue: maxBrightness, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var minContrast: NSNumber {
        didSet {
            save()
            readapt(newValue: minContrast, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var maxContrast: NSNumber {
        didSet {
            save()
            readapt(newValue: maxContrast, oldValue: oldValue)
        }
    }

    @Published @objc dynamic var brightness: NSNumber {
        didSet {
            save()

            guard !lockedBrightness, force || brightness != oldValue else { return }
            if control is GammaControl, !(enabledControls[.gamma] ?? false) { return }

            if !force {
                guard checkRemainingAdjustments() else { return }
            }

            guard !isForTesting else { return }
            var brightness: UInt8
            if displayController.adaptiveModeKey == AdaptiveModeKey.manual {
                brightness = cap(self.brightness.uint8Value, minVal: 0, maxVal: 100)
            } else {
                brightness = cap(self.brightness.uint8Value, minVal: minBrightness.uint8Value, maxVal: maxBrightness.uint8Value)
            }

            var oldBrightness: UInt8 = oldValue.uint8Value
            if maxDDCBrightness != 100, !(control is GammaControl) {
                oldBrightness = mapNumber(
                    oldBrightness.d,
                    fromLow: 0,
                    fromHigh: 100,
                    toLow: 0,
                    toHigh: maxDDCBrightness.doubleValue
                ).rounded().u8
                brightness = mapNumber(
                    brightness.d,
                    fromLow: 0,
                    fromHigh: 100,
                    toLow: 0,
                    toHigh: maxDDCBrightness.doubleValue
                ).rounded().u8
            }

            log.verbose("Set BRIGHTNESS to \(brightness) (old: \(oldBrightness)", context: context)
            let startTime = DispatchTime.now()

            if !control.setBrightness(brightness, oldValue: oldBrightness) {
                log.warning(
                    "Error writing brightness using \(control!.str)",
                    context: context
                )
            }

            let elapsedTime: UInt64 = DispatchTime.now().rawValue - startTime.rawValue
            checkSlowWrite(elapsedNS: elapsedTime)
        }
    }

    @Published @objc dynamic var contrast: NSNumber {
        didSet {
            save()

            guard !lockedContrast, force || contrast != oldValue else { return }
            if control is GammaControl, !(enabledControls[.gamma] ?? false) { return }

            if !force {
                guard checkRemainingAdjustments() else { return }
            }

            guard !isForTesting else { return }
            var contrast: UInt8
            if displayController.adaptiveModeKey == AdaptiveModeKey.manual {
                contrast = cap(self.contrast.uint8Value, minVal: 0, maxVal: 100)
            } else {
                contrast = cap(self.contrast.uint8Value, minVal: minContrast.uint8Value, maxVal: maxContrast.uint8Value)
            }

            var oldContrast: UInt8 = oldValue.uint8Value
            if maxDDCContrast != 100, !(control is GammaControl) {
                oldContrast = mapNumber(
                    oldContrast.d,
                    fromLow: 0,
                    fromHigh: 100,
                    toLow: 0,
                    toHigh: maxDDCContrast.doubleValue
                ).rounded().u8
                contrast = mapNumber(
                    contrast.d,
                    fromLow: 0,
                    fromHigh: 100,
                    toLow: 0,
                    toHigh: maxDDCContrast.doubleValue
                ).rounded().u8
            }

            log.verbose("Set CONTRAST to \(contrast) (old: \(oldContrast)", context: context)
            let startTime = DispatchTime.now()

            if !control.setContrast(contrast, oldValue: oldContrast) {
                log.warning(
                    "Error writing contrast using \(control!.str)",
                    context: context
                )
            }

            let elapsedTime: UInt64 = DispatchTime.now().rawValue - startTime.rawValue
            checkSlowWrite(elapsedNS: elapsedTime)
        }
    }

    @Published @objc dynamic var volume: NSNumber {
        didSet {
            save()

            guard !isForTesting else { return }

            var volume = self.volume.uint8Value
            if maxDDCVolume != 100, !(control is GammaControl) {
                volume = mapNumber(volume.d, fromLow: 0, fromHigh: 100, toLow: 0, toHigh: maxDDCVolume.doubleValue).rounded().u8
            }

            if !control.setVolume(volume) {
                log.warning(
                    "Error writing volume using \(control!.str)",
                    context: context
                )
            }
        }
    }

    @Published @objc dynamic var input: NSNumber {
        didSet {
            save()

            guard !isForTesting,
                  let input = InputSource(rawValue: self.input.uint8Value),
                  input != .unknown
            else { return }
            if !control.setInput(input) {
                log.warning(
                    "Error writing input using \(control!.str)",
                    context: context
                )
            }
        }
    }

    @Published @objc dynamic var hotkeyInput: NSNumber {
        didSet {
            save()
        }
    }

    @Published @objc dynamic var brightnessOnInputChange: NSNumber {
        didSet {
            save()
        }
    }

    @Published @objc dynamic var contrastOnInputChange: NSNumber {
        didSet {
            save()
        }
    }

    @Published @objc dynamic var audioMuted: Bool {
        didSet {
            save()

            guard !isForTesting else { return }
            if !control.setMute(audioMuted) {
                log.warning(
                    "Error writing muted audio using \(control!.str)",
                    context: context
                )
            }
        }
    }

    @Published @objc dynamic var power: Bool = true {
        didSet {
            save()
        }
    }

    // MARK: Computed Properties

    @Published @objc dynamic var active: Bool = false {
        didSet {
            if active {
                startControls()
            }

            save()
            mainThread {
                activeAndResponsive = (active && responsiveDDC) || !(control is DDCControl)
            }
        }
    }

    @Published @objc dynamic var responsiveDDC: Bool = true {
        didSet {
            context = getContext()
            mainThread {
                activeAndResponsive = (active && responsiveDDC) || !(control is DDCControl)
            }
        }
    }

    @Published @objc dynamic var activeAndResponsive: Bool = false

    // var i2cController: io_service_t? = nil {
    //     didSet {
    //         hasI2C = i2cController != nil || avService != nil
    //     }
    // }

    // var avService: IOAVService? = nil {
    //     didSet {
    //         hasI2C = i2cController != nil || avService != nil
    //     }
    // }

    @Published @objc dynamic var hasI2C: Bool = true {
        didSet {
            context = getContext()
            mainThread {
                hasDDC = hasI2C || hasNetworkControl
            }
        }
    }

    @Published @objc dynamic var hasNetworkControl: Bool = false {
        didSet {
            context = getContext()
            mainThread {
                hasDDC = hasI2C || hasNetworkControl
            }
        }
    }

    @Published @objc dynamic var hasDDC: Bool = false {
        didSet {}
    }

    @Published @objc dynamic var alwaysUseNetworkControl: Bool = false {
        didSet {
            context = getContext()
        }
    }

    @Published @objc dynamic var neverUseNetworkControl: Bool = false {
        didSet {
            context = getContext()
        }
    }

    @Published @objc dynamic var alwaysFallbackControl: Bool = false {
        didSet {
            context = getContext()
        }
    }

    @Published @objc dynamic var neverFallbackControl: Bool = false {
        didSet {
            context = getContext()
        }
    }

    @Published @objc dynamic var isSource: Bool = false {
        didSet {
            context = getContext()
        }
    }

    var enabledControls: [DisplayControl: Bool] = [
        .network: true,
        .coreDisplay: true,
        .ddc: true,
        .gamma: true,
    ]

    // MARK: "Sending" states

    func manageSendingValue(_ key: CodingKeys, oldValue _: Bool) {
        let name = key.rawValue
        guard let value = self.value(forKey: name) as? Bool,
              let condition =
              self.value(forKey: name.replacingOccurrences(of: "sending", with: "sent") + "Condition") as? NSCondition
        else {
            log.error("No condition property found for \(name)")
            return
        }

        if !value {
            condition.broadcast()
            hideOperationInProgress()
        } else {
            if let app = NSWorkspace.shared.frontmostApplication,
               !displayController.runningAppExceptions.contains(where: { appexc in appexc.identifier == app.bundleIdentifier })
            {
                showOperationInProgress(screen: screen)
            }
            let subscriberKey = "\(name)-\(serial)"
            debounce(ms: 5000, uniqueTaskKey: name, subscriberKey: subscriberKey) { [weak self] in
                guard let self = self else {
                    cancelTask(name, subscriberKey: subscriberKey)
                    return
                }
                self.setValue(false, forKey: name)

                guard let condition = self.value(
                    forKey: name.replacingOccurrences(of: "sending", with: "sent") + "Condition"
                ) as? NSCondition
                else {
                    log.error("No condition property found for \(name)")
                    return
                }
                condition.broadcast()
                hideOperationInProgress()
            }
        }
    }

    @objc dynamic var sentBrightnessCondition = NSCondition()
    @Published @objc dynamic var sendingBrightness: Bool = false {
        didSet {
            manageSendingValue(.sendingBrightness, oldValue: oldValue)
        }
    }

    @objc dynamic var sentContrastCondition = NSCondition()
    @Published @objc dynamic var sendingContrast: Bool = false {
        didSet {
            manageSendingValue(.sendingContrast, oldValue: oldValue)
        }
    }

    @objc dynamic var sentInputCondition = NSCondition()
    @Published @objc dynamic var sendingInput: Bool = false {
        didSet {
            manageSendingValue(.sendingInput, oldValue: oldValue)
        }
    }

    @objc dynamic var sentVolumeCondition = NSCondition()
    @Published @objc dynamic var sendingVolume: Bool = false {
        didSet {
            manageSendingValue(.sendingVolume, oldValue: oldValue)
        }
    }

    // MARK: Gamma and User values

    var infoDictionary: NSDictionary = [:]

    var userBrightness: [AdaptiveModeKey: [Int: Int]] = [:]
    var userContrast: [AdaptiveModeKey: [Int: Int]] = [:]

    var redMin: CGGammaValue = 0.0
    var redMax: CGGammaValue = 1.0
    var redGamma: CGGammaValue = 1.0

    var initialRedMin: CGGammaValue { INITIAL_MIN_VALUES[id]?.red ?? 1.0 }
    var initialRedMax: CGGammaValue { INITIAL_MAX_VALUES[id]?.red ?? 1.0 }
    var initialRedGamma: CGGammaValue { INITIAL_GAMMA_VALUES[id]?.red ?? 1.0 }

    var greenMin: CGGammaValue = 0.0
    var greenMax: CGGammaValue = 1.0
    var greenGamma: CGGammaValue = 1.0

    var initialGreenMin: CGGammaValue { INITIAL_MIN_VALUES[id]?.green ?? 1.0 }
    var initialGreenMax: CGGammaValue { INITIAL_MAX_VALUES[id]?.green ?? 1.0 }
    var initialGreenGamma: CGGammaValue { INITIAL_GAMMA_VALUES[id]?.green ?? 1.0 }

    var blueMin: CGGammaValue = 0.0
    var blueMax: CGGammaValue = 1.0
    var blueGamma: CGGammaValue = 1.0

    var initialBlueMin: CGGammaValue { INITIAL_MIN_VALUES[id]?.blue ?? 1.0 }
    var initialBlueMax: CGGammaValue { INITIAL_MAX_VALUES[id]?.blue ?? 1.0 }
    var initialBlueGamma: CGGammaValue { INITIAL_GAMMA_VALUES[id]?.blue ?? 1.0 }

    // MARK: Misc Properties

    var onReadapt: (() -> Void)?
    var smoothStep = 1
    var readableID: String {
        if name.isEmpty || name == "Unknown" {
            return shortHash(string: serial)
        }
        let safeName = "[^\\w\\d]+".r!.replaceAll(in: name.lowercased(), with: "")
        return "\(safeName)-\(shortHash(string: serial))"
    }

    @AtomicLock var brightnessDataPointInsertionTask: DispatchWorkItem? = nil
    @AtomicLock var contrastDataPointInsertionTask: DispatchWorkItem? = nil

    var slowRead = false
    var slowWrite = false

    var alternativeControlForCoreDisplay: Control? = nil {
        didSet {
            context = getContext()
            if let control = alternativeControlForCoreDisplay {
                log.debug(
                    "Display got alternativeControlForCoreDisplay \(control.str)",
                    context: context
                )
                mainThread {
                    hasNetworkControl = control is NetworkControl || alternativeControlForCoreDisplay is NetworkControl
                }
            }
        }
    }

    var onControlChange: ((Control) -> Void)? = nil
    @AtomicLock var control: Control! = nil {
        didSet {
            context = getContext()
            if let control = control {
                log.debug(
                    "Display got \(control.str)",
                    context: context
                )
                mainThread {
                    activeAndResponsive = (active && responsiveDDC) || !(control is DDCControl)
                    hasNetworkControl = control is NetworkControl || alternativeControlForCoreDisplay is NetworkControl
                }
                if !(control is GammaControl) {
                    resetGamma()
                }
                if !(oldValue is GammaControl), control is GammaControl {
                    if let app = NSRunningApplication.runningApplications(withBundleIdentifier: FLUX_IDENTIFIER).first {
                        (control as! GammaControl).fluxChecker(flux: app)
                    }
                    setGamma()
                }
                if control is CoreDisplayControl {
                    alternativeControlForCoreDisplay = getBestAlternativeControlForCoreDisplay()
                }
                onControlChange?(control)
            }
        }
    }

    @AtomicLock var context: [String: Any]? = nil

    lazy var isForTesting = isTestID(id)

    var observers: Set<AnyCancellable> = []

    lazy var screen: NSScreen? = {
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification, object: nil)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.screen = NSScreen.screens.first(where: { screen in screen.hasDisplayID(self.id) }) ?? NSScreen.onlyExternalScreen
            }
            .store(in: &observers)

        guard !isForTesting else { return nil }
        return NSScreen.screens.first(where: { screen in screen.hasDisplayID(id) }) ?? NSScreen.onlyExternalScreen
    }()

    lazy var armProps = DisplayController.armDisplayProperties(display: self)

    @Atomic var force = false
    @Atomic var faceLightEnabled = false
    lazy var brightnessBeforeFacelight = brightness
    lazy var contrastBeforeFacelight = contrast
    lazy var maxBrightnessBeforeFacelight = maxBrightness
    lazy var maxContrastBeforeFacelight = maxContrast

    // MARK: Functions

    func getContext() -> [String: Any] {
        [
            "name": name,
            "id": id,
            "serial": serial,
            "control": control?.str ?? "Unknown",
            "alternativeControlForCoreDisplay": alternativeControlForCoreDisplay?.str ?? "Unknown",
            "hasI2C": hasI2C,
            "hasNetworkControl": hasNetworkControl,
            "alwaysFallbackControl": alwaysFallbackControl,
            "neverFallbackControl": neverFallbackControl,
            "alwaysUseNetworkControl": alwaysUseNetworkControl,
            "neverUseNetworkControl": neverUseNetworkControl,
            "isAppleDisplay": isAppleDisplay(),
            "isSource": isSource,
        ]
    }

    func getBestControl() -> Control {
        let networkControl = NetworkControl(display: self)
        let coreDisplayControl = CoreDisplayControl(display: self)
        let ddcControl = DDCControl(display: self)
        let gammaControl = GammaControl(display: self)

        if networkControl.isAvailable() {
            resetGamma()
            return networkControl
        }
        if coreDisplayControl.isAvailable() {
            resetGamma()
            return coreDisplayControl
        }
        if ddcControl.isAvailable() {
            resetGamma()
            return ddcControl
        }

        return gammaControl
    }

    func getBestAlternativeControlForCoreDisplay() -> Control? {
        let networkControl = NetworkControl(display: self)
        let ddcControl = DDCControl(display: self)

        if networkControl.isAvailable() {
            return networkControl
        }
        if ddcControl.isAvailable() {
            return ddcControl
        }

        return nil
    }

    func values(_ monitorValue: MonitorValue, modeKey: AdaptiveModeKey) -> (Double, Double, Double, [Int: Int]) {
        var minValue, maxValue, value: Double
        var userValues: [Int: Int]

        switch monitorValue {
        case let .preciseBrightness(brightness):
            value = brightness
            minValue = minBrightness.doubleValue
            maxValue = maxBrightness.doubleValue
            userValues = userBrightness[modeKey] ?? [:]
        case let .preciseContrast(contrast):
            value = contrast
            minValue = minContrast.doubleValue
            maxValue = maxContrast.doubleValue
            userValues = userContrast[modeKey] ?? [:]
        case let .brightness(brightness):
            value = brightness.d
            minValue = minBrightness.doubleValue
            maxValue = maxBrightness.doubleValue
            userValues = userBrightness[modeKey] ?? [:]
        case let .contrast(contrast):
            value = contrast.d
            minValue = minContrast.doubleValue
            maxValue = maxContrast.doubleValue
            userValues = userContrast[modeKey] ?? [:]
        case let .nsBrightness(brightness):
            value = brightness.doubleValue
            minValue = minBrightness.doubleValue
            maxValue = maxBrightness.doubleValue
            userValues = userBrightness[modeKey] ?? [:]
        case let .nsContrast(contrast):
            value = contrast.doubleValue
            minValue = minContrast.doubleValue
            maxValue = maxContrast.doubleValue
            userValues = userContrast[modeKey] ?? [:]
        }

        return (value, minValue, maxValue, userValues)
    }

    // MARK: Initializers

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let userBrightnessContainer = try container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .userBrightness)
        let userContrastContainer = try container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .userContrast)
        let enabledControlsContainer = try container.nestedContainer(keyedBy: DisplayControlKeys.self, forKey: .enabledControls)

        _id = try container.decode(CGDirectDisplayID.self, forKey: .id)
        serial = try container.decode(String.self, forKey: .serial)

        adaptive = try container.decode(Bool.self, forKey: .adaptive)
        name = try container.decode(String.self, forKey: .name)
        edidName = try container.decode(String.self, forKey: .edidName)
        active = try container.decode(Bool.self, forKey: .active)

        brightness = (try container.decode(UInt8.self, forKey: .brightness)).ns
        contrast = (try container.decode(UInt8.self, forKey: .contrast)).ns
        minBrightness = (try container.decode(UInt8.self, forKey: .minBrightness)).ns
        maxBrightness = (try container.decode(UInt8.self, forKey: .maxBrightness)).ns
        minContrast = (try container.decode(UInt8.self, forKey: .minContrast)).ns
        maxContrast = (try container.decode(UInt8.self, forKey: .maxContrast)).ns

        defaultGammaRedMin = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaRedMin)?.ns) ?? 0.ns
        defaultGammaRedMax = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaRedMax)?.ns) ?? 1.ns
        defaultGammaRedValue = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaRedValue)?.ns) ?? 1.ns
        defaultGammaGreenMin = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaGreenMin)?.ns) ?? 0.ns
        defaultGammaGreenMax = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaGreenMax)?.ns) ?? 1.ns
        defaultGammaGreenValue = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaGreenValue)?.ns) ?? 1.ns
        defaultGammaBlueMin = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaBlueMin)?.ns) ?? 0.ns
        defaultGammaBlueMax = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaBlueMax)?.ns) ?? 1.ns
        defaultGammaBlueValue = (try container.decodeIfPresent(Float.self, forKey: .defaultGammaBlueValue)?.ns) ?? 1.ns

        maxDDCBrightness = (try container.decodeIfPresent(UInt8.self, forKey: .maxDDCBrightness)?.ns) ?? 100.ns
        maxDDCContrast = (try container.decodeIfPresent(UInt8.self, forKey: .maxDDCContrast)?.ns) ?? 100.ns
        maxDDCVolume = (try container.decodeIfPresent(UInt8.self, forKey: .maxDDCVolume)?.ns) ?? 100.ns

        lockedBrightness = try container.decode(Bool.self, forKey: .lockedBrightness)
        lockedContrast = try container.decode(Bool.self, forKey: .lockedContrast)

        alwaysUseNetworkControl = try container.decode(Bool.self, forKey: .alwaysUseNetworkControl)
        neverUseNetworkControl = try container.decode(Bool.self, forKey: .neverUseNetworkControl)
        alwaysFallbackControl = try container.decode(Bool.self, forKey: .alwaysFallbackControl)
        neverFallbackControl = try container.decode(Bool.self, forKey: .neverFallbackControl)

        volume = (try container.decode(UInt8.self, forKey: .volume)).ns
        audioMuted = try container.decode(Bool.self, forKey: .audioMuted)
        isSource = try container.decodeIfPresent(Bool.self, forKey: .isSource) ?? false
        input = (try container.decode(UInt8.self, forKey: .input)).ns
        hotkeyInput = (try container.decode(UInt8.self, forKey: .hotkeyInput)).ns
        brightnessOnInputChange = (try container.decode(UInt8.self, forKey: .brightnessOnInputChange)).ns
        contrastOnInputChange = (try container.decode(UInt8.self, forKey: .contrastOnInputChange)).ns

        if let syncUserBrightness = try userBrightnessContainer.decodeIfPresent([Int: Int].self, forKey: .sync) {
            userBrightness[.sync] = syncUserBrightness
        }
        if let sensorUserBrightness = try userBrightnessContainer.decodeIfPresent([Int: Int].self, forKey: .sensor) {
            userBrightness[.sensor] = sensorUserBrightness
        }
        if let locationUserBrightness = try userBrightnessContainer.decodeIfPresent([Int: Int].self, forKey: .location) {
            userBrightness[.location] = locationUserBrightness
        }
        if let manualUserBrightness = try userBrightnessContainer.decodeIfPresent([Int: Int].self, forKey: .manual) {
            userBrightness[.manual] = manualUserBrightness
        }

        if let syncUserContrast = try userContrastContainer.decodeIfPresent([Int: Int].self, forKey: .sync) {
            userContrast[.sync] = syncUserContrast
        }
        if let sensorUserContrast = try userContrastContainer.decodeIfPresent([Int: Int].self, forKey: .sensor) {
            userContrast[.sensor] = sensorUserContrast
        }
        if let locationUserContrast = try userContrastContainer.decodeIfPresent([Int: Int].self, forKey: .location) {
            userContrast[.location] = locationUserContrast
        }
        if let manualUserContrast = try userContrastContainer.decodeIfPresent([Int: Int].self, forKey: .manual) {
            userContrast[.manual] = manualUserContrast
        }

        if let networkControlEnabled = try enabledControlsContainer.decodeIfPresent(Bool.self, forKey: .network) {
            enabledControls[.network] = networkControlEnabled
        }
        if let coreDisplayControlEnabled = try enabledControlsContainer.decodeIfPresent(Bool.self, forKey: .coreDisplay) {
            enabledControls[.coreDisplay] = coreDisplayControlEnabled
        }
        if let ddcControlEnabled = try enabledControlsContainer.decodeIfPresent(Bool.self, forKey: .ddc) {
            enabledControls[.ddc] = ddcControlEnabled
        }
        if let gammaControlEnabled = try enabledControlsContainer.decodeIfPresent(Bool.self, forKey: .gamma) {
            enabledControls[.gamma] = gammaControlEnabled
        }

        super.init()

        if let dict = displayInfoDictionary(id) {
            infoDictionary = dict
        }
    }

    func startControls() {
        if !isGeneric(id) {
            if CachedDefaults[.refreshValues] {
                serialQueue.async { [weak self] in
                    guard let self = self else { return }
                    self.refreshBrightness()
                    self.refreshContrast()
                    self.refreshVolume()
                    self.refreshInput()
                }
            }
            refreshGamma()
        }

        startI2CDetection()
        detectI2C()

        control = getBestControl()
    }

    func matchesEDIDUUID(_ edidUUID: String) -> Bool {
        let uuids = possibleEDIDUUIDs()
        guard !uuids.isEmpty else {
            log.info("No EDID UUID pattern to test with \(edidUUID) for display \(self)")
            return false
        }

        return uuids.contains { uuid in
            guard let uuidPattern = uuid.r else { return false }
            log.info("Testing EDID UUID pattern \(uuid) with \(edidUUID) for display \(self)")

            let matched = uuidPattern.matches(edidUUID)
            if matched {
                log.info("Matched EDID UUID pattern \(uuid) with \(edidUUID) for display \(self)")
            }
            return matched
        }
    }

    func possibleEDIDUUIDs() -> [String] {
        let infoDict = infoDictionary
        guard let manufactureYear = infoDict[kDisplayYearOfManufacture] as? Int64, manufactureYear >= 1990,
              let manufactureWeek = infoDict[kDisplayWeekOfManufacture] as? Int64,
              let serialNumber = infoDict[kDisplaySerialNumber] as? Int64,
              let productID = infoDict[kDisplayProductID] as? Int64,
              let vendorID = infoDict[kDisplayVendorID] as? Int64,
              let verticalPixels = infoDict[kDisplayVerticalImageSize] as? Int64,
              let horizontalPixels = infoDict[kDisplayHorizontalImageSize] as? Int64
        else { return [] }

        let yearByte = (manufactureYear - 1990).u8.hex.uppercased()
        let weekByte = manufactureWeek.u8.hex.uppercased()
        let vendorBytes = vendorID.u16.str(reversed: true, separator: "").uppercased()
        let productBytes = productID.u16.str(reversed: false, separator: "").uppercased()
        let serialBytes = serialNumber.u32.str(reversed: false, separator: "").uppercased()
        let verticalBytes = (verticalPixels / 10).u8.hex.uppercased()
        let horizontalBytes = (horizontalPixels / 10).u8.hex.uppercased()

        return [
            "\(vendorBytes)\(productBytes)-0000-0000-\(weekByte)\(yearByte)-0104B5\(horizontalBytes)\(verticalBytes)78",
            "\(vendorBytes)\(productBytes)-\(serialBytes.prefix(4))-\(serialBytes.suffix(4))-\(weekByte)\(yearByte)-0104B5\(horizontalBytes)\(verticalBytes)78",
            "\(vendorBytes)\(productBytes)-0000-0000-\(weekByte)\(yearByte)-[\\dA-F]{6}\(horizontalBytes)\(verticalBytes)[\\dA-F]{2}",
            "\(vendorBytes)\(productBytes)-\(serialBytes.prefix(4))-\(serialBytes.suffix(4))-\(weekByte)\(yearByte)-[\\dA-F]{6}\(horizontalBytes)\(verticalBytes)[\\dA-F]{2}",
        ]
    }

    func detectI2C() {
        #if DEBUG
            #if arch(arm64)
                // avService = (id == TEST_DISPLAY_ID) ? (1 as IOAVService) : DDC.AVService(displayID: id, display: self)
                hasI2C = (id == TEST_DISPLAY_ID) ? true : DDC.hasAVService(displayID: id, display: self, ignoreCache: true)
            #else
                // i2cController = (id == TEST_DISPLAY_ID) ? 1 : DDC.I2CController(displayID: id)
                hasI2C = (id == TEST_DISPLAY_ID) ? true : DDC.hasI2CController(displayID: id, ignoreCache: true)
            #endif
        #else
            #if arch(arm64)
                // avService = DDC.AVService(displayID: id, display: self)
                hasI2C = DDC.hasAVService(displayID: id, display: self, ignoreCache: true)
            #else
                // i2cController = DDC.I2CController(displayID: id)
                hasI2C = DDC.hasI2CController(displayID: id, ignoreCache: true)
            #endif
        #endif
    }

    func startI2CDetection() {
        let taskKey = "i2c-detector-\(serial)"
        asyncEvery(1.seconds, uniqueTaskKey: taskKey, runs: 15) { [weak self] in
            guard let self = self else { return }
            self.detectI2C()
            if self.hasI2C {
                cancelTask(taskKey)
            }
        }
    }

    init(
        id: CGDirectDisplayID,
        brightness: UInt8 = 50,
        contrast: UInt8 = 50,
        serial: String? = nil,
        name: String? = nil,
        active: Bool = false,
        minBrightness: UInt8 = DEFAULT_MIN_BRIGHTNESS,
        maxBrightness: UInt8 = DEFAULT_MAX_BRIGHTNESS,
        minContrast: UInt8 = DEFAULT_MIN_CONTRAST,
        maxContrast: UInt8 = DEFAULT_MAX_CONTRAST,
        adaptive: Bool = true,
        maxDDCBrightness: UInt8 = 100,
        maxDDCContrast: UInt8 = 100,
        maxDDCVolume: UInt8 = 100,
        lockedBrightness: Bool = false,
        lockedContrast: Bool = false,
        volume: UInt8 = 10,
        audioMuted: Bool = false,
        input: UInt8 = InputSource.unknown.rawValue,
        hotkeyInput: UInt8 = InputSource.unknown.rawValue,
        userBrightness: [AdaptiveModeKey: [Int: Int]]? = nil,
        userContrast: [AdaptiveModeKey: [Int: Int]]? = nil,
        alwaysUseNetworkControl: Bool = false,
        neverUseNetworkControl: Bool = false,
        alwaysFallbackControl: Bool = false,
        neverFallbackControl: Bool = false,
        enabledControls: [DisplayControl: Bool]? = nil,
        brightnessOnInputChange: UInt8 = 100,
        contrastOnInputChange: UInt8 = 75,
        defaultGammaRedMin: Float = 0.0,
        defaultGammaRedMax: Float = 1.0,
        defaultGammaRedValue: Float = 1.0,
        defaultGammaGreenMin: Float = 0.0,
        defaultGammaGreenMax: Float = 1.0,
        defaultGammaGreenValue: Float = 1.0,
        defaultGammaBlueMin: Float = 0.0,
        defaultGammaBlueMax: Float = 1.0,
        defaultGammaBlueValue: Float = 1.0
    ) {
        _id = id
        self.active = active
        activeAndResponsive = active || id != GENERIC_DISPLAY_ID
        self.adaptive = adaptive

        self.defaultGammaRedMin = defaultGammaRedMin.ns
        self.defaultGammaRedMax = defaultGammaRedMax.ns
        self.defaultGammaRedValue = defaultGammaRedValue.ns
        self.defaultGammaGreenMin = defaultGammaGreenMin.ns
        self.defaultGammaGreenMax = defaultGammaGreenMax.ns
        self.defaultGammaGreenValue = defaultGammaGreenValue.ns
        self.defaultGammaBlueMin = defaultGammaBlueMin.ns
        self.defaultGammaBlueMax = defaultGammaBlueMax.ns
        self.defaultGammaBlueValue = defaultGammaBlueValue.ns

        self.maxDDCBrightness = maxDDCBrightness.ns
        self.maxDDCContrast = maxDDCContrast.ns
        self.maxDDCVolume = maxDDCVolume.ns

        self.lockedBrightness = lockedBrightness
        self.lockedContrast = lockedContrast
        self.audioMuted = audioMuted

        self.brightness = brightness.ns
        self.contrast = contrast.ns
        self.volume = volume.ns
        self.minBrightness = minBrightness.ns
        self.maxBrightness = maxBrightness.ns
        self.minContrast = minContrast.ns
        self.maxContrast = maxContrast.ns
        self.input = input.ns
        self.hotkeyInput = hotkeyInput.ns
        self.alwaysUseNetworkControl = alwaysUseNetworkControl
        self.neverUseNetworkControl = neverUseNetworkControl
        self.alwaysFallbackControl = alwaysFallbackControl
        self.neverFallbackControl = neverFallbackControl

        self.brightnessOnInputChange = brightnessOnInputChange.ns
        self.contrastOnInputChange = contrastOnInputChange.ns

        if let enabledControls = enabledControls {
            self.enabledControls = enabledControls
        }
        if let userBrightness = userBrightness {
            self.userBrightness = userBrightness
        }
        if let userContrast = userContrast {
            self.userContrast = userContrast
        }

        edidName = DDC.getDisplayName(for: id) ?? "Unknown"
        if let n = name, !n.isEmpty {
            self.name = n
        } else {
            self.name = edidName
        }
        self.serial = (serial ?? Display.uuid(id: id))

        super.init()

        if let dict = displayInfoDictionary(id) {
            infoDictionary = dict
        }

        startControls()
    }

    static func fromDictionary(_ config: [String: Any]) -> Display? {
        guard let id = config["id"] as? CGDirectDisplayID,
              let serial = config["serial"] as? String else { return nil }

        return Display(
            id: id,
            brightness: (config["brightness"] as? UInt8) ?? 50,
            contrast: (config["contrast"] as? UInt8) ?? 50,
            serial: serial,
            name: config["name"] as? String,
            active: (config["active"] as? Bool) ?? false,
            minBrightness: (config["minBrightness"] as? UInt8) ?? DEFAULT_MIN_BRIGHTNESS,
            maxBrightness: (config["maxBrightness"] as? UInt8) ?? DEFAULT_MAX_BRIGHTNESS,
            minContrast: (config["minContrast"] as? UInt8) ?? DEFAULT_MIN_CONTRAST,
            maxContrast: (config["maxContrast"] as? UInt8) ?? DEFAULT_MAX_CONTRAST,
            adaptive: (config["adaptive"] as? Bool) ?? true,
            maxDDCBrightness: (config["maxDDCBrightness"] as? UInt8) ?? 100,
            maxDDCContrast: (config["maxDDCContrast"] as? UInt8) ?? 100,
            maxDDCVolume: (config["maxDDCVolume"] as? UInt8) ?? 100,
            lockedBrightness: (config["lockedBrightness"] as? Bool) ?? false,
            lockedContrast: (config["lockedContrast"] as? Bool) ?? false,
            volume: (config["volume"] as? UInt8) ?? 10,
            audioMuted: (config["audioMuted"] as? Bool) ?? false,
            input: (config["input"] as? UInt8) ?? InputSource.unknown.rawValue,
            hotkeyInput: (config["hotkeyInput"] as? UInt8) ?? InputSource.unknown.rawValue,
            userBrightness: (config["userBrightness"] as? [AdaptiveModeKey: [Int: Int]]) ?? [:],
            userContrast: (config["userContrast"] as? [AdaptiveModeKey: [Int: Int]]) ?? [:],
            alwaysUseNetworkControl: (config["alwaysUseNetworkControl"] as? Bool) ?? false,
            neverUseNetworkControl: (config["neverUseNetworkControl"] as? Bool) ?? false,
            alwaysFallbackControl: (config["alwaysFallbackControl"] as? Bool) ?? false,
            neverFallbackControl: (config["neverFallbackControl"] as? Bool) ?? false,
            enabledControls: (config["enabledControls"] as? [DisplayControl: Bool]) ?? [
                .network: true,
                .coreDisplay: true,
                .ddc: true,
                .gamma: true,
            ],
            brightnessOnInputChange: (config["brightnessOnInputChange"] as? UInt8) ?? 100,
            contrastOnInputChange: (config["contrastOnInputChange"] as? UInt8) ?? 75,
            defaultGammaRedMin: (config["defaultGammaRedMin"] as? Float) ?? 0.0,
            defaultGammaRedMax: (config["defaultGammaRedMax"] as? Float) ?? 1.0,
            defaultGammaRedValue: (config["defaultGammaRedValue"] as? Float) ?? 1.0,
            defaultGammaGreenMin: (config["defaultGammaGreenMin"] as? Float) ?? 0.0,
            defaultGammaGreenMax: (config["defaultGammaGreenMax"] as? Float) ?? 1.0,
            defaultGammaGreenValue: (config["defaultGammaGreenValue"] as? Float) ?? 1.0,
            defaultGammaBlueMin: (config["defaultGammaBlueMin"] as? Float) ?? 0.0,
            defaultGammaBlueMax: (config["defaultGammaBlueMax"] as? Float) ?? 1.0,
            defaultGammaBlueValue: (config["defaultGammaBlueValue"] as? Float) ?? 1.0
        )
    }

    func save() {
        debounce(ms: 800, uniqueTaskKey: "displaySave", value: self) { display in
            DataStore.storeDisplay(display: display)
        }
    }

    // MARK: EDID

    static func printableName(_ id: CGDirectDisplayID) -> String {
        #if DEBUG
            switch id {
            case TEST_DISPLAY_ID:
                return "Test Display"
            case TEST_DISPLAY_PERSISTENT_ID:
                return "Persistent"
            case TEST_DISPLAY_PERSISTENT2_ID:
                return "Persistent v2"
            case TEST_DISPLAY_PERSISTENT3_ID:
                return "Persistent v3"
            case TEST_DISPLAY_PERSISTENT4_ID:
                return "Persistent v4"
            default:
                break
            }
        #endif

        if let screen = NSScreen.forDisplayID(id) {
            return screen.localizedName
        }

        if let infoDict = displayInfoDictionary(id), let names = infoDict["DisplayProductName"] as? [String: String],
           let name = names[Locale.current.identifier] ?? names["en_US"] ?? names.first?.value
        {
            return name
        }

        if var name = DDC.getDisplayName(for: id) {
            name = name.stripped
            let minChars = floor(name.count.d * 0.8)
            if name.utf8.map({ c in (0x21 ... 0x7E).contains(c) ? 1 : 0 }).reduce(0, { $0 + $1 }) >= minChars {
                return name
            }
        }
        return "Unknown"
    }

    static func uuid(id: CGDirectDisplayID) -> String {
        #if DEBUG
            switch id {
            case TEST_DISPLAY_ID:
                return "TEST_DISPLAY_SERIAL"
            case TEST_DISPLAY_PERSISTENT_ID:
                return "TEST_DISPLAY_PERSISTENT_SERIAL"
            case TEST_DISPLAY_PERSISTENT2_ID:
                return "TEST_DISPLAY_PERSISTENT2_SERIAL"
            case TEST_DISPLAY_PERSISTENT3_ID:
                return "TEST_DISPLAY_PERSISTENT3_SERIAL"
            case TEST_DISPLAY_PERSISTENT4_ID:
                return "TEST_DISPLAY_PERSISTENT4_SERIAL"
            default:
                break
            }
        #endif

        if let uuid = CGDisplayCreateUUIDFromDisplayID(id) {
            let uuidValue = uuid.takeRetainedValue()
            let uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuidValue) as String
            return uuidString
        }
        if let edid = Display.edid(id: id) {
            return edid
        }
        return String(describing: id)
    }

    static func edid(id: CGDirectDisplayID) -> String? {
        DDC.getEdidData(displayID: id)?.map { $0 }.str(hex: true)
    }

    func resetName() {
        name = Display.printableName(id)
    }

    // MARK: Codable

    enum CodingKeys: String, CodingKey, CaseIterable, ExpressibleByArgument {
        case id
        case name
        case edidName
        case serial
        case adaptive
        case defaultGammaRedMin
        case defaultGammaRedMax
        case defaultGammaRedValue
        case defaultGammaGreenMin
        case defaultGammaGreenMax
        case defaultGammaGreenValue
        case defaultGammaBlueMin
        case defaultGammaBlueMax
        case defaultGammaBlueValue
        case maxDDCBrightness
        case maxDDCContrast
        case maxDDCVolume
        case lockedBrightness
        case lockedContrast
        case minContrast
        case minBrightness
        case maxContrast
        case maxBrightness
        case contrast
        case brightness
        case volume
        case audioMuted
        case power
        case active
        case responsiveDDC
        case input
        case hotkeyInput
        case userBrightness
        case userContrast
        case alwaysUseNetworkControl
        case neverUseNetworkControl
        case alwaysFallbackControl
        case neverFallbackControl
        case enabledControls
        case activeAndResponsive
        case hasDDC
        case hasI2C
        case hasNetworkControl
        case sendingBrightness
        case sendingContrast
        case sendingInput
        case sendingVolume
        case isSource
        case brightnessOnInputChange
        case contrastOnInputChange

        static var settable: [CodingKeys] {
            [
                .name,
                .adaptive,
                .defaultGammaRedMin,
                .defaultGammaRedMax,
                .defaultGammaRedValue,
                .defaultGammaGreenMin,
                .defaultGammaGreenMax,
                .defaultGammaGreenValue,
                .defaultGammaBlueMin,
                .defaultGammaBlueMax,
                .defaultGammaBlueValue,
                .maxDDCBrightness,
                .maxDDCContrast,
                .maxDDCVolume,
                .lockedBrightness,
                .lockedContrast,
                .minContrast,
                .minBrightness,
                .maxContrast,
                .maxBrightness,
                .contrast,
                .brightness,
                .volume,
                .audioMuted,
                .power,
                .input,
                .hotkeyInput,
                .alwaysUseNetworkControl,
                .neverUseNetworkControl,
                .alwaysFallbackControl,
                .neverFallbackControl,
                .isSource,
                .brightnessOnInputChange,
                .contrastOnInputChange,
            ]
        }
    }

    enum AdaptiveModeKeys: String, CodingKey {
        case sensor
        case sync
        case location
        case manual
    }

    enum DisplayControlKeys: String, CodingKey {
        case network
        case coreDisplay
        case ddc
        case gamma
    }

    func encode(to encoder: Encoder) throws {
        try displayEncodingLock.aroundThrows {
            var container = encoder.container(keyedBy: CodingKeys.self)
            var userBrightnessContainer = container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .userBrightness)
            var userContrastContainer = container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .userContrast)
            var enabledControlsContainer = container.nestedContainer(keyedBy: DisplayControlKeys.self, forKey: .enabledControls)

            try container.encode(active, forKey: .active)
            try container.encode(adaptive, forKey: .adaptive)
            try container.encode(audioMuted, forKey: .audioMuted)
            try container.encode(brightness.uint8Value, forKey: .brightness)
            try container.encode(contrast.uint8Value, forKey: .contrast)
            try container.encode(edidName, forKey: .edidName)

            try container.encode(defaultGammaRedMin.floatValue, forKey: .defaultGammaRedMin)
            try container.encode(defaultGammaRedMax.floatValue, forKey: .defaultGammaRedMax)
            try container.encode(defaultGammaRedValue.floatValue, forKey: .defaultGammaRedValue)
            try container.encode(defaultGammaGreenMin.floatValue, forKey: .defaultGammaGreenMin)
            try container.encode(defaultGammaGreenMax.floatValue, forKey: .defaultGammaGreenMax)
            try container.encode(defaultGammaGreenValue.floatValue, forKey: .defaultGammaGreenValue)
            try container.encode(defaultGammaBlueMin.floatValue, forKey: .defaultGammaBlueMin)
            try container.encode(defaultGammaBlueMax.floatValue, forKey: .defaultGammaBlueMax)
            try container.encode(defaultGammaBlueValue.floatValue, forKey: .defaultGammaBlueValue)

            try container.encode(maxDDCBrightness.uint8Value, forKey: .maxDDCBrightness)
            try container.encode(maxDDCContrast.uint8Value, forKey: .maxDDCContrast)
            try container.encode(maxDDCVolume.uint8Value, forKey: .maxDDCVolume)

            try container.encode(id, forKey: .id)
            try container.encode(lockedBrightness, forKey: .lockedBrightness)
            try container.encode(lockedContrast, forKey: .lockedContrast)
            try container.encode(maxBrightness.uint8Value, forKey: .maxBrightness)
            try container.encode(maxContrast.uint8Value, forKey: .maxContrast)
            try container.encode(minBrightness.uint8Value, forKey: .minBrightness)
            try container.encode(minContrast.uint8Value, forKey: .minContrast)
            try container.encode(name, forKey: .name)
            try container.encode(responsiveDDC, forKey: .responsiveDDC)
            try container.encode(serial, forKey: .serial)
            try container.encode(volume.uint8Value, forKey: .volume)
            try container.encode(input.uint8Value, forKey: .input)
            try container.encode(hotkeyInput.uint8Value, forKey: .hotkeyInput)
            try container.encode(brightnessOnInputChange.uint8Value, forKey: .brightnessOnInputChange)
            try container.encode(contrastOnInputChange.uint8Value, forKey: .contrastOnInputChange)

            try userBrightnessContainer.encodeIfPresent(userBrightness[.sync], forKey: .sync)
            try userBrightnessContainer.encodeIfPresent(userBrightness[.sensor], forKey: .sensor)
            try userBrightnessContainer.encodeIfPresent(userBrightness[.location], forKey: .location)
            try userBrightnessContainer.encodeIfPresent(userBrightness[.manual], forKey: .manual)

            try userContrastContainer.encodeIfPresent(userContrast[.sync], forKey: .sync)
            try userContrastContainer.encodeIfPresent(userContrast[.sensor], forKey: .sensor)
            try userContrastContainer.encodeIfPresent(userContrast[.location], forKey: .location)
            try userContrastContainer.encodeIfPresent(userContrast[.manual], forKey: .manual)

            try enabledControlsContainer.encodeIfPresent(enabledControls[.network], forKey: .network)
            try enabledControlsContainer.encodeIfPresent(enabledControls[.coreDisplay], forKey: .coreDisplay)
            try enabledControlsContainer.encodeIfPresent(enabledControls[.ddc], forKey: .ddc)
            try enabledControlsContainer.encodeIfPresent(enabledControls[.gamma], forKey: .gamma)

            try container.encode(alwaysUseNetworkControl, forKey: .alwaysUseNetworkControl)
            try container.encode(neverUseNetworkControl, forKey: .neverUseNetworkControl)
            try container.encode(alwaysFallbackControl, forKey: .alwaysFallbackControl)
            try container.encode(neverFallbackControl, forKey: .neverFallbackControl)
            try container.encode(power, forKey: .power)
            try container.encode(isSource, forKey: .isSource)
        }
    }

    // MARK: Sentry

    func addSentryData() {
        SentrySDK.configureScope { [weak self] scope in
            guard let self = self, var dict = self.dictionary else { return }
            if let encoded = try? encoder.encode(ForgivingEncodable(self.infoDictionary)),
               let compressed = encoded.gzip()?.base64EncodedString()
            {
                dict["infoDictionary"] = compressed
            }
            if var armProps = self.armProps {
                armProps.removeValue(forKey: "TimingElements")
                armProps.removeValue(forKey: "ColorElements")
                if let encoded = try? encoder.encode(ForgivingEncodable(armProps)),
                   let compressed = encoded.gzip()?.base64EncodedString()
                {
                    dict["armProps"] = compressed
                }
            }
            if let deviceDescription = self.screen?.deviceDescription,
               let encoded = try? encoder.encode(ForgivingEncodable(deviceDescription)),
               let compressed = encoded.gzip()?.base64EncodedString()
            {
                dict["deviceDescription"] = compressed
            }
            #if arch(arm64)
                let avService = DDC.AVService(displayID: self.id)
                dict["avService"] = avService == nil ? "NONE" : CFCopyDescription(avService!) as String
            #else
                dict["i2cController"] = DDC.I2CController(displayID: self.id)
            #endif

            dict["hasNetworkControl"] = self.hasNetworkControl
            dict["hasI2C"] = self.hasI2C
            dict["hasDDC"] = self.hasDDC
            dict["activeAndResponsive"] = self.activeAndResponsive
            dict["responsiveDDC"] = self.responsiveDDC
            dict["gamma"] = [
                "redMin": self.redMin,
                "redMax": self.redMax,
                "redGamma": self.redGamma,
                "greenMin": self.greenMin,
                "greenMax": self.greenMax,
                "greenGamma": self.greenGamma,
                "blueMin": self.blueMin,
                "blueMax": self.blueMax,
                "blueGamma": self.blueGamma,
            ]
            scope.setExtra(value: dict, key: "display-\(self.serial)")
        }
    }

    // MARK: CoreDisplay Detection

    func isUltraFine() -> Bool {
        name.contains(ULTRAFINE_NAME) || edidName.contains(ULTRAFINE_NAME)
    }

    func isThunderbolt() -> Bool {
        name.contains(THUNDERBOLT_NAME) || edidName.contains(THUNDERBOLT_NAME)
    }

    func isLEDCinema() -> Bool {
        name.contains(LED_CINEMA_NAME) || edidName.contains(LED_CINEMA_NAME)
    }

    func isCinema() -> Bool {
        name == CINEMA_NAME || edidName == CINEMA_NAME || name == CINEMA_HD_NAME || edidName == CINEMA_HD_NAME
    }

    func isColorLCD() -> Bool {
        name.contains(COLOR_LCD_NAME) || edidName.contains(COLOR_LCD_NAME)
    }

    func isAppleDisplay() -> Bool {
        CachedDefaults[.useCoreDisplay] && (isUltraFine() || isThunderbolt() || isLEDCinema() || isCinema() || isAppleVendorID())
    }

    func isAppleVendorID() -> Bool {
        CGDisplayVendorNumber(id) == APPLE_DISPLAY_VENDOR_ID
    }

    func checkSlowWrite(elapsedNS: UInt64) {
        if !slowWrite, elapsedNS > MAX_SMOOTH_STEP_TIME_NS * 2 {
            slowWrite = true
        }
        if slowWrite, elapsedNS < MAX_SMOOTH_STEP_TIME_NS * 2 {
            slowWrite = false
        }
    }

    func smoothTransition(from currentValue: UInt8, to value: UInt8, adjust: @escaping ((UInt8) -> Void)) {
        var steps = abs(value.distance(to: currentValue))

        var step: Int
        let minVal: UInt8
        let maxVal: UInt8
        if value < currentValue {
            step = cap(-smoothStep, minVal: -steps, maxVal: -1)
            minVal = value
            maxVal = currentValue
        } else {
            step = cap(smoothStep, minVal: 1, maxVal: steps)
            minVal = currentValue
            maxVal = value
        }
        concurrentQueue.asyncAfter(deadline: DispatchTime.now(), flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let startTime = DispatchTime.now()
            var elapsedTime: UInt64
            var elapsedSeconds: Double
            var elapsedSecondsStr: String

            adjust((currentValue.i + step).u8)

            elapsedTime = DispatchTime.now().rawValue - startTime.rawValue
            elapsedSeconds = elapsedTime.d / 1_000_000_000.0
            elapsedSecondsStr = String(format: "%.3f", elapsedSeconds)
            log.debug("It took \(elapsedTime)ns (\(elapsedSecondsStr)s) to change brightness by \(step)")

            self.checkSlowWrite(elapsedNS: elapsedTime)

            steps = steps - abs(step)
            if steps <= 0 {
                adjust(value)
                return
            }

            self.smoothStep = cap((elapsedTime / MAX_SMOOTH_STEP_TIME_NS).i, minVal: 1, maxVal: 100)
            if value < currentValue {
                step = cap(-self.smoothStep, minVal: -steps, maxVal: -1)
            } else {
                step = cap(self.smoothStep, minVal: 1, maxVal: steps)
            }

            for newValue in stride(from: currentValue.i, through: value.i, by: step) {
                adjust(cap(newValue.u8, minVal: minVal, maxVal: maxVal))
            }
            adjust(value)

            elapsedTime = DispatchTime.now().rawValue - startTime.rawValue
            elapsedSeconds = elapsedTime.d / 1_000_000_000.0
            elapsedSecondsStr = String(format: "%.3f", elapsedSeconds)
            log.debug("It took \(elapsedTime)ns (\(elapsedSeconds)s) to change brightness from \(currentValue) to \(value) by \(step)")

            self.checkSlowWrite(elapsedNS: elapsedTime)
        }
    }

    func readapt<T: Equatable>(newValue: T?, oldValue: T?) {
        if let readaptListener = onReadapt {
            readaptListener()
        }
        if adaptive, displayController.adaptiveModeKey != .manual, let newVal = newValue, let oldVal = oldValue, newVal != oldVal {
            displayController.adaptBrightness(for: self, force: true)
        }
    }

    // MARK: Reading Functions

    func readAudioMuted() -> Bool? {
        control?.getMute()
    }

    func readVolume() -> UInt8? {
        control?.getVolume()
    }

    func readContrast() -> UInt8? {
        control?.getContrast()
    }

    func readInput() -> UInt8? {
        control?.getInput()?.rawValue
    }

    func readBrightness() -> UInt8? {
        control?.getBrightness()
    }

    func refreshBrightness() {
        guard !isUserAdjusting(), !sendingBrightness else { return }
        guard let newBrightness = readBrightness() else {
            log.warning("Can't read brightness for \(name)")
            return
        }

        guard !isUserAdjusting(), !sendingBrightness else { return }
        if newBrightness != brightness.uint8Value {
            log.info("Refreshing brightness: \(brightness.uint8Value) <> \(newBrightness)")

            guard displayController.adaptiveModeKey == .manual else {
                readapt(newValue: newBrightness, oldValue: brightness.uint8Value)
                return
            }

            withoutSmoothTransition {
                withoutDDC {
                    brightness = newBrightness.ns
                }
            }
        }
    }

    func refreshContrast() {
        guard !isUserAdjusting(), !sendingContrast else { return }
        guard let newContrast = readContrast() else {
            log.warning("Can't read contrast for \(name)")
            return
        }

        guard !isUserAdjusting(), !sendingContrast else { return }
        if newContrast != contrast.uint8Value {
            log.info("Refreshing contrast: \(contrast.uint8Value) <> \(newContrast)")

            guard displayController.adaptiveModeKey == .manual else {
                readapt(newValue: newContrast, oldValue: contrast.uint8Value)
                return
            }

            withoutSmoothTransition {
                withoutDDC {
                    contrast = newContrast.ns
                }
            }
        }
    }

    func refreshInput() {
        guard let newInput = readInput() else {
            log.warning("Can't read input for \(name)")
            return
        }
        if newInput != input.uint8Value {
            log.info("Refreshing input: \(input.uint8Value) <> \(newInput)")

            withoutSmoothTransition {
                withoutDDC {
                    input = newInput.ns
                }
            }
        }
    }

    func refreshVolume() {
        guard let newVolume = readVolume(), let newAudioMuted = readAudioMuted() else {
            log.warning("Can't read volume for \(name)")
            return
        }

        if newAudioMuted != audioMuted {
            log.info("Refreshing mute value: \(audioMuted) <> \(newAudioMuted)")
            audioMuted = newAudioMuted
        }
        if newVolume != volume.uint8Value {
            log.info("Refreshing volume: \(volume.uint8Value) <> \(newVolume)")

            withoutSmoothTransition {
                withoutDDC {
                    volume = newVolume.ns
                }
            }
        }
    }

    func refreshGamma() {
        guard !isForTesting else { return }

        CGGetDisplayTransferByFormula(2, &redMin, &redMax, &redGamma, &greenMin, &greenMax, &greenGamma, &blueMin, &blueMax, &blueGamma)
        if INITIAL_MIN_VALUES[id] == nil {
            INITIAL_MIN_VALUES[id] = Gamma(red: redMin, green: greenMin, blue: blueMin, contrast: minContrast.floatValue)
        }
        if INITIAL_MAX_VALUES[id] == nil {
            INITIAL_MAX_VALUES[id] = Gamma(red: redMax, green: greenMax, blue: blueMax, contrast: maxContrast.floatValue)
        }
        if INITIAL_GAMMA_VALUES[id] == nil {
            INITIAL_GAMMA_VALUES[id] = Gamma(red: redGamma, green: greenGamma, blue: blueGamma, contrast: contrast.floatValue)
        }
    }

    // MARK: Gamma

    func resetGamma() {
        guard !isForTesting else { return }
        // CGSetDisplayTransferByFormula(id, 0, 1, 1, 0, 1, 1, 0, 1, 1)
        CGSetDisplayTransferByFormula(
            id,
            defaultGammaRedMin.floatValue,
            defaultGammaRedMax.floatValue,
            defaultGammaRedValue.floatValue,
            defaultGammaGreenMin.floatValue,
            defaultGammaGreenMax.floatValue,
            defaultGammaGreenValue.floatValue,
            defaultGammaBlueMin.floatValue,
            defaultGammaBlueMax.floatValue,
            defaultGammaBlueValue.floatValue
        )
    }

    lazy var gammaLockPath = "/tmp/lunar-gamma-lock-\(serial)"
    lazy var gammaDistributedLock: NSDistributedLock? = NSDistributedLock(path: gammaLockPath)

    @discardableResult func gammaLock() -> Bool {
        log.verbose("Locking gamma", context: context)
        return gammaDistributedLock?.try() ?? false
    }

    func gammaUnlock() {
        log.verbose("Unlocking gamma", context: context)
        gammaDistributedLock?.unlock()
    }

    func computeGamma(brightness: UInt8? = nil, contrast: UInt8? = nil) -> Gamma {
        let rawBrightness = powf(Float(brightness ?? self.brightness.uint8Value) / 100.0, 0.3)
        let redGamma = CGGammaValue(mapNumber(
            rawBrightness,
            fromLow: 0.0, fromHigh: 1.0,
            toLow: 0.3, toHigh: defaultGammaRedValue.floatValue
        ))
        let greenGamma = CGGammaValue(mapNumber(
            rawBrightness,
            fromLow: 0.0, fromHigh: 1.0,
            toLow: 0.3, toHigh: defaultGammaGreenValue.floatValue
        ))
        let blueGamma = CGGammaValue(mapNumber(
            rawBrightness,
            fromLow: 0.0, fromHigh: 1.0,
            toLow: 0.3, toHigh: defaultGammaBlueValue.floatValue
        ))

        let contrast = CGGammaValue(mapNumber(
            powf(Float(contrast ?? self.contrast.uint8Value) / 100.0, 0.3),
            fromLow: 0, fromHigh: 1.0,
            toLow: -0.2, toHigh: 0.2
        ))

        return Gamma(red: redGamma, green: greenGamma, blue: blueGamma, contrast: contrast)
    }

    var lastConnectionTime = Date()

    func setGamma(brightness: UInt8? = nil, contrast: UInt8? = nil, oldBrightness: UInt8? = nil, oldContrast: UInt8? = nil) {
        #if DEBUG
            guard !isForTesting else { return }
        #endif

        guard enabledControls[.gamma] ?? false, timeSince(lastConnectionTime) > 5 else { return }
        gammaLock()

        let newGamma = computeGamma(brightness: brightness, contrast: contrast)
        log.debug("gamma contrast: \(newGamma.contrast)")
        log.debug("red: \(newGamma.red)")
        log.debug("green: \(newGamma.green)")
        log.debug("blue: \(newGamma.blue)")
        let gammaSemaphore = DispatchSemaphore(value: 0, name: "gammaSemaphore")
        let id = self.id

        showOperationInProgress(screen: screen)

        if oldBrightness != nil || oldContrast != nil {
            asyncNow(runLoopQueue: realtimeQueue) { [weak self] in
                guard let self = self else {
                    gammaSemaphore.signal()
                    return
                }
                Thread.sleep(forTimeInterval: 0.005)

                let redGamma = self.defaultGammaRedValue.floatValue
                let greenGamma = self.defaultGammaGreenValue.floatValue
                let blueGamma = self.defaultGammaBlueValue.floatValue

                let oldGamma = self.computeGamma(brightness: oldBrightness, contrast: oldContrast)
                let maxDiff = max(
                    abs(newGamma.red - oldGamma.red), abs(newGamma.green - oldGamma.green),
                    abs(newGamma.blue - oldGamma.blue), abs(newGamma.contrast - oldGamma.contrast)
                )
                for gamma in oldGamma.stride(to: newGamma, samples: (maxDiff * 100).intround) {
                    CGSetDisplayTransferByFormula(
                        id,
                        self.defaultGammaRedMin.floatValue,
                        gamma.red,
                        redGamma + gamma.contrast,
                        self.defaultGammaGreenMin.floatValue,
                        gamma.green,
                        greenGamma + gamma.contrast,
                        self.defaultGammaBlueMin.floatValue,
                        gamma.blue,
                        blueGamma + gamma.contrast
                    )
                    Thread.sleep(forTimeInterval: 0.01)
                }
                gammaSemaphore.signal()
            }
        }
        asyncNow(runLoopQueue: lowprioQueue) { [weak self] in
            guard let self = self else { return }
            if oldBrightness != nil || oldContrast != nil {
                gammaSemaphore.wait(for: 1.8)
            }

            let redGamma = self.defaultGammaRedValue.floatValue
            let greenGamma = self.defaultGammaGreenValue.floatValue
            let blueGamma = self.defaultGammaBlueValue.floatValue

            CGSetDisplayTransferByFormula(
                id,
                self.defaultGammaRedMin.floatValue,
                newGamma.red,
                redGamma + newGamma.contrast,
                self.defaultGammaGreenMin.floatValue,
                newGamma.green,
                greenGamma + newGamma.contrast,
                self.defaultGammaBlueMin.floatValue,
                newGamma.blue,
                blueGamma + newGamma.contrast
            )
            gammaSemaphore.signal()
        }
    }

    func reset() {
        userContrast[displayController.adaptiveModeKey]?.removeAll()
        userBrightness[displayController.adaptiveModeKey]?.removeAll()

        alwaysFallbackControl = false
        neverFallbackControl = false
        alwaysUseNetworkControl = false
        neverUseNetworkControl = false
        enabledControls = [
            .network: true,
            .coreDisplay: true,
            .ddc: true,
            .gamma: true,
        ]

        save()

        _ = control.reset()
        readapt(newValue: false, oldValue: true)
    }

    // MARK: "With/out" functions

    @inline(__always) func withoutDDC(_ block: () -> Void) {
        DDC.queue.sync {
            DDC.apply = false
            block()
            DDC.apply = true
        }
    }

    @inline(__always) func withForce(_ force: Bool = true, _ block: () -> Void) {
        self.force = force
        block()
        self.force = false
    }

    @inline(__always) func withoutSmoothTransition(_ block: () -> Void) {
        withSmoothTransition(false, block)
    }

    @inline(__always) func withSmoothTransition(_ active: Bool = true, _ block: () -> Void) {
        if CachedDefaults[.smoothTransition] == active {
            block()
            return
        }

        CachedDefaults[.smoothTransition] = active
        block()
        CachedDefaults[.smoothTransition] = !active
    }

    // MARK: Computing Values

    func getMinMaxFactor(
        type: ValueType,
        factor: Double? = nil,
        minVal: Double? = nil,
        maxVal: Double? = nil
    ) -> (Double, Double, Double) {
        let minValue: Double
        let maxValue: Double
        if type == .brightness {
            maxValue = maxVal ?? maxBrightness.doubleValue
            minValue = minVal ?? minBrightness.doubleValue
        } else {
            maxValue = maxVal ?? maxContrast.doubleValue
            minValue = minVal ?? minContrast.doubleValue
        }

        return (minValue, maxValue, factor ?? 1.0)
    }

    func computeValue(
        from percent: Double,
        type: ValueType,
        factor: Double? = nil,
        appOffset: Int = 0,
        minVal: Double? = nil,
        maxVal: Double? = nil
    ) -> Double {
        let (minValue, maxValue, factor) = getMinMaxFactor(type: type, factor: factor, minVal: minVal, maxVal: maxVal)

        var value: Double
        if percent == 1.0 {
            value = maxValue
        } else if percent == 0.0 {
            value = minValue
        } else {
            value = pow((percent * (maxValue - minValue) + minValue) / 100.0, factor) * 100.0
            value = cap(value, minVal: minValue, maxVal: maxValue)
        }

        if appOffset > 0 {
            value = cap(value + appOffset.d, minVal: minValue, maxVal: maxValue)
        }
        return value.rounded()
    }

    func computeSIMDValue(
        from percent: [Double],
        type: ValueType,
        factor: Double? = nil,
        appOffset: Int = 0,
        minVal: Double? = nil,
        maxVal: Double? = nil
    ) -> [Double] {
        let (minValue, maxValue, factor) = getMinMaxFactor(type: type, factor: factor, minVal: minVal, maxVal: maxVal)

        var value = (percent * (maxValue - minValue) + minValue)
        value /= 100.0
        value = pow(value, factor)

        value = (value * 100.0 + appOffset.d)
        return value.map {
            b in cap(b, minVal: minValue, maxVal: maxValue)
        }
    }

    // MARK: User Data Points

    static func insertDataPoint(values: inout [Int: Int], featureValue: Int, targetValue: Int, logValue: Bool = true) {
        for (x, y) in values {
            if (x < featureValue && y > targetValue) || (x > featureValue && y < targetValue) {
                if logValue {
                    log.debug("Removing data point \(x) => \(y)")
                }
                values.removeValue(forKey: x)
            }
        }
        if logValue {
            log.debug("Adding data point \(featureValue) => \(targetValue)")
        }
        values[featureValue] = targetValue
    }

    func insertBrightnessUserDataPoint(_ featureValue: Int, _ targetValue: Int, modeKey: AdaptiveModeKey) {
        brightnessDataPointInsertionTask?.cancel()
        if userBrightness[modeKey] == nil {
            userBrightness[modeKey] = [:]
        }
        let targetValue = mapNumber(
            targetValue.f,
            fromLow: minBrightness.floatValue,
            fromHigh: maxBrightness.floatValue,
            toLow: MIN_BRIGHTNESS.f,
            toHigh: MAX_BRIGHTNESS.f
        ).i

        brightnessDataPointInsertionTask = DispatchWorkItem(name: "brightnessDataPointInsertionTask") { [weak self] in
            while let self = self, self.sendingBrightness {
                self.sentBrightnessCondition.wait(until: Date().addingTimeInterval(5.seconds.timeInterval))
            }

            guard let self = self else { return }
            Display.insertDataPoint(values: &self.userBrightness[modeKey]!, featureValue: featureValue, targetValue: targetValue)
            self.save()
            self.brightnessDataPointInsertionTask = nil
        }
        serialAsyncAfter(ms: 5000, brightnessDataPointInsertionTask!)

        var userValues = userBrightness[modeKey]!
        Display.insertDataPoint(values: &userValues, featureValue: featureValue, targetValue: targetValue, logValue: false)
        NotificationCenter.default.post(name: brightnessDataPointInserted, object: self, userInfo: ["values": userValues])
    }

    func insertContrastUserDataPoint(_ featureValue: Int, _ targetValue: Int, modeKey: AdaptiveModeKey) {
        contrastDataPointInsertionTask?.cancel()
        if userContrast[modeKey] == nil {
            userContrast[modeKey] = [:]
        }
        let targetValue = mapNumber(
            targetValue.f,
            fromLow: minContrast.floatValue,
            fromHigh: maxContrast.floatValue,
            toLow: MIN_CONTRAST.f,
            toHigh: MAX_CONTRAST.f
        ).i

        contrastDataPointInsertionTask = DispatchWorkItem(name: "contrastDataPointInsertionTask") { [weak self] in
            while let self = self, self.sendingContrast {
                self.sentContrastCondition.wait(until: Date().addingTimeInterval(5.seconds.timeInterval))
            }

            guard let self = self else { return }
            Display.insertDataPoint(values: &self.userContrast[modeKey]!, featureValue: featureValue, targetValue: targetValue)
            self.save()
            self.contrastDataPointInsertionTask = nil
        }
        serialAsyncAfter(ms: 5000, contrastDataPointInsertionTask!)

        var userValues = userContrast[modeKey]!
        Display.insertDataPoint(values: &userValues, featureValue: featureValue, targetValue: targetValue, logValue: false)
        NotificationCenter.default.post(name: contrastDataPointInserted, object: self, userInfo: ["values": userValues])
    }

    func isUserAdjusting() -> Bool {
        brightnessDataPointInsertionTask != nil || contrastDataPointInsertionTask != nil
    }
}
