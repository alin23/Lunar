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

    @IBOutlet var skipButton: Button!

    lazy var markdown = getMarkdownRenderer()
    lazy var lightMarkdown = getMarkdownRenderer(color: white)

    var buttonCount: CGFloat = 0

    var cancelled = false
    lazy var originalOverride = CachedDefaults[.overrideAdaptiveMode]
    lazy var originalMode = displayController.adaptiveModeKey

    var didAppear = false

    func queueChange(_ change: @escaping (() -> Void)) {
        guard let wc = view.window?.windowController as? OnboardWindowController else {
            return
        }
        wc.changes.append(change)
    }

    func getMarkdownRenderer(color: NSColor? = nil) -> SwiftyMarkdown {
        let md = getMD(dark: true)

        md.body.color = color ?? .black
        md.body.fontSize = 15
        md.body.alignment = .center

        md.bold.color = color ?? .black
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
        button.isEnabled = false
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

        let y = subheading.frame.minY - 74 - (buttonCount * (button.frame.height + 10))
        let transitionTime = 0.6 + 0.1 * buttonCount
        mainAsyncAfter(ms: 1800) {
            button.transition(0.8)
            button.alphaValue = 0.85

            button.transition(transitionTime, type: .moveIn, easing: .easeOutBack)
            button.setFrameOrigin(NSPoint(
                x: button.frame.origin.x,
                y: y
            ))

            notice.transition(1, type: .push)
            notice.setFrameOrigin(NSPoint(
                x: notice.frame.origin.x,
                y: button.frame.minY - 36
            ))
        }
        mainAsyncAfter(ms: 2700) {
            button.baseFrame = button.frame
            button.isEnabled = true
        }

        buttonCount += 1
    }

    func next() {
        guard let wc = view.window?.windowController as? OnboardWindowController else { return }
        guard !displayController.externalActiveDisplays.isEmpty else {
            wc.pageController?.select(index: 2)
            return
        }
        wc.pageController?.navigateForward(self)
    }

    @objc func syncBuiltinClick() {
        queueChange {
            guard let builtin = displayController.builtinDisplay else { return }
            builtin.isSource = true
            displayController.displays.values
                .filter { $0.serial != builtin.serial }
                .forEach { d in
                    d.isSource = false
                    d.userContrast[.sync]?.removeAll()
                    d.userBrightness[.sync]?.removeAll()
                    d.lockedBrightnessCurve = false
                    d.lockedContrastCurve = false
                }

            CachedDefaults[.overrideAdaptiveMode] = DisplayController.autoMode().key != .sync
            displayController.enable(mode: .sync)
        }
        next()
    }

    @objc func syncSourceClick() {
        queueChange {
            let externals = displayController.externalActiveDisplays
            guard let source = externals
                .filter({ $0.hasAmbientLightAdaptiveBrightness && AppleNativeControl.isAvailable(for: $0) })
                .sorted(by: \.syncSourcePriority)
                .first
            else { return }

            source.isSource = true
            displayController.displays.values
                .filter { $0.serial != source.serial }
                .forEach { d in
                    d.isSource = false
                    d.systemAdaptiveBrightness = false
                    d.adaptive = true
                    d.userContrast[.sync]?.removeAll()
                    d.userBrightness[.sync]?.removeAll()
                    if d.name == source.name {
                        d.lockedBrightnessCurve = true
                        d.lockedContrastCurve = true
                    }
                }

            CachedDefaults[.overrideAdaptiveMode] = DisplayController.autoMode().key != .sync
            displayController.enable(mode: .sync)
        }
        next()
    }

    @objc func locationClick() {
        queueChange {
            LocationMode.specific.fetchGeolocation()
            CachedDefaults[.overrideAdaptiveMode] = DisplayController.autoMode().key != .location
            displayController.enable(mode: .location)
        }
        next()
    }

    @objc func clockClick() {
        queueChange {
            CachedDefaults[.overrideAdaptiveMode] = DisplayController.autoMode().key != .clock
            displayController.enable(mode: .clock)
        }
        next()
    }

    @objc func sensorClick() {
        queueChange {
            CachedDefaults[.overrideAdaptiveMode] = DisplayController.autoMode().key != .sensor
            displayController.enable(mode: .sensor)
        }

        if let url = URL(string: "https://lunar.fyi/sensor") {
            NSWorkspace.shared.open(url)
        }

        next()
    }

    @objc func manualClick() {
        queueChange {
            CachedDefaults[.overrideAdaptiveMode] = true
            CachedDefaults[.adaptiveBrightnessMode] = .manual
        }
        next()
    }

    func revert() {
        CachedDefaults[.overrideAdaptiveMode] = originalOverride
        displayController.enable(mode: originalMode)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard !useOnboardingForDiagnostics else { return }

        originalOverride = CachedDefaults[.overrideAdaptiveMode]
        originalMode = displayController.adaptiveModeKey
        CachedDefaults[.overrideAdaptiveMode] = true
        CachedDefaults[.adaptiveBrightnessMode] = .manual

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

        let source = externals.first { $0.hasAmbientLightAdaptiveBrightness && AppleNativeControl.isAvailable(for: $0) }
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
            color: blue.highlight(withLevel: 0.2) ?? blue,
            title: markdown
                .attributedString(
                    from: "**Adapt** your **\(externalName)** based on readings\nfrom a wireless **ambient light sensor**"
                ),
            enabled: true,
            action: #selector(sensorClick)
        )

        setupButton(
            manual,
            notice: manualNotice,
            color: red.highlight(withLevel: 0.2) ?? red,
            title: markdown
                .attributedString(
                    from: "**Control** your **\(externalName)** manually\nusing brightness and volume **keys**"
                ),
            enabled: ManualMode.specific.available,
            action: #selector(manualClick)
        )

        mainAsyncAfter(ms: 500) { [weak self] in
            guard let self else { return }
            self.heading.transition(0.3)
            self.heading.alphaValue = 1
        }
        mainAsyncAfter(ms: 1000) { [weak self] in
            guard let self else { return }
            self.subheading.transition(0.8)
            self.subheading.alphaValue = 1
        }
    }

    override func viewDidAppear() {
        guard !didAppear else { return }
        didAppear = true

        uiCrumb("Mode Choice")
        if let wc = view.window?.windowController as? OnboardWindowController {
            wc.setupSkipButton(skipButton) { [weak self] in
                self?.revert()
            }
        }
    }
}
