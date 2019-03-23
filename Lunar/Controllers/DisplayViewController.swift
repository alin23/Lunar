//
//  DisplayViewController.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Charts
import Cocoa

class DisplayViewController: NSViewController {
    @IBOutlet var displayView: DisplayView!
    @IBOutlet var displayName: NSTextField!
    @IBOutlet var adaptiveButton: NSButton!

    @IBOutlet var scrollableBrightness: ScrollableBrightness!
    @IBOutlet var scrollableContrast: ScrollableContrast!

    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView!

    @IBOutlet var swipeLeftHint: NSTextField!
    @IBOutlet var swipeRightHint: NSTextField!

    var display: Display! {
        didSet {
            if let display = display {
                update(from: display)
            }
        }
    }

    var adaptiveButtonTrackingArea: NSTrackingArea!
    var adaptiveModeObserver: NSKeyValueObservation?

    func update(from display: Display) {
        if display.id == GENERIC_DISPLAY_ID {
            displayName?.stringValue = "No Display"
        } else {
            displayName?.stringValue = display.name
        }

        if display.adaptive {
            adaptiveButton?.state = .on
        } else {
            adaptiveButton?.state = .off
        }
    }

    func updateDataset(minBrightness: UInt8? = nil, maxBrightness: UInt8? = nil, minContrast: UInt8? = nil, maxContrast: UInt8? = nil, factor: Double? = nil) {
        guard let display = display, display.id != GENERIC_DISPLAY_ID else { return }

        var brightnessChartEntry = brightnessContrastChart.brightnessGraph.values
        var contrastChartEntry = brightnessContrastChart.contrastGraph.values

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

//        brightnessContrastChart.clampDataset(display: display, mode: brightnessAdapter.mode, minBrightness: minBrightness != nil ? Double(minBrightness!) : nil)
        brightnessContrastChart.notifyDataSetChanged()
    }

    @IBAction func toggleAdaptive(_ sender: NSButton) {
        switch sender.state {
        case .on:
            sender.layer?.backgroundColor = adaptiveButtonBgOn.cgColor
            display?.setValue(true, forKey: "adaptive")
            setValuesHidden(false)
        case .off:
            sender.layer?.backgroundColor = adaptiveButtonBgOff.cgColor
            display?.setValue(false, forKey: "adaptive")
            setValuesHidden(true)
        default:
            return
        }
    }

    func initAdaptiveButton() {
        if let button = adaptiveButton {
            let buttonSize = button.frame
            button.wantsLayer = true

            let activeTitle = NSMutableAttributedString(attributedString: button.attributedAlternateTitle)
            activeTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: adaptiveButtonLabelOn, range: NSMakeRange(0, activeTitle.length))
            let inactiveTitle = NSMutableAttributedString(attributedString: button.attributedTitle)
            inactiveTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: adaptiveButtonLabelOff, range: NSMakeRange(0, inactiveTitle.length))

            button.attributedTitle = inactiveTitle
            button.attributedAlternateTitle = activeTitle

            button.setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.height + 10))
            button.layer?.cornerRadius = button.frame.height / 2
            if button.state == .on {
                button.layer?.backgroundColor = adaptiveButtonBgOn.cgColor
            } else {
                button.layer?.backgroundColor = adaptiveButtonBgOff.cgColor
            }
            adaptiveButtonTrackingArea = NSTrackingArea(rect: button.visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
            button.addTrackingArea(adaptiveButtonTrackingArea)
        }
    }

    override func mouseEntered(with _: NSEvent) {
        if let button = adaptiveButton {
            button.layer?.add(fadeTransition(duration: 0.1), forKey: "transition")

            if button.state == .on {
                button.layer?.backgroundColor = adaptiveButtonBgOnHover.cgColor
            } else {
                button.layer?.backgroundColor = adaptiveButtonBgOffHover.cgColor
            }
        }
    }

    override func mouseExited(with _: NSEvent) {
        if let button = adaptiveButton {
            button.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")

            if button.state == .on {
                button.layer?.backgroundColor = adaptiveButtonBgOn.cgColor
            } else {
                button.layer?.backgroundColor = adaptiveButtonBgOff.cgColor
            }
        }
    }

    func setIsHidden(_ value: Bool) {
        adaptiveButton.isHidden = value
        scrollableBrightness.isHidden = value
        scrollableContrast.isHidden = value
        brightnessContrastChart.isHidden = value
        swipeLeftHint.isHidden = value
        swipeRightHint.isHidden = value
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = datastore.defaults.observe(\.adaptiveBrightnessMode, options: [.old, .new], changeHandler: { _, change in
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
            } else {
                self.scrollableBrightness.disabled = false
                self.scrollableContrast.disabled = false
                self.setValuesHidden(false, mode: adaptiveMode)
            }
        })
    }

    func initGraph(mode: AdaptiveMode? = nil) {
        brightnessContrastChart?.initGraph(display: display, brightnessColor: brightnessGraphColor, contrastColor: contrastGraphColor, labelColor: xAxisLabelColor, mode: mode)
    }

    func zeroGraph() {
        brightnessContrastChart?.initGraph(display: nil, brightnessColor: brightnessGraphColor, contrastColor: contrastGraphColor, labelColor: xAxisLabelColor)
    }

    func setValuesHidden(_ hidden: Bool, mode: AdaptiveMode? = nil) {
        scrollableBrightness.setValuesHidden(hidden, mode: mode)
        scrollableContrast.setValuesHidden(hidden, mode: mode)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        swipeLeftHint?.isHidden = true
        swipeRightHint?.isHidden = true

        if let display = display, display.id != GENERIC_DISPLAY_ID {
            update(from: display)

            scrollableBrightness.display = display
            scrollableContrast.display = display

            initAdaptiveButton()

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
        listenForAdaptiveModeChange()
    }
}
