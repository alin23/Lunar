//
//  DisplayViewController.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Charts
import Cocoa
import Combine
import Defaults
import Magnet
import Sauce
import SwiftDate

class DisplayViewController: NSViewController {
    // MARK: Lifecycle

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif

        for observer in displayObservers.values {
            observer.cancel()
        }
    }

    // MARK: Internal

    enum ResetAction: Int {
        case algorithmCurve = 0
        case networkControl
        case ddcState
        case brightnessAndContrast
        case lunarSettings
        case fullReset
        case reset = 99
    }

    let LOCK_BRIGHTNESS_HELP_TEXT = """
    ## Description

    This setting allows the user to **restrict** changes on the brightness of this monitor.

    - `LOCKED` will **stop** the adaptive algorithm or the hotkeys from changing this monitor's brightness
    - `UNLOCKED` will **allow** this monitor's brightness to be adjusted by the adaptive algorithm or by hotkeys
    """
    let LOCK_CONTRAST_HELP_TEXT = """
    ## Description

    This setting allows the user to **restrict** changes on the contrast of this monitor.

    - `LOCKED` will **stop** the adaptive algorithm or the hotkeys from changing this monitor's contrast
    - `UNLOCKED` will **allow** this monitor's contrast to be adjusted by the adaptive algorithm or by hotkeys
    """

    let NATIVE_CONTROLS_HELP_TEXT = """
    ## CoreDisplay

    This monitor's brightness can be controlled natively through the **CoreDisplay framework**.

    ### Advantages
    * Lunar doesn't need to use less stable methods like *DDC* for the brightness
    * Brightness transitions are smoother

    ### Disadvantages
    * **Contrast/Volume still needs to be changed through DDC** as there is no API for them in CoreDisplay
    * Needs an additional USB connection for older Apple displays like LED Cinema
    """
    let HARDWARE_CONTROLS_HELP_TEXT = """
    ## DDC/CI

    This monitor's **hardware brightness** can be controlled through the **DDC protocol**.
    That is the same brightness that you can control with the physical buttons/controls on your monitor.

    ### Advantages
    * Support for changing brightness, contrast, volume and input
    * Colors are rendered more correctly than with a software overlay like *QuickShade*
    * Allows the monitor to consume less power on low brightness values

    ### Disadvantages
    * Not supported by TVs
    * Doesn't work on Mac Mini's HDMI port
    * Can wear out the monitor flash memory
    * Even though DDC is supported by all monitors, **a bad combination of cables/adapters/hubs/GPU can break it**
        - *Aim for using as little adapters as possible between your Mac device and your monitor*
    """
    let SOFTWARE_CONTROLS_HELP_TEXT = """
    ## Gamma tables

    This monitor's hardware brightness can't be controlled in any way.
    Lunar has to fallback to mimicking a brightness change through gamma table alteration.

    ### Advantages
    * It works on any monitor no matter what cable/adapter/connector you use

    ### Disadvantages
    * **Needs the hardware brightness/contrast to be set manually to high values like 100/70 first**
    * No support for changing volume or input
    * Low brightness values can wash out colors
    * Quitting Lunar resets the brightness to default
    * Contrast is approximated by adjusting the gamma factor and can look very bad on some monitors
    * **Airplay**, **iPad Sidecar** and **DisplayLink** monitors don't support Gamma so we have to use an overlay which looks even worse
        - An overlay is a black, always-on-top, semi-transparent window that adjusts its opacity based on the brightness set in Lunar
        - The overlay is not used on non-Airplay/Virtual monitors because Gamma is a better choice for accurate color rendering
    """
    let NO_CONTROLS_HELP_TEXT = """
    ## No controls available

    Looks like all available controls for this monitor have been disabled manually.

    Click on the ⚙️ icon near the `RESET` dropdown to enable a control.
    """
    let NETWORK_CONTROLS_HELP_TEXT = """
    ## Network control

    This monitor's hardware brightness can be controlled through another device accessible on the local network.

    That is the same brightness that you can control with the physical buttons/controls on your monitor.

    ### Advantages
    * Support for changing brightness, contrast, volume and input
    * Colors are rendered more correctly than with a software overlay like *QuickShade*
    * Allows the monitor to consume less power on low brightness values

    ### Disadvantages
    * Even though DDC is supported by all monitors, **a bad combination of cables/adapters/hubs/GPU can break it**
        - *Aim for using as little adapters as possible between your network device and your monitor*
    * Can wear out the monitor flash memory
    * Not supported by TVs
    """

    @IBOutlet var displayView: DisplayView?
    @IBOutlet var displayName: DisplayName?
    @IBOutlet var adaptiveNotice: NSTextField!
    @IBOutlet var gammaNotice: NSTextField!
    @IBOutlet var scrollableBrightness: ScrollableBrightness?
    @IBOutlet var scrollableContrast: ScrollableContrast?
    @IBOutlet var resetDropdown: PopUpButton?

    @IBOutlet var builtinBrightnessField: ScrollableTextField?
    @IBOutlet var builtinBrightnessCaption: ScrollableTextFieldCaption?
    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView?

    @IBOutlet var _controlsButton: NSButton!
    @IBOutlet var _proButton: NSButton!
    @IBOutlet var _lockContrastHelpButton: NSButton?
    @IBOutlet var _lockBrightnessHelpButton: NSButton?
    @IBOutlet var _settingsButton: NSButton?
    @IBOutlet var lockContrastCurveButton: LockButton!
    @IBOutlet var lockBrightnessCurveButton: LockButton!

    @objc dynamic var noDisplay: Bool = false
    @objc dynamic lazy var inputHidden: Bool = display == nil || noDisplay || display!.isBuiltin || !display!.activeAndResponsive
    @objc dynamic lazy var chartHidden: Bool = display == nil || noDisplay || display!.isBuiltin || displayController
        .adaptiveModeKey == .clock

    var graphObserver: Cancellable?
    var adaptiveModeObserver: Cancellable?
    var sendingBrightnessObserver: ((Bool, Bool) -> Void)?
    var sendingContrastObserver: ((Bool, Bool) -> Void)?
    var activeAndResponsiveObserver: ((Bool, Bool) -> Void)?
    var adaptiveObserver: ((Bool, Bool) -> Void)?
    var viewID: String?
    var displayObservers = [String: AnyCancellable]()

    var pausedAdaptiveModeObserver: Bool = false

    @AtomicLock var gammaHighlighterTask: CFRunLoopTimer?

    @AtomicLock var adaptiveHighlighterTask: CFRunLoopTimer?

    @IBOutlet var inputDropdown: PopUpButton?

    @objc dynamic lazy var powerOffEnabled = getPowerOffEnabled()
    @objc dynamic lazy var powerOffTooltip = getPowerOffTooltip()

    @Atomic var optionKeyPressed = false

    @IBOutlet var scheduleBox: NSBox!
    @IBOutlet var schedule1: Schedule!
    @IBOutlet var schedule2: Schedule!
    @IBOutlet var schedule3: Schedule!
    @IBOutlet var schedule4: Schedule!
    @IBOutlet var schedule5: Schedule!

    @objc dynamic var nonResponsiveTextFieldHidden: Bool = true

    @IBOutlet var _inputDropdownHotkeyButton: NSButton? {
        didSet {
            mainThread {
                initHotkeys()
            }
        }
    }

    var inputDropdownHotkeyButton: HotkeyButton? {
        _inputDropdownHotkeyButton as? HotkeyButton
    }

    var controlsButton: HelpButton? {
        _controlsButton as? HelpButton
    }

    var proButton: Button? {
        _proButton as? Button
    }

    @IBOutlet var nonResponsiveTextField: NonResponsiveTextField? {
        didSet {
            mainThread {
                nonResponsiveTextField?.isHidden = getNonResponsiveTextFieldHidden()
            }
        }
    }

    var lockContrastHelpButton: HelpButton? {
        _lockContrastHelpButton as? HelpButton
    }

    var lockBrightnessHelpButton: HelpButton? {
        _lockBrightnessHelpButton as? HelpButton
    }

    var settingsButton: SettingsButton? {
        _settingsButton as? SettingsButton
    }

    @objc dynamic weak var display: Display? {
        didSet {
            if let display = display {
                mainThread { update(display) }
                noDisplay = display.id == GENERIC_DISPLAY_ID
            }
        }
    }

    @objc dynamic var lockedBrightnessCurve: Bool = false {
        didSet {
            display?.lockedBrightnessCurve = lockedBrightnessCurve
            lockBrightnessCurveButton?.state = lockedBrightnessCurve.state
        }
    }

    @objc dynamic var lockedContrastCurve: Bool = false {
        didSet {
            display?.lockedContrastCurve = lockedContrastCurve
            lockContrastCurveButton?.state = lockedContrastCurve.state
        }
    }

    func getNonResponsiveTextFieldHidden() -> Bool {
        guard let display = display, display.active else { return true }
        return display.id == GENERIC_DISPLAY_ID || display.isBuiltin || display.activeAndResponsive
    }

    @IBAction func lockCurve(_ sender: LockButton) {
        switch sender.tag {
        case 1:
            lockedContrastCurve = sender.state == .on
        case 2:
            lockedBrightnessCurve = sender.state == .on
        default:
            break
        }
    }

    override func mouseDown(with ev: NSEvent) {
        if let editor = displayName?.currentEditor() {
            editor.selectedRange = NSMakeRange(0, 0)
            displayName?.abortEditing()
        }
        super.mouseDown(with: ev)
    }

    func setButtonsHidden(_ hidden: Bool) {
        mainThread {
            resetDropdown?.isHidden = hidden
            inputDropdown?.isHidden = hidden
            inputDropdownHotkeyButton?.isHidden = hidden
        }
    }

    func refreshView() {
        mainThread {
            view.setNeedsDisplay(view.visibleRect)
        }
    }

    @discardableResult
    func initHotkeys() -> Bool {
        guard let button = inputDropdownHotkeyButton, let display = display, !display.isBuiltin, display.hotkeyPopoverController != nil
        else {
            if let button = inputDropdownHotkeyButton {
                button.onClick = { [weak self] in
                    guard let self = self else { return }
                    if self.initHotkeys() {
                        button.onClick = nil
                    }
                }
            }
            return false
        }

        button.setup(from: display)
        return true
    }

    @objc func adaptToDataPointBounds(notification _: Notification) {
        guard let display = display, brightnessContrastChart != nil, display.id != GENERIC_DISPLAY_ID else { return }
        initGraph()
    }

    @objc func highlightChartValue(notification _: Notification) {
        guard CachedDefaults[.moreGraphData], let display = display, let brightnessContrastChart = brightnessContrastChart,
              display.id != GENERIC_DISPLAY_ID else { return }
        brightnessContrastChart.highlightCurrentValues(adaptiveMode: displayController.adaptiveMode, for: display)
    }

    @objc func adaptToUserDataPoint(notification: Notification) {
        guard displayController.adaptiveModeKey != .manual, displayController.adaptiveModeKey != .clock,
              let values = notification.userInfo?["values"] as? [Int: Int]
        else { return }

        if notification.name == brightnessDataPointInserted {
            updateDataset(userBrightness: values)
        } else if notification.name == contrastDataPointInserted {
            updateDataset(userContrast: values)
        }
    }

    func updateNotificationObservers(for display: Display) {
        NotificationCenter.default.removeObserver(
            self,
            name: brightnessDataPointInserted,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: contrastDataPointInserted,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: currentDataPointChanged,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: dataPointBoundsChanged,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: lunarProStateChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adaptToUserDataPoint(notification:)),
            name: brightnessDataPointInserted,
            object: display
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adaptToUserDataPoint(notification:)),
            name: contrastDataPointInserted,
            object: display
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(highlightChartValue(notification:)),
            name: currentDataPointChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adaptToDataPointBounds(notification:)),
            name: dataPointBoundsChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateProIndicator(notification:)),
            name: lunarProStateChanged,
            object: nil
        )
    }

    @IBAction func proButtonClick(_: Any) {
        if lunarProActive, !lunarProOnTrial {
            NSWorkspace.shared.open(try! "https://lunar.fyi/#pro".asURL())
        } else if lunarProBadSignature {
            NSWorkspace.shared.open(try! "https://lunar.fyi/download/latest".asURL())
        } else if let paddle = paddle, let lunarProProduct = lunarProProduct {
            if lunarProProduct.licenseCode != nil {
                deactivateLicense {
                    paddle.showProductAccessDialog(with: lunarProProduct)
                }
            } else {
                paddle.showProductAccessDialog(with: lunarProProduct)
            }
        }
    }

    func setupProButton() {
        guard let button = proButton else { return }

        mainThread {
            let width = button.frame.width
            if lunarProActive {
                button.bg = red
                button.attributedTitle = "Pro".withAttribute(.textColor(white))
                button.setFrameSize(NSSize(width: 50, height: button.frame.height))
            } else if lunarProBadSignature {
                button.bg = errorRed
                button.attributedTitle = "Invalid App Signature".withAttribute(.textColor(.black.withAlphaComponent(0.8)))
                button.setFrameSize(NSSize(width: 150, height: button.frame.height))
            } else {
                button.bg = green
                button.attributedTitle = "Get Pro".withAttribute(.textColor(white))
                button.setFrameSize(NSSize(width: 70, height: button.frame.height))
            }
            if button.frame.width != width {
                button.center(within: view, vertically: false)
            }
        }
    }

    @objc func updateProIndicator(notification _: Notification) {
        setupProButton()
    }

    func update(_ display: Display? = nil) {
        guard let display = display ?? self.display else { return }

        powerOffEnabled = getPowerOffEnabled()
        powerOffTooltip = getPowerOffTooltip()
        inputHidden = noDisplay || display.isBuiltin || !display.activeAndResponsive
        chartHidden = noDisplay || display.isBuiltin || displayController.adaptiveModeKey == .clock

        settingsButton?.display = display
        settingsButton?.displayViewController = self
        scrollableBrightness?.display = display
        scrollableContrast?.display = display

        updateControlsButton()
        updateNotificationObservers(for: display)

        lockedBrightnessCurve = display.lockedBrightnessCurve
        lockedContrastCurve = display.lockedContrastCurve

        schedule1?.display = display
        schedule2?.display = display
        schedule3?.display = display
        schedule4?.display = display
        schedule5?.display = display
        scheduleBox?.isHidden = displayController.adaptiveModeKey != .clock

        if display.isBuiltin {
            builtinBrightnessField?.onValueChanged = { value in
                display
                    .withBrightnessTransition(brightnessTransition == .instant ? .smooth : brightnessTransition) {
                        display.brightness = value.ns
                    }
            }
        }

        scrollableBrightness?.onCurrentValueChanged = { [weak self] brightness in
            guard let self = self, let display = self.display,
                  displayController.adaptiveModeKey != .manual, displayController.adaptiveModeKey != .clock,
                  !display.lockedBrightnessCurve
            else {
                self?.updateDataset(currentBrightness: brightness.u8)
                return
            }
            cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)

            let lastDataPoint = datapointLock.around { displayController.adaptiveMode.brightnessDataPoint.last }
            display.insertBrightnessUserDataPoint(lastDataPoint, brightness, modeKey: displayController.adaptiveModeKey)

            let userValues = display.userBrightness[displayController.adaptiveModeKey] ?? ThreadSafeDictionary()
            self.updateDataset(currentBrightness: brightness.u8, userBrightness: userValues.dictionary)
        }
        scrollableContrast?.onCurrentValueChanged = { [weak self] contrast in
            guard let self = self, let display = self.display,
                  displayController.adaptiveModeKey != .manual, displayController.adaptiveModeKey != .clock,
                  !display.lockedContrastCurve
            else {
                self?.updateDataset(currentContrast: contrast.u8)
                return
            }

            let lastDataPoint = displayController.adaptiveMode.contrastDataPoint.last
            display.insertContrastUserDataPoint(lastDataPoint, contrast, modeKey: displayController.adaptiveModeKey)

            let userValues = display.userContrast[displayController.adaptiveModeKey] ?? ThreadSafeDictionary()
            self.updateDataset(currentContrast: contrast.u8, userContrast: userValues.dictionary)
        }

        display.onControlChange = { [weak self] control in
            mainThread {
                self?.updateControlsButton(control: control)
                if control is GammaControl, display.enabledControls[.gamma] ?? false {
                    self?.showGammaNotice()
                } else {
                    self?.hideGammaNotice()
                }
            }
        }

        if display.id == GENERIC_DISPLAY_ID {
            displayName?.stringValue = "No Display"
            displayName?.display = nil
        } else {
            displayName?.stringValue = display.name
            displayName?.display = self.display
            nonResponsiveTextField?.onClick = { [weak self] in
                mainThread { [weak self] in
                    guard let self = self, let display = self.display else { return }
                    display.control?.resetState()
                    self.setButtonsHidden(display.id == GENERIC_DISPLAY_ID || display.isBuiltin)
                    self.refreshView()
                }
            }
        }

        display.$input.sink { [weak self] _ in
            mainAsyncAfter(ms: 1000) {
                guard let self = self else { return }
                if !self.inputHidden { self.inputDropdown?.fade() }
            }
        }.store(in: &displayObservers, for: "input")

        initHotkeys()
        setButtonsHidden(display.id == GENERIC_DISPLAY_ID || display.isBuiltin)
        refreshView()

        listenForSendingBrightnessContrast()
        listenForGraphDataChange()
        listenForAdaptiveModeChange()
        listenForDisplayBoolChange()
        listenForBrightnessContrastChange()
        updateControlsButton()
        setupProButton()
    }

    func setDisconnected() {
        guard let button = controlsButton else { return }
        button.bg = darkMode ? gray.withAlphaComponent(0.6) : gray.withAlphaComponent(0.9)
        button.attributedTitle = "Disconnected".withAttribute(.textColor(.darkGray))
        button.helpText = "This display is not connected to your Mac."
    }

    func updateControlsButton(control: Control? = nil) {
        guard let button = controlsButton, let display = display else {
            return
        }

        guard display.active else {
            setDisconnected()
            return
        }

        guard let control = control ?? display.control else {
            return
        }

        mainThread {
            button.alpha = 1.0
            button.hoverAlpha = 0.9
            button.circle = false

            switch control {
            case is CoreDisplayControl:
                button.bg = green
                button.attributedTitle = "Native Controls".withAttribute(.textColor(mauve))
                button.helpText = NATIVE_CONTROLS_HELP_TEXT
            case is DDCControl:
                button.bg = darkMode ? peach : lunarYellow
                button.attributedTitle = "Hardware Controls".withAttribute(.textColor(darkMauve))
                button.helpText = HARDWARE_CONTROLS_HELP_TEXT
            case is GammaControl where display.enabledControls[.gamma] ?? false:
                button.bg = darkMode ? peach.blended(withFraction: 0.5, of: red) : red.withAlphaComponent(0.9)
                button.attributedTitle = "Software Controls".withAttribute(.textColor(.black))
                button.helpText = SOFTWARE_CONTROLS_HELP_TEXT
            case is NetworkControl:
                button.bg = darkMode ? blue.highlight(withLevel: 0.2) : blue.withAlphaComponent(0.9)
                button.attributedTitle = "Network Controls".withAttribute(.textColor(.black))
                button.helpText = NETWORK_CONTROLS_HELP_TEXT
            default:
                button.bg = darkMode ? gray.withAlphaComponent(0.6) : gray.withAlphaComponent(0.9)
                button.attributedTitle = "No Controls".withAttribute(.textColor(.darkGray))
                button.helpText = NO_CONTROLS_HELP_TEXT
            }
        }
    }

    func updateDataset(
        minBrightness: UInt8? = nil,
        maxBrightness: UInt8? = nil,
        minContrast: UInt8? = nil,
        maxContrast: UInt8? = nil,
        currentBrightness: UInt8? = nil,
        currentContrast: UInt8? = nil,
        brightnessFactor: Double? = nil,
        contrastFactor: Double? = nil,
        userBrightness: [Int: Int]? = nil,
        userContrast: [Int: Int]? = nil,
        force: Bool = false
    ) {
        guard let display = display, let brightnessContrastChart = brightnessContrastChart, display.id != GENERIC_DISPLAY_ID
        else { return }

        let brightnessChartEntry = brightnessContrastChart.brightnessGraph.entries
        let contrastChartEntry = brightnessContrastChart.contrastGraph.entries

        switch displayController.adaptiveMode {
        case let mode as LocationMode:
            let points = mode.getBrightnessContrastBatch(
                display: display, brightnessFactor: brightnessFactor, contrastFactor: contrastFactor,
                minBrightness: minBrightness, maxBrightness: maxBrightness,
                minContrast: minContrast, maxContrast: maxContrast,
                userBrightness: userBrightness, userContrast: userContrast
            )
            let maxValues = min(
                mode.maxChartDataPoints,
                points.brightness.count,
                points.contrast.count,
                brightnessChartEntry.count,
                contrastChartEntry.count
            )
            let xs = stride(from: 0, to: maxValues, by: 1)
            for (x, y) in zip(xs, points.brightness.striding(by: 9)) {
                brightnessChartEntry[x].y = y
            }
            for (x, y) in zip(xs, points.contrast.striding(by: 9)) {
                contrastChartEntry[x].y = y
            }
        case let mode as SyncMode:
            let maxValues = min(mode.maxChartDataPoints, brightnessChartEntry.count, contrastChartEntry.count)
            let xs = stride(from: 0, to: maxValues, by: 1)

            if force || minBrightness != nil || maxBrightness != nil || userBrightness != nil || brightnessFactor != nil {
                let values = mode.interpolateSIMD(
                    .brightness(0),
                    display: display,
                    minVal: minBrightness?.d,
                    maxVal: maxBrightness?.d,
                    factor: brightnessFactor,
                    userValues: userBrightness
                )
                for (x, b) in zip(xs, values.striding(by: 6)) {
                    brightnessChartEntry[x].y = b
                }
            }
            if force || minContrast != nil || maxContrast != nil || userContrast != nil || contrastFactor != nil {
                let values = mode.interpolateSIMD(
                    .contrast(0),
                    display: display,
                    minVal: minContrast?.d,
                    maxVal: maxContrast?.d,
                    factor: contrastFactor,
                    userValues: userContrast
                )
                for (x, b) in zip(xs, values.striding(by: 6)) {
                    contrastChartEntry[x].y = b
                }
            }
        case let mode as SensorMode:
            let maxValues = min(mode.maxChartDataPoints, brightnessChartEntry.count, contrastChartEntry.count)
            let xs = stride(from: 0, to: maxValues, by: 1)

            if force || minBrightness != nil || maxBrightness != nil || userBrightness != nil || brightnessFactor != nil {
                let values = mode.interpolateSIMD(
                    .brightness(0),
                    display: display,
                    minVal: minBrightness?.d,
                    maxVal: maxBrightness?.d,
                    factor: brightnessFactor,
                    userValues: userBrightness
                )
                for (x, b) in zip(xs, values.striding(by: 30)) {
                    brightnessChartEntry[x].y = b
                }
            }
            if force || minContrast != nil || maxContrast != nil || userContrast != nil || contrastFactor != nil {
                let values = mode.interpolateSIMD(
                    .contrast(0),
                    display: display,
                    minVal: minContrast?.d,
                    maxVal: maxContrast?.d,
                    factor: contrastFactor,
                    userValues: userContrast
                )
                for (x, b) in zip(xs, values.striding(by: 30)) {
                    contrastChartEntry[x].y = b
                }
            }
        case let mode as ManualMode:
            let maxValues = min(mode.maxChartDataPoints, brightnessChartEntry.count, contrastChartEntry.count)
            let xs = stride(from: 0, to: maxValues, by: 1)
            let percents = Array(stride(from: 0.0, to: maxValues.d / 100.0, by: 0.01))
            for (x, b) in zip(
                xs,
                mode.computeSIMD(
                    from: percents,
                    minVal: minBrightness?.d ?? display.minBrightness.doubleValue,
                    maxVal: maxBrightness?.d ?? display.maxBrightness.doubleValue
                )
            ) {
                brightnessChartEntry[x].y = b
            }
            for (x, b) in zip(
                xs,
                mode.computeSIMD(
                    from: percents,
                    minVal: minContrast?.d ?? display.minContrast.doubleValue,
                    maxVal: maxContrast?.d ?? display.maxContrast.doubleValue
                )
            ) {
                contrastChartEntry[x].y = b
            }
        default:
            break
        }

        brightnessContrastChart.highlightCurrentValues(
            adaptiveMode: displayController.adaptiveMode, for: display,
            brightness: currentBrightness?.d, contrast: currentContrast?.d
        )
        mainThread {
            brightnessContrastChart.notifyDataSetChanged()
        }
    }

    func resetControl() {
        guard let display = display else { return }
        let control = display.getBestControl()
        display.control = control
        display.onControlChange?(control)

        if !(display.enabledControls[.gamma] ?? false),
           display.applyGamma || display.gammaChanged || display.isVirtual || display.isAirPlay
        {
            display.resetSoftwareControl()
        }
    }

    func resetDDC() {
        let key = "resetDDCTask"
        let subscriberKey = "\(key)-\(view.accessibilityIdentifier())"
        debounce(ms: 10, uniqueTaskKey: key, subscriberKey: subscriberKey) { [weak self] in
            guard let self = self, let display = self.display else {
                cancelTask(key, subscriberKey: subscriberKey)
                return
            }
            if display.control is DDCControl {
                display.control?.resetState()
            } else {
                DDCControl(display: display).resetState()
            }

            self.resetControl()

            asyncEvery(2.seconds, uniqueTaskKey: SCREEN_WAKE_ADAPTER_TASK_KEY, runs: 5, skipIfExists: true) { _ in
                displayController.adaptBrightness(force: true)
            }
        }
    }

    func resetNetworkController() {
        let key = "resetNetworkControlTask"
        let subscriberKey = "\(key)-\(view.accessibilityIdentifier())"
        debounce(ms: 10, uniqueTaskKey: key, subscriberKey: subscriberKey) { [weak self] in
            guard let self = self, let display = self.display else {
                cancelTask(key, subscriberKey: subscriberKey)
                return
            }
            if display.control is NetworkControl {
                display.control?.resetState()
            } else {
                NetworkControl.resetState(serial: display.serial)
            }

            self.resetControl()

            asyncEvery(2.seconds, uniqueTaskKey: SCREEN_WAKE_ADAPTER_TASK_KEY, runs: 5, skipIfExists: true) { _ in
                displayController.adaptBrightness(force: true)
            }
        }
    }

    @IBAction func reset(_ sender: NSPopUpButton) {
        guard let display = display, let action = ResetAction(rawValue: sender.selectedTag()) else { return }
        switch action {
        case .algorithmCurve:
            display.adaptivePaused = true
            defer {
                display.adaptivePaused = false
                display.readapt(newValue: false, oldValue: true)
            }

            display.userContrast[displayController.adaptiveModeKey]?.removeAll()
            display.userBrightness[displayController.adaptiveModeKey]?.removeAll()
            display.save()
            updateDataset(force: true)
        case .networkControl:
            resetNetworkController()
        case .ddcState:
            resetDDC()
        case .brightnessAndContrast:
            display.adaptive = false
            _ = display.control?.reset()
        case .lunarSettings:
            resetDisplay(askBefore: false, resetControl: false)
        case .fullReset:
            resetDisplay()
        default:
            break
        }
        sender.selectItem(withTag: ResetAction.reset.rawValue)
    }

    func resetDisplay(askBefore: Bool = true, resetControl: Bool = true) {
        guard let display = display else { return }

        let resetHandler = { [weak self] (shouldReset: Bool) in
            guard shouldReset, let display = self?.display, let self = self else { return }
            display.adaptivePaused = true
            defer {
                display.adaptivePaused = false
                display.readapt(newValue: false, oldValue: true)
            }

            display.reset(resetControl: resetControl)
            self.settingsButton?.popoverController?.display = display
            self.updateDataset(force: true)
        }

        guard askBefore else {
            resetHandler(true)
            return
        }

        if display.control is GammaControl {
            guard ask(message: "Monitor Reset", info: """
            This will reset the following settings for this display:
            • The algorithm curve that Lunar learned from your adjustments
            • The enabled controls
            • The "Always Use Network Control" setting
            • The "Always Fallback to Gamma" setting
            • The min/max brightness/contrast values
            """, okButton: "Ok", cancelButton: "Cancel", window: view.window, onCompletion: resetHandler, wide: true)
            else { return }
        } else {
            guard ask(message: "Monitor Reset", info: """
            This will reset the following settings for this display:
            • Everything you have manually adjusted using the monitor's physical buttons/controls
            • The algorithm curve that Lunar learned from your adjustments
            • The enabled controls
            • The "Always Use Network Control" setting
            • The "Always Fallback to Gamma" setting
            • The min/max brightness/contrast values
            """, okButton: "Ok", cancelButton: "Cancel", window: view.window, onCompletion: resetHandler, wide: true)
            else { return }
        }
        if view.window == nil {
            resetHandler(true)
        }
    }

    func listenForSendingBrightnessContrast() {
        display?.$sendingBrightness.receive(on: dataPublisherQueue).sink { [weak self] newValue in
            guard newValue else {
                self?.scrollableBrightness?.currentValue.stopHighlighting()
                return
            }

            if let control = self?.display?.control as? NetworkControl {
                if control.isResponsive() {
                    self?.scrollableBrightness?.currentValue.highlight(message: "Sending")
                } else {
                    self?.scrollableBrightness?.currentValue.highlight(message: "Not responding")
                }
            }
        }.store(in: &displayObservers, for: "sendingBrightness")
        display?.$sendingContrast.receive(on: dataPublisherQueue).sink { [weak self] newValue in
            guard newValue else {
                self?.scrollableContrast?.currentValue.stopHighlighting()
                return
            }
            if let control = self?.display?.control as? NetworkControl {
                if control.isResponsive() {
                    self?.scrollableContrast?.currentValue.highlight(message: "Sending")
                } else {
                    self?.scrollableContrast?.currentValue.highlight(message: "Not responding")
                }
            }
        }.store(in: &displayObservers, for: "sendingContrast")
    }

    func listenForBrightnessContrastChange() {
        display?.$maxBrightness.receive(on: dataPublisherQueue).sink { [weak self] value in
            guard let self = self else { return }
            mainThread {
                self.scrollableBrightness?.maxValue.integerValue = value.intValue
                self.scrollableBrightness?.minValue.upperLimit = value.doubleValue - 1

                self.schedule1?.brightness.upperLimit = value.doubleValue
                self.schedule2?.brightness.upperLimit = value.doubleValue
                self.schedule3?.brightness.upperLimit = value.doubleValue
                self.schedule4?.brightness.upperLimit = value.doubleValue
                self.schedule5?.brightness.upperLimit = value.doubleValue
            }
        }.store(in: &displayObservers, for: "maxBrightness")
        display?.$maxContrast.receive(on: dataPublisherQueue).sink { [weak self] value in
            guard let self = self else { return }
            mainThread {
                self.scrollableContrast?.maxValue.integerValue = value.intValue
                self.scrollableContrast?.minValue.upperLimit = value.doubleValue - 1

                self.schedule1?.contrast.upperLimit = value.doubleValue
                self.schedule2?.contrast.upperLimit = value.doubleValue
                self.schedule3?.contrast.upperLimit = value.doubleValue
                self.schedule4?.contrast.upperLimit = value.doubleValue
                self.schedule5?.contrast.upperLimit = value.doubleValue
            }
        }.store(in: &displayObservers, for: "maxContrast")

        display?.$minBrightness.receive(on: dataPublisherQueue).sink { [weak self] value in
            guard let self = self else { return }
            mainThread {
                self.scrollableBrightness?.minValue.integerValue = value.intValue
                self.scrollableBrightness?.maxValue.lowerLimit = value.doubleValue + 1

                self.schedule1?.brightness.lowerLimit = value.doubleValue
                self.schedule2?.brightness.lowerLimit = value.doubleValue
                self.schedule3?.brightness.lowerLimit = value.doubleValue
                self.schedule4?.brightness.lowerLimit = value.doubleValue
                self.schedule5?.brightness.lowerLimit = value.doubleValue
            }
        }.store(in: &displayObservers, for: "minBrightness")
        display?.$minContrast.receive(on: dataPublisherQueue).sink { [weak self] value in
            guard let self = self else { return }
            mainThread {
                self.scrollableContrast?.minValue.integerValue = value.intValue
                self.scrollableContrast?.maxValue.lowerLimit = value.doubleValue + 1

                self.schedule1?.contrast.lowerLimit = value.doubleValue
                self.schedule2?.contrast.lowerLimit = value.doubleValue
                self.schedule3?.contrast.lowerLimit = value.doubleValue
                self.schedule4?.contrast.lowerLimit = value.doubleValue
                self.schedule5?.contrast.lowerLimit = value.doubleValue
            }
        }.store(in: &displayObservers, for: "minContrast")

        display?.$brightness.receive(on: dataPublisherQueue).sink { [weak self] value in
            guard let self = self else { return }
            mainThread {
                self.scrollableBrightness?.currentValue.integerValue = value.intValue
                self.builtinBrightnessField?.integerValue = value.intValue
            }
        }.store(in: &displayObservers, for: "brightness")
        display?.$contrast.receive(on: dataPublisherQueue).sink { [weak self] value in
            guard let self = self else { return }
            mainThread {
                self.scrollableContrast?.currentValue.integerValue = value.intValue
            }
        }.store(in: &displayObservers, for: "contrast")
    }

    func listenForDisplayBoolChange() {
        guard let display = display else { return }
        display.$hasDDC.receive(on: dataPublisherQueue).sink { [weak self] hasDDC in
            guard let self = self else { return }
            self.powerOffEnabled = self.getPowerOffEnabled(hasDDC: hasDDC)
            self.powerOffTooltip = self.getPowerOffTooltip(hasDDC: hasDDC)
        }.store(in: &displayObservers, for: "hasDDC")
        display.$activeAndResponsive.receive(on: dataPublisherQueue).sink { [weak self] newActiveAndResponsive in
            if let self = self, let display = self.display, let textField = self.nonResponsiveTextField {
                self.setButtonsHidden(display.id == GENERIC_DISPLAY_ID || !newActiveAndResponsive)

                mainThread { textField.isHidden = newActiveAndResponsive }
            }
        }.store(in: &displayObservers, for: "activeAndResponsive")
        if !display.adaptive {
            showAdaptiveNotice()
        }
        display.$adaptive.receive(on: dataPublisherQueue).sink { [weak self] newAdaptive in
            if let self = self {
                mainThread {
                    if !newAdaptive {
                        self.showAdaptiveNotice()
                    } else {
                        self.hideAdaptiveNotice()
                    }
                }
            }
        }.store(in: &displayObservers, for: "adaptive")
    }

    func listenForGraphDataChange() {
        graphObserver = moreGraphDataPublisher.sink { [weak self] change in
            log.debug("More graph data: \(change.newValue)")
            guard let self = self else { return }
            mainAsyncAfter(ms: 1000) {
                self.initGraph()
            }
        }
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = adaptiveBrightnessModePublisher.sink { [weak self] change in
            guard let self = self, !self.pausedAdaptiveModeObserver else {
                return
            }

            self.pausedAdaptiveModeObserver = true
            mainThread {
                self.chartHidden = self.display == nil || self.noDisplay || self.display!.isBuiltin || change.newValue == .clock
                self.scheduleBox?.isHidden = change.newValue != .clock
            }
            Defaults.withoutPropagation {
                let adaptiveMode = change.newValue
                mainThread {
                    if self.brightnessContrastChart != nil {
                        self.initGraph(mode: adaptiveMode.mode)
                    }
                }
                self.pausedAdaptiveModeObserver = false
            }
        }
    }

    func initGraph(mode: AdaptiveMode? = nil) {
        guard !chartHidden else {
            zeroGraph()
            return
        }
        brightnessContrastChart?.initGraph(
            display: display,
            brightnessColor: brightnessGraphColor,
            contrastColor: contrastGraphColor,
            labelColor: xAxisLabelColor,
            mode: mode
        )
        brightnessContrastChart?.rightAxis.gridColor = mauve.withAlphaComponent(0.1)
        brightnessContrastChart?.xAxis.gridColor = mauve.withAlphaComponent(0.1)
    }

    func zeroGraph() {
        brightnessContrastChart?.initGraph(
            display: nil,
            brightnessColor: brightnessGraphColor,
            contrastColor: contrastGraphColor,
            labelColor: xAxisLabelColor
        )
        brightnessContrastChart?.rightAxis.gridColor = mauve.withAlphaComponent(0.0)
        brightnessContrastChart?.xAxis.gridColor = mauve.withAlphaComponent(0.0)
    }

    func getPowerOffEnabled(hasDDC: Bool? = nil) -> Bool {
        guard let display = display, display.active else { return false }
        guard !display.isInMirrorSet else { return true }

        return (displayController.activeDisplays.count > 1 || (hasDDC ?? display.hasDDC)) && !display.isSidecar && !display.isAirplay
    }

    func getPowerOffTooltip(hasDDC: Bool? = nil) -> String? {
        guard let display = display else { return nil }
        guard !(hasDDC ?? display.hasDDC) else {
            return """
            BlackOut simulates a monitor power off by mirroring the contents of the other visible screen to this one and setting this monitor's brightness to absolute 0.

            Can also be toggled with the keyboard using Ctrl-Cmd-6.

            Hold the Option key while clicking the button if you want to power off the monitor completely using DDC.
            Caveats:
              • works only if the monitor can be controlled through DDC
              • can't be used to power on the monitor
              • when a monitor is turned off or in standby, it does not accept commands from a connected device
              • remember to keep holding the Option key for 2 seconds after you pressed the button to account for possible DDC delays
            """
        }
        guard displayController.activeDisplays.count > 1 else {
            return "At least 2 screens need to be visible for this to work."
        }

        return """
        BlackOut simulates a monitor power off by mirroring the contents of the other visible screen to this one and setting this monitor's brightness to absolute 0.

        Can also be toggled with the keyboard using Ctrl-Cmd-6.
        """
    }

    override func flagsChanged(with event: NSEvent) {
        optionKeyPressed = event.modifierFlags.contains(.option)
    }

    @IBAction func powerOff(_: Any) {
        guard let display = display, displayController.activeDisplays.count > 1 else { return }

        guard display.hasDDC, optionKeyPressed else {
            guard lunarProOnTrial || lunarProActive else {
                if let url = URL(string: "https://lunar.fyi/#blackout") {
                    NSWorkspace.shared.open(url)
                }
                return
            }

            if !display.isInMirrorSet {
                displayController.blackOut(display: display.id, state: .on)
            } else {
                let mirrored = CGDisplayMirrorsDisplay(display.id)
                displayController.blackOut(
                    display: (mirrored != kCGNullDirectDisplay) ? mirrored : display.id,
                    state: .off
                )
            }
            return
        }
        _ = display.control?.setPower(.off)
    }

    func showGammaNotice() {
        guard display?.active ?? false else { return }
        let windowVisible = mainThread { view.window?.isVisible ?? false }
        guard gammaHighlighterTask == nil || !realtimeQueue.isValid(timer: gammaHighlighterTask!), windowVisible
        else {
            return
        }

        gammaHighlighterTask = realtimeQueue.async(every: 10.seconds) { [weak self] (_: CFRunLoopTimer?) in
            guard let s = self else {
                if let timer = self?.gammaHighlighterTask { realtimeQueue.cancel(timer: timer) }
                return
            }

            let windowVisible: Bool = mainThread { s.view.window?.isVisible ?? false }
            guard windowVisible, let gammaNotice = s.gammaNotice
            else {
                if let timer = self?.gammaHighlighterTask { realtimeQueue.cancel(timer: timer) }
                return
            }

            mainThread {
                if gammaNotice.alphaValue == 0 {
                    gammaNotice.transition(1)
                    gammaNotice.alphaValue = 0.9
                    gammaNotice.needsDisplay = true
                } else {
                    gammaNotice.transition(3)
                    gammaNotice.alphaValue = 0.0
                    gammaNotice.needsDisplay = true
                }
            }
        }
    }

    func hideGammaNotice() {
        if let timer = gammaHighlighterTask {
            realtimeQueue.cancel(timer: timer)
        }
        gammaHighlighterTask = nil

        mainThread { [weak self] in
            guard let gammaNotice = self?.gammaNotice else { return }
            gammaNotice.transition(0.3)
            gammaNotice.alphaValue = 0.0
            gammaNotice.needsDisplay = true
        }
    }

    func showAdaptiveNotice() {
        let windowVisible = mainThread { view.window?.isVisible ?? false }

        guard adaptiveHighlighterTask == nil || !realtimeQueue.isValid(timer: adaptiveHighlighterTask!), windowVisible
        else {
            return
        }

        adaptiveHighlighterTask = realtimeQueue.async(every: 5.seconds) { [weak self] (_: CFRunLoopTimer?) in
            guard let s = self else {
                if let timer = self?.adaptiveHighlighterTask { realtimeQueue.cancel(timer: timer) }
                return
            }

            let windowVisible: Bool = mainThread { s.view.window?.isVisible ?? false }
            guard windowVisible, let adaptiveNotice = s.adaptiveNotice
            else {
                if let timer = self?.adaptiveHighlighterTask { realtimeQueue.cancel(timer: timer) }
                return
            }

            mainThread {
                if adaptiveNotice.alphaValue == 0 {
                    adaptiveNotice.transition(1)
                    adaptiveNotice.alphaValue = 0.9
                    adaptiveNotice.needsDisplay = true
                } else {
                    adaptiveNotice.transition(3)
                    adaptiveNotice.alphaValue = 0.0
                    adaptiveNotice.needsDisplay = true
                }
            }
        }
    }

    func hideAdaptiveNotice() {
        if let timer = adaptiveHighlighterTask {
            realtimeQueue.cancel(timer: timer)
        }
        adaptiveHighlighterTask = nil

        mainThread { [weak self] in
            guard let adaptiveNotice = self?.adaptiveNotice else { return }
            adaptiveNotice.transition(0.3)
            adaptiveNotice.alphaValue = 0.0
            adaptiveNotice.needsDisplay = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewID = view.accessibilityIdentifier()

        lockBrightnessHelpButton?.helpText = LOCK_BRIGHTNESS_HELP_TEXT
        lockContrastHelpButton?.helpText = LOCK_CONTRAST_HELP_TEXT

        if let display = display, display.id != GENERIC_DISPLAY_ID {
            update()

            inputDropdown?.page = darkMode ? .hotkeys : .display
            inputDropdown?.fade()
            resetDropdown?.page = darkMode ? .hotkeysReset : .displayReset

            scrollableBrightness?.label.textColor = scrollableViewLabelColor
            scrollableContrast?.label.textColor = scrollableViewLabelColor
            builtinBrightnessField?.caption = builtinBrightnessCaption

            scrollableBrightness?.onMinValueChanged = { [weak self] (value: Int) in self?.updateDataset(minBrightness: value.u8) }
            scrollableBrightness?.onMaxValueChanged = { [weak self] (value: Int) in self?.updateDataset(maxBrightness: value.u8) }
            scrollableContrast?.onMinValueChanged = { [weak self] (value: Int) in self?.updateDataset(minContrast: value.u8) }
            scrollableContrast?.onMaxValueChanged = { [weak self] (value: Int) in self?.updateDataset(maxContrast: value.u8) }

            initGraph()
        } else {
            mainThread {
                setButtonsHidden(true)

                nonResponsiveTextField?.isHidden = true
                scrollableBrightness?.isHidden = true
                scrollableContrast?.isHidden = true
                brightnessContrastChart?.isHidden = true
            }
        }

        powerOffEnabled = getPowerOffEnabled()
        powerOffTooltip = getPowerOffTooltip()
        scheduleBox?.bg = .black.withAlphaComponent(0.03)
        scheduleBox?.radius = 10
    }
}
