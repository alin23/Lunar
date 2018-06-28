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

    @IBOutlet var deleteButton: DeleteButton!
    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView!

    var display: Display! {
        didSet {
            if let display = display {
                update(from: display)
            }
        }
    }

    var adaptiveButtonTrackingArea: NSTrackingArea!
    var deleteButtonTrackingArea: NSTrackingArea!

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

    func updateDataset(minBrightness: UInt8? = nil, maxBrightness: UInt8? = nil, minContrast: UInt8? = nil, maxContrast: UInt8? = nil) {
        var brightnessChartEntry = brightnessContrastChart.brightnessGraph.values
        var contrastChartEntry = brightnessContrastChart.contrastGraph.values

        for hour in 0 ..< 24 {
            let (brightness, contrast) = brightnessAdapter.getBrightnessContrast(
                for: display,
                hour: hour,
                minBrightness: minBrightness,
                maxBrightness: maxBrightness,
                minContrast: minContrast,
                maxContrast: maxContrast
            )
            brightnessChartEntry[hour].y = brightness.doubleValue
            contrastChartEntry[hour].y = contrast.doubleValue
        }
        brightnessChartEntry[24] = brightnessChartEntry[0]
        contrastChartEntry[24] = contrastChartEntry[0]

        brightnessContrastChart.notifyDataSetChanged()
    }

    @IBAction func toggleAdaptive(_ sender: NSButton) {
        switch sender.state {
        case .on:
            sender.layer!.backgroundColor = adaptiveButtonBgOn.cgColor
            display?.setValue(true, forKey: "adaptive")
        case .off:
            sender.layer!.backgroundColor = adaptiveButtonBgOff.cgColor
            display?.setValue(false, forKey: "adaptive")
        default:
            return
        }
    }

    @IBAction func delete(_: NSButton) {
        (view.superview!.nextResponder as! PageController).deleteDisplay()
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
            button.layer!.cornerRadius = button.frame.height / 2
            if button.state == .on {
                button.layer!.backgroundColor = adaptiveButtonBgOn.cgColor
            } else {
                button.layer!.backgroundColor = adaptiveButtonBgOff.cgColor
            }
            adaptiveButtonTrackingArea = NSTrackingArea(rect: button.visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
            button.addTrackingArea(adaptiveButtonTrackingArea)
        }
    }

    override func mouseEntered(with _: NSEvent) {
        if let button = adaptiveButton {
            button.layer!.add(fadeTransition(duration: 0.1), forKey: "transition")

            if button.state == .on {
                button.layer!.backgroundColor = adaptiveButtonBgOnHover.cgColor
            } else {
                button.layer!.backgroundColor = adaptiveButtonBgOffHover.cgColor
            }
        }
    }

    override func mouseExited(with _: NSEvent) {
        if let button = adaptiveButton {
            button.layer!.add(fadeTransition(duration: 0.2), forKey: "transition")

            if button.state == .on {
                button.layer!.backgroundColor = adaptiveButtonBgOn.cgColor
            } else {
                button.layer!.backgroundColor = adaptiveButtonBgOff.cgColor
            }
        }
    }

    func setIsHidden(_ value: Bool) {
        adaptiveButton.isHidden = value
        scrollableBrightness.isHidden = value
        scrollableContrast.isHidden = value
        brightnessContrastChart.isHidden = value
    }

    func initGraph() {
        brightnessContrastChart?.initGraph(display: display, brightnessColor: brightnessGraphColor, contrastColor: contrastGraphColor, labelColor: xAxisLabelColor)
    }

    func zeroGraph() {
        brightnessContrastChart?.initGraph(display: nil, brightnessColor: brightnessGraphColor, contrastColor: contrastGraphColor, labelColor: xAxisLabelColor)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let display = display, display != GENERIC_DISPLAY {
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
        } else {
            setIsHidden(true)
        }
    }
}
