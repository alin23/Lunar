//
//  DisplayViewController.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Charts
import Cocoa

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

class DisplayViewController: NSViewController {
    @IBOutlet var displayView: DisplayView!
    @IBOutlet var displayName: NSTextField!
    @IBOutlet var adaptiveButton: NSButton!

    @IBOutlet var brightnessRangeButton: NSButton!
    @IBOutlet var algorithmText: NSTextField!
    @IBOutlet var brightnessRangeText: NSTextField!

    @IBOutlet var scrollableBrightness: ScrollableBrightness!
    @IBOutlet var scrollableContrast: ScrollableContrast!

    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView!

    @IBOutlet var swipeLeftHint: NSTextField!
    @IBOutlet var swipeRightHint: NSTextField!

    @IBOutlet var adaptiveHelpButton: HelpButton!

    @IBOutlet var brightnessRangeHelpButton: HelpButton!

    @IBOutlet var nonResponsiveDDCTextField: NonResponsiveDDCTextField!
    @IBOutlet var lockContrastHelpButton: HelpButton!
    @IBOutlet var lockBrightnessHelpButton: HelpButton!

    @objc dynamic var display: Display! {
        didSet {
            if let display = display {
                update(from: display)
            }
        }
    }

    var adaptiveButtonTrackingArea: NSTrackingArea!
    var adaptiveModeObserver: NSKeyValueObservation?
    var adaptiveObserver: ((Bool, Bool) -> Void)?
    var brightnessRangeObserver: ((Bool, Bool) -> Void)?
    var activeAndResponsiveObserver: ((Bool, Bool) -> Void)?
    var showNavigationHintsObserver: NSKeyValueObservation?

    func setAdaptiveButtonEnabled(_ enabled: Bool) {
        guard let adaptiveButton = adaptiveButton else { return }

        adaptiveButton.layer?.add(fadeTransition(duration: 0.1), forKey: "transition")
        adaptiveButton.isEnabled = enabled
        adaptiveHelpButton?.isEnabled = enabled

        if enabled {
            switch adaptiveButton.state {
            case .on:
                adaptiveButton.layer?.backgroundColor = adaptiveButtonColors[.bgOn]!.cgColor
            case .off:
                adaptiveButton.layer?.backgroundColor = adaptiveButtonColors[.bgOff]!.cgColor
            default:
                return
            }
        } else {
            adaptiveButton.layer?.backgroundColor = darkMauve.cgColor
        }
    }

    func setButtonsHidden(_ hidden: Bool) {
        adaptiveButton?.isHidden = hidden
        adaptiveHelpButton?.isHidden = hidden
        algorithmText?.isHidden = hidden

        brightnessRangeButton?.isHidden = hidden
        brightnessRangeHelpButton?.isHidden = hidden
        brightnessRangeText?.isHidden = hidden
    }

    func update(from display: Display) {
        if display.id == GENERIC_DISPLAY_ID {
            displayName?.stringValue = "No Display"
        } else {
            displayName?.stringValue = display.name
            nonResponsiveDDCTextField?.onClick = {
                runInMainThread {
                    DDC.skipWritingPropertyById[self.display.id]?.removeAll()
                    DDC.skipReadingPropertyById[self.display.id]?.removeAll()
                    DDC.writeFaults[self.display.id]?.removeAll()
                    DDC.readFaults[self.display.id]?.removeAll()
                    self.display.responsive = true
                    self.setButtonsHidden(display.id == GENERIC_DISPLAY_ID)
                    self.setAdaptiveButtonEnabled(brightnessAdapter.mode != .manual)
                    self.view.setNeedsDisplay(self.view.visibleRect)
                }
            }
        }

        if display.adaptive {
            adaptiveButton?.state = .on
        } else {
            adaptiveButton?.state = .off
        }
        if display.extendedBrightnessRange {
            brightnessRangeButton?.state = .on
        } else {
            brightnessRangeButton?.state = .off
        }

        setButtonsHidden(display.id == GENERIC_DISPLAY_ID)
        setAdaptiveButtonEnabled(brightnessAdapter.mode != .manual)
        view.setNeedsDisplay(view.visibleRect)
    }

    func updateDataset(minBrightness: UInt8? = nil, maxBrightness: UInt8? = nil, minContrast: UInt8? = nil, maxContrast: UInt8? = nil, factor: Double? = nil) {
        guard let display = display, display.id != GENERIC_DISPLAY_ID else { return }

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
            for (x, b) in zip(xs, display.computeSIMDValue(from: percents, type: .brightness, minVal: minBrightness, maxVal: maxBrightness)) {
                brightnessChartEntry[x].y = b.doubleValue
            }
            for (x, b) in zip(xs, display.computeSIMDValue(from: percents, type: .contrast, minVal: minContrast, maxVal: maxContrast)) {
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
            sender.layer?.backgroundColor = adaptiveButtonColors[.bgOn]!.cgColor
            display?.adaptive = true
            setValuesHidden(false)
        case .off:
            sender.layer?.backgroundColor = adaptiveButtonColors[.bgOff]!.cgColor
            display?.adaptive = false
            setValuesHidden(true)
        default:
            return
        }
    }

    @IBAction func toggleBrightnessRange(_ sender: NSButton) {
        switch sender.state {
        case .on:
            sender.layer?.backgroundColor = brightnessRangeButtonColors[.bgOn]!.cgColor
            display?.extendedBrightnessRange = true
        case .off:
            sender.layer?.backgroundColor = brightnessRangeButtonColors[.bgOff]!.cgColor
            display?.extendedBrightnessRange = false
        default:
            return
        }
    }

    func initToggleButton(_ button: NSButton?, helpButton: NSButton?, buttonColors: [ButtonColor: NSColor]) {
        guard let button = button else { return }
        if brightnessAdapter.mode == .manual || !display.activeAndResponsive || display.id == GENERIC_DISPLAY_ID {
            button.isHidden = true
            helpButton?.isHidden = true
        } else {
            button.isHidden = false
            helpButton?.isHidden = false
        }

        let buttonSize = button.frame
        button.wantsLayer = true

        let activeTitle = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
        activeTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: buttonColors[.labelOn]!, range: NSMakeRange(0, activeTitle.length))
        let inactiveTitle = NSMutableAttributedString(attributedString: button.attributedTitle)
        inactiveTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: buttonColors[.labelOff]!, range: NSMakeRange(0, inactiveTitle.length))

        button.attributedTitle = inactiveTitle
        button.attributedAlternateTitle = activeTitle

        button.setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.height + 10))
        button.layer?.cornerRadius = button.frame.height / 2
        if button.state == .on {
            button.layer?.backgroundColor = buttonColors[.bgOn]!.cgColor
        } else {
            button.layer?.backgroundColor = buttonColors[.bgOff]!.cgColor
        }
        button.addTrackingArea(NSTrackingArea(rect: button.visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: ["button": button, "colors": buttonColors]))
    }

    override func mouseEntered(with event: NSEvent) {
        guard let data = event.trackingArea?.userInfo,
            let button = data["button"] as? NSButton,
            let colors = data["colors"] as? [ButtonColor: NSColor],
            !button.isHidden, button.isEnabled else { return }

        button.layer?.add(fadeTransition(duration: 0.1), forKey: "transition")

        if button.state == .on {
            button.layer?.backgroundColor = colors[.bgOnHover]!.cgColor
        } else {
            button.layer?.backgroundColor = colors[.bgOffHover]!.cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard let data = event.trackingArea?.userInfo,
            let button = data["button"] as? NSButton,
            let colors = data["colors"] as? [ButtonColor: NSColor],
            !button.isHidden, button.isEnabled else { return }

        button.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")

        if button.state == .on {
            button.layer?.backgroundColor = colors[.bgOn]!.cgColor
        } else {
            button.layer?.backgroundColor = colors[.bgOff]!.cgColor
        }
    }

    func setIsHidden(_ value: Bool) {
        setButtonsHidden(value)

        scrollableBrightness.isHidden = value
        scrollableContrast.isHidden = value
        brightnessContrastChart.isHidden = value
        swipeLeftHint.isHidden = value
        swipeRightHint.isHidden = value
    }

    func listenForShowNavigationHintsChange() {
        showNavigationHintsObserver = datastore.defaults.observe(\.showNavigationHints, options: [.old, .new], changeHandler: { _, change in
            guard let show = change.newValue, let oldShow = change.oldValue, show != oldShow else {
                return
            }
            runInMainThread {
                self.swipeLeftHint?.isHidden = !show
                self.swipeRightHint?.isHidden = !show
            }
        })
    }

    deinit {
        display.boolObservers["adaptive"]?.removeValue(forKey: "displayViewController-\(self.view.accessibilityIdentifier())")
        display.boolObservers["activeAndResponsive"]?.removeValue(forKey: "displayViewController-\(self.view.accessibilityIdentifier())")
    }

    func listenForAdaptiveChange() {
        adaptiveObserver = { newAdaptive, oldValue in
            if let button = self.adaptiveButton, let display = self.display {
                runInMainThread {
                    if newAdaptive {
                        button.layer?.backgroundColor = adaptiveButtonColors[.bgOn]!.cgColor
                        self.setValuesHidden(false)
                        button.state = .on
                    } else {
                        button.layer?.backgroundColor = adaptiveButtonColors[.bgOff]!.cgColor
                        self.setValuesHidden(true)
                        button.state = .off
                    }
                    display.readapt(newValue: newAdaptive, oldValue: oldValue)
                }
            }
        }
        display.boolObservers["adaptive"]?["displayViewController-\(view.accessibilityIdentifier())"] = adaptiveObserver!
    }

    func listenForBrightnessRangeChange() {
        brightnessRangeObserver = { newBrightnessRange, oldValue in
            if let button = self.brightnessRangeButton, let display = self.display {
                runInMainThread {
                    if newBrightnessRange {
                        button.layer?.backgroundColor = brightnessRangeButtonColors[.bgOn]!.cgColor
                        button.state = .on
                    } else {
                        button.layer?.backgroundColor = brightnessRangeButtonColors[.bgOff]!.cgColor
                        button.state = .off
                    }
                    display.readapt(newValue: newBrightnessRange, oldValue: oldValue)
                }
            }
        }
        display.boolObservers["extendedBrightnessRange"]?["displayViewController-\(view.accessibilityIdentifier())"] = brightnessRangeObserver!
    }

    func listenForActiveAndResponsiveChange() {
        activeAndResponsiveObserver = { newActiveAndResponsive, _ in
            if let display = self.display, let textField = self.nonResponsiveDDCTextField {
                runInMainThread {
                    self.setButtonsHidden(display.id == GENERIC_DISPLAY_ID || !newActiveAndResponsive)
                    self.setAdaptiveButtonEnabled(brightnessAdapter.mode != .manual)

                    textField.isHidden = !(self.adaptiveButton?.isHidden ?? false)
                }
            }
        }
        display.boolObservers["activeAndResponsive"]?["displayViewController-\(view.accessibilityIdentifier())"] = activeAndResponsiveObserver!
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = datastore.defaults.observe(\.adaptiveBrightnessMode, options: [.old, .new], changeHandler: { _, change in
            runInMainThread {
                guard let mode = change.newValue, let oldMode = change.oldValue, mode != oldMode else {
                    return
                }
                let adaptiveMode = AdaptiveMode(rawValue: mode)
                if let chart = self.brightnessContrastChart, !chart.visibleRect.isEmpty {
                    self.initGraph(mode: adaptiveMode)
                }
                if adaptiveMode == .manual {
                    self.scrollableBrightness.disabled = true
                    self.scrollableContrast.disabled = true
                    self.setValuesHidden(true, mode: adaptiveMode)
                    self.setAdaptiveButtonEnabled(false)
                } else {
                    self.scrollableBrightness.disabled = false
                    self.scrollableContrast.disabled = false
                    self.setValuesHidden(false, mode: adaptiveMode)
                    self.setAdaptiveButtonEnabled(self.display.id != GENERIC_DISPLAY_ID)
                }
            }
        })
    }

    func initGraph(mode: AdaptiveMode? = nil) {
        brightnessContrastChart?.initGraph(display: display, brightnessColor: brightnessGraphColor, contrastColor: contrastGraphColor, labelColor: xAxisLabelColor, mode: mode)
        brightnessContrastChart?.rightAxis.gridColor = mauve.withAlphaComponent(0.1)
        brightnessContrastChart?.xAxis.gridColor = mauve.withAlphaComponent(0.1)
    }

    func zeroGraph() {
        brightnessContrastChart?.initGraph(display: nil, brightnessColor: brightnessGraphColor, contrastColor: contrastGraphColor, labelColor: xAxisLabelColor)
        brightnessContrastChart?.rightAxis.gridColor = mauve.withAlphaComponent(0.0)
        brightnessContrastChart?.xAxis.gridColor = mauve.withAlphaComponent(0.0)
    }

    func setValuesHidden(_ hidden: Bool, mode: AdaptiveMode? = nil) {
        scrollableBrightness.setValuesHidden(hidden, mode: mode)
        scrollableContrast.setValuesHidden(hidden, mode: mode)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        swipeLeftHint?.isHidden = true
        swipeRightHint?.isHidden = true

        adaptiveHelpButton?.helpText = ADAPTIVE_HELP_TEXT
        brightnessRangeHelpButton?.helpText = BRIGHTNESS_RANGE_HELP_TEXT
        lockBrightnessHelpButton?.helpText = LOCK_BRIGHTNESS_HELP_TEXT
        lockContrastHelpButton?.helpText = LOCK_CONTRAST_HELP_TEXT

        if let display = display, display.id != GENERIC_DISPLAY_ID {
            update(from: display)

            scrollableBrightness.display = display
            scrollableContrast.display = display

            initToggleButton(adaptiveButton, helpButton: adaptiveHelpButton, buttonColors: adaptiveButtonColors)
            initToggleButton(brightnessRangeButton, helpButton: brightnessRangeHelpButton, buttonColors: brightnessRangeButtonColors)

            scrollableBrightness.label.textColor = scrollableViewLabelColor
            scrollableContrast.label.textColor = scrollableViewLabelColor

            scrollableBrightness.onMinValueChanged = { (value: Int) in self.updateDataset(minBrightness: UInt8(value)) }
            scrollableBrightness.onMaxValueChanged = { (value: Int) in self.updateDataset(maxBrightness: UInt8(value)) }
            scrollableContrast.onMinValueChanged = { (value: Int) in self.updateDataset(minContrast: UInt8(value)) }
            scrollableContrast.onMaxValueChanged = { (value: Int) in self.updateDataset(maxContrast: UInt8(value)) }

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
