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
import Magnet
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

let DEFAULT_SENSOR_BRIGHTNESS_CURVE_FACTOR = 0.5
let DEFAULT_SYNC_BRIGHTNESS_CURVE_FACTOR = 0.5
let DEFAULT_LOCATION_BRIGHTNESS_CURVE_FACTOR = 1.0
let DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR = 1.0

let DEFAULT_SENSOR_CONTRAST_CURVE_FACTOR = 0.2
let DEFAULT_SYNC_CONTRAST_CURVE_FACTOR = 2.0
let DEFAULT_LOCATION_CONTRAST_CURVE_FACTOR = 0.8
let DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR = 1.0

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

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(serial)
        return hasher.finalize()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Display else {
            return false
        }
        return serial == other.serial
    }

    lazy var _hotkeyPopover: NSPopover? = POPOVERS[serial] ?? nil
    lazy var hotkeyPopoverController: HotkeyPopoverController? = {
        mainThread {
            guard let popover = _hotkeyPopover else {
                _hotkeyPopover = NSPopover()
                if let popover = _hotkeyPopover, popover.contentViewController == nil, let stb = NSStoryboard.main,
                   let controller = stb.instantiateController(
                       withIdentifier: NSStoryboard.SceneIdentifier("HotkeyPopoverController")
                   ) as? HotkeyPopoverController
                {
                    POPOVERS[serial] = _hotkeyPopover
                    popover.contentViewController = controller
                    popover.contentViewController!.loadView()
                    popover.appearance = NSAppearance(named: .vibrantDark)
                }

                return _hotkeyPopover?.contentViewController as? HotkeyPopoverController
            }
            return popover.contentViewController as? HotkeyPopoverController
        }
    }()

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

    @Published @objc dynamic var applyGamma: Bool {
        didSet {
            save()
            readapt(newValue: applyGamma, oldValue: oldValue)
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
            } else if applyGamma || gammaChanged {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaRedMax: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else if applyGamma || gammaChanged {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaRedValue: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else if applyGamma || gammaChanged {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaGreenMin: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else if applyGamma || gammaChanged {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaGreenMax: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else if applyGamma || gammaChanged {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaGreenValue: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else if applyGamma || gammaChanged {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaBlueMin: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else if applyGamma || gammaChanged {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaBlueMax: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else if applyGamma || gammaChanged {
                resetGamma()
            }
        }
    }

    @Published @objc dynamic var defaultGammaBlueValue: NSNumber {
        didSet {
            save()
            if control is GammaControl {
                setGamma()
            } else if applyGamma || gammaChanged {
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

            guard DDC.apply, !lockedBrightness, force || brightness != oldValue else { return }
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
            if DDC.applyLimits, maxDDCBrightness != 100, !(control is GammaControl) {
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

            log.verbose("Set BRIGHTNESS to \(brightness) (old: \(oldBrightness))", context: context)
            let startTime = DispatchTime.now()

            if let control = control, !control.setBrightness(brightness, oldValue: oldBrightness) {
                log.warning(
                    "Error writing brightness using \(control.str)",
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

            guard DDC.apply, !lockedContrast, force || contrast != oldValue else { return }
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
            if DDC.applyLimits, maxDDCContrast != 100, !(control is GammaControl) {
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

            log.verbose("Set CONTRAST to \(contrast) (old: \(oldContrast))", context: context)
            let startTime = DispatchTime.now()

            if let control = control, !control.setContrast(contrast, oldValue: oldContrast) {
                log.warning(
                    "Error writing contrast using \(control.str)",
                    context: context
                )
            }

            let elapsedTime: UInt64 = DispatchTime.now().rawValue - startTime.rawValue
            checkSlowWrite(elapsedNS: elapsedTime)
        }
    }

    lazy var lastVolume: NSNumber = volume

    @Published @objc dynamic var volume: NSNumber {
        didSet {
            if oldValue.uint8Value > 0 {
                lastVolume = oldValue
            }

            save()

            guard !isForTesting else { return }

            var volume = self.volume.uint8Value
            if DDC.applyLimits, maxDDCVolume != 100, !(control is GammaControl) {
                volume = mapNumber(volume.d, fromLow: 0, fromHigh: 100, toLow: 0, toHigh: maxDDCVolume.doubleValue).rounded().u8
            }

            if let control = control, !control.setVolume(volume) {
                log.warning(
                    "Error writing volume using \(control.str)",
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
            if let control = control, !control.setInput(input) {
                log.warning(
                    "Error writing input using \(control.str)",
                    context: context
                )
            }
        }
    }

    @Published @objc dynamic var hotkeyInput1: NSNumber { didSet { save() } }
    @Published @objc dynamic var hotkeyInput2: NSNumber { didSet { save() } }
    @Published @objc dynamic var hotkeyInput3: NSNumber { didSet { save() } }

    @Published @objc dynamic var brightnessOnInputChange1: NSNumber { didSet { save() } }
    @Published @objc dynamic var contrastOnInputChange1: NSNumber { didSet { save() } }
    @Published @objc dynamic var brightnessOnInputChange2: NSNumber { didSet { save() } }
    @Published @objc dynamic var contrastOnInputChange2: NSNumber { didSet { save() } }
    @Published @objc dynamic var brightnessOnInputChange3: NSNumber { didSet { save() } }
    @Published @objc dynamic var contrastOnInputChange3: NSNumber { didSet { save() } }

    @Published @objc dynamic var audioMuted: Bool {
        didSet {
            save()

            guard !isForTesting else { return }
            if let control = control, !control.setMute(audioMuted) {
                log.warning(
                    "Error writing muted audio using \(control.str)",
                    context: context
                )
            }

            guard CachedDefaults[.muteVolumeZero] else { return }
            volume = audioMuted ? 0 : lastVolume
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
                if let controller = hotkeyPopoverController {
                    #if DEBUG
                        log.info("Display \(description) is now active, enabling hotkeys")
                    #endif
                    // if controller.display == nil || controller.display!.serial != serial {
                    controller.setup(from: self)
                    // }
                    if let h = controller.hotkey1, h.isEnabled { h.register() }
                    if let h = controller.hotkey2, h.isEnabled { h.register() }
                    if let h = controller.hotkey3, h.isEnabled { h.register() }
                }
            } else if let controller = hotkeyPopoverController {
                #if DEBUG
                    log.info("Display \(description) is now inactive, disabling hotkeys")
                #endif

                controller.hotkey1?.unregister()
                controller.hotkey2?.unregister()
                controller.hotkey3?.unregister()
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

    @Published @objc dynamic var isSource: Bool {
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

    var brightnessCurveFactors: [AdaptiveModeKey: Double] = [
        .sensor: DEFAULT_SENSOR_BRIGHTNESS_CURVE_FACTOR,
        .sync: DEFAULT_SYNC_BRIGHTNESS_CURVE_FACTOR,
        .location: DEFAULT_LOCATION_BRIGHTNESS_CURVE_FACTOR,
        .manual: DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR,
    ]

    var contrastCurveFactors: [AdaptiveModeKey: Double] = [
        .sensor: DEFAULT_SENSOR_CONTRAST_CURVE_FACTOR,
        .sync: DEFAULT_SYNC_CONTRAST_CURVE_FACTOR,
        .location: DEFAULT_LOCATION_CONTRAST_CURVE_FACTOR,
        .manual: DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR,
    ]

    @inline(__always) var brightnessCurveFactor: Double {
        get { brightnessCurveFactors[displayController.adaptiveModeKey] ?? 1.0 }
        set {
            let oldValue = brightnessCurveFactors[displayController.adaptiveModeKey]
            brightnessCurveFactors[displayController.adaptiveModeKey] = newValue
            readapt(newValue: newValue, oldValue: oldValue)
        }
    }

    @inline(__always) var contrastCurveFactor: Double {
        get { contrastCurveFactors[displayController.adaptiveModeKey] ?? 1.0 }
        set {
            let oldValue = contrastCurveFactors[displayController.adaptiveModeKey]
            contrastCurveFactors[displayController.adaptiveModeKey] = newValue
            readapt(newValue: newValue, oldValue: oldValue)
        }
    }

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
    var macMiniHDMI = false

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
    @AtomicLock var control: Control? = nil {
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
            "applyGamma": applyGamma,
        ]
    }

    func getBestControl() -> Control {
        let networkControl = NetworkControl(display: self)
        let coreDisplayControl = CoreDisplayControl(display: self)
        let ddcControl = DDCControl(display: self)
        let gammaControl = GammaControl(display: self)

        if coreDisplayControl.isAvailable() {
            if applyGamma || gammaChanged {
                resetGamma()
                coreDisplayControl.reapply()
            }
            return coreDisplayControl
        }
        if ddcControl.isAvailable() {
            if applyGamma || gammaChanged {
                resetGamma()
                ddcControl.reapply()
            }
            return ddcControl
        }
        if networkControl.isAvailable() {
            if applyGamma || gammaChanged {
                resetGamma()
                networkControl.reapply()
            }
            return networkControl
        }

        return gammaControl
    }

    func getBestAlternativeControlForCoreDisplay() -> Control? {
        let networkControl = NetworkControl(display: self)
        let ddcControl = DDCControl(display: self)

        if ddcControl.isAvailable() {
            return ddcControl
        }
        if networkControl.isAvailable() {
            return networkControl
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
        let brightnessCurveFactorsContainer = try container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .brightnessCurveFactors)
        let contrastCurveFactorsContainer = try container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .contrastCurveFactors)

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
        applyGamma = try container.decodeIfPresent(Bool.self, forKey: .applyGamma) ?? false
        input = (try container.decode(UInt8.self, forKey: .input)).ns

        hotkeyInput1 = try (
            (try container.decodeIfPresent(UInt8.self, forKey: .hotkeyInput1))?
                .ns ?? (try container.decodeIfPresent(UInt8.self, forKey: .hotkeyInput))?.ns ?? InputSource.unknown.rawValue.ns
        )
        hotkeyInput2 = (try container.decodeIfPresent(UInt8.self, forKey: .hotkeyInput2))?.ns ?? InputSource.unknown.rawValue.ns
        hotkeyInput3 = (try container.decodeIfPresent(UInt8.self, forKey: .hotkeyInput3))?.ns ?? InputSource.unknown.rawValue.ns

        brightnessOnInputChange1 = (
            try (try container.decodeIfPresent(UInt8.self, forKey: .brightnessOnInputChange1))?
                .ns ?? (try container.decodeIfPresent(UInt8.self, forKey: .brightnessOnInputChange))?.ns ?? 100.ns
        )
        brightnessOnInputChange2 = (try container.decodeIfPresent(UInt8.self, forKey: .brightnessOnInputChange2))?.ns ?? 100.ns
        brightnessOnInputChange3 = (try container.decodeIfPresent(UInt8.self, forKey: .brightnessOnInputChange3))?.ns ?? 100.ns

        contrastOnInputChange1 = try (
            (try container.decodeIfPresent(UInt8.self, forKey: .contrastOnInputChange1))?
                .ns ?? (try container.decodeIfPresent(UInt8.self, forKey: .contrastOnInputChange))?.ns ?? 75.ns
        )
        contrastOnInputChange2 = (try container.decodeIfPresent(UInt8.self, forKey: .contrastOnInputChange2))?.ns ?? 75.ns
        contrastOnInputChange3 = (try container.decodeIfPresent(UInt8.self, forKey: .contrastOnInputChange3))?.ns ?? 75.ns

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

        if let sensorFactor = try brightnessCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .sensor) {
            brightnessCurveFactors[.sensor] = sensorFactor > 0 ? sensorFactor : DEFAULT_SENSOR_BRIGHTNESS_CURVE_FACTOR
        }
        if let syncFactor = try brightnessCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .sync) {
            brightnessCurveFactors[.sync] = syncFactor > 0 ? syncFactor : DEFAULT_SYNC_BRIGHTNESS_CURVE_FACTOR
        }
        if let locationFactor = try brightnessCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .location) {
            brightnessCurveFactors[.location] = locationFactor > 0 ? locationFactor : DEFAULT_LOCATION_BRIGHTNESS_CURVE_FACTOR
        }
        if let manualFactor = try brightnessCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .manual) {
            brightnessCurveFactors[.manual] = manualFactor > 0 ? manualFactor : DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR
        }

        if let sensorFactor = try contrastCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .sensor) {
            contrastCurveFactors[.sensor] = sensorFactor > 0 ? sensorFactor : DEFAULT_SENSOR_CONTRAST_CURVE_FACTOR
        }
        if let syncFactor = try contrastCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .sync) {
            contrastCurveFactors[.sync] = syncFactor > 0 ? syncFactor : DEFAULT_SYNC_CONTRAST_CURVE_FACTOR
        }
        if let locationFactor = try contrastCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .location) {
            contrastCurveFactors[.location] = locationFactor > 0 ? locationFactor : DEFAULT_LOCATION_CONTRAST_CURVE_FACTOR
        }
        if let manualFactor = try contrastCurveFactorsContainer.decodeIfPresent(Double.self, forKey: .manual) {
            contrastCurveFactors[.manual] = manualFactor > 0 ? manualFactor : DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR
        }

        super.init()

        if let dict = displayInfoDictionary(id) {
            infoDictionary = dict
        }

        setupHotkeys()
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
        guard let ddcEnabled = enabledControls[.ddc], ddcEnabled else { return }

        #if DEBUG
            #if arch(arm64)
                // avService = (id == TEST_DISPLAY_ID) ? (1 as IOAVService) : DDC.AVService(displayID: id, display: self)
                hasI2C = (id == TEST_DISPLAY_ID || id == TEST_DISPLAY_PERSISTENT_ID || id == TEST_DISPLAY_PERSISTENT2_ID) ? true : DDC
                    .hasAVService(
                        displayID: id,
                        display: self,
                        ignoreCache: true
                    )
            #else
                // i2cController = (id == TEST_DISPLAY_ID) ? 1 : DDC.I2CController(displayID: id)
                hasI2C = (id == TEST_DISPLAY_ID || id == TEST_DISPLAY_PERSISTENT_ID || id == TEST_DISPLAY_PERSISTENT2_ID) ? true : DDC
                    .hasI2CController(
                        displayID: id,
                        ignoreCache: true
                    )
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
        asyncEvery(1.seconds, uniqueTaskKey: taskKey, runs: 15) { [weak self] _ in
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
        hotkeyInput1: UInt8 = InputSource.unknown.rawValue,
        hotkeyInput2: UInt8 = InputSource.unknown.rawValue,
        hotkeyInput3: UInt8 = InputSource.unknown.rawValue,
        userBrightness: [AdaptiveModeKey: [Int: Int]]? = nil,
        userContrast: [AdaptiveModeKey: [Int: Int]]? = nil,
        alwaysUseNetworkControl: Bool = false,
        neverUseNetworkControl: Bool = false,
        alwaysFallbackControl: Bool = false,
        neverFallbackControl: Bool = false,
        enabledControls: [DisplayControl: Bool]? = nil,
        brightnessOnInputChange1: UInt8 = 100,
        brightnessOnInputChange2: UInt8 = 100,
        brightnessOnInputChange3: UInt8 = 100,
        contrastOnInputChange1: UInt8 = 75,
        contrastOnInputChange2: UInt8 = 75,
        contrastOnInputChange3: UInt8 = 75,
        defaultGammaRedMin: Float = 0.0,
        defaultGammaRedMax: Float = 1.0,
        defaultGammaRedValue: Float = 1.0,
        defaultGammaGreenMin: Float = 0.0,
        defaultGammaGreenMax: Float = 1.0,
        defaultGammaGreenValue: Float = 1.0,
        defaultGammaBlueMin: Float = 0.0,
        defaultGammaBlueMax: Float = 1.0,
        defaultGammaBlueValue: Float = 1.0,
        isSource: Bool = false,
        applyGamma: Bool = false
    ) {
        _id = id
        self.active = active
        activeAndResponsive = active || id != GENERIC_DISPLAY_ID
        self.adaptive = adaptive

        self.isSource = isSource
        self.applyGamma = applyGamma

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

        self.hotkeyInput1 = hotkeyInput1.ns
        self.hotkeyInput2 = hotkeyInput2.ns
        self.hotkeyInput3 = hotkeyInput3.ns

        self.alwaysUseNetworkControl = alwaysUseNetworkControl
        self.neverUseNetworkControl = neverUseNetworkControl
        self.alwaysFallbackControl = alwaysFallbackControl
        self.neverFallbackControl = neverFallbackControl

        self.brightnessOnInputChange1 = brightnessOnInputChange1.ns
        self.brightnessOnInputChange2 = brightnessOnInputChange2.ns
        self.brightnessOnInputChange3 = brightnessOnInputChange3.ns
        self.contrastOnInputChange1 = contrastOnInputChange1.ns
        self.contrastOnInputChange2 = contrastOnInputChange2.ns
        self.contrastOnInputChange3 = contrastOnInputChange3.ns

        if let enabledControls = enabledControls {
            self.enabledControls = enabledControls
        }
        if let userBrightness = userBrightness {
            self.userBrightness = userBrightness
        }
        if let userContrast = userContrast {
            self.userContrast = userContrast
        }

        edidName = Self.printableName(id)
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
        setupHotkeys()
    }

    func setupHotkeys() {
        #if DEBUG
            log.info("Trying to setup hotkeys for \(description)")
        #endif
        guard active else { return }

        if let controller = hotkeyPopoverController {
            controller.setup(from: self)
            log.info("Initialized hotkeyPopoverController for \(description)")
        } else {
            log.info("Error initializing hotkeyPopoverController for \(description)")
        }
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
            hotkeyInput1: (config["hotkeyInput1"] as? UInt8) ?? (config["hotkeyInput"] as? UInt8) ?? InputSource.unknown.rawValue,
            hotkeyInput2: (config["hotkeyInput2"] as? UInt8) ?? InputSource.unknown.rawValue,
            hotkeyInput3: (config["hotkeyInput3"] as? UInt8) ?? InputSource.unknown.rawValue,
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
            brightnessOnInputChange1: (config["brightnessOnInputChange1"] as? UInt8) ?? (config["brightnessOnInputChange"] as? UInt8) ??
                100,
            brightnessOnInputChange2: (config["brightnessOnInputChange2"] as? UInt8) ?? 100,
            brightnessOnInputChange3: (config["brightnessOnInputChange3"] as? UInt8) ?? 100,
            contrastOnInputChange1: (config["contrastOnInputChange1"] as? UInt8) ?? (config["contrastOnInputChange"] as? UInt8) ?? 75,
            contrastOnInputChange2: (config["contrastOnInputChange2"] as? UInt8) ?? 75,
            contrastOnInputChange3: (config["contrastOnInputChange3"] as? UInt8) ?? 75,
            defaultGammaRedMin: (config["defaultGammaRedMin"] as? Float) ?? 0.0,
            defaultGammaRedMax: (config["defaultGammaRedMax"] as? Float) ?? 1.0,
            defaultGammaRedValue: (config["defaultGammaRedValue"] as? Float) ?? 1.0,
            defaultGammaGreenMin: (config["defaultGammaGreenMin"] as? Float) ?? 0.0,
            defaultGammaGreenMax: (config["defaultGammaGreenMax"] as? Float) ?? 1.0,
            defaultGammaGreenValue: (config["defaultGammaGreenValue"] as? Float) ?? 1.0,
            defaultGammaBlueMin: (config["defaultGammaBlueMin"] as? Float) ?? 0.0,
            defaultGammaBlueMax: (config["defaultGammaBlueMax"] as? Float) ?? 1.0,
            defaultGammaBlueValue: (config["defaultGammaBlueValue"] as? Float) ?? 1.0,
            isSource: (config["isSource"] as? Bool) ?? false,
            applyGamma: (config["applyGamma"] as? Bool) ?? false
        )
    }

    func resetDefaultGamma() {
        defaultGammaRedMin = 0.0
        defaultGammaRedMax = 1.0
        defaultGammaRedValue = 1.0
        defaultGammaGreenMin = 0.0
        defaultGammaGreenMax = 1.0
        defaultGammaGreenValue = 1.0
        defaultGammaBlueMin = 0.0
        defaultGammaBlueMax = 1.0
        defaultGammaBlueValue = 1.0
    }

    func resetBrightnessCurveFactor(mode: AdaptiveModeKey? = nil) {
        let mode = mode ?? displayController.adaptiveModeKey
        switch mode {
        case .sensor:
            brightnessCurveFactors[mode] = DEFAULT_SENSOR_BRIGHTNESS_CURVE_FACTOR
        case .sync:
            brightnessCurveFactors[mode] = DEFAULT_SYNC_BRIGHTNESS_CURVE_FACTOR
        case .location:
            brightnessCurveFactors[mode] = DEFAULT_LOCATION_BRIGHTNESS_CURVE_FACTOR
        case .manual:
            brightnessCurveFactors[mode] = DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR
        }
    }

    func resetContrastCurveFactor(mode: AdaptiveModeKey? = nil) {
        let mode = mode ?? displayController.adaptiveModeKey
        switch mode {
        case .sensor:
            contrastCurveFactors[mode] = DEFAULT_SENSOR_CONTRAST_CURVE_FACTOR
        case .sync:
            contrastCurveFactors[mode] = DEFAULT_SYNC_CONTRAST_CURVE_FACTOR
        case .location:
            contrastCurveFactors[mode] = DEFAULT_LOCATION_CONTRAST_CURVE_FACTOR
        case .manual:
            contrastCurveFactors[mode] = DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR
        }
    }

    func save(now: Bool = false) {
        if now {
            DataStore.storeDisplay(display: self, now: now)
            return
        }
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
        case hotkeyInput1
        case hotkeyInput2
        case hotkeyInput3
        case userBrightness
        case userContrast
        case alwaysUseNetworkControl
        case neverUseNetworkControl
        case alwaysFallbackControl
        case neverFallbackControl
        case enabledControls
        case brightnessCurveFactors
        case contrastCurveFactors
        case activeAndResponsive
        case hasDDC
        case hasI2C
        case hasNetworkControl
        case sendingBrightness
        case sendingContrast
        case sendingInput
        case sendingVolume
        case isSource
        case applyGamma
        case brightnessOnInputChange
        case brightnessOnInputChange1
        case brightnessOnInputChange2
        case brightnessOnInputChange3
        case contrastOnInputChange
        case contrastOnInputChange1
        case contrastOnInputChange2
        case contrastOnInputChange3

        var isHidden: Bool {
            Self.hidden.contains(self)
        }

        static var bool: Set<CodingKeys> = [
            .adaptive,
            .lockedBrightness,
            .lockedContrast,
            .audioMuted,
            .power,
            .alwaysUseNetworkControl,
            .neverUseNetworkControl,
            .alwaysFallbackControl,
            .neverFallbackControl,
            .isSource,
            .applyGamma,
        ]

        static var hidden: Set<CodingKeys> = [
            .hotkeyInput,
            .brightnessOnInputChange,
            .contrastOnInputChange,
        ]

        static var settable: Set<CodingKeys> = [
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
            .hotkeyInput1,
            .hotkeyInput2,
            .hotkeyInput3,
            .alwaysUseNetworkControl,
            .neverUseNetworkControl,
            .alwaysFallbackControl,
            .neverFallbackControl,
            .isSource,
            .applyGamma,
            .brightnessOnInputChange1,
            .brightnessOnInputChange2,
            .brightnessOnInputChange3,
            .contrastOnInputChange1,
            .contrastOnInputChange2,
            .contrastOnInputChange3,
        ]
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
        try displayEncodingLock.aroundThrows(ignoreMainThread: true) {
            var container = encoder.container(keyedBy: CodingKeys.self)
            var userBrightnessContainer = container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .userBrightness)
            var userContrastContainer = container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .userContrast)
            var enabledControlsContainer = container.nestedContainer(keyedBy: DisplayControlKeys.self, forKey: .enabledControls)
            var brightnessCurveFactorsContainer = container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .brightnessCurveFactors)
            var contrastCurveFactorsContainer = container.nestedContainer(keyedBy: AdaptiveModeKeys.self, forKey: .contrastCurveFactors)

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

            try container.encode(hotkeyInput1.uint8Value, forKey: .hotkeyInput1)
            try container.encode(hotkeyInput2.uint8Value, forKey: .hotkeyInput2)
            try container.encode(hotkeyInput3.uint8Value, forKey: .hotkeyInput3)

            try container.encode(brightnessOnInputChange1.uint8Value, forKey: .brightnessOnInputChange1)
            try container.encode(brightnessOnInputChange2.uint8Value, forKey: .brightnessOnInputChange2)
            try container.encode(brightnessOnInputChange3.uint8Value, forKey: .brightnessOnInputChange3)

            try container.encode(contrastOnInputChange1.uint8Value, forKey: .contrastOnInputChange1)
            try container.encode(contrastOnInputChange2.uint8Value, forKey: .contrastOnInputChange2)
            try container.encode(contrastOnInputChange3.uint8Value, forKey: .contrastOnInputChange3)

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

            try brightnessCurveFactorsContainer.encodeIfPresent(brightnessCurveFactors[.sync], forKey: .sync)
            try brightnessCurveFactorsContainer.encodeIfPresent(brightnessCurveFactors[.sensor], forKey: .sensor)
            try brightnessCurveFactorsContainer.encodeIfPresent(brightnessCurveFactors[.location], forKey: .location)
            try brightnessCurveFactorsContainer.encodeIfPresent(brightnessCurveFactors[.manual], forKey: .manual)

            try contrastCurveFactorsContainer.encodeIfPresent(contrastCurveFactors[.sync], forKey: .sync)
            try contrastCurveFactorsContainer.encodeIfPresent(contrastCurveFactors[.sensor], forKey: .sensor)
            try contrastCurveFactorsContainer.encodeIfPresent(contrastCurveFactors[.location], forKey: .location)
            try contrastCurveFactorsContainer.encodeIfPresent(userContrast[.manual], forKey: .manual)

            try container.encode(alwaysUseNetworkControl, forKey: .alwaysUseNetworkControl)
            try container.encode(neverUseNetworkControl, forKey: .neverUseNetworkControl)
            try container.encode(alwaysFallbackControl, forKey: .alwaysFallbackControl)
            try container.encode(neverFallbackControl, forKey: .neverFallbackControl)
            try container.encode(power, forKey: .power)
            try container.encode(isSource, forKey: .isSource)
            try container.encode(applyGamma, forKey: .applyGamma)
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

    @Atomic var inSmoothTransition = false

    func smoothTransition(from currentValue: UInt8, to value: UInt8, adjust: @escaping ((UInt8) -> Void)) {
        inSmoothTransition = true

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
        asyncNow(barrier: true) { [weak self] in
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

            self.inSmoothTransition = false
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
        guard !isTestID(id), !inSmoothTransition, !isUserAdjusting(), !sendingBrightness else { return }
        guard let newBrightness = readBrightness() else {
            log.warning("Can't read brightness for \(name)")
            return
        }

        guard !inSmoothTransition, !isUserAdjusting(), !sendingBrightness else { return }
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
        guard !isTestID(id), !inSmoothTransition, !isUserAdjusting(), !sendingContrast else { return }
        guard let newContrast = readContrast() else {
            log.warning("Can't read contrast for \(name)")
            return
        }

        guard !inSmoothTransition, !isUserAdjusting(), !sendingContrast else { return }
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

//    deinit {
//        #if DEBUG
//            log.verbose("START DEINIT: \(description)")
//            log.verbose("popover: \(_hotkeyPopover)")
//            log.verbose("POPOVERS: \(POPOVERS.map { "\($0.key): \($0.value)" })")
//            do { log.verbose("END DEINIT: \(description)") }
//        #endif
//    }

    lazy var hotkeyIdentifiers = [
        "toggle-last-input-\(serial)",
        "toggle-last-input2-\(serial)",
        "toggle-last-input3-\(serial)",
    ]

    func refreshInput() {
        let hotkeys = CachedDefaults[.hotkeys]
        let hotkeyInputEnabled = hotkeyIdentifiers.compactMap { identifier in
            hotkeys.first { $0.identifier == identifier }
        }.first { $0.isEnabled }?.isEnabled ?? false

        guard !isTestID(id), !hotkeyInputEnabled else { return }
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
        guard !isTestID(id) else { return }
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
        gammaChanged = true
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
    @Atomic var gammaChanged = false

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
                self.gammaChanged = true
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

            self.gammaChanged = true
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

    func reset(resetControl: Bool = true) {
        maxDDCBrightness = 100.ns
        maxDDCContrast = 100.ns
        maxDDCVolume = 100.ns

        userContrast[displayController.adaptiveModeKey]?.removeAll()
        userBrightness[displayController.adaptiveModeKey]?.removeAll()

        resetDefaultGamma()

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
        brightnessCurveFactors = [
            .sensor: DEFAULT_SENSOR_BRIGHTNESS_CURVE_FACTOR,
            .sync: DEFAULT_SYNC_BRIGHTNESS_CURVE_FACTOR,
            .location: DEFAULT_LOCATION_BRIGHTNESS_CURVE_FACTOR,
            .manual: DEFAULT_MANUAL_BRIGHTNESS_CURVE_FACTOR,
        ]

        contrastCurveFactors = [
            .sensor: DEFAULT_SENSOR_CONTRAST_CURVE_FACTOR,
            .sync: DEFAULT_SYNC_CONTRAST_CURVE_FACTOR,
            .location: DEFAULT_LOCATION_CONTRAST_CURVE_FACTOR,
            .manual: DEFAULT_MANUAL_CONTRAST_CURVE_FACTOR,
        ]

        save()

        if resetControl {
            _ = control?.reset()
        }
        readapt(newValue: false, oldValue: true)
    }

    // MARK: "With/out" functions

    @inline(__always) func withoutDDCLimits(_ block: () -> Void) {
        DDC.sync {
            DDC.applyLimits = false
            block()
            DDC.applyLimits = true
        }
    }

    @inline(__always) func withoutDDC(_ block: () -> Void) {
        DDC.sync {
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
