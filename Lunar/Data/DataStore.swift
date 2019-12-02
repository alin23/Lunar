//
//  DataStore.swift
//  Lunar
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

let APP_SETTINGS = [
    "adaptiveBrightnessMode",
    "brightnessLimitMax",
    "brightnessLimitMin",
    "brightnessOffset",
    "brightnessStep",
    "contrastLimitMax",
    "contrastLimitMin",
    "contrastOffset",
    "contrastStep",
    "curveFactor",
    "daylightExtensionMinutes",
    "debug",
    "didScrollTextField",
    "didSwipeLeft",
    "didSwipeRight",
    "didSwipeToHotkeys",
    "firstRun",
    "hotkeys",
    "manualLocation",
    "noonDurationMinutes",
    "refreshBrightness",
    "showNavigationHints",
    "smoothTransition",
    "solarNoon",
    "startAtLogin",
    "sunrise",
    "sunset",
    "syncPollingSeconds",
]

extension UserDefaults {
    @objc dynamic var sunrise: String {
        return string(forKey: "sunrise") ?? ""
    }

    @objc dynamic var sunset: String {
        return string(forKey: "sunset") ?? ""
    }

    @objc dynamic var solarNoon: String {
        return string(forKey: "solarNoon") ?? ""
    }

    @objc dynamic var noonDurationMinutes: Int {
        return integer(forKey: "noonDurationMinutes")
    }

    @objc dynamic var daylightExtensionMinutes: Int {
        return integer(forKey: "daylightExtensionMinutes")
    }

    @objc dynamic var curveFactor: Double {
        return double(forKey: "curveFactor")
    }

    @objc dynamic var locationLat: Double {
        return double(forKey: "locationLat")
    }

    @objc dynamic var locationLon: Double {
        return double(forKey: "locationLon")
    }

    @objc dynamic var manualLocation: Bool {
        return bool(forKey: "manualLocation")
    }

    @objc dynamic var showNavigationHints: Bool {
        return bool(forKey: "showNavigationHints")
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

    @objc dynamic var didSwipeToHotkeys: Bool {
        return bool(forKey: "didSwipeToHotkeys")
    }

    @objc dynamic var didSwipeRight: Bool {
        return bool(forKey: "didSwipeRight")
    }

    @objc dynamic var smoothTransition: Bool {
        return bool(forKey: "smoothTransition")
    }

    @objc dynamic var refreshBrightness: Bool {
        return bool(forKey: "refreshBrightness")
    }

    @objc dynamic var debug: Bool {
        return bool(forKey: "debug")
    }

    @objc dynamic var syncPollingSeconds: Int {
        return integer(forKey: "syncPollingSeconds")
    }

    @objc dynamic var adaptiveBrightnessMode: Int {
        return integer(forKey: "adaptiveBrightnessMode")
    }

    @objc dynamic var brightnessStep: Int {
        return integer(forKey: "brightnessStep")
    }

    @objc dynamic var contrastStep: Int {
        return integer(forKey: "contrastStep")
    }

    @objc dynamic var brightnessOffset: Int {
        return integer(forKey: "brightnessOffset")
    }

    @objc dynamic var contrastOffset: Int {
        return integer(forKey: "contrastOffset")
    }

    @objc dynamic var brightnessLimitMin: Int {
        return integer(forKey: "brightnessLimitMin")
    }

    @objc dynamic var contrastLimitMin: Int {
        return integer(forKey: "contrastLimitMin")
    }

    @objc dynamic var brightnessLimitMax: Int {
        return integer(forKey: "brightnessLimitMax")
    }

    @objc dynamic var contrastLimitMax: Int {
        return integer(forKey: "contrastLimitMax")
    }

    @objc dynamic var hotkeys: [String: Any]? {
        return dictionary(forKey: "hotkeys")
    }
}

@available(OSX 10.12, *)
let container = NSPersistentContainer(name: "Model")

let appName = Bundle.main.infoDictionary!["CFBundleName"] as! String
let persistentStoreUrl = FileManager().urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(appName, isDirectory: true).appendingPathComponent("Model.sqlite", isDirectory: false)
let model = NSManagedObjectModel(contentsOf: Bundle.main.url(forResource: "Model", withExtension: "momd")!)
let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model!)

class DataStore: NSObject {
    static let defaults: UserDefaults = NSUserDefaultsController.shared.defaults
    let defaults: UserDefaults = DataStore.defaults
    var context: NSManagedObjectContext

    func save(context: NSManagedObjectContext? = nil) {
        do {
            try (context ?? self.context).save()
        } catch {
            log.error("Error on saving context: \(error)")
        }
    }

    func hotkeys() -> [HotkeyIdentifier: [HotkeyPart: Int]]? {
        guard let hotkeyConfig = defaults.hotkeys else { return nil }
        return Hotkey.toDictionary(hotkeyConfig)
    }

    func cleanUpDisplays(context: NSManagedObjectContext? = nil) throws {
        if let display = DDC.getBuiltinDisplay() {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Display")
            fetchRequest.predicate = NSPredicate(format: "id == %@", NSNumber(value: display))
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try (context ?? self.context).execute(deleteRequest)
        }
    }

    func fetchDisplays(by serials: [String], context: NSManagedObjectContext? = nil) throws -> [Display] {
        let fetchRequest = NSFetchRequest<Display>(entityName: "Display")
        fetchRequest.predicate = NSPredicate(format: "serial IN %@", Set(serials))
        return try (context ?? self.context).fetch(fetchRequest)
    }

    func countDisplays(context: NSManagedObjectContext? = nil) -> Int {
        let fetchRequest = NSFetchRequest<Display>(entityName: "Display")
        return (try? (context ?? self.context).count(for: fetchRequest)) ?? 0
    }

    func fetchAppExceptions(by identifiers: [String], context: NSManagedObjectContext? = nil) throws -> [AppException] {
        let fetchRequest = NSFetchRequest<AppException>(entityName: "AppException")
        fetchRequest.predicate = NSPredicate(format: "identifier IN %@", Set(identifiers))
        return try (context ?? self.context).fetch(fetchRequest)
    }

    func fetchAllAppExceptions(context: NSManagedObjectContext? = nil) throws -> [AppException] {
        let fetchRequest = NSFetchRequest<AppException>(entityName: "AppException")
        return try (context ?? self.context).fetch(fetchRequest)
    }

    func fetchAppException(by identifier: String, context: NSManagedObjectContext? = nil) throws -> AppException? {
        return try DataStore.fetchAppException(by: identifier, context: context ?? self.context)
    }

    func settingsDictionary() -> [String: Any] {
        return defaults.dictionaryRepresentation().filter { elem in
            APP_SETTINGS.contains(elem.key)
        }
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
                if let exc = ((try? DataStore.fetchAppException(by: id, context: context)) as AppException??) {
                    if exc == nil {
                        _ = AppException(identifier: id, name: name, context: context)
                    }
                    log.debug("Existing app for \(app): \(String(describing: exc))")
                    continue
                }
            }
        }
    }

    static func setDefault(_ value: Int, for key: String) {
        if DataStore.defaults.object(forKey: key) == nil {
            DataStore.defaults.set(value, forKey: key)
        }
    }

    static func setDefault(_ value: Double, for key: String) {
        if DataStore.defaults.object(forKey: key) == nil {
            DataStore.defaults.set(value, forKey: key)
        }
    }

    static func setDefault(_ value: Bool, for key: String) {
        if DataStore.defaults.object(forKey: key) == nil {
            DataStore.defaults.set(value, forKey: key)
        }
    }

    static func setDefault(_ value: NSDictionary, for key: String) {
        if DataStore.defaults.object(forKey: key) == nil {
            DataStore.defaults.set(value, forKey: key)
        }
    }

    override init() {
        NSUserDefaultsController.shared.appliesImmediately = true

        if #available(OSX 10.12, *) {
            container.loadPersistentStores(completionHandler: { _, error in
                if let error = error {
                    fatalError("Unable to load persistent stores: \(error)")
                }
            })
            context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy(merge: .overwriteMergePolicyType)
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
            context.mergePolicy = NSMergePolicy(merge: .overwriteMergePolicyType)
        }
        super.init()

        log.debug("Checking First Run")
        if DataStore.defaults.object(forKey: "firstRun") == nil {
            DataStore.firstRun(context: context)
            DataStore.defaults.set(true, forKey: "firstRun")
        } else {
            try? cleanUpDisplays()
        }

        DataStore.setDefault(0.5, for: "curveFactor")
        DataStore.setDefault(false, for: "didScrollTextField")
        DataStore.setDefault(false, for: "didSwipeToHotkeys")
        DataStore.setDefault(false, for: "didSwipeLeft")
        DataStore.setDefault(false, for: "didSwipeRight")
        DataStore.setDefault(false, for: "smoothTransition")
        DataStore.setDefault(false, for: "refreshBrightness")
        DataStore.setDefault(false, for: "debug")
        DataStore.setDefault(false, for: "manualLocation")
        DataStore.setDefault(false, for: "showNavigationHints")
        DataStore.setDefault(true, for: "startAtLogin")
        DataStore.setDefault(180, for: "daylightExtensionMinutes")
        DataStore.setDefault(240, for: "noonDurationMinutes")
        DataStore.setDefault(5, for: "brightnessOffset")
        DataStore.setDefault(20, for: "contrastOffset")
        DataStore.setDefault(5, for: "brightnessLimitMin")
        DataStore.setDefault(20, for: "contrastLimitMin")
        DataStore.setDefault(90, for: "brightnessLimitMax")
        DataStore.setDefault(70, for: "contrastLimitMax")
        DataStore.setDefault(3, for: "brightnessStep")
        DataStore.setDefault(3, for: "contrastStep")
        DataStore.setDefault(2, for: "syncPollingSeconds")
        DataStore.setDefault(AdaptiveMode.sync.rawValue, for: "adaptiveBrightnessMode")
        DataStore.setDefault(Hotkey.defaultHotkeys, for: "hotkeys")
    }
}
