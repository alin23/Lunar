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

// MARK: - DisplayRowView

struct DisplayRowView: View {
    @ObservedObject var display: Display
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors
    @Default(.showSliderValues) var showSliderValues
    @Default(.showInputInQuickActions) var showInputInQuickActions

    var softwareSliders: some View {
        Group {
            if display.enhanced || SWIFTUI_PREVIEW {
                BigSurSlider(
                    percentage: $display.xdrBrightness,
                    image: "speedometer",
                    color: Colors.blue.blended(withFraction: 0.5, of: .white),
                    backgroundColor: Colors.blue.opacity(colorScheme == .dark ? 0.1 : 0.2),
                    showValue: $showSliderValues
                )
            }
            if display.subzero || SWIFTUI_PREVIEW {
                BigSurSlider(
                    percentage: $display.softwareBrightness,
                    image: "moon.circle.fill",
                    color: Colors.red.blended(withFraction: 0.3, of: .white),
                    backgroundColor: Colors.red.opacity(colorScheme == .dark ? 0.1 : 0.2),
                    showValue: $showSliderValues
                )
            }
        }
    }

    var sdrXdrSelector: some View {
        HStack {
            SwiftUI.Button("SDR") {
                display.enhanced = false
            }
            .buttonStyle(PickerButton(
                enumValue: $display.enhanced, onValue: false
            ))
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .help("Standard Dynamic Range disables XDR and allows the system to limit the brightness to 500nits.")

            SwiftUI.Button("XDR") {
                display.enhanced = true
            }
            .buttonStyle(PickerButton(
                enumValue: $display.enhanced, onValue: true
            ))
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
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
        .opacity(0.7)
        .colorMultiply(colors.accent)
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
            Text(display.name)
                .font(.system(size: 22, weight: .black))
                .padding(.bottom, display.supportsEnhance ? 0 : 6)

            if display.supportsEnhance {
                sdrXdrSelector
            }

            if display.noDDCOrMergedBrightnessContrast {
                BigSurSlider(
                    percentage: $display.preciseBrightnessContrast.f,
                    image: "sun.max.fill",
                    color: colors.accent,
                    backgroundColor: colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.3),
                    showValue: $showSliderValues
                )
                softwareSliders
            } else {
                BigSurSlider(
                    percentage: $display.preciseBrightness.f,
                    image: "sun.max.fill",
                    color: colors.accent,
                    backgroundColor: colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.3),
                    showValue: $showSliderValues
                )
                softwareSliders
                BigSurSlider(
                    percentage: $display.preciseContrast.f,
                    image: "circle.righthalf.fill",
                    color: colors.accent,
                    backgroundColor: colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.3),
                    showValue: $showSliderValues
                )
            }

            if display.hasDDC, display.showVolumeSlider {
                BigSurSlider(
                    percentage: $display.preciseVolume.f,
                    image: "speaker.2.fill",
                    color: colors.accent,
                    backgroundColor: colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.3),
                    showValue: $showSliderValues
                )
            }

            if (display.hasDDC && showInputInQuickActions) || display.showOrientation || display.appPreset != nil {
                VStack {
                    if display.hasDDC, showInputInQuickActions { inputSelector }
                    if display.showOrientation { rotationSelector }
                    if let app = display.appPreset {
                        SwiftUI.Button("App Preset: \(app.name)") {
                            app.runningApps?.first?.activate()
                        }
                        .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .secondary.opacity(0.8)))
                        .font(.system(size: 9, weight: .bold))
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(
                        cornerRadius: 8,
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
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
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

    var body: some View {
        VStack(alignment: .leading) {
            SettingsToggle(text: "Show slider values", setting: $showSliderValues)
            SettingsToggle(text: "Show volume slider", setting: $showVolumeSlider)
            SettingsToggle(text: "Show rotation selector", setting: $showOrientationInQuickActions)
            SettingsToggle(text: "Show input source selector", setting: $showInputInQuickActions)
            SettingsToggle(text: "Merge brightness and contrast", setting: $mergeBrightnessContrast)
            SettingsToggle(text: "Show brightness near menubar icon", setting: $showBrightnessMenuBar)
            SettingsToggle(text: "Show only external monitor brightness", setting: $showOnlyExternalBrightnessMenuBar)
                .padding(.leading)
                .disabled(!showBrightnessMenuBar)
        }.frame(maxWidth: .infinity, alignment: .leading)
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
        .opacity(0.7)
        .colorMultiply(colors.accent)
    }

    var body: some View {
        VStack {
            if layoutShown {
                QuickActionsLayoutView()
                    .padding(.bottom)
                Divider().padding(.bottom)
            }

            HStack {
                modeSelector
                Spacer()
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

            if let d = cursorDisplay, !SWIFTUI_PREVIEW {
                DisplayRowView(display: d)
                    .padding(.vertical)
            }

            ForEach(displays) { d in
                DisplayRowView(display: d)
                    .padding(.vertical)
            }

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
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                ).fill(Color.primary.opacity(0.05))
            )
            .padding(.top)

            HStack {
                SwiftUI.Button("Preferences") {
                    appDelegate!.showPreferencesWindow(sender: nil)
                }
                .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                .font(.system(size: 12, weight: .medium, design: .monospaced))

                Spacer()

                SwiftUI.Button("Restart") {
                    appDelegate!.restartApp(appDelegate!)
                }
                .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                SwiftUI.Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
        }
        .frame(width: 320, alignment: .top)
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .padding(.top, 20)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .shadow(color: Colors.blackMauve.opacity(0.2), radius: 8, x: 0, y: 4)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill((colorScheme == .dark ? Colors.blackMauve : Color.white).opacity(0.7))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        ).colors(colorScheme == .dark ? .dark : .light)
        .onAppear {
            cursorDisplay = dc.cursorDisplay
            displays = dc.nonCursorDisplays
        }
    }
}

// MARK: - QuickActionsMenuView_Previews

struct QuickActionsMenuView_Previews: PreviewProvider {
    static var previews: some View {
        QuickActionsMenuView()
    }
}
