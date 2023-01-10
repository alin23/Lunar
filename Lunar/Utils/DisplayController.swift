//
//  DisplayController.swift
//  Lunar
//
//  Created by Alin on 02/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import AnyCodable
import AXSwift
import Cocoa
import Combine
import CoreLocation
import Defaults
import Foundation
import FuzzyMatcher
import Sentry
import Solar
import Surge
import SwiftDate
import SwiftyJSON

#if arch(arm64)
    let DCP_NAMES = ["dcp", "dcpext", "dcp0"] + (0 ... 7).map { "dcpext\($0)" }
    let DISP_NAMES = ["disp"] + (0 ... 7).map { "dispext\($0)" } + (0 ... 7).map { "disp\($0)" }

    func IOServiceNameMatches(_ service: io_service_t, names: [String]) -> Bool {
        guard let name = IOServiceName(service) else { return false }
        return names.contains(name)
    }

    func IOServiceName(_ service: io_service_t) -> String? {
        let deviceNamePtr = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
        defer { deviceNamePtr.deallocate() }
        deviceNamePtr.initialize(repeating: 0, count: MemoryLayout<io_name_t>.size)
        defer { deviceNamePtr.deinitialize(count: MemoryLayout<io_name_t>.size) }

        let kr = IORegistryEntryGetName(service, deviceNamePtr)
        if kr != KERN_SUCCESS {
            return nil
        }

        return String(cString: deviceNamePtr)
    }

    func isExternalDCPAVService(_ dcpAvServiceProxy: io_service_t) -> Bool {
        var dcpAvServiceProperties: Unmanaged<CFMutableDictionary>?
        let extractionResult = IORegistryEntryCreateCFProperties(
            dcpAvServiceProxy,
            &dcpAvServiceProperties,
            kCFAllocatorDefault,
            IOOptionBits()
        )

        guard extractionResult == KERN_SUCCESS,
              let dcpAvCFProps = dcpAvServiceProperties, let dcpAvProps = dcpAvCFProps.takeRetainedValue() as? [String: Any],
              let avServiceLocation = dcpAvProps["Location"] as? String
        else { return false }
        return avServiceLocation == "External"
    }

    func IOServiceFirstChildMatchingRecursively(_ service: io_service_t, names: [String]) -> io_service_t? {
        var iterator = io_iterator_t()

        guard IORegistryEntryCreateIterator(
            service, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator
        ) == KERN_SUCCESS
        else {
            log.info("Can't create iterator for service \(service): (names: \(names))")
            return nil
        }

        defer {
            IOObjectRelease(iterator)
        }
        log.info("Looking for service (names: \(names)) in iterator \(iterator)")
        return IOServiceFirstMatchingInIterator(iterator, names: names)
    }

    func IOServiceFirstMatchingInIterator(_ iterator: io_iterator_t, names: [String]) -> io_service_t? {
        var service: io_service_t?

        while case let txIOChild = IOIteratorNext(iterator), txIOChild != 0 {
            if IOServiceNameMatches(txIOChild, names: names) {
                service = txIOChild
                log.info("Found service \(txIOChild) in iterator \(iterator): (names: \(names))")
                break
            }
            IOObjectRelease(txIOChild)
        }

        return service
    }

    // MARK: - AVServiceMatch

    enum AVServiceMatch {
        case byEDIDUUID
        case byProductAttributes
        case byExclusion
    }

    class DCP: CustomStringConvertible, Hashable, Equatable {
        deinit {
            IOObjectRelease(dispService)
            IOObjectRelease(dcpService)
            IOObjectRelease(dcpAvServiceProxy)
            IOObjectRelease(clcd2Service)
        }
        init?(dispService: io_service_t, txIOIterator: io_iterator_t, index: Int) {
            guard let dispName = IOServiceName(dispService), DISP_NAMES.contains(dispName) else {
                return nil
            }

            guard let dcpService = IOServiceFirstMatchingInIterator(txIOIterator, names: DCP_NAMES),
                  let dcpName = IOServiceName(dcpService),
                  let dcpAvServiceProxy = IOServiceFirstChildMatchingRecursively(dcpService, names: ["DCPAVServiceProxy"])
            else {
                log.debug("No DCPAVServiceProxy for \(dispName)")
                return nil
            }

            guard let avService = AVServiceCreateFromDCPAVServiceProxy(dcpAvServiceProxy)?.takeRetainedValue(),
                  !CFEqual(avService, 0 as IOAVService), isExternalDCPAVService(dcpAvServiceProxy)
            else {
                log.debug("No AVService for \(dispName)")
                return nil
            }

            guard let clcd2Service = IOServiceFirstChildMatchingRecursively(dispService, names: ["AppleCLCD2"])
            else {
                log.debug("No AppleCLCD2 for \(dispName)")
                return nil

            }

            var clcd2ServiceProperties: Unmanaged<CFMutableDictionary>?
            var displayProps = [String: Any]()

            let kernResult = IORegistryEntryCreateCFProperties(
                clcd2Service, &clcd2ServiceProperties, kCFAllocatorDefault, IOOptionBits()
            )
            if kernResult == KERN_SUCCESS, let cfProps = clcd2ServiceProperties,
               let props = cfProps.takeRetainedValue() as? [String: Any]
            {
                displayProps = props
            } else {
                log.debug("No display props for service \(dispName)")
            }

            guard let edidUUID = (displayProps["EDID UUID"] as? String) ?? (displayProps["IOMFBUUID"] as? String)
            else {
                log.debug("No EDID UUID for service \(dispName)")
                return nil
            }

            var transport: Transport?
            if let transportDict = displayProps["Transport"] as? [String: String] {
                transport = Transport(
                    upstream: transportDict["Upstream"] ?? "",
                    downstream: transportDict["Downstream"] ?? ""
                )
            }

            var displayAttributes = displayProps["DisplayAttributes"] as? [String: Any] ?? [:]
            displayAttributes.removeValue(forKey: "TimingElements")
            displayAttributes.removeValue(forKey: "ColorElements")

            let productAttributes = displayAttributes["ProductAttributes"] as? [String: Any] ?? [:]

            self.index = index
            self.dispService = dispService
            self.dcpService = dcpService
            self.dcpAvServiceProxy = dcpAvServiceProxy
            self.clcd2Service = clcd2Service
            self.dispName = dispName
            self.dcpName = dcpName
            self.avService = avService
            self.edidUUID = edidUUID
            isMCDP = isMCDP29XX(dcpAvServiceProxy: dcpAvServiceProxy)
            self.displayProps = displayAttributes
            self.transport = transport
            productName = productAttributes["ProductName"] as? String
            productID = productAttributes["ProductID"] as? Int
            serialNumber = productAttributes["SerialNumber"] as? Int
            yearOfManufacture = productAttributes["YearOfManufacture"] as? Int
            manufacturerID = productAttributes["ManufacturerID"] as? String
            legacyManufacturerID = productAttributes["LegacyManufacturerID"] as? Int
            nativeFormatHorizontalPixels = productAttributes["NativeFormatHorizontalPixels"] as? Int
            nativeFormatVerticalPixels = productAttributes["NativeFormatVerticalPixels"] as? Int
        }

        let index: Int

        let dispService: io_service_t
        let dcpService: io_service_t
        let dcpAvServiceProxy: io_service_t
        let clcd2Service: io_service_t

        let dispName: String
        let dcpName: String

        let avService: IOAVService
        let edidUUID: String?
        let isMCDP: Bool
        let displayProps: [String: Any]
        let transport: Transport?

        let productName: String?
        let productID: Int?
        let serialNumber: Int?
        let yearOfManufacture: Int?

        let manufacturerID: String?
        let legacyManufacturerID: Int?
        let nativeFormatHorizontalPixels: Int?
        let nativeFormatVerticalPixels: Int?

        var scores: [CGDirectDisplayID: Int] = [:]

        var scoreDict: [String: Int] {
            scores.dict { id, score in
                guard let display = displayController.activeDisplays[id] else { return nil }
                return (display.description, score)
            }
        }

        var description: String {
            """
            <DCP \(dispName)>
                dispService: \(dispService)
                dcpService: \(dcpService)
                dcpAvServiceProxy: \(dcpAvServiceProxy)
                clcd2Service: \(clcd2Service)
                dcpName: \(dcpName)
                avService: \(avService)
                edidUUID: \(edidUUID ?? "nil")
                isMCDP: \(isMCDP)
                transport: \(transport ?? .init(upstream: "nil", downstream: "nil"))
                productName: \(productName ?? "nil")
                productID: \(productID ?? -1)
                serialNumber: \(serialNumber ?? -1)
                yearOfManufacture: \(yearOfManufacture ?? -1)
                manufacturerID: \(manufacturerID ?? "nil")
                legacyManufacturerID: \(legacyManufacturerID ?? -1)
                nativeFormatHorizontalPixels: \(nativeFormatHorizontalPixels ?? -1)
                nativeFormatVerticalPixels: \(nativeFormatVerticalPixels ?? -1)
                displayProps: \((try? encoder.encode(ForgivingEncodable(displayProps)))?.s ?? "{}")
                scores: \((try? encoder.encode(scoreDict))?.s ?? "{}")
            """
        }

        static func == (lhs: DCP, rhs: DCP) -> Bool {
            lhs.index == rhs.index &&
                lhs.dispService == rhs.dispService &&
                lhs.dispName == rhs.dispName
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(index)
            hasher.combine(dispService)
            hasher.combine(dispName)
        }

        func matchesEdidUUID(_ uuid: String) -> Bool {
            guard let uuidPattern = uuid.r, let edidUUID else { return false }
            log.debug("Testing EDID UUID pattern \(uuid) with \(edidUUID) for display \(self)")

            let matched = uuidPattern.matches(edidUUID)
            if matched {
                log.debug("Matched EDID UUID pattern \(uuid) with \(edidUUID) for display \(self)")
            }
            return matched
        }

        func matchingScore(for display: Display, in displayIDs: [CGDirectDisplayID]? = nil) -> Int {
            var score = 0

            if let edidUUID {
                let uuids = display.possibleEDIDUUIDs()
                if uuids.isEmpty {
                    log.debug("No EDID UUID pattern to test with \(edidUUID) for display \(self)")
                } else if let edidUUIDIndex = uuids.firstIndex(where: matchesEdidUUID(_:)) {
                    score += uuids.count - edidUUIDIndex
                }
            }

            score += DisplayController.displayInfoDictPartialMatchScore(
                display: display,
                name: productName,
                serial: serialNumber,
                productID: productID,
                manufactureYear: yearOfManufacture,
                vendorID: legacyManufacturerID,
                width: nativeFormatHorizontalPixels,
                height: nativeFormatVerticalPixels,
                transport: transport
            )

            return score
        }

    }
#endif

public enum BackportSortOrder {
    case forward
    case reverse
}

public extension Collection {
    func sorted(by keyPath: KeyPath<Element, some Comparable>, order: BackportSortOrder = .forward) -> [Element] {
        sorted(by: { e1, e2 in
            switch order {
            case .forward:
                return e1[keyPath: keyPath] < e2[keyPath: keyPath]
            case .reverse:
                return e1[keyPath: keyPath] > e2[keyPath: keyPath]
            }
        })
    }

}
infix operator ?!: NilCoalescingPrecedence

func ?! (_ str: String?, _ str2: String) -> String {
    guard let str, !str.isEmpty else {
        return str2
    }
    return str
}

func ?! (_ str: io_service_t?, _ str2: io_service_t?) -> io_service_t? {
    guard let str, str != 0 else {
        return str2
    }
    return str
}
func ?! (_ str: io_service_t?, _ str2: io_service_t) -> io_service_t {
    guard let str, str != 0 else {
        return str2
    }
    return str
}

// MARK: - DisplayController

class DisplayController: ObservableObject {
    init() {
        watchControlAvailability()
        watchModeAvailability()
        watchScreencaptureProcess()
        initObservers()
        setupXdrTask()
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        controlWatcherTask = nil
        modeWatcherTask = nil
        screencaptureWatcherTask = nil
    }

    static var panelManager: MPDisplayMgr? = MPDisplayMgr()
    static var manualModeFromSyncMode = false

    var averageDDCWriteNanoseconds: ThreadSafeDictionary<CGDirectDisplayID, UInt64> = ThreadSafeDictionary()
    var averageDDCReadNanoseconds: ThreadSafeDictionary<CGDirectDisplayID, UInt64> = ThreadSafeDictionary()

    var controlWatcherTask: Repeater?
    var modeWatcherTask: Repeater?
    var screencaptureWatcherTask: Repeater?

    let getDisplaysLock = NSRecursiveLock()
    var clamshellMode = false

    var appObserver: NSKeyValueObservation?
    @AtomicLock var runningAppExceptions: [AppException]!

    var onActiveDisplaysChange: (() -> Void)?
    var _activeDisplaysLock = NSRecursiveLock()
    var _activeDisplays: [CGDirectDisplayID: Display] = [:]
    var activeDisplaysByReadableID: [String: Display] = [:]
    var activeDisplaysBySerial: [String: Display] = [:]
    var lastNonManualAdaptiveMode: AdaptiveMode = DisplayController.getAdaptiveMode()
    var lastModeWasAuto: Bool = !CachedDefaults[.overrideAdaptiveMode]

    var onAdapt: ((Any) -> Void)?

    var pausedAdaptiveModeObserver = false
    var adaptiveModeObserver: Cancellable?

    var overrideAdaptiveModeObserver: Cancellable?
    var pausedOverrideAdaptiveModeObserver = false

    var observers: Set<AnyCancellable> = []

    lazy var currentAudioDisplay: Display? = getCurrentAudioDisplay()

    let SCREENCAPTURE_WATCHER_TASK_KEY = "screencaptureWatcherTask"
    let MODE_WATCHER_TASK_KEY = "modeWatcherTask"
    let CONTROL_WATCHER_TASK_KEY = "controlWatcherTask"

    @Atomic var lastPidCount = 0
    @Atomic var gammaDisabledCompletely = CachedDefaults[.gammaDisabledCompletely]

    @Published var activeDisplayList: [Display] = [] {
        didSet {
            #if arch(arm64)
                DDC.rebuildDCPList()
            #endif
        }
    }

    @Atomic var lidClosed: Bool = isLidClosed() {
        didSet {
            guard lidClosed != oldValue else { return }

            log.info(
                "Lid state changed",
                context: [
                    "old": oldValue ? "closed" : "opened",
                    "new": lidClosed ? "closed" : "opened",
                ]
            )

            reset()
        }
    }

    static func tryLockManager(tries: Int = 10) -> Bool {
        for i in 1 ... tries {
            log.info("Trying to lock display manager (try: \(i))")
            if let mgr = panelManager, mgr.tryLockAccess() { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }

    static func displayInfoDictPartialMatchScore(
        display: Display,
        name: String?,
        serial: Int?,
        productID: Int?,
        manufactureYear: Int?,
        vendorID: Int? = nil,
        width: Int? = nil,
        height: Int? = nil,
        transport: Transport? = nil
    ) -> Int {
        var score = 0

        if let name {
            score += display.edidName.lowercased() == name.lowercased() ? 1 : -1
        }

        let infoDict = (displayInfoDictionary(display.id) ?? display.infoDictionary)

        if let manufactureYear, let displayYearManufacture = infoDict[kDisplayYearOfManufacture] as? Int64, displayYearManufacture != 0 {
            score += (displayYearManufacture == manufactureYear).i
        }

        if let serial, let displaySerialNumber = infoDict[kDisplaySerialNumber] as? Int64,
           abs(displaySerialNumber.i - serial) < 3
        {
            score += 3 - abs(displaySerialNumber.i - serial)
        }

        if let productID, let displayProductID = infoDict[kDisplayProductID] as? Int64,
           abs(displayProductID.i - productID) < 3
        {
            score += 3 - abs(displayProductID.i - productID)
        }

        if let vendorID, let displayVendorID = infoDict[kDisplayVendorID] as? Int64,
           abs(displayVendorID.i - vendorID) < 3
        {
            score += 3 - abs(displayVendorID.i - vendorID)
        }

        if let width, let displayWidth = infoDict["kCGDisplayPixelWidth"] as? Int64,
           abs(displayWidth.i - width) < 3
        {
            score += 3 - abs(displayWidth.i - width)
        }

        if let height, let displayHeight = infoDict["kCGDisplayPixelHeight"] as? Int64,
           abs(displayHeight.i - height) < 3
        {
            score += 3 - abs(displayHeight.i - height)
        }

        if let transport, let transportType = infoDict["kDisplayTransportType"] as? Int,
           let connection = Display.ConnectionType.fromTransport(transport),
           let connection2 = Display.ConnectionType.fromTransportType(transportType)
        {
            score += connection == connection2 ? 1 : -1
        }

        return score
    }

    static func displayInfoDictFullMatch(
        display: Display,
        name: String,
        serial: Int,
        productID: Int,
        manufactureYear: Int,
        manufacturer _: String? = nil,
        vendorID: Int? = nil,
        width: Int? = nil,
        height: Int? = nil
    ) -> Bool {
        let infoDict = (displayInfoDictionary(display.id) ?? display.infoDictionary)
        guard let displayYearManufacture = infoDict[kDisplayYearOfManufacture] as? Int64,
              let displaySerialNumber = infoDict[kDisplaySerialNumber] as? Int64,
              let displayProductID = infoDict[kDisplayProductID] as? Int64,
              let displayVendorID = infoDict[kDisplayVendorID] as? Int64
        else { return false }

        var matches = (
            display.edidName.lowercased() == name.lowercased() &&
                displayYearManufacture == manufactureYear &&
                displaySerialNumber == serial &&
                displayProductID == productID
        )

        if let vendorID {
            matches = matches || displayVendorID == vendorID
        }

        if let width, let displayWidth = infoDict["kCGDisplayPixelWidth"] as? Int64 {
            matches = matches || displayWidth == width
        }

        if let height, let displayHeight = infoDict["kCGDisplayPixelHeight"] as? Int64 {
            matches = matches || displayHeight == height
        }

        return matches
    }

    func swap(firstDisplay: CGDirectDisplayID, secondDisplay: CGDirectDisplayID, rotation: Bool = true) {
        Display.configure { config in
            let firstMonitorBounds = CGDisplayBounds(firstDisplay)
            let secondMonitorBounds = CGDisplayBounds(secondDisplay)

            CGConfigureDisplayOrigin(
                config,
                firstDisplay,
                Int32(secondMonitorBounds.origin.x.rounded()),
                Int32(secondMonitorBounds.origin.y.rounded())
            )
            CGConfigureDisplayOrigin(
                config,
                secondDisplay,
                Int32(firstMonitorBounds.origin.x.rounded()),
                Int32(firstMonitorBounds.origin.y.rounded())
            )
            return true
        }

        guard rotation,
              let panel1 = DisplayController.panel(with: firstDisplay),
              let panel2 = DisplayController.panel(with: secondDisplay)
        else { return }

        guard panel1.canChangeOrientation(), panel2.canChangeOrientation()
        else {
            print("The monitors don't have the ability to change orientation")
            return
        }
        guard panel1.orientation != panel2.orientation
        else {
            print("Orientation is the same for both monitors")
            return
        }
        let rotation1 = panel1.orientation
        let rotation2 = panel2.orientation

        Display.reconfigure { _ in
            panel1.orientation = rotation2
            panel2.orientation = rotation1
        }
    }

    func reset() {
        menuWindow?.forceClose()

        displayController.manageClamshellMode()
        displayController.resetDisplayList(autoBlackOut: Defaults[.autoBlackoutBuiltin])

        displayController.adaptBrightness(force: true)
        appDelegate!.resetStatesPublisher.send(true)
    }

    func watchModeAvailability() {
        guard modeWatcherTask == nil else {
            return
        }

        guard !pausedOverrideAdaptiveModeObserver else { return }

        pausedOverrideAdaptiveModeObserver = true
        modeWatcherTask = Repeater(every: 5, name: MODE_WATCHER_TASK_KEY) { [weak self] in
            guard !displayController.screensSleeping, let self else { return }
            self.autoAdaptMode()
        }
        pausedOverrideAdaptiveModeObserver = false
    }

    func watchScreencaptureProcess() {
        guard screencaptureWatcherTask == nil else {
            return
        }

        screencaptureWatcherTask = Repeater(every: 1, name: SCREENCAPTURE_WATCHER_TASK_KEY) { [weak self] in
            guard !displayController.screensSleeping, let self,
                  self.activeDisplayList.contains(where: { $0.hasSoftwareControl && !$0.supportsGamma })
            else { return }
            let pids = pidCount()

            if pids != self.lastPidCount {
                self.screencaptureIsRunning.send(processIsRunning("/usr/sbin/screencapture", nil))
            }
            self.lastPidCount = pids.i
        }
    }

    func initObservers() {
        NotificationCenter.default.publisher(for: lunarProStateChanged, object: nil).sink { _ in
            self.autoAdaptMode()
        }.store(in: &observers)

        NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.screensDidWakeNotification, object: nil
        ).sink { _ in
            self.watchControlAvailability()
            self.watchModeAvailability()
            self.watchScreencaptureProcess()
        }.store(in: &observers)

        NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.screensDidSleepNotification, object: nil
        ).sink { _ in
            self.controlWatcherTask = nil
            self.modeWatcherTask = nil
            self.screencaptureWatcherTask = nil
        }.store(in: &observers)

        gammaDisabledCompletelyPublisher
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [self] change in
                if change.newValue {
                    restoreColorSyncSettings()
                }

                gammaDisabledCompletely = change.newValue
                guard change.newValue else {
                    if let oldVal = CachedDefaults[.oldHdrWorkaround] { CachedDefaults[.hdrWorkaround] = oldVal }
                    if let oldVal = CachedDefaults[.oldAutoXdr] { CachedDefaults[.autoXdr] = oldVal }
                    if let oldVal = CachedDefaults[.oldAutoXdrSensor] { CachedDefaults[.autoXdrSensor] = oldVal }
                    if let oldVal = CachedDefaults[.oldAutoSubzero] { CachedDefaults[.autoSubzero] = oldVal }
                    if let oldVal = CachedDefaults[.oldXdrContrast] { CachedDefaults[.xdrContrast] = oldVal }
                    if let oldVal = CachedDefaults[.oldShowXDRSelector] { CachedDefaults[.showXDRSelector] = oldVal }
                    if let oldVal = CachedDefaults[.oldAllowHDREnhanceBrightness] { CachedDefaults[.allowHDREnhanceBrightness] = oldVal }
                    if let oldVal = CachedDefaults[.oldAllowHDREnhanceContrast] { CachedDefaults[.allowHDREnhanceContrast] = oldVal }
                    return
                }

                displays.values.forEach {
                    $0.gammaEnabled = false
                }

                CachedDefaults[.oldHdrWorkaround] = CachedDefaults[.hdrWorkaround]
                CachedDefaults[.oldAutoXdr] = CachedDefaults[.autoXdr]
                CachedDefaults[.oldAutoXdrSensor] = CachedDefaults[.autoXdrSensor]
                CachedDefaults[.oldAutoSubzero] = CachedDefaults[.autoSubzero]
                CachedDefaults[.oldXdrContrast] = CachedDefaults[.xdrContrast]
                CachedDefaults[.oldShowXDRSelector] = CachedDefaults[.showXDRSelector]
                CachedDefaults[.oldAllowHDREnhanceBrightness] = CachedDefaults[.allowHDREnhanceBrightness]
                CachedDefaults[.oldAllowHDREnhanceContrast] = CachedDefaults[.allowHDREnhanceContrast]

                CachedDefaults[.hdrWorkaround] = false
                CachedDefaults[.autoXdr] = false
                CachedDefaults[.autoXdrSensor] = false
                CachedDefaults[.autoSubzero] = false
                CachedDefaults[.xdrContrast] = false
                CachedDefaults[.showXDRSelector] = false
                CachedDefaults[.allowHDREnhanceBrightness] = false
                CachedDefaults[.allowHDREnhanceContrast] = false
            }.store(in: &observers)

        mergeBrightnessContrastPublisher
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [self] change in
                displays.values.forEach {
                    $0.noDDCOrMergedBrightnessContrast = !$0.hasDDC || change.newValue
                }
            }.store(in: &observers)

        showOrientationInQuickActionsPublisher
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [self] change in
                displays.values.forEach {
                    #if DEBUG
                        $0.showOrientation = change.newValue
                    #else
                        $0.showOrientation = $0.canRotate && change.newValue
                    #endif
                }
            }.store(in: &observers)

        showVolumeSliderPublisher
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [self] change in
                displays.values.forEach {
                    $0.showVolumeSlider = $0.canChangeVolume && change.newValue
                }
            }.store(in: &observers)

        showTwoSchedulesPublisher.sink { [self] change in
            guard !change.newValue else { return }

            displays.values.forEach { d in
                guard let schedule = d.schedules[safe: 1] else { return }
                d.schedules[1] = schedule.with(type: .disabled)
                d.save()
            }
        }.store(in: &observers)
        showThreeSchedulesPublisher.sink { [self] change in
            guard !change.newValue else { return }

            displays.values.forEach { d in
                guard let schedule = d.schedules[safe: 2] else { return }
                d.schedules[2] = schedule.with(type: .disabled)
                d.save()
            }
        }.store(in: &observers)
        showFourSchedulesPublisher.sink { [self] change in
            guard !change.newValue else { return }

            displays.values.forEach { d in
                guard let schedule = d.schedules[safe: 3] else { return }
                d.schedules[3] = schedule.with(type: .disabled)
                d.save()
            }
        }.store(in: &observers)
        showFiveSchedulesPublisher.sink { [self] change in
            guard !change.newValue else { return }

            displays.values.forEach { d in
                guard let schedule = d.schedules[safe: 4] else { return }
                d.schedules[4] = schedule.with(type: .disabled)
                d.save()
            }
        }.store(in: &observers)

        allowHDREnhanceBrightnessPublisher.sink { change in
            if !change.newValue {
                self.activeDisplayList
                    .filter { $0.enhanced && !($0.control is AppleNativeControl) }
                    .forEach { $0.enhanced = false }
            }
        }.store(in: &observers)
        allowHDREnhanceContrastPublisher
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { _ in
                self.recomputeEDR()
                self.xdrContrastEnabled = CachedDefaults[.xdrContrast]
            }.store(in: &observers)
        xdrContrastFactorPublisher.sink { change in
            self.recomputeEDR(factor: change.newValue)
            self.xdrContrastEnabled = CachedDefaults[.xdrContrast]
        }.store(in: &observers)

        xdrContrastPublisher.sink { self.xdrContrastEnabled = $0.newValue }.store(in: &observers)
        autoXdrPublisher.sink { self.autoXdr = $0.newValue }.store(in: &observers)
        autoSubzeroPublisher.sink { self.autoSubzero = $0.newValue }.store(in: &observers)
    }

    func getMatchingDisplay(
        name: String,
        serial: Int,
        productID: Int,
        manufactureYear: Int,
        manufacturer: String? = nil,
        vendorID: Int? = nil,
        width: Int? = nil,
        height: Int? = nil,
        displays: [Display]? = nil,
        partial: Bool = true
    ) -> Display? {
        let displays = (displays ?? self.displays.values.map { $0 })
        let d = displays.first(where: { display in
            DisplayController.displayInfoDictFullMatch(
                display: display,
                name: name,
                serial: serial,
                productID: productID,
                manufactureYear: manufactureYear,
                manufacturer: manufacturer,
                vendorID: vendorID,
                width: width,
                height: height
            )
        })

        if let fullyMatchedDisplay = d {
            log.info("Fully matched display \(fullyMatchedDisplay)")
            return fullyMatchedDisplay
        }

        guard partial else { return nil }

        let displayScores = displays.map { display -> (Display, Int) in
            let score = DisplayController.displayInfoDictPartialMatchScore(
                display: display,
                name: name,
                serial: serial,
                productID: productID,
                manufactureYear: manufactureYear,
                vendorID: vendorID,
                width: width,
                height: height
            )

            return (display, score)
        }

        log.info("Display scores: \(displayScores)")
        return displayScores.max(count: 1, sortedBy: { first, second in first.1 <= second.1 }).first?.0
    }

    #if arch(arm64)

        func clcd2Properties(_ dispService: io_service_t) -> [String: Any]? {
            guard let clcd2Service = IOServiceFirstChildMatchingRecursively(dispService, names: ["AppleCLCD2"]) else { return nil }

            var clcd2ServiceProperties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(
                clcd2Service,
                &clcd2ServiceProperties,
                kCFAllocatorDefault,
                IOOptionBits()
            ) == KERN_SUCCESS,
                let cfProps = clcd2ServiceProperties, let displayProps = cfProps.takeRetainedValue() as? [String: Any]
            else {
                log.info("No display props for service \(dispService)")
                return nil
            }
            return displayProps
        }

        // func matchDisplayByEDIDUUID(_ service: io_service_t, displays: [Display]? = nil, props: [String: Any]? = nil) -> Display? {
        //     guard let displayProps = props ?? clcd2Properties(service) else { return nil }
        //     guard let edidUUID = displayProps["EDID UUID"] as? String
        //     else {
        //         log.info("No display matched for service \(service): (Can't find EDID UUID)")
        //         return nil
        //     }

        //     var transport: Transport?
        //     if let transportDict = displayProps["Transport"] as? [String: String] {
        //         transport = Transport(upstream: transportDict["Upstream"] ?? "", downstream: transportDict["Downstream"] ?? "")
        //     }

        //     let activeDisplays = (displays ?? activeDisplays.values.map { $0 })
        //     guard let display = activeDisplays.first(where: { $0.matchesEDIDUUID(edidUUID) }) else {
        //         log.info("No UUID matched: (EDID UUID: \(edidUUID), Transport: \(transport?.description ?? "Unknown"))")
        //         return nil
        //     }

        //     log.info("Matched display \(display) (EDID UUID: \(edidUUID), Transport: \(transport?.description ?? "Unknown"))")
        //     display.transport = transport
        //     display.audioIdentifier = edidUUID
        //     return display
        // }

        // func matchDisplayByExcludingOthers(_: io_service_t, displays: [Display]? = nil) -> Display? {
        //     guard let display = displays?.first else { return nil }

        //     return display
        // }

        // func matchDisplayByProductAttributes(_ service: io_service_t, displays: [Display]? = nil, props: [String: Any]? = nil) -> Display? {
        //     guard let displayProps = props ?? clcd2Properties(service) else { return nil }

        //     var transport: Transport?
        //     if let transportDict = displayProps["Transport"] as? [String: String] {
        //         transport = Transport(upstream: transportDict["Upstream"] ?? "", downstream: transportDict["Downstream"] ?? "")
        //     }

        //     guard let displayAttributes = displayProps["DisplayAttributes"] as? [String: Any],
        //           let props = displayAttributes["ProductAttributes"] as? [String: Any],
        //           let name = props["ProductName"] as? String, let serial = props["SerialNumber"] as? Int,
        //           let productID = props["ProductID"] as? Int, let manufactureYear = props["YearOfManufacture"] as? Int
        //     else {
        //         log.info("No display matched for service \(service)")
        //         log.verbose("displayProps: \(displayProps)")
        //         return nil
        //     }

        //     var allActiveDisplays = Set(activeDisplays.values.map { $0 })
        //     if let displays {
        //         allActiveDisplays.formUnion(displays)
        //     }

        //     guard let display = getMatchingDisplay(
        //         name: name, serial: serial, productID: productID, manufactureYear: manufactureYear,
        //         manufacturer: props["ManufacturerID"] as? String, vendorID: props["LegacyManufacturerID"] as? Int,
        //         width: props["NativeFormatHorizontalPixels"] as? Int, height: props["NativeFormatVerticalPixels"] as? Int,
        //         displays: Array(allActiveDisplays)
        //     ) else {
        //         return nil
        //     }

        //     log
        //         .info(
        //             "Matched display \(display) (name: \(name), serial: \(serial), productID: \(productID), Transport: \(transport?.description ?? "Unknown"))"
        //         )
        //     display.transport = transport
        //     return display
        // }

        // func displayForIOService(_ service: io_service_t, displays: [Display]? = nil, match: AVServiceMatch) -> Display? {
        //     switch match {
        //     case .byEDIDUUID:
        //         return matchDisplayByEDIDUUID(service, displays: displays)
        //     case .byProductAttributes:
        //         return matchDisplayByProductAttributes(service, displays: displays)
        //     case .byExclusion:
        //         return matchDisplayByExcludingOthers(service, displays: displays)
        //     }
        // }

//        func avService(displayID: CGDirectDisplayID, display: Display? = nil, match: AVServiceMatch) -> IOAVService? {
//            if match == .byExclusion {
//                let matchedIDs = Set(DDC.avServiceCache.dictionary.keys)
//                let idsToMatch = activeDisplayList.filter(\.shouldDetectI2C).map(\.id)
//                guard matchedIDs.isSuperset(of: idsToMatch) else { return nil }
//            }
//
//            let forceDDC = (display?.forceDDC ?? false)
//            guard !isTestID(displayID), NSScreen.isOnline(displayID),
//                  forceDDC || (!DDC.isVirtualDisplay(displayID, checkName: false))
//            else {
//                log.info("""
//                    No AVService for display \(displayID): (
//                        isOnline: \(NSScreen.isOnline(displayID)),
//                        isVirtual: \(DDC.isVirtualDisplay(displayID, checkName: false)),
//                        MCDP: \(display?.mcdp ?? false)
//                    )
//                """)
//                return nil
//            }
//
//            if forceDDC {
//                log.info("Forcing DDC assignment for \(displayID)")
//            }
//
//            var clcd2Num = 0
//            var txIOIterator = io_iterator_t()
//            var txIOService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleT810xIO"))
//            if txIOService == 0 {
//                txIOService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleT600xIO"))
//            }
//            if txIOService == 0 {
//                txIOService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleT811xIO"))
//            }
//
//            defer {
//                if txIOService != 0 {
//                    IOObjectRelease(txIOService)
//                }
//            }
//
//            let childIteratorErr = (txIOService != 0)
//                ? IORegistryEntryGetChildIterator(txIOService, kIOServicePlane, &txIOIterator)
//                : KERN_SUCCESS
//            guard txIOService != 0, childIteratorErr == KERN_SUCCESS
//            else {
//                log.warning("Can't iterate AppleT810xIO/AppleT600xIO/AppleT811xIO")
//                log.info("""
//                    No AVService for display \(displayID): (
//                        txIOService: \(txIOService),
//                        childIteratorErr: \(childIteratorErr)
//                    )
//                """)
//                return nil
//            }
//
//            defer {
//                if txIOIterator != 0 {
//                    IOObjectRelease(txIOIterator)
//                }
//            }
//
//            var matchedDisplay: Display?
//            while case let txIOChild = IOIteratorNext(txIOIterator), txIOChild != 0 {
//                defer {
//                    IOObjectRelease(txIOChild)
//                }
//
//                if let name = IOServiceName(txIOChild), DISP_NAMES.contains(name) {
//                    log.debug("Iterating \(name)")
//                    clcd2Num += 1
//                    guard clcd2Mapping[clcd2Num] == nil || clcd2Mapping[clcd2Num] == displayID else { continue }
//
//                    if let d = displayForIOService(txIOChild, displays: display != nil ? [display!] : nil, match: match),
//                       d.id == displayID
//                    {
//                        matchedDisplay = d
//                        break
//                    }
//                }
//            }
//
//            guard let display = matchedDisplay else {
//                log.info("No AVService for display \(displayID): (no matched display)")
//                return nil
//            }
//
//            guard let dcpService = IOServiceFirstMatchingInIterator(txIOIterator, names: DCP_NAMES),
//                  let dcpAvServiceProxy = IOServiceFirstChildMatchingRecursively(dcpService, names: ["DCPAVServiceProxy"])
//            else {
//                log.warning("No DCPAVServiceProxy for display with ID: \(displayID)")
//                return nil
//            }
//
//            defer {
//                IOObjectRelease(dcpService)
//                IOObjectRelease(dcpAvServiceProxy)
//            }
//
//            if isMCDP29XX(dcpAvServiceProxy: dcpAvServiceProxy) {
//                display.mcdp = true
        ////                if !forceDDC {
        ////                    return nil
        ////                }
//            }
//
//            guard let ioAvService = AVServiceCreateFromDCPAVServiceProxy(dcpAvServiceProxy)?.takeRetainedValue(),
//                  !CFEqual(ioAvService, 0 as IOAVService), isExternalDCPAVService(dcpAvServiceProxy)
//            else {
//                log.warning("No AVService for display with ID: \(displayID)")
//                return nil
//            }
//            log.info("Found AVService for display \(display): \(CFCopyDescription(ioAvService) as String)")
//
//            clcd2Mapping[clcd2Num] = displayID
//            return ioAvService
//        }
    #endif

    enum XDRState {
        case none
        case enabledManually
        case disabledManually
        case enabledAutomatically
        case disabledAutomatically
    }

    static var nonZeroBuiltinMinBrightness: NSNumber = -1

    static var serials: [CGDirectDisplayID: String] = [:]

    var screencaptureIsRunning: CurrentValueSubject<Bool, Never> = .init(processIsRunning("/usr/sbin/screencapture", nil))

    @Atomic var apply = true

    lazy var panelRefreshPublisher: PassthroughSubject<CGDirectDisplayID, Never> = {
        let p = PassthroughSubject<CGDirectDisplayID, Never>()
        p.debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [self] id in
                DisplayController.panelManager = MPDisplayMgr()
                if let display = self.activeDisplays[id] {
                    display.refreshPanel()
                }
            }.store(in: &observers)
        return p
    }()

    var reconfigureTask: Repeater?

    lazy var autoBlackoutPublisher: PassthroughSubject<Bool, Never> = {
        let p = PassthroughSubject<Bool, Never>()
        p
            .debounce(for: .seconds(AUTO_OSD_DEBOUNCE_SECONDS), scheduler: RunLoop.main)
            .sink { shouldBlackout in
                defer { self.autoBlackoutPending = false }
                guard shouldBlackout, let d = self.builtinDisplay else { return }
                lastBlackOutToggleDate = .distantPast
                self.blackOut(display: d.id, state: .on)
            }.store(in: &observers)
        return p
    }()

    lazy var autoXdrAmbientLightPublisher: PassthroughSubject<Bool?, Never> = {
        let p = PassthroughSubject<Bool?, Never>()
        p
            .debounce(for: .seconds(AUTO_OSD_DEBOUNCE_SECONDS), scheduler: RunLoop.main)
            .sink { xdrEnabled in
                defer {
                    self.autoXdrPendingEnabled = false
                    self.autoXdrPendingDisabled = false
                }
                guard let xdrEnabled, let d = self.builtinDisplay else { return }

                d.enhanced = xdrEnabled
                self.xdrState = xdrEnabled ? .enabledAutomatically : .disabledAutomatically
            }.store(in: &observers)
        return p
    }()

    var panelModesBeforeMirroring: [CGDirectDisplayID: MPDisplayMode] = [:]
    var mirrorSetBeforeBlackout: [CGDirectDisplayID: [MPDisplay]] = [:]
    var enabledHDRBeforeXDR: [CGDirectDisplayID: Bool] = [:]

    var lastXdrContrast: Float = 0.0
    var xdrContrast: Float = 0.0

    var resetDisplayListTask: DispatchWorkItem?

    var xdrSensorTask: Repeater?
    lazy var autoXdrSensorLuxThreshold: Float = {
        autoXdrSensorLuxThresholdPublisher.sink { change in
            self.autoXdrSensorLuxThreshold = change.newValue
        }.store(in: &self.observers)
        return CachedDefaults[.autoXdrSensorLuxThreshold]
    }()

    @Published var autoXdrSensorPausedReason: String? = nil
    @Published var internalSensorLux: Float = 0

    var xdrState: XDRState = .none

    @Atomic var autoXdrTipShown = CachedDefaults[.autoXdrTipShown]
    @Atomic var screensSleeping = false
    @Atomic var loggedOut = false

    var autoXdrSensor: Bool = Defaults[.autoXdrSensor]
    var autoXdrSensorShowOSD: Bool = Defaults[.autoXdrSensorShowOSD]

    var lastTimeBrightnessKeyPressed = Date.distantPast

    @Atomic var autoBlackoutPending = false {
        didSet {
            log.info("autoBlackoutPending=\(autoBlackoutPending)")
        }
    }

    @Atomic var autoXdrPendingEnabled = false {
        didSet {
            log.info("autoXdrPendingEnabled=\(autoXdrPendingEnabled)")
            if autoXdrPendingEnabled {
                autoXdrPendingDisabled = false
            }
        }
    }

    @Atomic var autoXdrPendingDisabled = false {
        didSet {
            log.info("autoXdrPendingDisabled=\(autoXdrPendingDisabled)")
            if autoXdrPendingDisabled {
                autoXdrPendingEnabled = false
            }
        }
    }

    var displayList: [Display] {
        displays.values.sorted { (d1: Display, d2: Display) -> Bool in d1.id < d2.id }.reversed()
    }

    var externalActiveDisplays: [Display] {
        activeDisplayList.filter { !$0.isBuiltin }
    }

    var externalHardwareActiveDisplays: [Display] {
        activeDisplayList.filter { !$0.isBuiltin && !$0.isSidecar && !$0.isAirplay && !$0.isFakeDummy }
    }

    var nonDummyDisplays: [Display] {
        activeDisplayList.filter { !$0.isDummy }
    }

    var nonDummyDisplay: Display? {
        nonDummyDisplays.first
    }

    var builtinActiveDisplays: [Display] {
        activeDisplays.values.filter(\.isBuiltin)
    }

    var externalDisplays: [Display] {
        displays.values.filter { !$0.isBuiltin }
    }

    var builtinDisplays: [Display] {
        displays.values.filter(\.isBuiltin)
    }

    var builtinDisplay: Display? {
        builtinActiveDisplays.first
    }

    var sourceDisplay: Display? {
        guard let source = activeDisplays.values.first(where: \.isSource) else {
            if let builtin = builtinDisplay {
                mainAsync { builtin.isSource = true }
                return builtin
            }
            return nil
        }

        return source
    }

    var targetDisplays: [Display] {
        activeDisplays.values.filter { !$0.isSource }
    }
    @AtomicLock var displays: [CGDirectDisplayID: Display] = [:] {
        didSet {
            activeDisplays = displays.filter { $1.active }
            activeDisplaysByReadableID = [String: Display](
                activeDisplays.map { _, display in (display.readableID, display) },
                uniquingKeysWith: first(this:other:)
            )
            activeDisplaysBySerial = [String: Display](
                activeDisplays.map { _, display in (display.serial, display) },
                uniquingKeysWith: first(this:other:)
            )
            if CachedDefaults[.autoXdrSensor] {
                xdrSensorTask = getSensorTask()
            }
        }
    }
    var activeDisplays: [CGDirectDisplayID: Display] {
        get { _activeDisplaysLock.around(ignoreMainThread: true) { _activeDisplays } }
        set {
            _activeDisplaysLock.around {
                _activeDisplays = newValue
                CachedDefaults[.hasActiveDisplays] = !_activeDisplays.isEmpty
                CachedDefaults[.hasActiveExternalDisplays] = !_activeDisplays.values.filter(\.isExternal).isEmpty
                onActiveDisplaysChange?()
                newValue.values.forEach { d in
                    d.updateCornerWindow()
                }

                mainAsync {
                    self.activeDisplayList = self._activeDisplays.values
                        .sorted { (d1: Display, d2: Display) -> Bool in d1.id < d2.id }
                        .reversed()
                }
                #if DEBUG
                    newValue.values.forEach {
                        $0.blackOutMirroringAllowed = true
                    }
                #endif
            }

            DDC.sync {
                Self.serials = newValue.mapValues(\.serial)
            }
        }
    }

    @Published var adaptiveMode: AdaptiveMode = DisplayController.getAdaptiveMode() {
        didSet {
            withoutApply {
                adaptiveModeKey = adaptiveMode.key
            }

            if adaptiveMode.key != .manual {
                lastNonManualAdaptiveMode = adaptiveMode
            }
            oldValue.stopWatching()
            if adaptiveMode.available {
                adaptiveMode.watch()
            }
        }
    }

    @Published var adaptiveModeKey: AdaptiveModeKey = DisplayController.getAdaptiveMode().key {
        didSet {
            guard apply else { return }
            guard adaptiveModeKey != .auto else {
                CachedDefaults[.overrideAdaptiveMode] = false

                let key = DisplayController.autoMode().key
                CachedDefaults[.adaptiveBrightnessMode] = key
                withoutApply {
                    adaptiveModeKey = key
                }
                return
            }
            CachedDefaults[.overrideAdaptiveMode] = true
            CachedDefaults[.adaptiveBrightnessMode] = adaptiveModeKey
        }
    }

    var firstDisplay: Display {
        if !displays.isEmpty {
            return displays.values.first(where: { d in d.active }) ?? displays.values.first!
        } else {
            #if TEST_MODE
                return TEST_DISPLAY
            #endif
            return GENERIC_DISPLAY
        }
    }

    var mainExternalDisplay: Display? {
        guard let screen = NSScreen.externalWithMouse ?? NSScreen.onlyExternalScreen,
              let id = screen.displayID
        else { return nil }

        return activeDisplays[id]
    }

    var nonCursorDisplays: [Display] {
        guard let cursorDisplay else { return [] }
        return activeDisplayList.filter { $0.id != cursorDisplay.id }
    }

    var mainDisplay: Display? {
        guard let screenID = NSScreen.main?.displayID else { return nil }
        return activeDisplays[screenID]
    }

    var nonMainDisplays: [Display] {
        guard let mainDisplay else { return [] }
        return activeDisplayList.filter { $0.id != mainDisplay.id }
    }

    var cursorDisplay: Display? {
        guard let screen = NSScreen.withMouse,
              let id = screen.displayID
        else { return nil }

        if let d = activeDisplays[id], !d.isDummy {
            return d
        }
        if let secondary = Display.getSecondaryMirrorScreenID(id), let d = activeDisplays[secondary], !d.isDummy {
            return d
        }
        return nil
    }

    var mainExternalOrCGMainDisplay: Display? {
        if let display = mainExternalDisplay, !display.isIndependentDummy {
            return display
        }

        let displays = activeDisplays.values.map { $0 }
        if displays.count == 1 {
            return displays[0]
        } else {
            for display in displays {
                if CGDisplayIsMain(display.id) == 1, !display.isIndependentDummy {
                    return display
                }
            }
        }
        return nil
    }

    var activeDisplayCount: Int {
        #if DEBUG
            return activeDisplayList.filter { !$0.isForTesting }.count
        #else
            return activeDisplayList.count
        #endif
    }

    var xdrContrastEnabled: Bool = Defaults[.xdrContrast] {
        didSet {
            guard activeDisplayCount == 1, let display = firstNonTestingDisplay,
                  display.control is AppleNativeControl || CachedDefaults[.allowHDREnhanceContrast]
            else { return }

            guard xdrContrastEnabled, display.enhanced else {
                setXDRContrast(0.0, now: true)
                return
            }

            setXDRContrast(xdrContrast, now: true)
            display.setIndependentSoftwareBrightness(display.softwareBrightness, withoutSettingContrast: true)
        }
    }

    var autoXdr: Bool = Defaults[.autoXdr] {
        didSet {
            guard !autoXdr else { return }
            activeDisplayList.filter(\.enhanced).forEach { $0.enhanced = false }
        }
    }

    var autoSubzero: Bool = Defaults[.autoSubzero] {
        didSet {
            guard !autoSubzero else { return }
            activeDisplayList.filter(\.subzero).forEach { $0.softwareBrightness = 1 }
        }
    }

    var screenIDs: Set<CGDirectDisplayID> = Set(NSScreen.onlineDisplayIDs) {
        didSet {
            guard screenIDs != oldValue else { return }
            log.info(
                "New screen IDs after screen configuration change",
                context: ["old": oldValue.commaSeparatedString, "new": screenIDs.commaSeparatedString]
            )
            reset()
        }
    }

    var autoXdrTipShowTask: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }

    var volumeHotkeysEnabled: Bool {
        CachedDefaults[.volumeKeysEnabled] || (
            !CachedDefaults[.volumeHotkeysControlAllMonitors] &&
                (
                    CachedDefaults[.hotkeys].first { $0.identifier == HotkeyIdentifier.volumeUp.rawValue }?.isEnabled ?? true
                        || CachedDefaults[.hotkeys].first { $0.identifier == HotkeyIdentifier.volumeDown.rawValue }?.isEnabled ?? true
                        || CachedDefaults[.hotkeys].first { $0.identifier == HotkeyIdentifier.muteAudio.rawValue }?.isEnabled ?? true
                )
        )
    }

    static func getAdaptiveMode() -> AdaptiveMode {
        if CachedDefaults[.overrideAdaptiveMode] {
            return CachedDefaults[.adaptiveBrightnessMode].mode
        } else {
            let mode = autoMode()
            return mode
        }
    }

    static func panel(with id: CGDirectDisplayID) -> MPDisplay? {
        guard id != kCGNullDirectDisplay else { return nil }
        guard let mgr = DisplayController.panelManager, mgr.tryLockAccess() else {
            return nil
        }
        defer { mgr.unlockAccess() }
        return mgr.display(withID: id.i32) as? MPDisplay
    }

    static func autoMode() -> AdaptiveMode {
        if let mode = SensorMode.specific.ifExternalSensorAvailable() {
            return mode
        } else if let mode = SyncMode.shared.ifAvailable() {
            return mode
        } else if let mode = SensorMode.specific.ifInternalSensorAvailable() {
            return mode
        } else if let mode = LocationMode.shared.ifAvailable() {
            return mode
        } else {
            return ManualMode.shared
        }
    }

    static func allDisplayProperties() -> [[String: Any]] {
        var propList: [[String: Any]] = []
        var ioIterator = io_iterator_t()

        guard IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceNameMatching("AppleCLCD2"), &ioIterator) == KERN_SUCCESS
        else {
            return propList
        }

        defer {
            assert(IOObjectRelease(ioIterator) == KERN_SUCCESS)
        }
        while case let ioService = IOIteratorNext(ioIterator), ioService != 0 {
            var serviceProperties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(ioService, &serviceProperties, kCFAllocatorDefault, IOOptionBits()) == KERN_SUCCESS,
                  let cfProps = serviceProperties,
                  let props = cfProps.takeRetainedValue() as? [String: Any]
            else {
                continue
            }
            propList.append(props)
        }
        return propList
    }

    static func armDisplayProperties(display: Display) -> [String: Any]? {
        // "DisplayAttributes" =
        // {"ProductAttributes"={"ManufacturerID"="GSM","YearOfManufacture"=2017,"SerialNumber"=314041,"ProductName"="LG Ultra
        // HD","LegacyManufacturerID"=7789,"ProductID"=23305,"WeekOfManufacture"=8}

        let allProps = allDisplayProperties()

        if let props = allProps.first(where: { props in
            guard let edidUUID = props["EDID UUID"] as? String else { return false }
            return display.matchesEDIDUUID(edidUUID)
        }) {
            log.info("Found ARM properties for display \(display) by EDID UUID")
            return props
        }

        let fullyMatchedProps = allProps.first(where: { props in
            guard let attrs = props["DisplayAttributes"] as? [String: Any],
                  let productAttrs = attrs["ProductAttributes"] as? [String: Any],
                  let manufactureYear = productAttrs["YearOfManufacture"] as? Int64,
                  let serial = productAttrs["SerialNumber"] as? Int64,
                  let name = productAttrs["ProductName"] as? String,
                  let vendorID = productAttrs["LegacyManufacturerID"] as? Int64,
                  let productID = productAttrs["ProductID"] as? Int64
            else { return false }
            return DisplayController.displayInfoDictFullMatch(
                display: display,
                name: name,
                serial: serial.i,
                productID: productID.i,
                manufactureYear: manufactureYear.i,
                vendorID: vendorID.i
            )
        })

        if let fullyMatchedProps {
            return fullyMatchedProps
        }

        let propScores = allProps.map { props -> ([String: Any], Int) in
            guard let attrs = props["DisplayAttributes"] as? [String: Any],
                  let productAttrs = attrs["ProductAttributes"] as? [String: Any],
                  let manufactureYear = productAttrs["YearOfManufacture"] as? Int64,
                  let serial = productAttrs["SerialNumber"] as? Int64,
                  let name = productAttrs["ProductName"] as? String,
                  let vendorID = productAttrs["LegacyManufacturerID"] as? Int64,
                  let productID = productAttrs["ProductID"] as? Int64
            else { return (props, 0) }

            let score = DisplayController.displayInfoDictPartialMatchScore(
                display: display,
                name: name,
                serial: serial.i,
                productID: productID.i,
                manufactureYear: manufactureYear.i,
                vendorID: vendorID.i
            )

            return (props, score)
        }

        return propScores.max(count: 1, sortedBy: { first, second in first.1 <= second.1 }).first?.0
    }

    static func getDisplays(
        includeVirtual: Bool = true,
        includeAirplay: Bool = false,
        includeProjector: Bool = false,
        includeDummy: Bool = false
    ) -> [CGDirectDisplayID: Display] {
        var ids = DDC.findExternalDisplays(
            includeVirtual: includeVirtual,
            includeAirplay: includeAirplay,
            includeProjector: includeProjector,
            includeDummy: includeDummy
        )
        if let builtinDisplayID = NSScreen.builtinDisplayID {
            ids.append(builtinDisplayID)
        }
        var serials = ids.map { Display.uuid(id: $0) }

        // Make sure serials are unique
        if serials.count != Set(serials).count {
            serials = zip(serials, ids).map { serial, id in "\(serial)-\(id)" }
        }

        let idForSerial = Dictionary(zip(serials, ids), uniquingKeysWith: first(this:other:))
        let serialForID = Dictionary(zip(ids, serials), uniquingKeysWith: first(this:other:))

        Display.applySource = false
        defer {
            Display.applySource = true
        }

        if AppDelegate.hdrWorkaround {
            restoreColorSyncSettings()
        }

        DisplayController.panelManager = MPDisplayMgr()
        guard let displayList = datastore.displays(serials: serials), !displayList.isEmpty else {
            let displays = ids.map { Display(id: $0, active: true) }

            #if DEBUG
                log.debug("STORING NEW DISPLAYS \(displays.map(\.serial))")
            #endif
            let storedDisplays = datastore.storeDisplays(displays)
            #if DEBUG
                log.debug("STORED NEW DISPLAYS \(storedDisplays.map(\.serial))")
            #endif

            printMirrors(displays)
            return Dictionary(
                storedDisplays.map { d in (d.id, d) },
                uniquingKeysWith: first(this:other:)
            )
        }

        // Update IDs after reconnection
        for display in displayList {
            defer { mainThread { display.active = true } }
            guard let newID = idForSerial[display.serial] else {
                continue
            }

            display.id = newID
            display.edidName = Display.printableName(newID)
            if display.name.isEmpty {
                display.name = display.edidName
            }
        }

        var displays = Dictionary(
            displayList.map { ($0.id, $0) },
            uniquingKeysWith: first(this:other:)
        )

        // Initialize displays that were never seen before
        let newDisplayIDs = Set(ids).subtracting(Set(displays.keys))
        for id in newDisplayIDs {
            displays[id] = Display(id: id, serial: serialForID[id], active: true)
        }

        #if DEBUG
            log.debug("STORING UPDATED DISPLAYS \(displays.values.map(\.serial))")
        #endif
        let storedDisplays = datastore.storeDisplays(displays.values.map { $0 })
        #if DEBUG
            log.debug("STORED UPDATED DISPLAYS \(storedDisplays.map(\.serial))")
        #endif

        printMirrors(storedDisplays)
        return Dictionary(storedDisplays.map { d in (d.id, d) }, uniquingKeysWith: first(this:other:))
    }

    static func printMirrors(_ displays: [Display]) {
        for d in displays {
            log.debug("Primary mirror for \(d): \(String(describing: d.primaryMirrorScreen))")
            log.debug("Secondary mirror for \(d): \(String(describing: d.secondaryMirrorScreenID))")
        }
    }

    func setupXdrTask() {
        autoXdrSensorShowOSDPublisher
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [self] change in
                autoXdrSensorShowOSD = change.newValue
            }.store(in: &observers)

        autoXdrSensorPublisher
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [self] change in
                autoXdrSensor = change.newValue
                guard let display = builtinDisplay, display.isMacBookXDR, let lux = SensorMode.getInternalSensorLux()?.f else {
                    xdrSensorTask = nil
                    return
                }
                internalSensorLux = lux
                xdrSensorTask = change.newValue ? getSensorTask() : nil
            }.store(in: &observers)

        if CachedDefaults[.autoXdrSensor] {
            xdrSensorTask = getSensorTask()
        }
    }

    func retryAutoBlackoutLater() {
        if autoBlackoutPending, let d = builtinDisplay, !d.blackOutEnabled {
            log.info("Retrying Auto Blackout later")
            d.showAutoBlackOutOSD()
            autoBlackoutPublisher.send(true)
        }
    }

    func cancelAutoXdr() {
        guard autoXdrPendingEnabled || autoXdrPendingDisabled else { return }
        log.info("Cancelling Auto XDR")

        lastXDRAbortDate = Date()
        xdrState = autoXdrPendingEnabled ? .disabledManually : .enabledManually

        builtinDisplay?.autoOsdWindowController?.close()
        builtinDisplay?.autoOsdWindowController = nil
        autoXdrAmbientLightPublisher.send(nil)
    }

    func cancelAutoBlackout() {
        guard autoBlackoutPending else { return }
        log.info("Cancelling Auto Blackout")
        builtinDisplay?.autoOsdWindowController?.close()
        builtinDisplay?.autoOsdWindowController = nil
        autoBlackoutPublisher.send(false)
    }

    @inline(__always) func withoutApply(_ block: () -> Void) {
        apply = false
        block()
        apply = true
    }

    func getCurrentAudioDisplay() -> Display? {
        guard let audioDevice = simplyCA.defaultOutputDevice,
              !audioDevice.canSetVirtualMainVolume(scope: .output),
              volumeHotkeysEnabled
        else {
            return nil
        }

        if let audioDeviceUid = audioDevice.uid,
           let display = activeDisplayList.filter({ $0.audioIdentifier != nil })
           .first(where: { audioDeviceUid.contains($0.audioIdentifier!) })
        {
            log.info("Matched Audio Device UID \(audioDeviceUid) with Display UID \(display.audioIdentifier ?? "")")
            return display
        } else {
            log.info("Audio Device UID \(audioDevice.uid ?? "")")
            log.info("Audio Display UID \(activeDisplayList.map { ($0.name, $0.audioIdentifier ?? "nil") })")
        }

        let audioDeviceName = audioDevice.name
        guard !audioDeviceName.isEmpty else { return nil }

        guard let name = activeDisplays.values.map(\.name).fuzzyFind(audioDeviceName)
        else {
            return mainExternalOrCGMainDisplay
        }

        return activeDisplays.values.first(where: { $0.name == name }) ?? mainExternalOrCGMainDisplay
    }

    func autoAdaptMode() {
        guard !CachedDefaults[.overrideAdaptiveMode] else {
            if adaptiveMode.available {
                adaptiveMode.watch()
            } else {
                adaptiveMode.stopWatching()
            }
            return
        }

        let mode = DisplayController.autoMode()
        if mode.key != adaptiveMode.key {
            adaptiveMode = mode
            CachedDefaults[.adaptiveBrightnessMode] = mode.key
        }
    }

    func manualAppBrightnessContrast(for display: Display, app: AppException) -> (Brightness, Contrast) {
        let br: Brightness
        let cr: Contrast

        if CachedDefaults[.mergeBrightnessContrast] {
            (br, cr) = display.sliderValueToBrightnessContrast(app.manualBrightnessContrast)
            log.debug("App offset: \(app.identifier) \(app.name) \(app.manualBrightnessContrast) \(br) \(cr)")
        } else {
            br = display.sliderValueToBrightness(app.manualBrightness).uint16Value
            cr = display.sliderValueToBrightness(app.manualContrast).uint16Value
            log.debug("App offset: \(app.identifier) \(app.name) \(app.manualBrightness) \(app.manualContrast) \(br) \(cr)")
        }

        return (br, cr)
    }

    func appBrightnessContrastOffset(for display: Display) -> (Int, Int)? {
        guard lunarProActive, !display.enhanced, let exceptions = runningAppExceptions, !exceptions.isEmpty,
              let screen = display.nsScreen
        else {
            log.debug("!exceptions: \(runningAppExceptions ?? [])")
            log.debug("!screen: \(display.nsScreen?.description ?? "")")
            log.debug("!xdr: \(display.enhanced)")
            mainAsync { display.appPreset = nil }
            return nil
        }
        log.debug("exceptions: \(exceptions)")
        log.debug("screen: \(screen)")

        if displayController.activeDisplays.count == 1, let app = runningAppExceptions.first,
           app.runningApps?.first?.windows(appException: app) == nil
        {
            log.debug("App offset (single monitor): \(app.identifier) \(app.name) \(app.brightness) \(app.contrast)")
            mainAsync { display.appPreset = app }

            if adaptiveModeKey == .manual {
                guard !display.isBuiltin || app.applyBuiltin else { return nil }
                let (br, cr) = manualAppBrightnessContrast(for: display, app: app)

                return (br.i, cr.i)
            }

            return (app.brightness.i, app.contrast.i)
        }

        if let app = activeWindow(on: screen)?.appException {
            mainAsync { display.appPreset = app }
            if adaptiveModeKey == .manual {
                guard !display.isBuiltin || app.applyBuiltin else { return nil }
                let (br, cr) = manualAppBrightnessContrast(for: display, app: app)

                return (br.i, cr.i)
            }
            return (app.brightness.i, app.contrast.i)
        }

        let windows = exceptions.compactMap { (app: AppException) -> FlattenSequence<[[AXWindow]]>? in
            guard let runningApps = app.runningApps, !runningApps.isEmpty else { return nil }
            return runningApps.compactMap { (a: NSRunningApplication) -> [AXWindow]? in
                a.windows(appException: app)?.filter { window in
                    !window.minimized && window.size != .zero && window.screen != nil
                }
            }.joined()
        }.joined()

        let windowsOnScreen = windows.filter { w in w.screen?.displayID == screen.displayID }
        guard let focusedWindow = windowsOnScreen.first(where: { $0.focused }) ?? windowsOnScreen.first,
              let app = focusedWindow.appException
        else {
            mainAsync { display.appPreset = nil }
            return nil
        }

        log.debug("App offset: \(app.identifier) \(app.name) \(app.brightness) \(app.contrast)")
        mainAsync { display.appPreset = app }

        if adaptiveModeKey == .manual {
            guard !display.isBuiltin || app.applyBuiltin else { return nil }
            let (br, cr) = manualAppBrightnessContrast(for: display, app: app)

            return (br.i, cr.i)
        }

        return (app.brightness.i, app.contrast.i)
    }

    func removeDisplay(serial: String) {
        guard let display = displays.values.first(where: { $0.serial == serial }) else { return }
        displays.removeValue(forKey: display.id)
        CachedDefaults[.displays] = displays.values.map { $0 }
        CachedDefaults[.hotkeys] = CachedDefaults[.hotkeys].filter { hk in
            if display.hotkeyIdentifiers.contains(hk.identifier) {
                hk.unregister()
                return false
            }
            return true
        }
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = adaptiveBrightnessModePublisher
            .debounce(for: .milliseconds(10), scheduler: RunLoop.main)
            .sink { [weak self] change in
                adaptiveCrumb("Changed mode from \(change.oldValue) to \(change.newValue)")
                guard let self else { return }

                guard !self.pausedAdaptiveModeObserver else {
                    return
                }

                Defaults.withoutPropagation {
                    self.pausedAdaptiveModeObserver = true
                    self.adaptiveMode = change.newValue.mode
                    self.pausedAdaptiveModeObserver = false
                }
            }
    }

    func toggle() {
        if adaptiveModeKey == .manual {
            enable()
        } else {
            disable()
        }
    }

    func disable() {
        if adaptiveModeKey != .manual {
            adaptiveMode = ManualMode.shared
        }
        lastModeWasAuto = !CachedDefaults[.overrideAdaptiveMode]
        if lastModeWasAuto {
            CachedDefaults[.overrideAdaptiveMode] = true
        }
        CachedDefaults[.adaptiveBrightnessMode] = AdaptiveModeKey.manual
    }

    func enable(mode: AdaptiveModeKey? = nil) {
        if let newMode = mode {
            adaptiveMode = newMode.mode
        } else if lastModeWasAuto {
            CachedDefaults[.overrideAdaptiveMode] = false
            adaptiveMode = DisplayController.getAdaptiveMode()
        } else if lastNonManualAdaptiveMode.available, lastNonManualAdaptiveMode.key != .manual {
            adaptiveMode = lastNonManualAdaptiveMode
        } else {
            CachedDefaults[.overrideAdaptiveMode] = false
            adaptiveMode = DisplayController.getAdaptiveMode()
        }
        CachedDefaults[.adaptiveBrightnessMode] = adaptiveMode.key
        adaptBrightness(force: true)
    }

    func resetDisplayList(configurationPage: Bool = false, autoBlackOut: Bool? = nil) {
        resetDisplayListTask?.cancel()
        resetDisplayListTask = mainAsyncAfter(ms: 200) {
            self.resetDisplayListTask = nil
            self.getDisplaysLock.around {
                Self.panelManager = MPDisplayMgr()
                DDC.reset()

                let activeOldDisplays = self.displays.values.filter(\.active)
                self.displays = DisplayController.getDisplays(
                    includeVirtual: CachedDefaults[.showVirtualDisplays],
                    includeAirplay: CachedDefaults[.showAirplayDisplays],
                    includeProjector: CachedDefaults[.showProjectorDisplays],
                    includeDummy: CachedDefaults[.showDummyDisplays]
                )
                let activeNewDisplays = self.displays.values.filter(\.active)

                let d = self.displays.values
                if !d.contains(where: \.isSource),
                   let possibleSource = (d.first(where: \.isSmartBuiltin) ?? d.first(where: \.canChangeBrightnessDS))
                {
                    mainThread { possibleSource.isSource = true }
                }

                SyncMode.refresh()
                self.addSentryData()

                log.debug("Disabling BlackOut where the mirror does not exist anymore")
                for d in activeNewDisplays {
                    log.debug(
                        "\(d): blackOutEnabled=\(d.blackOutEnabled) blackOutEnabledWithoutMirroring=\(d.blackOutEnabledWithoutMirroring)"
                    )
                    guard d.blackOutEnabled, !d.blackOutEnabledWithoutMirroring, let panel = Self.panel(with: d.id),
                          !panel.isMirrored
                    else {
                        d.blackoutDisablerPublisher.send(false)
                        continue
                    }

                    log.info(
                        "Disabling BlackOut for \(d): blackOutEnabled=\(d.blackOutEnabled) isMirrored=\(panel.isMirrored) isMirrorMaster=\(panel.isMirrorMaster) mirrorMasterDisplayID=\(panel.mirrorMasterDisplayID)"
                    )
                    d.blackoutDisablerPublisher.send(false)
                }

                if let d = activeNewDisplays.first, activeNewDisplays.count == 1, d.isBuiltin, d.blackOutEnabled,
                   activeOldDisplays.count > 1
                {
                    log.info("Disabling BlackOut if we're left with only 1 screen")
                    mainAsync {
                        lastBlackOutToggleDate = .distantPast
                        displayController.blackOut(display: d.id, state: .off)
                    }
                }

                guard let autoBlackOut, autoBlackOut, lunarProOnTrial || lunarProActive else { return }
                if let d = activeOldDisplays.first, activeOldDisplays.count == 1, d.isBuiltin, activeNewDisplays.count > 1,
                   !d.blackOutEnabled
                {
                    log.info("Activating Auto Blackout")
                    self.autoBlackoutPending = true
                    self.builtinDisplay?.showAutoBlackOutOSD()
                    self.autoBlackoutPublisher.send(true)
                } else {
                    log.info(
                        "Not activating Auto Blackout: activeOldDisplays.count=\(activeOldDisplays.count) activeNewDisplays.count=\(activeNewDisplays.count)"
                    )
                }
            }

            if CachedDefaults[.autoXdrSensor] {
                self.xdrSensorTask = self.getSensorTask()
            }
            self.reconfigure()
            mainAsync {
                appDelegate!.recreateWindow(
                    page: configurationPage ? Page.settings.rawValue : nil
                )
                NotificationCenter.default.post(name: displayListChanged, object: nil)
            }
        }
    }

    func reconfigure() {
        reconfigureTask = nil

        guard adaptiveMode.available else { return }
        reconfigureTask = Repeater(every: 1, times: 3, name: "DisplayControllerReconfigure") { [self] in
            adaptiveMode.withForce {
                activeDisplays.values.forEach { d in
                    d.updateCornerWindow()
                    if d.softwareBrightness == 1.0 {
                        d.resetSoftwareControl()
                    }
                }

                log.info("Removing old overlays")
                removeOldOverlays()

                log.info("Re-adapting brightness after reconfiguration")
                adaptBrightness(force: true)
            }
        }
    }

    func removeOldOverlays() {
        windowControllerQueue.sync {
            let idsWithWindows: Set<CGDirectDisplayID> = Set(
                Thread.current.threadDictionary.allKeys
                    .compactMap { $0 as? String }
                    .filter { $0.starts(with: "window-") }
                    .compactMap { $0.split(separator: "-").last?.u32 }
            )
            let currentIDs: Set<CGDirectDisplayID> = Set(displays.keys)

            let idsToRemove = idsWithWindows.subtracting(currentIDs)
            Thread.current.threadDictionary.allKeys
                .compactMap { $0 as? String }
                .filter {
                    guard $0.starts(with: "window-"), let id = $0.split(separator: "-").last?.u32 else { return false }
                    return idsToRemove.contains(id)
                }.forEach { key in
                    guard let wc = Thread.current.threadDictionary[key] as? NSWindowController else {
                        return
                    }
                    wc.close()
                    Thread.current.threadDictionary.removeObject(forKey: key)
                }
        }
    }

    func shouldPromptAboutFallback(_ display: Display) -> Bool {
//        guard !display.neverFallbackControl, display.enabledControls[.gamma] ?? false else { return false }
        guard !display.neverFallbackControl, !display.isBuiltin, !AppleNativeControl.isAvailable(for: display),
              !display.isAppleDisplay() else { return false }

        if !SyncMode.possibleClamshellModeSoon, !displayController.screensSleeping,
           let screen = display.nsScreen, !screen.visibleFrame.isEmpty, timeSince(display.lastConnectionTime) > 10,
           let control = display.control, !control.isResponsive()
        {
            if let promptTime = display.fallbackPromptTime {
                return promptTime + 20.minutes < Date()
            }
            return true
        }

        return false
    }

    func cleanup() {
        log.info("Going down")

        Defaults[.debug] = false
        Defaults[.streamLogs] = false
        Defaults[.showOptionsMenu] = false

        appDelegate?.valuesReaderThread = nil
        activeDisplayList.filter(\.ambientLightCompensationEnabledByUser).forEach { d in
            d.systemAdaptiveBrightness = true
        }
        if xdrContrastEnabled, displayController.xdrContrast > 0 {
            setXDRContrast(0, now: true)
        }

        activeDisplayList.filter(\.faceLightEnabled).forEach { display in
            display.disableFaceLight(smooth: false)
            display.save(now: true)
        }
        activeDisplayList.filter(\.blackOutEnabled).forEach { display in
            display.disableBlackOut()
            display.save(now: true)
        }
    }

    func averageDDCWriteNanoseconds(for id: CGDirectDisplayID, ns: UInt64) {
        mainAsync { [self] in
            guard let writens = averageDDCWriteNanoseconds[id], writens > 0 else {
                averageDDCWriteNanoseconds[id] = ns
                return
            }

            averageDDCWriteNanoseconds[id] = (writens + ns) / 2
        }
    }

    func averageDDCReadNanoseconds(for id: CGDirectDisplayID, ns: UInt64) {
        mainAsync { [self] in
            guard let readns = averageDDCReadNanoseconds[id], readns > 0 else {
                averageDDCReadNanoseconds[id] = ns
                return
            }

            averageDDCReadNanoseconds[id] = (readns + ns) / 2
        }
    }

    func promptAboutFallback(_ display: Display) {
        log.warning("Non-responsive display", context: display.context)
        display.fallbackPromptTime = Date()
        let semaphore = DispatchSemaphore(value: 0, name: "Non-responsive Control Watcher Prompt")
        let completionHandler = { (fallbackToGamma: NSApplication.ModalResponse) in
            if fallbackToGamma == .alertFirstButtonReturn {
                if let control = display.control?.displayControl {
                    display.enabledControls[control] = false
                }
                display.gammaEnabled = true
                display.control = GammaControl(display: display)
                display.setGamma()
            }
            if fallbackToGamma == .alertThirdButtonReturn {
                display.neverFallbackControl = true
            }
            semaphore.signal()
        }

        if display.alwaysFallbackControl {
            completionHandler(.alertFirstButtonReturn)
            return
        }

        let window = mainThread { appDelegate!.windowController?.window }

        let resp = ask(
            message: "Non-responsive display \"\(display.name)\"",
            info: """
            `\(display.name.trimmed)` is not responding to commands in **\(display.control!.str)** mode.

            Do you want to fallback to `Software Dimming`?

            Note: adjust the monitor to `[BRIGHTNESS: 100%, CONTRAST: 70%]` manually using its physical buttons to allow for a full range in software dimming.
            """,
            okButton: "Yes",
            cancelButton: "Not now",
            thirdButton: "No, never ask again",
            screen: display.nsScreen ?? display.primaryMirrorScreen,
            window: window,
            suppressionText: "Always fallback to software controls for this display when needed",
            onSuppression: { fallback in
                display.alwaysFallbackControl = fallback
                display.save()
            },
            onCompletion: completionHandler,
            unique: true,
            waitTimeout: 60.seconds,
            wide: true,
            markdown: true
        )
        if window == nil {
            completionHandler(resp)
        } else {
            semaphore.wait(for: nil)
        }
    }

    func watchControlAvailability() {
        guard controlWatcherTask == nil else {
            return
        }

        controlWatcherTask = Repeater(every: 15, name: CONTROL_WATCHER_TASK_KEY) { [self] in
            guard !displayController.screensSleeping, completedOnboarding else { return }
            for display in activeDisplays.values {
                display.control = display.getBestControl()
                if shouldPromptAboutFallback(display) {
                    asyncNow { self.promptAboutFallback(display) }
                }
            }
        }
    }

    func addSentryData() {
        guard CachedDefaults[.enableSentry] else { return }
        SentrySDK.configureScope { [weak self] scope in
            log.info("Creating Sentry extra context")
            scope.setExtra(value: datastore.settingsDictionary(), key: "settings")
            if var armProps = SyncMode.getArmBuiltinDisplayProperties() {
                armProps.removeValue(forKey: "TimingElements")
                armProps.removeValue(forKey: "ColorElements")

                var computedProps = [String: String]()
                if let (b, c) = SyncMode.readBrightnessContrast() {
                    computedProps["Brightness"] = b.str(decimals: 4)
                    computedProps["Contrast"] = c.str(decimals: 4)
                }

                var br: Float = cap(Float(armProps["property"] as! Int) / MAX_IOMFB_BRIGHTNESS.f, minVal: 0.0, maxVal: 1.0)
                computedProps["ComputedFromproperty"] = br.str(decimals: 4)
                if let id = self?.builtinDisplay?.id {
                    DisplayServicesGetLinearBrightness(id, &br)
                    computedProps["DisplayServicesGetLinearBrightness"] = br.str(decimals: 4)
                }
                armProps["ComputedProps"] = computedProps

                if let encoded = try? encoder.encode(ForgivingEncodable(armProps)),
                   let compressed = encoded.gzip()?.base64EncodedString()
                {
                    scope.setExtra(value: compressed, key: "armBuiltinProps")
                }
            } else {
                scope.setExtra(value: SyncMode.readBrightnessIOKit(), key: "builtinDisplayBrightnessIOKit")
            }
            scope.setTag(value: String(describing: self?.lidClosed ?? isLidClosed()), key: "lidClosed")

            guard let self else { return }
            for display in self.activeDisplayList {
                display.addSentryData()
                if display.isUltraFine() {
                    scope.setTag(value: "true", key: "ultrafine")
                    continue
                }
                if display.isThunderbolt() {
                    scope.setTag(value: "true", key: "thunderbolt")
                    continue
                }
                if display.isLEDCinema() {
                    scope.setTag(value: "true", key: "ledcinema")
                    continue
                }
                if display.isCinema() {
                    scope.setTag(value: "true", key: "cinema")
                    continue
                }
                if display.isSidecar {
                    scope.setTag(value: "true", key: "sidecar")
                }
                if display.isAirplay {
                    scope.setTag(value: "true", key: "airplay")
                }
                if display.isVirtual {
                    scope.setTag(value: "true", key: "virtual")
                }
                if display.isProjector {
                    scope.setTag(value: "true", key: "projector")
                }
                if display.isDummy {
                    scope.setTag(value: "true", key: "dummy")
                    continue
                }
            }
        }
    }

    func adaptiveModeString(last: Bool = false) -> String {
        let mode: AdaptiveModeKey
        if last {
            mode = lastNonManualAdaptiveMode.key
        } else {
            mode = adaptiveModeKey
        }

        return mode.str
    }

    func activateClamshellMode() {
        if adaptiveModeKey == .sync {
            clamshellMode = true
            disable()
        }
    }

    func deactivateClamshellMode() {
        if adaptiveModeKey == .manual {
            clamshellMode = false
            enable()
        }
    }

    func manageClamshellMode() {
        lidClosed = isLidClosed()
        SyncMode.refresh()
        log.info("Lid closed: \(lidClosed)")
        if CachedDefaults[.enableSentry] {
            SentrySDK.configureScope { [weak self] scope in
                guard let self else { return }
                scope.setTag(value: String(describing: self.lidClosed), key: "clamshellMode")
            }
        }

        guard Sysctl.isMacBook, CachedDefaults[.clamshellModeDetection], SyncMode.sourceDisplay?.isBuiltin ?? true
        else {
            return
        }

        if lidClosed {
            activateClamshellMode()
        } else if clamshellMode {
            deactivateClamshellMode()
        }
    }

    func listenForRunningApps() {
        let appIdentifiers = NSWorkspace.shared.runningApplications.map { app in app.bundleIdentifier }.compactMap { $0 }
        runningAppExceptions = datastore.appExceptions(identifiers: appIdentifiers) ?? []
        adaptBrightness()

        NSWorkspace.shared.publisher(for: \.runningApplications, options: [.new])
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [self] change in
                let identifiers = change.compactMap(\.bundleIdentifier)

                if identifiers.contains(FLUX_IDENTIFIER),
                   let app = change.first(where: { app in app.bundleIdentifier == FLUX_IDENTIFIER }),
                   let display = activeDisplays.values.first(where: { d in d.hasSoftwareControl }),
                   let control = display.control as? GammaControl
                {
                    control.fluxChecker(flux: app)
                }

                runningAppExceptions = datastore.appExceptions(identifiers: Array(identifiers.uniqued())) ?? []
                log.info("New running applications: \(runningAppExceptions.map(\.name))")
                adaptBrightness()
            }
            .store(in: &observers)
    }

    func fetchValues(for displays: [Display]? = nil) {
        for display in displays ?? activeDisplays.values.map({ $0 }) {
            display.refreshBrightness()
            display.refreshContrast()
            display.refreshVolume()
            // display.refreshInput()
            display.refreshColors()
        }
    }

    func adaptBrightness(for display: Display, force: Bool = false) {
        guard adaptiveMode.available else { return }
        adaptiveMode.withForce(force || display.force) {
            self.adaptiveMode.adapt(display)
        }
    }

    func adaptBrightness(for displays: [Display]? = nil, force: Bool = false) {
        guard adaptiveMode.available else { return }
        for display in (displays ?? activeDisplayList).filter({ !$0.blackOutEnabled }) {
            adaptiveMode.withForce(force || display.force) {
                guard !display.enhanced else {
                    display.brightness = display.brightness
                    display.softwareBrightness = display.softwareBrightness
                    return
                }
                self.adaptiveMode.adapt(display)
            }
        }
    }

    func setBrightnessPercent(value: Int8, for displays: [Display]? = nil, now: Bool = false) {
        let manualMode = (adaptiveMode as? ManualMode) ?? ManualMode.specific
        let displays = displays ?? activeDisplays.values.map { $0 }

        displays.forEach { display in
            guard CachedDefaults[.hotkeysAffectBuiltin] || !display.isBuiltin,
                  !display.lockedBrightness || display.hasSoftwareControl
            else { return }

            let set = {
                let minBr = display.minBrightness.intValue
                display.brightness = manualMode.compute(
                    percent: value,
                    minVal: (display.isBuiltin && minBr == 0) ? 1 : minBr,
                    maxVal: display.maxBrightness.intValue
                )
            }
            if now {
                set()
            } else {
                mainAsyncAfter(ms: 1, set)
            }
        }
    }

    func setContrastPercent(value: Int8, for displays: [Display]? = nil, now: Bool = false) {
        let manualMode = (adaptiveMode as? ManualMode) ?? ManualMode.specific
        let displays = displays ?? activeDisplays.values.map { $0 }

        displays.forEach { display in
            guard !display.isBuiltin, !display.lockedContrast else { return }

            let set = {
                display.contrast = manualMode.compute(
                    percent: value,
                    minVal: display.minContrast.intValue,
                    maxVal: display.maxContrast.intValue
                )
            }
            if now {
                set()
            } else {
                mainAsyncAfter(ms: 1, set)
            }
        }
    }

    func setBrightness(brightness: NSNumber, for displays: [Display]? = nil) {
        if let displays {
            displays.forEach { display in display.brightness = brightness }
        } else {
            activeDisplays.values.forEach { display in display.brightness = brightness }
        }
    }

    func setContrast(contrast: NSNumber, for displays: [Display]? = nil) {
        if let displays {
            displays.forEach { display in display.contrast = contrast }
        } else {
            activeDisplays.values.forEach { display in display.contrast = contrast }
        }
    }

    func toggleAudioMuted(for displays: [Display]? = nil, currentDisplay: Bool = false, currentAudioDisplay: Bool = true) {
        adjustValue(for: displays, currentDisplay: currentDisplay, currentAudioDisplay: currentAudioDisplay) { (display: Display) in
            display.audioMuted = !display.audioMuted
        }
    }

    func adjustVolume(by offset: Int, for displays: [Display]? = nil, currentDisplay: Bool = false, currentAudioDisplay: Bool = true) {
        adjustValue(for: displays, currentDisplay: currentDisplay, currentAudioDisplay: currentAudioDisplay) { (display: Display) in
            var value = getFilledChicletValue(display.volume.floatValue, offset: offset.f).i
            value = cap(value, minVal: MIN_VOLUME, maxVal: MAX_VOLUME)
            display.volume = value.ns
        }
    }

    func adjustBrightness(
        by offset: Int,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        builtinDisplay: Bool = false,
        sourceDisplay: Bool = false,
        mainDisplay: Bool = false,
        nonMainDisplays: Bool = false
    ) {
        guard checkRemainingAdjustments() else { return }

        adjustValue(
            for: displays,
            currentDisplay: currentDisplay,
            builtinDisplay: builtinDisplay,
            sourceDisplay: sourceDisplay,
            mainDisplay: mainDisplay,
            nonMainDisplays: nonMainDisplays
        ) { (display: Display) in
            guard !display.noControls, !display.blackOutEnabled else { return }
            if display.isBuiltin {
                guard builtinDisplay || currentDisplay || sourceDisplay || mainDisplay else { return }
            }

            var value = getFilledChicletValue(display.brightness.floatValue, offset: offset.f).i

            let minBrightness = display.minBrightness.intValue
            let maxBrightness = display.maxBrightness.intValue
            let oldValue = display.brightness.intValue
            value = cap(
                value,
                minVal: minBrightness,
                maxVal: maxBrightness
            )

            if autoSubzero || display.softwareBrightness < 1.0,
               !display.hasSoftwareControl, minBrightness <= 1, !display.isForTesting,
               (value == minBrightness && value == oldValue && timeSince(lastTimeBrightnessKeyPressed) < 3) ||
               (oldValue == minBrightness && display.softwareBrightness < 1.0)
            {
                display.forceShowSoftwareOSD = true
                display.softwareBrightness = cap(
                    getFilledChicletValue(
                        display.softwareBrightness,
                        offset: offset.f / 96,
                        thresholds: Display.SUBZERO_FILLED_CHICLETS_THRESHOLDS,
                        fillOffset: Display.FILLED_CHICLET_OFFSET
                    ),
                    minVal: 0.0,
                    maxVal: 1.0
                )
                if adaptiveModeKey != .manual {
                    display.insertBrightnessUserDataPoint(
                        adaptiveMode.brightnessDataPoint.last,
                        value.d,
                        modeKey: adaptiveModeKey
                    )
                }

                return
            }

            if autoXdr || display.softwareBrightness > 1.0 || display.enhanced,
               display.supportsEnhance, !display.isForTesting,
               (value == maxBrightness && value == oldValue && timeSince(lastTimeBrightnessKeyPressed) < 3) ||
               (oldValue == maxBrightness && display.softwareBrightness > Display.MIN_SOFTWARE_BRIGHTNESS),
               lunarProActive || lunarProOnTrial
            {
                if !display.enhanced {
                    display.handleEnhance(true, withoutSettingBrightness: true)
                }

                display.maxEDR = display.computeMaxEDR()

                let range = (display.maxSoftwareBrightness - Display.MIN_SOFTWARE_BRIGHTNESS)
                let softOffset = (offset.f / (96 * (1 / range)))
                let nextSoftwareBrightness = cap(
                    getFilledChicletValue(
                        display.softwareBrightness,
                        offset: softOffset,
                        thresholds: display.xdrFilledChicletsThresholds,
                        fillOffset: display.xdrFilledChicletOffset
                    ),
                    minVal: Display.MIN_SOFTWARE_BRIGHTNESS,
                    maxVal: display.maxSoftwareBrightness
                )

                display.forceShowSoftwareOSD = true
                display.softwareBrightness = nextSoftwareBrightness
                return
            }

            if CachedDefaults[.mergeBrightnessContrast] {
                let preciseValue: Double
                if !display.lockedBrightness || display.hasSoftwareControl {
                    preciseValue = mapNumber(
                        value.d,
                        fromLow: display.minBrightness.doubleValue,
                        fromHigh: display.maxBrightness.doubleValue,
                        toLow: 0,
                        toHigh: 100
                    ) / 100
                } else {
                    preciseValue = cap(display.preciseBrightnessContrast + (offset.d / 100), minVal: 0.0, maxVal: 1.0)
                }

                withoutSlowTransition {
                    display.preciseBrightnessContrast = preciseValue
                }
            } else {
                withoutSlowTransition {
                    display.brightness = value.ns
                }
            }

            if adaptiveModeKey != .manual {
                display.insertBrightnessUserDataPoint(
                    adaptiveMode.brightnessDataPoint.last,
                    value.d,
                    modeKey: adaptiveModeKey
                )
            }
        }
    }

    @inline(__always) func withoutSlowTransition(_ block: () -> Void) {
        guard brightnessTransition == .slow else {
            block()
            return
        }

        brightnessTransition = .smooth
        block()
        brightnessTransition = .slow
    }

    func adjustContrast(
        by offset: Int,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        sourceDisplay: Bool = false,
        mainDisplay: Bool = false,
        nonMainDisplays: Bool = false
    ) {
        guard checkRemainingAdjustments() else { return }

        adjustValue(
            for: displays,
            currentDisplay: currentDisplay,
            sourceDisplay: sourceDisplay,
            mainDisplay: mainDisplay,
            nonMainDisplays: nonMainDisplays
        ) { (display: Display) in
            guard !display.isBuiltin, !display.blackOutEnabled else { return }

            var value = getFilledChicletValue(display.contrast.floatValue, offset: offset.f).i

            value = cap(
                value,
                minVal: display.minContrast.intValue,
                maxVal: display.maxContrast.intValue
            )

            withoutSlowTransition {
                display.contrast = value.ns
            }

            if adaptiveModeKey != .manual {
                display.insertContrastUserDataPoint(
                    adaptiveMode.contrastDataPoint.last,
                    value.d,
                    modeKey: adaptiveModeKey
                )
            }
        }
    }

    func adjustValue(
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        currentAudioDisplay: Bool = false,
        builtinDisplay: Bool = false,
        sourceDisplay: Bool = false,
        mainDisplay: Bool = false,
        nonMainDisplays: Bool = false,
        _ setValue: (Display) -> Void
    ) {
        if currentAudioDisplay {
            if let display = self.currentAudioDisplay {
                setValue(display)
            }
        } else if currentDisplay {
            if let display = cursorDisplay {
                if let mirrors = display.displaysInMirrorSet {
                    mirrors.filter { !$0.blackOutEnabled }.forEach { display in setValue(display) }
                } else {
                    setValue(display)
                }
            }
        } else if builtinDisplay {
            if let display = self.builtinDisplay {
                setValue(display)
            }
        } else if sourceDisplay {
            if let display = self.sourceDisplay {
                setValue(display)
            }
        } else if mainDisplay {
            if let display = self.mainDisplay {
                setValue(display)
            }
        } else if nonMainDisplays {
            self.nonMainDisplays.forEach { display in
                setValue(display)
            }
        } else if let displays {
            displays.forEach { display in
                setValue(display)
            }
        } else {
            activeDisplayList.forEach { display in
                setValue(display)
            }
        }
    }

    func getFilledChicletValue(_ value: Float, offset: Float, thresholds: [Float]? = nil, fillOffset: Float = 6) -> Float {
        let newValue = value + offset
        guard abs(offset) == fillOffset else { return newValue }

        let thresholds = thresholds ?? FILLED_CHICLETS_THRESHOLDS

        let diffs = thresholds - newValue
        if let index = abs(diffs).enumerated().min(by: { $0.element <= $1.element })?.offset {
            let backupIndex = cap(index + (offset < 0 ? -1 : 1), minVal: 0, maxVal: thresholds.count - 1)
            let chicletValue = thresholds[index]
            return chicletValue != value ? chicletValue : thresholds[backupIndex]
        }
        return newValue
    }

    func gammaUnlock(for displays: [Display]? = nil) {
        (displays ?? self.displays.values.map { $0 }).forEach { $0.gammaUnlock() }
    }
}

let displayController = DisplayController()
let FILLED_CHICLETS_THRESHOLDS: [Float] = [0, 6, 12, 18, 24, 31, 37, 43, 50, 56, 62, 68, 75, 81, 87, 93, 100]
