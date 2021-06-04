//
//  NetworkControl.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25.02.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Ciao
import Defaults
import Foundation

class Service {
    var scheme: String
    var path: String
    var service: NetService

    init(_ service: NetService, scheme: String = "http", path: String = "") {
        self.service = service
        self.scheme = scheme
        self.path = path
    }

    func buildURL(_ addr: String, path: String? = nil) -> URL? {
        var urlBuilder = URLComponents()
        urlBuilder.scheme = scheme
        urlBuilder.host = addr.contains(":") ? "[\(addr)]" : addr
        urlBuilder.port = service.port
        urlBuilder.path = path ?? self.path
        return urlBuilder.url
    }

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

    func getFirstRespondingURL(urls: [URL], timeout: DateComponents = 3.seconds, retries: UInt = 3) -> URL? {
        for url in urls {
            if waitForResponse(from: url, timeoutPerTry: timeout, retries: retries) != nil {
                return url
            }
        }
        return nil
    }

    lazy var url = getFirstRespondingURL(urls: urls)
    lazy var maxValueUrl = getFirstRespondingURL(urls: maxValueUrls)
    lazy var smoothTransitionUrl = getFirstRespondingURL(urls: smoothTransitionUrls)
}

class NetworkControl: Control {
    var displayControl: DisplayControl = .network

    static var browser = CiaoBrowser()
    static var controllersForDisplay: [CGDirectDisplayID: Service] = [:]
    static let alamoFireManager = buildAlamofireSession()
    static var controllerVideoObserver: DefaultsObservation?
    let str = "Network Control"
    weak var display: Display!
    var setterTasks = [ControlID: DispatchWorkItem]()
    let setterTasksSemaphore = DispatchSemaphore(value: 1)

    init(display: Display) {
        self.display = display
    }

    static func setup() {
        listenForDDCUtilControllers()
        controllerVideoObserver = Defaults.observe(.disableControllerVideo) { change in
            guard change.newValue != change.oldValue else { return }
            setDisplayPower(!change.newValue)
        }
    }

    static func promptForNetworkControl(_ displayNum: Int, netService: NetService, display: Display) {
        let service = Service(netService, path: "/\(displayNum)")
        if !service.urls.isEmpty {
            log
                .debug(
                    "Matched display [\(display.id): \(display.name)] with network controller (\(netService.hostName ?? "nil"): \(service.urls)"
                )
            let completionHandler = { (useNetwork: Bool) in
                if useNetwork {
                    controllersForDisplay[display.id] = service
                    async(threaded: true) {
                        display.control = display.getBestControl()
                    }
                }
            }
            if display.alwaysUseNetworkControl {
                completionHandler(true)
                return
            }

            let window = mainThread { appDelegate().sshWindowController?.window ?? appDelegate().windowController?.window }
            let resp = ask(
                message: "Lunar Network Controller",
                info: """
                    Lunar found a network controller at \"\(service.urls.first!
                    .absoluteString)\" for this \"\(display.name)\" monitor.

                    Do you want to use it?
                """,
                okButton: "Yes",
                cancelButton: "No",
                screen: display.screen,
                window: window,
                suppressionText: "Always use network control for this display when possible",
                onSuppression: { useNetworkControl in
                    display.alwaysUseNetworkControl = useNetworkControl
                    display.save()
                },
                onCompletion: completionHandler,
                unique: true,
                waitTimeout: 60.seconds
            )
            if window == nil {
                completionHandler(resp)
            }
        }
    }

    static func matchTXTRecord(_ netService: NetService) {
        guard let txt = netService.txtRecordDictionary else { return }

        let serviceConnectedDisplayCount = Set(txt.compactMap { $0.key.split(separator: ":").first }).count
        if serviceConnectedDisplayCount == 1, displayController.activeDisplays.count == 1, let display = displayController.activeDisplays.first {
            promptForNetworkControl(1, netService: netService, display: display.value)
            return
        }

        for displayNum in 1 ... 4 {
            guard let name = txt["\(displayNum):model"], let manufacturer = txt["\(displayNum):mfg"],
                  let serialString = txt["\(displayNum):serial"], let serial = Int(serialString),
                  let yearString = txt["\(displayNum):year"], let year = Int(yearString),
                  let productString = txt["\(displayNum):product"], let productID = Int(productString)
            else { return }

            guard let display = displayController.getMatchingDisplay(
                name: name, serial: serial, productID: productID, manufactureYear: year, manufacturer: manufacturer
            ) else {
                return
            }
            promptForNetworkControl(displayNum, netService: netService, display: display)
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
            log.info("Service removed: \(service)")
            if let toRemove = controllersForDisplay.first(where: { _, displayService in
                service == displayService.service
            }) {
                controllersForDisplay.removeValue(forKey: toRemove.key)
            }
        }

        browser.browse(type: ServiceType.tcp("ddcutil"))
    }

    static func sendToAllControllers(_ action: (URL) -> Void) {
        for url in controllersForDisplay.values.compactMap({ $0.url?.deletingLastPathComponent() }).uniqued() {
            action(url)
        }
    }

    static func setDisplayPower(_ power: Bool) {
        sendToAllControllers { url in
            _ = try? query(url: url / "display-power" / power.i, wait: false)
        }
    }

    func manageSendingState(for controlID: ControlID, sending: Bool) {
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

    func set(_ value: UInt8, for controlID: ControlID, smooth: Bool = false, oldValue: UInt8? = nil) -> Bool {
        guard let service = NetworkControl.controllersForDisplay[display.id],
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

        let setter = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            defer {
                self.manageSendingState(for: controlID, sending: false)
            }

            do {
                let resp = try query(url: fullUrl, timeout: smooth ? 60 : 15)
                guard let display = self.display else { return }
                log.debug("Sent \(controlID)=\(value), received response `\(resp)`", context: display.context)
            } catch {
                guard let display = self.display else { return }
                log.error("Error sending \(controlID)=\(value): \(error)", context: display.context.with(["url": fullUrl]))
            }

            _ = self.setterTasksSemaphore.wait(timeout: DispatchTime.now() + 5.seconds.timeInterval)
            defer {
                self.setterTasksSemaphore.signal()
            }

            self.setterTasks.removeValue(forKey: controlID)
        }

        _ = setterTasksSemaphore.wait(timeout: DispatchTime.now() + 5.seconds.timeInterval)
        defer {
            self.setterTasksSemaphore.signal()
        }

        if let task = setterTasks[controlID] {
            task.cancel()
        }
        setterTasks[controlID] = setter
        asyncAfter(ms: 100, setter)

        return true
    }

    func get(_ controlID: ControlID, max: Bool = false) -> UInt8? {
        _ = setterTasksSemaphore.wait(timeout: DispatchTime.now() + 5.seconds.timeInterval)

        guard let controller = NetworkControl.controllersForDisplay[display.id],
              let url = max ? controller.maxValueUrl : controller.url,
              setterTasks[controlID] == nil || setterTasks[controlID]!.isCancelled
        else {
            setterTasksSemaphore.signal()
            return nil
        }

        setterTasksSemaphore.signal()

        var value: UInt8?
        do {
            let resp = try query(url: url / controlID, timeout: 1.5)
            log.debug("Read \(controlID), received response `\(resp)`", context: ["name": display.name, "id": display.id])
            value = UInt8(resp)
        } catch {
            log.error("Error reading \(controlID): \(error)", context: ["name": display.name, "id": display.id])
        }

        return value
    }

    func setPower(_ power: PowerState) -> Bool {
        set(power == .on ? 1 : 5, for: .DPMS)
    }

    func setBrightness(_ brightness: Brightness, oldValue: Brightness? = nil) -> Bool {
        if Defaults[.smoothTransition], supportsSmoothTransition(for: .BRIGHTNESS), let oldValue = oldValue {
            return set(brightness, for: .BRIGHTNESS, smooth: true, oldValue: oldValue)
        }
        return set(brightness, for: .BRIGHTNESS)
    }

    func setContrast(_ contrast: Contrast, oldValue: Contrast? = nil) -> Bool {
        if Defaults[.smoothTransition], supportsSmoothTransition(for: .CONTRAST), let oldValue = oldValue {
            return set(contrast, for: .CONTRAST, smooth: true, oldValue: oldValue)
        }
        return set(contrast, for: .CONTRAST)
    }

    func setVolume(_ volume: UInt8) -> Bool {
        set(volume, for: .AUDIO_SPEAKER_VOLUME)
    }

    func setMute(_ muted: Bool) -> Bool {
        set(muted ? 1 : 2, for: .AUDIO_MUTE)
    }

    func setInput(_ input: InputSource) -> Bool {
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

    func getVolume() -> UInt8? {
        get(.AUDIO_SPEAKER_VOLUME)
    }

    func getInput() -> InputSource? {
        guard let input = get(.INPUT_SOURCE), let inputSource = InputSource(rawValue: input) else { return nil }
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
        if display.isForTesting, let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay {
            return true
        }

        guard let enabledForDisplay = display.enabledControls[displayControl], enabledForDisplay,
              let service = NetworkControl.controllersForDisplay[display.id] else { return false }

        if service.url == nil {
            async(runLoopQueue: lowprioQueue) {
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

    var responsiveTryCount = 0

    func isResponsive() -> Bool {
        guard let service = NetworkControl.controllersForDisplay[display.id] else {
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

        asyncAfter(ms: 100, uniqueTaskKey: "networkControlResponsiveChecker") { [weak self] in
            guard let self = self else { return }
            guard let service = NetworkControl.controllersForDisplay[self.display.id],
                  let url = service.url, let newURL = service.getFirstRespondingURL(urls: service.urls, timeout: 600.milliseconds, retries: 1)
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
                service.smoothTransitionUrl = service.getFirstRespondingURL(urls: service.smoothTransitionUrls, timeout: 600.milliseconds, retries: 1)
            }
        }

        return true
    }

    func resetState() {
        Self.controllersForDisplay.removeValue(forKey: display.id)
        Self.resetState()
    }

    static let browserSemaphore = DispatchSemaphore(value: 1)

    static func resetState() {
        async(timeout: 2.minutes) {
            browserSemaphore.wait()
            defer {
                browserSemaphore.signal()
            }

            browser.reset()
            browser.browse(type: ServiceType.tcp("ddcutil"))
        }
    }

    func supportsSmoothTransition(for _: ControlID) -> Bool {
        guard let service = NetworkControl.controllersForDisplay[display.id] else { return false }
        return service.smoothTransitionUrl != nil
    }
}
