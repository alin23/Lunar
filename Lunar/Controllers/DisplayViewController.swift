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

let NATIVE_CONTROLS_BUILTIN_HELP_TEXT = """
## Apple Native Protocol

The builtin screen brightness can be controlled natively through the macOS internal **DisplayServices framework**.
"""
let NATIVE_CONTROLS_HELP_TEXT = """
## Apple Native Protocol

This monitor's brightness can be controlled natively through the macOS internal **DisplayServices framework**.

### Advantages
* Lunar doesn't need to use less stable methods like *DDC* for the brightness
* Brightness transitions are smoother

### Disadvantages
* **Contrast/Volume still needs to be changed through DDC** as there is no API for them in DisplayServices
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

"""

let SOFTWARE_OVERLAY_FORCED_HELP_TEXT = """
## Software Overlay

This monitor's brightness will be dimmed by placing a dark overlay on top.

### Advantages
* It works on any monitor no matter what type of connections is used

### Disadvantages
* **Needs the hardware brightness/contrast to be set manually to high values like 100/70 first**
* No support for changing volume, contrast or input
* Low brightness values can wash out colors
* Quitting Lunar resets the brightness to default

#### Notes

An **overlay** is a black, always-on-top, semi-transparent window that adjusts its opacity based on the brightness set in Lunar.

"""
let SOFTWARE_CONTROLS_FORCED_HELP_TEXT = """
## Gamma tables

This monitor's brightness will be dimmed by altering its RGB Gamma table to make the colors look less bright.

### Advantages
* It works on any monitor no matter what cable/adapter/connector you use

### Disadvantages
* **Needs the hardware brightness/contrast to be set manually to high values like 100/70 first**
* No support for changing volume or input
* Low brightness values can wash out colors
* Quitting Lunar resets the brightness to default

"""

let NO_CONTROLS_HELP_TEXT = """
## No controls available

Looks like all available controls for this monitor have been disabled manually.

Click on the `Controls` button near the `Reset` button to enable a control.
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
var macbookScreenColor: NSColor { darkMode ? rouge.blended(withFraction: 0.3, of: peach)! : violet }

// MARK: - DisplayImage

@IBDesignable
class DisplayImage: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup(frame: frame)
    }

    @IBInspectable var baseCornerRadius: CGFloat = 14
    @IBInspectable var maxCornerRadius: CGFloat = 24

    var isMacBook = false {
        didSet {
            screenColor = isMacBook ? macbookScreenColor : monitorScreenColor
        }
    }

    var isSidecar = false {
        didSet { setup(frame: frame) }
    }

    lazy var standColor = monitorStandColor { didSet { setup(frame: frame) }}
    lazy var screenColor = isMacBook ? macbookScreenColor : monitorScreenColor { didSet { setup(frame: frame) }}

    @IBInspectable var cornerRadius: CGFloat = 0 { didSet {
        transition(0.2)
        setup(frame: frame)
    }}

    func screenLayer(perspective: CGFloat = 0) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.cornerCurve = .continuous

        let radius = mapNumber(cornerRadius, fromLow: 0, fromHigh: maxCornerRadius, toLow: baseCornerRadius, toHigh: 24)

        layer.path = CGPath(
            roundedRect: CGRect(
                x: perspective / 4, y: frame.height * 0.25 + perspective / 6,
                width: frame.width - perspective / 2,
                height: (frame.height * 0.75 - perspective / 2) - perspective / 6
            ),
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        layer.fillColor = screenColor.cgColor
        if isSidecar {
            layer.fillColor = NSColor.black.highlight(withLevel: 0.15)!.cgColor
            layer.lineWidth = 9
            layer.strokeColor = NSColor.black.withAlphaComponent(0.95).cgColor
        }
        return layer
    }

    func macbookLayer(perspective: CGFloat) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.cornerCurve = .continuous

        let h = 0.08
        let y = 1.1
        let hh = 0.03

        let radius = mapNumber(cornerRadius, fromLow: 0, fromHigh: maxCornerRadius, toLow: 10, toHigh: 14)
        let rect = CGRect(
            x: 0, y: frame.height * y,
            width: frame.width,
            height: frame.height * h
        )
        layer.path = CGPath(
            rect: rect,
            transform: nil
        )

        if darkMode {
            layer.fillColor = screenColor.highlight(withLevel: 0.1)!.cgColor
        } else {
            layer.fillColor = screenColor.shadow(withLevel: 0.2)!.cgColor
        }
        layer.cornerRadius = radius
        layer.masksToBounds = true
        layer.bounds = rect
        layer.anchorPoint = NSPoint(x: 0, y: -1.05 - y)
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        let sublayer = CAShapeLayer()
        sublayer.cornerCurve = .continuous

        let mid = frame.width / 2
        sublayer.path = CGPath(
            roundedRect: CGRect(
                x: mid - 30, y: frame.height * ((h + y) - hh),
                width: 60,
                height: frame.height * hh
            ),
            cornerWidth: 3,
            cornerHeight: 3,
            transform: nil
        )

        if darkMode {
            sublayer.fillColor = screenColor.shadow(withLevel: 0.2)!.cgColor
        } else {
            sublayer.fillColor = screenColor.highlight(withLevel: 0.2)!.cgColor
        }

        layer.addSublayer(sublayer)
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
        if isMacBook {
            let perspective: CGFloat = 30
            layer = screenLayer(perspective: perspective)
            layer?.addSublayer(macbookLayer(perspective: perspective))
        } else if isSidecar {
            layer = screenLayer(perspective: 30)
        } else {
            layer = screenLayer()
            layer?.addSublayer(standLayer())
        }
    }
}

// MARK: - DisplayViewController

class DisplayViewController: NSViewController {
    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif

        for observer in displayObservers.values {
            observer.cancel()
        }
    }

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
    @IBOutlet var softwareBrightnessSlider: Slider?
    @IBOutlet var resolutionsDropdown: ModePopupButton?
    @IBOutlet var inputDropdown: NSPopUpButton?

    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView?

    @IBOutlet var cornerRadiusField: ScrollableTextField?
    @IBOutlet var cornerRadiusFieldCaption: ScrollableTextFieldCaption?

    @IBOutlet var minBrightnessField: ScrollableTextField?
    @IBOutlet var minBrightnessFieldCaption: ScrollableTextFieldCaption?

    @IBOutlet var maxBrightnessField: ScrollableTextField?
    @IBOutlet var maxBrightnessFieldCaption: ScrollableTextFieldCaption?

    @IBOutlet var _controlsButton: NSButton!
    @IBOutlet var _softwareDimmingButton: NSButton!
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
        .systemAdaptiveBrightness || displayController
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
    var openedXDRPage = false

    var gammaNoticeHighlighterTask: Repeater?

    var buttonY: CGFloat?
    var resolutionsY: CGFloat?

    var deleteButtonY: CGFloat?
    var powerButtonY: CGFloat?
    var syncSourceButtonY: CGFloat?
    var offTextY: CGFloat?

    let topButtonsMacBookOffset: CGFloat = -13
    var cornerRadiusFieldY: CGFloat?
    var cornerRadiusFieldCaptionY: CGFloat?

    @IBOutlet var brightnessSliderImage: ClickThroughImageView?

    @IBOutlet var advancedSettingsButton: LockButton? {
        didSet {
            guard let b = advancedSettingsButton else { return }
            b.monospaced = true
        }
    }

    @IBOutlet var notchButton: LockButton! { didSet {
        guard let notchButton else { return }
        notchButton.layer?.cornerCurve = .continuous
        notchButton.layer?.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
    }}

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

    var softwareDimmingButton: HelpButton? {
        _softwareDimmingButton as? HelpButton
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
            if let display {
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

    @IBOutlet var deleteButton: Button! {
        didSet {
            guard let deleteButton, let display else { return }
            let f = deleteButton.frame
            if deleteButtonY == nil { deleteButtonY = f.origin.y }

            guard let deleteButtonY else { return }
            deleteButton
                .setFrameOrigin(NSPoint(
                    x: f.origin.x,
                    y: deleteButtonY + ((display.isMacBook || display.isSidecar) ? topButtonsMacBookOffset : 0)
                ))
        }
    }

    @IBOutlet var powerButton: Button! {
        didSet {
            guard let powerButton, let display else { return }
            let f = powerButton.frame
            if powerButtonY == nil { powerButtonY = f.origin.y }

            guard let powerButtonY else { return }
            powerButton
                .setFrameOrigin(NSPoint(
                    x: f.origin.x,
                    y: powerButtonY + ((display.isMacBook || display.isSidecar) ? topButtonsMacBookOffset : 0)
                ))
        }
    }

    @IBOutlet var syncSourceButton: LockButton! {
        didSet {
            guard let syncSourceButton, let display else { return }
            let f = syncSourceButton.frame
            if syncSourceButtonY == nil { syncSourceButtonY = f.origin.y }

            guard let syncSourceButtonY else { return }
            syncSourceButton
                .setFrameOrigin(NSPoint(
                    x: f.origin.x,
                    y: syncSourceButtonY + ((display.isMacBook || display.isSidecar) ? topButtonsMacBookOffset : 0)
                ))
        }
    }

    @IBOutlet var offText: NSTextField! {
        didSet {
            guard let offText, let display else { return }
            let f = offText.frame
            if offTextY == nil { offTextY = f.origin.y }

            guard let offTextY else { return }
            offText
                .setFrameOrigin(NSPoint(
                    x: f.origin.x,
                    y: offTextY + ((display.isMacBook || display.isSidecar) ? topButtonsMacBookOffset : 0)
                ))
        }
    }

    func placeAddScheduleButton() {
        guard let addScheduleButton,
              let schedule2,
              let schedule3,
              let schedule4,
              let schedule5
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
            guard let self else { return }
            self.view.setNeedsDisplay(self.view.visibleRect)
        }
    }

    @discardableResult
    func initHotkeys() -> Bool {
        guard let button = inputDropdownHotkeyButton, let display, !display.isBuiltin, display.hotkeyPopoverController != nil
        else {
            if let button = inputDropdownHotkeyButton {
                button.onClick = { [weak self] in
                    guard let self else { return }
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
        guard let display, brightnessContrastChart != nil, display.id != GENERIC_DISPLAY_ID else { return }
        initGraph()
    }

    @objc func highlightChartValue(notification _: Notification) {
        guard CachedDefaults[.moreGraphData], let display, let brightnessContrastChart,
              display.id != GENERIC_DISPLAY_ID else { return }
        brightnessContrastChart.highlightCurrentValues(adaptiveMode: displayController.adaptiveMode, for: display)
    }

    @objc func adaptToUserDataPoint(notification: Notification) {
        guard displayController.adaptiveModeKey != .manual, displayController.adaptiveModeKey != .clock,
              let values = notification.userInfo?["values"] as? [Double: Double]
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
            NSWorkspace.shared.open("https://lunar.fyi/pro".asURL()!)
        } else if let paddle, let lunarProProduct {
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
            guard let self else { return }
            guard let button = self.proButton else { return }

            let width = button.frame.width
            if lunarProActive {
                button.bg = red
                button.attributedTitle = "Pro".withAttribute(.textColor(white))
                button.setFrameSize(NSSize(width: 50, height: button.frame.height))
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

    func styleButton(_ button: PopoverButton<some Any>, icon: String, display: Display) {
        if buttonY == nil { buttonY = button.frame.origin.y }

        let color = NSColor(named: "Caption Tertiary")!
        let symbol = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)

        button.textColor = color
        button.contentTintColor = color
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?.withSymbolConfiguration(symbol)
        if let buttonY {
            let f = button.frame
            button.setFrameOrigin(NSPoint(x: f.origin.x, y: buttonY + (display.isMacBook ? -26 : 0)))
        }
    }

    func update(_ display: Display? = nil) {
        guard let display = display ?? self.display else { return }

        if let resolutionsDropdown {
            resolutionsDropdown.setItemStyles()
        }
        if let inputDropdown {
            for item in inputDropdown.itemArray {
                item.attributedTitle = item.title.withFont(.monospacedSystemFont(ofSize: 12, weight: .semibold)).withTextColor(.labelColor)
            }
        }

        display.withoutDDC { display.panelMode = display.panel?.currentMode }
        displayImage?.cornerRadius = CGFloat(display.cornerRadius.floatValue)
        displayImage?.isMacBook = display.isMacBook
        displayImage?.isSidecar = display.isSidecar

        if let cornerRadiusField {
            cornerRadiusField.isHidden = display.isSidecar
            cornerRadiusFieldCaption?.isHidden = display.isSidecar

            cornerRadiusField.textFieldColor = display.isMacBook ? NSColor(named: "Caption Tertiary")! : violet
            cornerRadiusField.textFieldColorHover = cornerRadiusField.textFieldColor.highlight(withLevel: 0.2)!
            cornerRadiusField.textFieldColorLight = cornerRadiusField.textFieldColor.blended(withFraction: 0.2, of: red)!
            cornerRadiusField.editingTextFieldColor = cornerRadiusField.textFieldColor
            cornerRadiusField.textFieldColor = cornerRadiusField.textFieldColor.withAlphaComponent(0.0)

            if cornerRadiusFieldY == nil { cornerRadiusFieldY = cornerRadiusField.frame.origin.y }
            if cornerRadiusFieldCaptionY == nil { cornerRadiusFieldCaptionY = cornerRadiusFieldCaption?.frame.origin.y }
            if let cornerRadiusFieldY {
                cornerRadiusField
                    .setFrameOrigin(NSPoint(x: cornerRadiusField.frame.origin.x, y: cornerRadiusFieldY + (display.isMacBook ? -42 : 0)))
            }
            if let cornerRadiusFieldCaptionY, let cornerRadiusFieldCaption {
                cornerRadiusFieldCaption
                    .setFrameOrigin(NSPoint(
                        x: cornerRadiusFieldCaption.frame.origin.x,
                        y: cornerRadiusFieldCaptionY + (display.isMacBook ? -42 : 0)
                    ))
            }
        }
        cornerRadiusField?.didScrollTextField = true
        cornerRadiusField?.integerValue = display.cornerRadius.intValue
        cornerRadiusField?.onValueChangedInstant = { [weak self] value in
            mainAsync {
                self?.displayImage?.cornerRadius = CGFloat(value)
                self?.display?.cornerRadius = value.ns
            }
        }
        cornerRadiusField?.onMouseEnter = { [weak self] in
            guard let self else { return }
            self.cornerRadiusFieldCaption?.transition(1.5, easing: .easeInEaseOut)
            self.cornerRadiusFieldCaption?.textColor = self.cornerRadiusField?.textColor
            self.cornerRadiusFieldCaption?.alphaValue = 0.8
        }
        cornerRadiusField?.onMouseExit = { [weak self] in
            guard let self, let f = self.cornerRadiusField, !f.editing else { return }
            self.cornerRadiusFieldCaption?.transition(1)
            self.cornerRadiusFieldCaption?.alphaValue = 0.0
        }

        cornerRadiusField?.onEditStateChange = { [weak self] editing in
            if editing {
                self?.cornerRadiusField?.onMouseEnter?()
            } else {
                self?.cornerRadiusField?.onMouseExit?()
            }
        }

        if let resolutionsDropdown {
            if resolutionsY == nil { resolutionsY = resolutionsDropdown.frame.origin.y }
            if let resolutionsY {
                let f = resolutionsDropdown.frame
                resolutionsDropdown.setFrameOrigin(NSPoint(x: f.origin.x, y: resolutionsY + (display.isMacBook ? 40 : 0)))
            }
        }

        deleteEnabled = getDeleteEnabled(display: display)
        powerOffEnabled = getPowerOffEnabled(display: display)
        powerOffTooltip = getPowerOffTooltip(display: display)
        chartHidden = noDisplay || display.systemAdaptiveBrightness || displayController.adaptiveModeKey == .clock

        if let button = colorsButton {
            button.display = display
            styleButton(button, icon: "paintpalette", display: display)
        }
        if let button = ddcButton {
            button.display = display
            styleButton(button, icon: "display", display: display)
        }
        if let button = settingsButton {
            button.display = display
            button.displayViewController = self
            button.notice = adaptiveNotice
            styleButton(button, icon: "gear", display: display)
        }
        if let button = resetButton {
            button.display = display
            button.displayViewController = self
            styleButton(button, icon: "clock.arrow.circlepath", display: display)
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
            guard let self else { return }
            self.updateDataset(brightnessFactor: factor)
        }

        display.onContrastCurveFactorChange = { [weak self] factor in
            guard let self else { return }
            self.updateDataset(contrastFactor: factor)
        }

        minBrightnessField?.integerValue = display.minBrightness.intValue
        minBrightnessField?.lowerLimit = display.allowBrightnessZero ? 0 : 1
        minBrightnessField?.upperLimit = (display.maxBrightness.intValue - 1).d

        maxBrightnessField?.integerValue = display.maxBrightness.intValue
        maxBrightnessField?.lowerLimit = (display.minBrightness.intValue + 1).d

        minBrightnessField?.onValueChangedInstant = { [weak self] (value: Int) in
            guard let self, let display = self.display else { return }

            self.updateDataset(minBrightness: value.u16)
            display.minBrightness = value.ns
        }
        minBrightnessField?.onValueChanged = { [weak self] (value: Int) in
            guard let self, let display = self.display else { return }

            self.updateDataset(minBrightness: value.u16)
            display.minBrightness = value.ns
        }
        maxBrightnessField?.onValueChangedInstant = { [weak self] (value: Int) in
            guard let self, let display = self.display else { return }

            self.updateDataset(maxBrightness: value.u16)
            display.maxBrightness = value.ns
        }
        maxBrightnessField?.onValueChanged = { [weak self] (value: Int) in
            guard let self, let display = self.display else { return }

            self.updateDataset(maxBrightness: value.u16)
            display.maxBrightness = value.ns
        }

        scrollableBrightness?.onCurrentValueChanged = { [weak self] brightness in
            guard let self, let display = self.display,
                  displayController.adaptiveModeKey != .manual, displayController.adaptiveModeKey != .clock,
                  !display.lockedBrightnessCurve
            else {
                self?.updateDataset(currentBrightness: brightness.u16)
                return
            }
            cancelScreenWakeAdapterTask()

            let lastDataPoint = datapointLock.around { displayController.adaptiveMode.brightnessDataPoint.last }
            display.insertBrightnessUserDataPoint(lastDataPoint, brightness.d, modeKey: displayController.adaptiveModeKey)

            let userValues = display.userBrightness[displayController.adaptiveModeKey] ?? ThreadSafeDictionary()
            self.updateDataset(currentBrightness: brightness.u16, userBrightness: userValues.dictionary)
        }
        scrollableContrast?.onCurrentValueChanged = { [weak self] contrast in
            guard let self, let display = self.display,
                  displayController.adaptiveModeKey != .manual, displayController.adaptiveModeKey != .clock,
                  !display.lockedContrastCurve
            else {
                self?.updateDataset(currentContrast: contrast.u16)
                return
            }

            let lastDataPoint = displayController.adaptiveMode.contrastDataPoint.last
            display.insertContrastUserDataPoint(lastDataPoint, contrast.d, modeKey: displayController.adaptiveModeKey)

            let userValues = display.userContrast[displayController.adaptiveModeKey] ?? ThreadSafeDictionary()
            self.updateDataset(currentContrast: contrast.u16, userContrast: userValues.dictionary)
        }

        display.onControlChange = { [weak self] control in
            mainAsyncAfter(ms: 10) { [weak self] in
                guard let self else { return }
                self.updateControlsButton(control: control)
                if control.isSoftware, display.enabledControls[.gamma] ?? false {
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

    override func viewDidAppear() {
        if let resolutionsDropdown {
            resolutionsDropdown.setItemStyles()
        }
        updateControlsButton()
    }

    func setDisconnected() {
        guard let button = controlsButton else { return }
        button.bg = darkMode ? gray.withAlphaComponent(0.6) : gray.withAlphaComponent(0.9)
        button.attributedTitle = "Disconnected".withAttribute(.textColor(.darkGray))
        button.helpText = "This display is not connected to your Mac."
    }

    func updateControlsButton(control: Control? = nil) {
        mainAsync { [weak self] in
            guard let self else { return }
            guard let button = self.controlsButton,
                  let softwareDimmingButton = self.softwareDimmingButton,
                  let display = self.display
            else {
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
            button.shadowAlpha = 0.0
            button.identifier = NSUserInterfaceItemIdentifier("ControlsButton")
            button.onClick = nil

            softwareDimmingButton.alpha = 0.85
            softwareDimmingButton.hoverAlpha = 1.0
            softwareDimmingButton.shadowAlpha = 0.0
            softwareDimmingButton.identifier = NSUserInterfaceItemIdentifier("SoftwareDimmingButton")
            softwareDimmingButton.onClick = nil
            softwareDimmingButton.attributedTitle = "".attributedString
            softwareDimmingButton.isHidden = true
            softwareDimmingButton.isEnabled = false

            if let brightnessSliderImage = self.brightnessSliderImage {
                brightnessSliderImage.contentFilters = brightnessSliderImage.contentFilters.filter { $0.name != "CIColorInvert" }
            }
            switch control {
            case is AppleNativeControl:
                if display.isMacBook {
                    button.bg = NSColor.black.blended(withFraction: 0.6, of: macbookScreenColor)
                    button.attributedTitle = "Apple Native".withAttribute(.textColor(white))
                    button.helpText = NATIVE_CONTROLS_BUILTIN_HELP_TEXT
                    if let brightnessSliderImage = self.brightnessSliderImage {
                        brightnessSliderImage.contentFilters += [CIFilter(name: "CIColorInvert")!]
                    }
                } else {
                    button.bg = green
                    button.attributedTitle = "Apple Native".withAttribute(.textColor(mauve))
                    button.helpText = NATIVE_CONTROLS_HELP_TEXT
                }
                button.showPopover = true
            case is DDCControl:
                button.transition(0.2)
                button.bg = darkMode ? peach : lunarYellow
                button.attributedTitle = "Hardware DDC".withAttribute(.textColor(darkMauve))
                button.helpText = HARDWARE_CONTROLS_HELP_TEXT
                button.alpha = 1.0
                button.shadowAlpha = 1.0
                button.showPopover = true
                button.layer?.setAffineTransform(.init(scaleX: 1.0, y: 1.0))

                softwareDimmingButton.transition(0.2)
                softwareDimmingButton.bg = darkMode ? peach.blended(withFraction: 0.7, of: red) : red
                softwareDimmingButton.attributedTitle = "Software Dimming".withAttribute(.textColor(.white))
                softwareDimmingButton.alpha = 0.4
                softwareDimmingButton.shadowAlpha = 0.0
                softwareDimmingButton.isHidden = false
                softwareDimmingButton.isEnabled = true
                softwareDimmingButton.showPopover = false
                softwareDimmingButton.layer?.setAffineTransform(.init(scaleX: 0.9, y: 0.9).translatedBy(x: softwareDimmingButton.frame.width * 0.05, y: 0))
                softwareDimmingButton.onClick = { [weak self] in
                    guard let display = self?.display else { return }
                    display.networkEnabled = false
                    display.ddcEnabled = false
                    display.gammaEnabled = true
                    display.control = display.getBestControl(reapply: true)
                }
                self.view.bringSubviewToFront(button)
            case is GammaControl where display.enabledControls[.gamma] ?? false:
                #if arch(arm64)
                    let hasI2C = DDC.hasAVService(displayID: display.id, ignoreCache: true)
                #else
                    let hasI2C = DDC.hasI2CController(displayID: display.id, ignoreCache: true)
                #endif

                if hasI2C || display.isForTesting {
                    button.transition(0.2)
                    button.bg = (darkMode ? peach : lunarYellow)
                    button.attributedTitle = "Hardware DDC".withAttribute(.textColor(darkMauve))
                    button.helpText = HARDWARE_CONTROLS_HELP_TEXT
                    button.shadowAlpha = 0.0
                    button.alpha = 0.4
                    button.showPopover = false
                    button.layer?.setAffineTransform(.init(scaleX: 0.9, y: 0.9).translatedBy(x: button.frame.width * 0.05, y: 0))
                    button.onClick = { [weak self] in
                        guard let display = self?.display else { return }
                        display.ddcEnabled = true
                        display.control = display.getBestControl(reapply: true)
                    }

                    softwareDimmingButton.transition(0.2)
                    softwareDimmingButton.bg = (darkMode ? peach.blended(withFraction: 0.7, of: red) : red)
                    softwareDimmingButton.attributedTitle = "Software Dimming".withAttribute(.textColor(darkMauve))
                    softwareDimmingButton.alpha = 1.0
                    softwareDimmingButton.shadowAlpha = 1.0
                    softwareDimmingButton.isHidden = false
                    softwareDimmingButton.isEnabled = true
                    softwareDimmingButton.showPopover = true
                    softwareDimmingButton.layer?.setAffineTransform(.init(scaleX: 1.0, y: 1.0))
                    softwareDimmingButton.helpText = display
                        .supportsGamma ? SOFTWARE_CONTROLS_FORCED_HELP_TEXT : SOFTWARE_OVERLAY_FORCED_HELP_TEXT
                    self.view.bringSubviewToFront(softwareDimmingButton)
                } else {
                    button.bg = darkMode ? peach.blended(withFraction: 0.7, of: red) : red.withAlphaComponent(0.9)
                    if display.supportsGamma {
                        button.attributedTitle = "Software Gamma".withAttribute(.textColor(.black))
                        button.helpText = SOFTWARE_CONTROLS_HELP_TEXT
                    } else {
                        button.attributedTitle = "Software Overlay".withAttribute(.textColor(.black))
                        button.helpText = SOFTWARE_OVERLAY_HELP_TEXT
                    }
                    button.showPopover = true
                }

            case is NetworkControl:
                button.bg = darkMode ? blue.highlight(withLevel: 0.2) : blue.withAlphaComponent(0.9)
                button.attributedTitle = "Network Pi".withAttribute(.textColor(.black))
                button.helpText = NETWORK_CONTROLS_HELP_TEXT
                button.showPopover = true
            default:
                button.bg = darkMode ? gray.withAlphaComponent(0.6) : gray.withAlphaComponent(0.9)
                button.attributedTitle = "No Controls".withAttribute(.textColor(.darkGray))
                button.helpText = NO_CONTROLS_HELP_TEXT
                button.showPopover = true
            }

            if control is GammaControl, display.enabledControls[.gamma] ?? false {
                self.brightnessSlider?.color = darkMode ? peach.blended(withFraction: 0.7, of: red) ?? peach : red
                self.brightnessContrastSlider?.color = darkMode ? peach.blended(withFraction: 0.7, of: red) ?? peach : red
                self.softwareBrightnessSlider?.color = subzeroColor
            } else {
                self.brightnessSlider?.color = button.bg!
                self.brightnessContrastSlider?.color = button.bg!
                self.softwareBrightnessSlider?.color = subzeroColor
            }
        }
    }

    func updateDataset(
        minBrightness: UInt16? = nil,
        maxBrightness: UInt16? = nil,
        minContrast: UInt16? = nil,
        maxContrast: UInt16? = nil,
        currentBrightness: UInt16? = nil,
        currentContrast: UInt16? = nil,
        brightnessFactor: Double? = nil,
        contrastFactor: Double? = nil,
        userBrightness: [Double: Double]? = nil,
        userContrast: [Double: Double]? = nil,
        force: Bool = false
    ) {
        guard let display, let brightnessContrastChart, display.id != GENERIC_DISPLAY_ID
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
        guard let display else { return }
        display.resetDDC()
    }

    @objc func resetBlackOut() {
        guard let display else { return }
        display.resetBlackOut()
    }

    @objc func resetNetworkController() {
        guard let display else { return }
        display.resetNetworkController()
    }

    @objc func resetAlgorithmCurve() {
        guard let display else {
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
        guard let display else {
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
        guard let display else { return }

        let resetHandler = { [weak self] (shouldReset: Bool) in
            guard shouldReset, let display = self?.display, let self else { return }
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

        if display.hasSoftwareControl {
            guard ask(message: "Monitor Reset", info: """
            This will reset the following settings for this display:

            * The *algorithm curve* that Lunar learned from your adjustments
            * The checkboxes for enabled controls
            * The *"Always Use Network Control"* setting
            * The *"Always Fallback to Gamma"* setting
            * The min/max brightness/contrast values
            """, okButton: "Ok", cancelButton: "Cancel", window: view.window, onCompletion: resetHandler, wide: true, markdown: true)
            else { return }
        } else {
            guard ask(message: "Monitor Reset", info: """
            This will reset the following settings for this display:

            * Everything you have manually adjusted using the monitor's physical buttons/controls
            * The *algorithm curve* that Lunar learned from your adjustments
            * The checkboxes for enabled controls
            * The *"Always Use Network Control"* setting
            * The *"Always Fallback to Gamma"* setting
            * The min/max brightness/contrast values
            """, okButton: "Ok", cancelButton: "Cancel", window: view.window, onCompletion: resetHandler, wide: true, markdown: true)
            else { return }
        }
        if view.window == nil {
            resetHandler(true)
        }
    }

    func listenForSendingBrightnessContrast() {
        display?.$sendingBrightness
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] newValue in
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
        display?.$sendingContrast
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] newValue in
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
        display?.$maxBrightness
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] value in
                guard let self else { return }
                // self.scrollableBrightness?.maxValue.integerValue = value.intValue
                // self.scrollableBrightness?.minValue.upperLimit = value.doubleValue - 1

                self.maxBrightnessField?.integerValue = value.intValue
                self.minBrightnessField?.upperLimit = value.doubleValue - 1
            }.store(in: &displayObservers, for: "maxBrightness")
        // display?.$maxContrast
        //     .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
        //     .sink { [weak self] value in
        //         guard let self = self else { return }
        //         self.scrollableContrast?.maxValue.integerValue = value.intValue
        //         self.scrollableContrast?.minValue.upperLimit = value.doubleValue - 1
        //     }.store(in: &displayObservers, for: "maxContrast")

        display?.$minBrightness
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] value in
                guard let self else { return }
                // self.scrollableBrightness?.minValue.integerValue = value.intValue
                // self.scrollableBrightness?.maxValue.lowerLimit = value.doubleValue + 1

                self.minBrightnessField?.integerValue = value.intValue
                self.maxBrightnessField?.lowerLimit = value.doubleValue + 1
            }.store(in: &displayObservers, for: "minBrightness")
        // display?.$minContrast
        //     .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
        //     .sink { [weak self] value in
        //         guard let self = self else { return }
        //         self.scrollableContrast?.minValue.integerValue = value.intValue
        //         self.scrollableContrast?.maxValue.lowerLimit = value.doubleValue + 1
        //     }.store(in: &displayObservers, for: "minContrast")

        // display?.$brightness
        //     .throttle(for: .milliseconds(50), scheduler: DDC.queue, latest: true)
        //     .sink { [weak self] value in
        //         guard let self = self else { return }
        //         mainAsync { self.scrollableBrightness?.currentValue.integerValue = value.intValue }
        //     }.store(in: &displayObservers, for: "brightness")
        // display?.$contrast
        //     .throttle(for: .milliseconds(50), scheduler: DDC.queue, latest: true)
        //     .sink { [weak self] value in
        //         guard let self = self else { return }
        //         mainAsync { self.scrollableContrast?.currentValue.integerValue = value.intValue }
        //     }.store(in: &displayObservers, for: "contrast")
        display?.$allowBrightnessZero
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] value in
                self?.minBrightnessField?.lowerLimit = value ? 0 : 1
            }.store(in: &displayObservers, for: "allowBrightnessZero")
    }

    func listenForDisplayBoolChange() {
        guard let display else { return }
        display.$hasDDC
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] hasDDC in
                guard let self else { return }

                self.powerOffEnabled = self.getPowerOffEnabled(hasDDC: hasDDC)
                self.powerOffTooltip = self.getPowerOffTooltip(hasDDC: hasDDC)
            }.store(in: &displayObservers, for: "hasDDC")

        if !display.adaptive, !display.systemAdaptiveBrightness {
            showAdaptiveNotice()
        }
        display.$adaptive
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] newAdaptive in
                guard let self else { return }
                guard let display = self.display else {
                    self.hideAdaptiveNotice()
                    return
                }
                self.chartHidden = self.noDisplay || self.display!.systemAdaptiveBrightness || displayController
                    .adaptiveModeKey == .clock

                if !newAdaptive, !display.systemAdaptiveBrightness {
                    self.showAdaptiveNotice()
                } else {
                    self.hideAdaptiveNotice()
                }
            }.store(in: &displayObservers, for: "adaptive")
    }

    func listenForGraphDataChange() {
        graphObserver = moreGraphDataPublisher.sink { [weak self] change in
            log.debug("More graph data: \(change.newValue)")
            guard let self else { return }
            mainAsyncAfter(ms: 1000) { [weak self] in
                guard let self else { return }
                self.initGraph()
            }
        }
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = adaptiveBrightnessModePublisher.sink { [weak self] change in
            mainAsync {
                guard let self, !self.pausedAdaptiveModeObserver else { return }
                self.pausedAdaptiveModeObserver = true

                self.chartHidden = self.display == nil || self.noDisplay || self.display!.systemAdaptiveBrightness || change
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
        return display.getPowerOffEnabled(hasDDC: hasDDC)
    }

    func getPowerOffTooltip(display: Display? = nil, hasDDC: Bool? = nil) -> String? {
        guard let display = display ?? self.display else { return nil }
        return display.getPowerOffTooltip(hasDDC: hasDDC)
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

    @IBAction func xdrBrightness(_: Any) {
        guard lunarProOnTrial || lunarProActive || openedXDRPage else {
            openedXDRPage = true
            if let url = URL(string: "https://lunar.fyi/#xdr") {
                NSWorkspace.shared.open(url)
            }
            return
        }
    }

    @IBAction func powerOff(_: Any) {
        guard let display else { return }
        display.powerOff()
    }

    func showGammaNotice() {
        mainAsync { [weak self] in
            guard let self, self.display?.active ?? false, self.view.window?.isVisible ?? false,
                  self.gammaNoticeHighlighterTask == nil
            else { return }

            self.gammaNoticeHighlighterTask = Repeater(
                every: 5,
                name: "gammaNoticeHighlighter-\(self.display?.serial ?? "display")"
            ) { [weak self] in
                guard let self else { return }

                guard self.view.window?.isVisible ?? false, let gammaNotice = self.gammaNotice
                else {
                    self.gammaNoticeHighlighterTask = nil
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
            guard let self else { return }
            self.gammaNoticeHighlighterTask = nil

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

        if let display, display.id != GENERIC_DISPLAY_ID {
            update()

            scrollableBrightness?.label.textColor = scrollableViewLabelColor
            scrollableContrast?.label.textColor = scrollableViewLabelColor

            scrollableBrightness?.onMinValueChanged = { [weak self] (value: Int) in self?.updateDataset(minBrightness: value.u16) }
            scrollableBrightness?.onMaxValueChanged = { [weak self] (value: Int) in self?.updateDataset(maxBrightness: value.u16) }
            scrollableContrast?.onMinValueChanged = { [weak self] (value: Int) in self?.updateDataset(minContrast: value.u16) }
            scrollableContrast?.onMaxValueChanged = { [weak self] (value: Int) in self?.updateDataset(maxContrast: value.u16) }

            initGraph()
        }

        deleteEnabled = getDeleteEnabled()
        powerOffEnabled = getPowerOffEnabled()
        powerOffTooltip = getPowerOffTooltip()
    }
}
