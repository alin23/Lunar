//
//  NetworkControl.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25.02.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Combine
import Defaults
import Foundation
import SwiftDate
import UserNotifications

// MARK: - Service

class Service {
    init(_ service: NetService, scheme: String = "http", path: String = "") {
        self.service = service
        self.scheme = scheme
        self.path = path
    }

    var scheme: String
    var path: String
    var service: NetService

    lazy var urls: [URL] = {
        guard let addresses = service.addresses else { return [] }
        return addresses.compactMap { data in
            guard let addr = data.withUnsafeBytes(address) else { return nil }
            return buildURL(addr)
        }
    }()

    lazy var maxValueUrls: [URL] = {
        guard let addresses = service.addresses else { return [] }
        return addresses.compactMap { data in
            guard let addr = data.withUnsafeBytes(address) else { return nil }
            return buildURL(addr, path: "/max\(path)")
        }
    }()

    lazy var smoothTransitionUrls: [URL] = {
        guard let addresses = service.addresses else { return [] }
        return addresses.compactMap { data in
            guard let addr = data.withUnsafeBytes(address) else { return nil }
            return buildURL(addr, path: "/smooth\(path)")
        }
    }()

    var urlInitialized = false
    @AtomicLock var _url: URL? = nil
    var maxValueUrlInitialized = false
    @AtomicLock var _maxValueUrl: URL? = nil
    var smoothTransitionUrlInitialized = false
    @AtomicLock var _smoothTransitionUrl: URL? = nil

    var url: URL? {
        get {
            if !urlInitialized {
                urlInitialized = true
                _url = getFirstRespondingURL(urls: urls)
            }
            return _url
        }
        set {
            _url = newValue
        }
    }

    var maxValueUrl: URL? {
        get {
            if !maxValueUrlInitialized {
                maxValueUrlInitialized = true
                _maxValueUrl = getFirstRespondingURL(urls: maxValueUrls)
            }
            return _maxValueUrl
        }
        set {
            _maxValueUrl = newValue
        }
    }

    var smoothTransitionUrl: URL? {
        get {
            if !smoothTransitionUrlInitialized {
                smoothTransitionUrlInitialized = true
                _smoothTransitionUrl = getFirstRespondingURL(urls: smoothTransitionUrls)
            }
            return _smoothTransitionUrl
        }
        set {
            _smoothTransitionUrl = newValue
        }
    }

    func buildURL(_ addr: String, path: String? = nil) -> URL? {
        var urlBuilder = URLComponents()
        urlBuilder.scheme = scheme
        urlBuilder.host = addr.contains(":") ? "[\(addr)]" : addr
        urlBuilder.port = service.port
        urlBuilder.path = path ?? self.path
        return urlBuilder.url
    }

    func getFirstRespondingURL(urls: [URL], timeout: DateComponents = 3.seconds, retries: UInt = 3) -> URL? {
        for url in urls {
            if waitForResponse(from: url, timeoutPerTry: timeout, retries: retries) != nil {
                return url
            }
        }
        return nil
    }
}

// MARK: - NetworkControl

class NetworkControl: Control {
    init(display: Display) {
        self.display = display
        listenForRequests()
    }

    struct Request: Equatable {
        var url: URL
        var controlID: ControlID
        var timeout: DateComponents
        var value: UInt16
    }

    static var browser = CiaoBrowser()
    static var controllersForDisplay: [String: Service] = [:]
    static var controllerVideoObserver: Cancellable?
    static let browserSemaphore = DispatchSemaphore(value: 1, name: "browserSemaphore")

    var displayControl: DisplayControl = .network

    let str = "Network Control"
    weak var display: Display?
    var setterTasks = [ControlID: DispatchWorkItem]()
    let getterTasksSemaphore = DispatchSemaphore(value: 1, name: "getterTasksSemaphore")

    var requestsPublisher = PassthroughSubject<Request, Never>()
    var responsiveCheckPublisher = PassthroughSubject<Bool, Never>()

    var observers = Set<AnyCancellable>()

    var responsiveTryCount = 0

    var isSoftware: Bool { false }

    static func setup() {
        displayController.onActiveDisplaysChange = {
            let matchedServices = controllersForDisplay.values.map(\.service)
            for service in Set(browser.services).subtracting(matchedServices) {
                matchTXTRecord(service)
            }
        }
        listenForDDCUtilControllers()
        controllerVideoObserver = disableControllerVideoPublisher.sink { change in
            setDisplayPower(!change.newValue)
        }
    }

    static func shouldPromptForNetworkControl(_ display: Display) -> Bool {
        guard !display.neverUseNetworkControl else { return false }

        if !displayController.screensSleeping, let screen = display.nsScreen ?? display.primaryMirrorScreen,
           !screen.visibleFrame.isEmpty
        {
            return true
        }

        return false
    }

    static func promptForNetworkControl(_ displayNum: Int, netService: NetService, display: Display) {
        let service = Service(netService, path: "/\(displayNum)")
        guard !service.urls.isEmpty else { return }

        log
            .debug(
                "Matched display [\(display.id): \(display.name)] with network controller (\(netService.hostName ?? "nil"): \(service.urls)"
            )
        let semaphore = DispatchSemaphore(value: 0, name: "Network Control found prompt")
        let completionHandler = { (useNetwork: NSApplication.ModalResponse) in
            if useNetwork == .alertFirstButtonReturn {
                controllersForDisplay[display.serial] = service

                asyncNow(threaded: true) {
                    display.control = display.getBestControl()
                }
            }
            if useNetwork == .alertThirdButtonReturn {
                display.neverUseNetworkControl = true
                display.save()
            }
            semaphore.signal()
        }
        if display.alwaysUseNetworkControl {
            completionHandler(.alertFirstButtonReturn)
            return
        }

        let window = mainThread { appDelegate!.sshWindowController?.window ?? appDelegate!.windowController?.window }
        let resp = ask(
            message: "Lunar Network Controller",
            info: """
            Lunar found a network controller at `\(service.urls.first!.absoluteString)` for the `\(display.name)` monitor.

            Do you want to use it?
            """,
            okButton: "Yes",
            cancelButton: "Not now",
            thirdButton: "No, never ask again",
            screen: nil,
            window: window,
            suppressionText: "Always use network control for this display when possible",
            onSuppression: { useNetworkControl in
                display.alwaysUseNetworkControl = useNetworkControl
                display.save()
            },
            onCompletion: completionHandler,
            unique: true,
            waitTimeout: 60.seconds,
            markdown: true
        )

        if window == nil {
            completionHandler(resp)
        } else {
            semaphore.wait(for: nil)
        }
    }

    static func matchTXTRecord(_ netService: NetService) {
        guard let txt = netService.txtRecordDictionary else { return }

        let serviceConnectedDisplayCount = Set(txt.compactMap { $0.key.split(separator: ":").first }).count
        if serviceConnectedDisplayCount == 1, displayController.activeDisplays.count == 1,
           let display = displayController.activeDisplays.first?.value, shouldPromptForNetworkControl(display)
        {
            asyncNow { promptForNetworkControl(1, netService: netService, display: display) }
            return
        }

        for displayNum in 1 ... 4 {
            guard let name = txt["\(displayNum):model"], let manufacturer = txt["\(displayNum):mfg"],
                  let serialString = txt["\(displayNum):serial"], let serial = Int(serialString),
                  let yearString = txt["\(displayNum):year"], let year = Int(yearString),
                  let productString = txt["\(displayNum):product"], let productID = Int(productString)
            else { return }

            guard let display = displayController.getMatchingDisplay(
                name: name, serial: serial, productID: productID,
                manufactureYear: year, manufacturer: manufacturer,
                displays: displayController.externalActiveDisplays.filter(\.networkEnabled)
            ),
                shouldPromptForNetworkControl(display)
            else {
                return
            }
            asyncNow { promptForNetworkControl(displayNum, netService: netService, display: display) }
        }
    }

    static func listenForDDCUtilControllers() {
        browser.serviceFoundHandler = { _ in
            log.info("Service found")
        }

        browser.serviceUpdatedTXTHandler = { service in
            log.debug("Service updated TXT: \(service.txtRecordDictionary ?? [:])")
            matchTXTRecord(service)
        }

        browser.serviceResolvedHandler = { service in
            switch service {
            case let .success(netService):
                log.info("Service resolved: \(netService)", context: netService.txtRecordDictionary)
                log.debug("Service hostname: \(netService.hostName ?? "nil")")
                matchTXTRecord(netService)
            case let .failure(error):
                print(error)
            }
        }

        browser.serviceRemovedHandler = { service in
            let displayService = controllersForDisplay.first(where: { _, displayService in
                service == displayService.service
            })
            if !displayController.screensSleeping,
               let serial = displayService?.key, let controller = displayService?.value,
               let display = displayController.displays.values.first(where: { $0.serial == serial })
            {
                let serviceName = controller.url?.absoluteString ?? "\(service.hostName ?? service.name):\(service.port)"
                let body =
                    "Connection was lost for the controller found at \(serviceName). \(display.name) will not be controllable through network until reconnection"
                notify(identifier: "serviceRemoved\(service.domain):\(service.port)", title: "Network controller disappeared", body: body)
            }

            log.info("Service removed: \(service)")

            if let toRemove = displayService {
                controllersForDisplay.removeValue(forKey: toRemove.key)
            }
        }

        browser.browse(type: ServiceType.tcp("ddcutil"))
    }

    static func sendToAllControllers(_ action: (URL) -> Void) {
        let urls = controllersForDisplay.values.compactMap { $0.url?.deletingLastPathComponent() }.uniqued()
        for url in urls {
            action(url)
        }
    }

    static func setDisplayPower(_ power: Bool) {
        guard !displayController.screensSleeping else { return }
        sendToAllControllers { url in
            _ = waitForResponse(from: url / "display-power" / power.i)
        }
    }

    static func resetState(serial: String? = nil) {
        serviceBrowserQueue.async {
            if browserSemaphore.wait(for: 5) == .timedOut {
                return
            }
            defer {
                browserSemaphore.signal()
            }
            if let serial {
                _ = controllersForDisplay.removeValue(forKey: serial)
            }
            for display in displayController.activeDisplays.values {
                display.lastConnectionTime = Date()
            }
            browser.reset()
            browser.delegate.onStop = {
                browser.browse(type: ServiceType.tcp("ddcutil"))
                browser.delegate.onStop = nil
            }
        }
    }

    func manageSendingState(for controlID: ControlID, sending: Bool) {
        guard let display else { return }

        switch controlID {
        case .BRIGHTNESS:
            display.sendingBrightness = sending
        case .CONTRAST:
            display.sendingContrast = sending
        case .INPUT_SOURCE:
            display.sendingInput = sending
        case .AUDIO_SPEAKER_VOLUME:
            display.sendingVolume = sending
        default:
            if sending {
                log.verbose("Sending \(controlID)")
            } else {
                log.verbose("Sent \(controlID)")
            }
        }
    }

    func listenForRequests() {
        serviceBrowserQueue.async { [weak self] in
            guard let self else { return }
            self.requestsPublisher
                .removeDuplicates()
                .throttle(for: .milliseconds(500), scheduler: RunLoop.current, latest: true)
                .sink { [weak self] request in
                    guard let self, !displayController.screensSleeping else { return }

                    defer {
                        self.manageSendingState(for: request.controlID, sending: false)
                    }

                    guard let resp = waitForResponse(from: request.url, timeoutPerTry: request.timeout) else {
                        guard let display = self.display else { return }
                        log.error(
                            "Error sending \(request.controlID)=\(request.value) to \(request.url) for display \(display)"
                        )
                        return
                    }
                    guard let display = self.display else { return }
                    log.debug("Sent \(request.controlID)=\(request.value), received response `\(resp)` for display \(display)")
                }.store(in: &self.observers)

            self.responsiveCheckPublisher
                .debounce(for: .milliseconds(500), scheduler: RunLoop.current)
                .sink { [weak self] _ in
                    guard let self, let display = self.display else { return }
                    guard let service = NetworkControl.controllersForDisplay[display.serial],
                          let url = service.url, let newURL = service.getFirstRespondingURL(
                              urls: service.urls,
                              timeout: 600.milliseconds,
                              retries: 1
                          )
                    else {
                        self.responsiveTryCount += 1
                        if self.responsiveTryCount > 10 {
                            self.responsiveTryCount = 0
                            self.resetState()
                        }
                        return
                    }
                    if newURL != url {
                        service.url = newURL
                        service.smoothTransitionUrl = service.getFirstRespondingURL(
                            urls: service.smoothTransitionUrls,
                            timeout: 600.milliseconds,
                            retries: 1
                        )
                    }
                }.store(in: &self.observers)
        }
    }

    func set(_ value: UInt16, for controlID: ControlID, smooth: Bool = false, oldValue: UInt16? = nil) -> Bool {
        guard let display else { return false }

        guard let service = NetworkControl.controllersForDisplay[display.serial],
              let url = smooth ? service.smoothTransitionUrl : service.url,
              DDC.apply
        else {
            manageSendingState(for: controlID, sending: true)
            asyncAfter(ms: 1000) { [weak self] in self?.manageSendingState(for: controlID, sending: false) }
            return false
        }

        if smooth, oldValue == nil {
            return false
        }

        manageSendingState(for: controlID, sending: true)

        var fullUrl: URL
        if smooth {
            fullUrl = url / controlID / oldValue! / value
        } else {
            fullUrl = url / controlID / value
        }

        requestsPublisher.send(Request(url: fullUrl, controlID: controlID, timeout: smooth ? 60.seconds : 15.seconds, value: value))

        return true
    }

    func get(_ controlID: ControlID, max: Bool = false) -> UInt16? {
        guard let display else { return nil }

        guard !displayController.screensSleeping else { return nil }

        _ = getterTasksSemaphore.wait(for: 5.seconds)
        defer { getterTasksSemaphore.signal() }

        guard let controller = NetworkControl.controllersForDisplay[display.serial],
              let url = max ? controller.maxValueUrl : controller.url
        else {
            return nil
        }

        var value: UInt16?
        guard let resp = waitForResponse(from: url / controlID, timeoutPerTry: 1500.milliseconds) else {
            log.error("Error reading \(controlID) for \(display)")
            return nil
        }
        log.debug("Read \(controlID), received response `\(resp)` for \(display)")
        value = UInt16(resp)

        return value
    }

    func setPower(_ power: PowerState) -> Bool {
        set(power == .on ? 1 : 5, for: .DPMS)
    }

    func setRedGain(_ gain: UInt16) -> Bool {
        set(gain, for: .RED_GAIN)
    }

    func setGreenGain(_ gain: UInt16) -> Bool {
        set(gain, for: .GREEN_GAIN)
    }

    func setBlueGain(_ gain: UInt16) -> Bool {
        set(gain, for: .BLUE_GAIN)
    }

    func getRedGain() -> UInt16? {
        get(.RED_GAIN)
    }

    func getGreenGain() -> UInt16? {
        get(.GREEN_GAIN)
    }

    func getBlueGain() -> UInt16? {
        get(.BLUE_GAIN)
    }

    func resetColors() -> Bool {
        set(1, for: .RESET_COLOR)
    }

    func setBrightness(
        _ brightness: Brightness,
        oldValue: Brightness? = nil,
        force: Bool = false,
        transition: BrightnessTransition? = nil,
        onChange: ((Brightness) -> Void)? = nil
    ) -> Bool {
        defer { onChange?(brightness) }
        let brightnessTransition = transition ?? brightnessTransition
        if brightnessTransition != .instant, supportsSmoothTransition(for: .BRIGHTNESS), let oldValue,
           oldValue != brightness
        {
            return set(brightness, for: .BRIGHTNESS, smooth: true, oldValue: oldValue)
        }
        return set(brightness, for: .BRIGHTNESS)
    }

    func setContrast(
        _ contrast: Contrast,
        oldValue: Contrast? = nil,
        transition: BrightnessTransition? = nil,
        onChange: ((Contrast) -> Void)? = nil
    ) -> Bool {
        defer { onChange?(contrast) }
        let brightnessTransition = transition ?? brightnessTransition
        if brightnessTransition != .instant, supportsSmoothTransition(for: .CONTRAST), let oldValue,
           oldValue != contrast
        {
            return set(contrast, for: .CONTRAST, smooth: true, oldValue: oldValue)
        }
        return set(contrast, for: .CONTRAST)
    }

    func setVolume(_ volume: UInt16) -> Bool {
        set(volume, for: .AUDIO_SPEAKER_VOLUME)
    }

    func setMute(_ muted: Bool) -> Bool {
        guard let display else { return false }

        return set(muted ? display.muteByteValueOn : display.muteByteValueOff, for: .AUDIO_MUTE)
    }

    func setInput(_ input: VideoInputSource) -> Bool {
        set(input.rawValue, for: .INPUT_SOURCE)
    }

    func getBrightness() -> Brightness? {
        get(.BRIGHTNESS)
    }

    func getContrast() -> Contrast? {
        get(.CONTRAST)
    }

    func getMaxBrightness() -> Brightness? {
        get(.BRIGHTNESS, max: true)
    }

    func getMaxContrast() -> Contrast? {
        get(.CONTRAST, max: true)
    }

    func getMaxVolume() -> UInt16? {
        get(.AUDIO_SPEAKER_VOLUME, max: true)
    }

    func getVolume() -> UInt16? {
        get(.AUDIO_SPEAKER_VOLUME)
    }

    func getInput() -> VideoInputSource? {
        guard let input = get(.INPUT_SOURCE), let inputSource = VideoInputSource(rawValue: input) else { return nil }
        return inputSource
    }

    func getMute() -> Bool? {
        guard let muted = get(.AUDIO_MUTE) else { return false }
        return muted != 2
    }

    func reset() -> Bool {
        set(1, for: .RESET_BRIGHTNESS_AND_CONTRAST)
    }

    func isAvailable() -> Bool {
        guard let display else { return false }

        guard display.active else { return false }
        if display.isForTesting, let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay {
            return true
        }

        guard let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay,
              let service = NetworkControl.controllersForDisplay[display.serial] else { return false }

        if service.url == nil {
            serialQueue.async {
                guard let newURL = service.getFirstRespondingURL(urls: service.urls) else { return }
                if newURL != service.url {
                    service.url = newURL
                    service.smoothTransitionUrl = service.getFirstRespondingURL(urls: service.smoothTransitionUrls)
                }
            }
            return false
        }
        return true
    }

    func isResponsive() -> Bool {
        guard let display else { return false }

        #if DEBUG
            if TEST_IDS.contains(display.id) {
                return true
            }
        #endif
        guard let service = NetworkControl.controllersForDisplay[display.serial] else {
            responsiveTryCount += 1
            if responsiveTryCount > 3 {
                responsiveTryCount = 0
                resetState()
            }
            return false
        }

        guard service.url != nil else {
            return false
        }

        responsiveCheckPublisher.send(true)

        return true
    }

    func resetState() {
        guard let display else { return }

        Self.resetState(serial: display.serial)
    }

    func supportsSmoothTransition(for _: ControlID) -> Bool {
        guard let display else { return false }

        guard let service = NetworkControl.controllersForDisplay[display.serial] else { return false }
        return service.smoothTransitionUrl != nil
    }
}
