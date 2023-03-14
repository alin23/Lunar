//
//  Ciao.swift
//  Lunar
//
//  Created by Alin Panaitiu on 05.06.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Foundation

// MARK: - CiaoBrowser

//
//  CiaoBrowser.swift
//  Ciao
//
//  Created by Alexandre Tavares on 11/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

final class CiaoBrowser {
    public init() {
        netServiceBrowser = NetServiceBrowser()
        delegate = CiaoBrowserDelegate()
        netServiceBrowser.delegate = delegate
        delegate.browser = self
        netServiceBrowser.remove(from: RunLoop.current, forMode: .default)
        serviceBrowserQueue.syncSafe {
            self.netServiceBrowser.schedule(in: RunLoop.current, forMode: .default)
        }
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        stop()

        services.removeAll()
        netServiceBrowser.delegate = nil
    }

    public var services = Set<NetService>()

    // Handlers
    public var serviceFoundHandler: ((NetService) -> Void)?
    public var serviceRemovedHandler: ((NetService) -> Void)?
    public var serviceResolvedHandler: ((Result<NetService, ErrorDictionary>) -> Void)?
    public var serviceUpdatedTXTHandler: ((NetService) -> Void)?

    public var isSearching = false {
        didSet {
            log.info(isSearching.s)
        }
    }

    public func browse(type: ServiceType, domain: String = "") {
        browse(type: type.description, domain: domain)
    }

    public func browse(type: String, domain: String = "") {
        netServiceBrowser.searchForServices(ofType: type, inDomain: domain)
    }

    public func reset() {
        SwiftyLogger.info("Resetting browser")
        stop()
        services.removeAll()

//        netServiceBrowser.delegate = nil
//        netServiceBrowser = NetServiceBrowser()
//        netServiceBrowser.delegate = delegate
    }

    public func stop() {
        for service in services {
            service.stopMonitoring()
        }

        serviceBrowserQueue.syncSafe {
            self.netServiceBrowser.stop()
        }
    }

    var netServiceBrowser: NetServiceBrowser
    var delegate: CiaoBrowserDelegate

    fileprivate func serviceFound(_ service: NetService) {
        serviceBrowserQueue.syncSafe {
            service.schedule(in: RunLoop.current, forMode: .default)
        }
        service.startMonitoring()
        services.update(with: service)
        serviceFoundHandler?(service)

        // resolve services if handler is registered
        guard let serviceResolvedHandler else { return }
        var resolver: CiaoResolver? = CiaoResolver(service: service)
        resolver?.resolve(withTimeout: 0) { result in
            serviceResolvedHandler(result)
            // retain resolver until resolution
            resolver = nil
        }
    }

    fileprivate func serviceRemoved(_ service: NetService) {
        services.remove(service)
        serviceRemovedHandler?(service)
    }

    fileprivate func serviceUpdatedTXT(_ service: NetService, _ txtRecord: Data) {
        service.setTXTRecord(txtRecord)
        serviceUpdatedTXTHandler?(service)
    }
}

// MARK: - CiaoBrowserDelegate

final class CiaoBrowserDelegate: NSObject, NetServiceBrowserDelegate {
    public func netServiceBrowser(_: NetServiceBrowser, didFind service: NetService, moreComing _: Bool) {
        SwiftyLogger.info("Service found \(service)")
        browser?.serviceFound(service)
    }

    public func netServiceBrowserWillSearch(_: NetServiceBrowser) {
//        Logger.info("Browser will search")
        browser?.isSearching = true
    }

    public func netServiceBrowserDidStopSearch(_: NetServiceBrowser) {
//        Logger.info("Browser stopped search")
        browser?.isSearching = false
        onStop?()
    }

    public func netServiceBrowser(_: NetServiceBrowser, didNotSearch _: [String: NSNumber]) {
//        Logger.debug("Browser didn't search \(errorDict)")
        browser?.isSearching = false
    }

    public func netServiceBrowser(_: NetServiceBrowser, didRemove service: NetService, moreComing _: Bool) {
//        Logger.info("Service removed \(service)")
        browser?.serviceRemoved(service)
    }

    public func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
//        Logger.info("Service updated txt records \(sender)")
        browser?.serviceUpdatedTXT(sender, data)
    }

    weak var browser: CiaoBrowser?
    var onStop: (() -> Void)?
}

// MARK: - CiaoResolver

//
//  CiaoResolver.swift
//  Ciao
//
//  Created by Alexandre Mantovani Tavares on 14/07/19.
//

final class CiaoResolver {
    public init(service: NetService) {
        self.service = service
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        log.verbose(String(describing: self))
        service.stop()
    }

    public func resolve(withTimeout timeout: TimeInterval, completion: @escaping (Result<NetService, ErrorDictionary>) -> Void) {
        delegate.onResolve = completion
        service.delegate = delegate
        service.resolve(withTimeout: timeout)
    }

    let service: NetService
    let delegate = CiaoResolverDelegate()
}

public typealias ErrorDictionary = [String: Int]

// MARK: Error

extension ErrorDictionary: Error {}

// MARK: - CiaoResolver.CiaoResolverDelegate

extension CiaoResolver {
    final class CiaoResolverDelegate: NSObject, NetServiceDelegate {
        var onResolve: ((Result<NetService, ErrorDictionary>) -> Void)?

        func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
            SwiftyLogger.error("Service didn't resolve \(sender) \(errorDict)")
            onResolve?(Result.failure(errorDict.mapValues { $0.intValue }))
        }

        func netServiceDidResolveAddress(_ sender: NetService) {
            SwiftyLogger.info("Service resolved \(sender)")
            onResolve?(Result.success(sender))
        }

        func netServiceWillResolve(_ sender: NetService) {
            SwiftyLogger.info("Service will resolve \(sender)")
        }
    }
}

// MARK: - CiaoServer

//
//  CiaoService.swift
//  Ciao
//
//  Created by Alexandre Tavares on 10/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

final class CiaoServer {
    public convenience init(type: ServiceType, domain: String = "", name: String = "", port: Int32 = 0) {
        self.init(type: type.description, domain: domain, name: name, port: port)
    }

    public init(type: String, domain: String = "", name: String = "", port: Int32 = 0) {
        netService = NetService(domain: domain, type: type, name: name, port: port)
        delegate = CiaoServerDelegate()
        delegate?.server = self
        netService.delegate = delegate
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        stop()
        netService.delegate = nil
        delegate = nil
    }

    public fileprivate(set) var started = false {
        didSet {
            successCallback?(started)
            successCallback = nil
        }
    }

    public var txtRecord: [String: String]? {
        get {
            netService.txtRecordDictionary
        }
        set {
            netService.setTXTRecord(dictionary: newValue)
            SwiftyLogger.info("TXT Record updated \(newValue ?? [:])")
        }
    }

    public func start(options: NetService.Options = [], success: ((Bool) -> Void)? = nil) {
        if started {
            success?(true)
            return
        }
        successCallback = success
        netService.schedule(in: RunLoop.current, forMode: RunLoop.Mode.common)
        netService.publish(options: options)
    }

    public func stop() {
        netService.stop()
    }

    var netService: NetService
    var delegate: CiaoServerDelegate?
    var successCallback: ((Bool) -> Void)?
}

// MARK: - CiaoServerDelegate

final class CiaoServerDelegate: NSObject, NetServiceDelegate {
    weak var server: CiaoServer?

    func netServiceDidPublish(_: NetService) {
        server?.started = true
        SwiftyLogger.info("CiaoServer Started")
    }

    func netService(_: NetService, didNotPublish errorDict: [String: NSNumber]) {
        server?.started = false
        SwiftyLogger.error("CiaoServer did not publish \(errorDict)")
    }

    func netServiceDidStop(_: NetService) {
        server?.started = false
        SwiftyLogger.info("CiaoServer Stopped")
    }
}

// MARK: - Level

//
//  Logger.swift
//  Ciao
//
//  Created by Alexandre Tavares on 11/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

public enum Level: Int {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4

    var description: String {
        switch self {
        case .verbose:
            return "verbose"
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .warning:
            return "warning"
        case .error:
            return "error"
        }
    }
}

//
//  NetServiceExtension.swift
//  Ciao
//
//  Created by Alexandre Tavares on 11/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

public extension NetService {
    class func dictionary(fromTXTRecord data: Data) -> [String: String] {
        NetService.dictionary(fromTXTRecord: data).mapValues { data in
            String(data: data, encoding: .utf8) ?? ""
        }
    }

    class func data(fromTXTRecord data: [String: String]) -> Data {
        NetService.data(fromTXTRecord: data.mapValues { $0.data(using: .utf8) ?? Data() })
    }

    func setTXTRecord(dictionary: [String: String]?) {
        guard let dictionary else {
            setTXTRecord(nil)
            return
        }
        setTXTRecord(NetService.data(fromTXTRecord: dictionary))
    }

    var txtRecordDictionary: [String: String]? {
        guard let data = txtRecordData() else { return nil }
        return NetService.dictionary(fromTXTRecord: data)
    }
}

// MARK: - ServiceType

//
//  ServiceType.swift
//  Ciao
//
//  Created by Alexandre Tavares on 16/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

public enum ServiceType {
    case tcp(String)
    case udp(String)

    public var description: String {
        switch self {
        case let .tcp(name):
            return "_\(name)._tcp"
        case let .udp(name):
            return "_\(name)._udp"
        }
    }
}
