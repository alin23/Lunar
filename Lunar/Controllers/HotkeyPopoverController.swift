//
//  HotkeyPopoverController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 23.12.2020.
//  Copyright © 2020 Alin. All rights reserved.
//

import Cocoa
import Defaults
import Foundation

class HotkeyPopoverController: NSViewController {
    @IBOutlet var hotkeyLabel: NSTextField!
    @IBOutlet var hotkeyView: HotkeyView!
    @IBOutlet var dropdown: NSPopUpButton!
    @IBOutlet var scrollableBrightnessField: ScrollableTextField!
    @IBOutlet var scrollableContrastField: ScrollableTextField!
    @IBOutlet var scrollableBrightnessCaption: ScrollableTextFieldCaption!
    @IBOutlet var scrollableContrastCaption: ScrollableTextFieldCaption!
    @IBOutlet var backingView: NSView!

    var onClick: (() -> Void)?
    var onDropdownSelect: ((NSPopUpButton) -> Void)?
    weak var display: Display?

    func setup(from display: Display) {
        self.display = display
        scrollableBrightnessField.integerValue = display.brightnessOnInputChange.intValue
        scrollableContrastField.integerValue = display.contrastOnInputChange.intValue
        scrollableBrightnessField.onValueChanged = { display.brightnessOnInputChange = $0.ns }
        scrollableContrastField.onValueChanged = { display.contrastOnInputChange = $0.ns }
    }

    override func viewDidLoad() {
        backingView.radius = 8.ns

        scrollableBrightnessField.caption = scrollableBrightnessCaption
        scrollableContrastField.caption = scrollableContrastCaption
        scrollableBrightnessField.integerValue = CachedDefaults[.brightnessOnInputChange]
        scrollableContrastField.integerValue = CachedDefaults[.contrastOnInputChange]
        scrollableBrightnessField.onValueChanged = { CachedDefaults[.brightnessOnInputChange] = $0 }
        scrollableContrastField.onValueChanged = { CachedDefaults[.contrastOnInputChange] = $0 }

        for field in [scrollableBrightnessField, scrollableContrastField] {
            field!.textFieldColor = scrollableTextFieldColorOnBlack
            field!.textFieldColorHover = scrollableTextFieldColorHoverOnBlack
            field!.textFieldColorLight = scrollableTextFieldColorLightOnBlack
            field!.caption!.textColor = scrollableCaptionColorOnBlack
        }

        super.viewDidLoad()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        view.window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }

    @IBAction func selectItem(_ sender: NSPopUpButton) {
        onDropdownSelect?(sender)
    }
}
