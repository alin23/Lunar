//
//  ExceptionsView.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa
import Combine

final class ExceptionsView: NSTableView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func didRemove(_ rowView: NSTableRowView, forRow _: Int) {
        guard let app = (rowView.view(atColumn: 0) as? NSTableCellView)?.objectValue as? AppException
        else { return }

        displayController.runningAppExceptions.removeAll(where: { $0.identifier == app.identifier })
        displayController.adaptBrightness(force: true)
    }

    override func didAdd(_ rowView: NSTableRowView, forRow _: Int) {
        guard let app = (rowView.view(atColumn: 0) as? NSTableCellView)?.objectValue as? AppException
        else { return }

        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: app.identifier)
        if !runningApps.isEmpty {
            displayController.runningAppExceptions.append(app)
            displayController.adaptBrightness(force: true)
        }
    }

    override func wantsScrollEventsForSwipeTracking(on axis: NSEvent.GestureAxis) -> Bool {
        axis == .horizontal
    }
}
