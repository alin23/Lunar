//
//  ScrollableValueController.swift
//  Lunar
//
//  Created by Alin on 25/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Combine
import Defaults

class ScrollableBrightness: NSView {
    @IBOutlet var label: NSTextField!
    @IBOutlet var minValue: ScrollableTextField!
    @IBOutlet var maxValue: ScrollableTextField!
    @IBOutlet var currentValue: ScrollableTextField!

    @IBOutlet var minValueCaption: ScrollableTextFieldCaption!
    @IBOutlet var maxValueCaption: ScrollableTextFieldCaption!
    @IBOutlet var currentValueCaption: ScrollableTextFieldCaption!

    @IBOutlet var lockButton: LockButton!

    var minObserver: Cancellable?
    var maxObserver: Cancellable?
    var onMinValueChanged: ((Int) -> Void)?
    var onMaxValueChanged: ((Int) -> Void)?
    var onCurrentValueChanged: ((Int) -> Void)?
    var disabled = false {
        didSet {
            minValue.isEnabled = !disabled
            maxValue.isEnabled = !disabled
        }
    }

    weak var display: Display? {
        didSet {
            if let d = display {
                update(from: d)
            }
        }
    }

    var name: String! {
        didSet {
            label?.stringValue = name
        }
    }

    var displayMinValue: Int {
        get {
            display?.minBrightness.intValue ?? 0
        }
        set {
            cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
            display?.minBrightness = newValue.ns
        }
    }

    var displayMaxValue: Int {
        get {
            display?.maxBrightness.intValue ?? 100
        }
        set {
            cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
            display?.maxBrightness = newValue.ns
        }
    }

    var displayValue: Int {
        get {
            display?.brightness.intValue ?? 50
        }
        set {
            cancelAsyncTask(SCREEN_WAKE_ADAPTER_TASK_KEY)
            display?.brightness = newValue.ns
        }
    }

    var displayObservers = Set<AnyCancellable>()

    func addObserver(_ display: Display) {
        display.$brightness.sink { [weak self] newBrightness in
            if let display = self?.display, display.id != GENERIC_DISPLAY_ID {
                let minBrightness = display.minBrightness.uint8Value
                let maxBrightness = display.maxBrightness.uint8Value

                let newBrightness = cap(newBrightness.uint8Value, minVal: minBrightness, maxVal: maxBrightness)
                mainThread {
                    self?.currentValue?.stringValue = String(newBrightness)
                }
            }
        }.store(in: &displayObservers)
    }

    func update(from display: Display) {
        minValue?.intValue = Int32(displayMinValue)
        minValue?.upperLimit = (displayMaxValue - 1).d
        maxValue?.intValue = Int32(displayMaxValue)
        maxValue?.lowerLimit = (displayMinValue + 1).d
        currentValue?.intValue = Int32(displayValue)
        currentValue?.lowerLimit = displayMinValue.d
        currentValue?.upperLimit = displayMaxValue.d

        if let button = lockButton {
            button.setup(display.lockedBrightness)
            if display.lockedBrightness {
                button.state = .on
            } else {
                button.state = .off
            }
        }

        addObserver(display)
    }

    deinit {
        for observer in displayObservers {
            observer.cancel()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
        lockButton?.setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        lockButton?.setup()
    }

    @IBAction func toggleLock(_ sender: LockButton) {
        switch sender.state {
        case .on:
            sender.bg = lockButtonBgOn
            display?.lockedBrightness = true
        case .off:
            sender.bg = lockButtonBgOff
            display?.lockedBrightness = false
        default:
            return
        }
        displayController.adaptBrightness()
    }

    func setup() {
        minValue?.onValueChangedInstant = minValue?.onValueChangedInstant ?? onMinValueChanged
        minValue?.onValueChanged = minValue?.onValueChanged ?? { [weak self] (value: Int) in
            guard let self = self else { return }

            self.maxValue?.lowerLimit = (value + 1).d
            self.currentValue?.lowerLimit = value.d
            self.currentValue.integerValue = max(self.currentValue.integerValue, value)
            if self.display != nil {
                self.displayMinValue = value
            }
        }
        maxValue?.onValueChangedInstant = maxValue?.onValueChangedInstant ?? onMaxValueChanged
        maxValue?.onValueChanged = maxValue?.onValueChanged ?? { [weak self] (value: Int) in
            guard let self = self else { return }

            self.minValue?.upperLimit = (value - 1).d
            self.currentValue?.upperLimit = value.d
            self.currentValue.integerValue = min(self.currentValue.integerValue, value)
            if self.display != nil {
                self.displayMaxValue = value
            }
        }

        currentValue?.onValueChangedInstant = currentValue?.onValueChangedInstant ?? onCurrentValueChanged
        currentValue?.onValueChanged = currentValue?.onValueChanged ?? { [weak self] (value: Int) in
            if self?.display != nil {
                self?.displayValue = value
            }
        }

        minValue?.caption = minValue?.caption ?? minValueCaption
        maxValue?.caption = maxValue?.caption ?? maxValueCaption
        currentValue?.caption = currentValue?.caption ?? currentValueCaption
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        setup()
    }
}
