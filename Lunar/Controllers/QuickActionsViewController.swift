//
//  MenuPopoverController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 25/11/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa
import Combine
import Defaults
import Surge
import SwiftUI

// MARK: - PresetButtonView

struct PresetButtonView: View {
    @State var percent: Int8

    var body: some View {
        SwiftUI.Button("\(percent)%") {
            appDelegate!.setLightPercent(percent: percent)
        }
        .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
        .font(.system(size: 12, weight: .medium, design: .monospaced))
    }
}

// MARK: - PowerOffButtonView

struct PowerOffButtonView: View {
    @ObservedObject var display: Display
    @State var hoveringPowerButton = false
    @Default(.neverShowBlackoutPopover) var neverShowBlackoutPopover

    var body: some View {
        SwiftUI.Button(action: {
            guard !AppDelegate.controlKeyPressed,
                  lunarProActive || lunarProOnTrial || (AppDelegate.optionKeyPressed && !AppDelegate.shiftKeyPressed)
            else {
                hoveringPowerButton = true
                return
            }
            display.powerOff()
        }) {
            Image(systemName: "power").font(.system(size: 10, weight: .heavy))
        }
        .buttonStyle(FlatButton(
            color: display.blackOutEnabled ? Color.gray : Colors.red,
            circle: true,
            horizontalPadding: 3,
            verticalPadding: 3
        ))
        .onHover { hovering in
            if !hoveringPowerButton, hovering {
                hoveringPowerButton = hovering && !neverShowBlackoutPopover
            }
        }
        .popover(isPresented: $hoveringPowerButton) {
            BlackoutPopoverView(hasDDC: display.hasDDC).onDisappear {
                if !neverShowBlackoutPopover {
                    neverShowBlackoutPopover = true
                }
            }
        }
    }
}

// MARK: - DisplayRowView

struct DisplayRowView: View {
    @ObservedObject var display: Display
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors
    @Default(.showSliderValues) var showSliderValues
    @Default(.showInputInQuickActions) var showInputInQuickActions
    @Default(.showPowerInQuickActions) var showPowerInQuickActions
    @Default(.showXDRSelector) var showXDRSelector
    @Default(.showRawValues) var showRawValues

    @State var showNeedsLunarPro = false

    var softwareSliders: some View {
        Group {
            if display.enhanced || SWIFTUI_PREVIEW, !display.blackOutEnabled {
                BigSurSlider(
                    percentage: $display.xdrBrightness,
                    image: "sun.max.circle.fill",
                    color: Colors.xdr.opacity(0.7),
                    backgroundColor: Colors.xdr.opacity(colorScheme == .dark ? 0.1 : 0.2),
                    knobColor: Colors.xdr,
                    showValue: $showSliderValues
                )
            }
            if display.subzero || SWIFTUI_PREVIEW, !display.blackOutEnabled {
                BigSurSlider(
                    percentage: $display.softwareBrightness,
                    image: "moon.circle.fill",
                    color: Colors.subzero.opacity(0.7),
                    backgroundColor: Colors.subzero.opacity(colorScheme == .dark ? 0.1 : 0.2),
                    knobColor: Colors.subzero,
                    showValue: $showSliderValues
                )
            }
        }
    }

    var sdrXdrSelector: some View {
        HStack {
            SwiftUI.Button("SDR") {
                guard display.enhanced else { return }
                withAnimation(.fastSpring) { display.enhanced = false }
            }
            .buttonStyle(PickerButton(
                enumValue: $display.enhanced, onValue: false
            ))
            .font(.system(size: 12, weight: display.enhanced ? .semibold : .bold, design: .monospaced))
            .help("Standard Dynamic Range disables XDR and allows the system to limit the brightness to 500nits.")

            SwiftUI.Button("XDR") {
                guard lunarProActive || lunarProOnTrial else {
                    showNeedsLunarPro = true
                    return
                }
                guard !display.enhanced else { return }
                withAnimation(.fastSpring) { display.enhanced = true }
            }
            .buttonStyle(PickerButton(
                enumValue: $display.enhanced, onValue: true
            ))
            .font(.system(size: 12, weight: display.enhanced ? .bold : .semibold, design: .monospaced))
            .help("""
            Enable XDR high-dynamic range for getting past the 500nits brightness limit.

            It's not recommended to keep this enabled for prolonged periods of time.
            """)
            .popover(isPresented: $showNeedsLunarPro) { NeedsLunarProView() }
        }
        .padding(.bottom, 4)
    }

    var inputSelector: some View {
        Dropdown(
            selection: $display.inputSource,
            width: 150,
            height: 20,
            noValueText: "Video Input",
            noValueImage: "input",
            content: .constant(InputSource.mostUsed)
        )
        .frame(width: 150, height: 20, alignment: .center)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            ).fill(Color.primary.opacity(0.15))
        )
        .colorMultiply(colors.accent.blended(withFraction: 0.7, of: .white))
    }

    var rotationSelector: some View {
        HStack {
            rotationPicker(0).help("No rotation")
            rotationPicker(90).help("90 degree rotation (vertical)")
            rotationPicker(180).help("180 degree rotation (upside down)")
            rotationPicker(270).help("270 degree rotation (vertical)")
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            let xdrSelectorShown = display.supportsEnhance && showXDRSelector
            if showPowerInQuickActions, display.getPowerOffEnabled() {
                ZStack(alignment: .topTrailing) {
                    Text(display.name)
                        .font(.system(size: 22, weight: .black))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(colors.bg.primary.opacity(0.5)))
                        .padding(.bottom, xdrSelectorShown ? 0 : 6)

                    PowerOffButtonView(display: display)
                        .offset(x: 10, y: -8)
                }
            } else {
                Text(display.name)
                    .font(.system(size: 22, weight: .black))
                    .padding(.bottom, xdrSelectorShown ? 0 : 6)
            }

            if xdrSelectorShown { sdrXdrSelector }

            if display.noDDCOrMergedBrightnessContrast {
                BigSurSlider(
                    percentage: $display.preciseBrightnessContrast.f,
                    image: "sun.max.fill",
                    colorBinding: .constant(colors.accent),
                    backgroundColorBinding: .constant(colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues
                )
                softwareSliders
            } else {
                BigSurSlider(
                    percentage: $display.preciseBrightness.f,
                    image: "sun.max.fill",
                    colorBinding: .constant(colors.accent),
                    backgroundColorBinding: .constant(colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues
                )
                softwareSliders
                BigSurSlider(
                    percentage: $display.preciseContrast.f,
                    image: "circle.righthalf.fill",
                    colorBinding: .constant(colors.accent),
                    backgroundColorBinding: .constant(colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues
                )
            }

            if display.hasDDC, display.showVolumeSlider {
                BigSurSlider(
                    percentage: $display.preciseVolume.f,
                    image: "speaker.2.fill",
                    colorBinding: .constant(colors.accent),
                    backgroundColorBinding: .constant(colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues
                )
            }

            if (display.hasDDC && showInputInQuickActions)
                || display.showOrientation
                || display.appPreset != nil
                || (display.adaptivePaused && !display.blackOutEnabled)
                || showRawValues
                || SWIFTUI_PREVIEW
            {
                VStack {
                    if (display.hasDDC && showInputInQuickActions) || SWIFTUI_PREVIEW { inputSelector }
                    if display.showOrientation || SWIFTUI_PREVIEW { rotationSelector }
                    if let app = display.appPreset {
                        SwiftUI.Button("App Preset: \(app.name)") {
                            app.runningApps?.first?.activate()
                        }
                        .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .secondary.opacity(0.8)))
                        .font(.system(size: 9, weight: .bold))
                    }
                    if (display.adaptivePaused && !display.blackOutEnabled) || SWIFTUI_PREVIEW {
                        SwiftUI.Button(action: { display.adaptivePaused.toggle() }) {
                            VStack {
                                Text("Adaptive paused")
                                Text("click to resume").font(.system(size: 9))
                            }
                        }
                        .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .secondary.opacity(0.8)))
                        .font(.system(size: 9, weight: .bold))
                    }

                    if showRawValues {
                        RawValuesView(display: display).frame(width: 220).padding(.vertical, 3)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    ).fill(Color.primary.opacity(0.05))
                )
                .padding(.vertical, 3)
            }
        }
    }

    func rotationPicker(_ degrees: Int) -> some View {
        SwiftUI.Button("\(degrees)°") {
            display.rotation = degrees
        }
        .buttonStyle(PickerButton(enumValue: $display.rotation, onValue: degrees))
        .font(.system(size: 12, weight: display.rotation == degrees ? .bold : .semibold, design: .monospaced))
        .help("No rotation")
    }
}

// MARK: - NeedsLunarProView

struct NeedsLunarProView: View {
    var body: some View {
        PaddedPopoverView(background: AnyView(Colors.red.brightness(0.05))) {
            HStack(spacing: 4) {
                Text("Needs a")
                    .foregroundColor(.black)
                    .font(.system(size: 16, weight: .bold))
                SwiftUI.Button("Lunar Pro") { appDelegate!.getLunarPro(appDelegate!) }
                    .buttonStyle(FlatButton(color: .black.opacity(0.5), textColor: .white))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("licence")
                    .foregroundColor(.black)
                    .font(.system(size: 16, weight: .bold))
            }
        }
    }
}

// MARK: - RawValueView

struct RawValueView: View {
    @Binding var value: Double?
    @State var icon: String
    @State var decimals: UInt8 = 0

    var body: some View {
        if let v = value?.str(decimals: decimals) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                Text(v)
            }
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.07)))
        } else {
            EmptyView()
        }
    }
}

// MARK: - RawValuesView

struct RawValuesView: View {
    @ObservedObject var display: Display

    var body: some View {
        if display.lastRawBrightness != nil || display.lastRawContrast != nil || display.lastRawVolume != nil {
            HStack(spacing: 0) {
                Text("Raw Values").font(.system(size: 12, weight: .semibold, design: .monospaced))
                Spacer()
                HStack(spacing: 4) {
                    RawValueView(
                        value: $display.lastRawBrightness,
                        icon: "sun.max.fill",
                        decimals: display.control is AppleNativeControl ? 2 : 0
                    )
                    RawValueView(value: $display.lastRawContrast, icon: "circle.righthalf.fill")
                    RawValueView(value: $display.lastRawVolume, icon: "speaker.2.fill")
                }.fixedSize()
            }.foregroundColor(.secondary).padding(.horizontal, 3)
        } else {
            EmptyView()
        }
    }
}

// MARK: - AdvancedSettingsView

struct AdvancedSettingsView: View {
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @Default(.showDockIcon) var showDockIcon
    @Default(.moreGraphData) var moreGraphData

    @Default(.silentUpdate) var silentUpdate
    @Default(.workaroundBuiltinDisplay) var workaroundBuiltinDisplay
    @Default(.debug) var debug
    @Default(.ddcSleepLonger) var ddcSleepLonger
    @Default(.clamshellModeDetection) var clamshellModeDetection
    @Default(.muteVolumeZero) var muteVolumeZero
    @Default(.refreshValues) var refreshValues
    @Default(.enableOrientationHotkeys) var enableOrientationHotkeys
    @Default(.detectResponsiveness) var detectResponsiveness
    @Default(.disableControllerVideo) var disableControllerVideo
    @Default(.allowBlackOutOnSingleScreen) var allowBlackOutOnSingleScreen
    @Default(.reapplyValuesAfterWake) var reapplyValuesAfterWake
    @Default(.hdrWorkaround) var hdrWorkaround
    @Default(.xdrContrast) var xdrContrast

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                SettingsToggle(text: "Hide menubar icon", setting: $hideMenuBarIcon)
                SettingsToggle(text: "Show dock icon", setting: $showDockIcon)
                SettingsToggle(
                    text: "Show more graph data",
                    setting: $moreGraphData,
                    help: "Renders values and data lines on the bottom graph of the preferences window"
                )
                SettingsToggle(text: "Install updates silently in the background", setting: $silentUpdate)
                SettingsToggle(
                    text: "Enable verbose logging", setting: $debug,
                    help: """
                    Log path: ~/Library/Caches/Lunar/swiftybeaver.log

                    This option will deactivate itself when the app quits
                    to avoid filling up disk space with unnecessary logs.
                    """
                )
            }
            Divider()
            VStack(alignment: .leading) {
                SettingsToggle(
                    text: "Use workaround for built-in display", setting: $workaroundBuiltinDisplay,
                    help: """
                    Forward brightness key events to the system instead of
                    changing built-in brightness from Lunar.

                    Disables the "Hotkey Step" setting for built-in but persists
                    brightness changes better on some specific devices.
                    """
                )
                SettingsToggle(
                    text: "Run in HDR compatibility mode", setting: $hdrWorkaround,
                    help: """
                    Because of a macOS bug, any app that uses the Gamma API will break HDR.

                    This workaround tries to keep HDR working by periodically resetting Gamma changes.

                    This will stop working in the following cases:

                    • Using "Software Dimming" with the Gamma method on any display
                    • Having the f.lux app running
                    • Having the Gamma Control app running
                    • Using "XDR Brightness"
                    • Using "Sub-zero dimming"
                    """
                )
                SettingsToggle(
                    text: "Enhance contrast in XDR Brightness", setting: $xdrContrast,
                    help: "Improve readability in sunlight by increasing XDR contrast.\nThis option is especially useful when using apps with dark backgrounds."
                )
                SettingsToggle(
                    text: "Allow BlackOut on single screen", setting: $allowBlackOutOnSingleScreen,
                    help: "Allows turning off a screen even if it's the only visible screen left"
                )
                SettingsToggle(
                    text: "Toggle Manual/Sync when the lid is closed/opened",
                    setting: $clamshellModeDetection
                ).disabled(!Sysctl.isMacBook)
                SettingsToggle(
                    text: "Re-apply brightness on screen wake", setting: $reapplyValuesAfterWake,
                    help: """
                    On each screen wake/reconnection, Lunar will try to
                    re-apply previous brightness and contrast 3 times.

                    Disable this if system appears slow on screen wake.
                    """
                )
            }
            Divider()
            VStack(alignment: .leading) {
                SettingsToggle(
                    text: "Enable rotation hotkeys",
                    setting: $enableOrientationHotkeys,
                    help: """
                    Pressing the following keys will change the
                    orientation for the display with the cursor on it:

                        Ctrl+0: 0°
                        Ctrl+9: 90°
                        Ctrl+8: 180°
                        Ctrl+7: 270°
                    """
                )
                SettingsToggle(
                    text: "Apply volume 0 on the DDC mute command", setting: $muteVolumeZero,
                    help: """
                    Some monitors don't implement the DDC mute command.

                    This option also sets the volume to 0 when muting
                    to help working around that issue.
                    """
                )
                SettingsToggle(
                    text: "Wait longer between DDC requests", setting: $ddcSleepLonger,
                    help: """
                    Some monitors have a slower response time on DDC requests.

                    This option might help reduce flicker in those cases.
                    """
                )
                SettingsToggle(
                    text: "Check for DDC responsiveness periodically", setting: $detectResponsiveness,
                    help: """
                    Detects when DDC becomes unresponsive and presents
                    the choice to switch to Software Dimming.
                    """
                )
                SettingsToggle(
                    text: "Disable Network Controller video ", setting: $disableControllerVideo,
                    help: """
                    When using "Network Control" with a Raspberry Pi, it might be
                    helpful to disable the Pi desktop if you don't need it.
                    """
                )
                SettingsToggle(
                    text: "Refresh values from monitor settings ", setting: $refreshValues,
                    help: """
                    Keep Lunar state in sync by reading monitor settings periodically.

                    Caution: This can freeze the system if a monitor doesn't support reading.
                    """
                )
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - QuickActionsLayoutView

struct QuickActionsLayoutView: View {
    @Default(.showSliderValues) var showSliderValues
    @Default(.mergeBrightnessContrast) var mergeBrightnessContrast
    @Default(.showVolumeSlider) var showVolumeSlider
    @Default(.showRawValues) var showRawValues
    @Default(.showBrightnessMenuBar) var showBrightnessMenuBar
    @Default(.showOnlyExternalBrightnessMenuBar) var showOnlyExternalBrightnessMenuBar
    @Default(.showOrientationInQuickActions) var showOrientationInQuickActions
    @Default(.showInputInQuickActions) var showInputInQuickActions
    @Default(.showPowerInQuickActions) var showPowerInQuickActions
    @Default(.showStandardPresets) var showStandardPresets
    @Default(.showCustomPresets) var showCustomPresets
    @Default(.showXDRSelector) var showXDRSelector
    @Default(.showHeaderOnHover) var showHeaderOnHover
    @Default(.showFooterOnHover) var showFooterOnHover
    @Default(.autoXdr) var autoXdr
    @Default(.autoSubzero) var autoSubzero

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                SettingsToggle(text: "Only show top buttons on hover", setting: $showHeaderOnHover.animation(.fastSpring))
                SettingsToggle(text: "Only show bottom buttons on hover", setting: $showFooterOnHover.animation(.fastSpring))
            }
            Divider()
            VStack(alignment: .leading) {
                SettingsToggle(text: "Show slider values", setting: $showSliderValues.animation(.fastSpring))
                SettingsToggle(text: "Show volume slider", setting: $showVolumeSlider.animation(.fastSpring))
                SettingsToggle(text: "Show rotation selector", setting: $showOrientationInQuickActions.animation(.fastSpring))
                SettingsToggle(text: "Show input source selector", setting: $showInputInQuickActions.animation(.fastSpring))
                SettingsToggle(text: "Show power button", setting: $showPowerInQuickActions.animation(.fastSpring))
            }
            Divider()
            VStack(alignment: .leading) {
                SettingsToggle(text: "Show standard presets", setting: $showStandardPresets.animation(.fastSpring))
                SettingsToggle(text: "Show custom presets", setting: $showCustomPresets.animation(.fastSpring))
                SettingsToggle(text: "Merge brightness and contrast", setting: $mergeBrightnessContrast.animation(.fastSpring))
            }
            Divider()
            VStack(alignment: .leading) {
                SettingsToggle(text: "Show XDR brightness toggle when available", setting: $showXDRSelector.animation(.fastSpring))
                SettingsToggle(text: "Toggle XDR Brightness when going over 100%", setting: $autoXdr.animation(.fastSpring))
                SettingsToggle(
                    text: "Toggle Sub-zero Dimming when going below 0%",
                    setting: $autoSubzero.animation(.fastSpring)
                )
            }
            Divider()
            VStack(alignment: .leading) {
                SettingsToggle(text: "Show last raw values sent to the display", setting: $showRawValues.animation(.fastSpring))
                SettingsToggle(text: "Show brightness near menubar icon", setting: $showBrightnessMenuBar.animation(.fastSpring))
                SettingsToggle(
                    text: "Show only external monitor brightness",
                    setting: $showOnlyExternalBrightnessMenuBar.animation(.fastSpring)
                )
                .padding(.leading)
                .disabled(!showBrightnessMenuBar)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - BlackoutPopoverRowView

struct BlackoutPopoverRowView: View {
    @State var modifiers: [String] = []
    @State var action: String
    @State var hotkeyText = ""
    @State var actionInfo = ""

    var body: some View {
        HStack {
            Text((modifiers + ["Click"]).joined(separator: " + ")).font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                ).frame(width: 200, alignment: .leading)
            HStack {
                if !hotkeyText.isEmpty {
                    Text("or").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.5))
                    Text(hotkeyText).font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .kerning(3)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }.frame(width: 100, alignment: .leading)
            HStack {
                Text(action)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                if !actionInfo.isEmpty {
                    Text(actionInfo)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
}

// MARK: - BlackoutPopoverHeaderView

struct BlackoutPopoverHeaderView: View {
    @Default(.neverShowBlackoutPopover) var neverShowBlackoutPopover

    var body: some View {
        HStack {
            Text("BlackOut")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)
            Spacer()
            if lunarProActive || lunarProOnTrial {
                Text("Click anywhere to hide")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            } else {
                SwiftUI.Button("Needs Lunar Pro") {
                    showCheckout()
                    appDelegate?.windowController?.window?.makeKeyAndOrderFront(nil)
                }.buttonStyle(FlatButton(color: Colors.red, textColor: .white))
            }
        }
    }
}

// MARK: - PaddedPopoverView

struct PaddedPopoverView<Content>: View where Content: View {
    @State var background: AnyView

    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            background.scaleEffect(1.5)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }.preferredColorScheme(.light)
    }
}

// MARK: - BlackoutPopoverView

struct BlackoutPopoverView: View {
    @State var hasDDC: Bool
    @Default(.hotkeys) var hotkeys

    var body: some View {
        ZStack {
            Color.black.brightness(0.02).scaleEffect(1.5)
            VStack(alignment: .leading, spacing: 10) {
                BlackoutPopoverHeaderView().padding(.bottom)
                BlackoutPopoverRowView(action: "Soft power off", hotkeyText: hotkeyText(id: .blackOut), actionInfo: "(with mirroring)")
                BlackoutPopoverRowView(
                    modifiers: ["Shift"],
                    action: "Soft power off",
                    hotkeyText: hotkeyText(id: .blackOutNoMirroring),
                    actionInfo: "(without mirroring)"
                )
                BlackoutPopoverRowView(
                    modifiers: ["Option", "Shift"],
                    action: "Soft power off other displays",
                    hotkeyText: hotkeyText(id: .blackOutOthers),
                    actionInfo: "(without mirroring)"
                )

                if hasDDC {
                    BlackoutPopoverRowView(
                        modifiers: ["Option"],
                        action: "Hardware power off",
                        hotkeyText: hotkeyText(id: .blackOutPowerOff),
                        actionInfo: "(uses DDC)"
                    )
                    .colorMultiply(Colors.red)
                }
                Divider().background(Color.white.opacity(0.2))
                BlackoutPopoverRowView(modifiers: ["Control"], action: "Show this help menu")
                    .colorMultiply(Colors.peach)

                HStack(spacing: 7) {
                    Text("Press")
                    Text("⌘ Command")
                        .padding(.vertical, 3)
                        .padding(.horizontal, 5)
                        .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color.white))
                        .foregroundColor(.black)
                    Text("more than 8 times in a row to force turn on all displays and reset BlackOut")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.1)))
                .colorMultiply(Colors.peach)
                .padding(.top)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }.preferredColorScheme(.light)
    }

    func hotkeyText(id: HotkeyIdentifier) -> String {
        guard let h = hotkeys.first(where: { $0.identifier == id.rawValue }), h.isEnabled else { return "" }
        return h.keyCombo.keyEquivalentModifierMaskString + h.keyCombo.keyEquivalent
    }
}

// MARK: - PaddedTextFieldStyle

public struct PaddedTextFieldStyle: TextFieldStyle {
    // MARK: Public

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(font)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor ?? .white.opacity(colorScheme == .dark ? 0.2 : 0.9))
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
    }

    // MARK: Internal

    @State var font: Font = .system(size: 12, weight: .bold)
    @State var verticalPadding: CGFloat = 4
    @State var horizontalPadding: CGFloat = 8
    @State var backgroundColor: Color? = nil

    @Environment(\.colorScheme) var colorScheme
}

// MARK: - TextInputView

struct TextInputView: View {
    @State var label: String
    @State var placeholder: String
    @Binding var data: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            TextField(placeholder, text: $data)
                .textFieldStyle(PaddedTextFieldStyle())
        }
    }
}

// MARK: - MenuDensity

enum MenuDensity: String, Codable, Defaults.Serializable {
    case clean
    case comfortable
    case dense
}

// MARK: - EnvState

final class EnvState: ObservableObject {
    @Published var recording = false
    @Published var menuWidth: CGFloat = MENU_WIDTH
    @Published var menuHeight: CGFloat = 100
    @Published var menuMaxHeight: CGFloat = (NSScreen.main?.visibleFrame.height ?? 600) - 50
}

// MARK: - QuickActionsMenuView

struct QuickActionsMenuView: View {
    enum OptionsTab {
        case layout
        case advanced
    }

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors
    @EnvironmentObject var env: EnvState
    @ObservedObject var dc: DisplayController = displayController
    @Namespace var namespace

    @Default(.overrideAdaptiveMode) var overrideAdaptiveMode
    @Default(.showStandardPresets) var showStandardPresets
    @Default(.showCustomPresets) var showCustomPresets
    @Default(.showHeaderOnHover) var showHeaderOnHover
    @Default(.showFooterOnHover) var showFooterOnHover
    @Default(.showOptionsMenu) var showOptionsMenu
    @Default(.popoverClosed) var popoverClosed
    @Default(.menuDensity) var menuDensity

    @Default(.showBrightnessMenuBar) var showBrightnessMenuBar
    @Default(.showOnlyExternalBrightnessMenuBar) var showOnlyExternalBrightnessMenuBar
    @Default(.showAdditionalInfo) var showAdditionalInfo
    @Default(.startAtLogin) var startAtLogin

    @State var displays: [Display] = displayController.activeDisplayList
    @State var cursorDisplay: Display? = displayController.cursorDisplay
    @State var adaptiveModes: [AdaptiveModeKey] = [.sensor, .sync, .location, .clock, .manual, .auto]

    @State var headerOpacity: CGFloat = 1.0
    @State var footerOpacity: CGFloat = 1.0
    @State var additionalInfoButtonOpacity: CGFloat = 0.3
    @State var headerIndicatorOpacity: CGFloat = 0.0
    @State var footerIndicatorOpacity: CGFloat = 0
    @State var optionsTab: OptionsTab = .layout

    @State var displayCount = displayController.activeDisplayList.count

    var modeSelector: some View {
        let titleBinding = Binding<String>(
            get: { overrideAdaptiveMode ? "⁣\(dc.adaptiveModeKey.name)⁣" : "Auto: \(dc.adaptiveModeKey.str)" }, set: { _ in }
        )
        let imageBinding = Binding<String>(
            get: { overrideAdaptiveMode ? dc.adaptiveModeKey.image ?? "automode" : "automode" }, set: { _ in }
        )

        return Dropdown(
            selection: $dc.adaptiveModeKey,
            width: 140,
            height: 20,
            noValueText: "Adaptive Mode",
            noValueImage: "automode",
            content: $adaptiveModes,
            title: titleBinding,
            image: imageBinding,
            validate: AdaptiveModeButton.validate(_:)
        )
        .frame(width: 140, height: 20, alignment: .center)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            ).fill(Color.primary.opacity(0.15))
        )
        .colorMultiply(colors.accent.blended(withFraction: 0.7, of: .white))
    }

    var topRightButtons: some View {
        Group {
            SwiftUI.Button(
                action: { withAnimation(.fastSpring) { showOptionsMenu.toggle() } },
                label: {
                    HStack(spacing: 2) {
                        Image(systemName: "line.horizontal.3.decrease.circle.fill").font(.system(size: 12, weight: .semibold))
                        Text("Options").font(.system(size: 13, weight: .semibold))
                    }
                }
            )
            .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
            .popover(isPresented: $showOptionsMenu, arrowEdge: .trailing) {
                PaddedPopoverView(background: AnyView(colorScheme == .dark ? Colors.sunYellow : Colors.lunarYellow)) {
                    HStack {
                        SwiftUI.Button("Menu layout") {
                            withAnimation(.fastSpring) { optionsTab = .layout }
                            showOptionsMenu = false
                            showOptionsMenu = true
                        }
                        .buttonStyle(PickerButton(enumValue: $optionsTab, onValue: .layout))
                        .font(.system(size: 12, weight: optionsTab == .layout ? .bold : .medium, design: .rounded))

                        SwiftUI.Button("Advanced settings") {
                            withAnimation(.fastSpring) { optionsTab = .advanced }
                            showOptionsMenu = false
                            showOptionsMenu = true
                        }
                        .buttonStyle(PickerButton(enumValue: $optionsTab, onValue: .advanced))
                        .font(.system(size: 12, weight: optionsTab == .advanced ? .bold : .medium, design: .rounded))
                    }.frame(maxWidth: .infinity)

                    switch optionsTab {
                    case .layout:
                        QuickActionsLayoutView().padding(10)
                    case .advanced:
                        AdvancedSettingsView().padding(10)
                    }
                }.frame(width: 390, height: 465, alignment: .center)
            }
            .onChange(of: showBrightnessMenuBar) { _ in
                let old = showOptionsMenu
                showOptionsMenu = false
                if old { mainAsyncAfter(ms: 500) { showOptionsMenu = true }}
            }
            .onChange(of: showOnlyExternalBrightnessMenuBar) { _ in
                let old = showOptionsMenu
                showOptionsMenu = false
                if old { mainAsyncAfter(ms: 500) { showOptionsMenu = true }}
            }

            SwiftUI.Button(
                action: {
                    guard let view = menuPopover?.contentViewController?.view else { return }
                    appDelegate!.menu.popUp(
                        positioning: nil,
                        at: NSPoint(x: view.frame.width - (POPOVER_PADDING / 2), y: 0),
                        in: view
                    )
                },
                label: {
                    HStack(spacing: 2) {
                        Image(systemName: "ellipsis.circle.fill").font(.system(size: 12, weight: .semibold))
                        Text("Menu").font(.system(size: 13, weight: .semibold))
                    }
                }
            ).buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
        }
    }

    var standardPresets: some View {
        HStack {
            VStack(alignment: .center, spacing: -2) {
                Text("Standard").font(.system(size: 10, weight: .bold)).opacity(0.7)
                Text("Presets").font(.system(size: 12, weight: .heavy)).opacity(0.7)
            }
            Spacer()
            PresetButtonView(percent: 0)
            PresetButtonView(percent: 25)
            PresetButtonView(percent: 50)
            PresetButtonView(percent: 75)
            PresetButtonView(percent: 100)
        }
    }

    var footer: some View {
        Group {
            let dynamicFooter = footerOpacity == 0.0 && showFooterOnHover
            ZStack {
                HStack {
                    SwiftUI.Button("Preferences") { appDelegate!.showPreferencesWindow(sender: nil) }
                        .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .fixedSize()

                    if !showAdditionalInfo {
                        SwiftUI.Button("App info") {
                            withAnimation(.fastSpring) {
                                showAdditionalInfo = true
                            }
                        }
                        .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .fixedSize()
                        .matchedGeometryEffect(id: "additional-info-button", in: namespace)
                    }
                    Spacer()

                    SwiftUI.Button("Restart") { appDelegate!.restartApp(appDelegate!) }
                        .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .fixedSize()

                    SwiftUI.Button("Quit") { NSApplication.shared.terminate(nil) }
                        .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .fixedSize()
                }
                .padding(.horizontal, MENU_HORIZONTAL_PADDING)
                .opacity(showFooterOnHover ? footerOpacity : 1.0)
                .contentShape(Rectangle())
                .onChange(of: showFooterOnHover) { showOnHover in
                    withAnimation(.fastTransition) { footerOpacity = showOnHover ? 0.0 : 1.0 }
                }
                .onHover { hovering in
                    guard showFooterOnHover else {
                        footerShowHideTask = nil
                        footerOpacity = 1.0
                        return
                    }

                    guard hovering else {
                        footerShowHideTask = mainAsyncAfter(ms: 500) {
                            withAnimation(.fastTransition) {
                                footerOpacity = 0.0
                                footerIndicatorOpacity = 0.0
                            }
                        }
                        return
                    }
                    footerShowHideTask = mainAsyncAfter(ms: 50) {
                        withAnimation(.fastTransition) { footerOpacity = 1.0 }
                    }
                }
                Rectangle()
                    .fill(Color.primary.opacity(dynamicFooter ? footerIndicatorOpacity : 0.0))
                    .frame(maxWidth: .infinity, maxHeight: dynamicFooter ? 20.0 : 0.0)
                    .onHover { hovering in
                        guard footerOpacity == 0.0, showFooterOnHover else { return }
                        if hovering {
                            withAnimation(.spring()) {
                                footerIndicatorOpacity = 0.1
                            }
                            withAnimation(.easeOut.delay(0.5)) {
                                footerIndicatorOpacity = 0
                            }
                        }
                    }
            }.frame(maxWidth: .infinity, maxHeight: footerOpacity == 0.0 ? 8 : nil)

            if let appDelegate = appDelegate, showAdditionalInfo {
                Divider()
                    .padding(.top, 10 * footerOpacity)
                    .padding(.bottom, 10)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Toggle("Hide app info", isOn: $showAdditionalInfo.animation(.fastSpring))
                            .toggleStyle(DetailToggleStyle(style: .circle))
                            .foregroundColor(colors.gray)
                            .font(.system(size: 12, weight: .semibold))
                            .fixedSize()
                            .matchedGeometryEffect(id: "additional-info-button", in: namespace)
                        Spacer()
                        Toggle("Launch at login", isOn: $startAtLogin)
                            .toggleStyle(CheckboxToggleStyle(style: .circle))
                            .foregroundColor(.primary)
                            .font(.system(size: 12, weight: .medium))
                    }
                    LicenseView()
                    VersionView(updater: appDelegate.updater)
                    MenuDensityView()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 25)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if Defaults[.launchCount] == 1 {
                withAnimation(.spring().delay(1.0)) { showAdditionalInfo = true }
            }
            if Defaults[.launchCount] == 2 {
                withAnimation(.spring().delay(1.0)) { showAdditionalInfo = false }
            }
        }
    }

    var header: some View {
        let op = (showHeaderOnHover && !showOptionsMenu) ? headerOpacity : 1.0
        return ZStack {
            HStack {
                modeSelector.fixedSize()
                Spacer()
                topRightButtons.fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.top, 10 * op)
            .padding(.bottom, 10 * op)
            .opacity(op)

            let dynamicHeader = headerOpacity == 0.0 && showHeaderOnHover
            Rectangle()
                .fill(Color.primary.opacity(dynamicHeader ? headerIndicatorOpacity : 0.0))
                .frame(maxWidth: .infinity, maxHeight: dynamicHeader ? 20.0 : 0.0)
                .onHover { hovering in
                    guard headerOpacity == 0.0, showHeaderOnHover else { return }
                    if hovering {
                        withAnimation(.spring()) {
                            headerIndicatorOpacity = 0.1
                        }
                        withAnimation(.easeOut.delay(0.5)) {
                            headerIndicatorOpacity = 0
                        }
                    }
                }.offset(x: 0, y: -6)
        }
        .background(Color.primary.opacity((colorScheme == .dark ? 0.03 : 0.05) * op))
        .padding(.bottom, 10 * op)
        .onHover(perform: handleHeaderTransition(hovering:))
        .onChange(of: showOptionsMenu, perform: handleHeaderTransition(hovering:))
    }

    var content: some View {
        Group {
            header

            if let d = cursorDisplay, !SWIFTUI_PREVIEW {
                DisplayRowView(display: d).padding(.bottom)
            }

            ForEach(displays) { d in
                DisplayRowView(display: d).padding(.bottom)
            }

            if showStandardPresets || showCustomPresets {
                VStack {
                    if showStandardPresets { standardPresets }
                    if showStandardPresets, showCustomPresets { Divider() }
                    if showCustomPresets { CustomPresetsView() }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
                .padding(.horizontal, MENU_HORIZONTAL_PADDING)
            }
        }
    }

    var body: some View {
        let op = (showFooterOnHover && !showAdditionalInfo) ? footerOpacity : 1.0
        GeometryReader { _ in
            VStack {
                content
                footer
            }
            .frame(maxWidth: env.menuWidth, alignment: .center)
            .scrollOnOverflow()
            .frame(width: env.menuWidth, height: cap(env.menuHeight, minVal: 100, maxVal: env.menuMaxHeight - 50), alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, MENU_HORIZONTAL_PADDING)
            .padding(.bottom, op < 1 ? 20 : 40)
            .padding(.top, 0)
            .background(bg, alignment: .top)
            .onAppear { setup() }
            .onChange(of: popoverClosed) { closed in setup(closed) }
            .frame(maxWidth: .infinity, alignment: .center)
            .onTapGesture { env.recording = false }

            .onChange(of: showStandardPresets, perform: setMenuWidth)
            .onChange(of: showCustomPresets, perform: setMenuWidth)
            .onChange(of: showHeaderOnHover, perform: setMenuWidth)
            .onChange(of: showFooterOnHover, perform: setMenuWidth)
            .onChange(of: showAdditionalInfo, perform: setMenuWidth)
            .onChange(of: headerOpacity, perform: setMenuWidth)
            .onChange(of: footerOpacity, perform: setMenuWidth)
        }
    }

    var bg: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, MENU_HORIZONTAL_PADDING)
                .padding(.bottom, 20)
                .shadow(color: Colors.blackMauve.opacity(colorScheme == .dark ? 0.5 : 0.2), radius: 8, x: 0, y: 6)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Colors.blackMauve.opacity(0.4) : Color.white.opacity(0.6))
                .padding(.horizontal, MENU_HORIZONTAL_PADDING)
                .padding(.bottom, 20)
        }
    }

    func setMenuWidth(_: Any) {
        withAnimation(.fastSpring) {
            env.menuWidth = (
                showStandardPresets || showCustomPresets
                    || !showHeaderOnHover || !showFooterOnHover
                    || showAdditionalInfo
                    || headerOpacity > 0 || footerOpacity > 0
            ) ? MENU_WIDTH : MENU_WIDTH - 80
        }
    }

    func handleHeaderTransition(hovering: Bool) {
        guard !showOptionsMenu else {
            headerShowHideTask = nil
            headerOpacity = 1.0
            return
        }

        guard hovering else {
            headerShowHideTask = mainAsyncAfter(ms: 500) {
                withAnimation(.fastTransition) { headerOpacity = 0.0 }
            }
            return
        }
        headerShowHideTask = mainAsyncAfter(ms: 50) {
            withAnimation(.fastTransition) { headerOpacity = 1.0 }
        }
    }

    func setup(_ closed: Bool? = nil) {
        guard !(closed ?? popoverClosed) else {
            displayHideTask = mainAsyncAfter(ms: 2000) {
                cursorDisplay = nil
                displays = []
                displayCount = 0
            }
            return
        }

        displayHideTask = nil
        cursorDisplay = dc.cursorDisplay
        displays = dc.nonCursorDisplays
        displayCount = dc.activeDisplayList.count

        if showHeaderOnHover { headerOpacity = 0.0 }
        if showFooterOnHover { footerOpacity = 0.0 }
        env.menuMaxHeight = (NSScreen.main?.visibleFrame.height ?? 600) - 50

        appDelegate?.statusItemButtonController?
            .resize(NSSize(
                width: MENU_WIDTH + (MENU_HORIZONTAL_PADDING * 2),
                height: env.menuMaxHeight
            ))
    }
}

var displayHideTask: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}

var headerShowHideTask: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}

var footerShowHideTask: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}

extension Defaults.Keys {
    static let showAdditionalInfo = Key<Bool>("showAdditionalInfo", default: false)
}

// MARK: - QuickActionsView

struct QuickActionsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Default(.popoverClosed) var popoverClosed

    var env = EnvState()

    var body: some View {
        QuickActionsMenuView()
            .environmentObject(env)
            .colors(colorScheme == .dark ? .dark : .light)
    }
}

let MENU_WIDTH: CGFloat = 380
let MENU_HORIZONTAL_PADDING: CGFloat = 24
let MENU_VERTICAL_PADDING: CGFloat = 40

// MARK: - ViewSizeKey

struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - ViewGeometry

struct ViewGeometry: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: ViewSizeKey.self, value: geometry.size)
        }
    }
}

// MARK: - QuickActionsView_Previews

struct QuickActionsView_Previews: PreviewProvider {
    static var previews: some View {
        QuickActionsView()
    }
}
