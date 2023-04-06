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

var appInfoHiddenAfterLaunch = true

prefix func ! (value: Binding<Bool>) -> Binding<Bool> {
    Binding<Bool>(
        get: { !value.wrappedValue },
        set: { value.wrappedValue = !$0 }
    )
}

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
    @ObservedObject var km = KM
    @State var showPopover = false
    @Default(.newBlackOutDisconnect) var newBlackOutDisconnect
    @Default(.neverShowBlackoutPopover) var neverShowBlackoutPopover
    @Default(.allowBlackOutOnSingleScreen) var allowBlackOutOnSingleScreen

    @State var hovering = false
    @StateObject var poweringOff: ExpiringBool = false

    var actionText: String {
        if km.controlKeyPressed {
            if km.commandKeyPressed, !display.blackOutEnabled, DC.activeDisplayCount > 1 {
                return "Ignore"
            }
            return "Show Help"
        }

        if display.blackOutEnabled {
            return "Power On"
        }

        if allowBlackOutOnSingleScreen, DC.activeDisplayCount == 1 {
            if km.optionKeyPressed {
                return display.hasDDC ? "Power Off" : "Needs DDC"
            }
            return "Darken"
        }

        if km.optionKeyPressed {
            if km.shiftKeyPressed {
                return "Focus"
            }
            return display.hasDDC ? "Power Off" : "Needs DDC"
        }

        if km.shiftKeyPressed {
            return "Darken"
        }

        #if arch(arm64)
            if #available(macOS 13, *), km.commandKeyPressed {
                return newBlackOutDisconnect ? "BlackOut" : "Disconnect"
            }

            return newBlackOutDisconnect ? "Disconnect" : "BlackOut"
        #else
            return "BlackOut"
        #endif
    }

    var color: Color {
        if poweringOff.value || display.blackOutEnabled {
            return Color.gray
        }

        if km.controlKeyPressed {
            return Color.orange
        }

        if DC.activeDisplayCount == 1 {
            return Colors.red
        }

        if km.optionKeyPressed, !km.shiftKeyPressed, !display.hasDDC {
            return Color.gray
        }
        return Colors.red
    }

    var body: some View {
        HStack(spacing: 2) {
            SwiftUI.Button(action: {
                if km.controlKeyPressed, km.commandKeyPressed, DC.activeDisplayCount > 1 {
                    display.unmanaged = true
                    return
                }

                guard !KM.controlKeyPressed,
                      lunarProActive || lunarProOnTrial || (KM.optionKeyPressed && !KM.shiftKeyPressed)
                else {
                    showPopover = true
                    return
                }

                guard neverShowBlackoutPopover else {
                    showPopover = true
                    return
                }

                poweringOff.set(true, expireAfter: 1)
                if display.blackOutEnabled {
                    display.powerOn()
                } else {
                    display.powerOff()
                }
            }) {
                Image(systemName: "power").font(.system(size: 10, weight: .heavy))
            }

            .buttonStyle(FlatButton(
                color: color,
                circle: true,
                horizontalPadding: 3,
                verticalPadding: 3
            ))
            .popover(isPresented: $showPopover) {
                BlackoutPopoverView(hasDDC: display.hasDDC).onDisappear {
                    if !neverShowBlackoutPopover {
                        neverShowBlackoutPopover = true
                    }
                }
            }
            .onHover { h in withAnimation { hovering = h } }
            .disabled((km.optionKeyPressed && !km.shiftKeyPressed && !display.hasDDC) || poweringOff.value)

            Text(actionText)
                .font(.system(size: 10, weight: .semibold))
                .opacity(hovering ? 1 : 0)
        }
        .frame(width: 100, alignment: .leading)
    }
}

#if arch(arm64)
    @available(macOS 13, *)
    struct ReconnectButtonView: View {
        @State var display: CGDirectDisplayID
        @State var hovering = false
        @State var off = true

        var body: some View {
            HStack(spacing: 2) {
                SwiftUI.Button(action: {
                    off = false
                    DC.autoBlackoutPause = true
                    DC.en(display)
                }) {
                    Image(systemName: "power").font(.system(size: 10, weight: .heavy))
                }
                .buttonStyle(FlatButton(
                    color: off ? Color.gray : Colors.red,
                    circle: true,
                    horizontalPadding: 3,
                    verticalPadding: 3
                ))
                .onHover { h in withAnimation { hovering = h } }
                Text("Connect")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(hovering ? 1 : 0)
            }
            .frame(width: 100, alignment: .leading)
        }
    }

    @available(macOS 13, *)
    struct DisconnectedDisplayView: View {
        @Environment(\.colors) var colors

        @State var id: CGDirectDisplayID
        @State var name: String
        @State var possibly = false

        @ObservedObject var display: Display
        @Default(.autoBlackoutBuiltin) var autoBlackoutBuiltin

        var body: some View {
            VStack(spacing: 1) {
                HStack(alignment: .top, spacing: -10) {
                    Text(name)
                        .font(.system(size: 22, weight: .black))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(colors.bg.primary.opacity(0.5)))

                    ReconnectButtonView(display: id)
                        .offset(y: -8)
                }.offset(x: 45)

                Text(possibly ? "Possibly disconnected" : "Disconnected")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))

                if display.id == id, !display.isSidecar, !display.isAirplay {
                    let binding = !display.isMacBook ? $display.keepDisconnected : Binding<Bool>(
                        get: { autoBlackoutBuiltin },
                        set: {
                            autoBlackoutBuiltin = $0
                            display.keepDisconnected = $0
                        }
                    )
                    VStack {
                        SettingsToggle(
                            text: "Auto Disconnect",
                            setting: binding,
                            color: nil,
                            help: !display.isMacBook
                                ? """
                                The display might come back on by itself after standby/wake or when
                                reconnecting the monitor cable.

                                This option will automatically disconnect the display whenever that
                                happens, until you reconnect the display manually using the power button.

                                Note: Press ⌘ Command more than 8 times in a row to force connect all displays.
                                """
                                : """
                                Turns off the built-in screen automatically when a monitor is connected and turns
                                it back on when the last monitor is disconnected.

                                Keeps the screen disconnected between standby/wake or lid open/close states.

                                Note: Press ⌘ Command more than 8 times in a row to force connect all displays.
                                """
                        )
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
                    .padding(.vertical, 3)
                }
            }
        }
    }

#endif

struct UnmanagedDisplayView: View {
    @Environment(\.colors) var colors

    @ObservedObject var display: Display

    var body: some View {
        VStack(spacing: 1) {
            HStack(alignment: .top, spacing: -10) {
                Text(display.name)
                    .font(.system(size: 22, weight: .black))
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(colors.bg.primary.opacity(0.5)))

                ManageButtonView(display: display)
                    .offset(y: -8)
            }.offset(x: 45)
            Text("Not managed").font(.system(size: 10, weight: .semibold, design: .rounded))
        }
    }
}

struct ManageButtonView: View {
    @State var display: Display
    @State var hovering = false
    @State var off = true

    var body: some View {
        HStack(spacing: 2) {
            SwiftUI.Button(action: {
                off = false
                display.unmanaged = false
            }) {
                Image(systemName: "power").font(.system(size: 10, weight: .heavy))
            }
            .buttonStyle(FlatButton(
                color: off ? Color.gray : Colors.red,
                circle: true,
                horizontalPadding: 3,
                verticalPadding: 3
            ))
            Text("Unignore")
                .font(.system(size: 10, weight: .semibold))
                .opacity(hovering ? 1 : 0)
        }
        .onHover { h in withAnimation { hovering = h } }
        .frame(width: 100, alignment: .leading)
    }
}

// MARK: - DisplayRowView

struct AllDisplaysView: View {
    @ObservedObject var display: Display = ALL_DISPLAYS
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors
    @Default(.showSliderValues) var showSliderValues
    @Default(.mergeBrightnessContrast) var mergeBrightnessContrast

    @ViewBuilder var softwareSliders: some View {
        if display.subzero {
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

    var body: some View {
        VStack(spacing: 4) {
            Text(display.name)
                .font(.system(size: 22, weight: .black))
                .padding(.bottom, 6)

            if mergeBrightnessContrast {
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
        }
    }
}

struct DisplayRowView: View {
    static var hoveringVolumeSliderTask: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }

    @ObservedObject var display: Display
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors
    @Default(.showSliderValues) var showSliderValues
    #if arch(arm64)
        @Default(.syncNits) var syncNits
    #endif

    @Default(.showInputInQuickActions) var showInputInQuickActions
    @Default(.showPowerInQuickActions) var showPowerInQuickActions
    @Default(.showXDRSelector) var showXDRSelector
    @Default(.showRawValues) var showRawValues
    @Default(.xdrTipShown) var xdrTipShown
    @Default(.autoXdr) var autoXdr
    @Default(.syncMode) var syncMode

    @State var showNeedsLunarPro = false
    @State var showXDRTip = false
    @State var showSubzero = false
    @State var showXDR = false

    @State var hoveringVolumeSlider = false

    @Default(.autoBlackoutBuiltin) var autoBlackoutBuiltin

    @State var adaptiveStateText = ""
    @State var adaptivePausedText = "Adaptive brightness paused"

    @State var editingMaxNits = false
    @State var editingMinNits = false

    @State var hovering = false

    var softwareSliders: some View {
        Group {
            if display.enhanced {
                BigSurSlider(
                    percentage: $display.xdrBrightness,
                    image: "sun.max.circle.fill",
                    color: Colors.xdr.opacity(0.7),
                    backgroundColor: Colors.xdr.opacity(colorScheme == .dark ? 0.1 : 0.2),
                    knobColor: Colors.xdr,
                    showValue: $showSliderValues,
                    beforeSettingPercentage: { _ in display.forceHideSoftwareOSD = true }
                )
            }
            if display.subzero {
                BigSurSlider(
                    percentage: $display.softwareBrightness,
                    image: "moon.circle.fill",
                    color: Colors.subzero.opacity(0.7),
                    backgroundColor: Colors.subzero.opacity(colorScheme == .dark ? 0.1 : 0.2),
                    knobColor: Colors.subzero,
                    showValue: $showSliderValues,
                    beforeSettingPercentage: { _ in display.forceHideSoftwareOSD = true }
                ) { _ in
                    guard display.adaptiveSubzero else { return }

                    let lastDataPoint = datapointLock.around { DC.adaptiveMode.brightnessDataPoint.last }
                    display.insertBrightnessUserDataPoint(lastDataPoint, display.brightness.doubleValue, modeKey: DC.adaptiveModeKey)
                }
            }
        }
    }

    var sdrXdrSelector: some View {
        HStack(spacing: 2) {
            SwiftUI.Button("SDR") {
                guard display.enhanced else { return }
                withAnimation(.fastSpring) { display.enhanced = false }
            }
            .buttonStyle(PickerButton(
                onColor: Color.black, offColor: .oneway { colors.invertedGray }, enumValue: $display.enhanced, onValue: false
            ))
            .font(.system(size: 11, weight: display.enhanced ? .semibold : .bold, design: .monospaced))

            SwiftUI.Button("XDR") {
                guard lunarProActive || lunarProOnTrial else {
                    showNeedsLunarPro = true
                    return
                }
                guard !display.enhanced else { return }
                withAnimation(.fastSpring) { display.enhanced = true }
                if !xdrTipShown, autoXdr {
                    xdrTipShown = true
                    mainAsyncAfter(ms: 2000) {
                        showXDRTip = true
                    }
                }
            }
            .buttonStyle(PickerButton(
                onColor: Color.black, offColor: .oneway { colors.invertedGray }, enumValue: $display.enhanced, onValue: true
            ))
            .font(.system(size: 11, weight: display.enhanced ? .bold : .semibold, design: .monospaced))
            .popover(isPresented: $showNeedsLunarPro) { NeedsLunarProView() }
            .popover(isPresented: $showXDRTip) { XDRTipView() }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(colors.invertedGray))
        .padding(.bottom, 4)
    }

    var inputSelector: some View {
        Dropdown(
            selection: $display.inputSource,
            width: 150,
            height: 20,
            noValueText: "Video Input",
            noValueImage: "input",
            content: .constant(VideoInputSource.mostUsed)
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

    var disabledReason: String? {
        if display.noControls {
            return "No controls available"
        } else if display.useOverlay {
            if display.isInHardwareMirrorSet {
                return "Overlay dimming disabled while mirroring"
            } else if display.isIndependentDummy {
                return "Overlay dimming disabled for dummy"
            }
        }

        return nil
    }

    @ViewBuilder var appPresetAdaptivePaused: some View {
        if (display.hasDDC && showInputInQuickActions)
            || display.showOrientation
            || display.appPreset != nil
            || display.adaptivePaused
            || showRawValues && (display.lastRawBrightness != nil || display.lastRawContrast != nil || display.lastRawVolume != nil)
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
                    .font(.system(size: 9, weight: .semibold))
                }
                if display.adaptivePaused || SWIFTUI_PREVIEW {
                    SwiftUI.Button(adaptivePausedText) { display.adaptivePaused.toggle() }
                        .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .secondary.opacity(0.8)))
                        .font(.system(size: 9, weight: .semibold))
                        .onHover { hovering in
                            adaptivePausedText = hovering ? "Resume adaptive brightness" : "Adaptive brightness paused"
                        }
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

    @ViewBuilder var volumeSlider: some View {
        if display.hasDDC, display.showVolumeSlider, display.ddcEnabled || display.networkEnabled {
            ZStack {
                BigSurSlider(
                    percentage: $display.preciseVolume.f,
                    imageBinding: .oneway { display.audioMuted ? "speaker.slash.fill" : "speaker.2.fill" },
                    colorBinding: .constant(colors.accent),
                    backgroundColorBinding: .constant(colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues,
                    disabled: $display.audioMuted,
                    enableText: "Unmute"
                )
                if hoveringVolumeSlider, !display.audioMuted {
                    SwiftUI.Button("Mute") {
                        display.audioMuted = true
                    }
                    .buttonStyle(FlatButton(
                        color: Colors.red.opacity(0.7),
                        textColor: .white,
                        horizontalPadding: 6,
                        verticalPadding: 2
                    ))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .transition(.scale.animation(.fastSpring))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .offset(x: -120, y: 0)
                }
            }.onHover { hovering in
                Self.hoveringVolumeSliderTask = mainAsyncAfter(ms: 150) {
                    hoveringVolumeSlider = hovering
                }
            }
        }
    }

    @ViewBuilder var sliders: some View {
        if display.noDDCOrMergedBrightnessContrast {
            let mergedLockBinding = Binding<Bool>(
                get: { display.lockedBrightness && display.lockedContrast },
                set: { display.lockedBrightness = $0 }
            )
            HStack {
                #if arch(arm64)
                    NitsTextField(nits: $display.minNits, placeholder: "min", display: display)
                        .opacity(hovering ? 1 : 0)
                #endif
                BigSurSlider(
                    percentage: $display.preciseBrightnessContrast.f,
                    image: "sun.max.fill",
                    colorBinding: .constant(colors.accent),
                    backgroundColorBinding: .constant(colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues,
                    disabled: mergedLockBinding,
                    enableText: "Unlock",
                    insideText: nitsText
                )
                #if arch(arm64)
                    let maxNitsBinding = Binding<Double>(
                        get: { display.userMaxNits ?? display.maxNits },
                        set: {
                            display.userMaxNits = nil
                            display.maxNits = $0
                        }
                    )
                    NitsTextField(nits: maxNitsBinding, placeholder: "max", display: display)
                        .opacity(hovering ? 1 : 0)
                #endif
            }
            softwareSliders
        } else {
            BigSurSlider(
                percentage: $display.preciseBrightness.f,
                image: "sun.max.fill",
                colorBinding: .constant(colors.accent),
                backgroundColorBinding: .constant(colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                showValue: $showSliderValues,
                disabled: $display.lockedBrightness,
                enableText: "Unlock",
                insideText: nitsText
            )
            softwareSliders
            let contrastBinding: Binding<Float> = Binding(
                get: { display.preciseContrast.f },
                set: { val in
                    display.withoutLockedContrast {
                        display.preciseContrast = val.d
                    }
                }
            )
            BigSurSlider(
                percentage: contrastBinding,
                image: "circle.righthalf.fill",
                colorBinding: .constant(colors.accent),
                backgroundColorBinding: .constant(colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                showValue: $showSliderValues
            )
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            let xdrSelectorShown = display.supportsEnhance && showXDRSelector && !display.blackOutEnabled
            if showPowerInQuickActions, display.getPowerOffEnabled() {
                HStack(alignment: .top, spacing: -10) {
                    Text(display.name)
                        .font(.system(size: 22, weight: .black))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(colors.bg.primary.opacity(0.5)))
                        .padding(.bottom, xdrSelectorShown ? 0 : 6)

                    PowerOffButtonView(display: display)
                        .offset(y: -8)
                }.offset(x: 45)

            } else {
                Text(display.name ?! "Unknown")
                    .font(.system(size: 22, weight: .black))
                    .padding(.bottom, xdrSelectorShown ? 0 : 6)
            }

            if let disabledReason {
                Text(disabledReason).font(.system(size: 10, weight: .semibold, design: .rounded))
            } else if display.blackOutEnabled {
                Text("Blacked Out").font(.system(size: 10, weight: .semibold, design: .rounded))

                if display.isMacBook {
                    let binding = Binding<Bool>(
                        get: { autoBlackoutBuiltin },
                        set: {
                            autoBlackoutBuiltin = $0
                            display.keepDisconnected = $0
                        }
                    )

                    VStack {
                        SettingsToggle(
                            text: "Auto BlackOut",
                            setting: binding,
                            color: nil,
                            help: """
                            Turns off the built-in screen automatically when a monitor is connected and turns
                            it back on when the last monitor is disconnected.

                            Keeps the screen disconnected between standby/wake or lid open/close states.

                            Note: Press ⌘ Command more than 8 times in a row to force connect all displays.
                            """
                        )
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
                    .padding(.vertical, 3)
                }
            } else {
                if xdrSelectorShown { sdrXdrSelector }

                sliders
                adaptiveState
                volumeSlider
                appPresetAdaptivePaused
            }
        }.onHover { h in withAnimation { hovering = h } }
    }

    @ViewBuilder var adaptiveState: some View {
        let systemAdaptive = display.systemAdaptiveBrightness
        let key = DC.adaptiveModeKey
        if !display.adaptive, !display.xdr, !display.blackout, !display.facelight, !display.subzero, (key == .sync && !display.isActiveSyncSource) || key == .location || key == .sensor || key == .clock {
            SwiftUI.Button(adaptiveStateText.isEmpty ? (systemAdaptive ? "Adapted by the system" : "Adaptive brightness disabled") : adaptiveStateText) {
                display.adaptive = true
            }
            .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .secondary.opacity(0.8)))
            .font(.system(size: 9, weight: .semibold))
            .onHover { hovering in
                adaptiveStateText = hovering ? "Adapt brightness with Lunar" : ""
            }
        }
    }

    func nitsText() -> AnyView {
        #if arch(arm64)
            guard SyncMode.isUsingNits(), display.isNative, let nits = display.nits else {
                return EmptyView().any
            }
            return VStack(spacing: -3) {
                Text("\(nits.intround)")
                Text("nits")
            }
            .font(.system(size: 8, weight: .bold, design: .rounded).leading(.tight))
            .foregroundColor((display.preciseBrightnessContrast < 0.25 && colorScheme == .dark) ? Colors.lightGray.opacity(0.6) : Colors.grayMauve.opacity(0.7))
            .any
        #else
            EmptyView().any
        #endif
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

#if arch(arm64)
    struct NitsTextField: View {
        @Binding var nits: Double
        @State var placeholder: String
        @ObservedObject var display: Display
        @State var editing = false

        @Default(.syncMode) var syncMode

        var editPopover: some View {
            PaddedPopoverView(background: Colors.peach.any) {
                VStack {
                    Text("\(placeholder.titleCase())imum nits")
                        .font(.title.bold())
                    Text("for \(display.name)")

                    TextField("nits", value: $nits, formatter: NumberFormatter.shared(decimals: 0, padding: 0))
                        .onReceive(Just(nits)) { _ in
                            display.nitsEditPublisher.send(true)
                        }
                        .textFieldStyle(PaddedTextFieldStyle(backgroundColor: .primary.opacity(0.1)))
                        .font(.system(size: 20, weight: .bold, design: .monospaced).leading(.tight))
                        .lineLimit(1)
                        .frame(width: 70)
                        .multilineTextAlignment(.center)
                        .padding(.vertical)

                    Text("Value estimated from monitor\nfirmware data and user input")
                        .font(.system(size: 12, weight: .medium, design: .rounded).leading(.tight))
                        .foregroundColor(Colors.grayMauve.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
        }

        var body: some View {
            if syncMode, SyncMode.isUsingNits() {
                let disabled = display.isNative && (placeholder == "max" || display.isActiveSyncSource)
                SwiftUI.Button(action: { editing = true }) {
                    VStack(spacing: -3) {
                        Text(nits.str(decimals: 0))
                            .font(.system(size: 10, weight: .bold, design: .monospaced).leading(.tight))
                        Text("nits")
                            .font(.system(size: 8, weight: .semibold, design: .rounded).leading(.tight))
                    }
                }
                .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                .frame(width: 50)
                .popover(isPresented: $editing) { editPopover }
                .disabled(disabled)
                .help(disabled ? "Managed by the system" : "")
            }
        }
    }

#endif

// MARK: - NeedsLunarProView

struct NeedsLunarProView: View {
    var body: some View {
        PaddedPopoverView(background: Colors.red.brightness(0.1).any) {
            HStack(spacing: 4) {
                Text("Needs a")
                    .foregroundColor(.black.opacity(0.8))
                    .font(.system(size: 16, weight: .semibold))
                SwiftUI.Button("Lunar Pro") { appDelegate!.getLunarPro(appDelegate!) }
                    .buttonStyle(FlatButton(color: .black.opacity(0.3), textColor: .white))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("licence")
                    .foregroundColor(.black.opacity(0.8))
                    .font(.system(size: 16, weight: .semibold))
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

// MARK: - HDRSettingsView

struct HDRSettingsView: View {
    @ObservedObject var dc: DisplayController = DC

    @Default(.hdrWorkaround) var hdrWorkaround
    @Default(.xdrContrast) var xdrContrast
    @Default(.xdrContrastFactor) var xdrContrastFactor
    @Default(.allowHDREnhanceBrightness) var allowHDREnhanceBrightness
    @Default(.allowHDREnhanceContrast) var allowHDREnhanceContrast

    @Default(.autoXdr) var autoXdr
    @Default(.autoSubzero) var autoSubzero
    @Default(.disableNightShiftXDR) var disableNightShiftXDR
    @Default(.enableDarkModeXDR) var enableDarkModeXDR
    @Default(.autoXdrSensor) var autoXdrSensor
    @Default(.autoXdrSensorShowOSD) var autoXdrSensorShowOSD
    @Default(.autoXdrSensorLuxThreshold) var autoXdrSensorLuxThreshold

    var body: some View {
        ZStack {
            Color.clear.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading) {
                Group {
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
                        text: "Allow XDR on non-Apple HDR monitors", setting: $allowHDREnhanceBrightness.animation(.fastSpring),
                        help: """
                        This should work for HDR monitors that have higher brightness LEDs.
                        Known issues: some monitors turn to grayscale/monochrome when XDR is enabled.

                        In case of any issue, uncheck this and restart your computer to revert any changes.
                        """
                    )

                    if DC.activeDisplayList.contains(where: \.supportsEnhance) {
                        SettingsToggle(
                            text: "Enhance contrast in XDR Brightness", setting: $xdrContrast,
                            help: """
                            Improve readability in sunlight by increasing XDR contrast.
                            This option is especially useful when using apps with dark backgrounds.

                            Note: works only when using a single display
                            """
                        )
                        HStack {
                            BigSurSlider(
                                percentage: $xdrContrastFactor,
                                image: "circle.lefthalf.filled",
                                color: Colors.lightGray,
                                backgroundColor: Colors.grayMauve.opacity(0.1),
                                knobColor: Colors.lightGray,
                                showValue: .constant(false),
                                disabled: !$xdrContrast
                            )
                            .padding(.leading)

                            SwiftUI.Button("Reset") { xdrContrastFactor = 0.3 }
                                .buttonStyle(FlatButton(
                                    color: Colors.lightGray,
                                    textColor: Colors.darkGray,
                                    radius: 10,
                                    verticalPadding: 3
                                ))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .disabled(!xdrContrast)
                        }
                        SettingsToggle(text: "Allow on non-Apple HDR monitors", setting: $allowHDREnhanceContrast.animation(.fastSpring))
                            .padding(.leading)
                            .disabled(!xdrContrast)
                    }
                }
                Divider()
                xdrSettings
                Spacer()
                Color.clear
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var xdrSettings: some View {
        Group {
            SettingsToggle(text: "Disable Night Shift and f.lux when toggling XDR", setting: $disableNightShiftXDR.animation(.fastSpring))
            SettingsToggle(
                text: "Enable Dark Mode when toggling XDR", setting: $enableDarkModeXDR.animation(.fastSpring),
                help: """
                Use dark backgrounds with bright text for minimizing power usage and LED temperature while XDR is active.

                This works best in combination with the "Enhance contrast in XDR Brightness" setting.
                """
            )
            SettingsToggle(text: "Toggle XDR Brightness when going over 100%", setting: $autoXdr.animation(.fastSpring))
            SettingsToggle(
                text: "Toggle Sub-zero Dimming when going below 0%",
                setting: $autoSubzero.animation(.fastSpring)
            )

            if Sysctl.isMacBook, DC.builtinDisplay?.supportsEnhance ?? false {
                Divider().padding(.horizontal)
                VStack(alignment: .leading, spacing: 2) {
                    SettingsToggle(text: "Toggle XDR Brightness based on ambient light", setting: $autoXdrSensor)
                    Text(
                        """
                        XDR Brightness will be automatically enabled
                        when ambient light is above \(autoXdrSensorLuxThreshold.str(decimals: 0)) lux
                        """
                    )
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.black.opacity(0.4))
                    .fixedSize()
                    .padding(.leading, 20)
                }
                HStack {
                    let luxBinding = Binding<Float>(
                        get: { powf(max(autoXdrSensorLuxThreshold - XDR_LUX_LEAST_NONZERO, 0) / XDR_MAX_LUX, 0.25) },
                        set: { autoXdrSensorLuxThreshold = powf($0, 4) * XDR_MAX_LUX + XDR_LUX_LEAST_NONZERO }
                    )
                    BigSurSlider(
                        percentage: luxBinding,
                        image: "sun.dust.fill",
                        color: Colors.lightGray,
                        backgroundColor: Colors.grayMauve.opacity(0.1),
                        knobColor: Colors.lightGray,
                        showValue: .constant(false),
                        disabled: !$autoXdrSensor,
                        mark: .oneway { powf(max(dc.internalSensorLux - XDR_LUX_LEAST_NONZERO, 0) / XDR_MAX_LUX, 0.25) }
                    )
                    .padding(.leading)

                    SwiftUI.Button("Reset") { autoXdrSensorLuxThreshold = XDR_DEFAULT_LUX }
                        .buttonStyle(FlatButton(
                            color: Colors.lightGray,
                            textColor: Colors.darkGray,
                            radius: 10,
                            verticalPadding: 3
                        ))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .disabled(!autoXdrSensor)
                }
                if autoXdrSensor {
                    (
                        Text(dc.autoXdrSensorPausedReason ?? "Current ambient light: ")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            + Text(dc.autoXdrSensorPausedReason == nil ? "\(dc.internalSensorLux.str(decimals: 0)) lux" : "")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    )
                    .foregroundColor(.black.opacity(0.4))
                    .padding(.leading, 20)
                }
                VStack(alignment: .leading, spacing: 2) {
                    SettingsToggle(text: "Show OSD when toggling XDR automatically", setting: $autoXdrSensorShowOSD.animation(.fastSpring))
                    (
                        Text("Notifies you when XDR is activating and\n")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced).leading(.tight))
                            + Text("allows aborting AutoXDR by pressing ")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced).leading(.tight))
                            + Text("Esc")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced).leading(.tight))
                    )
                    .foregroundColor(.black.opacity(0.4))
                    .fixedSize()
                    .padding(.leading, 20)
                }.padding(.leading)
            }
        }
    }
}

// MARK: - AdvancedSettingsView

struct AdvancedSettingsView: View {
    @ObservedObject var dc: DisplayController = DC

    @Default(.workaroundBuiltinDisplay) var workaroundBuiltinDisplay
    @Default(.ddcSleepLonger) var ddcSleepLonger
    @Default(.clamshellModeDetection) var clamshellModeDetection
    @Default(.enableOrientationHotkeys) var enableOrientationHotkeys
    @Default(.detectResponsiveness) var detectResponsiveness
    @Default(.disableControllerVideo) var disableControllerVideo
    @Default(.allowBlackOutOnSingleScreen) var allowBlackOutOnSingleScreen
    @Default(.reapplyValuesAfterWake) var reapplyValuesAfterWake
    @Default(.clockMode) var clockMode
    @Default(.oldBlackOutMirroring) var oldBlackOutMirroring
    @Default(.newBlackOutDisconnect) var newBlackOutDisconnect

    @Default(.refreshValues) var refreshValues
    @Default(.gammaDisabledCompletely) var gammaDisabledCompletely
    @Default(.waitAfterWakeSeconds) var waitAfterWakeSeconds
    @Default(.delayDDCAfterWake) var delayDDCAfterWake

    @Default(.autoRestartOnFailedDDC) var autoRestartOnFailedDDC
    @Default(.autoRestartOnFailedDDCSooner) var autoRestartOnFailedDDCSooner
    @Default(.sleepInClamshellMode) var sleepInClamshellMode

    @State var sensorCheckerEnabled = !Defaults[.sensorHostname].isEmpty

    var body: some View {
        ZStack {
            Color.clear.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading) {
                Group {
                    #if arch(arm64)
                        if #available(macOS 13, *) {
                            SettingsToggle(
                                text: "Disable the Disconnect API in BlackOut", setting: !$newBlackOutDisconnect,
                                help: """
                                BlackOut can use a hidden macOS API to disconnect the display entirely,
                                freeing up GPU resources and allowing for an easy reconnection when needed.

                                If you're having trouble with how this works, you can switch to the old
                                method of mirroring the display to disable it.

                                Note: Press ⌘ Command more than 8 times in a row to force connect all displays.

                                In case the built-in MacBook display doesn't reconnect itself when it should,
                                close the laptop lid and reopen it to bring the display back.

                                For external displays, disconnect and reconnect the cable to fix any issue.
                                """
                            )
                        }
                    #endif

                    SettingsToggle(
                        text: "Allow BlackOut on single screen", setting: $allowBlackOutOnSingleScreen,
                        help: "Allows turning off a screen even if it's the only visible screen left"
                    )
                    if Sysctl.isMacBook {
                        SettingsToggle(
                            text: "Force Sleep when the lid is closed", setting: $sleepInClamshellMode,
                            help: """
                            When the MacBook is connected to a monitor that's also charging the Mac,
                            closing the lid will start Clamshell Mode.

                            That system feature keeps the system awake to allow you to use the external
                            monitor with the lid closed.

                            If you don't use that feature, enabling this option will disable Clamshell
                            Mode automatically when the lid is closed.
                            """
                        )
                    }

                    #if !arch(arm64)
                        if #available(macOS 13, *) {
                        } else {
                            SettingsToggle(
                                text: "Switch to the old BlackOut mirroring system", setting: $oldBlackOutMirroring,
                                help: """
                                Some setups will have trouble enabling mirroring with the new macOS 11+ API.

                                You can try enabling this option if BlackOut is not working properly.

                                Note: the old mirroring system can't handle complex mirror sets with dummies and virtual/wireless displays.
                                The best covered cases are "BlackOut built-in display" and "BlackOut only external displays".
                                """
                            )
                        }
                    #endif
                    Divider()

                    SettingsToggle(
                        text: "Use workaround for built-in display", setting: $workaroundBuiltinDisplay,
                        help: """
                        Forward brightness key events to the system instead of
                        changing built-in display brightness from Lunar.

                        This setting might be needed to persist brightness
                        changes better on some specific older devices.

                        Disables the following functions for the built-in display:
                          • Hotkey Step
                          • Auto XDR
                          • Sub-zero Dimming
                        """
                    )
                    if Sysctl.isMacBook {
                        SettingsToggle(
                            text: "Toggle Manual/Sync when the lid is closed/opened",
                            setting: $clamshellModeDetection
                        )
                    }
                    SettingsToggle(
                        text: "Re-apply last brightness on screen wake", setting: $reapplyValuesAfterWake,
                        help: """
                        On each screen wake/reconnection, Lunar will try to
                        re-apply previous brightness and contrast 3 times.

                        Disable this if system appears slow on screen wake.
                        """
                    )
                }
                Divider()
                Group {
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
                    if dc.activeDisplayList.contains(where: \.hasDDC) {
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
                    }
                    if dc.activeDisplayList.contains(where: { $0.control is NetworkControl }) {
                        SettingsToggle(
                            text: "Disable Network Controller video ", setting: $disableControllerVideo,
                            help: """
                            When using "Network Control" with a Raspberry Pi, it might be
                            helpful to disable the Pi desktop if you don't need it.
                            """
                        )
                    }
                    SettingsToggle(
                        text: "Check for network light sensors periodically", setting: $sensorCheckerEnabled,
                        help: """
                        To enable "Sensor Mode", Lunar periodically checks if a wireless light
                        sensor is available using local DNS requests. You can disable this if
                        you never intend to use a wireless ambient light sensor.
                        """
                    )
                    Divider()
                    Group {
                        Text("EXPERIMENTAL!")
                            .foregroundColor(Colors.red)
                            .bold()
                        Text("Don't use unless really needed or asked by the developer")
                            .foregroundColor(Colors.red)
                            .font(.caption)
                        SettingsToggle(
                            text: "Disable usage of Gamma API completely", setting: $gammaDisabledCompletely,
                            help: """
                            Experimental: for people running into macOS bugs like the color profile
                            being constantly reset, display turning to monochrome or HDR being disabled,
                            this could be a safe measure to ensure Lunar never touches the Gamma API of macOS.

                            This will disable or cripple the following features:

                            • XDR Brightness
                            • Facelight
                            • Blackout
                            • Software Dimming
                            • Sub-zero Dimming
                            """
                        )
                        if dc.activeDisplayList.contains(where: \.hasDDC) {
                            SettingsToggle(
                                text: "Auto restart Lunar when DDC fails", setting: $autoRestartOnFailedDDC,
                                help: """
                                Experimental: for people running into macOS bugs where a monitor can no longer
                                be controlled. You might see a lock icon when brightness keys are pressed.

                                To avoid jarring brightness changes, this will not restart the app
                                if any of the following features are in active use:

                                • XDR Brightness
                                • Facelight
                                • Blackout
                                • Sub-zero Dimming
                                """
                            )
                            SettingsToggle(
                                text: "Avoid safety checks", setting: $autoRestartOnFailedDDCSooner,
                                help: """
                                Don't wait for the detection of DDC fail to happen more than once, and restart
                                the app even if it could cause a jarring brightness change.
                                """
                            ).padding(.leading)

                            SettingsToggle(
                                text: "Delay DDC commands after wake", setting: $delayDDCAfterWake,
                                help: """
                                Experimental: for people running into monitor bugs like the video signal being
                                lost or screen not waking up after system sleep, this could be a safe measure
                                to ensure Lunar doesn't send any DDC command until the monitor connection
                                is fully established.

                                This will disable or cripple the following features:

                                • Smooth transitions
                                • DDC responsiveness checker
                                • Re-applying color gain on wake
                                • Re-applying brightness/contrast on wake
                                """
                            )
                            HStack {
                                let secondsBinding = Binding<Float>(
                                    get: { waitAfterWakeSeconds.f / 100 },
                                    set: { waitAfterWakeSeconds = ($0 * 100).i }
                                )
                                BigSurSlider(
                                    percentage: secondsBinding,
                                    image: "clock.circle",
                                    color: Colors.lightGray,
                                    backgroundColor: Colors.grayMauve.opacity(0.1),
                                    knobColor: Colors.lightGray,
                                    showValue: .constant(true),
                                    disabled: !$delayDDCAfterWake
                                )
                                .padding(.leading)

                                SwiftUI.Button("Reset") { waitAfterWakeSeconds = 30 }
                                    .buttonStyle(FlatButton(
                                        color: Colors.lightGray,
                                        textColor: Colors.darkGray,
                                        radius: 10,
                                        verticalPadding: 3
                                    ))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .disabled(!delayDDCAfterWake)
                            }
                            if delayDDCAfterWake {
                                Text("Lunar will wait \(waitAfterWakeSeconds) seconds before sending\nthe first DDC command after screen wake")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.4))
                                    .frame(height: 28, alignment: .topLeading)
                                    .fixedSize()
                                    .lineLimit(2)
                                    .padding(.leading, 20)
                                    .padding(.top, -5)
                            }
                        }
                    }
                }
                Spacer()
                Color.clear
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: sensorCheckerEnabled) { enabled in
            Defaults[.sensorHostname] = enabled ? "lunarsensor.local" : ""
        }
    }
}

// MARK: - QuickActionsLayoutView

struct QuickActionsLayoutView: View {
    @ObservedObject var dc: DisplayController = DC

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
    @Default(.keepOptionsMenu) var keepOptionsMenu

    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @Default(.showDockIcon) var showDockIcon
    @Default(.moreGraphData) var moreGraphData
    @Default(.infoMenuShown) var infoMenuShown
    @Default(.adaptiveBrightnessMode) var adaptiveBrightnessMode

    var body: some View {
        ZStack {
            Color.clear.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading) {
                Group {
                    Group {
                        SettingsToggle(text: "Only show top buttons on hover", setting: $showHeaderOnHover.animation(.fastSpring))
                        SettingsToggle(text: "Only show bottom buttons on hover", setting: $showFooterOnHover.animation(.fastSpring))
                        SettingsToggle(text: "Save open-state for this menu", setting: $keepOptionsMenu.animation(.fastSpring))
                    }
                    Divider()
                    Group {
                        SettingsToggle(text: "Show slider values", setting: $showSliderValues.animation(.fastSpring))
                        if dc.activeDisplayList.contains(where: \.hasDDC) {
                            SettingsToggle(text: "Show volume slider", setting: $showVolumeSlider.animation(.fastSpring))
                            SettingsToggle(text: "Show input source selector", setting: $showInputInQuickActions.animation(.fastSpring))
                        }
                        SettingsToggle(text: "Show rotation selector", setting: $showOrientationInQuickActions.animation(.fastSpring))
                        SettingsToggle(text: "Show power button", setting: $showPowerInQuickActions.animation(.fastSpring))
                    }
                    Divider()
                    Group {
                        SettingsToggle(text: "Show standard presets", setting: $showStandardPresets.animation(.fastSpring))
                        SettingsToggle(text: "Show custom presets", setting: $showCustomPresets.animation(.fastSpring))
                        if dc.activeDisplayList.contains(where: \.supportsEnhance) {
                            SettingsToggle(text: "Show XDR Brightness buttons", setting: $showXDRSelector.animation(.fastSpring))
                        }
                    }
                }
                if dc.activeDisplayList.contains(where: \.hasDDC) {
                    SettingsToggle(text: "Merge brightness and contrast", setting: $mergeBrightnessContrast.animation(.fastSpring))
                }
                Divider()
                Group {
                    if adaptiveBrightnessMode.hasUsefulInfo {
                        SettingsToggle(text: "Show useful adaptive info near mode selector", setting: $infoMenuShown.animation(.fastSpring))
                    }
                    if dc.activeDisplayList.contains(where: \.hasDDC) {
                        SettingsToggle(text: "Show last raw values sent to the display", setting: $showRawValues.animation(.fastSpring))
                    }
                    SettingsToggle(text: "Show brightness near menubar icon", setting: $showBrightnessMenuBar.animation(.fastSpring))
                    SettingsToggle(
                        text: "Show only external monitor brightness",
                        setting: $showOnlyExternalBrightnessMenuBar.animation(.fastSpring)
                    )
                    .padding(.leading)
                    .disabled(!showBrightnessMenuBar)
                }
                Divider()
                Group {
                    SettingsToggle(text: "Hide menubar icon", setting: $hideMenuBarIcon)
                    SettingsToggle(text: "Show dock icon", setting: $showDockIcon)
                    SettingsToggle(
                        text: "Show more graph data",
                        setting: $moreGraphData,
                        help: "Renders values and data lines on the bottom graph of the preferences window"
                    )
                }
                Spacer()
                Color.clear
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    @Default(.newBlackOutDisconnect) var newBlackOutDisconnect

    var body: some View {
        ZStack {
            Color.black.brightness(0.02).scaleEffect(1.5)
            VStack(alignment: .leading, spacing: 10) {
                BlackoutPopoverHeaderView().padding(.bottom)
                if DC.activeDisplayCount == 1 {
                    BlackoutPopoverRowView(action: "Make screen black", hotkeyText: hotkeyText(id: .blackOut), actionInfo: "(without disabling it)")
                } else {
                    if newBlackOutDisconnect, #available(macOS 13, *) {
                        BlackoutPopoverRowView(action: "Disconnect screen", hotkeyText: hotkeyText(id: .blackOut), actionInfo: "(free up GPU)")
                    } else {
                        BlackoutPopoverRowView(action: "Soft power off", hotkeyText: hotkeyText(id: .blackOut), actionInfo: "(disables screen by mirroring)")
                    }
                    BlackoutPopoverRowView(
                        modifiers: ["Shift"],
                        action: "Make screen black",
                        hotkeyText: hotkeyText(id: .blackOutNoMirroring),
                        actionInfo: "(without disabling it)"
                    )
                    BlackoutPopoverRowView(
                        modifiers: ["Option", "Shift"],
                        action: "Make other screens black",
                        hotkeyText: hotkeyText(id: .blackOutOthers),
                        actionInfo: "(keep this one visible)"
                    )

                    #if arch(arm64)
                        if #available(macOS 13, *) {
                            Divider().background(Color.white.opacity(0.2))
                            if newBlackOutDisconnect {
                                BlackoutPopoverRowView(modifiers: ["Command"], action: "Soft power off", hotkeyText: "", actionInfo: "(disables screen by mirroring)")
                                    .colorMultiply(Color.orange)
                            } else {
                                BlackoutPopoverRowView(
                                    modifiers: ["Command"],
                                    action: "Disconnect screen",
                                    hotkeyText: "",
                                    actionInfo: "(free up GPU)"
                                )
                                .colorMultiply(Color.orange)
                            }
                        }
                    #endif
                }

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

struct PaddedTextFieldStyle: TextFieldStyle {
    @State var verticalPadding: CGFloat = 4
    @State var horizontalPadding: CGFloat = 8
    @State var backgroundColor: Color? = nil

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.font) var font

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(font ?? .system(size: 12, weight: .bold))
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor ?? .white.opacity(colorScheme == .dark ? 0.2 : 0.9))
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
    }
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

    @Published var hoveringSlider = false
    @Published var draggingSlider = false
    @Published var optionsTab: OptionsTab = .layout
}

// MARK: - OptionsTab

enum OptionsTab: String, DefaultsSerializable {
    case layout
    case advanced
    case hdr
}

// MARK: - QuickActionsMenuView

struct QuickActionsMenuView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors
    @EnvironmentObject var env: EnvState
    @ObservedObject var dc: DisplayController = DC
    @ObservedObject var um = UM
    @Namespace var namespace

    @Default(.overrideAdaptiveMode) var overrideAdaptiveMode
    @Default(.showStandardPresets) var showStandardPresets
    @Default(.showCustomPresets) var showCustomPresets
    @Default(.showHeaderOnHover) var showHeaderOnHover
    @Default(.showFooterOnHover) var showFooterOnHover
    @Default(.showOptionsMenu) var showOptionsMenu

    @Default(.menuBarClosed) var menuBarClosed
    @Default(.menuDensity) var menuDensity

    @Default(.showBrightnessMenuBar) var showBrightnessMenuBar
    @Default(.showOnlyExternalBrightnessMenuBar) var showOnlyExternalBrightnessMenuBar
    @Default(.showAdditionalInfo) var showAdditionalInfo
    @Default(.startAtLogin) var startAtLogin

    @State var displays: [Display] = DC.nonCursorDisplays
    @State var cursorDisplay: Display? = DC.cursorDisplay
    @State var sourceDisplay: Display? = DC.sourceDisplay
    #if arch(arm64)
        @State var disconnectedDisplays: [Display] = DC.possiblyDisconnectedDisplayList
        @State var possiblyDisconnectedDisplays: [Display] = []
    #endif
    @State var unmanagedDisplays: [Display] = DC.unmanagedDisplays
    @State var adaptiveModes: [AdaptiveModeKey] = [.sensor, .sync, .location, .clock, .manual, .auto]

    @State var headerOpacity: CGFloat = 1.0
    @State var footerOpacity: CGFloat = 1.0
    @State var additionalInfoButtonOpacity: CGFloat = 0.3
    @State var headerIndicatorOpacity: CGFloat = 0.0
    @State var footerIndicatorOpacity: CGFloat = 0

    @State var displayCount = DC.activeDisplayCount

    @ObservedObject var menuBarIcon: StatusItemButtonController

    @ObservedObject var km = KM
    @ObservedObject var wm = WM

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
                action: { showOptionsMenu.toggle() },
                label: {
                    HStack(spacing: 2) {
                        Image(systemName: "gear.circle.fill").font(.system(size: 12, weight: .semibold))
                        Text("Settings").font(.system(size: 13, weight: .semibold))
                    }
                }
            )
            .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
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

//            SwiftUI.Button(
//                action: {
//                    guard let view = menuWindow?.contentViewController?.view else { return }
//                    appDelegate!.menu.popUp(
//                        positioning: nil,
//                        at: NSPoint(
//                            x: env
//                                .menuWidth +
//                                (showOptionsMenu ? MENU_HORIZONTAL_PADDING * 2 : OPTIONS_MENU_WIDTH / 2 + MENU_HORIZONTAL_PADDING / 2),
//                            y: 0
//                        ),
//                        in: view
//                    )
//                },
//                label: {
//                    HStack(spacing: 2) {
//                        Image(systemName: "ellipsis.circle.fill").font(.system(size: 12, weight: .semibold))
//                        Text("Menu").font(.system(size: 13, weight: .semibold))
//                    }
//                }
//            ).buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
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
                VStack(spacing: 5) {
                    HStack {
                        Toggle(um.newVersion != nil ? "" : "App info", isOn: $showAdditionalInfo.animation(.fastSpring))
                            .toggleStyle(DetailToggleStyle(style: .circle))
                            .foregroundColor(Color.secondary)
                            .font(.system(size: 12, weight: .semibold))
                            .fixedSize()

                        Spacer()

                        if let version = um.newVersion {
                            SwiftUI.Button("v\(version) available") { appDelegate!.updater.checkForUpdates() }
                                .buttonStyle(FlatButton(
                                    color: Colors.peach,
                                    textColor: Colors.blackMauve,
                                    horizontalPadding: 6,
                                    verticalPadding: 3
                                ))
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(.leastNonzeroMagnitude)
                                .scaledToFit()
                        }

                        SwiftUI.Button("Display Settings") { appDelegate!.showPreferencesWindow(sender: nil) }
                            .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .fixedSize()

                        SwiftUI.Button("Restart") { appDelegate!.restartApp(appDelegate!) }
                            .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .fixedSize()

                        SwiftUI.Button("Quit") { NSApplication.shared.terminate(nil) }
                            .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .fixedSize()
                    }
                    .padding(.bottom, showAdditionalInfo ? 0 : 7)
                }
                .padding(.horizontal, MENU_HORIZONTAL_PADDING / 2)
                .opacity(showFooterOnHover ? footerOpacity : 1.0)
                .contentShape(Rectangle())
                .onChange(of: showFooterOnHover) { showOnHover in
                    withAnimation(.fastTransition) { footerOpacity = showOnHover ? 0.0 : 1.0 }
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
            }
            .frame(maxWidth: .infinity, maxHeight: footerOpacity == 0.0 ? 8 : nil)
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

            if let appDelegate, showAdditionalInfo {
                Divider().padding(.bottom, 5)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Toggle("Launch at login", isOn: $startAtLogin)
                            .toggleStyle(CheckboxToggleStyle(style: .circle))
                            .foregroundColor(.primary)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        SwiftUI.Button("Contact") { NSWorkspace.shared.open("https://lunar.fyi/contact".asURL()!) }
                            .buttonStyle(OutlineButton(thickness: 1, font: .system(size: 9, weight: .medium, design: .rounded)))
                        SwiftUI.Button("FAQ") { NSWorkspace.shared.open("https://lunar.fyi/faq".asURL()!) }
                            .buttonStyle(OutlineButton(thickness: 1, font: .system(size: 9, weight: .medium, design: .rounded)))
                    }
                    LicenseView()
                    VersionView(updater: appDelegate.updater)
                    MenuDensityView()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 25)
                .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if Defaults[.launchCount] == 1, !appInfoHiddenAfterLaunch {
                appInfoHiddenAfterLaunch = true
                additionInfoTask = mainAsyncAfter(ms: 1000) {
                    withAnimation(.spring()) {
                        showAdditionalInfo = true
                    }
                }
            }
            if Defaults[.launchCount] == 2, !appInfoHiddenAfterLaunch {
                appInfoHiddenAfterLaunch = true
                additionInfoTask = mainAsyncAfter(ms: 1000) {
                    withAnimation(.spring()) {
                        showAdditionalInfo = false
                    }
                }
            }
        }
    }

    var header: some View {
        let op = (showHeaderOnHover && !showOptionsMenu) ? headerOpacity : 1.0
        return ZStack {
            HStack {
                if !menuBarClosed {
                    modeSelector.fixedSize()
                    UsefulInfo().fixedSize()
                }
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

            if dc.adaptiveModeKey == .sync, let d = sourceDisplay, d.isAllDisplays {
                AllDisplaysView().padding(.bottom)
            }

            if let d = cursorDisplay, !SWIFTUI_PREVIEW {
                DisplayRowView(display: d).padding(.bottom)
            }

            ForEach(displays) { d in
                DisplayRowView(display: d).padding(.bottom)
            }

            #if arch(arm64)
                if #available(macOS 13, *) {
                    ForEach(disconnectedDisplays) { d in
                        if d.id != 1 || !dc.clamshell {
                            DisconnectedDisplayView(id: d.id, name: d.name, display: d).padding(.vertical, 7)
                        }
                    }

                    ForEach(possiblyDisconnectedDisplays) { d in
                        DisconnectedDisplayView(id: d.id, name: d.name, possibly: true, display: d).padding(.vertical, 7)
                    }

                    if !menuBarClosed, Sysctl.isMacBook, !dc.lidClosed, cursorDisplay?.id != 1, !displays.contains(where: { $0.id == 1 }), !disconnectedDisplays.contains(where: { $0.id == 1 }),
                       !(DC.builtinDisplays.first?.unmanaged ?? false)
                    {
                        DisconnectedDisplayView(id: 1, name: "Built-in", display: dc.displays[1] ?? GENERIC_DISPLAY).padding(.vertical, 7)
                    }
                }
            #endif

            ForEach(unmanagedDisplays) { d in
                UnmanagedDisplayView(display: d).padding(.vertical, 7)
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
        let optionsMenuOverflow = showOptionsMenu ? isOptionsMenuOverflowing() : false
        HStack(alignment: .top, spacing: 1) {
            if optionsMenuOverflow {
                optionsMenu.padding(.leading, 20)
                    .matchedGeometryEffect(id: "options-menu", in: namespace)
            }
            VStack {
                content
                footer
            }
            .frame(maxWidth: env.menuWidth, alignment: .center)
            .scrollOnOverflow()
            .frame(width: env.menuWidth, height: cap(env.menuHeight, minVal: 100, maxVal: env.menuMaxHeight - 50), alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.top, 0)
            .background(bg(optionsMenuOverflow: optionsMenuOverflow), alignment: .top)
            .onAppear {
                displayHideTask = nil
                setup()
            }
            .onChange(of: menuBarClosed) { closed in
                setup(closed)
            }
            .onChange(of: dc.activeDisplayList) { _ in
                mainAsyncAfter(ms: 10) { setup() }
            }
            .onChange(of: dc.sourceDisplay) { _ in
                mainAsyncAfter(ms: 10) { setup() }
            }
            .onChange(of: dc.possiblyDisconnectedDisplayList) { disconnected in
                mainAsyncAfter(ms: 10) {
                    setup()
                    let ids = disconnected.map(\.id)
                    displays = displays.filter { !ids.contains($0.id) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .onTapGesture { env.recording = false }

            .onChange(of: showStandardPresets, perform: setMenuWidth)
            .onChange(of: showCustomPresets, perform: setMenuWidth)
            .onChange(of: showHeaderOnHover, perform: setMenuWidth)
            .onChange(of: showFooterOnHover, perform: setMenuWidth)
            .onChange(of: showAdditionalInfo, perform: setMenuWidth)
            .onChange(of: headerOpacity, perform: setMenuWidth)
            .onChange(of: footerOpacity, perform: setMenuWidth)
            .onChange(of: showOptionsMenu) { show in
                guard !menuBarClosed else { return }

                setMenuWidth(show)
                if !show, let menuWindow {
                    menuWindow.setContentSize(.zero)
                }
                appDelegate?.statusItemButtonController?.repositionWindow()
            }

            if showOptionsMenu, !optionsMenuOverflow {
                optionsMenu.padding(.trailing, 20)
                    .matchedGeometryEffect(id: "options-menu", in: namespace)
            }
        }
        .frame(width: MENU_WIDTH + FULL_OPTIONS_MENU_WIDTH, height: env.menuMaxHeight, alignment: .top)
        .padding(.horizontal, showOptionsMenu ? MENU_HORIZONTAL_PADDING * 2 : 0)
        .contrast(wm.focused ? 1.0 : 0.8)
        .brightness(wm.focused ? 0.0 : -0.1)
        .saturation(wm.focused ? 1.0 : 0.7)
        .allowsHitTesting(wm.focused)
    }

    @ViewBuilder var optionsMenu: some View {
        VStack(spacing: 10) {
            HStack {
                SwiftUI.Button("Layout") {
                    withAnimation(.fastSpring) { env.optionsTab = .layout }
                }
                .buttonStyle(PickerButton(
                    color: Colors.blackMauve.opacity(0.1),
                    onColor: Colors.blackMauve.opacity(0.4),
                    onTextColor: .white,
                    offTextColor: Colors.darkGray,
                    enumValue: $env.optionsTab,
                    onValue: .layout
                ))
                .font(.system(size: 12, weight: env.optionsTab == .layout ? .bold : .medium, design: .rounded))

                SwiftUI.Button("Advanced") {
                    withAnimation(.fastSpring) { env.optionsTab = .advanced }
                }
                .buttonStyle(PickerButton(
                    color: Colors.blackMauve.opacity(0.1),
                    onColor: Colors.blackMauve.opacity(0.4),
                    onTextColor: .white,
                    offTextColor: Colors.darkGray,
                    enumValue: $env.optionsTab,
                    onValue: .advanced
                ))
                .font(.system(size: 12, weight: env.optionsTab == .advanced ? .bold : .medium, design: .rounded))

                SwiftUI.Button("HDR") {
                    withAnimation(.fastSpring) { env.optionsTab = .hdr }
                }
                .buttonStyle(PickerButton(
                    color: Colors.blackMauve.opacity(0.1),
                    onColor: Colors.blackMauve.opacity(0.4),
                    onTextColor: .white,
                    offTextColor: Colors.darkGray,
                    enumValue: $env.optionsTab,
                    onValue: .hdr
                ))
                .font(.system(size: 12, weight: env.optionsTab == .hdr ? .bold : .medium, design: .rounded))
            }.frame(maxWidth: .infinity)

            switch env.optionsTab {
            case .layout:
                QuickActionsLayoutView().padding(10).foregroundColor(Colors.blackMauve)
            case .advanced:
                AdvancedSettingsView().padding(10).foregroundColor(Colors.blackMauve)
            case .hdr:
                HDRSettingsView().padding(10).foregroundColor(Colors.blackMauve)
            }

            SwiftUI.Button("Reset \(km.optionKeyPressed ? "ALL" : (km.commandKeyPressed ? "display-specific" : "global")) settings") {
                if km.optionKeyPressed {
                    resetAllSettings()
                } else if km.commandKeyPressed {
                    appDelegate!.resetStates()
                    Defaults.reset(.displays)
                    dc.displays = [:]
                } else {
                    DataStore.reset()
                }

                mainAsyncAfter(ms: 300) {
                    restart()
                }
            }
            .buttonStyle(FlatButton(color: Color.red.opacity(0.7), textColor: .white))
            .font(.system(size: 12, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .frame(width: OPTIONS_MENU_WIDTH, alignment: .center)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Colors.sunYellow : Colors.lunarYellow)
                .shadow(color: Colors.blackMauve.opacity(colorScheme == .dark ? 0.5 : 0.2), radius: 8, x: 0, y: 6)
        )
        .padding(.bottom, 20)
        .foregroundColor(Colors.blackMauve)
    }

    func bg(optionsMenuOverflow _: Bool) -> some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .followsWindowActiveState)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Colors.blackMauve.opacity(0.4) : Color.white.opacity(0.6))
        }
        .shadow(color: Colors.blackMauve.opacity(colorScheme == .dark ? 0.5 : 0.2), radius: 8, x: 0, y: 6)
    }

    func isOptionsMenuOverflowing() -> Bool {
        guard let screen = NSScreen.main else { return false }
        return menuBarIcon.storedPosition.x + MENU_WIDTH + MENU_WIDTH / 2 + FULL_OPTIONS_MENU_WIDTH >= screen.visibleFrame.maxX
    }

    func setMenuWidth(_: Any) {
        #if arch(arm64)
            withAnimation(.fastSpring) {
                env.menuWidth = (
                    showOptionsMenu || showStandardPresets || showCustomPresets
                        || !showHeaderOnHover || !showFooterOnHover
                        || showAdditionalInfo
                        || headerOpacity > 0 || footerOpacity > 0
                ) ? MENU_WIDTH : MENU_CLEAN_WIDTH
            }
        #else
            env.menuWidth = (
                showOptionsMenu || showStandardPresets || showCustomPresets
                    || !showHeaderOnHover || !showFooterOnHover
                    || showAdditionalInfo
                    || headerOpacity > 0 || footerOpacity > 0
            ) ? MENU_WIDTH : MENU_CLEAN_WIDTH
        #endif
        if let menuWindow, let size = menuWindow.contentView?.frame.size, size != menuWindow.frame.size {
            menuWindow.setContentSize(size)
        }
    }

    func handleHeaderTransition(hovering: Bool) {
        guard !menuBarClosed else { return }
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
        guard !(closed ?? menuBarClosed) else {
            displayHideTask = mainAsyncAfter(ms: 2000) {
                cursorDisplay = nil
                displays = []
                displayCount = 0
                sourceDisplay = nil
                #if arch(arm64)
                    disconnectedDisplays = []
                    possiblyDisconnectedDisplays = []
                #endif
                unmanagedDisplays = []
            }
            return
        }

        displayHideTask = nil
        cursorDisplay = dc.cursorDisplay
        displays = dc.nonCursorDisplays
        displayCount = dc.activeDisplayCount
        sourceDisplay = dc.sourceDisplay
        #if arch(arm64)
            disconnectedDisplays = dc.possiblyDisconnectedDisplayList

            let ids = disconnectedDisplays.map(\.id)
            displays = displays.filter { !ids.contains($0.id) }
            if let id = cursorDisplay?.id, ids.contains(id) {
                cursorDisplay = nil
            }

            let disconnectedSerials = disconnectedDisplays.map(\.serial)
            possiblyDisconnectedDisplays = dc.displays.map(\.1).filter { d in
                d.keepDisconnected && !(Sysctl.isMacBook && d.id == 1) &&
                    dc.activeDisplaysBySerial[d.serial] == nil &&
                    !disconnectedSerials.contains(d.serial)
            }
        #endif
        unmanagedDisplays = dc.unmanagedDisplays

        if showHeaderOnHover { headerOpacity = 0.0 }
        if showFooterOnHover { footerOpacity = 0.0 }
        env.menuMaxHeight = (NSScreen.main?.visibleFrame.height ?? 600) - 50
    }
}

struct UsefulInfo: View {
    @Default(.infoMenuShown) var infoMenuShown
    @Default(.adaptiveBrightnessMode) var adaptiveBrightnessMode
    @ObservedObject var ami = AMI

    var usefulInfoText: (String, String)? {
        guard infoMenuShown else { return nil }

        switch adaptiveBrightnessMode {
        case .sync:
            #if arch(arm64)
                guard SyncMode.syncNits, let nits = ami.nits else {
                    return nil
                }
                return (nits.intround.s, "nits")
            #else
                return nil
            #endif
        case .sensor:
            guard let lux = ami.lux else {
                return nil
            }
            return (lux > 10 ? lux.intround.s : lux.str(decimals: 1), "lux")
        case .location:
            guard let elevation = ami.sunElevation else {
                return nil
            }
            return ("\((elevation >= 10 || elevation <= -10) ? elevation.intround.s : elevation.str(decimals: 1))°", "sun")
        default:
            return nil
        }
    }

    var body: some View {
        if let (t1, t2) = usefulInfoText {
            VStack(spacing: -2) {
                Text(t1)
                    .font(.system(size: 10, weight: .bold, design: .monospaced).leading(.tight))
                Text(t2)
                    .font(.system(size: 9, weight: .semibold, design: .rounded).leading(.tight))
            }
            .foregroundColor(.secondary)
        }
    }
}

var windowShowTask: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}

var additionInfoTask: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}

var displayHideTask: DispatchWorkItem? {
    didSet {
        oldValue?.cancel()
    }
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

    var body: some View {
        QuickActionsMenuView(menuBarIcon: appDelegate!.statusItemButtonController!)
            .environmentObject(appDelegate!.env)
            .colors(colorScheme == .dark ? .dark : .light)
            .focusable(false)
    }
}

let MENU_WIDTH: CGFloat = 380
let OPTIONS_MENU_WIDTH: CGFloat = 390
let FULL_OPTIONS_MENU_WIDTH: CGFloat = 412
let MENU_CLEAN_WIDTH: CGFloat = 300
let MENU_HORIZONTAL_PADDING: CGFloat = 24
let MENU_VERTICAL_PADDING: CGFloat = 40
let FULL_MENU_WIDTH: CGFloat = MENU_WIDTH + (MENU_HORIZONTAL_PADDING * 2)

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
