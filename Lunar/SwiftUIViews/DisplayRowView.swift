import Defaults
import SwiftUI

struct DisplayContextMenu: View {
    @ObservedObject var display: Display

    // @ViewBuilder var resolutionMenu: some View {
    //     if let panel = display.panel, panel.modes.count > 1 {
    //         let modes = panel.groupedModes
    //         let refreshRates: [RefreshRate] = Array(modes.keys.map { $0 }.sorted().reversed())

    //         Menu("Resolution") {
    //             ForEach(refreshRates) { refreshRate in
    //                 Menu(refreshRate.description) {
    //                     let keys = modes[refreshRate]!.keys
    //                     let tags = [MPDisplayMode.Tag.hidpi, .lodpi, .unsafe].filter { keys.contains($0) }
    //                     ForEach(tags) { tag in
    //                         resolutionPicker(modes: modes[refreshRate]![tag]!, tag: tag)
    //                     }
    //                 }
    //             }
    //         }.onAppear {
    //             if display.observableResolution == nil {
    //                 display.withoutApply {
    //                     display.observableResolution = panel.currentMode
    //                 }
    //             }
    //         }
    //     }
    // }

    #if arch(arm64)
        var nightShiftOverrideBinding: Binding<Bool> {
            Binding(
                get: { isOverridden(displayID: display.id) },
                set: { overriden in
                    let result = if overriden {
                        disableTVMode(displayID: display.id)
                    } else {
                        resetOverride(displayID: display.id)
                    }

                    switch result {
                    case .needsRestart:
                        notify(identifier: "restart", title: "Restart needed", body: "The override will take effect after a system restart.")
                    case .success:
                        break
                    case .error:
                        notify(identifier: "error", title: "Override error", body: "An error occurred while trying to override Night Shift and True Tone.")
                    }
                }
            )
        }
    #endif

    // var hdrBinding: Binding<Bool> {
    //     Binding(
    //         get: { display.presetSupportsHDR },
    //         set: { enable in
    //             if enable {
    //                 display.enablePresetHDR()
    //             } else {
    //                 display.disablePresetHDR()
    //             }
    //         }
    //     )
    // }

    var facelightBinding: Binding<Bool> {
        Binding(
            get: { display.facelight },
            set: { display.facelight = $0 }
        )
    }

    var systemAdaptiveBrightnessBinding: Binding<Bool> {
        Binding(
            get: { display.systemAdaptiveBrightness },
            set: { display.systemAdaptiveBrightness = $0 }
        )
    }

    var body: some View {
        Toggle("FaceLight", isOn: facelightBinding)
        if display.hasAmbientLightAdaptiveBrightness {
            Toggle("System Adaptive Brightness", isOn: systemAdaptiveBrightnessBinding)
        }
        // if display.supportsHDRDisabling {
        //     Toggle("HDR", isOn: hdrBinding)
        // }

        Divider()

        Toggle("Ignore this display", isOn: $display.unmanaged)
        #if arch(arm64)
            if !display.isBuiltin, (display.panel?.isTV ?? false) || isOverridden(displayID: display.id) {
                Toggle("Force enable Night Shift and True Tone", isOn: nightShiftOverrideBinding)
            }
        #endif
//        resolutionMenu
    }

    // @ViewBuilder func resolutionPicker(modes: [MPDisplayMode], tag: MPDisplayMode.Tag) -> some View {
    //     Picker(tag.rawValue, selection: $display.observableResolution) {
    //         ForEach(modes, id: \.modeNumber) { mode in
    //             Text(mode.swiftUIString).tag(mode as MPDisplayMode?)
    //         }
    //     }
    // }
}

struct DisplayRowView: View {
    static var hoveringVolumeSliderTask: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }

    @ObservedObject var display: Display
    @ObservedObject var km = KM
    @Environment(\.colorScheme) var colorScheme

    @Default(.showSliderValues) var showSliderValues
    #if arch(arm64)
        @Default(.syncNits) var syncNits
    #endif

    @Default(.askedAboutXDR) var askedAboutXDR
    @Default(.newXDRMode) var newXDRMode
    @Default(.showInputInQuickActions) var showInputInQuickActions
    @Default(.showPowerInQuickActions) var showPowerInQuickActions
    @Default(.showXDRSelector) var showXDRSelector
    @Default(.showRawValues) var showRawValues
    @Default(.showNitsText) var showNitsText
    @Default(.xdrTipShown) var xdrTipShown
    @Default(.fullRangeTipShown) var fullRangeTipShown
    @Default(.autoXdr) var autoXdr
    @Default(.syncMode) var syncMode
    @Default(.dimNonEssentialUI) var dimNonEssentialUI
    @Default(.autoBlackoutBuiltin) var autoBlackoutBuiltin

    @State private var showNeedsLunarPro = false
    @State private var showNeedsLunarProForFullRange = false
    @State private var showFullRangeTip = false
    @State private var showXDRTip = false
    @State private var showSubzero = false
    @State private var showXDR = false

    @State private var adaptiveStateText = ""
    @State private var adaptivePausedText = "Adaptive brightness paused"
    @State private var editingMaxNits = false
    @State private var editingMinNits = false
    @State private var hovering = false

    @State private var hoveringVolumeSlider = false
    @State private var hoveringVideoInput = false
    @State private var hoveringXDRSelector = false

    @EnvironmentObject var env: EnvState

    var softwareSliders: some View {
        Group {
            if display.enhanced {
                BigSurSlider(
                    percentage: $display.xdrBrightness,
                    image: "sun.max.circle.fill",
                    color: Color.xdr.opacity(0.7),
                    backgroundColor: Color.xdr.opacity(colorScheme == .dark ? 0.1 : 0.2),
                    knobColor: Color.xdr,
                    showValue: $showSliderValues,
                    beforeSettingPercentage: { _ in display.forceHideSoftwareOSD = true }
                )
            }
            if display.subzero {
                BigSurSlider(
                    percentage: $display.softwareBrightness,
                    image: "moon.circle.fill",
                    color: Color.subzero.opacity(0.7),
                    backgroundColor: Color.subzero.opacity(colorScheme == .dark ? 0.1 : 0.2),
                    knobColor: Color.subzero,
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

    @ViewBuilder var newSdrXdrSelector: some View {
        let color = Color.bg.warm.opacity(colorScheme == .dark ? 0.8 : 0.4)
        HStack(spacing: 2) {
            SwiftUI.Button("SDR") {
                guard display.enhanced || display.fullRange else { return }
                withAnimation(.fastSpring) {
                    if display.enhanced {
                        display.enhanced = false
                    }
                    if display.fullRange {
                        display.fullRange = false
                    }
                }
            }
            .buttonStyle(PickerButton(
                onColor: Color.warmBlack.opacity(hoveringXDRSelector || !dimNonEssentialUI ? 1.0 : 0.2), offColor: color.opacity(0.4), enumValue: .oneway { display.enhanced || display.fullRange }, onValue: false
            ))
            .font(.system(size: 10, weight: display.enhanced ? .semibold : .bold, design: .monospaced))

            if display.supportsFullRangeXDR {
                SwiftUI.Button("XDR") {
                    guard proactive else {
                        showNeedsLunarProForFullRange = true
                        return
                    }
                    guard fullRangeTipShown || askedAboutXDR else {
                        fullRangeTipShown = true
                        showFullRangeTip = true
                        return
                    }

                    guard !km.controlKeyPressed else {
                        showFullRangeTip = true
                        return
                    }

                    if display.enhanced {
                        display.enhanced = false
                    }

                    withAnimation(.easeInOut(duration: 0.3)) { display.fullRange.toggle() }
                }
                .buttonStyle(PickerButton(
                    onColor: Color.fg.primary.opacity(hoveringXDRSelector || !dimNonEssentialUI ? 0.7 : 0.2),
                    offColor: color.opacity(0.4), onTextColor: .bg.primary, radius: 6, enumValue: $display.fullRange, onValue: true
                ))
                .font(.system(size: 10, weight: display.fullRange ? .bold : .semibold, design: .rounded))
                .popover(isPresented: $showNeedsLunarProForFullRange) { NeedsLunarProView() }
                .popover(isPresented: $showFullRangeTip) { FullRangeTipView() }
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .trim(from: 0.0, to: display.fullRange ? 1.0 : 0.0)
                .stroke(Color.fg.primary.opacity(0.7), lineWidth: 3)
                .scaleEffect(x: 0.98, y: 0.95, anchor: .center)
        )
        .padding(.bottom, 2)
        .opacity(hoveringXDRSelector || !dimNonEssentialUI ? 1 : 0.15)
        .onHover { hovering in
            withAnimation(.fastTransition) {
                hoveringXDRSelector = hovering
            }
        }
    }

    @ViewBuilder var sdrXdrSelector: some View {
        let color = Color.bg.warm.opacity(colorScheme == .dark ? 0.8 : 0.4)
        HStack(spacing: 2) {
            SwiftUI.Button("SDR") {
                guard display.enhanced || display.fullRange else { return }
                withAnimation(.fastSpring) {
                    if display.enhanced {
                        display.enhanced = false
                    }
                    if display.fullRange {
                        display.fullRange = false
                    }
                }
            }
            .buttonStyle(PickerButton(
                onColor: Color.warmBlack.opacity(hoveringXDRSelector || !dimNonEssentialUI ? 1.0 : 0.2), offColor: color.opacity(0.4), enumValue: .oneway { display.enhanced || display.fullRange }, onValue: false
            ))
            .font(.system(size: 10, weight: display.enhanced ? .semibold : .bold, design: .monospaced))

            if display.supportsFullRangeXDR {
                SwiftUI.Button("Full Range") {
                    guard proactive else {
                        showNeedsLunarProForFullRange = true
                        return
                    }
                    guard fullRangeTipShown else {
                        fullRangeTipShown = true
                        showFullRangeTip = true
                        return
                    }

                    guard !km.controlKeyPressed else {
                        showFullRangeTip = true
                        return
                    }

                    if display.enhanced {
                        display.enhanced = false
                    }

                    withAnimation(.easeInOut(duration: 0.3)) { display.fullRange.toggle() }
                }
                .buttonStyle(PickerButton(
                    onColor: Color.fg.primary.opacity(hoveringXDRSelector || !dimNonEssentialUI ? 0.7 : 0.2),
                    offColor: color.opacity(0.4), onTextColor: .bg.primary, radius: 6, enumValue: $display.fullRange, onValue: true
                ))
                .font(.system(size: 10, weight: display.fullRange ? .bold : .semibold, design: .rounded))
                .popover(isPresented: $showNeedsLunarProForFullRange) { NeedsLunarProView() }
                .popover(isPresented: $showFullRangeTip) { FullRangeTipView() }
            }

            if display.supportsEnhance {
                SwiftUI.Button("XDR") {
                    guard proactive else {
                        showNeedsLunarPro = true
                        return
                    }
                    if display.fullRange {
                        display.fullRange = false
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
                    onColor: Color.warmBlack.opacity(hoveringXDRSelector || !dimNonEssentialUI ? 1.0 : 0.2),
                    offColor: color.opacity(0.4), enumValue: $display.enhanced, onValue: true
                ))
                .font(.system(size: 10, weight: display.enhanced ? .bold : .semibold, design: .monospaced))
                .popover(isPresented: $showNeedsLunarPro) { NeedsLunarProView() }
                .popover(isPresented: $showXDRTip) { XDRTipView() }
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .trim(from: 0.0, to: display.fullRange ? 1.0 : 0.0)
                .stroke(Color.fg.primary.opacity(0.7), lineWidth: 3)
                .scaleEffect(x: 0.98, y: 0.95, anchor: .center)
        )
        .padding(.bottom, 2)
        .opacity(hoveringXDRSelector || !dimNonEssentialUI ? 1 : 0.15)
        .onHover { hovering in
            withAnimation(.fastTransition) {
                hoveringXDRSelector = hovering
            }
        }
    }

    var inputSelector: some View {
        Dropdown(
            selection: $display.inputSource,
            width: 150,
            height: 20,
            noValueText: "Video Input",
            noValueImage: "input",
            content: display.vendor == .lg ? .constant(VideoInputSource.mostUsed + [VideoInputSource.separator] + VideoInputSource.lgSpecific) : .constant(VideoInputSource.mostUsed)
        )
        .frame(width: 150, height: 20, alignment: .center)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            ).fill(Color.translucid)
        )
        .colorMultiply(Color.peach.blended(withFraction: 0.7, of: .white))
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
            if display.isInNonWirelessHardwareMirrorSet {
                return "Overlay dimming disabled while mirroring"
            } else if display.isIndependentDummy {
                return "Overlay dimming disabled for dummy"
            }
        }

        return nil
    }

    @ViewBuilder var appPresetAdaptivePaused: some View {
        VStack(spacing: 2) {
            let showInput = display.hasDDC && showInputInQuickActions
            let showAdditionalUI = display.showOrientation || display.appPreset != nil || display.adaptivePaused
                || showRawValues && (display.lastRawBrightness != nil || display.lastRawContrast != nil || display.lastRawVolume != nil)
                || SWIFTUI_PREVIEW

            if showInput, !showAdditionalUI {
                inputSelector
            }
            if showAdditionalUI {
                VStack {
                    if showInput { inputSelector }
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
                    ).fill(Color.primary.opacity(hoveringVideoInput || !dimNonEssentialUI ? 0.05 : 0.0))
                )
                .padding(.vertical, 2)
            }
        }
        .opacity(hoveringVideoInput || !dimNonEssentialUI ? 0.9 : 0.15)
        .onHover { hovering in
            withAnimation(.fastTransition) {
                hoveringVideoInput = hovering
            }
        }
    }

    @ViewBuilder var volumeSlider: some View {
        if display.hasDDC, display.showVolumeSlider, display.ddcEnabled || display.networkEnabled {
            ZStack {
                BigSurSlider(
                    percentage: $display.preciseVolume.f,
                    imageBinding: .oneway { display.audioMuted ? "speaker.slash.fill" : "speaker.2.fill" },
                    colorBinding: .constant(Color.peach),
                    backgroundColorBinding: .constant(Color.peach.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues,
                    disabled: $display.audioMuted,
                    enableText: "Unmute"
                )
                if hoveringVolumeSlider, !display.audioMuted {
                    SwiftUI.Button("Mute") {
                        display.audioMuted = true
                    }
                    .buttonStyle(FlatButton(
                        color: Color.red.opacity(0.7),
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
            HStack(spacing: 2) {
                #if arch(arm64)
                    if showNitsText {
                        NitsTextField(placeholder: "min", display: display)
                            .opacity(hovering ? 1 : 0)
                    }
                #endif
                BigSurSlider(
                    percentage: $display.preciseBrightnessContrast.f,
                    image: "sun.max.fill",
                    colorBinding: .constant(Color.peach),
                    backgroundColorBinding: .constant(Color.peach.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues,
                    disabled: mergedLockBinding,
                    enableText: "Unlock",
                    insideText: nitsText
                )
                #if arch(arm64)
                    if showNitsText {
                        NitsTextField(placeholder: "max", display: display)
                            .opacity(hovering ? 1 : 0)
                    }
                #endif
            }
            softwareSliders
        } else {
            BigSurSlider(
                percentage: $display.preciseBrightness.f,
                image: "sun.max.fill",
                colorBinding: .constant(Color.peach),
                backgroundColorBinding: .constant(Color.peach.opacity(colorScheme == .dark ? 0.1 : 0.4)),
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
                colorBinding: .constant(Color.peach),
                backgroundColorBinding: .constant(Color.peach.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                showValue: $showSliderValues
            )
        }
    }

    @ViewBuilder var name: some View {
        if showPowerInQuickActions, display.getPowerOffEnabled() {
            HStack(alignment: .top, spacing: -10) {
                Text(display.name)
                    .font(.system(size: 22, weight: .black))
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.bg.warm.opacity(colorScheme == .dark ? 0.5 : 0.2)))
                    .contextMenu { DisplayContextMenu(display: display) }

                PowerOffButtonView(display: display)
                    .offset(y: -8)
            }.offset(x: 45)

        } else {
            Text(display.name ?! "Unknown")
                .font(.system(size: 22, weight: .black))
                .contextMenu { DisplayContextMenu(display: display) }
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            let xdrSelectorShown = (display.supportsEnhance || display.supportsFullRangeXDR) && showXDRSelector && !display.blackOutEnabled

            name

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
                if display.presetSupportsBrightnessControl {
                    sliders
                    adaptiveState
                    volumeSlider
                    if xdrSelectorShown {
                        if newXDRMode, display.isBuiltin, display.supportsFullRangeXDR {
                            newSdrXdrSelector
                        } else {
                            sdrXdrSelector
                        }
                    }
                    appPresetAdaptivePaused
                } else {
                    lockedPresetView
                }
            }
        }.onHover { h in withAnimation { hovering = h } }
    }

    @ViewBuilder var lockedPresetView: some View {
        Text("Brightness locked by preset").font(.system(size: 10, weight: .semibold, design: .rounded))
        if let name = display.referencePreset?.presetName {
            Menu(name) {
                SwiftUI.Button("Unlock \"\(name)\"") {
                    display.panel?.unlockActivePreset()
                }
                Divider()

                let presets = display.panelPresets.filter(\.isValid)
                let groups = Set(presets.map(\.presetGroup)).sorted()
                ForEach(groups, id: \.self) { group in
                    Section(header: Text("\(MPDisplayPreset.groupName(group)) Presets")) {
                        ForEach(presets.filter { $0.presetGroup == group }, id: \.presetIndex) { preset in
                            SwiftUI.Button(preset.presetName) {
                                display.panel?.activatePreset(preset)
                            }
                        }
                    }
                }
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .menuStyle(.borderlessButton)
            .modifier(RoundBG(radius: 5, color: .invertedSemiOpaque, shadowSize: 0))
            .fixedSize(horizontal: true, vertical: false)
        }
    }
    @ViewBuilder var adaptiveState: some View {
        let systemAdaptive = display.systemAdaptiveBrightness
        let key = DC.adaptiveModeKey
        if !display.adaptive, !display.xdr, !display.blackout, !display.facelight, !display.subzero, (key == .sync && !display.isActiveSyncSource) || key == .location || key == .sensor || key == .clock {
            SwiftUI.Button(adaptiveStateText.isEmpty ? (systemAdaptive ? "Adapted by the system" : "Adaptive brightness disabled") : adaptiveStateText) {
                display.adaptive = true
            }
            .buttonStyle(FlatButton(color: .translucid, textColor: .fg.warm.opacity(0.4)))
            .font(.system(size: 9, weight: .semibold, design: .rounded))
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
            .foregroundColor((display.preciseBrightnessContrast < 0.25 && colorScheme == .dark) ? Color.lightGray.opacity(0.6) : Color.grayMauve.opacity(0.7))
            .any
        #else
            EmptyView().any
        #endif
    }

    func rotationPicker(_ degrees: Int) -> some View {
        SwiftUI.Button("\(degrees)°") {
            display.rotation = degrees
        }
        .buttonStyle(PickerButton(onColor: Color.fg.warm.opacity(colorScheme == .dark ? 0.15 : 0.9).opacity(hoveringVideoInput || !dimNonEssentialUI ? 1.0 : 0.2), enumValue: $display.rotation, onValue: degrees))
        .font(.system(size: 12, weight: display.rotation == degrees ? .bold : .semibold, design: .monospaced))
        .help("No rotation")
    }
}
