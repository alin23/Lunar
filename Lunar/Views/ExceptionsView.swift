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
        scrollableBrightness.onValueChanged = { value in
            app.setValue(value, forKey: "brightness")
        }
        scrollableContrast.onValueChanged = { value in
            app.setValue(value, forKey: "contrast")
        }
    }
}
