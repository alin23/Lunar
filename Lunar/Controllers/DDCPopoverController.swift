import Atomics
import Cocoa
import Combine
import Defaults

// MARK: - DDCPopoverController

final class DDCPopoverController: NSViewController {
    var displayObservers = [String: AnyCancellable]()

    @IBOutlet var muteByteValueOnField: ScrollableTextField!
    @IBOutlet var muteByteValueOffField: ScrollableTextField!
    @IBOutlet var volumeValueOnMuteField: ScrollableTextField!

    @IBOutlet var maxDDCBrightnessField: ScrollableTextField!
    @IBOutlet var maxDDCContrastField: ScrollableTextField!
    @IBOutlet var maxDDCVolumeField: ScrollableTextField!

    @IBOutlet var minDDCBrightnessField: ScrollableTextField!
    @IBOutlet var minDDCContrastField: ScrollableTextField!
    @IBOutlet var minDDCVolumeField: ScrollableTextField!

    @IBOutlet var volumeOSDToggle: MacToggle!

    @objc dynamic weak var display: Display? {
        didSet {
            guard let display else {
                return
            }

            volumeOSDToggle.toggleWithoutCallback(value: display.showVolumeOSD)
        }
    }

    @IBAction func readColors(_ sender: ResetButton) {
        guard let display, display.hasI2C, let control = display.control, !control.isSoftware else {
            sender.attributedTitle = "DDC support needed".withAttribute(.textColor(sender.labelColor))
            return
        }

        display.refreshColors { success in
            mainAsyncAfter(ms: 1000) { [weak sender] in
                guard let sender else { return }
                let text = success ? "Values refreshed successfully" : "Monitor not responding"
                sender.attributedTitle = text.withAttribute(.textColor(sender.labelColor))
            }
        }
    }

    func setup(_ display: Display? = nil) {
        guard let display = display ?? self.display else { return }

        volumeOSDToggle.callback = { [weak self] isOn in
            guard let self, let display = self.display else { return }
            display.showVolumeOSD = isOn
        }
        display.$showVolumeOSD.sink { [weak self] value in
            guard let self else { return }
            volumeOSDToggle.toggleWithoutCallback(value: value)
        }.store(in: &displayObservers, for: "showVolumeOSD")

        mainAsync { [weak self] in
            guard let self else { return }
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

            muteByteValueOnField.integerValue = display.muteByteValueOn.i
            muteByteValueOffField.integerValue = display.muteByteValueOff.i
            volumeValueOnMuteField.integerValue = display.volumeValueOnMute.i

            muteByteValueOnField.lowerLimit = 0
            muteByteValueOnField.upperLimit = UInt16.max.d
            muteByteValueOffField.lowerLimit = 0
            muteByteValueOffField.upperLimit = UInt16.max.d
            volumeValueOnMuteField.lowerLimit = 0
            volumeValueOnMuteField.upperLimit = UInt16.max.d
        }

        muteByteValueOnField.onValueChanged = { [weak self] value in
            self?.display?.muteByteValueOn = value.u16
        }
        muteByteValueOffField.onValueChanged = { [weak self] value in
            self?.display?.muteByteValueOff = value.u16
        }
        volumeValueOnMuteField.onValueChanged = { [weak self] value in
            self?.display?.volumeValueOnMute = value.u16
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
            guard let self else { return }
            minDDCBrightnessField.integerValue = value.intValue
            maxDDCBrightnessField.lowerLimit = value.doubleValue
        }.store(in: &displayObservers, for: "minDDCBrightness")
        display.$minDDCContrast.sink { [weak self] value in
            guard let self else { return }
            minDDCContrastField.integerValue = value.intValue
            maxDDCContrastField.lowerLimit = value.doubleValue
        }.store(in: &displayObservers, for: "minDDCContrast")
        display.$minDDCVolume.sink { [weak self] value in
            guard let self else { return }
            minDDCVolumeField.integerValue = value.intValue
            maxDDCVolumeField.lowerLimit = value.doubleValue
        }.store(in: &displayObservers, for: "minDDCVolume")
        display.$maxDDCBrightness.sink { [weak self] value in
            guard let self else { return }
            maxDDCBrightnessField.integerValue = value.intValue
            minDDCBrightnessField.upperLimit = value.doubleValue
        }.store(in: &displayObservers, for: "maxDDCBrightness")
        display.$maxDDCContrast.sink { [weak self] value in
            guard let self else { return }
            maxDDCContrastField.integerValue = value.intValue
            minDDCContrastField.upperLimit = value.doubleValue
        }.store(in: &displayObservers, for: "maxDDCContrast")
        display.$maxDDCVolume.sink { [weak self] value in
            guard let self else { return }
            maxDDCVolumeField.integerValue = value.intValue
            minDDCVolumeField.upperLimit = value.doubleValue
        }.store(in: &displayObservers, for: "maxDDCVolume")

        display.$muteByteValueOn.sink { [weak self] value in
            guard let self else { return }
            muteByteValueOnField.integerValue = value.i
        }.store(in: &displayObservers, for: "muteByteValueOn")
        display.$muteByteValueOff.sink { [weak self] value in
            guard let self else { return }
            muteByteValueOffField.integerValue = value.i
        }.store(in: &displayObservers, for: "muteByteValueOff")
        display.$volumeValueOnMute.sink { [weak self] value in
            guard let self else { return }
            volumeValueOnMuteField.integerValue = value.i
        }.store(in: &displayObservers, for: "volumeValueOnMute")
    }
}

// MARK: - DDCButton

final class DDCButton: PopoverButton<DDCPopoverController> {
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
