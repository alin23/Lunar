//
//  ControlChoiceViewController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 01.10.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import CoreImage
import Foundation

// MARK: - GradientView

class GradientView: NSView {
    override var wantsDefaultClipping: Bool { false }
    @IBInspectable var firstColor: NSColor = .clear {
        didSet {
            updateView()
        }
    }

    @IBInspectable var secondColor: NSColor = .clear {
        didSet {
            updateView()
        }
    }

    func updateView() {
        let layer = CAGradientLayer()
        layer.colors = [firstColor, secondColor].map(\.cgColor)
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 0.45)
        if let blur = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 20]) {
            layer.filters = [blur]
        }
        layer.masksToBounds = false
        self.layer = layer
    }
}

// MARK: - LunarTestViewController

class LunarTestViewController: NSViewController {
    @IBOutlet var label: NSTextField!

    override func viewDidAppear() {
        asyncEvery(2.seconds, uniqueTaskKey: "lunarTestHighlighter") { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            mainThread {
                self.label.transition(1.5, easing: .easeInEaseOut)
                if self.label.textColor == .white {
                    self.label.textColor = darkMauve
                } else {
                    self.label.textColor = .white
                }
            }
        }
    }

    override func viewDidLoad() {
        label.textColor = .white
    }
}

// MARK: - ControlReadResult

struct ControlReadResult {
    let brightness: Bool
    let contrast: Bool

    var all: Bool { brightness && contrast }
}

// MARK: - ControlWriteResult

struct ControlWriteResult {
    let brightness: Bool
    let contrast: Bool

    var all: Bool { brightness && contrast }
}

// MARK: - ControlResult

struct ControlResult {
    let read: ControlReadResult
    let write: ControlWriteResult

    var all: Bool { read.all && write.all }
}

// MARK: - ControlChoiceViewController

class ControlChoiceViewController: NSViewController {
    @IBOutlet var displayImage: DisplayImage?

    @IBOutlet var _controlButton: NSButton!
    @IBOutlet var actionLabel: NSTextField!
    @IBOutlet var actionInfo: NSTextField!
    @IBOutlet var displayName: DisplayName!
    @IBOutlet var brightnessField: ScrollableTextField!
    @IBOutlet var contrastField: ScrollableTextField!

    @IBOutlet var brightnessCaption: NSTextField!
    @IBOutlet var contrastCaption: NSTextField!

    @IBOutlet var brightnessReadResult: NSTextField!
    @IBOutlet var contrastReadResult: NSTextField!
    @IBOutlet var brightnessWriteResult: NSTextField!
    @IBOutlet var contrastWriteResult: NSTextField!

    @IBOutlet var actionButton: Button!
    @IBOutlet var noButton: Button!
    @IBOutlet var yesButton: Button!

    var testWindowController: NSWindowController?

    var actionLabelColor = white.blended(withFraction: 0.2, of: lunarYellow)

    var controlButton: HelpButton? { _controlButton as? HelpButton }

    func info(_ text: String, color: NSColor) {
        mainThread {
            actionLabel.stringValue = text
            actionLabel.transition(0.5, easing: .easeInEaseOut)
            actionLabel.textColor = color
        }
        mainAsyncAfter(ms: 600) { [weak self] in
            guard let self = self else { return }
            self.actionLabel.transition(0.5, easing: .easeInEaseOut)
            self.actionLabel.textColor = self.actionLabelColor
        }
    }

    func hideAction() {
        mainThread {
            actionInfo.transition(0.8)
            actionInfo.alphaValue = 0.0

            actionButton.transition(0.8)
            actionButton.alphaValue = 0.0
            actionButton.isEnabled = false
        }
    }

    func hideQuestion() {
        mainThread {
            actionInfo.transition(0.8)
            actionInfo.alphaValue = 0.0

            noButton.transition(0.8)
            noButton.alphaValue = 0.0
            noButton.isEnabled = false

            yesButton.transition(0.8)
            yesButton.alphaValue = 0.0
            yesButton.isEnabled = false
        }
    }

    func ask(_ question: String, answer: @escaping ((Bool) -> Void)) {
        mainThread {
            actionInfo.stringValue = question
            actionInfo.transition(0.8)
            actionInfo.alphaValue = 1.0

            noButton.transition(0.8)
            noButton.alphaValue = 1.0
            noButton.isEnabled = true

            yesButton.transition(0.8)
            yesButton.alphaValue = 1.0
            yesButton.isEnabled = true
        }
        let semaphore = DispatchSemaphore(value: 0, name: "Onboarding question")

        noButton.onClick = { [weak self] in
            guard let self = self else { return }

            self.hideQuestion()
            semaphore.signal()
            answer(false)
        }
        yesButton.onClick = { [weak self] in
            guard let self = self else { return }

            self.hideQuestion()
            semaphore.signal()
            answer(true)
        }
        semaphore.wait(for: 0)
    }

    func setBrightness(_ brightness: Brightness) {
        mainThread {
            if brightnessField.alphaValue == 0 {
                brightnessField.transition(1.0)
                brightnessField.alphaValue = 1.0
                brightnessCaption.transition(1.0)
                brightnessCaption.alphaValue = 1.0
            }
        }
        for br in stride(
            from: brightnessField.integerValue,
            through: brightness.i,
            by: brightnessField.integerValue < brightness.i ? 1 : -1
        ) {
            mainThread { brightnessField.integerValue = br }
            Thread.sleep(forTimeInterval: 0.005)
        }
    }

    func setContrast(_ contrast: Contrast) {
        mainThread {
            if contrastField.alphaValue == 0 {
                contrastField.transition(1.0)
                contrastField.alphaValue = 1.0
                contrastCaption.transition(1.0)
                contrastCaption.alphaValue = 1.0
            }
        }

        for cr in stride(from: contrastField.integerValue, through: contrast.i, by: contrastField.integerValue < contrast.i ? 1 : -1) {
            mainThread { contrastField.integerValue = cr }
            Thread.sleep(forTimeInterval: 0.005)
        }
    }

    func setResult(_ resultControl: NSTextField, text: String, color: NSColor, transitionSpeed: TimeInterval = 1.5, alpha: Double = 1.0) {
        mainThread {
            resultControl.stringValue = text
            resultControl.textColor = color
            resultControl.transition(transitionSpeed)
            resultControl.alphaValue = alpha
        }
    }

    func waitForAction(_: String, buttonColor: NSColor, buttonText: NSAttributedString, action: @escaping (() -> Void)) {
        mainThread {
            actionInfo.stringValue = "Reading didn't work for some values\nWrite the missing values manually and click the Continue button"
            actionInfo.transition(0.5)
            actionInfo.alphaValue = 1.0

            actionButton.attributedTitle = buttonText
            actionButton.bg = buttonColor
            actionButton.transition(0.8)
            actionButton.alphaValue = 1.0
        }
        let semaphore = DispatchSemaphore(value: 0, name: "Onboarding action")
        actionButton.onClick = { [weak self] in
            guard let self = self else { return }
            self.hideAction()
            semaphore.signal()
            action()
        }
        semaphore.wait(for: 0)
    }

    func testControl(_ control: Control, for display: Display) -> ControlResult {
        let readWorked = testControlRead(control, for: display)
        Thread.sleep(forTimeInterval: 1)

        guard readWorked.all else {
            info("Waiting for input", color: peach)
            var writeWorked = ControlWriteResult(brightness: false, contrast: false)
            waitForAction(
                "Reading didn't work for some values\nWrite the missing values manually and click the Continue button",
                buttonColor: lunarYellow, buttonText: "Continue".withAttribute(.textColor(darkMauve))
            ) { [weak self] in
                guard let self = self else { return }
                writeWorked = self.testControlWrite(control, for: display)
            }
            return ControlResult(read: readWorked, write: writeWorked)
        }

        info("Starting write tests", color: peach)
        Thread.sleep(forTimeInterval: 3)
        let writeWorked = testControlWrite(control, for: display)
        return ControlResult(read: readWorked, write: writeWorked)
    }

    func testControlWrite(_ control: Control, for display: Display) -> ControlWriteResult {
        let currentBrightness = brightnessField.integerValue.u8
        let currentContrast = contrastField.integerValue.u8
        var brightnessWriteWorked = false
        var contrastWriteWorked = false

        info("Writing brightness", color: peach)
        Thread.sleep(forTimeInterval: 1.1)

        display.withBrightnessTransition {
            let write1Worked = control.setBrightness(
                0,
                oldValue: currentBrightness,
                onChange: { [weak self] br in self?.setBrightness(br) }
            )
            Thread.sleep(forTimeInterval: 3)
            let write2Worked = control.setBrightness(75, oldValue: 0, onChange: { [weak self] br in self?.setBrightness(br) })
            Thread.sleep(forTimeInterval: 3)
            let write3Worked = control.setBrightness(
                currentBrightness,
                oldValue: 75,
                onChange: { [weak self] br in self?.setBrightness(br) }
            )
            brightnessWriteWorked = (write1Worked.i + write2Worked.i + write3Worked.i) >= 2
        }

        if brightnessWriteWorked {
            setResult(brightnessWriteResult, text: "Write seemed to work", color: peach)
            ask("Was there any change in brightness on the tested display?") { [weak self] itWorked in
                guard let self = self else { return }
                if itWorked {
                    self.setResult(self.brightnessWriteResult, text: "Write worked", color: green)
                } else {
                    self.setResult(self.brightnessWriteResult, text: "Failed to write", color: red)
                }
            }
        } else {
            setResult(brightnessWriteResult, text: "Failed to write", color: red)
        }
        Thread.sleep(forTimeInterval: 1.1)

        info("Writing contrast", color: peach)
        Thread.sleep(forTimeInterval: 1.1)

        display.withBrightnessTransition {
            let write1Worked = control.setContrast(0, oldValue: currentContrast, onChange: { [weak self] br in self?.setContrast(br) })
            Thread.sleep(forTimeInterval: 3)
            let write2Worked = control.setContrast(75, oldValue: 0, onChange: { [weak self] br in self?.setContrast(br) })
            Thread.sleep(forTimeInterval: 3)
            let write3Worked = control.setContrast(currentContrast, oldValue: 75, onChange: { [weak self] br in self?.setContrast(br) })
            contrastWriteWorked = (write1Worked.i + write2Worked.i + write3Worked.i) >= 2
        }

        if contrastWriteWorked {
            setResult(contrastWriteResult, text: "Write seemed to work", color: peach)
            ask("Was there any change in contrast on the tested display?") { [weak self] itWorked in
                guard let self = self else { return }
                if itWorked {
                    self.setResult(self.contrastWriteResult, text: "Write worked", color: green)
                } else {
                    self.setResult(self.contrastWriteResult, text: "Failed to write", color: red)
                }
            }
        } else {
            setResult(contrastWriteResult, text: "Failed to write", color: red)
        }
        Thread.sleep(forTimeInterval: 1.1)

        _ = control.setBrightness(currentBrightness, oldValue: nil, onChange: nil)
        setBrightness(currentBrightness)

        _ = control.setContrast(currentContrast, oldValue: nil, onChange: nil)
        setContrast(currentContrast)

        return ControlWriteResult(brightness: brightnessWriteWorked, contrast: contrastWriteWorked)
    }

    func testControlRead(_ control: Control, for _: Display) -> ControlReadResult {
        var brightnessReadWorked = false
        var contrastReadWorked = false

        info("Reading brightness", color: peach)
        Thread.sleep(forTimeInterval: 1.1)
        if let br = control.getBrightness() {
            brightnessReadWorked = true
            setBrightness(br)
            Thread.sleep(forTimeInterval: 1.1)
            setResult(brightnessReadResult, text: "Read worked", color: green)
            Thread.sleep(forTimeInterval: 1.1)
        } else {
            setBrightness(0)
            Thread.sleep(forTimeInterval: 1.1)
            setResult(brightnessReadResult, text: "Failed to read", color: red)
            Thread.sleep(forTimeInterval: 1.1)
        }

        info("Reading contrast", color: peach)
        Thread.sleep(forTimeInterval: 1.1)
        if let cr = control.getContrast() {
            contrastReadWorked = true
            setContrast(cr)
            Thread.sleep(forTimeInterval: 1.1)
            setResult(contrastReadResult, text: "Read worked", color: green)
            Thread.sleep(forTimeInterval: 1.1)
        } else {
            setContrast(0)
            Thread.sleep(forTimeInterval: 1.1)
            setResult(contrastReadResult, text: "Failed to read", color: red)
            Thread.sleep(forTimeInterval: 1.1)
        }

        return ControlReadResult(brightness: brightnessReadWorked, contrast: contrastReadWorked)
    }

    func hideDisplayValues() {
        mainThread {
            brightnessField.alphaValue = 0
            brightnessCaption.alphaValue = 0
            contrastField.alphaValue = 0
            contrastCaption.alphaValue = 0

            brightnessReadResult.alphaValue = 0
            brightnessWriteResult.alphaValue = 0
            contrastReadResult.alphaValue = 0
            contrastWriteResult.alphaValue = 0
        }
    }

    override func viewDidAppear() {
        asyncNow { [weak self] in
            displayController.externalActiveDisplays.forEach { d in
                guard let self = self, let button = self.controlButton else { return }
                mainThread {
                    createWindow(
                        "testWindowController",
                        controller: &self.testWindowController,
                        screen: d.screen,
                        show: true,
                        backgroundColor: .clear,
                        level: .screenSaver,
                        fillScreen: false,
                        stationary: true
                    )
                    self.displayName.display = d
                }

                let networkControl = NetworkControl(display: d)
                let coreDisplayControl = AppleNativeControl(display: d)
                let ddcControl = DDCControl(display: d)
                let gammaControl = GammaControl(display: d)

                if coreDisplayControl.isAvailable() {
                    mainThread {
                        button.bg = green
                        button.attributedTitle = "Using Apple Native Protocol".withAttribute(.textColor(mauve))
                        button.helpText = NATIVE_CONTROLS_HELP_TEXT
                    }
                    self.testControl(coreDisplayControl, for: d)
                }
                if ddcControl.isAvailable() {
                    mainThread {
                        button.bg = darkMode ? peach : lunarYellow
                        button.attributedTitle = "Using DDC Protocol".withAttribute(.textColor(darkMauve))
                        button.helpText = HARDWARE_CONTROLS_HELP_TEXT
                    }
                    self.testControl(ddcControl, for: d)
                }
                if networkControl.isAvailable() {
                    mainThread {
                        button.bg = darkMode ? blue.highlight(withLevel: 0.2) : blue.withAlphaComponent(0.9)
                        button.attributedTitle = "Using DDC-over-Network Protocol".withAttribute(.textColor(.black))
                        button.helpText = NETWORK_CONTROLS_HELP_TEXT
                    }
                    self.testControl(networkControl, for: d)
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        hideDisplayValues()
        hideAction()
        hideQuestion()

        noButton.bg = red
        noButton.attributedTitle = "No".withAttribute(.textColor(white))
        yesButton.bg = green
        yesButton.attributedTitle = "Yes".withAttribute(.textColor(white))

        displayImage?.cornerRadius = 16
        displayImage?.standColor = peach
        displayImage?.screenColor = rouge

        actionLabel.textColor = actionLabelColor
    }
}
