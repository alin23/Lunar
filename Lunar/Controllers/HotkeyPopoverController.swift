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
    @IBOutlet var hotkeyLabel1: NSBox!
    @IBOutlet var hotkeyView1: HotkeyView!
    @IBOutlet var dropdown1: NSPopUpButton!
    @IBOutlet var scrollableBrightnessField1: ScrollableTextField!
    @IBOutlet var scrollableContrastField1: ScrollableTextField!
    @IBOutlet var scrollableBrightnessCaption1: ScrollableTextFieldCaption!
    @IBOutlet var scrollableContrastCaption1: ScrollableTextFieldCaption!

    @IBOutlet var hotkeyLabel2: NSBox!
    @IBOutlet var hotkeyView2: HotkeyView!
    @IBOutlet var dropdown2: NSPopUpButton!
    @IBOutlet var scrollableBrightnessField2: ScrollableTextField!
    @IBOutlet var scrollableContrastField2: ScrollableTextField!
    @IBOutlet var scrollableBrightnessCaption2: ScrollableTextFieldCaption!
    @IBOutlet var scrollableContrastCaption2: ScrollableTextFieldCaption!

    @IBOutlet var hotkeyLabel3: NSBox!
    @IBOutlet var hotkeyView3: HotkeyView!
    @IBOutlet var dropdown3: NSPopUpButton!
    @IBOutlet var scrollableBrightnessField3: ScrollableTextField!
    @IBOutlet var scrollableContrastField3: ScrollableTextField!
    @IBOutlet var scrollableBrightnessCaption3: ScrollableTextFieldCaption!
    @IBOutlet var scrollableContrastCaption3: ScrollableTextFieldCaption!

    @IBOutlet var backingView: NSView!

    var onClick: (() -> Void)?
    var onDropdownSelect: ((NSPopUpButton) -> Void)?
    weak var display: Display?

    func setup(from display: Display) {
        self.display = display

        scrollableBrightnessField1.integerValue = display.brightnessOnInputChange1.intValue
        scrollableContrastField1.integerValue = display.contrastOnInputChange1.intValue
        scrollableBrightnessField1.onValueChanged = { [weak self] value in
            guard let self = self else { return }
            self.display?.brightnessOnInputChange1 = value.ns
        }
        scrollableContrastField1.onValueChanged = { [weak self] value in
            guard let self = self else { return }
            self.display?.contrastOnInputChange1 = value.ns
        }

        scrollableBrightnessField2.integerValue = display.brightnessOnInputChange2.intValue
        scrollableContrastField2.integerValue = display.contrastOnInputChange2.intValue
        scrollableBrightnessField2.onValueChanged = { [weak self] value in
            guard let self = self else { return }
            self.display?.brightnessOnInputChange2 = value.ns
        }
        scrollableContrastField2.onValueChanged = { [weak self] value in
            guard let self = self else { return }
            self.display?.contrastOnInputChange2 = value.ns
        }

        scrollableBrightnessField3.integerValue = display.brightnessOnInputChange3.intValue
        scrollableContrastField3.integerValue = display.contrastOnInputChange3.intValue
        scrollableBrightnessField3.onValueChanged = { [weak self] value in
            guard let self = self else { return }
            self.display?.brightnessOnInputChange3 = value.ns
        }
        scrollableContrastField3.onValueChanged = { [weak self] value in
            guard let self = self else { return }
            self.display?.contrastOnInputChange3 = value.ns
        }
    }

    override func viewDidLoad() {
        backingView.radius = 8.ns

        scrollableBrightnessField1.caption = scrollableBrightnessCaption1
        scrollableContrastField1.caption = scrollableContrastCaption1

        scrollableBrightnessField2.caption = scrollableBrightnessCaption2
        scrollableContrastField2.caption = scrollableContrastCaption2

        scrollableBrightnessField3.caption = scrollableBrightnessCaption3
        scrollableContrastField3.caption = scrollableContrastCaption3

        scrollableBrightnessField1.onValueChanged = { [weak self] in self?.display?.brightnessOnInputChange1 = $0.ns }
        scrollableContrastField1.onValueChanged = { [weak self] in self?.display?.contrastOnInputChange1 = $0.ns }

        scrollableBrightnessField2.onValueChanged = { [weak self] in self?.display?.brightnessOnInputChange2 = $0.ns }
        scrollableContrastField2.onValueChanged = { [weak self] in self?.display?.contrastOnInputChange2 = $0.ns }

        scrollableBrightnessField3.onValueChanged = { [weak self] in self?.display?.brightnessOnInputChange3 = $0.ns }
        scrollableContrastField3.onValueChanged = { [weak self] in self?.display?.contrastOnInputChange3 = $0.ns }

        if let display = display {
            scrollableBrightnessField1.integerValue = display.brightnessOnInputChange1.intValue
            scrollableContrastField1.integerValue = display.contrastOnInputChange1.intValue

            scrollableBrightnessField2.integerValue = display.brightnessOnInputChange2.intValue
            scrollableContrastField2.integerValue = display.contrastOnInputChange2.intValue

            scrollableBrightnessField3.integerValue = display.brightnessOnInputChange3.intValue
            scrollableContrastField3.integerValue = display.contrastOnInputChange3.intValue
        }

        for field in [
            scrollableBrightnessField1, scrollableContrastField1,
            scrollableBrightnessField2, scrollableContrastField2,
            scrollableBrightnessField3, scrollableContrastField3,
        ] {
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
