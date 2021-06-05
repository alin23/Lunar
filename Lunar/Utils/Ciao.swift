//
//  Ciao.swift
//  Lunar
//
//  Created by Alin Panaitiu on 05.06.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Foundation


//
//  CiaoBrowser.swift
//  Ciao
//
//  Created by Alexandre Tavares on 11/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//


public class CiaoBrowser {
    var netServiceBrowser: NetServiceBrowser
    var delegate: CiaoBrowserDelegate

    public var services = Set<NetService>()

    // Handlers
    public var serviceFoundHandler: ((NetService) -> Void)?
    public var serviceRemovedHandler: ((NetService) -> Void)?
    public var serviceResolvedHandler: ((Result<NetService, ErrorDictionary>) -> Void)?
    public var serviceUpdatedTXTHandler: ((NetService) -> Void)?


    public var isSearching = false {
        didSet {
            Logger.info(isSearching)
        }
    }

    public init() {
        netServiceBrowser = NetServiceBrowser()
        delegate = CiaoBrowserDelegate()
        netServiceBrowser.delegate = delegate
        delegate.browser = self
        netServiceBrowser.remove(from: RunLoop.current, forMode: .default)
        serviceBrowserQueue.sync {
            self.netServiceBrowser.schedule(in: RunLoop.current, forMode: .default)
        }
    }

    public func browse(type: ServiceType, domain: String = "") {
        browse(type: type.description, domain: domain)
    }

    public func browse(type: String, domain: String = "") {
        netServiceBrowser.searchForServices(ofType: type, inDomain: domain)
    }

    fileprivate func serviceFound(_ service: NetService) {
        serviceBrowserQueue.sync {
            service.schedule(in: RunLoop.current, forMode: .default)
        }
        service.startMonitoring()
        services.update(with: service)
        serviceFoundHandler?(service)

        // resolve services if handler is registered
        guard let serviceResolvedHandler = serviceResolvedHandler else { return }
        var resolver: CiaoResolver? = CiaoResolver(service: service)
        resolver?.resolve(withTimeout: 0) { result in
            serviceResolvedHandler(result)
            // retain resolver until resolution
            resolver = nil
        }
    }

    fileprivate func serviceRemoved(_ service: NetService) {
        serviceBrowserQueue.sync {
            service.remove(from: RunLoop.current, forMode: .default)
        }
        services.remove(service)
        serviceRemovedHandler?(service)
    }

    fileprivate func serviceUpdatedTXT(_ service: NetService, _ txtRecord: Data) {
        service.setTXTRecord(txtRecord)
        serviceUpdatedTXTHandler?(service)
    }

    public func reset() {
        stop()
        services.removeAll()
        
        serviceBrowserQueue.sync {
            self.netServiceBrowser.schedule(in: RunLoop.current, forMode: .default)
        }
//        netServiceBrowser.delegate = nil
//        netServiceBrowser = NetServiceBrowser()
//        netServiceBrowser.delegate = delegate
    }

    public func stop() {
        for service in services {
            service.stopMonitoring()
        }

        serviceBrowserQueue.sync {
            self.netServiceBrowser.remove(from: RunLoop.current, forMode: .default)
            self.netServiceBrowser.stop()
        }
    }

    deinit {
        stop()

        services.removeAll()
        netServiceBrowser.delegate = nil
    }
}

public class CiaoBrowserDelegate: NSObject, NetServiceBrowserDelegate {
    weak var browser: CiaoBrowser?
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Logger.info("Service found \(service)")
        self.browser?.serviceFound(service)
    }

    public func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        Logger.info("Browser will search")
        self.browser?.isSearching = true
    }

    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        Logger.info("Browser stopped search")
        self.browser?.isSearching = false
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        Logger.debug("Browser didn't search \(errorDict)")
        self.browser?.isSearching = false
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        Logger.info("Service removed \(service)")
        self.browser?.serviceRemoved(service)
    }

    public func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        Logger.info("Service updated txt records \(sender)")
        self.browser?.serviceUpdatedTXT(sender, data)
    }
}
//
//  CiaoResolver.swift
//  Ciao
//
//  Created by Alexandre Mantovani Tavares on 14/07/19.
//


public class CiaoResolver {
    public init(service: NetService) {
        self.service = service
    }

    let service: NetService
    let delegate: CiaoResolverDelegate = CiaoResolverDelegate()

    public func resolve(withTimeout timeout: TimeInterval, completion: @escaping (Result<NetService, ErrorDictionary>) -> Void) {
        delegate.onResolve = completion
        service.delegate = delegate
        service.resolve(withTimeout: timeout)
    }

    deinit {
        Logger.verbose(self)
        service.stop()
    }

}

public typealias ErrorDictionary = [String: NSNumber]

extension CiaoResolver {
    class CiaoResolverDelegate: NSObject, NetServiceDelegate {
        var onResolve: ((Result<NetService, ErrorDictionary>) -> Void)?

        func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
            Logger.error("Service didn't resolve \(sender) \(errorDict)")
            onResolve?(Result.failure(errorDict))
        }

        func netServiceDidResolveAddress(_ sender: NetService) {
            Logger.info("Service resolved \(sender)")
            onResolve?(Result.success(sender))
        }

        func netServiceWillResolve(_ sender: NetService) {
            Logger.info("Service will resolve \(sender)")
        }
    }
}
//
//  CiaoService.swift
//  Ciao
//
//  Created by Alexandre Tavares on 10/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//


public class CiaoServer {
    var netService: NetService
    var delegate: CiaoServerDelegate?
    var successCallback: ((Bool) -> Void)?
    public fileprivate(set) var started = false {
        didSet {
            successCallback?(started)
            successCallback = nil
        }
    }
    public var txtRecord: [String: String]? {
        get {
            return netService.txtRecordDictionary
        }
        set {
            netService.setTXTRecord(dictionary: newValue)
            Logger.info("TXT Record updated \(newValue ?? [:])")
        }
    }

    public convenience init(type: ServiceType, domain: String = "", name: String = "", port: Int32 = 0) {
        self.init(type: type.description, domain: domain, name: name, port: port)
    }

    public init(type: String, domain: String = "", name: String = "", port: Int32 = 0) {
        netService = NetService(domain: domain, type: type, name: name, port: port)
        delegate = CiaoServerDelegate()
        delegate?.server = self
        netService.delegate = delegate
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

    deinit {
        stop()
        netService.delegate = nil
        delegate = nil
    }
}

class CiaoServerDelegate: NSObject, NetServiceDelegate {
    weak var server: CiaoServer?

    func netServiceDidPublish(_ sender: NetService) {
        server?.started = true
        Logger.info("CiaoServer Started")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        server?.started = false
        Logger.error("CiaoServer did not publish \(errorDict)")
    }

    func netServiceDidStop(_ sender: NetService) {
        server?.started = false
        Logger.info("CiaoServer Stopped")
    }
}
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


extension NetService {
    public class func dictionary(fromTXTRecord data: Data) -> [String: String] {
        return NetService.dictionary(fromTXTRecord: data).mapValues { data in
            String(data: data, encoding: .utf8) ?? ""
        }
    }

    public class func data(fromTXTRecord data: [String: String]) -> Data {
        return NetService.data(fromTXTRecord: data.mapValues { $0.data(using: .utf8) ?? Data() })
    }

    public func setTXTRecord(dictionary: [String: String]?){
        guard let dictionary = dictionary else {
            self.setTXTRecord(nil)
            return
        }
        self.setTXTRecord(NetService.data(fromTXTRecord: dictionary))
    }

    public var txtRecordDictionary: [String: String]? {
        guard let data = self.txtRecordData() else { return nil }
        return NetService.dictionary(fromTXTRecord: data)
    }
}
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
        case .tcp(let name):
            return "_\(name)._tcp"
        case .udp(let name):
            return "_\(name)._udp"
        }
    }
}
