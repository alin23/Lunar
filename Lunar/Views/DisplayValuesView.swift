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
    var minBrightnessObservers: [CGDirectDisplayID: (NSNumber, NSNumber) -> Void] = [:]
    var minContrastObservers: [CGDirectDisplayID: (NSNumber, NSNumber) -> Void] = [:]
    var maxBrightnessObservers: [CGDirectDisplayID: (NSNumber, NSNumber) -> Void] = [:]
    var maxContrastObservers: [CGDirectDisplayID: (NSNumber, NSNumber) -> Void] = [:]

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    func setAdaptiveButtonHidden(_ hidden: Bool) {
        enumerateAvailableRowViews { rowView, _ in
            if let nameCell = rowView.view(atColumn: 1) as? NSTableCellView,
               let display = nameCell.objectValue as? Display,
               let adaptiveButton = nameCell.subviews.first(where: { v in (v as? QuickAdaptiveButton) != nil }) as? QuickAdaptiveButton,
               display.active
            {
                mainThread { [weak adaptiveButton] in
                    adaptiveButton?.isHidden = hidden
                }
            }
        }
    }

    deinit {
        enumerateAvailableRowViews { rowView, _ in
            if let display = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? Display {
                let id = "displayValuesView-\(accessibilityIdentifier())"
                display.resetObserver(prop: .brightness, key: id, type: NSNumber.self)
                display.resetObserver(prop: .contrast, key: id, type: NSNumber.self)
            }
        }
    }

    func resetDeleteButtons() {
        enumerateAvailableRowViews { rowView, row in
            guard let display = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? Display,
                  let notConnectedTextField = (rowView.view(atColumn: 1) as? NSTableCellView)?.subviews.first(
                      where: { v in (v as? NotConnectedTextField) != nil }
                  ) as? NotConnectedTextField
            else {
                return
            }
            notConnectedTextField.onClick = getDeleteAction(displayID: display.id, row: row)
        }
    }

    func getResetAction(displayID: CGDirectDisplayID) -> (() -> Void) {
        return {
            mainThread { [weak self] in
                DDC.skipWritingPropertyById[displayID]?.removeAll()
                DDC.skipReadingPropertyById[displayID]?.removeAll()
                DDC.writeFaults[displayID]?.removeAll()
                DDC.readFaults[displayID]?.removeAll()
                displayController.displays[displayID]?.responsiveDDC = true
                self?.needsDisplay = true
            }
        }
    }

    func getDeleteAction(displayID: CGDirectDisplayID, row: Int) -> (() -> Void) {
        return {
            mainThread { [weak self] in
                guard let self = self else { return }
                self.beginUpdates()
                self.removeRows(at: [row], withAnimation: .effectFade)
                self.endUpdates()
                if let controller = self.superview?.superview?.nextResponder?.nextResponder as? MenuPopoverController {
                    mainAsyncAfter(ms: 200) {
                        POPOVERS[.menu]!!.animates = false
                        controller.adaptViewSize()
                        POPOVERS[.menu]!!.animates = true
                        self.resetDeleteButtons()
                    }
                }
            }
            displayController.removeDisplay(id: displayID)
        }
    }

    func removeRow(_ rowView: NSTableRowView, forRow _: Int) {
        guard let display = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? Display else {
            return
        }
        let id = "displayValuesView-\(accessibilityIdentifier())"
        display.resetObserver(prop: .brightness, key: id, type: NSNumber.self)
        display.resetObserver(prop: .contrast, key: id, type: NSNumber.self)

        brightnessObservers.removeValue(forKey: display.id)
        contrastObservers.removeValue(forKey: display.id)
    }

    override func didRemove(_ rowView: NSTableRowView, forRow row: Int) {
        mainThread { [weak self] in
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
              let scrollableContrast = (rowView.view(atColumn: 2) as? NSTableCellView)?.subviews[0] as? ScrollableTextField,
              let scrollableBrightnessCaption = (rowView.view(atColumn: 0) as? NSTableCellView)?.subviews[1] as? ScrollableTextFieldCaption,
              let scrollableContrastCaption = (rowView.view(atColumn: 2) as? NSTableCellView)?.subviews[1] as? ScrollableTextFieldCaption
        else { return }

        notConnectedTextField.onClick = getDeleteAction(displayID: display.id, row: row)
        adaptiveButton.setup(displayID: display.id)
        adaptiveButton.isHidden = !display.active || displayController.adaptiveModeKey == .manual

        scrollableBrightness.textFieldColor = textFieldColor
        scrollableBrightness.textFieldColorHover = textFieldColorHover
        scrollableBrightness.textFieldColorLight = textFieldColorLight
        scrollableBrightness.doubleValue = display.brightness.doubleValue.rounded()
        scrollableBrightness.caption = scrollableBrightnessCaption
        scrollableBrightness.lowerLimit = display.minBrightness.doubleValue
        scrollableBrightness.upperLimit = display.maxBrightness.doubleValue
        if !display.activeAndResponsive {
            scrollableBrightness.textColor = textFieldColorLight.blended(withFraction: 0.7, of: gray)?
                .shadow(withLevel: 0.3) ?? textFieldColor
        }

        scrollableContrast.textFieldColor = textFieldColor
        scrollableContrast.textFieldColorHover = textFieldColorHover
        scrollableContrast.textFieldColorLight = textFieldColorLight
        scrollableContrast.doubleValue = display.contrast.doubleValue.rounded()
        scrollableContrast.caption = scrollableContrastCaption
        scrollableContrast.lowerLimit = display.minContrast.doubleValue
        scrollableContrast.upperLimit = display.maxContrast.doubleValue
        if !display.activeAndResponsive {
            scrollableContrast.textColor = textFieldColorLight.blended(withFraction: 0.7, of: gray)?
                .shadow(withLevel: 0.3) ?? textFieldColor
        }

        scrollableBrightnessCaption.textColor = white
        scrollableContrastCaption.textColor = white
        scrollableBrightnessCaption.initialColor = white
        scrollableContrastCaption.initialColor = white

        scrollableBrightness.onValueChangedInstant = { [weak display] value in
            cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
            display?.insertBrightnessUserDataPoint(displayController.adaptiveMode.brightnessDataPoint.last, value, modeKey: displayController.adaptiveModeKey)
        }
        scrollableBrightness.onValueChanged = { [weak display] value in
            display?.brightness = value.ns
        }
        scrollableContrast.onValueChangedInstant = { [weak display] value in
            cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
            display?.insertContrastUserDataPoint(displayController.adaptiveMode.contrastDataPoint.last, value, modeKey: displayController.adaptiveModeKey)
        }
        scrollableContrast.onValueChanged = { [weak display] value in
            display?.contrast = value.ns
        }
        let id = display.id
        brightnessObservers[id] = { (newBrightness: NSNumber, _: NSNumber) in
            if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
                mainThread {
                    scrollableBrightness.integerValue = newBrightness.intValue
                    scrollableBrightness.needsDisplay = true
                }
            }
        }

        contrastObservers[id] = { (newContrast: NSNumber, _: NSNumber) in
            if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
                mainThread {
                    scrollableContrast.integerValue = newContrast.intValue
                    scrollableContrast.needsDisplay = true
                }
            }
        }

        minBrightnessObservers[id] = { (newBrightness: NSNumber, _: NSNumber) in
            if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
                mainThread {
                    scrollableBrightness.lowerLimit = newBrightness.doubleValue
                }
            }
        }

        minContrastObservers[id] = { (newContrast: NSNumber, _: NSNumber) in
            if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
                mainThread {
                    scrollableContrast.lowerLimit = newContrast.doubleValue
                }
            }
        }

        maxBrightnessObservers[id] = { (newBrightness: NSNumber, _: NSNumber) in
            if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
                mainThread {
                    scrollableBrightness.upperLimit = newBrightness.doubleValue
                }
            }
        }

        maxContrastObservers[id] = { (newContrast: NSNumber, _: NSNumber) in
            if id != GENERIC_DISPLAY_ID, id != TEST_DISPLAY_ID {
                mainThread {
                    scrollableContrast.upperLimit = newContrast.doubleValue
                }
            }
        }

        let oid = "displayValuesView-\(accessibilityIdentifier())"
        display.setObserver(prop: .brightness, key: oid, action: brightnessObservers[id]!)
        display.setObserver(prop: .contrast, key: oid, action: contrastObservers[id]!)
        display.setObserver(prop: .minBrightness, key: oid, action: minBrightnessObservers[id]!)
        display.setObserver(prop: .minContrast, key: oid, action: minContrastObservers[id]!)
        display.setObserver(prop: .maxBrightness, key: oid, action: maxBrightnessObservers[id]!)
        display.setObserver(prop: .maxContrast, key: oid, action: maxContrastObservers[id]!)
    }

    override func didAdd(_ rowView: NSTableRowView, forRow row: Int) {
        mainThread { [weak self] in
            self?.addRow(rowView, forRow: row)
        }
    }
}
