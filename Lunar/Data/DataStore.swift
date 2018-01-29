//
//  DataStore.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

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
    
    override init() {
        container.loadPersistentStores(completionHandler: { (description, error) in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        })
        context = container.newBackgroundContext()
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
