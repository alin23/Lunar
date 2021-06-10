//
//  SSHConnectionViewController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.03.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Path

let SSH_DIR = Path.home / ".ssh"
let DDCUTIL_SERVER_INSTALLER_DIR = "/tmp/ddcutil-server"

@objc class SSHConnectionViewController: NSViewController {
    @IBOutlet var sshKeyCheckbox: NSButton!
    @objc dynamic var sshKeySelected: Bool = false {
        didSet {
            setInstallButtonEnabled()
        }
    }

    @objc dynamic var connecting: Bool = false {
        didSet {
            if connecting {
                connectingIndicator.startAnimation(nil)
                installButton.isEnabled = false
            } else {
                connectingIndicator.stopAnimation(nil)
                setInstallButtonEnabled()
            }
        }
    }

    @objc dynamic var cancellingCommand: Bool = false {
        didSet {
            if cancellingCommand {
                connectingIndicator.startAnimation(nil)
                installButton.isEnabled = false
                cancelButton.isEnabled = false
            } else {
                connectingIndicator.stopAnimation(nil)
                cancelButton.isEnabled = true
                setInstallButtonEnabled()
            }
        }
    }

    var sshKey: String?
    var sshKeyPath: Path? {
        didSet {
            setInstallButtonEnabled()
        }
    }

    @objc dynamic var hostname: String? = "raspberrypi.local" {
        didSet {
            setInstallButtonEnabled()
        }
    }

    @objc dynamic var username: String? = "pi" {
        didSet {
            setInstallButtonEnabled()
        }
    }

    @objc dynamic var port: String = "22"
    @objc dynamic var password: String? = "raspberry"
    @objc dynamic var passphrase: String?
    @objc dynamic var connectionMessage: String?

    @IBOutlet var chooseSSHKeyButton: PaddedButton!
    @IBOutlet var sshKeyMessage: NSTextField!
    @IBOutlet var installButton: PaddedButton!
    @IBOutlet var cancelButton: PaddedButton!
    @IBOutlet var connectingIndicator: NSProgressIndicator!
    var onInstall: ((SSH) -> Void)?
    var commandChannel: Channel?
    var cancelled = false

    override func viewDidLoad() {
        super.viewDidLoad()
        sshKeyCheckbox.attributedTitle = sshKeyCheckbox.title.withAttribute(.textColor(white))
        connectingIndicator.appearance = NSAppearance(named: .vibrantDark)
    }

    func setInstallButtonEnabled() {
        installButton.isEnabled = !(hostname?.isEmpty ?? true) && !(username?.isEmpty ?? true) && (sshKeySelected ? sshKeyPath != nil : true)
        installButton.fade()
    }

    @IBAction func chooseSSHKeyFile(_: Any) {
        let dialog = NSOpenPanel()

        dialog.title = "Choose a private SSH key file"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = true
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.treatsFilePackagesAsDirectories = false
        dialog.directoryURL = SSH_DIR.url

        guard dialog.runModal() == NSApplication.ModalResponse.OK,
              let result = dialog.url,
              let keyPath = Path(url: result)
        else {
            if sshKey == nil {
                sshKeyMessage.stringValue = "No key chosen"
            }
            return
        }

        guard keyPath.exists, let keyData = fm.contents(atPath: keyPath.string), let key = String(data: keyData, encoding: .utf8),
              key.contains("PRIVATE KEY--")
        else {
            sshKey = nil
            sshKeyPath = nil
            sshKeyMessage.stringValue = "The private key seems to be invalid"
            return
        }

        sshKey = key
        sshKeyPath = keyPath
        sshKeyMessage.stringValue = "Key: \(keyPath.basename())"
    }

    @IBAction func install(_: Any) {
        commitEditing()
        guard let hostname = hostname, let username = username else { return }
        if sshKeySelected, sshKeyPath == nil {
            return
        }

        let port = self.port.i32 ?? 22
        let passphrase = self.passphrase ?? ""
        let password = self.password ?? ""
        let sshKeyPath = self.sshKeyPath?.string ?? ""
        cancelled = false

        log.debug("Connecting to SSH", context: [
            "hostname": hostname,
            "port": port,
            "username": username,
            // "password": password,
            // "passphrase": passphrase,
            "sshKeyPath": sshKeyPath,
        ])

        async { [weak self] in
            guard let self = self, !self.cancelled else { return }

            mainThread {
                self.connecting = true
                self.connectionMessage = "Connecting to \(hostname):\(port)"
            }

            defer {
                mainThread {
                    self.connecting = false
                }
            }

            do {
                let ssh = try SSH(host: hostname, port: port)
                guard !self.cancelled else { return }

                mainThread {
                    self.connectionMessage = "Authenticating user '\(username)' with \(self.sshKeySelected ? "private key" : "password")"
                }
                if self.sshKeySelected {
                    try ssh.authenticate(username: username, privateKey: sshKeyPath, passphrase: passphrase)
                } else {
                    try ssh.authenticate(username: username, password: password)
                }

                guard !self.cancelled else { return }

                mainThread {
                    self.connectionMessage = "Downloading installer to '\(DDCUTIL_SERVER_INSTALLER_DIR)/'"
                }

                let status = try ssh.execute("""
                    mkdir -p \(DDCUTIL_SERVER_INSTALLER_DIR) 2>&1;
                    cd \(DDCUTIL_SERVER_INSTALLER_DIR) 2>&1;
                    curl -v -O https://static.lunar.fyi/ddcutil-server-installer.tar.gz 2>&1;
                    tar -xzvf ddcutil-server-installer.tar.gz 2>&1
                """, onChannelOpened: { channel in self.commandChannel = channel }) { output in
                    log.verbose(output)
                }

                guard let channel = self.commandChannel, !channel.cancelled else {
                    return
                }

                log.verbose("Download status: \(status)")

                mainThread {
                    self.connectionMessage = nil
                    self.commandChannel = nil
                    self.onInstall?(ssh)
                }
            } catch {
                log.error("Error connecting through SSH to \(hostname): \(error)")
                mainThread {
                    self.connectionMessage = String(describing: error)
                    self.commandChannel = nil
                }
                return
            }
        }
    }

    @IBAction func cancel(_: Any) {
        cancelled = true
        async { [weak self] in
            guard let self = self, let channel = self.commandChannel else { return }

            mainThread {
                self.cancellingCommand = true
            }

            do {
                mainThread { self.connectionMessage = "Cancelling" }
                try channel.cancel()
                mainThread { self.connectionMessage = "Cancelled" }
            } catch {
                mainThread { self.connectionMessage = "\(error)" }
            }

            mainThread {
                self.commandChannel = nil
                self.connecting = false
                self.cancellingCommand = false
            }
        }
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        cancel(self)
    }
}
