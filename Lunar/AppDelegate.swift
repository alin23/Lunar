//
//  AppDelegate.swift
//  Lunar
//
//  Created by Alin on 30/11/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Alamofire
import AMCoreAudio
import Carbon.HIToolbox
import Cocoa
import Compression
import CoreLocation
import Defaults
import LaunchAtLogin
import Magnet
import Sauce
import Sentry
import SwiftDate
import WAYWindow

extension Collection where Index: Comparable {
    subscript(back i: Int) -> Iterator.Element {
        let backBy = i + 1
        return self[index(endIndex, offsetBy: -backBy)]
    }
}

extension Encodable {
    var dictionary: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
    }
}

extension NSViewController {
    func listenForWindowClose(window: NSWindow) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(notification:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }

    @objc func windowWillClose(notification _: Notification) {}
}

private let kAppleInterfaceThemeChangedNotification = "AppleInterfaceThemeChangedNotification"
private let kAppleInterfaceStyle = "AppleInterfaceStyle"
private let kAppleInterfaceStyleSwitchesAutomatically = "AppleInterfaceStyleSwitchesAutomatically"

let concurrentQueue = DispatchQueue(label: "site.lunarapp.concurrent.queue.fg", qos: .userInitiated, attributes: .concurrent)
let serialQueue = DispatchQueue(label: "site.lunarapp.serial.queue.fg", qos: .userInitiated, target: .global())
let appName = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Lunar"

let TEST_MODE = true
let LOG_URL = FileManager().urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(appName, isDirectory: true)
    .appendingPathComponent("swiftybeaver.log", isDirectory: false)
let TRANSFER_URL = "https://transfer.sh"
let LOG_UPLOAD_URL = "https://log.lunar.fyi/upload"
let ANALYTICS_URL = "https://log.lunar.fyi/analytics"
let DEBUG_DATA_HEADERS: HTTPHeaders = [
    "Content-type": "application/octet-stream",
    "Max-Downloads": "50",
    "Max-Days": "5",
]
let LOG_ENCODING_THRESHOLD: UInt64 = 100_000_000 // 100MB

var lunarDisplayNames = [
    "Moony",
    "Celestial",
    "Lunatic",
    "Solar",
    "Stellar",
    "Apollo",
    "Selene",
    "Auroral",
    "Luna",
]

let log = Logger.self
let brightnessAdapter = BrightnessAdapter()

let datastore = DataStore()
var activeDisplay: Display?
var helpPopover: NSPopover?
var menuPopover = NSPopover()
var menuPopoverCloser = DispatchWorkItem {
    menuPopover.close()
}

func closeMenuPopover(after ms: Int) {
    menuPopoverCloser.cancel()
    menuPopoverCloser = DispatchWorkItem {
        menuPopover.close()
    }
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    DispatchQueue.main.asyncAfter(deadline: deadline, execute: menuPopoverCloser)
}

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

func cap<T: Comparable>(_ number: T, minVal: T, maxVal: T) -> T {
    return max(min(number, maxVal), minVal)
}

var upHotkey: Magnet.HotKey?
var downHotkey: Magnet.HotKey?
var leftHotkey: Magnet.HotKey?
var rightHotkey: Magnet.HotKey?

func disableUpDownHotkeys() {
    log.debug("Unregistering up/down hotkeys")
    HotKeyCenter.shared.unregisterHotKey(with: "increaseValue")
    HotKeyCenter.shared.unregisterHotKey(with: "decreaseValue")
    upHotkey?.unregister()
    downHotkey?.unregister()
    upHotkey = nil
    downHotkey = nil
}

func disableLeftRightHotkeys() {
    log.debug("Unregistering left/right hotkeys")
    HotKeyCenter.shared.unregisterHotKey(with: "navigateBack")
    HotKeyCenter.shared.unregisterHotKey(with: "navigateForward")
    leftHotkey?.unregister()
    rightHotkey?.unregister()
    leftHotkey = nil
    rightHotkey = nil
}

func disableUIHotkeys() {
    disableUpDownHotkeys()
    disableLeftRightHotkeys()
}

var thisIsFirstRun = false

func fadeTransition(duration: TimeInterval) -> CATransition {
    let transition = CATransition()
    transition.duration = duration
    transition.type = .fade
    return transition
}

extension String {
    var stripped: String {
        let okayChars = Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890+-=().!_")
        return filter { okayChars.contains($0) }
    }
}

class AudioEventSubscriber: EventSubscriber {
    func eventReceiver(_ event: AMCoreAudio.Event) {
        guard let hwEvent = event as? AudioHardwareEvent else {
            return
        }

        switch hwEvent {
        case .defaultOutputDeviceChanged, .defaultSystemOutputDeviceChanged:
            runInMainThread {
                appDelegate().startOrRestartMediaKeyTap()
            }
        default:
            return
        }
    }

    var hashValue: Int = 100
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate, NSMenuDelegate {
    var locationManager: CLLocationManager?
    var windowController: ModernWindowController?
    var valuesReaderThread: Foundation.Thread!
    var locationThread: Foundation.Thread!
    var syncThread: Foundation.Thread!
    var syncPollingSeconds: Int = Defaults[.syncPollingSeconds]
    var refreshValues: Bool = Defaults[.refreshValues]

    var mediaKeysEnabledObserver: DefaultsObservation?
    var volumeKeysEnabledObserver: DefaultsObservation?
    var daylightObserver: DefaultsObservation?
    var curveFactorObserver: DefaultsObservation?
    var noonObserver: DefaultsObservation?
    var sunsetObserver: DefaultsObservation?
    var sunriseObserver: DefaultsObservation?
    var solarNoonObserver: DefaultsObservation?
    var brightnessOffsetObserver: DefaultsObservation?
    var contrastOffsetObserver: DefaultsObservation?
    var adaptiveModeObserver: DefaultsObservation?
    var hotkeyObserver: DefaultsObservation?
    var loginItemObserver: DefaultsObservation?
    var syncPollingSecondsObserver: DefaultsObservation?
    var refreshValuesObserver: DefaultsObservation?
    var hideMenuBarIconObserver: DefaultsObservation?

    var statusButtonTrackingArea: NSTrackingArea?
    var statusItemButtonController: StatusItemButtonController?
    var alamoFireManager: Session?

    @IBOutlet var versionMenuItem: NSMenuItem!
    @IBOutlet var menu: NSMenu!
    @IBOutlet var preferencesMenuItem: NSMenuItem!
    @IBOutlet var stateMenuItem: NSMenuItem!
    @IBOutlet var toggleMenuItem: NSMenuItem!
    @IBOutlet var debugMenuItem: NSMenuItem!
    @IBOutlet var builtinBrightnessMenuItem: NSMenuItem!

    @IBOutlet var percent0MenuItem: NSMenuItem!
    @IBOutlet var percent25MenuItem: NSMenuItem!
    @IBOutlet var percent50MenuItem: NSMenuItem!
    @IBOutlet var percent75MenuItem: NSMenuItem!
    @IBOutlet var percent100MenuItem: NSMenuItem!

    @IBOutlet var brightnessUpMenuItem: NSMenuItem!
    @IBOutlet var brightnessDownMenuItem: NSMenuItem!
    @IBOutlet var contrastUpMenuItem: NSMenuItem!
    @IBOutlet var contrastDownMenuItem: NSMenuItem!

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    func menuWillOpen(_: NSMenu) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3"
        versionMenuItem?.title = "Lunar v\(version)"
        toggleMenuItem.title = AppDelegate.getToggleMenuItemTitle()
        stateMenuItem.title = AppDelegate.getStateMenuItemTitle()
    }

    func initHotkeys() {
        var hotkeyConfig = Defaults[.hotkeys]

        for identifier in HotkeyIdentifier.allCases {
            guard let hotkey = hotkeyConfig[identifier] ?? Hotkey.defaults[identifier],
                let keyCode = hotkey[.keyCode],
                var enabled = hotkey[.enabled],
                let modifiers = hotkey[.modifiers]
            else {
                continue
            }

            if hotkeyConfig[identifier] == nil {
                hotkeyConfig[identifier] = hotkey
            }

            if !preciseHotkeys.contains(identifier) {
                if let keyCombo = KeyCombo(QWERTYKeyCode: keyCode, carbonModifiers: modifiers) {
                    Hotkey.keys[identifier] = Magnet.HotKey(
                        identifier: identifier.rawValue,
                        keyCombo: keyCombo,
                        target: self,
                        action: Hotkey.handler(identifier: identifier)
                    )
                    if enabled == 1 {
                        Hotkey.keys[identifier]??.register()
                    }
                }
            } else {
                guard let coarseIdentifier = coarseHotkeysMapping[identifier],
                    let coarseHotkey = hotkeyConfig[coarseIdentifier] ?? Hotkey.defaults[coarseIdentifier],
                    let coarseKeyCode = coarseHotkey[.keyCode],
                    let coarseEnabled = coarseHotkey[.enabled],
                    let coarseModifiers = coarseHotkey[.modifiers]
                else {
                    continue
                }

                var flags = coarseModifiers.convertSupportCocoaModifiers()
                if flags.contains(.option) {
                    log.warning("Hotkey \(coarseIdentifier) already binds option. Fine adjustment will be disabled")
                    enabled = 0
                } else {
                    if coarseEnabled == 0 {
                        enabled = coarseEnabled
                    }
                    flags.insert(.option)
                }

                let newModifiers = flags.carbonModifiers()

                hotkeyConfig[identifier]?[.modifiers] = newModifiers
                hotkeyConfig[identifier]?[.keyCode] = coarseKeyCode

                if let keyCombo = KeyCombo(QWERTYKeyCode: coarseKeyCode, carbonModifiers: newModifiers) {
                    Hotkey.keys[identifier] = Magnet.HotKey(
                        identifier: identifier.rawValue,
                        keyCombo: keyCombo,
                        target: self,
                        action: Hotkey.handler(identifier: identifier)
                    )
                    if enabled == 1 {
                        Hotkey.keys[identifier]??.register()
                    }
                }
            }
        }
        Defaults[.hotkeys] = hotkeyConfig
        setKeyEquivalents(hotkeyConfig)
        startOrRestartMediaKeyTap()
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = Defaults.observe(.adaptiveBrightnessMode) { change in
            if change.newValue == change.oldValue {
                return
            }
            brightnessAdapter.mode = change.newValue
            SentrySDK.configureScope { scope in
                scope.setTag(value: brightnessAdapter.adaptiveModeString(), key: "adaptiveMode")
                scope.setTag(value: brightnessAdapter.adaptiveModeString(last: true), key: "lastAdaptiveMode")
            }
            runInMainThread {
                self.resetElements()
            }
            self.manageBrightnessAdapterActivity(mode: brightnessAdapter.mode)
        }
    }

    func listenForSettingsChange() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adaptToSettingsChange(notification:)),
            name: UserDefaults.didChangeNotification,
            object: UserDefaults.standard
        )
    }

    @objc func adaptToSettingsChange(notification _: Notification) {
        brightnessAdapter.addSentryData()
    }

    func showWindow() {
        var mainStoryboard: NSStoryboard?
        if #available(OSX 10.13, *) {
            mainStoryboard = NSStoryboard.main
        } else {
            mainStoryboard = NSStoryboard(name: "Main", bundle: nil)
        }

        if windowController == nil {
            windowController = mainStoryboard?
                .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("windowController")) as? ModernWindowController
        }

        if let wc = windowController {
            wc.showWindow(self)
            setupHotkeys()
            wc.initHelpPopover()

            log.debug("Showing window")
            if let window = wc.window as? ModernWindow {
                log.debug("Sending window to frontmost")
                window.orderFrontRegardless()
            }
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }

    @objc private func activate() {
        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
    }

    func handleDaemon() {
        loginItemObserver = Defaults.observe(.startAtLogin) { change in
            if change.newValue == change.oldValue {
                return
            }
            LaunchAtLogin.isEnabled = change.newValue
        }
    }

    func applicationDidResignActive(_: Notification) {
        log.debug("applicationDidResignActive")

        disableUIHotkeys()
    }

    func setupHotkeys() {
        if windowController != nil, windowController!.window != nil,
            let pageController = windowController!.window!.contentView?.subviews[0].subviews[0].nextResponder as? PageController {
            pageController.setupHotkeys()
        }
    }

    func applicationDidBecomeActive(_: Notification) {
        setupHotkeys()
    }

    func manageBrightnessAdapterActivity(mode: AdaptiveMode) {
        locationThread?.cancel()
        syncThread?.cancel()

        switch mode {
        case .sensor:
            log.info("Sensor mode")
        case .location:
            log.debug("Started BrightnessAdapter in Location mode")
            builtinBrightnessMenuItem.isHidden = true
            brightnessAdapter.adaptBrightness()

            locationThread = Thread {
                while true {
                    brightnessAdapter.adaptBrightness()

                    if Thread.current.isCancelled { return }
                    Thread.sleep(forTimeInterval: 60)
                    if Thread.current.isCancelled { return }
                }
            }
            locationThread.start()
        case .sync:
            log.debug("Started BrightnessAdapter in Sync mode")
            builtinBrightnessMenuItem.isHidden = false

            let builtinBrightness = ((brightnessAdapter.getBuiltinDisplayBrightness() ?? 0.0) * 100).rounded(.toNearestOrAwayFromZero) / 100
            runInMainThread {
                builtinBrightnessMenuItem.title = "Built-in display brightness: \(builtinBrightness)"
            }

            brightnessAdapter.adaptBrightness()

            syncThread = Thread { [weak self] in
                while true {
                    if var builtinBrightness = brightnessAdapter.getBuiltinDisplayBrightness(),
                        brightnessAdapter.lastBuiltinBrightness != builtinBrightness {
                        runInMainThread {
                            self?.builtinBrightnessMenuItem?
                                .title = "Built-in display brightness: \((builtinBrightness * 100).rounded(.toNearestOrAwayFromZero) / 100)"
                        }

                        if builtinBrightness == 0 || builtinBrightness == 100, IsLidClosed(),
                            let lastBrightness = brightnessAdapter.lastValidBuiltinBrightness({ b in b > 0 && b < 100 }) {
                            builtinBrightness = Double(lastBrightness)
                        }

                        brightnessAdapter.lastBuiltinBrightness = builtinBrightness
                        brightnessAdapter.adaptBrightness(percent: builtinBrightness)
                    }

                    if Thread.current.isCancelled { return }
                    Thread.sleep(forTimeInterval: TimeInterval(self?.syncPollingSeconds ?? 1))
                    if Thread.current.isCancelled { return }
                }
            }
            syncThread.start()
        case .manual:
            log.debug("BrightnessAdapter set to manual")
            builtinBrightnessMenuItem.isHidden = true
        }
    }

    func startValuesReaderThread() {
        valuesReaderThread = Thread {
            while true {
                if self.refreshValues {
                    brightnessAdapter.fetchValues()
                }

                if Thread.current.isCancelled { return }
                Thread.sleep(forTimeInterval: 10)
                if Thread.current.isCancelled { return }
            }
        }
        valuesReaderThread.qualityOfService = .background
        valuesReaderThread.start()
    }

    func initBrightnessAdapterActivity() {
        if refreshValues {
            startValuesReaderThread()
        }

        manageBrightnessAdapterActivity(mode: brightnessAdapter.mode)
    }

    func initMenubarIcon() {
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("MenubarIcon"))
            button.image?.isTemplate = true

            statusItemButtonController = StatusItemButtonController(button: button)
            statusButtonTrackingArea = NSTrackingArea(
                rect: button.visibleRect,
                options: [.mouseEnteredAndExited, .activeAlways],
                owner: statusItemButtonController,
                userInfo: nil
            )
            if let trackingArea = statusButtonTrackingArea {
                button.addTrackingArea(trackingArea)
            }
            button.addSubview(statusItemButtonController!)
        }
        statusItem.menu = menu
        toggleMenuItem.title = AppDelegate.getToggleMenuItemTitle()

        if menuPopover.contentViewController == nil {
            var storyboard: NSStoryboard?
            if #available(OSX 10.13, *) {
                storyboard = NSStoryboard.main
            } else {
                storyboard = NSStoryboard(name: "Main", bundle: nil)
            }

            menuPopover.contentViewController = storyboard!
                .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("MenuPopoverController")) as! MenuPopoverController
            menuPopover.contentViewController!.loadView()

            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(appleInterfaceThemeChangedNotification(notification:)),
                name: NSNotification.Name(rawValue: kAppleInterfaceThemeChangedNotification),
                object: nil
            )
            adaptAppearance()
        }
    }

    @objc func appleInterfaceThemeChangedNotification(notification _: Notification) {
        adaptAppearance()
    }

    func adaptAppearance() {
        runInMainThread { [weak menuPopover] in
            guard let menuPopover = menuPopover else { return }
            menuPopover.appearance = NSAppearance(named: .vibrantLight)
            if #available(OSX 10.15, *) {
                let appearanceDescription = NSApplication.shared.effectiveAppearance.debugDescription.lowercased()
                if appearanceDescription.contains("dark") {
                    menuPopover.appearance = NSAppearance(named: .vibrantDark)
                }

            } else if #available(OSX 10.14, *) {
                if let appleInterfaceStyle = UserDefaults.standard.object(forKey: kAppleInterfaceStyle) as? String {
                    if appleInterfaceStyle.lowercased().contains("dark") {
                        menuPopover.appearance = NSAppearance(named: .vibrantDark)
                    }
                }
            }
        }
    }

    func listenForScreenConfigurationChanged() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adaptToScreenConfiguration(notification:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc func adaptToScreenConfiguration(notification _: Notification) {
        menuPopover.close()
        brightnessAdapter.manageClamshellMode()
        brightnessAdapter.resetDisplayList()
        brightnessAdapter.builtinDisplay = DDC.getBuiltinDisplay()
        if let visible = windowController?.window?.isVisible, visible {
            windowController?.close()
            windowController?.window = nil
            windowController = nil
            showWindow()
        }
    }

    func addObservers() {
        sunsetObserver = Defaults.observe(.sunset) { _ in
            if brightnessAdapter.mode == .location {
                brightnessAdapter.adaptBrightness()
            }
        }
        sunriseObserver = Defaults.observe(.sunrise) { _ in
            if brightnessAdapter.mode == .location {
                brightnessAdapter.adaptBrightness()
            }
        }
        solarNoonObserver = Defaults.observe(.solarNoon) { _ in
            if brightnessAdapter.mode == .location {
                brightnessAdapter.adaptBrightness()
            }
        }
        curveFactorObserver = Defaults.observe(.curveFactor) { _ in
            if brightnessAdapter.mode == .location {
                brightnessAdapter.adaptBrightness()
            }
        }
        daylightObserver = Defaults.observe(.daylightExtensionMinutes) { _ in
            if brightnessAdapter.mode == .location {
                brightnessAdapter.adaptBrightness()
            }
        }
        noonObserver = Defaults.observe(.noonDurationMinutes) { _ in
            if brightnessAdapter.mode == .location {
                brightnessAdapter.adaptBrightness()
            }
        }
        brightnessOffsetObserver = Defaults.observe(.brightnessOffset) { _ in
            if brightnessAdapter.mode != .manual {
                brightnessAdapter.adaptBrightness()
            }
        }
        contrastOffsetObserver = Defaults.observe(.contrastOffset) { _ in
            if brightnessAdapter.mode != .manual {
                brightnessAdapter.adaptBrightness()
            }
        }

        syncPollingSecondsObserver = Defaults.observe(.syncPollingSeconds) { change in
            self.syncPollingSeconds = change.newValue
        }
        refreshValuesObserver = Defaults.observe(.refreshValues) { change in
            self.refreshValues = change.newValue

            self.valuesReaderThread?.cancel()
            if self.refreshValues {
                self.startValuesReaderThread()
            }
        }

        hotkeyObserver = Defaults.observe(.hotkeys) { _ in
            runInMainThread {
                self.setKeyEquivalents(Defaults[.hotkeys])
            }
        }
        mediaKeysEnabledObserver = Defaults.observe(.mediaKeysEnabled) { _ in
            self.startOrRestartMediaKeyTap()
        }
        volumeKeysEnabledObserver = Defaults.observe(.volumeKeysEnabled) { _ in
            self.startOrRestartMediaKeyTap()
        }
        hideMenuBarIconObserver = Defaults.observe(.hideMenuBarIcon) { change in
            log.info("Hiding menu bar icon: \(change.newValue)")
            self.statusItem.isVisible = !change.newValue
        }

        concurrentQueue.async {
            AMCoreAudio.NotificationCenter.defaultCenter.subscribe(
                AudioEventSubscriber(),
                eventType: AudioHardwareEvent.self,
                dispatchQueue: concurrentQueue
            )
        }
    }

    func setKeyEquivalents(_ hotkeys: [HotkeyIdentifier: [HotkeyPart: Int]]) {
        Hotkey.setKeyEquivalent(.lunar, menuItem: preferencesMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.toggle, menuItem: toggleMenuItem, hotkeys: hotkeys)

        Hotkey.setKeyEquivalent(.percent0, menuItem: percent0MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.percent25, menuItem: percent25MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.percent50, menuItem: percent50MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.percent75, menuItem: percent75MenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.percent100, menuItem: percent100MenuItem, hotkeys: hotkeys)

        Hotkey.setKeyEquivalent(.brightnessUp, menuItem: brightnessUpMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.brightnessDown, menuItem: brightnessDownMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.contrastUp, menuItem: contrastUpMenuItem, hotkeys: hotkeys)
        Hotkey.setKeyEquivalent(.contrastDown, menuItem: contrastDownMenuItem, hotkeys: hotkeys)

        menu?.update()
    }

    func acquirePrivileges() -> Bool {
        let accessEnabled = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )

        if accessEnabled != true {
            log.warning("You need to enable the event listener in the System Preferences")
        }
        return accessEnabled
    }

    func sendAnalytics() {
        guard let serialNumberHash = getSerialNumberHash(),
            let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        else {
            // log warning
            let serialNumberHash = getSerialNumberHash() ?? "no-serial-number"
            let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "no-version"

            log.warning("Can't send analytics", context: [
                serialNumberHash: serialNumberHash,
                appVersion: appVersion,
            ])

            return
        }

        let dataString =
            "id=\(serialNumberHash) version=\(appVersion) clamshell=\(IsLidClosed()) displays=\(brightnessAdapter.activeDisplays.count) mode=\(brightnessAdapter.mode) machine=\(Sysctl.model)"
        let data = dataString.data(using: .utf8, allowLossyConversion: true) ?? "no-data".data(using: .utf8)!
        log.info("Sending analytics", context: ["data": dataString])
        let req = AF.upload(data, to: ANALYTICS_URL)
            .authenticate(username: "lunar", password: secrets.analyticsHash)
            .validate()

        req.response(completionHandler: { resp in
            if let err = resp.error {
                log.error("Error sending analytics", context: ["error": err.errorDescription ?? ""])
            } else if let data = resp.data, let dataStr = String(data: data, encoding: .utf8) {
                log.debug("Analytics response", context: ["response": resp.debugDescription, "data": dataStr])
            } else {
                log.debug("Analytics response", context: ["response": resp.debugDescription])
            }
        })
    }

    func configureAlamofire() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 24.hours.timeInterval
        configuration.timeoutIntervalForResource = 7.days.timeInterval
        alamoFireManager = Session(configuration: configuration)
    }

    func applicationDidFinishLaunching(_: Notification) {
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        ValueTransformer.setValueTransformer(AppExceptionTransformer(), forName: .appExceptionTransformerName)
        ValueTransformer.setValueTransformer(DisplayTransformer(), forName: .displayTransformerName)

        log.initLogger()
        let release = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
        SentrySDK.start(options: [
            "dsn": secrets.sentryDSN,
            "enabled": true,
            "release": "v\(release)",
            "dist": release,
            "environment": "production",
        ])

        let user = User(userId: getSerialNumberHash() ?? "NOID")
        SentrySDK.configureScope { scope in
            scope.setUser(user)
            scope.setTag(value: brightnessAdapter.adaptiveModeString(), key: "adaptiveMode")
            scope.setTag(value: brightnessAdapter.adaptiveModeString(last: true), key: "lastAdaptiveMode")
        }

        brightnessAdapter.displays = BrightnessAdapter.getDisplays()
        brightnessAdapter.addSentryData()

        if let logPath = LOG_URL?.path.cString(using: .utf8) {
            log.info("Setting log path to \(LOG_URL?.path ?? "")")
            setLogPath(logPath, logPath.count)
        }

        handleDaemon()

        initBrightnessAdapterActivity()
        initMenubarIcon()
        initHotkeys()

        listenForAdaptiveModeChange()
        listenForScreenConfigurationChanged()
        brightnessAdapter.listenForRunningApps()
        brightnessAdapter.listenForBrightnessClipChange()

        addObservers()
        if thisIsFirstRun || TEST_MODE {
            showWindow()
        }

        configureAlamofire()
        // sendAnalytics()
        startReceivingSignificantLocationChanges()
        log.debug("App finished launching")
    }

    func applicationWillTerminate(_: Notification) {
        log.info("Going down")

        Defaults[.debug] = false

        locationThread?.cancel()
        syncThread?.cancel()
        valuesReaderThread?.cancel()
    }

    func geolocationFallback() {
        brightnessAdapter.fetchGeolocation()
    }

    internal func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            brightnessAdapter.geolocation = Geolocation(location: location)
            if brightnessAdapter.geolocation!.latitude != 0, brightnessAdapter.geolocation!.longitude != 0 {
                log.debug("Zero LocationManager coordinates")
            } else {
                log.debug("Got LocationManager coordinates")
            }
            brightnessAdapter.fetchMoments()
        } else {
            geolocationFallback()
        }
    }

    internal func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        log.error("Location manager failed with error: \(error)")
        geolocationFallback()
    }

    func locationManager(_ lm: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined, .authorizedAlways:
            lm.startUpdatingLocation()
        case .denied, .restricted:
            log.warning("User has not authorised location services")
            lm.stopUpdatingLocation()
            geolocationFallback()
        @unknown default:
            log.error("Unknown location manager status \(status)")
        }
    }

    func startReceivingSignificantLocationChanges() {
        if Defaults[.manualLocation] {
            brightnessAdapter.geolocation = Geolocation()
            return
        }
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager?.distanceFilter = 10000

        switch CLLocationManager.authorizationStatus() {
        case .notDetermined, .restricted, .denied:
            log.debug("Location not authorised")
        case .authorizedAlways:
            log.debug("Location authorised")
        @unknown default:
            log.debug("Location status unknown")
        }

        locationManager?.startUpdatingLocation()
    }

    static func getToggleMenuItemTitle() -> String {
        switch brightnessAdapter.mode {
        case .sensor:
            log.info("Sensor mode")
            return "Sensor mode"
        case .location:
            return "Adapt brightness based on built-in display"
        case .sync:
            return "Disable adaptive brightness"
        case .manual:
            return "Adapt brightness based on location"
        }
    }

    static func getStateMenuItemTitle() -> String {
        switch brightnessAdapter.mode {
        case .sensor:
            log.info("Sensor mode")
            return "Sensor Mode"
        case .location:
            return "☀️ Location Mode"
        case .sync:
            return "💻 Display Sync Mode"
        case .manual:
            return "🖥 Manual Mode"
        }
    }

    func resetElements() {
        toggleMenuItem.title = AppDelegate.getToggleMenuItemTitle()
        if let splitView = windowController?.window?.contentViewController as? SplitViewController {
            for button in splitView.buttons {
                button?.setNeedsDisplay()
            }
        }
    }

    func adapt() {
        brightnessAdapter.adaptBrightness()
    }

    func setLightPercent(percent: Int8) {
        brightnessAdapter.disable()
        brightnessAdapter.setBrightnessPercent(value: percent)
        brightnessAdapter.setContrastPercent(value: percent)
        log.debug("Setting brightness and contrast to \(percent)%")
    }

    func toggleAudioMuted() {
        brightnessAdapter.toggleAudioMuted(currentDisplay: true)
    }

    func increaseVolume(by amount: Int? = nil, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        let amount = amount ?? Defaults[.volumeStep]
        brightnessAdapter.adjustVolume(by: amount, for: displays, currentDisplay: currentDisplay)
    }

    func decreaseVolume(by amount: Int? = nil, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        let amount = amount ?? Defaults[.volumeStep]
        brightnessAdapter.adjustVolume(by: -amount, for: displays, currentDisplay: currentDisplay)
    }

    func increaseBrightness(by amount: Int? = nil, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        let amount = amount ?? Defaults[.brightnessStep]
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustBrightness(by: amount, for: displays, currentDisplay: currentDisplay)
        } else if brightnessAdapter.mode == .location {
            let newCurveFactor = cap(Defaults[.curveFactor] - Double(amount) * 0.1, minVal: 0.0, maxVal: 10.0)
            Defaults[.curveFactor] = newCurveFactor
        } else {
            let newBrightnessOffset = cap(Defaults[.brightnessOffset] + amount, minVal: -100, maxVal: 90)
            Defaults[.brightnessOffset] = newBrightnessOffset
        }
    }

    func increaseContrast(by amount: Int? = nil, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        let amount = amount ?? Defaults[.contrastStep]
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustContrast(by: amount, for: displays, currentDisplay: currentDisplay)
        } else if brightnessAdapter.mode == .location {
            let newCurveFactor = cap(Defaults[.curveFactor] - Double(amount) * 0.1, minVal: 0.0, maxVal: 10.0)
            Defaults[.curveFactor] = newCurveFactor
        } else {
            let newContrastOffset = cap(Defaults[.contrastOffset] + amount, minVal: -100, maxVal: 90)
            Defaults[.contrastOffset] = newContrastOffset
        }
    }

    func decreaseBrightness(by amount: Int? = nil, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        let amount = amount ?? Defaults[.brightnessStep]
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustBrightness(by: -amount, for: displays, currentDisplay: currentDisplay)
        } else if brightnessAdapter.mode == .location {
            let newCurveFactor = cap(Defaults[.curveFactor] + Double(amount) * 0.1, minVal: 0.0, maxVal: 10.0)
            Defaults[.curveFactor] = newCurveFactor
        } else {
            let newBrightnessOffset = cap(Defaults[.brightnessOffset] - amount, minVal: -100, maxVal: 90)
            Defaults[.brightnessOffset] = newBrightnessOffset
        }
    }

    func decreaseContrast(by amount: Int? = nil, for displays: [Display]? = nil, currentDisplay: Bool = false) {
        let amount = amount ?? Defaults[.contrastStep]
        if brightnessAdapter.mode == .manual {
            brightnessAdapter.adjustContrast(by: -amount, for: displays, currentDisplay: currentDisplay)
        } else if brightnessAdapter.mode == .location {
            let newCurveFactor = cap(Defaults[.curveFactor] + Double(amount) * 0.1, minVal: 0.0, maxVal: 10.0)
            Defaults[.curveFactor] = newCurveFactor
        } else {
            let newContrastOffset = cap(Defaults[.contrastOffset] - amount, minVal: -100, maxVal: 90)
            Defaults[.contrastOffset] = newContrastOffset
        }
    }

    @IBAction func setLight0Percent(sender _: Any?) {
        setLightPercent(percent: 0)
    }

    @IBAction func setLight25Percent(sender _: Any?) {
        setLightPercent(percent: 25)
    }

    @IBAction func setLight50Percent(sender _: Any?) {
        setLightPercent(percent: 50)
    }

    @IBAction func setLight75Percent(sender _: Any?) {
        setLightPercent(percent: 75)
    }

    @IBAction func setLight100Percent(sender _: Any?) {
        setLightPercent(percent: 100)
    }

    @IBAction func brightnessUp(_: Any) {
        increaseBrightness()
    }

    @IBAction func brightnessDown(_: Any) {
        decreaseBrightness()
    }

    @IBAction func contrastUp(_: Any) {
        increaseContrast()
    }

    @IBAction func contrastDown(_: Any) {
        decreaseContrast()
    }

    @IBAction func toggleBrightnessAdapter(sender _: Any?) {
        brightnessAdapter.toggle()
    }

    @IBAction func showPreferencesWindow(sender _: Any?) {
        showWindow()
    }

    @IBAction func buyMeACoffee(_: Any) {
        if let url = URL(string: "https://www.buymeacoffee.com/alin23") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func leaveFeedback(_: Any) {
        if let url = URL(string: "https://alinpanaitiu.com/contact/") {
            NSWorkspace.shared.open(url)
        }
    }

    func failDebugData() {
        runInMainThread {
            if dialog(message: "There's no debug data stored for Lunar", info: "Do you want to open a Github issue?") {
                guard let serialNumberHash = getSerialNumberHash(),
                    let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)?
                    .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
                    NSWorkspace.shared.open(
                        URL(
                            string:
                            "https://github.com/alin23/Lunar/issues/new?assignees=alin23&labels=diagnostics&template=lunar-diagnostics-report.md&title=Lunar+Diagnostics+Report+%5BNO+LOGS%5D"
                        )!
                    )
                    return
                }
                NSWorkspace.shared.open(
                    URL(
                        string:
                        "https://github.com/alin23/Lunar/issues/new?assignees=alin23&labels=diagnostics&template=lunar-diagnostics-report.md&title=Lunar+Diagnostics+Report+%5BNO+LOGS%5D+%5B\(serialNumberHash)%5D+%5B\(appVersion)%5D"
                    )!
                )
            }
        }
    }

    @IBAction func sendDebugData(_: Any) {
        guard dialog(
            message: "This will run a few diagnostic tests by trying to change the brightness and contrast of all of your external displays",
            info: "Do you want to continue?"
        ) else {
            return
        }

        let oldTitle = debugMenuItem.title
        menu.autoenablesItems = false
        debugMenuItem.isEnabled = false
        debugMenuItem.title = "Diagnosing displays"

        let oldDebugState = Defaults[.debug]
        let oldSmoothTransitionState = Defaults[.smoothTransition]
        Defaults[.debug] = true
        Defaults[.smoothTransition] = false

        setDebugMode(1)

        concurrentQueue.async(group: nil, qos: .userInitiated, flags: .barrier) {
            guard let serialNumberHash = getSerialNumberHash() else { return }

            let activeDisplays = brightnessAdapter.activeDisplays
            let oldBrightness = [CGDirectDisplayID: NSNumber](activeDisplays.map { ($0, $1.brightness) }, uniquingKeysWith: { first, _ in
                first
            })
            let oldContrast = [CGDirectDisplayID: NSNumber](activeDisplays.map { ($0, $1.contrast) }, uniquingKeysWith: { first, _ in
                first
            })

            brightnessAdapter.resetDisplayList()
            for (id, display) in brightnessAdapter.activeDisplays {
                for value in 1 ... 100 {
                    display.brightness = NSNumber(value: value)
                    display.contrast = NSNumber(value: value)
                }
                if let brightness = oldBrightness[id] {
                    for value in stride(from: 100, through: brightness.intValue, by: -1) {
                        display.brightness = NSNumber(value: value)
                    }
                }
                if let contrast = oldContrast[id] {
                    for value in stride(from: 100, through: contrast.intValue, by: -1) {
                        display.contrast = NSNumber(value: value)
                    }
                }
            }

            runInMainThread {
                Defaults[.debug] = oldDebugState
                Defaults[.smoothTransition] = oldSmoothTransitionState
            }

            setDebugMode(0)

            runInMainThread {
                self.debugMenuItem.title = "Gathering logs"
            }
            guard let logURL = LOG_URL, let sourceString = FileManager().contents(atPath: logURL.path) else {
                self.failDebugData()
                return
            }

            let data: Data
            let fileName: String
            if #available(OSX 10.13, *) {
                runInMainThread {
                    self.debugMenuItem.title = "Encrypting logs"
                }
                data = encrypt(message: sourceString) ?? sourceString
                fileName = "\(serialNumberHash).log.enc"
            } else {
                data = sourceString
                fileName = "\(serialNumberHash).log"
            }

            let req = AF.upload(data, to: LOG_UPLOAD_URL, headers: ["X-Filename": fileName])
                .authenticate(username: "lunar", password: secrets.analyticsHash)
                .validate(statusCode: 200 ..< 300)
            req.response(completionHandler: { [unowned self]
                response in
                defer {
                    self.menu.autoenablesItems = true
                    self.debugMenuItem.title = oldTitle
                    self.debugMenuItem.isEnabled = true
                }
                log.info("Got response from \(LOG_UPLOAD_URL)", context: response.response)
                if let err = response.error {
                    log.error("Debug data upload response error: \(err)")
                    self.failDebugData()
                    return
                }

                let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)?
                    .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "NOVERSION"
                if let url =
                    URL(
                        string: "https://github.com/alin23/Lunar/issues/new?assignees=alin23&labels=diagnostics&template=lunar-diagnostics-report.md&title=Lunar+Diagnostics+Report+%5B\(serialNumberHash)%5D+%5B\(appVersion)%5D"
                    ) {
                    NSWorkspace.shared.open(url)
                }
            })
        }
    }

    func dialog(message: String, info: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
