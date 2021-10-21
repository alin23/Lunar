import Atomics
import Cocoa
import Combine
import Defaults

// MARK: - DDCPopoverController

class DDCPopoverController: NSViewController {
    var displayObservers = [String: AnyCancellable]()

    @IBOutlet var maxDDCBrightnessField: ScrollableTextField!
    @IBOutlet var maxDDCContrastField: ScrollableTextField!
    @IBOutlet var maxDDCVolumeField: ScrollableTextField!

    @IBOutlet var minDDCBrightnessField: ScrollableTextField!
    @IBOutlet var minDDCContrastField: ScrollableTextField!
    @IBOutlet var minDDCVolumeField: ScrollableTextField!

    @IBOutlet var volumeOSDToggle: MacToggle!

    @objc dynamic weak var display: Display? {
        didSet {
            guard let display = display else {
                return
            }

            volumeOSDToggle.toggleWithoutCallback(value: display.showVolumeOSD)
        }
    }

    @IBAction func readColors(_ sender: ResetButton) {
        guard let display = display, display.hasI2C, let control = display.control, !(control is GammaControl) else {
            sender.attributedTitle = "DDC support needed".withAttribute(.textColor(sender.labelColor))
            return
        }

        let success = display.refreshColors()
        mainAsyncAfter(ms: 1000) {
            let text = success ? "Values refreshed successfully" : "Monitor not responding"
            sender.attributedTitle = text.withAttribute(.textColor(sender.labelColor))
        }
    }

    func setup(_ display: Display? = nil) {
        guard let display = display ?? self.display else { return }

        volumeOSDToggle.callback = { [weak self] isOn in
            guard let self = self, let display = self.display else { return }
            display.showVolumeOSD = isOn
        }
        display.$showVolumeOSD.sink { [weak self] value in
            guard let self = self else { return }
            self.volumeOSDToggle.toggleWithoutCallback(value: value)
        }.store(in: &displayObservers, for: "showVolumeOSD")

        mainThread {
            minDDCBrightnessField.integerValue = display.minDDCBrightness.intValue
            minDDCContrastField.integerValue = display.minDDCContrast.intValue
            minDDCVolumeField.integerValue = display.minDDCVolume.intValue

            maxDDCBrightnessField.integerValue = display.maxDDCBrightness.intValue
            maxDDCContrastField.integerValue = display.maxDDCContrast.intValue
            maxDDCVolumeField.integerValue = display.maxDDCVolume.intValue

            minDDCBrightnessField.upperLimit = maxDDCBrightnessField.intValue.d
            maxDDCBrightnessField.lowerLimit = minDDCBrightnessField.intValue.d
            minDDCContrastField.upperLimit = maxDDCContrastField.intValue.d
            maxDDCContrastField.lowerLimit = minDDCContrastField.intValue.d
            minDDCVolumeField.upperLimit = maxDDCVolumeField.intValue.d
            maxDDCVolumeField.lowerLimit = minDDCVolumeField.intValue.d
        }

        minDDCBrightnessField.onValueChanged = { [weak self] value in
            self?.display?.minDDCBrightness = value.ns
            self?.maxDDCBrightnessField.lowerLimit = value.d
        }
        minDDCContrastField.onValueChanged = { [weak self] value in
            self?.display?.minDDCContrast = value.ns
            self?.maxDDCContrastField.lowerLimit = value.d
        }
        minDDCVolumeField.onValueChanged = { [weak self] value in
            self?.display?.minDDCVolume = value.ns
            self?.maxDDCVolumeField.lowerLimit = value.d
        }

        maxDDCBrightnessField.onValueChanged = { [weak self] value in
            self?.display?.maxDDCBrightness = value.ns
            self?.minDDCBrightnessField.upperLimit = value.d
        }
        maxDDCContrastField.onValueChanged = { [weak self] value in
            self?.display?.maxDDCContrast = value.ns
            self?.minDDCContrastField.upperLimit = value.d
        }
        maxDDCVolumeField.onValueChanged = { [weak self] value in
            self?.display?.maxDDCVolume = value.ns
            self?.minDDCVolumeField.upperLimit = value.d
        }

        display.$minDDCBrightness.sink { [weak self] value in
            guard let self = self else { return }
            self.minDDCBrightnessField.integerValue = value.intValue
            self.maxDDCBrightnessField.lowerLimit = value.doubleValue
        }.store(in: &displayObservers, for: "minDDCBrightness")
        display.$minDDCContrast.sink { [weak self] value in
            guard let self = self else { return }
            self.minDDCContrastField.integerValue = value.intValue
            self.maxDDCContrastField.lowerLimit = value.doubleValue
        }.store(in: &displayObservers, for: "minDDCContrast")
        display.$minDDCVolume.sink { [weak self] value in
            guard let self = self else { return }
            self.minDDCVolumeField.integerValue = value.intValue
            self.maxDDCVolumeField.lowerLimit = value.doubleValue
        }.store(in: &displayObservers, for: "minDDCVolume")
        display.$maxDDCBrightness.sink { [weak self] value in
            guard let self = self else { return }
            self.maxDDCBrightnessField.integerValue = value.intValue
            self.minDDCBrightnessField.upperLimit = value.doubleValue
        }.store(in: &displayObservers, for: "maxDDCBrightness")
        display.$maxDDCContrast.sink { [weak self] value in
            guard let self = self else { return }
            self.maxDDCContrastField.integerValue = value.intValue
            self.minDDCContrastField.upperLimit = value.doubleValue
        }.store(in: &displayObservers, for: "maxDDCContrast")
        display.$maxDDCVolume.sink { [weak self] value in
            guard let self = self else { return }
            self.maxDDCVolumeField.integerValue = value.intValue
            self.minDDCVolumeField.upperLimit = value.doubleValue
        }.store(in: &displayObservers, for: "maxDDCVolume")
    }
}

// MARK: - DDCButton

class DDCButton: PopoverButton<DDCPopoverController> {
    weak var display: Display? {
        didSet {
            popoverController?.display = display
            popoverController?.setup()
        }
    }

    override var popoverKey: String {
        "ddc"
    }

    override func mouseDown(with event: NSEvent) {
        popoverController?.display = display
        popoverController?.setup()
        super.mouseDown(with: event)
    }
}
