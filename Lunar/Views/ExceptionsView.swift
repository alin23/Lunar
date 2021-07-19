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

    override func didRemove(_ rowView: NSTableRowView, forRow _: Int) {
        guard let app = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? AppException
        else { return }

        displayController.runningAppExceptions.removeAll(where: { $0.identifier == app.identifier })
        displayController.adaptBrightness(force: true)
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

        guard let exceptionsController = superview?.superview?.nextResponder?.nextResponder as? ExceptionsViewController,
              let controller = exceptionsController.parent?.parent as? SettingsPageController else { return }

        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: app.identifier)
        if !runningApps.isEmpty {
            displayController.runningAppExceptions.append(app)
            displayController.adaptBrightness(force: true)
        }
    }
}
