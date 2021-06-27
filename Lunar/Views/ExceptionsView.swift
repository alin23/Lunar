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
        guard let app = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? AppException,
              let scrollableBrightness = (rowView.view(atColumn: 2) as? NSTableCellView)?.subviews[0] as? ScrollableTextField,
              let scrollableContrast = (rowView.view(atColumn: 3) as? NSTableCellView)?.subviews[0] as? ScrollableTextField
        else { return }

        scrollableBrightness.textFieldColor = scrollableTextFieldColorWhite
        scrollableBrightness.textFieldColorHover = scrollableTextFieldColorHoverWhite
        scrollableBrightness.textFieldColorLight = scrollableTextFieldColorLightWhite
        scrollableBrightness.showPlusSign = true

        scrollableContrast.textFieldColor = scrollableTextFieldColorWhite
        scrollableContrast.textFieldColorHover = scrollableTextFieldColorHoverWhite
        scrollableContrast.textFieldColorLight = scrollableTextFieldColorLightWhite
        scrollableContrast.showPlusSign = true

        scrollableBrightness.onValueChanged = { [weak app] value in
            app?.brightness = value.i8
        }
        scrollableContrast.onValueChanged = { [weak app] value in
            app?.contrast = value.i8
        }
        if let exceptionsController = superview?.superview?.nextResponder?.nextResponder as? ExceptionsViewController {
            if let controller = exceptionsController.parent?.parent as? SettingsPageController {
                scrollableBrightness.onValueChangedInstant = { [weak controller, weak scrollableContrast] value in
                    guard let scrollableContrast = scrollableContrast, let controller = controller else { return }
                    controller.updateDataset(
                        display: displayController.firstDisplay,
                        appBrightnessOffset: value,
                        appContrastOffset: scrollableContrast.integerValue
                    )
                }
                scrollableContrast.onValueChangedInstant = { [weak controller, weak scrollableBrightness] value in
                    guard let scrollableBrightness = scrollableBrightness, let controller = controller else { return }
                    controller.updateDataset(
                        display: displayController.firstDisplay,
                        appBrightnessOffset: scrollableBrightness.integerValue,
                        appContrastOffset: value
                    )
                }

                scrollableBrightness.onMouseEnter = { [weak controller, weak scrollableBrightness, weak scrollableContrast] in
                    guard let scrollableBrightness = scrollableBrightness, let scrollableContrast = scrollableContrast,
                          let controller = controller else { return }
                    let brightnessOffset = scrollableBrightness.integerValue
                    let contrastOffset = scrollableContrast.integerValue
                    controller.updateDataset(
                        display: displayController.firstDisplay,
                        appBrightnessOffset: brightnessOffset,
                        appContrastOffset: contrastOffset,
                        withAnimation: true
                    )
                }
                scrollableContrast.onMouseEnter = { [weak controller, weak scrollableBrightness, weak scrollableContrast] in
                    guard let scrollableBrightness = scrollableBrightness, let scrollableContrast = scrollableContrast,
                          let controller = controller else { return }
                    let brightnessOffset = scrollableBrightness.integerValue
                    let contrastOffset = scrollableContrast.integerValue
                    controller.updateDataset(
                        display: displayController.firstDisplay,
                        appBrightnessOffset: brightnessOffset,
                        appContrastOffset: contrastOffset,
                        withAnimation: true
                    )
                }
            }
        }
    }
}
