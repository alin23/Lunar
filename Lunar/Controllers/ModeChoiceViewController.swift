//
//  ModeChoiceViewController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 01.10.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import SwiftyMarkdown

class ModeChoiceViewController: NSViewController {
    @IBOutlet var heading: NSTextField!
    @IBOutlet var subheading: NSTextField!

    @IBOutlet var syncBuiltin: PaddedButton!
    @IBOutlet var syncBuiltinNotice: NSTextField!

    @IBOutlet var syncSource: PaddedButton!
    @IBOutlet var syncSourceNotice: NSTextField!

    @IBOutlet var location: PaddedButton!
    @IBOutlet var locationNotice: NSTextField!

    @IBOutlet var clock: PaddedButton!
    @IBOutlet var clockNotice: NSTextField!

    @IBOutlet var sensor: PaddedButton!
    @IBOutlet var sensorNotice: NSTextField!

    lazy var markdown = getMarkdownRenderer()

    var buttonCount: CGFloat = 0

    func getMarkdownRenderer() -> SwiftyMarkdown {
        let md = getMD(dark: true)

        md.body.color = darkMauve
        md.body.fontSize = 16
        md.body.alignment = .center

        md.bold.color = mauve
        md.bold.fontSize = 16

        return md
    }

    func setupButton(_ button: PaddedButton, notice: NSTextField, color: NSColor, title: NSAttributedString, enabled: Bool) {
        button.alphaValue = 0
        notice.alphaValue = 0
        guard enabled else {
            button.isHidden = true
            notice.isHidden = true
            return
        }

        button.radius = 10
        button.bgColor = color

        button.setFrameOrigin(NSPoint(x: button.frame.origin.x, y: subheading.frame.minY))
        button.attributedTitle = title

        notice.setFrameOrigin(NSPoint(x: notice.frame.origin.x, y: subheading.frame.minY))

        let y = subheading.frame.minY - 74 - (buttonCount * (button.frame.height + notice.frame.height + 10))
        mainAsyncAfter(ms: 800) {
            button.transition(0.8)
            button.alphaValue = 0.85

            button.transition(1, type: .push)
            button.setFrameOrigin(NSPoint(
                x: button.frame.origin.x,
                y: y
            ))

            notice.transition(0.8)
            notice.alphaValue = 0.85

            notice.transition(1, type: .push)
            notice.setFrameOrigin(NSPoint(
                x: notice.frame.origin.x,
                y: button.frame.minY - 36
            ))
        }

        buttonCount += 1
    }

    override func viewDidLoad() {
        heading.alphaValue = 0
        subheading.alphaValue = 0

        let externals = displayController.externalActiveDisplays
        let externalName = displayController.externalActiveDisplays.count == 1 ? displayController.externalActiveDisplays[0]
            .name : "external monitors"
        setupButton(
            syncBuiltin,
            notice: syncBuiltinNotice,
            color: green,
            title: markdown
                .attributedString(
                    from: "**Sync** the brightness of your\n**\(Sysctl.device)** to your **\(externalName)**"
                ),
            enabled: SyncMode.specific.builtinAvailable
        )

        let source = externals.first { $0.isSmartDisplay && AppleNativeControl.isAvailable(for: $0) }
        let targets = externals.filter { source == nil || $0.serial != source!.serial }
        let sourceName = source?.name ?? "Source Display"
        let targetName =
            "\((targets.count == 1 && targets[0].name == sourceName) ? "other " : "")\(targets.count == 1 ? targets[0].name : "other external monitors")"
        setupButton(
            syncSource,
            notice: syncSourceNotice,
            color: green,
            title: markdown
                .attributedString(
                    from: "**Sync** the brightness of your\n**\(sourceName)** to your **\(targetName)**"
                ),
            enabled: source != nil
        )

        setupButton(
            location,
            notice: locationNotice,
            color: lunarYellow,
            title: markdown
                .attributedString(
                    from: "**Adapt** the brightness of your monitors\nbased on **sunrise** and **sunset**"
                ),
            enabled: true
        )

        setupButton(
            clock,
            notice: clockNotice,
            color: orange,
            title: markdown
                .attributedString(
                    from: "Schedule **presets** for changing the\n**brightness** at **predefined times**"
                ),
            enabled: true
        )

        setupButton(
            sensor,
            notice: sensorNotice,
            color: blue,
            title: markdown
                .attributedString(
                    from: "**Adapt** your **\(externalName)** based on readings\nfrom a wireless **ambient light sensor**"
                ),
            enabled: true
        )

        mainAsyncAfter(ms: 500) { [weak self] in
            guard let self = self else { return }
            self.heading.transition(0.3)
            self.heading.alphaValue = 1
        }
        mainAsyncAfter(ms: 800) { [weak self] in
            guard let self = self else { return }
            self.subheading.transition(0.8)
            self.subheading.alphaValue = 1
        }
        super.viewDidLoad()
    }
}
