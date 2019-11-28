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

        let scrollableBrightnessCaption = (rowView.view(atColumn: 2) as! NSTableCellView).subviews[1] as! ScrollableTextFieldCaption
        let scrollableContrastCaption = (rowView.view(atColumn: 3) as! NSTableCellView).subviews[1] as! ScrollableTextFieldCaption

        scrollableBrightness.textFieldColor = scrollableTextFieldColorWhite
        scrollableBrightness.textFieldColorHover = scrollableTextFieldColorHoverWhite
        scrollableBrightness.textFieldColorLight = scrollableTextFieldColorLightWhite
        scrollableBrightness.caption = scrollableBrightnessCaption

        scrollableContrast.textFieldColor = scrollableTextFieldColorWhite
        scrollableContrast.textFieldColorHover = scrollableTextFieldColorHoverWhite
        scrollableContrast.textFieldColorLight = scrollableTextFieldColorLightWhite
        scrollableContrast.caption = scrollableContrastCaption

        scrollableBrightnessCaption.textColor = scrollableCaptionColorWhite
        scrollableContrastCaption.textColor = scrollableCaptionColorWhite

        scrollableBrightness.onValueChanged = { value in
            app.setValue(NSNumber(value: value), forKey: "brightness")
        }
        scrollableContrast.onValueChanged = { value in
            app.setValue(NSNumber(value: value), forKey: "contrast")
        }
        if let exceptionsController = superview?.superview?.nextResponder?.nextResponder as? ExceptionsViewController {
            if let controller = exceptionsController.parent?.parent as? SettingsPageController {
                scrollableBrightness.onValueChangedInstant = { value in
                    controller.updateDataset(
                        display: brightnessAdapter.firstDisplay,
                        appBrightnessOffset: Int(value),
                        appContrastOffset: scrollableContrast.integerValue
                    )
                }
                scrollableContrast.onValueChangedInstant = { value in
                    controller.updateDataset(
                        display: brightnessAdapter.firstDisplay,
                        appBrightnessOffset: scrollableBrightness.integerValue,
                        appContrastOffset: Int(value)
                    )
                }

                scrollableBrightness.onMouseEnter = {
                    let brightnessOffset = scrollableBrightness.integerValue
                    let contrastOffset = scrollableContrast.integerValue
                    controller.updateDataset(
                        display: brightnessAdapter.firstDisplay,
                        appBrightnessOffset: brightnessOffset,
                        appContrastOffset: contrastOffset,
                        withAnimation: true
                    )
                }
                scrollableContrast.onMouseEnter = {
                    let brightnessOffset = scrollableBrightness.integerValue
                    let contrastOffset = scrollableContrast.integerValue
                    controller.updateDataset(
                        display: brightnessAdapter.firstDisplay,
                        appBrightnessOffset: brightnessOffset,
                        appContrastOffset: contrastOffset,
                        withAnimation: true
                    )
                }
            }
        }
    }
}
