//
//  ExceptionsViewController.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa
import Crashlytics

class ExceptionsViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var arrayController: NSArrayController!
    @IBOutlet var brightnessColumn: NSTableColumn!
    @IBOutlet var contrastColumn: NSTableColumn!
    @IBOutlet var addAppButton: NSButton!
    var addAppButtonTrackingArea: NSTrackingArea!
    var addAppButtonShadow: NSShadow!

    @IBAction func addAppException(_: NSButton) {
        let dialog = NSOpenPanel()

        dialog.title = "Choose an application"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["app"]
        dialog.treatsFilePackagesAsDirectories = false
        dialog.directoryURL = URL(string: "file:///Applications")

        if dialog.runModal() == NSApplication.ModalResponse.OK {
            let result = dialog.url

            if let res = result {
                let bundle = Bundle(url: res)
                guard let name = bundle?.infoDictionary?["CFBundleName"] as? String,
                    let id = bundle?.bundleIdentifier else {
                    log.warning("Bundle for \(res.path) does not contain required fields")
                    return
                }
                if try! datastore.fetchAppException(by: id) == nil {
                    let app = AppException(identifier: id, name: name)
                    arrayController.addObject(app)
                    Answers.logCustomEvent(withName: "Added AppException", customAttributes: ["id": id, "name": name])
                }
            }
        } else {
            return
        }
    }

    func initAddAppButton() {
        if let button = addAppButton {
            let buttonSize = button.frame
            button.wantsLayer = true

            button.setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.width))
            button.layer?.cornerRadius = button.frame.width / 2
            button.layer?.backgroundColor = white.cgColor
            button.alphaValue = 0.8

            addAppButtonShadow = button.shadow
            button.shadow = nil

            addAppButtonTrackingArea = NSTrackingArea(rect: button.visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
            button.addTrackingArea(addAppButtonTrackingArea)
        }
    }

    override func mouseEntered(with _: NSEvent) {
        if let button = addAppButton {
            button.layer?.add(fadeTransition(duration: 0.1), forKey: "transition")
            button.alphaValue = 1.0
            button.shadow = addAppButtonShadow
        }
    }

    override func mouseExited(with _: NSEvent) {
        if let button = addAppButton {
            button.layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
            button.alphaValue = 0.8
            button.shadow = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        arrayController.managedObjectContext = datastore.context
        tableView.headerView = nil
        initAddAppButton()
    }
}
