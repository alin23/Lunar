//
//  ExceptionsView.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

class ExceptionsView: NSTableView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func didAdd(_ rowView: NSTableRowView, forRow _: Int) {
        let app = (rowView.view(atColumn: 1) as! NSTableCellView).objectValue as! AppException
        let scrollableBrightness = (rowView.view(atColumn: 2) as! NSTableCellView).subviews[0] as! ScrollableTextField
        let scrollableContrast = (rowView.view(atColumn: 3) as! NSTableCellView).subviews[0] as! ScrollableTextField

        scrollableBrightness.textFieldColor = scrollableTextFieldColorWhite
        scrollableBrightness.textFieldColorHover = scrollableTextFieldColorHoverWhite
        scrollableBrightness.textFieldColorLight = scrollableTextFieldColorLightWhite

        scrollableContrast.textFieldColor = scrollableTextFieldColorWhite
        scrollableContrast.textFieldColorHover = scrollableTextFieldColorHoverWhite
        scrollableContrast.textFieldColorLight = scrollableTextFieldColorLightWhite

        scrollableBrightness.onValueChanged = { value in
            app.setValue(value, forKey: "brightness")
        }
        scrollableContrast.onValueChanged = { value in
            app.setValue(value, forKey: "contrast")
        }
        if let exceptionsController = superview?.superview?.nextResponder?.nextResponder as? ExceptionsViewController {
            if let controller = exceptionsController.parent?.parent as? SettingsPageController {
                scrollableBrightness.onValueChangedInstant = { value in
                    controller.updateDataset(
                        display: brightnessAdapter.firstDisplay,
                        brightnessOffset: value,
                        contrastOffset: scrollableContrast.integerValue
                    )
                }
                scrollableContrast.onValueChangedInstant = { value in
                    controller.updateDataset(
                        display: brightnessAdapter.firstDisplay,
                        brightnessOffset: scrollableBrightness.integerValue,
                        contrastOffset: value
                    )
                }

                scrollableBrightness.onMouseEnter = {
                    let brightnessOffset = scrollableBrightness.integerValue
                    let contrastOffset = scrollableContrast.integerValue
                    controller.updateDataset(
                        display: brightnessAdapter.firstDisplay,
                        brightnessOffset: brightnessOffset,
                        contrastOffset: contrastOffset,
                        withAnimation: true
                    )
                }
                scrollableContrast.onMouseEnter = {
                    let brightnessOffset = scrollableBrightness.integerValue
                    let contrastOffset = scrollableContrast.integerValue
                    controller.updateDataset(
                        display: brightnessAdapter.firstDisplay,
                        brightnessOffset: brightnessOffset,
                        contrastOffset: contrastOffset,
                        withAnimation: true
                    )
                }
            }
        }
    }
}
