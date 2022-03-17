//
//  DisplayController.swift
//  Lunar
//
//  Created by Alin on 02/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import AXSwift
import Cocoa
import Combine
import CoreLocation
import Defaults
import Foundation
import FuzzyFind
import Sentry
import Solar
import Surge
import SwiftDate
import SwiftyJSON

// MARK: - AVServiceMatch

enum AVServiceMatch {
    case byEDIDUUID
    case byProductAttributes
}

// MARK: - DisplayController

class DisplayController: ObservableObject {
    // MARK: Lifecycle

    init() {
        watchControlAvailability()
        watchModeAvailability()
        watchScreencaptureProcess()
        initObservers()
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        cancelTask(CONTROL_WATCHER_TASK_KEY)
        cancelTask(MODE_WATCHER_TASK_KEY)
        cancelTask(SCREENCAPTURE_WATCHER_TASK_KEY)
    }

    // MARK: Internal

    static var panelManager: MPDisplayMgr? = MPDisplayMgr()

    let getDisplaysLock = NSRecursiveLock()
    @Atomic var lidClosed: Bool = isLidClosed()
    var clamshellMode = false

    var appObserver: NSKeyValueObservation?
    @AtomicLock var runningAppExceptions: [AppException]!

    var onActiveDisplaysChange: (() -> Void)?
    var _activeDisplaysLock = NSRecursiveLock()
    var _activeDisplays: [CGDirectDisplayID: Display] = [:]
    var activeDisplaysByReadableID: [String: Display] = [:]
    var lastNonManualAdaptiveMode: AdaptiveMode = DisplayController.getAdaptiveMode()
    var lastModeWasAuto: Bool = !CachedDefaults[.overrideAdaptiveMode]

    var onAdapt: ((Any) -> Void)?

    var pausedAdaptiveModeObserver = false
    var adaptiveModeObserver: Cancellable?

    var fallbackPromptTime = [CGDirectDisplayID: Date]()

    var overrideAdaptiveModeObserver: Cancellable?
    var pausedOverrideAdaptiveModeObserver = false

    var observers: Set<AnyCancellable> = []

    lazy var currentAudioDisplay: Display? = getCurrentAudioDisplay()

    let SCREENCAPTURE_WATCHER_TASK_KEY = "screencaptureWatcherTask"
    let MODE_WATCHER_TASK_KEY = "modeWatcherTask"
    let CONTROL_WATCHER_TASK_KEY = "controlWatcherTask"

    @Published var activeDisplayList: [Display] = []

    static func displayInfoDictPartialMatchScore(
        display: Display,
        name: String,
        serial: Int,
        productID: Int,
        manufactureYear: Int,
        manufacturer _: String? = nil,
        vendorID: Int? = nil,
        width: Int? = nil,
        height: Int? = nil
    ) -> Int {
        var score = (display.edidName.lowercased() == name.lowercased()).i

        let infoDict = display.infoDictionary

        if let displayYearManufacture = infoDict[kDisplayYearOfManufacture] as? Int64, displayYearManufacture != 0 {
            score += (displayYearManufacture == manufactureYear).i
        }
        if let displaySerialNumber = infoDict[kDisplaySerialNumber] as? Int64, abs(displaySerialNumber.i - serial) < 3 {
            score += 3 - abs(displaySerialNumber.i - serial)
        }
        if let displayProductID = infoDict[kDisplayProductID] as? Int64, abs(displayProductID.i - productID) < 3 {
            score += 3 - abs(displayProductID.i - productID)
        }
        if let vendorID = vendorID, let displayVendorID = infoDict[kDisplayVendorID] as? Int64,
           abs(displayVendorID.i - vendorID) < 3
        {
            score += 3 - abs(displayVendorID.i - vendorID)
        }

        if let width = width, let displayWidth = infoDict["kCGDisplayPixelWidth"] as? Int64,
           abs(displayWidth.i - width) < 3
        {
            score += 3 - abs(displayWidth.i - width)
        }

        if let height = height, let displayHeight = infoDict["kCGDisplayPixelHeight"] as? Int64,
           abs(displayHeight.i - height) < 3
        {
            score += 3 - abs(displayHeight.i - height)
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
        let infoDict = display.infoDictionary
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

        if let vendorID = vendorID {
            matches = matches || displayVendorID == vendorID
        }

        if let width = width, let displayWidth = infoDict["kCGDisplayPixelWidth"] as? Int64 {
            matches = matches || displayWidth == width
        }

        if let height = height, let displayHeight = infoDict["kCGDisplayPixelHeight"] as? Int64 {
            matches = matches || displayHeight == height
        }

        return matches
    }

    func watchModeAvailability() {
        asyncNow { [self] in
            guard !taskIsRunning(MODE_WATCHER_TASK_KEY) else {
                return
            }

            guard !pausedOverrideAdaptiveModeObserver else { return }

            pausedOverrideAdaptiveModeObserver = true
            asyncEvery(5.seconds, uniqueTaskKey: MODE_WATCHER_TASK_KEY, queue: .main) { [weak self] in
                guard !screensSleeping.load(ordering: .relaxed), let self = self else { return }
                self.autoAdaptMode()
            }
            pausedOverrideAdaptiveModeObserver = false
        }
    }

    func watchScreencaptureProcess() {
        asyncNow { [self] in
            guard !taskIsRunning(SCREENCAPTURE_WATCHER_TASK_KEY) else {
                return
            }

            asyncEvery(1.seconds, uniqueTaskKey: SCREENCAPTURE_WATCHER_TASK_KEY, queue: .main) { [weak self] in
                guard !screensSleeping.load(ordering: .relaxed), let self = self,
                      self.activeDisplayList.contains(where: { $0.hasSoftwareControl && !$0.supportsGamma })
                else { return }
                self.screencaptureIsRunning.send(processIsRunning("/usr/sbin/screencapture", nil))
            }
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
            cancelTask(self.CONTROL_WATCHER_TASK_KEY)
            cancelTask(self.MODE_WATCHER_TASK_KEY)
            cancelTask(self.SCREENCAPTURE_WATCHER_TASK_KEY)
        }.store(in: &observers)

        mergeBrightnessContrastPublisher.sink { change in
            mainAsync { [self] in
                displays.values.forEach {
                    $0.noDDCOrMergedBrightnessContrast = !$0.hasDDC || change.newValue
                }
            }
        }.store(in: &observers)

        showOrientationInQuickActionsPublisher.sink { [self] change in
            mainAsync { [self] in
                displays.values.forEach {
                    #if DEBUG
                        $0.showOrientation = change.newValue
                    #else
                        $0.showOrientation = $0.canRotate && change.newValue
                    #endif
                }
            }
        }.store(in: &observers)

        showVolumeSliderPublisher.sink { [self] change in
            mainAsync { [self] in
                displays.values.forEach {
                    $0.showVolumeSlider = $0.canChangeVolume && change.newValue
                }
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
                manufacturer: manufacturer,
                vendorID: vendorID,
                width: width,
                height: height
            )

            return (display, score)
        }

        log.info("Display scores: \(displayScores)")
        return displayScores.max(count: 1, sortedBy: { first, second in first.1 <= second.1 }).first?.0
    }

    func IOServiceNameMatches(_ service: io_service_t, names: [String]) -> Bool {
        let deviceNamePtr = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
        defer { deviceNamePtr.deallocate() }
        deviceNamePtr.initialize(repeating: 0, count: MemoryLayout<io_name_t>.size)
        defer { deviceNamePtr.deinitialize(count: MemoryLayout<io_name_t>.size) }

        let kr = IORegistryEntryGetName(service, deviceNamePtr)
        if kr != KERN_SUCCESS {
            return false
        }
        let deviceName = String(cString: deviceNamePtr)

        return names.contains(deviceName)
    }

    #if arch(arm64)
        func clcd2Properties(_ dispService: io_service_t) -> [String: Any]? {
            guard let clcd2Service = firstChildMatching(dispService, names: ["AppleCLCD2"]) else { return nil }

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

        func matchDisplayByEDIDUUID(_ service: io_service_t, displays: [Display]? = nil, props: [String: Any]? = nil) -> Display? {
            guard let displayProps = props ?? clcd2Properties(service) else { return nil }
            guard let edidUUID = displayProps["EDID UUID"] as? String
            else {
                log.info("No display matched for service \(service): (Can't find EDID UUID)")
                return nil
            }

            var transport: Transport?
            if let transportDict = displayProps["Transport"] as? [String: String] {
                transport = Transport(upstream: transportDict["Upstream"] ?? "", downstream: transportDict["Downstream"] ?? "")
            }

            let activeDisplays = (displays ?? activeDisplays.values.map { $0 })
            guard let display = activeDisplays.first(where: { $0.matchesEDIDUUID(edidUUID) }) else {
                log.info("No UUID matched: (EDID UUID: \(edidUUID), Transport: \(transport?.description ?? "Unknown"))")
                return nil
            }

            log.info("Matched display \(display) (EDID UUID: \(edidUUID), Transport: \(transport?.description ?? "Unknown"))")
            display.transport = transport
            display.audioIdentifier = edidUUID
            return display
        }

        func matchDisplayByProductAttributes(_ service: io_service_t, displays: [Display]? = nil, props: [String: Any]? = nil) -> Display? {
            guard let displayProps = props ?? clcd2Properties(service) else { return nil }

            var transport: Transport?
            if let transportDict = displayProps["Transport"] as? [String: String] {
                transport = Transport(upstream: transportDict["Upstream"] ?? "", downstream: transportDict["Downstream"] ?? "")
            }

            guard let displayAttributes = displayProps["DisplayAttributes"] as? [String: Any],
                  let props = displayAttributes["ProductAttributes"] as? [String: Any],
                  let name = props["ProductName"] as? String, let serial = props["SerialNumber"] as? Int,
                  let productID = props["ProductID"] as? Int, let manufactureYear = props["YearOfManufacture"] as? Int
            else {
                log.info("No display matched for service \(service): (displayProps: \(displayProps))")
                log.verbose("displayProps: \(displayProps)")
                return nil
            }

            var allActiveDisplays = Set(activeDisplays.values.map { $0 })
            if let displays = displays {
                allActiveDisplays.formUnion(displays)
            }

            guard let display = getMatchingDisplay(
                name: name, serial: serial, productID: productID, manufactureYear: manufactureYear,
                manufacturer: props["ManufacturerID"] as? String, vendorID: props["LegacyManufacturerID"] as? Int,
                width: props["NativeFormatHorizontalPixels"] as? Int, height: props["NativeFormatVerticalPixels"] as? Int,
                displays: Array(allActiveDisplays)
            ) else {
                return nil
            }

            log
                .info(
                    "Matched display \(display) (name: \(name), serial: \(serial), productID: \(productID), Transport: \(transport?.description ?? "Unknown"))"
                )
            display.transport = transport
            return display
        }

        func displayForIOService(_ service: io_service_t, displays: [Display]? = nil, match: AVServiceMatch) -> Display? {
            switch match {
            case .byEDIDUUID:
                return matchDisplayByEDIDUUID(service, displays: displays)
            case .byProductAttributes:
                return matchDisplayByProductAttributes(service, displays: displays)
            }
        }

        func firstChildMatching(_ service: io_service_t, names: [String]) -> io_service_t? {
            var iterator = io_iterator_t()

            guard IORegistryEntryCreateIterator(service, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) ==
                KERN_SUCCESS
            else {
                log.info("Can't create iterator for service \(service): (names: \(names))")
                return nil
            }

            defer {
                assert(IOObjectRelease(iterator) == KERN_SUCCESS)
            }
            log.info("Looking for service (names: \(names)) in iterator \(iterator)")
            return firstServiceMatching(iterator, names: names)
        }

        func firstServiceMatching(_ iterator: io_iterator_t, names: [String]) -> io_service_t? {
            var service: io_service_t?

            while case let txIOChild = IOIteratorNext(iterator), txIOChild != 0 {
                if IOServiceNameMatches(txIOChild, names: names) {
                    service = txIOChild
                    log.info("Found service \(txIOChild) in iterator \(iterator): (names: \(names))")
                    break
                }
            }

            return service
        }

        var clcd2Mapping: ThreadSafeDictionary<Int, CGDirectDisplayID> = ThreadSafeDictionary()

        func avService(displayID: CGDirectDisplayID, display: Display? = nil, match: AVServiceMatch) -> IOAVService? {
            guard !isTestID(displayID), NSScreen.isOnline(displayID),
                  !(display?.badHDMI ?? false),
                  !DDC.isVirtualDisplay(displayID, checkName: false)
            else {
                log
                    .info(
                        "No AVService for display \(displayID): (isOnline: \(NSScreen.isOnline(displayID)), isVirtual: \(DDC.isVirtualDisplay(displayID, checkName: false)))"
                    )
                return nil
            }

            var clcd2Num = 0
            var txIOIterator = io_iterator_t()
            var txIOService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleT810xIO"))
            if txIOService == 0 {
                txIOService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleT600xIO"))
            }

            guard txIOService != 0,
                  IORegistryEntryGetChildIterator(txIOService, kIOServicePlane, &txIOIterator) == KERN_SUCCESS
            else {
                log
                    .info(
                        "No AVService for display \(displayID): (txIOService: \(txIOService), childIteratorErr: \((txIOService != 0) ? IORegistryEntryGetChildIterator(txIOService, kIOServicePlane, &txIOIterator) : KERN_SUCCESS)))"
                    )
                return nil
            }

            defer {
                assert(IOObjectRelease(txIOIterator) == KERN_SUCCESS)
            }

            var matchedDisplay: Display?
            while case let txIOChild = IOIteratorNext(txIOIterator), txIOChild != 0 {
                if IOServiceNameMatches(
                    txIOChild,
                    names: [
                        "disp0",
                        "dispext0",
                        "dispext1",
                        "dispext2",
                        "dispext3",
                        "dispext4",
                        "dispext5",
                        "dispext6",
                        "dispext7",
                        "disp1",
                        "disp2",
                        "disp3",
                        "disp4",
                        "disp5",
                        "disp6",
                        "disp7",
                    ]
                ) {
                    clcd2Num += 1
                    guard clcd2Mapping[clcd2Num] == nil || clcd2Mapping[clcd2Num] == displayID else { continue }

                    if let d = displayForIOService(
                        txIOChild,
                        displays: display != nil ? [display!] : nil,
                        match: match
                    ), d.id == displayID {
                        matchedDisplay = d
                        break
                    }
                }
            }

            guard let display = matchedDisplay else {
                log.info("No AVService for display \(displayID): (no matched display)")
                return nil
            }

            log.info("Mac Mini HDMI Ignore: hw.model=\(Sysctl.modelLowercased)")
            log.info("Mac Mini HDMI Ignore: isMacMini=\(Sysctl.isMacMini)")
            log.info("Mac Mini HDMI Ignore: isMacBook=\(Sysctl.isMacBook)")
            log.info("Mac Mini HDMI Ignore: Transport=\(display.transport?.description ?? "Unknown")")
            log.info("Mac Mini HDMI Ignore: CLCD2 Number=\(clcd2Num)")
            if Sysctl.isMacMini, clcd2Num == 1,
               // || (Sysctl.modelLowercased.starts(with: "macbookpro18,") && clcd2Num >= 1),
               let transport = display.transport,
               transport.upstream == "DP",
               transport.downstream == "HDMI"
            {
                log.warning("This HDMI port doesn't support DDC, ignoring for display \(display)")
                display.badHDMI = true
                return nil
            }

            var dcpAvServiceProperties: Unmanaged<CFMutableDictionary>?
            guard let dcpService = firstServiceMatching(
                txIOIterator,
                names: ["dcp", "dcpext", "dcpext0", "dcpext1", "dcpext2", "dcpext3", "dcpext4", "dcpext5", "dcpext6", "dcpext7"]
            ),
                let dcpAvServiceProxy = firstChildMatching(dcpService, names: ["DCPAVServiceProxy"]),
                firstChildMatching(dcpService, names: ["AppleDCPMCDP29XX"]) == nil,
                let ioAvService = AVServiceCreateFromDCPAVServiceProxy(dcpAvServiceProxy)?.takeRetainedValue(),
                !CFEqual(ioAvService, 0 as IOAVService),
                // Check if DCPAVServiceProxy belongs to an external monitor
                IORegistryEntryCreateCFProperties(dcpAvServiceProxy, &dcpAvServiceProperties, kCFAllocatorDefault, IOOptionBits()) ==
                KERN_SUCCESS,
                let dcpAvCFProps = dcpAvServiceProperties, let dcpAvProps = dcpAvCFProps.takeRetainedValue() as? [String: Any],
                let avServiceLocation = dcpAvProps["Location"] as? String, avServiceLocation == "External"
            else {
                log.warning("No AVService for display with ID: \(displayID)")
                return nil
            }
            log
                .info(
                    "Found AVService for display \(display): \(CFCopyDescription(ioAvService) as String)"
                )

            clcd2Mapping[clcd2Num] = displayID
            return ioAvService
        }
    #endif

    var screencaptureIsRunning: CurrentValueSubject<Bool, Never> = .init(processIsRunning("/usr/sbin/screencapture", nil))

    var displayList: [Display] {
        displays.values.sorted { (d1: Display, d2: Display) -> Bool in d1.id < d2.id }.reversed()
    }

    var externalActiveDisplays: [Display] {
        activeDisplays.values.filter { !$0.isBuiltin }
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
                uniqueKeysWithValues: activeDisplays.map { _, display in
                    (display.readableID, display)
                }
            )
        }
    }

    var activeDisplays: [CGDirectDisplayID: Display] {
        get { _activeDisplaysLock.around(ignoreMainThread: true) { _activeDisplays } }
        set {
            _activeDisplaysLock.around {
                _activeDisplays = newValue
                CachedDefaults[.hasActiveDisplays] = !_activeDisplays.isEmpty
                onActiveDisplaysChange?()
                newValue.values.forEach { d in
                    d.updateCornerWindow()
                }

                activeDisplayList = _activeDisplays.values.sorted { (d1: Display, d2: Display) -> Bool in d1.id < d2.id }.reversed()
            }
        }
    }

    @AtomicLock var adaptiveMode: AdaptiveMode = DisplayController.getAdaptiveMode() {
        didSet {
            if adaptiveMode.key != .manual {
                lastNonManualAdaptiveMode = adaptiveMode
            }
            oldValue.stopWatching()
            if adaptiveMode.available {
                adaptiveMode.watch()
            }
        }
    }

    var adaptiveModeKey: AdaptiveModeKey {
        adaptiveMode.key
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
        guard let cursorDisplay = cursorDisplay else { return [] }
        return activeDisplayList.filter { $0.id != cursorDisplay.id }
    }

    var mainDisplay: Display? {
        guard let screenID = NSScreen.main?.displayID else { return nil }
        return activeDisplays[screenID]
    }

    var nonMainDisplays: [Display] {
        guard let mainDisplay = mainDisplay else { return [] }
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

    static func getAdaptiveMode() -> AdaptiveMode {
        if CachedDefaults[.overrideAdaptiveMode] {
            return CachedDefaults[.adaptiveBrightnessMode].mode
        } else {
            let mode = autoMode()
//            if mode.key != CachedDefaults[.adaptiveBrightnessMode] {
//                CachedDefaults[.adaptiveBrightnessMode] = mode.key
//            }
            return mode
        }
    }

    static func panel(with id: CGDirectDisplayID) -> MPDisplay? {
        guard let displays = DisplayController.panelManager?.displays as? [MPDisplay] else { return nil }

        return displays.first { $0.displayID == id }
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
        // "DisplayAttributes" = {"ProductAttributes"={"ManufacturerID"="GSM","YearOfManufacture"=2017,"SerialNumber"=314041,"ProductName"="LG Ultra HD","LegacyManufacturerID"=7789,"ProductID"=23305,"WeekOfManufacture"=8}

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

        if let fullyMatchedProps = fullyMatchedProps {
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

        CGDisplayRestoreColorSyncSettings()
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
            d.primaryMirrorScreen = d.getPrimaryMirrorScreen()
//            d.secondaryMirrorScreenID = d.getSecondaryMirrorScreenID()
            let primary = d.primaryMirrorScreen
            let secondary = d.secondaryMirrorScreenID

            log.debug("Primary mirror for \(d): \(String(describing: primary))")
            log.debug("Secondary mirror for \(d): \(String(describing: secondary))")
        }
    }

    func getCurrentAudioDisplay() -> Display? {
        guard let audioDevice = simplyCA.defaultOutputDevice, !audioDevice.canSetVirtualMainVolume(scope: .output) else {
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

        let alignments = fuzzyFind(queries: [audioDevice.name], inputs: activeDisplays.values.map(\.name))
        guard let name = alignments.first?.result.asString else { return mainExternalOrCGMainDisplay }

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
        guard lunarProActive, let exceptions = runningAppExceptions, !exceptions.isEmpty, let screen = display.screen else {
            log.debug("!exceptions: \(runningAppExceptions ?? [])")
            log.debug("!screen: \(display.screen?.description ?? "")")
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
                guard let self = self else { return }

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

    func resetDisplayList(advancedSettings: Bool = false, configurationPage: Bool = false, autoBlackOut: Bool? = nil) {
        asyncNow {
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
                let activeNewDisplayIDs = activeNewDisplays.map(\.id)

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
                    let mirror = d.primaryMirrorScreen?.displayID ?? 0
                    let mirrorExists = activeNewDisplayIDs.contains(mirror)

                    log.debug("\(d): blackOutEnabled=\(d.blackOutEnabled) mirror=\(mirror) mirrorExists=\(mirrorExists)")
                    guard d.blackOutEnabled, mirror == 0 || !mirrorExists else { continue }

                    log
                        .info(
                            "Disabling BlackOut for \(d): blackOutEnabled=\(d.blackOutEnabled) mirror=\(mirror) mirrorExists=\(mirrorExists)"
                        )
                    mainAsync { displayController.blackOut(display: d.id, state: .off) }
                }

                if let d = activeNewDisplays.first, activeNewDisplays.count == 1, d.isBuiltin, d.blackOutEnabled,
                   activeOldDisplays.count > 1
                {
                    log.info("Disabling BlackOut if we're left with only 1 screen")
                    mainAsync { displayController.blackOut(display: d.id, state: .off) }
                }
                guard let autoBlackOut = autoBlackOut, autoBlackOut, lunarProOnTrial || lunarProActive else { return }
                if let d = activeOldDisplays.first, activeOldDisplays.count == 1, d.isBuiltin, activeNewDisplays.count > 1 {
                    mainAsync { displayController.blackOut(display: d.id, state: .on) }
                }
            }

            self.reconfigure()
            mainAsync {
                appDelegate!.recreateWindow(
                    page: (advancedSettings || configurationPage) ? Page.settings.rawValue : nil,
                    advancedSettings: advancedSettings
                )
                NotificationCenter.default.post(name: displayListChanged, object: nil)
            }
        }
    }

    func reconfigure() {
        thrice(uniqueTaskKey: "display-controller-reconfiguration") { dc in
            log.info("Resetting software dimming")
            dc.activeDisplays.values.forEach { d in
                d.updateCornerWindow()
                if d.softwareBrightness == 1.0 {
                    d.resetSoftwareControl()
                }
            }

            log.info("Removing old overlays")
            windowControllerQueue.sync {
                dc.removeOldOverlays()
            }

            log.info("Re-adapting brightness after reconfiguration")
            dc.adaptBrightness(force: true)
        }
    }

    func removeOldOverlays() {
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

    func shouldPromptAboutFallback(_ display: Display) -> Bool {
        guard !display.neverFallbackControl, display.enabledControls[.gamma] ?? false else { return false }

        if !SyncMode.possibleClamshellModeSoon, !screensSleeping.load(ordering: .relaxed),
           let screen = display.screen, !screen.visibleFrame.isEmpty,
           !(display.control?.isResponsive() ?? true)
        {
            if let promptTime = fallbackPromptTime[display.id] {
                return promptTime + 20.minutes < Date()
            }
            return true
        }

        return false
    }

    func promptAboutFallback(_ display: Display) {
        log.warning("Non-responsive display", context: display.context)
        fallbackPromptTime[display.id] = Date()
        let semaphore = DispatchSemaphore(value: 0, name: "Non-responsive Control Watcher Prompt")
        let completionHandler = { (fallbackToGamma: NSApplication.ModalResponse) in
            if fallbackToGamma == .alertFirstButtonReturn {
                if let control = display.control?.displayControl {
                    display.enabledControls[control] = false
                }
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
                `\(display.name)` is not responding to commands in
                **\(display.control!.str)** mode.

                Do you want to fallback to `Software Dimming`?

                Note: adjust the monitor to `[BRIGHTNESS: 100%, CONTRAST: 70%]` manually
                using its physical buttons to allow for a full range in software dimming.
            """,
            okButton: "Yes",
            cancelButton: "Not now",
            thirdButton: "No, never ask again",
            screen: display.screen ?? display.primaryMirrorScreen,
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
        asyncNow { [self] in
            guard !taskIsRunning(CONTROL_WATCHER_TASK_KEY) else {
                return
            }

            asyncEvery(15.seconds, uniqueTaskKey: CONTROL_WATCHER_TASK_KEY, queue: .main) { [self] in
                guard !screensSleeping.load(ordering: .relaxed) else { return }
                for display in activeDisplays.values {
                    display.control = display.getBestControl()
                    if shouldPromptAboutFallback(display) {
                        asyncNow { promptAboutFallback(display) }
                    }
                }
            }
        }
    }

    func addSentryData() {
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
                    computedProps["CoreDisplay_Display_GetUserBrightness"] = CoreDisplay_Display_GetUserBrightness(id).str(decimals: 4)
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

            guard let self = self else { return }
            for display in self.displays.values {
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
        SentrySDK.configureScope { [weak self] scope in
            guard let self = self else { return }
            scope.setTag(value: String(describing: self.lidClosed), key: "clamshellMode")
        }

        if CachedDefaults[.clamshellModeDetection], SyncMode.sourceDisplay?.isBuiltin ?? true {
            if lidClosed {
                activateClamshellMode()
            } else if clamshellMode {
                deactivateClamshellMode()
            }
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
                self.adaptiveMode.adapt(display)
            }
        }
    }

    @discardableResult
    func thrice(
        uniqueTaskKey key: String,
        _ action: @escaping ((DisplayController) -> Void),
        onFinish: ((DisplayController) -> Void)? = nil
    ) -> DispatchWorkItem {
        if Logger.trace {
            Thread.callStackSymbols.forEach {
                log.info($0)
            }
        }

        return asyncAfter(ms: 10, uniqueTaskKey: key) { [self] in
            guard adaptiveMode.available else { return }
            adaptiveMode.withForce {
                guard !isCancelled(key) else { return }
                for _ in 1 ... 3 {
                    action(self)
                    Thread.sleep(forTimeInterval: 1)
                    guard !isCancelled(key) else { return }
                }
                onFinish?(self)
            }
        }
    }

    func setBrightnessPercent(value: Int8, for displays: [Display]? = nil, now: Bool = false) {
        let manualMode = (adaptiveMode as? ManualMode) ?? ManualMode.specific
        let displays = displays ?? activeDisplays.values.map { $0 }

        displays.forEach { display in
            guard CachedDefaults[.hotkeysAffectBuiltin] || !display.isBuiltin,
                  !display.lockedBrightness
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
        if let displays = displays {
            displays.forEach { display in display.brightness = brightness }
        } else {
            activeDisplays.values.forEach { display in display.brightness = brightness }
        }
    }

    func setContrast(contrast: NSNumber, for displays: [Display]? = nil) {
        if let displays = displays {
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
            var value = getFilledChicletValue(display.volume.intValue, offset: offset)
            value = cap(value, minVal: MIN_VOLUME, maxVal: MAX_VOLUME)
            display.volume = value.ns
        }
    }

    func adjustBrightness(
        by offset: Int,
        for displays: [Display]? = nil,
        currentDisplay: Bool = false,
        builtinDisplay: Bool = false,
        sourceDisplay: Bool = false
    ) {
        guard checkRemainingAdjustments() else { return }

        adjustValue(
            for: displays,
            currentDisplay: currentDisplay,
            builtinDisplay: builtinDisplay,
            sourceDisplay: sourceDisplay
        ) { (display: Display) in
            guard !display.noControls, !display.blackOutEnabled else { return }
            if display.isBuiltin {
                guard builtinDisplay || currentDisplay || sourceDisplay else { return }
            }

            var value = getFilledChicletValue(display.brightness.intValue, offset: offset)

            let minBrightness = display.minBrightness.intValue
            let maxBrightness = display.maxBrightness.intValue
            let oldValue = display.brightness.intValue
            value = cap(
                value,
                minVal: minBrightness,
                maxVal: maxBrightness
            )

            if !display.hasSoftwareControl, minBrightness <= 1, !display.isForTesting,
               (value == minBrightness && value == oldValue) ||
               (oldValue == minBrightness && display.softwareBrightness < 1.0)
            {
                display.softwareBrightness = cap(
                    display.softwareBrightness + (offset.f / 36),
                    minVal: 0.0,
                    maxVal: 1.0
                )
                return
            }

            if display.enhanced, !display.hasSoftwareControl, !display.isForTesting,
               (value == maxBrightness && value == oldValue) ||
               (oldValue == maxBrightness && display.softwareBrightness > 1.01)
            {
                display.softwareBrightness = cap(
                    display.softwareBrightness + (offset.f / 70),
                    minVal: 1.01,
                    maxVal: 1.5
                )
                return
            }

            if CachedDefaults[.mergeBrightnessContrast] {
                let preciseValue = mapNumber(
                    value.d,
                    fromLow: display.minBrightness.doubleValue,
                    fromHigh: display.maxBrightness.doubleValue,
                    toLow: 0,
                    toHigh: 100
                ) / 100

                display.preciseBrightnessContrast = preciseValue
            } else {
                display.brightness = value.ns
            }

            if adaptiveModeKey != .manual {
                display.insertBrightnessUserDataPoint(
                    adaptiveMode.brightnessDataPoint.last,
                    value,
                    modeKey: adaptiveModeKey
                )
            }
        }
    }

    func adjustContrast(by offset: Int, for displays: [Display]? = nil, currentDisplay: Bool = false, sourceDisplay: Bool = false) {
        guard checkRemainingAdjustments() else { return }

        adjustValue(for: displays, currentDisplay: currentDisplay, sourceDisplay: sourceDisplay) { (display: Display) in
            guard !display.isBuiltin, !display.blackOutEnabled else { return }

            var value = getFilledChicletValue(display.contrast.intValue, offset: offset)

            value = cap(
                value,
                minVal: display.minContrast.intValue,
                maxVal: display.maxContrast.intValue
            )
            display.contrast = value.ns

            if adaptiveModeKey != .manual {
                display.insertContrastUserDataPoint(
                    adaptiveMode.contrastDataPoint.last,
                    value,
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
        } else if let displays = displays {
            displays.forEach { display in
                setValue(display)
            }
        } else {
            activeDisplayList.forEach { display in
                setValue(display)
            }
        }
    }

    func getFilledChicletValue(_ value: Int, offset: Int) -> Int {
        let newValue = value + offset
        guard abs(offset) == 6 else { return newValue }
        let diffs = FILLED_CHICLETS_THRESHOLDS - newValue.f
        if let index = abs(diffs).enumerated().min(by: { $0.element <= $1.element })?.offset {
            let backupIndex = cap(index + (offset < 0 ? -1 : 1), minVal: 0, maxVal: FILLED_CHICLETS_THRESHOLDS.count - 1)
            let chicletValue = FILLED_CHICLETS_THRESHOLDS[index].i
            return chicletValue != value ? chicletValue : FILLED_CHICLETS_THRESHOLDS[backupIndex].i
        }
        return newValue
    }

    func gammaUnlock(for displays: [Display]? = nil) {
        (displays ?? self.displays.values.map { $0 }).forEach { $0.gammaUnlock() }
    }
}

let displayController = DisplayController()
let FILLED_CHICLETS_THRESHOLDS: [Float] = [0, 6, 12, 19, 25, 31, 37, 44, 50, 56, 62, 69, 75, 81, 87, 94, 100]
