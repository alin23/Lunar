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
* Doesn't work on the HDMI port of the post-2021 MacBook Pro
* Can wear out the monitor flash memory
* Even though DDC is supported by all monitors, **a bad combination of cables/adapters/hubs/GPU can break it**
    - *Aim for using as little adapters as possible between your Mac device and your monitor*
"""
let SOFTWARE_OVERLAY_HELP_TEXT = """
## Software Overlay

This monitor's hardware brightness can't be controlled in any way.
Because it is a **Virtual/Sidecar/Airplay** display, it doesn't support Gamma table alteration either.

Lunar has to fallback to mimicking a brightness change through a dark overlay.

### Advantages
* It works on any monitor no matter what type of connections is used

### Disadvantages
* **Needs the hardware brightness/contrast to be set manually to high values like 100/70 first**
* No support for changing volume, contrast or input
* Low brightness values can wash out colors
* Quitting Lunar resets the brightness to default

#### Notes

An **overlay** is a black, always-on-top, semi-transparent window that adjusts its opacity based on the brightness set in Lunar.

The overlay is not used on non-Airplay/Virtual monitors because Gamma is a better choice for accurate color rendering

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
"""
let NO_CONTROLS_HELP_TEXT = """
## No controls available

Looks like all available controls for this monitor have been disabled manually.

Click on the **Display Settings** button near the `RESET` dropdown to enable a control.
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

var monitorStandColor: NSColor { darkMode ? peach : lunarYellow }
var monitorScreenColor: NSColor { darkMode ? rouge : mauve }

// MARK: - DisplayImage

@IBDesignable
class DisplayImage: NSView {
    // MARK: Lifecycle

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup(frame: frame)
    }

    // MARK: Internal

    @IBInspectable var baseCornerRadius: CGFloat = 14
    @IBInspectable var maxCornerRadius: CGFloat = 24

    lazy var standColor = monitorStandColor { didSet { setup(frame: frame) }}
    lazy var screenColor = monitorScreenColor { didSet { setup(frame: frame) }}

    @IBInspectable var cornerRadius: CGFloat = 0 { didSet {
        transition(0.2)
        setup(frame: frame)
    }}

    func screenLayer() -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.cornerCurve = .continuous

        let radius = mapNumber(cornerRadius, fromLow: 0, fromHigh: maxCornerRadius, toLow: baseCornerRadius, toHigh: 24)

        layer.path = CGPath(
            roundedRect: CGRect(
                x: 0, y: frame.height * 0.25,
                width: frame.width,
                height: frame.height * 0.75
            ),
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        layer.fillColor = screenColor.cgColor
        return layer
    }

    func standLayer() -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.cornerCurve = .continuous

        let path = CGMutablePath()
        let tip: CGFloat = 85
        let mid = frame.width / 2

        let tip1 = CGPoint(x: mid, y: tip)
        let tip2 = CGPoint(x: mid - 50, y: 0)
        let tip3 = CGPoint(x: mid + 50, y: 0)
        let radius = mapNumber(cornerRadius, fromLow: 0, fromHigh: maxCornerRadius, toLow: baseCornerRadius, toHigh: 18)

        if radius > 0 {
            path.move(to: tip3)
            path.addArc(tangent1End: tip1, tangent2End: tip2, radius: radius)
            path.addArc(tangent1End: tip2, tangent2End: tip3, radius: radius)
            path.addArc(tangent1End: tip3, tangent2End: tip1, radius: radius)
            path.closeSubpath()
        } else {
            path.move(to: tip1)
            path.addLine(to: tip2)
            path.addLine(to: tip3)
            path.addLine(to: tip1)
        }

        layer.path = path
        layer.cornerRadius = radius
        layer.fillColor = standColor.cgColor
        return layer
    }

    func setup(frame _: NSRect) {
        wantsLayer = true
        layer = screenLayer()
        layer?.addSublayer(standLayer())
    }
}

// MARK: - DisplayViewController

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

    @IBOutlet var displayImage: DisplayImage?
    @IBOutlet var displayName: DisplayName?
    @IBOutlet var adaptiveNotice: NSTextField!
    @IBOutlet var gammaNotice: NSTextField!
    @IBOutlet var scrollableBrightness: ScrollableBrightness?
    @IBOutlet var scrollableContrast: ScrollableContrast?
    @IBOutlet var brightnessSlider: Slider?
    @IBOutlet var brightnessContrastSlider: Slider?

    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView?

    @IBOutlet var cornerRadiusField: ScrollableTextField?
    @IBOutlet var cornerRadiusFieldCaption: ScrollableTextFieldCaption?

    @IBOutlet var _controlsButton: NSButton!
    @IBOutlet var _proButton: NSButton!
    @IBOutlet var _lockContrastHelpButton: NSButton?
    @IBOutlet var _lockBrightnessHelpButton: NSButton?
    @IBOutlet var _settingsButton: NSButton?
    @IBOutlet var _resetButton: NSButton?
    @IBOutlet var _colorsButton: NSButton?
    @IBOutlet var _ddcButton: NSButton?
    @IBOutlet var lockContrastCurveButton: LockButton!
    @IBOutlet var lockBrightnessCurveButton: LockButton!

    @objc dynamic var noDisplay = false
    @objc dynamic lazy var chartHidden: Bool = display == nil || noDisplay || display!
        .ambientLightAdaptiveBrightnessEnabled || displayController
        .adaptiveModeKey == .clock

    var graphObserver: Cancellable?
    var adaptiveModeObserver: Cancellable?
    var sendingBrightnessObserver: ((Bool, Bool) -> Void)?
    var sendingContrastObserver: ((Bool, Bool) -> Void)?
    var activeAndResponsiveObserver: ((Bool, Bool) -> Void)?
    var adaptiveObserver: ((Bool, Bool) -> Void)?
    var viewID: String?
    var displayObservers = [String: AnyCancellable]()

    var pausedAdaptiveModeObserver = false

    @objc dynamic lazy var deleteEnabled = getDeleteEnabled()
    @objc dynamic lazy var powerOffEnabled = getPowerOffEnabled()
    @objc dynamic lazy var powerOffTooltip = getPowerOffTooltip()

    @IBOutlet var scheduleBox: NSBox!
    @IBOutlet var schedule1: Schedule!
    @IBOutlet var schedule2: Schedule!
    @IBOutlet var schedule3: Schedule!
    @IBOutlet var schedule4: Schedule!
    @IBOutlet var schedule5: Schedule!

    @IBOutlet var addScheduleButton: Button!

    var observers: Set<AnyCancellable> = []

    var openedBlackoutPage = false

    @IBOutlet var _inputDropdownHotkeyButton: NSButton? {
        didSet {
            mainAsync { [weak self] in
                self?.initHotkeys()
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

    var lockContrastHelpButton: HelpButton? {
        _lockContrastHelpButton as? HelpButton
    }

    var lockBrightnessHelpButton: HelpButton? {
        _lockBrightnessHelpButton as? HelpButton
    }

    var settingsButton: SettingsButton? {
        _settingsButton as? SettingsButton
    }

    var resetButton: ResetPopoverButton? {
        _resetButton as? ResetPopoverButton
    }

    var colorsButton: ColorsButton? {
        _colorsButton as? ColorsButton
    }

    var ddcButton: DDCButton? {
        _ddcButton as? DDCButton
    }

    @objc dynamic weak var display: Display? {
        didSet {
            if let display = display {
                mainAsync { [weak self] in self?.update(display) }
                noDisplay = display.id == GENERIC_DISPLAY_ID
            }
        }
    }

    @objc dynamic var lockedBrightnessCurve = false {
        didSet {
            display?.lockedBrightnessCurve = lockedBrightnessCurve
            lockBrightnessCurveButton?.state = lockedBrightnessCurve.state
        }
    }

    @objc dynamic var lockedContrastCurve = false {
        didSet {
            display?.lockedContrastCurve = lockedContrastCurve
            lockContrastCurveButton?.state = lockedContrastCurve.state
        }
    }

    lazy var gammaNoticeHighlighterTaskKey = "gammaNoticeHighlighter-\(display?.serial ?? "display")" {
        didSet {
            cancelTask(oldValue)
        }
    }

    func placeAddScheduleButton() {
        guard let addScheduleButton = addScheduleButton,
              let schedule2 = schedule2,
              let schedule3 = schedule3,
              let schedule4 = schedule4,
              let schedule5 = schedule5
        else { return }

        if schedule5.isEnabled {
            addScheduleButton.isHidden = true
            return
        }

        addScheduleButton.isHidden = false
        if schedule4.isEnabled {
            addScheduleButton.frame = schedule5.frame
        } else if schedule3.isEnabled {
            addScheduleButton.frame = schedule4.frame
        } else if schedule2.isEnabled {
            addScheduleButton.frame = schedule3.frame
        } else {
            addScheduleButton.frame = schedule2.frame
        }
        addScheduleButton.needsDisplay = true
    }

    @IBAction func showMoreSchedules(_: Any) {
        if !CachedDefaults[.showTwoSchedules] {
            CachedDefaults[.showTwoSchedules] = true
            schedule2.isEnabled = true
        } else if !CachedDefaults[.showThreeSchedules] {
            CachedDefaults[.showThreeSchedules] = true
            schedule3.isEnabled = true
        } else if !CachedDefaults[.showFourSchedules] {
            CachedDefaults[.showFourSchedules] = true
            schedule4.isEnabled = true
        } else if !CachedDefaults[.showFiveSchedules] {
            CachedDefaults[.showFiveSchedules] = true
            schedule5.isEnabled = true
        }
        placeAddScheduleButton()
    }

    @IBAction func showFewerSchedules(_: Any) {
        if CachedDefaults[.showFiveSchedules] {
            CachedDefaults[.showFiveSchedules] = false
            schedule5.isEnabled = false
        } else if CachedDefaults[.showFourSchedules] {
            CachedDefaults[.showFourSchedules] = false
            schedule4.isEnabled = false
        } else if CachedDefaults[.showThreeSchedules] {
            CachedDefaults[.showThreeSchedules] = false
            schedule3.isEnabled = false
        } else if CachedDefaults[.showTwoSchedules] {
            CachedDefaults[.showTwoSchedules] = false
            schedule2.isEnabled = false
        }
        placeAddScheduleButton()
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

    func refreshView() {
        mainAsync { [weak self] in
            guard let self = self else { return }
            self.view.setNeedsDisplay(self.view.visibleRect)
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
            NSWorkspace.shared.open("https://lunar.fyi/#pro".asURL()!)
            // } else if lunarProBadSignature {
            //     NSWorkspace.shared.open("https://lunar.fyi/download/latest".asURL()!)
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
        mainAsync { [weak self] in
            guard let self = self else { return }
            guard let button = self.proButton else { return }

            let width = button.frame.width
            if lunarProActive {
                button.bg = red
                button.attributedTitle = "Pro".withAttribute(.textColor(white))
                button.setFrameSize(NSSize(width: 50, height: button.frame.height))
                // } else if lunarProBadSignature {
                //     button.bg = errorRed
                //     button.attributedTitle = "Invalid App Signature".withAttribute(.textColor(.black.withAlphaComponent(0.8)))
                //     button.setFrameSize(NSSize(width: 150, height: button.frame.height))
            } else {
                button.bg = green
                button.attributedTitle = "Get Pro".withAttribute(.textColor(white))
                button.setFrameSize(NSSize(width: 70, height: button.frame.height))
            }
            if button.frame.width != width {
                button.center(within: self.view, vertically: false)
            }
        }
    }

    @objc func updateProIndicator(notification _: Notification) {
        setupProButton()
    }

    func update(_ display: Display? = nil) {
        guard let display = display ?? self.display else { return }

        display.withoutDDC { display.panelMode = display.panel?.currentMode }
        displayImage?.cornerRadius = CGFloat(display.cornerRadius.floatValue)
        // cornerRadiusField?.caption = cornerRadiusFieldCaption
        cornerRadiusField?.didScrollTextField = true
        cornerRadiusField?.integerValue = display.cornerRadius.intValue
        cornerRadiusField?.onValueChangedInstant = { [weak self] value in
            mainAsync {
                self?.displayImage?.cornerRadius = CGFloat(value)
                display.cornerRadius = value.ns
            }
        }
        cornerRadiusField?.onMouseEnter = { [weak self] in
            guard let self = self else { return }
            self.cornerRadiusFieldCaption?.transition(1.5, easing: .easeInEaseOut)
            self.cornerRadiusFieldCaption?.textColor = self.cornerRadiusField?.textColor
            self.cornerRadiusFieldCaption?.alphaValue = 0.8
        }
        cornerRadiusField?.onMouseExit = { [weak self] in
            guard let self = self else { return }
            self.cornerRadiusFieldCaption?.transition(1)
            self.cornerRadiusFieldCaption?.alphaValue = 0.0
        }

        deleteEnabled = getDeleteEnabled(display: display)
        powerOffEnabled = getPowerOffEnabled(display: display)
        powerOffTooltip = getPowerOffTooltip(display: display)
        chartHidden = noDisplay || display.ambientLightAdaptiveBrightnessEnabled || displayController.adaptiveModeKey == .clock

        if let button = colorsButton {
            button.display = display
        }
        if let button = ddcButton {
            button.display = display
        }
        if let button = settingsButton {
            button.display = display
            button.displayViewController = self
            button.notice = adaptiveNotice
        }
        if let button = resetButton {
            button.display = display
            button.displayViewController = self
        }

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

        schedule2?.isEnabled = CachedDefaults[.showTwoSchedules]
        schedule3?.isEnabled = CachedDefaults[.showThreeSchedules]
        schedule4?.isEnabled = CachedDefaults[.showFourSchedules]
        schedule5?.isEnabled = CachedDefaults[.showFiveSchedules]

        placeAddScheduleButton()

        scheduleBox?.isHidden = displayController.adaptiveModeKey != .clock

        display.onBrightnessCurveFactorChange = { [weak self] factor in
            guard let self = self else { return }
            self.updateDataset(brightnessFactor: factor)
        }

        display.onContrastCurveFactorChange = { [weak self] factor in
            guard let self = self else { return }
            self.updateDataset(contrastFactor: factor)
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
            mainAsyncAfter(ms: 10) { [weak self] in
                guard let self = self else { return }
                self.updateControlsButton(control: control)
                if control is GammaControl, display.enabledControls[.gamma] ?? false {
                    self.showGammaNotice()
                } else {
                    self.hideGammaNotice()
                }
            }
        }

        if display.id == GENERIC_DISPLAY_ID {
            displayName?.stringValue = "No Display"
            displayName?.display = nil
        } else {
            displayName?.stringValue = display.name
            displayName?.display = self.display
        }

        initHotkeys()
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
        mainAsync { [weak self] in
            guard let self = self else { return }
            guard let button = self.controlsButton, let display = self.display else {
                return
            }

            guard display.active else {
                self.setDisconnected()
                return
            }

            guard let control = control ?? display.control else {
                return
            }

            button.alpha = 0.85
            button.hoverAlpha = 1.0
            button.circle = false

            switch control {
            case is AppleNativeControl:
                button.bg = green
                button.attributedTitle = "Apple Native".withAttribute(.textColor(mauve))
                button.helpText = NATIVE_CONTROLS_HELP_TEXT
            case is DDCControl:
                button.bg = darkMode ? peach : lunarYellow
                button.attributedTitle = "Hardware DDC".withAttribute(.textColor(darkMauve))
                button.helpText = HARDWARE_CONTROLS_HELP_TEXT
            case is GammaControl where display.enabledControls[.gamma] ?? false:
                button.bg = darkMode ? peach.blended(withFraction: 0.5, of: red) : red.withAlphaComponent(0.9)
                if display.supportsGamma {
                    button.attributedTitle = "Software Gamma".withAttribute(.textColor(.black))
                    button.helpText = SOFTWARE_CONTROLS_HELP_TEXT
                } else {
                    button.attributedTitle = "Software Overlay".withAttribute(.textColor(.black))
                    button.helpText = SOFTWARE_OVERLAY_HELP_TEXT
                }
            case is NetworkControl:
                button.bg = darkMode ? blue.highlight(withLevel: 0.2) : blue.withAlphaComponent(0.9)
                button.attributedTitle = "Network Pi".withAttribute(.textColor(.black))
                button.helpText = NETWORK_CONTROLS_HELP_TEXT
            default:
                button.bg = darkMode ? gray.withAlphaComponent(0.6) : gray.withAlphaComponent(0.9)
                button.attributedTitle = "No Controls".withAttribute(.textColor(.darkGray))
                button.helpText = NO_CONTROLS_HELP_TEXT
            }
            self.brightnessSlider?.color = button.bg!
            self.brightnessContrastSlider?.color = button.bg!
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
                let curveAdjustedValues = mode.adjustCurveSIMD(
                    [Double](values.striding(by: 30)),
                    factor: mode.visualCurveFactor,
                    minVal: minBrightness?.d ?? display.minBrightness.doubleValue,
                    maxVal: maxBrightness?.d ?? display.maxBrightness.doubleValue
                )
                for (x, b) in zip(xs, curveAdjustedValues) {
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
                let curveAdjustedValues = mode.adjustCurveSIMD(
                    [Double](values.striding(by: 30)),
                    factor: mode.visualCurveFactor,
                    minVal: minContrast?.d ?? display.minContrast.doubleValue,
                    maxVal: maxContrast?.d ?? display.maxContrast.doubleValue
                )
                for (x, b) in zip(xs, curveAdjustedValues) {
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
        mainAsync { [weak self] in
            self?.brightnessContrastChart?.notifyDataSetChanged()
        }
    }

    @objc func resetDDC() {
        guard let display = display else { return }
        display.resetDDC()
    }

    @objc func resetNetworkController() {
        guard let display = display else { return }
        display.resetNetworkController()
    }

    @objc func resetAlgorithmCurve() {
        guard let display = display else {
            return
        }

        display.adaptivePaused = true
        defer {
            display.adaptivePaused = false
            display.readapt(newValue: false, oldValue: true)
        }

        display.userContrast[displayController.adaptiveModeKey]?.removeAll()
        display.userBrightness[displayController.adaptiveModeKey]?.removeAll()
        display.save()
        updateDataset(force: true)
    }

    @objc func resetBrightnessAndContrast() {
        guard let display = display else {
            return
        }
        display.adaptive = false
        _ = display.control?.reset()
    }

    @objc func resetLunarSettings() {
        resetDisplay(askBefore: false, resetControl: false)
    }

    @objc func fullReset() {
        resetDisplay()
    }

    @IBAction func reset(_ sender: NSPopUpButton) {
        guard display != nil, let action = ResetAction(rawValue: sender.selectedTag()) else { return }

        switch action {
        case .algorithmCurve:
            resetAlgorithmCurve()
        case .networkControl:
            resetNetworkController()
        case .ddcState:
            resetDDC()
        case .brightnessAndContrast:
            resetBrightnessAndContrast()
        case .lunarSettings:
            resetLunarSettings()
        case .fullReset:
            fullReset()
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
        display?.$maxBrightness.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self = self else { return }
            self.scrollableBrightness?.maxValue.integerValue = value.intValue
            self.scrollableBrightness?.minValue.upperLimit = value.doubleValue - 1
        }.store(in: &displayObservers, for: "maxBrightness")
        display?.$maxContrast.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self = self else { return }
            self.scrollableContrast?.maxValue.integerValue = value.intValue
            self.scrollableContrast?.minValue.upperLimit = value.doubleValue - 1
        }.store(in: &displayObservers, for: "maxContrast")

        display?.$minBrightness.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self = self else { return }
            self.scrollableBrightness?.minValue.integerValue = value.intValue
            self.scrollableBrightness?.maxValue.lowerLimit = value.doubleValue + 1
        }.store(in: &displayObservers, for: "minBrightness")
        display?.$minContrast.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self = self else { return }
            self.scrollableContrast?.minValue.integerValue = value.intValue
            self.scrollableContrast?.maxValue.lowerLimit = value.doubleValue + 1
        }.store(in: &displayObservers, for: "minContrast")

        display?.$brightness.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self = self else { return }
            self.scrollableBrightness?.currentValue.integerValue = value.intValue
        }.store(in: &displayObservers, for: "brightness")
        display?.$contrast.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self = self else { return }
            self.scrollableContrast?.currentValue.integerValue = value.intValue
        }.store(in: &displayObservers, for: "contrast")
    }

    func listenForDisplayBoolChange() {
        guard let display = display else { return }
        display.$hasDDC.receive(on: dataPublisherQueue).sink { [weak self] hasDDC in
            mainAsyncAfter(ms: 10) { [weak self] in
                guard let self = self else { return }

                self.powerOffEnabled = self.getPowerOffEnabled(hasDDC: hasDDC)
                self.powerOffTooltip = self.getPowerOffTooltip(hasDDC: hasDDC)
            }
        }.store(in: &displayObservers, for: "hasDDC")

        if !display.adaptive, !display.ambientLightAdaptiveBrightnessEnabled {
            showAdaptiveNotice()
        }
        display.$adaptive.receive(on: dataPublisherQueue).sink { [weak self] newAdaptive in
            mainAsync { [weak self] in
                guard let self = self else { return }
                guard let display = self.display else {
                    self.hideAdaptiveNotice()
                    return
                }
                self.chartHidden = self.noDisplay || self.display!.ambientLightAdaptiveBrightnessEnabled || displayController
                    .adaptiveModeKey == .clock

                if !newAdaptive, !display.ambientLightAdaptiveBrightnessEnabled {
                    self.showAdaptiveNotice()
                } else {
                    self.hideAdaptiveNotice()
                }
            }
        }.store(in: &displayObservers, for: "adaptive")
    }

    func listenForGraphDataChange() {
        graphObserver = moreGraphDataPublisher.sink { [weak self] change in
            log.debug("More graph data: \(change.newValue)")
            guard let self = self else { return }
            mainAsyncAfter(ms: 1000) { [weak self] in
                guard let self = self else { return }
                self.initGraph()
            }
        }
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = adaptiveBrightnessModePublisher.sink { [weak self] change in
            mainAsync {
                guard let self = self, !self.pausedAdaptiveModeObserver else { return }
                self.pausedAdaptiveModeObserver = true

                self.chartHidden = self.display == nil || self.noDisplay || self.display!.ambientLightAdaptiveBrightnessEnabled || change
                    .newValue == .clock
                self.scheduleBox?.isHidden = self.display == nil || self.noDisplay || change.newValue != .clock

                Defaults.withoutPropagation {
                    let adaptiveMode = change.newValue
                    if self.brightnessContrastChart != nil {
                        self.initGraph(mode: adaptiveMode.mode)
                    }
                    self.pausedAdaptiveModeObserver = false
                }
            }
        }
        DistributedNotificationCenter.default()
            .publisher(for: NSNotification.Name(rawValue: kAppleInterfaceThemeChangedNotification), object: nil)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.display?._hotkeyPopover = nil
                self?.display?.hotkeyPopoverController = self?.display?.initHotkeyPopoverController()
                self?.initHotkeys()
            }.store(in: &observers)
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

    func getDeleteEnabled(display: Display? = nil) -> Bool {
        guard let display = display ?? self.display else {
            return false
        }
        return display.id != GENERIC_DISPLAY_ID && !display.active
    }

    func getPowerOffEnabled(display: Display? = nil, hasDDC: Bool? = nil) -> Bool {
        guard let display = display ?? self.display, display.active else { return false }
        guard !display.isInMirrorSet else { return true }

        return (
            displayController.activeDisplays.count > 1 ||
                CachedDefaults[.allowBlackOutOnSingleScreen] ||
                (hasDDC ?? display.hasDDC)
        ) &&
            !display.isSidecar &&
            !display.isAirplay &&
            !display.isDummy
    }

    func getPowerOffTooltip(display: Display? = nil, hasDDC: Bool? = nil) -> String? {
        guard let display = display ?? self.display else { return nil }
        guard !(hasDDC ?? display.hasDDC) else {
            return """
            BlackOut simulates a monitor power off by mirroring the contents of the other visible screen to this one and setting this monitor's brightness to absolute 0.

            Can also be toggled with the keyboard using Ctrl-Cmd-6.

            Hold the Shift key while clicking the button (or while pressing the hotkey) if you only want to make the screen black without changing the mirroring state.

            Hold the Option key while clicking the button (or while pressing the hotkey) if you want to power off the monitor completely using DDC.

            Caveats for DDC power offf:
              • works only if the monitor can be controlled through DDC
              • can't be used to power on the monitor
              • when a monitor is turned off or in standby, it does not accept commands from a connected device
              • remember to keep holding the Option key for 2 seconds after you pressed the button to account for possible DDC delays
            """
        }
        guard displayController.activeDisplays.count > 1 || CachedDefaults[.allowBlackOutOnSingleScreen] else {
            return """
            At least 2 screens need to be visible for this to work.

            The option can also be enabled for a single screen in Advanced settings.
            """
        }

        return """
        BlackOut simulates a monitor power off by mirroring the contents of the other visible screen to this one and setting this monitor's brightness to absolute 0.

        Can also be toggled with the keyboard using Ctrl-Cmd-6.

        Hold the Shift key while clicking the button (or while pressing the hotkey) if you only want to make the screen black without changing the mirroring state.
        """
    }

    @IBAction func delete(_: Any) {
        guard let serial = display?.serial else { return }
        CachedDefaults[.displays] = CachedDefaults[.displays]?.filter { $0.serial != serial }
        displayController.resetDisplayList()
    }

    @IBAction func autoBlackout(_: Any) {
        guard lunarProOnTrial || lunarProActive || openedBlackoutPage else {
            openedBlackoutPage = true
            if let url = URL(string: "https://lunar.fyi/#blackout") {
                NSWorkspace.shared.open(url)
            }
            return
        }
    }

    @IBAction func powerOff(_: Any) {
        guard let display = display,
              displayController.activeDisplays.count > 1 || CachedDefaults[.allowBlackOutOnSingleScreen] else { return }

        if display.hasDDC, AppDelegate.optionKeyPressed {
            _ = display.control?.setPower(.off)
            return
        }

        guard lunarProOnTrial || lunarProActive else {
            if let url = URL(string: "https://lunar.fyi/#blackout") {
                NSWorkspace.shared.open(url)
            }
            return
        }

        displayController.blackOut(
            display: display.id,
            state: display.blackOutEnabled ? .off : .on,
            mirroringAllowed: !AppDelegate.shiftKeyPressed && display.blackOutMirroringAllowed
        )
    }

    func showGammaNotice() {
        mainAsync { [weak self] in
            guard let self = self, self.display?.active ?? false, self.view.window?.isVisible ?? false
            else { return }

            asyncEvery(
                5.seconds,
                uniqueTaskKey: self.gammaNoticeHighlighterTaskKey,
                skipIfExists: true,
                eager: true,
                queue: DispatchQueue.main
            ) { [weak self] in
                guard let self = self else { return }

                guard self.view.window?.isVisible ?? false, let gammaNotice = self.gammaNotice
                else {
                    cancelTask(self.gammaNoticeHighlighterTaskKey)
                    return
                }

                if gammaNotice.alphaValue <= 0.1 {
                    gammaNotice.transition(2)
                    gammaNotice.alphaValue = 0.9
                    gammaNotice.needsDisplay = true
                } else {
                    gammaNotice.transition(3)
                    gammaNotice.alphaValue = 0.01
                    gammaNotice.needsDisplay = true
                }
            }
        }
    }

    func hideGammaNotice() {
        mainAsync { [weak self] in
            guard let self = self else { return }
            cancelTask(self.gammaNoticeHighlighterTaskKey)

            guard let gammaNotice = self.gammaNotice else { return }
            gammaNotice.transition(0.3)
            gammaNotice.alphaValue = 0.0
            gammaNotice.needsDisplay = true
        }
    }

    func showAdaptiveNotice() {
        guard let d = display, !d.isBuiltin, let button = settingsButton else {
            hideAdaptiveNotice()
            return
        }
        button.highlight()
    }

    func hideAdaptiveNotice() {
        guard let button = settingsButton else { return }
        button.stopHighlighting()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewID = view.accessibilityIdentifier()

        lockBrightnessHelpButton?.helpText = LOCK_BRIGHTNESS_HELP_TEXT
        lockContrastHelpButton?.helpText = LOCK_CONTRAST_HELP_TEXT

        if let display = display, display.id != GENERIC_DISPLAY_ID {
            update()

            scrollableBrightness?.label.textColor = scrollableViewLabelColor
            scrollableContrast?.label.textColor = scrollableViewLabelColor

            scrollableBrightness?.onMinValueChanged = { [weak self] (value: Int) in self?.updateDataset(minBrightness: value.u8) }
            scrollableBrightness?.onMaxValueChanged = { [weak self] (value: Int) in self?.updateDataset(maxBrightness: value.u8) }
            scrollableContrast?.onMinValueChanged = { [weak self] (value: Int) in self?.updateDataset(minContrast: value.u8) }
            scrollableContrast?.onMaxValueChanged = { [weak self] (value: Int) in self?.updateDataset(maxContrast: value.u8) }

            initGraph()
        }

        deleteEnabled = getDeleteEnabled()
        powerOffEnabled = getPowerOffEnabled()
        powerOffTooltip = getPowerOffTooltip()
    }
}
