//
//  ExceptionsView.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa
import Combine

let textFieldColor = sunYellow
let textFieldColorHover = sunYellow.blended(withFraction: 0.2, of: red) ?? textFieldColor
let textFieldColorLight = sunYellow.blended(withFraction: 0.4, of: red) ?? textFieldColor

// MARK: - DisplayValuesView

class DisplayValuesView: NSTableView {
    // MARK: Lifecycle

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif

        for (_, observers) in displayObservers {
            for observer in observers {
                observer.cancel()
            }
        }
    }

    // MARK: Internal

    var displayObservers: [CGDirectDisplayID: Set<AnyCancellable>] = [:]

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
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
            notConnectedTextField.onClick = getDeleteAction(displaySerial: display.serial, row: row)
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

    func getDeleteAction(displaySerial: String, row: Int) -> (() -> Void) {
        let action = {
            mainThread { [weak self] in
                guard let self = self else { return }
                self.removeRows(at: [row], withAnimation: .effectFade)
                if let controller = self.superview?.nextResponder as? MenuPopoverController {
                    mainAsyncAfter(ms: 200) {
                        POPOVERS["menu"]!!.animates = false
                        controller.adaptViewSize()
                        POPOVERS["menu"]!!.animates = true
                        self.resetDeleteButtons()
                    }
                }
            }
            displayController.removeDisplay(serial: displaySerial)
        }

        return action
    }

    func removeRow(_ rowView: NSTableRowView, forRow _: Int) {
        if let display = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? Display,
           let observers = displayObservers[display.id]
        {
            for observer in observers {
                observer.cancel()
            }
            displayObservers.removeValue(forKey: display.id)
        }

        guard let scrollableBrightness = (rowView.view(atColumn: 0) as? NSTableCellView)?.subviews[0] as? ScrollableTextField,
              let scrollableContrast = (rowView.view(atColumn: 2) as? NSTableCellView)?.subviews[0] as? ScrollableTextField
        else {
            return
        }

        scrollableBrightness.onValueChangedInstant = nil
        scrollableBrightness.onValueChanged = nil

        scrollableContrast.onValueChangedInstant = nil
        scrollableContrast.onValueChanged = nil
    }

    override func didRemove(_ rowView: NSTableRowView, forRow row: Int) {
        mainThread { [weak self] in
            self?.removeRow(rowView, forRow: row)
        }
    }

    func addRow(_ rowView: NSTableRowView, forRow row: Int) {
        guard let scrollableBrightness = (rowView.view(atColumn: 0) as? NSTableCellView)?.subviews[0] as? ScrollableTextField,
              let display = (rowView.view(atColumn: 1) as? NSTableCellView)?.objectValue as? Display,
              let inputDropdown = (rowView.view(atColumn: 1) as? NSTableCellView)?.subviews.first(
                  where: { v in (v as? PopUpButton) != nil }
              ) as? PopUpButton,
              let notConnectedTextField = (rowView.view(atColumn: 1) as? NSTableCellView)?.subviews.first(
                  where: { v in (v as? NotConnectedTextField) != nil }
              ) as? NotConnectedTextField,
              let scrollableContrast = (rowView.view(atColumn: 2) as? NSTableCellView)?.subviews[0] as? ScrollableTextField,
              let scrollableBrightnessCaption = (rowView.view(atColumn: 0) as? NSTableCellView)?.subviews[1] as? ScrollableTextFieldCaption,
              let scrollableContrastCaption = (rowView.view(atColumn: 2) as? NSTableCellView)?.subviews[1] as? ScrollableTextFieldCaption
        else { return }

        let id = display.id

        notConnectedTextField.onClick = getDeleteAction(displaySerial: display.serial, row: row)

        inputDropdown.isHidden = !display.active
        inputDropdown.isEnabled = display.active && displayController.adaptiveModeKey != .manual
        inputDropdown.page = .hotkeys
        inputDropdown.tag = id.i
        inputDropdown.fade()

        scrollableBrightness.textFieldColor = textFieldColor
        scrollableBrightness.textFieldColorHover = textFieldColorHover
        scrollableBrightness.textFieldColorLight = textFieldColorLight
        scrollableBrightness.integerValue = display.brightness.intValue
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
        scrollableContrast.integerValue = display.contrast.intValue
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

        scrollableBrightness.onValueChangedInstant = { value in
            cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
            display.insertBrightnessUserDataPoint(
                datapointLock.around { displayController.adaptiveMode.brightnessDataPoint.last },
                value,
                modeKey: displayController.adaptiveModeKey
            )
        }
        scrollableBrightness.onValueChanged = { value in
            display.brightness = value.ns
        }
        scrollableContrast.onValueChangedInstant = { value in
            cancelTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
            display.insertContrastUserDataPoint(
                datapointLock.around { displayController.adaptiveMode.contrastDataPoint.last },
                value,
                modeKey: displayController.adaptiveModeKey
            )
        }
        scrollableContrast.onValueChanged = { value in
            display.contrast = value.ns
        }

        if displayObservers[id] == nil {
            displayObservers[id] = []
        }

        guard var observers = displayObservers[id] else { return }

        display.$brightness.receive(on: dataPublisherQueue).sink { newBrightness in
            guard !isGeneric(id) else { return }
            mainThread {
                scrollableBrightness.integerValue = newBrightness.intValue
                scrollableBrightness.needsDisplay = true
            }
        }.store(in: &observers)

        display.$contrast.receive(on: dataPublisherQueue).sink { newContrast in
            guard !isGeneric(id) else { return }
            mainThread {
                scrollableContrast.integerValue = newContrast.intValue
                scrollableContrast.needsDisplay = true
            }
        }.store(in: &observers)

        display.$minBrightness.receive(on: dataPublisherQueue).sink { newBrightness in
            guard !isGeneric(id) else { return }
            mainThread {
                scrollableBrightness.lowerLimit = newBrightness.doubleValue
            }
        }.store(in: &observers)

        display.$minContrast.receive(on: dataPublisherQueue).sink { newContrast in
            guard !isGeneric(id) else { return }
            mainThread {
                scrollableContrast.lowerLimit = newContrast.doubleValue
            }
        }.store(in: &observers)

        display.$maxBrightness.receive(on: dataPublisherQueue).sink { newBrightness in
            guard !isGeneric(id) else { return }
            mainThread {
                scrollableBrightness.upperLimit = newBrightness.doubleValue
            }
        }.store(in: &observers)

        display.$maxContrast.receive(on: dataPublisherQueue).sink { newContrast in
            guard !isGeneric(id) else { return }
            mainThread {
                scrollableContrast.upperLimit = newContrast.doubleValue
            }
        }.store(in: &observers)
        display.$input.sink { [weak self] _ in
            self?.enumerateAvailableRowViews { rowView, _ in
                if let inputDropdown = (rowView.view(atColumn: 1) as? NSTableCellView)?.subviews.first(
                    where: { v in (v as? PopUpButton) != nil }
                ) as? PopUpButton, inputDropdown.tag == id {
                    mainAsyncAfter(ms: 1000) { inputDropdown.fade() }
                }
            }

        }.store(in: &observers)
    }

    func resizeInputs() {
        enumerateAvailableRowViews { rowView, _ in
            if let inputDropdown = (rowView.view(atColumn: 1) as? NSTableCellView)?.subviews.first(
                where: { v in (v as? PopUpButton) != nil }
            ) as? PopUpButton {
                inputDropdown.fade()
            }
        }
    }

    override func didAdd(_ rowView: NSTableRowView, forRow row: Int) {
        mainThread { [weak self] in
            self?.addRow(rowView, forRow: row)
        }
    }
}
