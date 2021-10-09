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

    @IBOutlet var manual: PaddedButton!
    @IBOutlet var manualNotice: NSTextField!

    lazy var markdown = getMarkdownRenderer()
    lazy var lightMarkdown = getMarkdownRenderer(color: white)

    var buttonCount: CGFloat = 0

    func getMarkdownRenderer(color: NSColor? = nil) -> SwiftyMarkdown {
        let md = getMD(dark: true)

        md.body.color = color ?? darkMauve
        md.body.fontSize = 15
        md.body.alignment = .center

        md.bold.color = color ?? mauve
        md.bold.fontSize = 15

        return md
    }

    func setupButton(
        _ button: PaddedButton,
        notice: NSTextField,
        color: NSColor,
        title: NSAttributedString,
        enabled: Bool,
        action: Selector
    ) {
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

        button.target = self
        button.action = action

        notice.setFrameOrigin(NSPoint(x: notice.frame.origin.x, y: subheading.frame.minY))

//        let y = subheading.frame.minY - 74 - (buttonCount * (button.frame.height + notice.frame.height + 10))
        let y = subheading.frame.minY - 74 - (buttonCount * (button.frame.height + 10))
        let transitionTime = 0.6 + 0.1 * buttonCount
        mainAsyncAfter(ms: 1800) {
            button.transition(0.8)
            button.alphaValue = 0.85

            button.transition(transitionTime, type: .push)
            button.setFrameOrigin(NSPoint(
                x: button.frame.origin.x,
                y: y
            ))

//            notice.transition(0.8)
//            notice.alphaValue = 0.85

            notice.transition(1, type: .push)
            notice.setFrameOrigin(NSPoint(
                x: notice.frame.origin.x,
                y: button.frame.minY - 36
            ))
        }

        buttonCount += 1
    }

    func next() {
        guard let pageController = view.superview?.nextResponder as? OnboardPageController else { return }
        pageController.navigateForward(self)
    }

    @objc func syncBuiltinClick() {
        guard let builtin = displayController.builtinDisplay else { return }
        builtin.isSource = true
        displayController.displays.values
            .filter { $0.serial != builtin.serial }
            .forEach { d in
                d.isSource = false
                d.brightnessCurveFactors[.sync] = DEFAULT_SYNC_BRIGHTNESS_CURVE_FACTOR
                d.contrastCurveFactors[.sync] = DEFAULT_SYNC_CONTRAST_CURVE_FACTOR
                d.userContrast[.sync]?.removeAll()
                d.userBrightness[.sync]?.removeAll()
                d.lockedBrightnessCurve = false
                d.lockedContrastCurve = false
            }

        CachedDefaults[.overrideAdaptiveMode] = true
        displayController.adaptiveMode = SyncMode.specific
        next()
    }

    @objc func syncSourceClick() {
        let externals = displayController.externalActiveDisplays
        guard let source = externals.first(where: { $0.isSmartDisplay && AppleNativeControl.isAvailable(for: $0) })
        else { return }

        source.isSource = true
        displayController.displays.values
            .filter { $0.serial != source.serial }
            .forEach { d in
                d.isSource = false
                d.brightnessCurveFactors[.sync] = 1
                d.contrastCurveFactors[.sync] = 1
                d.userContrast[.sync]?.removeAll()
                d.userBrightness[.sync]?.removeAll()
                if d.name == source.name {
                    d.lockedBrightnessCurve = true
                    d.lockedContrastCurve = true
                }
            }

        CachedDefaults[.overrideAdaptiveMode] = true
        displayController.adaptiveMode = SyncMode.specific
        next()
    }

    @objc func locationClick() {
        LocationMode.specific.fetchGeolocation()
        CachedDefaults[.overrideAdaptiveMode] = true
        displayController.adaptiveMode = LocationMode.specific
        next()
    }

    @objc func clockClick() {
        CachedDefaults[.overrideAdaptiveMode] = true
        displayController.adaptiveMode = ClockMode.specific
        next()
    }

    @objc func sensorClick() {
        CachedDefaults[.overrideAdaptiveMode] = true
        displayController.adaptiveMode = SensorMode.specific
        next()
    }

    @objc func manualClick() {
        CachedDefaults[.overrideAdaptiveMode] = true
        displayController.adaptiveMode = ManualMode.specific
        next()
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
            enabled: SyncMode.specific.builtinAvailable,
            action: #selector(syncBuiltinClick)
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
            enabled: source != nil,
            action: #selector(syncSourceClick)
        )

        setupButton(
            location,
            notice: locationNotice,
            color: lunarYellow,
            title: markdown
                .attributedString(
                    from: "**Adapt** the brightness of your **\(externalName)**\nbased on **sunrise** and **sunset**"
                ),
            enabled: true,
            action: #selector(locationClick)
        )

        setupButton(
            clock,
            notice: clockNotice,
            color: orange,
            title: markdown
                .attributedString(
                    from: "Schedule **presets** for changing the\n**brightness** at **predefined times**"
                ),
            enabled: true,
            action: #selector(clockClick)
        )

        setupButton(
            sensor,
            notice: sensorNotice,
            color: blue,
            title: lightMarkdown
                .attributedString(
                    from: "**Adapt** your **\(externalName)** based on readings\nfrom a wireless **ambient light sensor**"
                ),
            enabled: true,
            action: #selector(sensorClick)
        )

        setupButton(
            manual,
            notice: manualNotice,
            color: red,
            title: lightMarkdown
                .attributedString(
                    from: "**Control** your **\(externalName)** manually\nusing brightness and volume **keys**"
                ),
            enabled: ManualMode.specific.available,
            action: #selector(manualClick)
        )

        mainAsyncAfter(ms: 500) { [weak self] in
            guard let self = self else { return }
            self.heading.transition(0.3)
            self.heading.alphaValue = 1
        }
        mainAsyncAfter(ms: 1000) { [weak self] in
            guard let self = self else { return }
            self.subheading.transition(0.8)
            self.subheading.alphaValue = 1
        }
        super.viewDidLoad()
    }
}
