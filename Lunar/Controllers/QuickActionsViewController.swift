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

    var softwareSliders: some View {
        Group {
            if display.enhanced || SWIFTUI_PREVIEW {
                BigSurSlider(
                    percentage: $display.xdrBrightness,
                    image: "speedometer",
                    color: Colors.xdr,
                    backgroundColor: Colors.xdr.opacity(colorScheme == .dark ? 0.1 : 0.2),
                    showValue: $showSliderValues
                )
            }
            if display.subzero || SWIFTUI_PREVIEW, !display.blackOutEnabled, display.supportsGamma {
                BigSurSlider(
                    percentage: $display.softwareBrightness,
                    image: "moon.circle.fill",
                    color: Colors.subzero,
                    backgroundColor: Colors.subzero.opacity(colorScheme == .dark ? 0.1 : 0.2),
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
            if showPowerInQuickActions, display.getPowerOffEnabled() {
                ZStack(alignment: .topTrailing) {
                    Text(display.name)
                        .font(.system(size: 22, weight: .black))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(colors.fg.primary.opacity(0.5)))
                        .padding(.bottom, display.supportsEnhance ? 0 : 6)
                        .padding(.top, 12)
                    PowerOffButtonView(display: display)
                        .offset(x: 10, y: 4)
                }
            } else {
                Text(display.name)
                    .font(.system(size: 22, weight: .black))
                    .padding(.bottom, display.supportsEnhance ? 0 : 6)
            }

            if display.supportsEnhance { sdrXdrSelector }

            if display.noDDCOrMergedBrightnessContrast {
                BigSurSlider(
                    percentage: $display.preciseBrightnessContrast.f,
                    image: "sun.max.fill",
                    color: colors.accent,
                    backgroundColor: colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4),
                    showValue: $showSliderValues
                )
                softwareSliders
            } else {
                BigSurSlider(
                    percentage: $display.preciseBrightness.f,
                    image: "sun.max.fill",
                    color: colors.accent,
                    backgroundColor: colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4),
                    showValue: $showSliderValues
                )
                softwareSliders
                BigSurSlider(
                    percentage: $display.preciseContrast.f,
                    image: "circle.righthalf.fill",
                    color: colors.accent,
                    backgroundColor: colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4),
                    showValue: $showSliderValues
                )
            }

            if display.hasDDC, display.showVolumeSlider {
                BigSurSlider(
                    percentage: $display.preciseVolume.f,
                    image: "speaker.2.fill",
                    color: colors.accent,
                    backgroundColor: colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4),
                    showValue: $showSliderValues
                )
            }

            if (display.hasDDC && showInputInQuickActions) || display.showOrientation || display.appPreset != nil || (
                display
                    .adaptivePaused && !display.blackOutEnabled
            ) || SWIFTUI_PREVIEW {
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

// MARK: - QuickActionsLayoutView

struct QuickActionsLayoutView: View {
    @Default(.showSliderValues) var showSliderValues
    @Default(.mergeBrightnessContrast) var mergeBrightnessContrast
    @Default(.showVolumeSlider) var showVolumeSlider
    @Default(.showBrightnessMenuBar) var showBrightnessMenuBar
    @Default(.showOnlyExternalBrightnessMenuBar) var showOnlyExternalBrightnessMenuBar
    @Default(.showOrientationInQuickActions) var showOrientationInQuickActions
    @Default(.showInputInQuickActions) var showInputInQuickActions
    @Default(.showPowerInQuickActions) var showPowerInQuickActions

    var body: some View {
        VStack(alignment: .leading) {
            SettingsToggle(text: "Show slider values", setting: $showSliderValues.animation(.fastSpring))
            SettingsToggle(text: "Show volume slider", setting: $showVolumeSlider.animation(.fastSpring))
            SettingsToggle(text: "Show rotation selector", setting: $showOrientationInQuickActions.animation(.fastSpring))
            SettingsToggle(text: "Show input source selector", setting: $showInputInQuickActions.animation(.fastSpring))
            SettingsToggle(text: "Show power button", setting: $showPowerInQuickActions.animation(.fastSpring))
            SettingsToggle(text: "Merge brightness and contrast", setting: $mergeBrightnessContrast.animation(.fastSpring))
            SettingsToggle(text: "Show brightness near menubar icon", setting: $showBrightnessMenuBar.animation(.fastSpring))
            SettingsToggle(
                text: "Show only external monitor brightness",
                setting: $showOnlyExternalBrightnessMenuBar.animation(.fastSpring)
            )
            .padding(.leading)
            .disabled(!showBrightnessMenuBar)
        }.frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - QuickActionsMenuView

struct QuickActionsMenuView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors
    @ObservedObject var dc: DisplayController = displayController
    @Default(.overrideAdaptiveMode) var overrideAdaptiveMode
    @State var displays: [Display] = displayController.activeDisplayList
    @State var cursorDisplay: Display? = displayController.cursorDisplay
    @State var layoutShown = false
    @State var adaptiveModes: [AdaptiveModeKey] = [.sensor, .sync, .location, .clock, .manual, .auto]

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
                action: { withAnimation(.fastSpring) { layoutShown.toggle() } },
                label: {
                    HStack(spacing: 2) {
                        Image(systemName: "line.horizontal.3.decrease.circle.fill").font(.system(size: 12, weight: .semibold))
                        Text("Options").font(.system(size: 13, weight: .semibold))
                    }
                }
            ).buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))

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
            Text("Presets:").font(.system(size: 14, weight: .semibold)).opacity(0.7)
            Spacer()
            PresetButtonView(percent: 0)
            PresetButtonView(percent: 25)
            PresetButtonView(percent: 50)
            PresetButtonView(percent: 75)
            PresetButtonView(percent: 100)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
        .padding(.top)
        .padding(.horizontal, 24)
    }

    var footer: some View {
        HStack {
            SwiftUI.Button("Preferences") { appDelegate!.showPreferencesWindow(sender: nil) }
                .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                .font(.system(size: 12, weight: .medium, design: .monospaced))

            Spacer()

            SwiftUI.Button("Restart") { appDelegate!.restartApp(appDelegate!) }
                .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                .font(.system(size: 12, weight: .medium, design: .monospaced))

            SwiftUI.Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 24)
    }

    var header: some View {
        VStack(spacing: 0) {
            HStack {
                modeSelector
                Spacer()
                topRightButtons
            }.padding(10)

            if layoutShown || SWIFTUI_PREVIEW {
                QuickActionsLayoutView()
                    .padding(.horizontal, MENU_HORIZONTAL_PADDING)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }

        }.background(Color.primary.opacity(colorScheme == .dark ? 0.03 : 0.05))
    }

    var body: some View {
        GeometryReader { geom in
            VStack {
                header
                if let d = cursorDisplay, !SWIFTUI_PREVIEW {
                    DisplayRowView(display: d).padding(.vertical)
                }

                ForEach(displays) { d in
                    DisplayRowView(display: d).padding(.vertical)
                }

                standardPresets
                footer
            }
            .frame(width: MENU_WIDTH, alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, MENU_HORIZONTAL_PADDING)
            .padding(.bottom, 40)
            .padding(.top, 0)
            .background(bg, alignment: .top)
            .colors(colorScheme == .dark ? .dark : .light)
            .onAppear {
                cursorDisplay = dc.cursorDisplay
                displays = dc.nonCursorDisplays
                appDelegate?.statusItemButtonController?
                    .resize(NSSize(
                        width: MENU_WIDTH + (MENU_HORIZONTAL_PADDING * 2),
                        height: (NSScreen.main?.visibleFrame.height ?? 600) - 100
                    ))
            }
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
}

let MENU_WIDTH: CGFloat = 360
let MENU_HORIZONTAL_PADDING: CGFloat = 24

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

// MARK: - QuickActionsMenuView_Previews

struct QuickActionsMenuView_Previews: PreviewProvider {
    static var previews: some View {
        QuickActionsMenuView()
    }
}
