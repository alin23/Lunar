//
//  ExceptionsView.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

let textFieldColor = sunYellow
let textFieldColorHover = sunYellow.blended(withFraction: 0.2, of: red) ?? textFieldColor
let textFieldColorLight = sunYellow.blended(withFraction: 0.4, of: red) ?? textFieldColor

class DisplayValuesView: NSTableView {
    var brightnessObservers: [CGDirectDisplayID: (NSNumber, NSNumber) -> Void] = [:]
    var contrastObservers: [CGDirectDisplayID: (NSNumber, NSNumber) -> Void] = [:]

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    func setAdaptiveButtonHidden(_ hidden: Bool) {
        enumerateAvailableRowViews { rowView, _ in
            if let nameCell = rowView.view(atColumn: 1) as? NSTableCellView,
                let display = nameCell.objectValue as? Display,
                let adaptiveButton = nameCell.subviews.first(where: { v in (v as? QuickAdaptiveButton) != nil }) as? QuickAdaptiveButton,
                display.activeAndResponsive {
                runInMainThread { [weak adaptiveButton] in
                    adaptiveButton?.isHidden = hidden
                }
            }
        }
    }

    deinit {
        enumerateAvailableRowViews { rowView, _ in
            if let display = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? Display {
                let id = "displayValuesView-\(accessibilityIdentifier())"
                display.resetObserver(prop: "brightness", key: id, type: NSNumber.self)
                display.resetObserver(prop: "contrast", key: id, type: NSNumber.self)
            }
        }
    }

    func resetDeleteButtons() {
        enumerateAvailableRowViews { rowView, row in
            guard let display = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? Display,
                let notConnectedTextField = (rowView.view(atColumn: 1) as? NSTableCellView)?.subviews.first(
                    where: { v in (v as? NotConnectedTextField) != nil }
                ) as? NotConnectedTextField else {
                return
            }
            notConnectedTextField.onClick = getDeleteAction(displayID: display.id, row: row)
        }
    }

    func getResetAction(displayID: CGDirectDisplayID) -> (() -> Void) {
        return {
            runInMainThread { [weak self] in
                DDC.skipWritingPropertyById[displayID]?.removeAll()
                DDC.skipReadingPropertyById[displayID]?.removeAll()
                DDC.writeFaults[displayID]?.removeAll()
                DDC.readFaults[displayID]?.removeAll()
                brightnessAdapter.displays[displayID]?.responsive = true
                self?.setNeedsDisplay()
            }
        }
    }

    func getDeleteAction(displayID: CGDirectDisplayID, row: Int) -> (() -> Void) {
        return {
            runInMainThread { [weak self] in
                guard let self = self else { return }
                self.beginUpdates()
                self.removeRows(at: [row], withAnimation: .effectFade)
                self.endUpdates()
                if let controller = self.superview?.superview?.nextResponder?.nextResponder as? MenuPopoverController {
                    runInMainThreadAsyncAfter(ms: 200) {
                        menuPopover.animates = false
                        controller.adaptViewSize()
                        menuPopover.animates = true
                        self.resetDeleteButtons()
                    }
                }
            }
            brightnessAdapter.removeDisplay(id: displayID)
        }
    }

    func removeRow(_ rowView: NSTableRowView, forRow _: Int) {
        guard let display = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? Display else {
            return
        }
        let id = "displayValuesView-\(accessibilityIdentifier())"
        display.resetObserver(prop: "brightness", key: id, type: NSNumber.self)
        display.resetObserver(prop: "contrast", key: id, type: NSNumber.self)

        brightnessObservers.removeValue(forKey: display.id)
        contrastObservers.removeValue(forKey: display.id)
    }

    override func didRemove(_ rowView: NSTableRowView, forRow row: Int) {
        runInMainThread { [weak self] in
            self?.removeRow(rowView, forRow: row)
        }
    }

    func addRow(_ rowView: NSTableRowView, forRow row: Int) {
        guard let scrollableBrightness = (rowView.view(atColumn: 0) as? NSTableCellView)?.subviews[0] as? ScrollableTextField,
            let display = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? Display,
            let adaptiveButton = (rowView.view(atColumn: 1) as? NSTableCellView)?.subviews.first(
                where: { v in (v as? QuickAdaptiveButton) != nil }
            ) as? QuickAdaptiveButton,
            let notConnectedTextField = (rowView.view(atColumn: 1) as? NSTableCellView)?.subviews.first(
                where: { v in (v as? NotConnectedTextField) != nil }
            ) as? NotConnectedTextField,
            let nonResponsiveDDCTextField = (rowView.view(atColumn: 1) as? NSTableCellView)?.subviews.first(
                where: { v in (v as? NonResponsiveDDCTextField) != nil }
            ) as? NonResponsiveDDCTextField,
            let scrollableContrast = (rowView.view(atColumn: 2) as? NSTableCellView)?.subviews[0] as? ScrollableTextField,
            let scrollableBrightnessCaption = (rowView.view(atColumn: 0) as? NSTableCellView)?.subviews[1] as? ScrollableTextFieldCaption,
            let scrollableContrastCaption = (rowView.view(atColumn: 2) as? NSTableCellView)?.subviews[1] as? ScrollableTextFieldCaption else { return }

        notConnectedTextField.onClick = getDeleteAction(displayID: display.id, row: row)
        nonResponsiveDDCTextField.onClick = getResetAction(displayID: display.id)
        adaptiveButton.setup(displayID: display.id)
        if display.activeAndResponsive {
            if brightnessAdapter.mode == .manual {
                adaptiveButton.isHidden = true
            } else {
                adaptiveButton.isHidden = false
            }
        } else {
            adaptiveButton.isHidden = true
        }

        scrollableBrightness.textFieldColor = textFieldColor
        scrollableBrightness.textFieldColorHover = textFieldColorHover
        scrollableBrightness.textFieldColorLight = textFieldColorLight
        scrollableBrightness.doubleValue = display.brightness.doubleValue.rounded()
        scrollableBrightness.caption = scrollableBrightnessCaption
        if !display.activeAndResponsive {
            scrollableBrightness.textColor = textFieldColorLight.blended(withFraction: 0.7, of: gray)?.shadow(withLevel: 0.3) ?? textFieldColor
        }

        scrollableContrast.textFieldColor = textFieldColor
        scrollableContrast.textFieldColorHover = textFieldColorHover
        scrollableContrast.textFieldColorLight = textFieldColorLight
        scrollableContrast.doubleValue = display.contrast.doubleValue.rounded()
        scrollableContrast.caption = scrollableContrastCaption
        if !display.activeAndResponsive {
            scrollableContrast.textColor = textFieldColorLight.blended(withFraction: 0.7, of: gray)?.shadow(withLevel: 0.3) ?? textFieldColor
        }

        scrollableBrightnessCaption.textColor = NSColor.textColor
        scrollableContrastCaption.textColor = NSColor.textColor

        scrollableBrightness.onValueChanged = { value in
            display.brightness = NSNumber(value: value)
            if brightnessAdapter.mode != .manual {
                display.adaptive = false
            }
        }
        scrollableContrast.onValueChanged = { value in
            display.contrast = NSNumber(value: value)
            if brightnessAdapter.mode != .manual {
                display.adaptive = false
            }
        }
        let id = display.id
        brightnessObservers[id] = { newBrightness, _ in
            if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
                runInMainThread {
                    scrollableBrightness.integerValue = newBrightness.intValue
                    scrollableBrightness.setNeedsDisplay()
                }
            }
        }

        contrastObservers[id] = { newContrast, _ in
            if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
                runInMainThread {
                    scrollableContrast.integerValue = newContrast.intValue
                    scrollableContrast.setNeedsDisplay()
                }
            }
        }

        let oid = "displayValuesView-\(accessibilityIdentifier())"
        display.setObserver(prop: "brightness", key: oid, action: brightnessObservers[id]!)
        display.setObserver(prop: "contrast", key: oid, action: contrastObservers[id]!)
    }

    override func didAdd(_ rowView: NSTableRowView, forRow row: Int) {
        runInMainThread { [weak self] in
            self?.addRow(rowView, forRow: row)
        }
    }
}
