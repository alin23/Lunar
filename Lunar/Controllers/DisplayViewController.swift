//
//  DisplayViewController.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Charts
import Cocoa
import Defaults
import Magnet
import Sauce

class DisplayViewController: NSViewController {
    let ADAPTIVE_HELP_TEXT = """
    ## Description

    This setting allows the user to **disable** the adaptive algorithm on a **per-monitor** basis.

    - `ADAPTIVE` will **allow** Lunar to change the brightness and contrast automatically for this monitor
    - `MANUAL` will **restrict** Lunar from changing the brightness and contrast automatically for this monitor
    """
    let BRIGHTNESS_RANGE_HELP_TEXT = """
    ## Description

    This setting allows the user to change the brightness range for the monitor.
    Some monitors will have an extended brightness range with values up to 255 instead of the standard 100.

    If you notice Lunar's 100% doesn't map to your monitor's 100% you might benefit from enabling the extended range by clicking on this button.

    - `Normal range` will map Lunar's 100% brightness value to the monitor's 100 value
    - `Extended range` will map Lunar's 100% brightness value to the monitor's 255 value and interpolate the value between 0 and 255
    """
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

    @IBOutlet var displayView: DisplayView?
    @IBOutlet var displayName: DisplayName?
    @IBOutlet var algorithmButton: ToggleButton?
    @IBOutlet var inputDropdownText: NSTextField?
    @IBOutlet var _inputDropdownHotkeyButton: NSButton? {
        didSet {
            guard let display = display, let button = inputDropdownHotkeyButton, initHotkeys(from: display) else { return }

            button.onClick = { [weak self] in
                guard let self = self else { return }
                if self.initHotkeys(from: display) {
                    button.onClick = nil
                }
            }
        }
    }

    var inputDropdownHotkeyButton: HotkeyButton? {
        _inputDropdownHotkeyButton as? HotkeyButton
    }

    @IBOutlet var inputDropdown: NSPopUpButton? {
        didSet {
            if let display = display, let input = InputSource(rawValue: display.input.uint8Value) {
                inputDropdown?.selectItem(withTag: Int(input.rawValue))
            }
        }
    }

    @IBOutlet var brightnessRangeButton: ToggleButton?
    @IBOutlet var algorithmText: NSTextField?
    @IBOutlet var brightnessRangeText: NSTextField?

    @IBOutlet var scrollableBrightness: ScrollableBrightness?
    @IBOutlet var scrollableContrast: ScrollableContrast?

    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView?

    @IBOutlet var swipeLeftHint: NSTextField?
    @IBOutlet var swipeRightHint: NSTextField?

    @IBOutlet var _adaptiveHelpButton: NSButton?
    var adaptiveHelpButton: HelpButton? {
        _adaptiveHelpButton as? HelpButton
    }

    @IBOutlet var _brightnessRangeHelpButton: NSButton?
    var brightnessRangeHelpButton: HelpButton? {
        _brightnessRangeHelpButton as? HelpButton
    }

    @IBOutlet var nonResponsiveDDCTextField: NonResponsiveDDCTextField? {
        didSet {
            if let d = display {
                nonResponsiveDDCTextField?.isHidden = d.id == GENERIC_DISPLAY_ID
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

    @objc dynamic weak var display: Display? {
        didSet {
            if let display = display {
                update(from: display)
                noDisplay = display.id == GENERIC_DISPLAY_ID
            }
        }
    }

    @objc dynamic var noDisplay: Bool = false

    var adaptiveModeObserver: DefaultsObservation?
    var adaptiveObserver: ((Bool, Bool) -> Void)?
    var brightnessRangeObserver: ((Bool, Bool) -> Void)?
    var activeAndResponsiveObserver: ((Bool, Bool) -> Void)?
    var showNavigationHintsObserver: DefaultsObservation?
    var viewID: String?

    func setAdaptiveButtonEnabled(_ enabled: Bool) {
        guard let adaptiveButton = algorithmButton else { return }

        adaptiveButton.isEnabled = enabled
        adaptiveHelpButton?.isEnabled = enabled
    }

    override func mouseDown(with ev: NSEvent) {
        if let editor = displayName?.currentEditor() {
            editor.selectedRange = NSMakeRange(0, 0)
            displayName?.abortEditing()
        }
        super.mouseDown(with: ev)
    }

    func setButtonsHidden(_ hidden: Bool) {
        algorithmButton?.isHidden = hidden
        adaptiveHelpButton?.isHidden = hidden
        algorithmText?.isHidden = hidden

        brightnessRangeButton?.isHidden = hidden
        brightnessRangeHelpButton?.isHidden = hidden
        brightnessRangeText?.isHidden = hidden

        inputDropdown?.isHidden = hidden
        inputDropdownText?.isHidden = hidden
        inputDropdownHotkeyButton?.isHidden = hidden
    }

    func refreshView() {
        view.setNeedsDisplay(view.visibleRect)
    }

    func initHotkeys(from display: Display) -> Bool {
        guard let controller = inputDropdownHotkeyButton?.popoverController else {
            return false
        }

        controller.onDropdownSelect = { [unowned display] dropdown in
            guard let input = InputSource(rawValue: UInt8(dropdown.selectedTag())) else { return }
            display.hotkeyInput = NSNumber(value: input.rawValue)
        }
        controller.dropdown.removeAllItems()
        controller.dropdown
            .addItems(
                withTitles: InputSource.allCases
                    .map { input in input.displayName() }
            )
        for item in controller.dropdown.itemArray {
            guard let input = inputSourceMapping[item.title] else { continue }
            item.tag = Int(input.rawValue)

            if input == .unknown {
                item.isEnabled = false
                item.isHidden = true
            }
        }
        controller.dropdown.selectItem(withTag: display.hotkeyInput.intValue)

        let identifier = "toggle-last-input-\(display.serial)"
        let handler = { [weak display] (_: HotKey) -> Void in
            guard let display = display, display.hotkeyInput.uint8Value != InputSource.unknown.rawValue else { return }
            display.input = display.hotkeyInput
        }
        var hotkey: PersistentHotkey
        if let hk = Defaults[.hotkeys][identifier],
           let keyCode = hk[.keyCode],
           let enabled = hk[.enabled],
           let modifiers = hk[.modifiers], let keyCombo = KeyCombo(QWERTYKeyCode: keyCode, carbonModifiers: modifiers)
        {
            hotkey = PersistentHotkey(hotkey: Magnet.HotKey(
                identifier: identifier,
                keyCombo: keyCombo,
                handler: handler
            ), isEnabled: enabled == 1)

        } else {
            hotkey = PersistentHotkey(
                hotkey: Magnet
                    .HotKey(
                        identifier: identifier,
                        keyCombo: KeyCombo(key: .zero, cocoaModifiers: [.control, .option])!,
                        handler: handler
                    ),
                isEnabled: false
            )
        }
        if let hotkeyView = controller.hotkeyView {
            hotkeyView.hotkey = hotkey
            hotkeyView.endRecording()
        }
        return true
    }

    func update(from display: Display) {
        if let input = InputSource(rawValue: display.input.uint8Value) {
            inputDropdown?.selectItem(withTag: Int(input.rawValue))
        }
        if !initHotkeys(from: display), let button = inputDropdownHotkeyButton {
            button.onClick = { [weak self] in
                guard let self = self else { return }
                if self.initHotkeys(from: display) {
                    button.onClick = nil
                }
            }
        }

        if display.id == GENERIC_DISPLAY_ID {
            displayName?.stringValue = "No Display"
            displayName?.display = nil
        } else {
            displayName?.stringValue = display.name
            displayName?.display = display
            nonResponsiveDDCTextField?.onClick = { [weak self] in
                runInMainThread { [weak self] in
                    DDC.skipWritingPropertyById[display.id]?.removeAll()
                    DDC.skipReadingPropertyById[display.id]?.removeAll()
                    DDC.writeFaults[display.id]?.removeAll()
                    DDC.readFaults[display.id]?.removeAll()
                    display.responsive = true
                    self?.setButtonsHidden(display.id == GENERIC_DISPLAY_ID)
                    self?.setAdaptiveButtonEnabled(brightnessAdapter.mode != .manual)
                    self?.refreshView()
                }
            }
        }

        if display.adaptive {
            algorithmButton?.state = .on
        } else {
            algorithmButton?.state = .off
        }
        if display.extendedBrightnessRange {
            brightnessRangeButton?.state = .on
        } else {
            brightnessRangeButton?.state = .off
        }

        setButtonsHidden(display.id == GENERIC_DISPLAY_ID)
        setAdaptiveButtonEnabled(brightnessAdapter.mode != .manual)
        refreshView()
    }

    func updateDataset(
        minBrightness: UInt8? = nil,
        maxBrightness: UInt8? = nil,
        minContrast: UInt8? = nil,
        maxContrast: UInt8? = nil,
        factor: Double? = nil
    ) {
        guard let display = display, let brightnessContrastChart = brightnessContrastChart, display.id != GENERIC_DISPLAY_ID else { return }

        let brightnessChartEntry = brightnessContrastChart.brightnessGraph.entries
        let contrastChartEntry = brightnessContrastChart.contrastGraph.entries

        switch brightnessAdapter.mode {
        case .location:
            let maxValues = brightnessContrastChart.maxValuesLocation
            let steps = brightnessContrastChart.interpolationValues
            let points = brightnessAdapter.getBrightnessContrastBatch(
                for: display, count: maxValues, minutesBetween: steps, factor: factor,
                minBrightness: minBrightness, maxBrightness: maxBrightness,
                minContrast: minContrast, maxContrast: maxContrast
            )
            var idx: Int
            for x in 0 ..< (maxValues - 1) {
                let startIndex = x * steps
                let xPoints = points[startIndex ..< (startIndex + steps)]
                for (i, y) in xPoints.enumerated() {
                    idx = x * steps + i
                    if idx >= brightnessChartEntry.count || idx >= contrastChartEntry.count {
                        break
                    }
                    brightnessChartEntry[idx].y = y.0.doubleValue
                    contrastChartEntry[idx].y = y.1.doubleValue
                }
            }
            for (i, point) in brightnessChartEntry.prefix(steps).reversed().enumerated() {
                idx = (maxValues - 1) * steps + i
                if idx >= brightnessChartEntry.count {
                    break
                }
                brightnessChartEntry[idx].y = point.y
            }
            for (i, point) in contrastChartEntry.prefix(steps).reversed().enumerated() {
                idx = (maxValues - 1) * steps + i
                if idx >= contrastChartEntry.count {
                    break
                }
                contrastChartEntry[idx].y = point.y
            }
        case .sync:
            let maxValues = brightnessContrastChart.maxValuesSync
            let minBrightness = minBrightness != nil ? Double(minBrightness!) : nil
            let maxBrightness = maxBrightness != nil ? Double(maxBrightness!) : nil
            let minContrast = minContrast != nil ? Double(minContrast!) : nil
            let maxContrast = maxContrast != nil ? Double(maxContrast!) : nil
            let xs = stride(from: 0, to: maxValues - 1, by: 1)
            let percents = Array(stride(from: 0.0, to: Double(maxValues - 1) / 100.0, by: 0.01))

            let clipMin = brightnessAdapter.brightnessClipMin
            let clipMax = brightnessAdapter.brightnessClipMax

            for (x, b) in zip(
                xs,
                display
                    .computeSIMDValue(
                        from: percents,
                        type: .brightness,
                        minVal: minBrightness,
                        maxVal: maxBrightness,
                        brightnessClipMin: clipMin,
                        brightnessClipMax: clipMax
                    )
            ) {
                brightnessChartEntry[x].y = b.doubleValue
            }
            for (x, b) in zip(
                xs,
                display
                    .computeSIMDValue(
                        from: percents,
                        type: .contrast,
                        minVal: minContrast,
                        maxVal: maxContrast,
                        brightnessClipMin: clipMin,
                        brightnessClipMax: clipMax
                    )
            ) {
                contrastChartEntry[x].y = b.doubleValue
            }
        default:
            break
        }

        brightnessContrastChart.notifyDataSetChanged()
    }

    @IBAction func toggleAdaptive(_ sender: NSButton) {
        switch sender.state {
        case .on:
            display?.adaptive = true
            setValuesHidden(false)
        case .off:
            display?.adaptive = false
            setValuesHidden(true)
        default:
            return
        }
    }

    @IBAction func toggleBrightnessRange(_ sender: NSButton) {
        switch sender.state {
        case .on:
            display?.extendedBrightnessRange = true
        case .off:
            display?.extendedBrightnessRange = false
        default:
            return
        }
    }

    func initToggleButton(_ button: NSButton?, helpButton: NSButton?) {
        guard let button = button else { return }
        if brightnessAdapter.mode == .manual || (display != nil && !display!.activeAndResponsive || display!.id == GENERIC_DISPLAY_ID) {
            button.isHidden = true
            helpButton?.isHidden = true
        } else {
            button.isHidden = false
            helpButton?.isHidden = false
        }
    }

    func setIsHidden(_ value: Bool) {
        setButtonsHidden(value)

        nonResponsiveDDCTextField?.isHidden = value
        scrollableBrightness?.isHidden = value
        scrollableContrast?.isHidden = value
        brightnessContrastChart?.isHidden = value
        swipeLeftHint?.isHidden = value
        swipeRightHint?.isHidden = value
    }

    func listenForShowNavigationHintsChange() {
        showNavigationHintsObserver = Defaults.observe(.showNavigationHints) { [weak self] change in
            if change.newValue == change.oldValue {
                return
            }
            runInMainThread { [weak self] in
                guard let self = self else { return }
                self.swipeLeftHint?.isHidden = !change.newValue
                self.swipeRightHint?.isHidden = !change.newValue
            }
        }
    }

    deinit {
        let id = "displayViewController-\(self.viewID ?? "")"
        display?.resetObserver(prop: "adaptive", key: id, type: Bool.self)
        display?.resetObserver(prop: "activeAndResponsive", key: id, type: Bool.self)
    }

    func listenForAdaptiveChange() {
        adaptiveObserver = { [weak self] newAdaptive, oldValue in
            if let self = self, let button = self.algorithmButton, let display = self.display {
                runInMainThread { [weak self] in
                    guard let self = self else { return }
                    if newAdaptive {
                        self.setValuesHidden(false)
                        button.state = .on
                    } else {
                        self.setValuesHidden(true)
                        button.state = .off
                    }
                    display.readapt(newValue: newAdaptive, oldValue: oldValue)
                }
            }
        }
        display?.setObserver(prop: "adaptive", key: "displayViewController-\(viewID ?? "")", action: adaptiveObserver!)
    }

    func listenForBrightnessRangeChange() {
        brightnessRangeObserver = { [weak self] newBrightnessRange, oldValue in
            if let self = self, let button = self.brightnessRangeButton, let display = self.display {
                runInMainThread { [weak display, weak button] in
                    if newBrightnessRange {
                        button?.state = .on
                    } else {
                        button?.state = .off
                    }
                    display?.readapt(newValue: newBrightnessRange, oldValue: oldValue)
                }
            }
        }
        display?.setObserver(
            prop: "extendedBrightnessRange",
            key: "displayViewController-\(viewID ?? "")",
            action: brightnessRangeObserver!
        )
    }

    func listenForActiveAndResponsiveChange() {
        activeAndResponsiveObserver = { [weak self] newActiveAndResponsive, _ in
            if let self = self, let display = self.display, let textField = self.nonResponsiveDDCTextField {
                runInMainThread { [weak self] in
                    guard let self = self else { return }
                    self.setButtonsHidden(display.id == GENERIC_DISPLAY_ID || !newActiveAndResponsive)
                    self.setAdaptiveButtonEnabled(brightnessAdapter.mode != .manual)

                    textField.isHidden = !(self.algorithmButton?.isHidden ?? false)
                }
            }
        }
        display?.setObserver(
            prop: "activeAndResponsive",
            key: "displayViewController-\(viewID ?? "")",
            action: activeAndResponsiveObserver!
        )
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = Defaults.observe(.adaptiveBrightnessMode) { [weak self] change in
            runInMainThread { [weak self, weak brightnessContrastChart = self?.brightnessContrastChart] in
                guard let self = self, change.newValue != change.oldValue else {
                    return
                }
                let adaptiveMode = change.newValue
                if let chart = brightnessContrastChart, !chart.visibleRect.isEmpty {
                    self.initGraph(mode: adaptiveMode)
                }
                if adaptiveMode == .manual {
                    self.scrollableBrightness?.disabled = true
                    self.scrollableContrast?.disabled = true
                    self.setValuesHidden(true, mode: adaptiveMode)
                    self.setAdaptiveButtonEnabled(false)
                } else {
                    self.scrollableBrightness?.disabled = false
                    self.scrollableContrast?.disabled = false
                    self.setValuesHidden(false, mode: adaptiveMode)
                    self.setAdaptiveButtonEnabled((self.display?.id ?? GENERIC_DISPLAY_ID) != GENERIC_DISPLAY_ID)
                }
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

    func setValuesHidden(_ hidden: Bool, mode: AdaptiveMode? = nil) {
        scrollableBrightness?.setValuesHidden(hidden, mode: mode)
        scrollableContrast?.setValuesHidden(hidden, mode: mode)
    }

    @IBAction func setInput(_ sender: NSPopUpButton) {
        guard let display = display, let input = InputSource(rawValue: UInt8(sender.selectedTag())) else { return }
        display.input = NSNumber(value: input.rawValue)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewID = view.accessibilityIdentifier()

        swipeLeftHint?.isHidden = true
        swipeRightHint?.isHidden = true

        adaptiveHelpButton?.helpText = ADAPTIVE_HELP_TEXT
        brightnessRangeHelpButton?.helpText = BRIGHTNESS_RANGE_HELP_TEXT
        lockBrightnessHelpButton?.helpText = LOCK_BRIGHTNESS_HELP_TEXT
        lockContrastHelpButton?.helpText = LOCK_CONTRAST_HELP_TEXT

        if let display = display, display.id != GENERIC_DISPLAY_ID {
            update(from: display)

            scrollableBrightness?.display = display
            scrollableContrast?.display = display

            initToggleButton(algorithmButton, helpButton: adaptiveHelpButton)
            algorithmButton?.page = .displayAlgorithm

            initToggleButton(brightnessRangeButton, helpButton: brightnessRangeHelpButton)
            brightnessRangeButton?.page = .displayBrightnessRange

            if let inputDropdown = inputDropdown {
                inputDropdown.appearance = NSAppearance(named: .vibrantLight)
                for item in inputDropdown.itemArray {
                    item.attributedTitle = (item.attributedTitle?.string ?? item.title)
                        .withAttribute(.textColor(darkMauve.blended(withFraction: 0.3, of: gray)!))
                }
            }

            scrollableBrightness?.label.textColor = scrollableViewLabelColor
            scrollableContrast?.label.textColor = scrollableViewLabelColor

            scrollableBrightness?.onMinValueChanged = { [weak self] (value: Int) in self?.updateDataset(minBrightness: UInt8(value)) }
            scrollableBrightness?.onMaxValueChanged = { [weak self] (value: Int) in self?.updateDataset(maxBrightness: UInt8(value)) }
            scrollableContrast?.onMinValueChanged = { [weak self] (value: Int) in self?.updateDataset(minContrast: UInt8(value)) }
            scrollableContrast?.onMaxValueChanged = { [weak self] (value: Int) in self?.updateDataset(maxContrast: UInt8(value)) }

            initGraph()

            if !display.adaptive || brightnessAdapter.mode == .manual {
                setValuesHidden(true)
            }
        } else {
            setIsHidden(true)
        }
        listenForAdaptiveChange()
        listenForBrightnessRangeChange()
        listenForAdaptiveModeChange()
        listenForActiveAndResponsiveChange()
        listenForShowNavigationHintsChange()
    }
}
