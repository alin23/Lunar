//
//  ProgressViewController.swift
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

    if shell("/sbin/ping", args: ["-o", "-t", "3", SENSOR_DEFAULT_HOSTNAME], timeout: 5.seconds).success {
        devicePaths.append(SENSOR_DEFAULT_HOSTNAME)
    }

    guard !devicePaths.isEmpty else {
        return [NO_DEVICE_AVAILABLE_ITEM]
    }
    return devicePaths
}

// MARK: - ALSInstallViewController

class ALSInstallViewController: NSViewController {
    // MARK: Lifecycle

    deinit {
        #if DEBUG
            log.debug("DEINIT")
        #endif
    }

    // MARK: Internal

    @objc dynamic var operationTitle: String = "Ambient Light Sensor"
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

    @objc dynamic var board: String = SELECT_BOARD_ITEM {
        didSet {
            setInstallButtonEnabled()
        }
    }

    var boardID: String {
        switch board {
        case "Metro ESP32 S2":
            return "metroesp32-s2"
        case "WEMOS LOLIN32":
            return "lolin32"
        case "WEMOS LOLIN32 Lite":
            return "lolin32_lite"
        case "NodeMCU ESP32":
            return "nodemcu-32s"
        case "Generic ESP32":
            return "esp32dev"

        case "NodeMCU v2 (ESP8266)":
            return "nodemcuv2"
        case "WEMOS D1 Mini (ESP8266)":
            return "d1_mini"
        case "WEMOS D1 Mini Lite (ESP8266)":
            return "d1_mini_lite"
        case "WEMOS D1 Mini Pro (ESP8266)":
            return "d1_mini_pro"
        case "SparkFun Thing (ESP8266)":
            return "thing"
        case "NodeMCU v1 (ESP8266)":
            return "nodemcu"
        case "Generic ESP8266":
            return "esp_wroom_02"
        default:
            return "esp32dev"
        }
    }

    @objc dynamic var device: String = SELECT_DEVICE_ITEM {
        didSet {
            setInstallButtonEnabled()
        }
    }

    @objc dynamic var done: Bool = false {
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
        guard let ssid = ssid, let password = password,
              let installScript = (try? Bundle.main.path(forResource: "install", ofType: "sh")?.realpath())?.string,
              let process = shell(
                  args: [installScript],
                  env: ["WIFI_SSID": ssid, "WIFI_PASSWORD": password, "ESP_DEVICE": device, "BOARD": boardID, "LOG_PATH": INSTALL_LOG_PATH]
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
            guard let self = self else {
                return
            }

            self.stopped = true
            if proc.terminationStatus == 0 {
                mainThread { self.done = true }
            } else {
                mainThread {
                    self.installButton?.attributedTitle = "View logs".withAttribute(.textColor(mauve))
                    self.installButton.bgColor = red
                    self.operationDescription = "Error installing the firmware!\nCheck the logs for more details.".attributedString
                    self.progressBar?.stopAnimation(nil)
                }
                self.onClick = { NSWorkspace.shared.openFile(INSTALL_LOG_PATH) }
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

        asyncEvery(1.seconds) { [weak self] (timer: Timer) in
            guard let self = self, !self.stopped else {
                timer.invalidate()
                return
            }

            guard let lastLines = fm
                .contents(atPath: INSTALL_LOG_PATH)?
                .split(separator: 0x0A)
                .suffix(3)
                .joined(separator: [0x0A])
            else { return }

            self.operationDescription = Data(lastLines).str().attributedString
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
    public func control(_ control: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
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
