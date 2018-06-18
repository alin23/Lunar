//
//  DisplayViewController.swift
//  Lunar
//
//  Created by Alin on 22/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Charts

class DisplayViewController: NSViewController {
    
    @IBOutlet weak var displayView: DisplayView!
    @IBOutlet weak var displayName: NSTextField!
    @IBOutlet weak var adaptiveButton: NSButton!
    
    @IBOutlet weak var scrollableBrightness: ScrollableBrightness!
    @IBOutlet weak var scrollableContrast: ScrollableContrast!
    
    @IBOutlet weak var deleteButton: DeleteButton!
    @IBOutlet weak var brightnessContrastChart: LineChartView!
    
    var display: Display! {
        didSet {
            if let display = display {
                update(from: display)
            }
        }
    }
    
    var adaptiveButtonTrackingArea: NSTrackingArea!
    var deleteButtonTrackingArea: NSTrackingArea!
    let brightnessGraph = LineChartDataSet(values: [ChartDataEntry](), label: "Brightness")
    let contrastGraph = LineChartDataSet(values: [ChartDataEntry](), label: "Contrast")
    let graphData = LineChartData()
    
    func update(from display: Display) {
        displayName?.stringValue = display.name
        if display.adaptive {
            adaptiveButton?.state = .on
        } else {
            adaptiveButton?.state = .off
        }
    }
    
    func updateDataset(minBrightness: UInt8? = nil, maxBrightness: UInt8? = nil, minContrast: UInt8? = nil, maxContrast: UInt8? = nil) {
        var brightnessChartEntry = brightnessGraph.values
        var contrastChartEntry = contrastGraph.values
        
        for hour in 0..<24 {
            let (brightness, contrast) = brightnessAdapter.getBrightnessContrast(
                for: display, hour: hour,
                minBrightness: minBrightness,
                maxBrightness: maxBrightness,
                minContrast: minContrast,
                maxContrast: maxContrast)
            brightnessChartEntry[hour].y = brightness.doubleValue
            contrastChartEntry[hour].y = contrast.doubleValue
        }
        
        brightnessContrastChart.notifyDataSetChanged()
    }
    
    func updateGraph() {
        var brightnessChartEntry = brightnessGraph.values
        var contrastChartEntry = contrastGraph.values
        
        brightnessChartEntry.reserveCapacity(24)
        contrastChartEntry.reserveCapacity(24)
        brightnessChartEntry.removeAll(keepingCapacity: true)
        contrastChartEntry.removeAll(keepingCapacity: true)
        
        for hour in 0..<24 {
            let (brightness, contrast) = brightnessAdapter.getBrightnessContrast(for: display, hour: hour)
            brightnessChartEntry.append(ChartDataEntry(x: Double(hour), y: brightness.doubleValue))
            contrastChartEntry.append(ChartDataEntry(x: Double(hour), y: contrast.doubleValue))
        }
        
        brightnessGraph.values = brightnessChartEntry
        contrastGraph.values = contrastChartEntry
        
        graphData.addDataSet(contrastGraph)
        graphData.addDataSet(brightnessGraph)
        
        brightnessGraph.colors = [NSColor.clear]
        brightnessGraph.fillColor = brightnessGraphColor
        brightnessGraph.drawCirclesEnabled = false
        brightnessGraph.drawFilledEnabled = true
        brightnessGraph.drawValuesEnabled = false
        brightnessGraph.mode = LineChartDataSet.Mode.cubicBezier
        
        contrastGraph.colors = [NSColor.clear]
        contrastGraph.fillColor = contrastGraphColor
        contrastGraph.drawCirclesEnabled = false
        contrastGraph.drawFilledEnabled = true
        contrastGraph.drawValuesEnabled = false
        contrastGraph.mode = LineChartDataSet.Mode.cubicBezier
        
        brightnessContrastChart.data = graphData
        brightnessContrastChart.gridBackgroundColor = NSColor.clear
        brightnessContrastChart.drawGridBackgroundEnabled = false
        brightnessContrastChart.drawBordersEnabled = false
        brightnessContrastChart.autoScaleMinMaxEnabled = false
        
        let leftAxis = brightnessContrastChart.leftAxis
        let rightAxis = brightnessContrastChart.rightAxis
        let xAxis = brightnessContrastChart.xAxis
        
        leftAxis.axisMaximum = 130
        leftAxis.axisMinimum = 0
        leftAxis.drawGridLinesEnabled = false
        leftAxis.drawLabelsEnabled = false
        leftAxis.drawAxisLineEnabled = false
        
        rightAxis.axisMaximum = 130
        rightAxis.axisMinimum = 0
        rightAxis.drawGridLinesEnabled = false
        rightAxis.drawLabelsEnabled = false
        rightAxis.drawAxisLineEnabled = false
        
        xAxis.drawGridLinesEnabled = false
        xAxis.drawLabelsEnabled = false
        xAxis.drawAxisLineEnabled = false
        
        brightnessContrastChart.chartDescription = nil
        brightnessContrastChart.legend.enabled = false
        brightnessContrastChart.animate(yAxisDuration: 1.5, easingOption: ChartEasingOption.easeOutExpo)
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
    
    @IBAction func delete(_ sender: NSButton) {
        (self.view.superview!.nextResponder as! PageController).deleteDisplay()
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
    
    
    override func mouseEntered(with event: NSEvent) {
        if let button = adaptiveButton {
            button.layer!.add(fadeTransition(duration: 0.1), forKey: "transition")
            
            if button.state == .on {
                button.layer!.backgroundColor = adaptiveButtonBgOnHover.cgColor
            } else {
                button.layer!.backgroundColor = adaptiveButtonBgOffHover.cgColor
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
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
            scrollableBrightness.onMinValueChanged = {value in self.updateDataset(minBrightness: value)}
            scrollableBrightness.onMaxValueChanged = {value in self.updateDataset(maxBrightness: value)}
            scrollableContrast.onMinValueChanged = {value in self.updateDataset(minContrast: value)}
            scrollableContrast.onMaxValueChanged = {value in self.updateDataset(maxContrast: value)}
            updateGraph()
        } else {
            setIsHidden(true)
        }
    }
}
