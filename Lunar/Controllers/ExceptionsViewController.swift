//
//  ExceptionsViewController.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa
import Combine
import Defaults
import Paddle

final class ExceptionsViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var arrayController: NSArrayController!
    @IBOutlet var addAppButton: NSButton!
    var addAppButtonTrackingArea: NSTrackingArea!
    var addAppButtonShadow: NSShadow!
    var observer: Cancellable!

    @IBInspectable dynamic var appExceptions: [AppException] = datastore.appExceptions() ?? []

    @IBAction func addAppException(_: NSButton) {
        let dialog = NSOpenPanel()

        dialog.title = "Choose an application"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        if #available(OSX 11.0, *) {
            dialog.allowedContentTypes = [.application]
        } else {
            dialog.allowedFileTypes = ["app"]
        }
        dialog.treatsFilePackagesAsDirectories = false
        dialog.directoryURL = URL(string: "file:///Applications")

        guard dialog.runModal() == NSApplication.ModalResponse.OK,
              let res = dialog.url, let bundle = Bundle(url: res)
        else { return }

        guard let name = (bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?["CFBundleExecutable"] as? String),
              let id = bundle.bundleIdentifier
        else {
            log.warning("Bundle for \(res.path) does not contain required fields")
            return
        }

        if !(CachedDefaults[.appExceptions]?.contains(where: { $0.identifier == id }) ?? false) {
            let app = AppException(identifier: id, name: name)
            DataStore.storeAppException(app: app)
            acquirePrivileges(
                notificationTitle: "Lunar can now watch for app exceptions",
                notificationBody: "Whenever an app in the exception list is focused or visible on a screen, Lunar will apply its offsets."
            )
        }
    }

    func initAddAppButton() {
        if let button = addAppButton {
            let buttonSize = button.frame
            button.wantsLayer = true

            button.setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.width))
            button.radius = (button.frame.width / 2).ns
            button.bg = white
            button.alphaValue = 0.8

            addAppButtonShadow = button.shadow
            button.shadow = nil

            addAppButtonTrackingArea = NSTrackingArea(
                rect: button.visibleRect,
                options: [.mouseEnteredAndExited, .activeInActiveApp],
                owner: self,
                userInfo: nil
            )
            button.addTrackingArea(addAppButtonTrackingArea)
        }
    }

    override func mouseEntered(with _: NSEvent) {
        if let button = addAppButton {
            button.transition(0.5)
            button.alphaValue = 1.0
            button.shadow = addAppButtonShadow
        }
    }

    override func mouseExited(with _: NSEvent) {
        if let button = addAppButton {
            button.transition(1.0)
            button.alphaValue = 0.8
            button.shadow = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.headerView = nil
        initAddAppButton()
        observer = appExceptionsPublisher.sink { [weak self] change in
            guard let self, let newVal = change.newValue, newVal.count != self.appExceptions.count else {
                return
            }
            mainAsync { [weak self] in
                self?.setValue(datastore.appExceptions(), forKey: "appExceptions")
            }
        }
    }

    override func wantsScrollEventsForSwipeTracking(on axis: NSEvent.GestureAxis) -> Bool {
        axis == .horizontal
    }

    @IBAction func proButtonClick(_: Any) {
        if lunarProActive, !lunarProOnTrial {
            NSWorkspace.shared.open("https://lunar.fyi/pro".asURL()!)
            // } else if lunarProBadSignature {
            //     NSWorkspace.shared.open("https://lunar.fyi/download/latest".asURL()!)
        } else if let paddle, let producct {
            if producct.licenseCode != nil {
                deactivateLicense {
                    paddle.showProductAccessDialog(with: producct)
                }
            } else {
                paddle.showProductAccessDialog(with: producct)
            }
        }
    }
}
