//
//  ALSInstallViewController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25.04.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Glob

let NO_DEVICE_AVAILABLE_ITEM = "No device available"
let SELECT_DEVICE_ITEM = "Select a device"
let SELECT_BOARD_ITEM = "Select a dev board"
let INSTALL_LOG_PATH = "/tmp/lunar-sensor-install.log"

func getDevices() -> [String] {
    var devicePaths = Glob(pattern: "/dev/cu.usb*").filter { portPath in
        !IGNORED_SERIAL_PORTS.contains(portPath)
    }

    #if DEBUG
        devicePaths.append("/dev/cu.usbserial-110")
    #endif

    if shell("/sbin/ping", args: ["-o", "-t", "3", CachedDefaults[.sensorHostname]], timeout: 5.seconds).success {
        devicePaths.append(CachedDefaults[.sensorHostname])
    }

    guard !devicePaths.isEmpty else {
        return [NO_DEVICE_AVAILABLE_ITEM]
    }
    return devicePaths
}

enum AmbientLightSensor: String, CaseIterable {
    case bh1750
    case ltr390
    case max44009
    case tcs34725
    case tsl2561
    case tsl2591
}

// MARK: - ALSInstallViewController

final class ALSInstallViewController: NSViewController {
    deinit {
        #if DEBUG
            log.debug("DEINIT")
        #endif
    }

    @objc dynamic var operationTitle = "Ambient Light Sensor"
    @objc dynamic var operationDescription: NSAttributedString =
        "Your WiFi credentials will be programmed into the sensor firmware so it can connect to your local network and send lux values when requested."
            .attributedString
    @IBOutlet var progressBar: NSProgressIndicator!
    @IBOutlet var installButton: PaddedButton!

    var installProcess: Process?
    var stopped = true

    @objc dynamic var devices: [String] = []

    lazy var onClick: (() -> Void)? = { [weak self] in
        self?.startFirmwareInstallation()
    }

    var installFinishChecker: Repeater?

    @objc dynamic var sensor = "TSL2591"
    @objc dynamic var sda = "GPIO4"
    @objc dynamic var scl = "GPIO5"

    @objc dynamic var board: String = SELECT_BOARD_ITEM {
        didSet {
            setInstallButtonEnabled()
            setPins()
        }
    }

    var boardID: String {
        switch board {
        // ESP32-S2
        case "Metro ESP32 S2":
            "adafruit_metro_esp32s2"
        case "SparkFun Thing Plus ESP32 S2":
            "sparkfun_esp32s2_thing_plus"
        case "Feather ESP32 S2":
            "featheresp32-s2"
        case "Feather ESP32 S2 TFT":
            "adafruit_feather_esp32s2_tft"
        case "Feather ESP32 S2 Reverse TFT":
            "adafruit_feather_esp32s2_reversetft"
        case "MagTag ESP32 S2":
            "adafruit_magtag29_esp32s2"
        case "Funhouse ESP32 S2":
            "adafruit_funhouse_esp32s2"
        case "NodeMCU ESP32 S2":
            "nodemcu-32s2"
        // ESP32
        case "Adafruit HUZZAH32 Feather ESP32":
            "featheresp32"
        case "WEMOS LOLIN32":
            "lolin32"
        case "WEMOS LOLIN32 Lite":
            "lolin32_lite"
        case "NodeMCU ESP32":
            "nodemcu-32s"
        case "Generic ESP32":
            "esp32dev"
        // ESP8266
        case "NodeMCU v2 (ESP8266)":
            "nodemcuv2"
        case "NodeMCU v3 (ESP8266)":
            "nodemcuv2"
        case "WEMOS D1 Mini (ESP8266)":
            "d1_mini"
        case "WEMOS D1 Mini Lite (ESP8266)":
            "d1_mini_lite"
        case "WEMOS D1 Mini Pro (ESP8266)":
            "d1_mini_pro"
        case "SparkFun Thing (ESP8266)":
            "thing"
        case "NodeMCU v1 (ESP8266)":
            "nodemcu"
        case "Generic ESP8266":
            "esp_wroom_02"
        default:
            "esp32dev"
        }
    }

    @objc dynamic var device: String = SELECT_DEVICE_ITEM {
        didSet {
            setInstallButtonEnabled()
        }
    }

    @objc dynamic var done = false {
        didSet {
            if done {
                mainThread {
                    stopped = true
                    installButton?.attributedTitle = "Done".withAttribute(.textColor(white))
                    installButton.bgColor = blue
                    progressBar.stopAnimation(nil)
                    operationDescription = DARK_MD
                        .attributedString(
                            from: "**Firmware was installed successfully!**\nIf the WiFi credentials were correct, Lunar should enable `Sensor Mode` when the sensor is detected on the local network."
                        )
                }
                onClick = { [weak self] in self?.view.window?.close() }
            }
        }
    }

    @objc dynamic var ssid: String? = "WiFi" {
        didSet {
            setInstallButtonEnabled()
        }
    }

    @objc dynamic var password: String? = "xxxxxxxxx" {
        didSet {
            setInstallButtonEnabled()
        }
    }

    func setPins() {
        switch boardID {
        case "sparkfun_esp32s2_thing_plus":
            sda = "01"
            scl = "02"
        case "featheresp32-s2", "adafruit_feather_esp32s2_reversetft":
            sda = "03"
            scl = "04"
        case "adafruit_funhouse_esp32s2":
            sda = "34"
            scl = "33"
        case "adafruit_feather_esp32s2_tft":
            sda = "42"
            scl = "41"
        case "nodemcu-32s2":
            sda = "08"
            scl = "09"
        case "adafruit_metro_esp32s2", "adafruit_magtag29_esp32s2":
            sda = "33"
            scl = "34"
        case "nodemcuv2", "d1_mini", "d1_mini_lite", "d1_mini_pro", "nodemcu":
            sda = "D2"
            scl = "D1"
        case "esp32dev", "lolin32", "lolin32_lite", "nodemcu-32s":
            sda = "19"
            scl = "23"
        default:
            sda = "GPIO4"
            scl = "GPIO5"
        }
    }

    @IBAction func viewLogs(_: Any) {
        NSWorkspace.shared.open(URL(fileURLWithPath: INSTALL_LOG_PATH))
    }

    @IBAction func onDoneClicked(_: Any) {
        onClick?()
    }

    func setInstallButtonEnabled() {
        installButton.isEnabled = (
            !(ssid?.isEmpty ?? true) &&
                !(password?.isEmpty ?? true) &&
                board != SELECT_BOARD_ITEM &&
                device != SELECT_DEVICE_ITEM &&
                device != NO_DEVICE_AVAILABLE_ITEM
        )
        installButton.fade()
    }

    func cancelFirmwareInstallation() {
        installProcess?.terminationHandler = nil
        installProcess?.terminate()

        mainThread {
            stopped = true
            installButton?.attributedTitle = "Start".withAttribute(.textColor(mauve))
            installButton.bgColor = lunarYellow
            progressBar?.stopAnimation(nil)
        }
        onClick = { [weak self] in
            self?.startFirmwareInstallation()
        }
    }

    func startFirmwareInstallation() {
        guard let ssid, let password,
              let installScript = (try? Bundle.main.path(forResource: "install", ofType: "sh")?.realpath()),
              let process = shellProc(
                  args: [installScript.string],
                  env: [
                      "DIR": installScript.parent.string,
                      "WIFI_SSID": ssid,
                      "WIFI_PASSWORD": password,
                      "ESP_DEVICE": device,
                      "BOARD": boardID,
                      "LOG_PATH": INSTALL_LOG_PATH,
                      "SENSOR": sensor.lowercased(),
                      "SDA": sda,
                      "SCL": scl,
                  ]
              )
        else {
            mainThread {
                stopped = true
                installButton?.attributedTitle = "Error!".withAttribute(.textColor(mauve))
                installButton.bgColor = red
                progressBar?.stopAnimation(nil)
                operationDescription = DARK_MD
                    .attributedString(from: "Please contact the developer about this.\n[Contact Page](\(contactURL().absoluteString))")
            }
            onClick = { NSWorkspace.shared.open(contactURL()) }
            return
        }

        installProcess = process
        installProcess?.terminationHandler = { [weak self] proc in
            guard let self else {
                return
            }

            stopped = true
            if proc.terminationStatus == 0 {
                mainThread { self.done = true }
            } else {
                mainThread {
                    self.installButton?.attributedTitle = "View logs".withAttribute(.textColor(mauve))
                    self.installButton.bgColor = red
                    self.operationDescription = "Error installing the firmware!\nCheck the logs for more details.".attributedString
                    self.progressBar?.stopAnimation(nil)
                }
                onClick = { NSWorkspace.shared.open(URL(fileURLWithPath: INSTALL_LOG_PATH)) }
            }
        }

        mainThread {
            stopped = false
            installButton?.attributedTitle = "Cancel".withAttribute(.textColor(mauve))
            installButton.bgColor = red
            progressBar?.startAnimation(nil)
        }
        onClick = { [weak self] in
            self?.cancelFirmwareInstallation()
        }

        installFinishChecker = Repeater(every: 1, name: "ALSInstallFinishChecker") { [weak self] in
            guard let self, !self.stopped else {
                self?.installFinishChecker = nil
                return
            }

            guard let lastLines = fm
                .contents(atPath: INSTALL_LOG_PATH)?
                .split(separator: 0x0A)
                .suffix(3)
                .joined(separator: [0x0A])
            else { return }

            operationDescription = Data(lastLines).str().attributedString
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mainAsyncAfter(ms: 100) { [weak self] in
            self?.devices = getDevices()
            log.debug("Available sensor devices: \(self?.devices ?? [])")
        }

        view.wantsLayer = true
        view.radius = 12.0.ns
        view.bg = darkMauve
        progressBar?.appearance = NSAppearance(named: .vibrantDark)

        installButton?.bgColor = lunarYellow
        installButton?.radius = 10.ns
        installButton?.frame = NSRect(origin: installButton.frame.origin, size: CGSize(width: installButton.frame.width, height: 30))
        installButton?.attributedTitle = "Start".withAttribute(.textColor(mauve))
        operationDescription =
            "Your WiFi credentials will be programmed into the sensor firmware so it can connect to your local network and send lux values when requested."
                .attributedString
    }
}

// MARK: NSControlTextEditingDelegate

extension ALSInstallViewController: NSControlTextEditingDelegate {
    func control(_ control: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.moveDown(_:)):
            control.window?.makeFirstResponder(control.nextKeyView)
            return true
        default:
            return false
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField else {
            return
        }

        switch textField.tag {
        case 1:
            ssid = textField.stringValue
            #if DEBUG
                let text = ssid ?? ""
                log.verbose("SSID: \(text)")
            #endif
        case 2:
            password = textField.stringValue
            #if DEBUG
                let text = ssid ?? ""
                log.verbose("PASSWORD: \(text)")
            #endif
        default:
            break
        }
    }
}
