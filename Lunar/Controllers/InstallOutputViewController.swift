//
//  InstallOutputViewController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 03.04.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Regex

let NEW_HOSTNAME_PATTERN = try! Regex(pattern: "NEW_HOSTNAME=(\\S+)", groupNames: ["hostname"])

class OutputScrollView: NSScrollView {
    var onScroll: ((NSEvent) -> Void)?
    var onKeyDown: ((NSEvent) -> Void)?

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
        super.keyDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event)
        super.scrollWheel(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        guard let textView = documentView as? NSTextView, textView.isSelectable else { return }
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let textView = documentView as? NSTextView, textView.isSelectable else { return }
        super.rightMouseDown(with: event)
    }
}

class InstallOutputViewController: NSViewController {
    @objc dynamic var scrollAutomatically: Bool = true {
        didSet {
            if scrollAutomatically, let textView = outputScrollView.documentView as? NSTextView {
                textView.scrollToEndOfDocument(nil)
            }
        }
    }

    @objc dynamic var waitingForServer: Bool = false {
        didSet {
            if waitingForServer {
                waitingIndicator.startAnimation(nil)
            } else {
                waitingIndicator.stopAnimation(nil)
            }
        }
    }

    @objc dynamic var cancellingCommand: Bool = false {
        didSet {
            if cancellingCommand {
                cancellingIndicator.startAnimation(nil)
            } else {
                cancellingIndicator.stopAnimation(nil)
            }
        }
    }

    var commandChannel: Channel?

    @IBOutlet var outputScrollView: OutputScrollView!
    @IBOutlet var scrollAutomaticallyCheckbox: NSButton!
    @IBOutlet var waitingIndicator: NSProgressIndicator!
    @IBOutlet var cancellingIndicator: NSProgressIndicator!
    @IBOutlet var cancelButton: PaddedButton!

    func printNewHostname(new: String, old: String, textView: NSTextView) {
        if new != old {
            textView.string += "\n\nNOTE: The hostname has been changed from \(old) to \(new) to avoid name clashes\n\n"
        }
    }

    func startInstall(ssh: SSH) {
        asyncNow { [weak self] in
            guard let self = self, let textView = self.outputScrollView.documentView as? NSTextView else { return }
            var status: Int32 = -1
            var newHostname = ssh.host
            do {
                mainThread { textView.string += "[\(DDCUTIL_SERVER_INSTALLER_DIR)] ❯ sudo bash ./install.sh\n\n" }
                status = try ssh.execute(
                    "cd \(DDCUTIL_SERVER_INSTALLER_DIR); sudo bash ./install.sh 2>&1",
                    onChannelOpened: { channel in self.commandChannel = channel }
                ) { output in
                    mainThread {
                        textView.string += output
                        if let match = NEW_HOSTNAME_PATTERN.findFirst(in: output), let hostname = match.group(named: "hostname") {
                            newHostname = "\(hostname).local"
                        }
                        if self.scrollAutomatically { textView.scrollToEndOfDocument(nil) }
                    }
                }
            } catch {
                mainThread {
                    self.printNewHostname(new: newHostname, old: ssh.host, textView: textView)
                    textView.string += "\n\n\(error)"
                    self.commandChannel = nil
                }
                return
            }

            guard let channel = self.commandChannel, !channel.cancelled else {
                self.printNewHostname(new: newHostname, old: ssh.host, textView: textView)
                return
            }

            mainThread {
                if status != -1 {
                    textView.string += "\n\nStatus code: \(status)"
                }

                if status == 0 {
                    textView.string += "\nInstallation finished successfully!\n"
                    self.waitingForServer = true
                } else {
                    textView.string += "\nLooks like something went wrong.\n"
                }

                self.printNewHostname(new: newHostname, old: ssh.host, textView: textView)
                if self.scrollAutomatically { textView.scrollToEndOfDocument(nil) }
            }

            defer {
                mainThread {
                    self.waitingForServer = false
                    self.commandChannel = nil

                    textView.string += "\n\nYou can close this window now"
                    textView.string += "\nLunar will continue to check for new servers in the background"

                    if self.scrollAutomatically { textView.scrollToEndOfDocument(nil) }
                    self.commandChannel = nil
                }
            }

            var urlBuilder = URLComponents()
            urlBuilder.scheme = "http"
            urlBuilder.host = newHostname.contains(":") ? "[\(newHostname)]" : newHostname
            urlBuilder.port = 3485
            urlBuilder.path = "/displays"
            guard let url = urlBuilder.url else {
                mainThread {
                    textView.string += "\nCould not build a valid URL for host \(newHostname)"
                }
                return
            }

            mainThread {
                self.cancelButton.isHidden = true
            }

            sleep(4)
            guard let resp = waitForResponse(from: url, timeoutPerTry: 2.seconds, retries: 30, backoff: 1.1, sleepBetweenTries: 1) else {
                mainThread {
                    textView.string += "\nCould not get a response from \(newHostname)"
                }
                return
            }

            mainThread {
                if !resp.isEmpty {
                    textView.string += "\n\n\(resp)\n\n"
                }

                textView.string += "\nFound a new DDC server at \(newHostname):3485!"
                textView
                    .string +=
                    "\nIf this \(Sysctl.device) is connected to the same monitor as the Pi, you should receive a notification to confirm if Lunar should control the monitor through the Pi when it's available"
            }
        }
    }

    @IBAction func cancelInstall(_: Any) {
        asyncNow { [weak self] in
            guard let self = self, let channel = self.commandChannel,
                  let textView = self.outputScrollView.documentView as? NSTextView else { return }

            mainThread {
                self.cancellingCommand = true
            }

            do {
                mainThread { textView.string += "\nCancelling...\n" }
                try channel.cancel()
                mainThread { textView.string += "\n\nCancelled." }
            } catch {
                mainThread { textView.string += "\n\n\(error)" }
            }

            mainThread {
                self.commandChannel = nil
                self.cancellingCommand = false
                self.cancelButton?.isEnabled = false
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        waitingIndicator.appearance = NSAppearance(named: .vibrantDark)
        cancellingIndicator.appearance = NSAppearance(named: .vibrantDark)
        scrollAutomaticallyCheckbox.attributedTitle = scrollAutomaticallyCheckbox.title.withAttribute(.textColor(white))
        outputScrollView.scrollsDynamically = true
        outputScrollView.wantsLayer = true
        outputScrollView.appearance = NSAppearance(named: .vibrantDark)
        outputScrollView.radius = 14.0.ns

        outputScrollView.onScroll = { [weak self] event in
            if let self = self, self.scrollAutomatically, abs(event.scrollingDeltaY) > 1 {
                self.scrollAutomatically = false
            }
        }

        if let textView = outputScrollView.documentView as? NSTextView {
            textView.isEditable = false
            textView.font = monospace(size: 13)
            textView.string = "\n"
        }
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        cancelInstall(self)
    }
}
