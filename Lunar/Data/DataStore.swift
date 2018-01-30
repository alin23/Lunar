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
}

class DataStore: NSObject {
    let defaults: UserDefaults = UserDefaults()
    let container = NSPersistentContainer(name: "Model")
    var context: NSManagedObjectContext
    
    func save(context: NSManagedObjectContext? = nil) {
        do {
            try (context ?? self.context).save()
        } catch {
            log.error("Error on saving context: \(error)")
        }
    }
    
    func fetchDisplays(by serials: [String]) throws -> [Display] {
        let fetchRequest = NSFetchRequest<Display>(entityName: "Display")
        fetchRequest.predicate = NSPredicate(format: "serial IN %@", Set(serials))
        return try context.fetch(fetchRequest)
    }
    
    func fetchAppExceptions(by names: [String]) throws -> [AppException] {
        let fetchRequest = NSFetchRequest<AppException>(entityName: "AppException")
        fetchRequest.predicate = NSPredicate(format: "name IN %@", Set(names))
        return try context.fetch(fetchRequest)
    }
    
    static func firstRun(context: NSManagedObjectContext) {
        for app in DEFAULT_APP_EXCEPTIONS {
            let _ = AppException(name: app, context: context)
        }
    }
    
    override init() {
        container.loadPersistentStores(completionHandler: { (description, error) in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        })
        context = container.newBackgroundContext()
        if defaults.object(forKey: "firstRun") == nil {
            DataStore.firstRun(context: context)
            defaults.set(true, forKey: "firstRun")
        }
        if defaults.object(forKey: "interpolationFactor") == nil {
            defaults.set(0.5, forKey: "interpolationFactor")
        }
        if defaults.object(forKey: "didScrollTextField") == nil {
            defaults.set(false, forKey: "didScrollTextField")
        }
        if defaults.object(forKey: "daylightExtensionMinutes") == nil {
            defaults.set(0, forKey: "daylightExtensionMinutes")
        }
        if defaults.object(forKey: "noonDurationMinutes") == nil {
            defaults.set(60, forKey: "noonDurationMinutes")
        }
    }
    
}
