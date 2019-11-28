//
//  ExceptionsView.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

let textFieldColor = sunYellow
let textFieldColorHover = sunYellow.blended(withFraction: 0.1, of: red)!
let textFieldColorLight = sunYellow.blended(withFraction: 0.3, of: red)!

class DisplayValuesView: NSTableView {
    var brightnessObservers: [CGDirectDisplayID: NSKeyValueObservation] = [:]
    var contrastObservers: [CGDirectDisplayID: NSKeyValueObservation] = [:]

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func didRemove(_ rowView: NSTableRowView, forRow _: Int) {
        guard let display = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? Display else {
            return
        }
        brightnessObservers.removeValue(forKey: display.id)
        contrastObservers.removeValue(forKey: display.id)
    }

    override func didAdd(_ rowView: NSTableRowView, forRow _: Int) {
        guard let scrollableBrightness = (rowView.view(atColumn: 0) as? NSTableCellView)?.subviews[0] as? ScrollableTextField,
            let display = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? Display,
            let adaptiveButton = (rowView.view(atColumn: 1) as? NSTableCellView)?.subviews.first(
                where: { v in (v as? QuickAdaptiveButton) != nil }
            ) as? QuickAdaptiveButton,
            let scrollableContrast = (rowView.view(atColumn: 2) as? NSTableCellView)?.subviews[0] as? ScrollableTextField,
            let scrollableBrightnessCaption = (rowView.view(atColumn: 0) as? NSTableCellView)?.subviews[1] as? ScrollableTextFieldCaption,
            let scrollableContrastCaption = (rowView.view(atColumn: 2) as? NSTableCellView)?.subviews[1] as? ScrollableTextFieldCaption else { return }

        adaptiveButton.setup(displayID: display.id)

        scrollableBrightness.textFieldColor = textFieldColor
        scrollableBrightness.textFieldColorHover = textFieldColorHover
        scrollableBrightness.textFieldColorLight = textFieldColorLight
        scrollableBrightness.caption = scrollableBrightnessCaption

        scrollableContrast.textFieldColor = textFieldColor
        scrollableContrast.textFieldColorHover = textFieldColorHover
        scrollableContrast.textFieldColorLight = textFieldColorLight
        scrollableContrast.caption = scrollableContrastCaption

        scrollableBrightnessCaption.textColor = NSColor.textColor
        scrollableContrastCaption.textColor = NSColor.textColor

        scrollableBrightness.onValueChanged = { value in
            display.setValue(NSNumber(value: value), forKey: "brightness")
            display.setValue(false, forKey: "adaptive")
        }
        scrollableContrast.onValueChanged = { value in
            display.setValue(NSNumber(value: value), forKey: "contrast")
            display.setValue(false, forKey: "adaptive")
        }
        brightnessObservers[display.id] = display.observe(
            \.brightness,
            options: [.new, .old],
            changeHandler: { d, change in
                if let newBrightness = change.newValue, d.id != GENERIC_DISPLAY_ID, d.id != TEST_DISPLAY_ID {
                    DispatchQueue.main.async {
                        scrollableBrightness.integerValue = newBrightness.intValue
                        scrollableBrightness.setNeedsDisplay()
                    }
                }
            }
        )

        contrastObservers[display.id] = display.observe(
            \.contrast,
            options: [.new, .old],
            changeHandler: { d, change in
                if let newContrast = change.newValue, d.id != GENERIC_DISPLAY_ID, d.id != TEST_DISPLAY_ID {
                    DispatchQueue.main.async {
                        scrollableContrast.integerValue = newContrast.intValue
                        scrollableContrast.setNeedsDisplay()
                    }
                }
            }
        )
    }
}
