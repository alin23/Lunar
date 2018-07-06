//
//  DataStore.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

extension UserDefaults {
    @objc dynamic var noonDurationMinutes: Int {
        return integer(forKey: "noonDurationMinutes")
    }

    @objc dynamic var daylightExtensionMinutes: Int {
        return integer(forKey: "daylightExtensionMinutes")
    }

    @objc dynamic var interpolationFactor: Double {
        return double(forKey: "interpolationFactor")
    }

    @objc dynamic var startAtLogin: Bool {
        return bool(forKey: "startAtLogin")
    }

    @objc dynamic var didScrollTextField: Bool {
        return bool(forKey: "didScrollTextField")
    }

    @objc dynamic var didSwipeLeft: Bool {
        return bool(forKey: "didSwipeLeft")
    }

    @objc dynamic var didSwipeRight: Bool {
        return bool(forKey: "didSwipeRight")
    }

    @objc dynamic var adaptiveBrightnessEnabled: Bool {
        return bool(forKey: "adaptiveBrightnessEnabled")
    }
}

@available(OSX 10.12, *)
let container = NSPersistentContainer(name: "Model")

let appName = Bundle.main.infoDictionary!["CFBundleName"] as! String
let persistentStoreUrl = FileManager().urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(appName, isDirectory: true).appendingPathComponent("Model.sqlite", isDirectory: false)
let model = NSManagedObjectModel(contentsOf: Bundle.main.url(forResource: "Model", withExtension: "momd")!)
let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model!)

class DataStore: NSObject {
    static let defaults: UserDefaults = UserDefaults()
    let defaults: UserDefaults = DataStore.defaults
    var context: NSManagedObjectContext

    func save(context: NSManagedObjectContext? = nil) {
        do {
            try (context ?? self.context).save()
        } catch {
            log.error("Error on saving context: \(error)")
        }
    }

    func fetchDisplays(by serials: [String], context: NSManagedObjectContext? = nil) throws -> [Display] {
        let fetchRequest = NSFetchRequest<Display>(entityName: "Display")
        fetchRequest.predicate = NSPredicate(format: "serial IN %@", Set(serials))
        return try (context ?? self.context).fetch(fetchRequest)
    }

    func fetchAppExceptions(by identifiers: [String], context: NSManagedObjectContext? = nil) throws -> [AppException] {
        let fetchRequest = NSFetchRequest<AppException>(entityName: "AppException")
        fetchRequest.predicate = NSPredicate(format: "identifier IN %@", Set(identifiers))
        return try (context ?? self.context).fetch(fetchRequest)
    }

    func fetchAppException(by identifier: String, context: NSManagedObjectContext? = nil) throws -> AppException? {
        return try DataStore.fetchAppException(by: identifier, context: (context ?? self.context))
    }

    static func fetchAppException(by identifier: String, context: NSManagedObjectContext) throws -> AppException? {
        let fetchRequest = NSFetchRequest<AppException>(entityName: "AppException")
        fetchRequest.predicate = NSPredicate(format: "identifier == %@", identifier)
        return try context.fetch(fetchRequest).first
    }

    static func firstRun(context: NSManagedObjectContext) {
        log.debug("First run")
        thisIsFirstRun = true
        for app in DEFAULT_APP_EXCEPTIONS {
            let appPath = "/Applications/\(app).app"
            if FileManager.default.fileExists(atPath: appPath) {
                let bundle = Bundle(path: appPath)
                guard let id = bundle?.bundleIdentifier,
                    let name = bundle?.infoDictionary?["CFBundleName"] as? String else {
                    continue
                }
                if let exc = (try? DataStore.fetchAppException(by: id, context: context)) {
                    if exc == nil {
                        _ = AppException(identifier: id, name: name, context: context)
                    }
                    log.debug("Existing app for \(app): \(String(describing: exc))")
                    continue
                }
            }
        }
    }

    override init() {
        if #available(OSX 10.12, *) {
            container.loadPersistentStores(completionHandler: { _, error in
                if let error = error {
                    fatalError("Unable to load persistent stores: \(error)")
                }
            })
            context = container.newBackgroundContext()
        } else {
            do {
                if coordinator.persistentStore(for: persistentStoreUrl) == nil {
                    try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: persistentStoreUrl, options: nil)
                }
            } catch {
                fatalError("Unable to load persistent stores: \(error)")
            }

            context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator
        }
        log.debug("Checking First Run")
        if DataStore.defaults.object(forKey: "firstRun") == nil {
            DataStore.firstRun(context: context)
            DataStore.defaults.set(true, forKey: "firstRun")
        }
        if DataStore.defaults.object(forKey: "interpolationFactor") == nil {
            DataStore.defaults.set(2.0, forKey: "interpolationFactor")
        }
        if DataStore.defaults.object(forKey: "didScrollTextField") == nil {
            DataStore.defaults.set(false, forKey: "didScrollTextField")
        }
        if DataStore.defaults.object(forKey: "didSwipeLeft") == nil {
            DataStore.defaults.set(false, forKey: "didSwipeLeft")
        }
        if DataStore.defaults.object(forKey: "didSwipeRight") == nil {
            DataStore.defaults.set(false, forKey: "didSwipeRight")
        }
        if DataStore.defaults.object(forKey: "startAtLogin") == nil {
            DataStore.defaults.set(true, forKey: "startAtLogin")
        }
        if DataStore.defaults.object(forKey: "daylightExtensionMinutes") == nil {
            DataStore.defaults.set(180, forKey: "daylightExtensionMinutes")
        }
        if DataStore.defaults.object(forKey: "noonDurationMinutes") == nil {
            DataStore.defaults.set(240, forKey: "noonDurationMinutes")
        }
    }
}
