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
    * Even though DDC is supported by all monitors, **a bad combination of cables/adapters/hubs/GPU can break it**
        - *Aim for using as little adapters as possible between your Mac device and your monitor*
    * Can wear out the monitor flash memory
    * Not supported by TVs
    """
    let SOFTWARE_CONTROLS_HELP_TEXT = """
    ## Gamma tables

    This monitor's hardware brightness can't be controlled in any way.
    Lunar has to fallback to mimicking a brightness change through gamma table alteration.

    ### Advantages
    * It works on any monitor no matter what cable/adapter/connector you use
    * Uhh.. the only thing that works out of the box on Apple Silicon for now

    ### Disadvantages
    * **Needs the hardware brightness/contrast to be set manually to high values like 100/70 first**
    * No support for changing volume or input
    * No smooth transitions
    * Low brightness values can wash out colors
    * Quitting Lunar resets the brightness to default
    * Contrast is approximated by adjusting the gamma factor and can look very bad on some monitors
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
    @IBOutlet var _inputDropdownHotkeyButton: NSButton? {
        didSet {
            mainThread {
                initHotkeys()
            }
        }
    }

    @IBOutlet var adaptiveNotice: NSTextField!
    @IBOutlet var gammaNotice: NSTextField!
    var inputDropdownHotkeyButton: HotkeyButton? {
        _inputDropdownHotkeyButton as? HotkeyButton
    }

    @IBOutlet var inputDropdown: PopUpButton? {
        didSet {
            if let display = display, let input = InputSource(rawValue: display.input.uint8Value) {
                inputDropdown?.selectItem(withTag: input.rawValue.i)
            }
        }
    }

    @IBOutlet var scrollableBrightness: ScrollableBrightness?
    @IBOutlet var scrollableContrast: ScrollableContrast?

    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView?

    @IBOutlet var _controlsButton: NSButton!
    var controlsButton: HelpButton? {
        _controlsButton as? HelpButton
    }

    @IBOutlet var _proButton: NSButton!
    var proButton: Button? {
        _proButton as? Button
    }

    @IBOutlet var nonResponsiveTextField: NonResponsiveTextField? {
        didSet {
            if let d = display {
                mainThread {
                    nonResponsiveTextField?.isHidden = d.id == GENERIC_DISPLAY_ID
                }
            }
        }
    }

    @IBOutlet var _lockContrastHelpButton: NSButton?
    var lockContrastHelpButton: HelpButton? {
        _lockContrastHelpButton as? HelpButton
    }

    @IBOutlet var _lockBrightnessHelpButton: NSButton?
    var lockBrightnessHelpButton: HelpButton? {
        _lockBrightnessHelpButton as? HelpButton
    }

    @IBOutlet var _settingsButton: NSButton?
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

    @objc dynamic var noDisplay: Bool = false

    var adaptiveModeObserver: Cancellable?
    var sendingBrightnessObserver: ((Bool, Bool) -> Void)?
    var sendingContrastObserver: ((Bool, Bool) -> Void)?
    var activeAndResponsiveObserver: ((Bool, Bool) -> Void)?
    var adaptiveObserver: ((Bool, Bool) -> Void)?
    var viewID: String?
    var displayObservers = Set<AnyCancellable>()

    override func mouseDown(with ev: NSEvent) {
        if let editor = displayName?.currentEditor() {
            editor.selectedRange = NSMakeRange(0, 0)
            displayName?.abortEditing()
        }
        super.mouseDown(with: ev)
    }

    func setButtonsHidden(_ hidden: Bool) {
        mainThread {
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
        guard let button = inputDropdownHotkeyButton, let display = display, button.popoverController != nil
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
        guard let display = display, let brightnessContrastChart = brightnessContrastChart, display.id != GENERIC_DISPLAY_ID else { return }
        brightnessContrastChart.highlightCurrentValues(adaptiveMode: displayController.adaptiveMode, for: display)
    }

    @objc func adaptToUserDataPoint(notification: Notification) {
        guard displayController.adaptiveModeKey != .manual,
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
            NSWorkspace.shared.open(try! "https://lunar.fyi/#sync".asURL())
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
            button.center(within: view, vertically: false)
        }
    }

    @objc func updateProIndicator(notification _: Notification) {
        setupProButton()
    }

    func update(_ display: Display? = nil) {
        guard let display = display ?? self.display else { return }

        settingsButton?.display = display
        updateControlsButton()
        updateNotificationObservers(for: display)

        scrollableBrightness?.onCurrentValueChanged = { [weak self] brightness in
            guard let self = self, let display = self.display, displayController.adaptiveModeKey != .manual else {
                self?.updateDataset(currentBrightness: brightness.u8)
                return
            }
            cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)

            var userValues = display.userBrightness[displayController.adaptiveModeKey] ?? [:]
            let lastDataPoint = datapointLock.around { displayController.adaptiveMode.brightnessDataPoint.last }
            Display.insertDataPoint(
                values: &userValues,
                featureValue: lastDataPoint,
                targetValue: brightness,
                logValue: false
            )
            self.updateDataset(currentBrightness: brightness.u8, userBrightness: userValues)
            display.insertBrightnessUserDataPoint(lastDataPoint, brightness, modeKey: displayController.adaptiveModeKey)
        }
        scrollableContrast?.onCurrentValueChanged = { [weak self] contrast in
            guard let self = self, let display = self.display, displayController.adaptiveModeKey != .manual else {
                self?.updateDataset(currentContrast: contrast.u8)
                return
            }

            var userValues = display.userContrast[displayController.adaptiveModeKey] ?? [:]
            let lastDataPoint = displayController.adaptiveMode.contrastDataPoint.last
            Display.insertDataPoint(
                values: &userValues,
                featureValue: lastDataPoint,
                targetValue: contrast,
                logValue: false
            )
            self.updateDataset(currentContrast: contrast.u8, userContrast: userValues)
            display.insertContrastUserDataPoint(lastDataPoint, contrast, modeKey: displayController.adaptiveModeKey)
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
                    display.control.resetState()
                    self.setButtonsHidden(display.id == GENERIC_DISPLAY_ID)
                    self.refreshView()
                }
            }
        }

        if let input = InputSource(rawValue: display.input.uint8Value) {
            inputDropdown?.selectItem(withTag: input.rawValue.i)
        }
        initHotkeys()
        setButtonsHidden(display.id == GENERIC_DISPLAY_ID)
        refreshView()
    }

    func updateControlsButton(control: Control? = nil) {
        guard let button = controlsButton, let display = display, let control = control ?? display.control else { return }

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
                button.bg = lunarYellow
                button.attributedTitle = "Hardware Controls".withAttribute(.textColor(darkMauve))
                button.helpText = HARDWARE_CONTROLS_HELP_TEXT
            case is GammaControl where display.enabledControls[.gamma] ?? false:
                button.bg = red.withAlphaComponent(0.9)
                button.attributedTitle = "Software Controls".withAttribute(.textColor(.black))
                button.helpText = SOFTWARE_CONTROLS_HELP_TEXT
            case is NetworkControl:
                button.bg = blue.withAlphaComponent(0.9)
                button.attributedTitle = "Network Controls".withAttribute(.textColor(.black))
                button.helpText = NETWORK_CONTROLS_HELP_TEXT
            default:
                button.bg = gray.withAlphaComponent(0.9)
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
        factor: Double? = nil,
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
                display: display, factor: factor,
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
            for (x, y) in zip(xs, points.brightness) {
                brightnessChartEntry[x].y = y
            }
            for (x, y) in zip(xs, points.contrast) {
                contrastChartEntry[x].y = y
            }
        case let mode as SyncMode:
            let maxValues = min(mode.maxChartDataPoints, brightnessChartEntry.count, contrastChartEntry.count)
            let xs = stride(from: 0, to: maxValues, by: 1)

            if force || minBrightness != nil || maxBrightness != nil || userBrightness != nil {
                let values = mode.interpolateSIMD(
                    .brightness(0),
                    display: display,
                    minVal: minBrightness?.d,
                    maxVal: maxBrightness?.d,
                    userValues: userBrightness
                )
                for (x, b) in zip(xs, values) {
                    brightnessChartEntry[x].y = b
                }
            }
            if force || minContrast != nil || maxContrast != nil || userContrast != nil {
                let values = mode.interpolateSIMD(
                    .contrast(0),
                    display: display,
                    minVal: minContrast?.d,
                    maxVal: maxContrast?.d,
                    userValues: userContrast
                )
                for (x, b) in zip(xs, values) {
                    contrastChartEntry[x].y = b
                }
            }
        case let mode as SensorMode:
            let maxValues = min(mode.maxChartDataPoints, brightnessChartEntry.count, contrastChartEntry.count)
            let xs = stride(from: 0, to: maxValues, by: 1)

            if force || minBrightness != nil || maxBrightness != nil || userBrightness != nil {
                let values = mode.interpolateSIMD(
                    .brightness(0),
                    display: display,
                    minVal: minBrightness?.d,
                    maxVal: maxBrightness?.d,
                    userValues: userBrightness
                )
                for (x, b) in zip(xs, values) {
                    brightnessChartEntry[x].y = b
                }
            }
            if force || minContrast != nil || maxContrast != nil || userContrast != nil {
                let values = mode.interpolateSIMD(
                    .contrast(0),
                    display: display,
                    minVal: minContrast?.d,
                    maxVal: maxContrast?.d,
                    userValues: userContrast
                )
                for (x, b) in zip(xs, values) {
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
        brightnessContrastChart.notifyDataSetChanged()
    }

//     func demo() {
//         guard let solar = LocationMode.specific.geolocation?.solar,
//               let sunrise = LocationMode.specific.moment?.sunrise,
//               let sunset = LocationMode.specific.moment?.sunset,
    // //              let sunrisePosition = solar.sunrisePosition,
    // //              let sunsetPosition = solar.sunsetPosition,
    // //              let solarNoonPosition = solar.solarNoonPosition,
//               let display = display, let brightnessContrastChart = brightnessContrastChart
//         else {
//             return
//         }
//         scrollableBrightness?.onCurrentValueChanged = nil
//         scrollableContrast?.onCurrentValueChanged = nil
//         for hour in sunrise.hour ... sunset.hour {
//             for minute in stride(from: 0, to: 60, by: 5) {
//                 log.info("Setting time to \(hour):\(minute)")
//                 let (brightness, contrast) = LocationMode.specific.getBrightnessContrast(
//                     display: display, hour: hour, minute: minute
//                 )
//                 mainThread {
//                     log.info("Brightness: \(brightness)    Contrast: \(contrast)")
//                     scrollableBrightness!.currentValue.stringValue = brightness.intround.s
//                     scrollableContrast!.currentValue.stringValue = contrast.intround.s
//                     scrollableBrightness!.setNeedsDisplay(scrollableBrightness!.visibleRect)
//                     scrollableContrast!.setNeedsDisplay(scrollableContrast!.visibleRect)

//                     var now = DateInRegion().convertTo(region: Region.local)
//                     now = now.dateBySet(hour: hour, min: minute, secs: 0)!

//                     brightnessContrastChart.highlightCurrentValues(
//                         adaptiveMode: displayController.adaptiveMode, for: display,
//                         now: now.date
//                     )
//                     brightnessContrastChart.notifyDataSetChanged()
//                     brightnessContrastChart.setNeedsDisplay(brightnessContrastChart.visibleRect)
//                     view.setNeedsDisplay(view.visibleRect)
//                 }
    // //            let sleepTime = pow(0.01, 1 - (elevation / solarNoonPosition.elevation))
    // //            log.info("Sleeping for \(sleepTime)")
    // //            Thread.sleep(forTimeInterval: sleepTime)
//                 Thread.sleep(forTimeInterval: 0.01)
//             }
//         }
//     }

    enum ResetAction: Int {
        case algorithmCurve = 0
        case networkControl
        case ddcState
        case brightnessAndContrast
        case fullReset
        case reset = 99
    }

    func resetControl() {
        guard let display = display else { return }
        display.control = display.getBestControl()
        display.onControlChange?(display.control)

        if !(display.enabledControls[.gamma] ?? false) {
            display.resetGamma()
        }
    }

    func resetDDC() {
        asyncAfter(ms: 10, uniqueTaskKey: "resetDDCTask") { [weak self] in
            guard let self = self, let display = self.display else { return }
            if display.control is DDCControl {
                display.control.resetState()
            } else {
                DDCControl(display: display).resetState()
            }

            self.resetControl()

            for _ in 1 ... 5 {
                displayController.adaptBrightness(force: true)
                sleep(3)
            }
        }
    }

    func resetNetworkController() {
        asyncAfter(ms: 10, uniqueTaskKey: "resetNetworkControlTask") { [weak self] in
            guard let self = self, let display = self.display else { return }
            if display.control is NetworkControl {
                display.control.resetState()
            } else {
                NetworkControl.resetState(serial: display.serial)
            }

            self.resetControl()

            for _ in 1 ... 5 {
                displayController.adaptBrightness(force: true)
                sleep(3)
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
            _ = display.control.reset()
        case .fullReset:
            resetDisplay()
        default:
            break
        }
        sender.selectItem(withTag: ResetAction.reset.rawValue)
    }

    func resetDisplay() {
        guard let display = display else { return }

        let resetHandler = { [weak self] (_: Bool) in
            guard let display = self?.display, let self = self else { return }
            display.adaptivePaused = true
            defer {
                display.adaptivePaused = false
                display.readapt(newValue: false, oldValue: true)
            }

            display.reset()
            self.settingsButton?.popoverController?.display = display
            self.updateDataset(force: true)
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

    func initToggleButton(_ button: NSButton?, helpButton: NSButton?) {
        guard let button = button else { return }
        if displayController
            .adaptiveModeKey == .manual || (display != nil && !display!.activeAndResponsive || display!.id == GENERIC_DISPLAY_ID)
        {
            button.isHidden = true
            helpButton?.isHidden = true
        } else {
            button.isHidden = false
            helpButton?.isHidden = false
        }
    }

    func setIsHidden(_ value: Bool) {
        mainThread {
            setButtonsHidden(value)

            nonResponsiveTextField?.isHidden = value
            scrollableBrightness?.isHidden = value
            scrollableContrast?.isHidden = value
            brightnessContrastChart?.isHidden = value
        }
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif

        for observer in displayObservers {
            observer.cancel()
        }
    }

    func listenForSendingBrightnessContrast() {
        display?.$sendingContrast.receive(on: dataPublisherQueue).sink { [weak self] newValue in
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
        }.store(in: &displayObservers)
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
        }.store(in: &displayObservers)
    }

    func listenForBrightnessContrastChange() {
        display?.$maxBrightness.receive(on: dataPublisherQueue).sink { [weak self] value in
            guard let self = self else { return }
            mainThread { self.scrollableBrightness?.maxValue.integerValue = value.intValue }
        }.store(in: &displayObservers)
        display?.$maxContrast.receive(on: dataPublisherQueue).sink { [weak self] value in
            guard let self = self else { return }
            mainThread { self.scrollableContrast?.maxValue.integerValue = value.intValue }
        }.store(in: &displayObservers)
    }

    func listenForDisplayBoolChange() {
        display?.$activeAndResponsive.receive(on: dataPublisherQueue).sink { [weak self] newActiveAndResponsive in
            if let self = self, let display = self.display, let textField = self.nonResponsiveTextField {
                self.setButtonsHidden(display.id == GENERIC_DISPLAY_ID || !newActiveAndResponsive)

                mainThread { textField.isHidden = newActiveAndResponsive }
            }
        }.store(in: &displayObservers)

        if let display = display {
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
            }.store(in: &displayObservers)
//            display.setObserver(
//                prop: .adaptive,
//                key: "displayViewController-\(viewID ?? "")",
//                action: adaptiveObserver!
//            )
        }
    }

    var pausedAdaptiveModeObserver: Bool = false

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = adaptiveBrightnessModePublisher.sink { [weak self] change in
            guard let self = self, !self.pausedAdaptiveModeObserver else {
                return
            }
            self.pausedAdaptiveModeObserver = true
            Defaults.withoutPropagation {
                let adaptiveMode = change.newValue
                mainThread {
                    if CachedDefaults[.overrideAdaptiveMode] {
                        self.inputDropdown?.selectItem(withTag: adaptiveMode.rawValue)
                    } else {
                        self.inputDropdown?.selectItem(withTag: AUTO_MODE_TAG)
                    }

                    if let chart = self.brightnessContrastChart, !chart.visibleRect.isEmpty {
                        self.initGraph(mode: adaptiveMode.mode)
                    }
                }
                self.pausedAdaptiveModeObserver = false
            }
        }
    }

    func initGraph(mode: AdaptiveMode? = nil) {
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

    @IBAction func powerOff(_: Any) {
        _ = display?.control?.setPower(.off)
    }

    @IBAction func setInput(_ sender: NSPopUpButton) {
        guard let display = display, let input = InputSource(rawValue: sender.selectedTag().u8) else { return }
        display.input = input.rawValue.ns
    }

    @AtomicLock var gammaHighlighterTask: CFRunLoopTimer?

    func showGammaNotice() {
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

    @AtomicLock var adaptiveHighlighterTask: CFRunLoopTimer?

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

            scrollableBrightness?.display = display
            scrollableContrast?.display = display

            if let inputDropdown = inputDropdown {
                inputDropdown.appearance = NSAppearance(named: .vibrantLight)

                for item in inputDropdown.itemArray {
                    var title = item.attributedTitle?.string ?? item.title
                    if title == "Unknown" {
                        title = "Input"
                    }
                    item.attributedTitle = title
                        .withAttribute(.textColor(darkMauve.blended(withFraction: 0.3, of: gray)!))
                }
            }

            scrollableBrightness?.label.textColor = scrollableViewLabelColor
            scrollableContrast?.label.textColor = scrollableViewLabelColor

            scrollableBrightness?.onMinValueChanged = { [weak self] (value: Int) in self?.updateDataset(minBrightness: value.u8) }
            scrollableBrightness?.onMaxValueChanged = { [weak self] (value: Int) in self?.updateDataset(maxBrightness: value.u8) }
            scrollableContrast?.onMinValueChanged = { [weak self] (value: Int) in self?.updateDataset(minContrast: value.u8) }
            scrollableContrast?.onMaxValueChanged = { [weak self] (value: Int) in self?.updateDataset(maxContrast: value.u8) }

            initGraph()
        } else {
            setIsHidden(true)
        }
        listenForSendingBrightnessContrast()
        listenForAdaptiveModeChange()
        listenForDisplayBoolChange()
        listenForBrightnessContrastChange()
        updateControlsButton()
        setupProButton()

        // upHotkey = Magnet.HotKey(identifier: "LocationMode Demo", keyCombo: KeyCombo(key: .d, cocoaModifiers: [.option])!) { _ in
        //     log.debug("DEMO TIME!!")
        //     async(threaded: true) {
        //         self.demo()
        //     }
        // }
        // upHotkey?.register()
    }
}
