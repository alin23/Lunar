import Defaults
import SwiftUI

struct QuickActionsMenuView: View {
    @Environment(\.colorScheme) var colorScheme

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
    @Default(.dimNonEssentialUI) var dimNonEssentialUI

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

    @State var hoveringFooter = false
    @State var hoveringPresets = false
    @State var hoveringHeader = false

    @State var hoveringAppInfoToggle = false

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
            ).fill(Color.translucid)
        )
        .colorMultiply(Color.peach.blended(withFraction: 0.7, of: .white))
        .foregroundColor(Color.fg.warm)
    }

    var topRightButtons: some View {
        Group {
            SwiftUI.Button(
                action: { showOptionsMenu.toggle() },
                label: {
                    HStack(spacing: 2) {
                        Image(systemName: "gear.circle.fill").font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text("Settings").font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                }
            )
            .buttonStyle(FlatButton(color: .translucid, textColor: .fg.warm.opacity(0.8)))
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
//            VStack(alignment: .center, spacing: -2) {
//                Text("Standard").font(.system(size: 10, weight: .bold))
//                Text("Presets").font(.system(size: 12, weight: .heavy))
//            }.foregroundColor(Color.fg.warm.opacity(0.65))
//            Spacer()
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
                            .foregroundColor(Color.fg.warm.opacity(hoveringAppInfoToggle ? 0.8 : 0.3))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .fixedSize()
                            .onHover { hovering in
                                withAnimation(.fastTransition) {
                                    hoveringAppInfoToggle = hovering
                                }
                            }

                        Spacer()

                        if let version = um.newVersion {
                            SwiftUI.Button("\(Image(systemName: "sparkles")) v\(version)") { appDelegate!.updater.checkForUpdates() }
                                .buttonStyle(FlatButton(
                                    color: Color.peach,
                                    textColor: Color.blackMauve,
                                    horizontalPadding: 6,
                                    verticalPadding: 3
                                ))
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(.leastNonzeroMagnitude)
                                .scaledToFit()
                        }

                        SwiftUI.Button("Display Settings") { appDelegate!.showPreferencesWindow(sender: nil) }
                            .buttonStyle(FlatButton(color: .translucid, textColor: .fg.warm.opacity(0.8)))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .fixedSize()

                        SwiftUI.Button("Restart") { appDelegate!.restartApp(appDelegate!) }
                            .buttonStyle(FlatButton(color: .translucid, textColor: .fg.warm.opacity(0.8)))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .fixedSize()

                        SwiftUI.Button("Quit") { NSApplication.shared.terminate(nil) }
                            .buttonStyle(FlatButton(color: .translucid, textColor: .fg.warm.opacity(0.8)))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .fixedSize()
                    }
                    .padding(.bottom, showAdditionalInfo ? 0 : 7)
                }
                .padding(.horizontal, MENU_HORIZONTAL_PADDING / 2)
                .opacity(showFooterOnHover ? footerOpacity : (hoveringFooter || !dimNonEssentialUI ? 1.0 : 0.15))
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
                withAnimation(.fastTransition) {
                    hoveringFooter = hovering
                }
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
                            .foregroundColor(.fg.warm)
                            .font(.system(size: 11, weight: .medium))
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
                .padding(.horizontal, 15)
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
        .background(Color.fg.warm.opacity((colorScheme == .dark ? 0.03 : 0.05) * op))
        .padding(.bottom, 10 * op)
        .onChange(of: showOptionsMenu, perform: handleHeaderTransition(hovering:))
        .opacity(hoveringHeader || !dimNonEssentialUI ? 1.0 : 0.15)
        .onHover { hovering in
            withAnimation(.fastTransition) {
                hoveringHeader = hovering
            }
            handleHeaderTransition(hovering: hovering)
        }
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
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.fg.warm.opacity(0.03)))
                .padding(.horizontal, MENU_HORIZONTAL_PADDING)
                .opacity(hoveringPresets || !dimNonEssentialUI ? 1.0 : 0.15)
                .onHover { hovering in
                    withAnimation(.fastTransition) {
                        hoveringPresets = hovering
                    }
                }
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
            VStack(spacing: 5) {
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
//        .contrast(wm.focused ? 1.0 : 0.8)
//        .brightness(wm.focused ? 0.0 : -0.1)
//        .saturation(wm.focused ? 1.0 : 0.7)
//        .allowsHitTesting(wm.focused)
    }

    @ViewBuilder var optionsMenu: some View {
        VStack(spacing: 10) {
            HStack {
                SwiftUI.Button("Layout") {
                    withAnimation(.fastSpring) { env.optionsTab = .layout }
                }
                .buttonStyle(PickerButton(
                    color: Color.blackMauve.opacity(0.1),
                    onColor: Color.blackMauve.opacity(0.4),
                    onTextColor: .white,
                    offTextColor: Color.darkGray,
                    enumValue: $env.optionsTab,
                    onValue: .layout
                ))
                .font(.system(size: 12, weight: env.optionsTab == .layout ? .bold : .medium, design: .rounded))

                SwiftUI.Button("Advanced") {
                    withAnimation(.fastSpring) { env.optionsTab = .advanced }
                }
                .buttonStyle(PickerButton(
                    color: Color.blackMauve.opacity(0.1),
                    onColor: Color.blackMauve.opacity(0.4),
                    onTextColor: .white,
                    offTextColor: Color.darkGray,
                    enumValue: $env.optionsTab,
                    onValue: .advanced
                ))
                .font(.system(size: 12, weight: env.optionsTab == .advanced ? .bold : .medium, design: .rounded))

                SwiftUI.Button("HDR") {
                    withAnimation(.fastSpring) { env.optionsTab = .hdr }
                }
                .buttonStyle(PickerButton(
                    color: Color.blackMauve.opacity(0.1),
                    onColor: Color.blackMauve.opacity(0.4),
                    onTextColor: .white,
                    offTextColor: Color.darkGray,
                    enumValue: $env.optionsTab,
                    onValue: .hdr
                ))
                .font(.system(size: 12, weight: env.optionsTab == .hdr ? .bold : .medium, design: .rounded))
            }.frame(maxWidth: .infinity)

            switch env.optionsTab {
            case .layout:
                QuickActionsLayoutView().padding(10).foregroundColor(Color.blackMauve)
            case .advanced:
                AdvancedSettingsView().padding(10).foregroundColor(Color.blackMauve)
            case .hdr:
                HDRSettingsView().padding(10).foregroundColor(Color.blackMauve)
            }

            SwiftUI.Button("Reset \(km.optionKeyPressed ? "global" : (km.commandKeyPressed ? "display-specific" : "ALL")) settings") {
                if km.optionKeyPressed {
                    DataStore.reset()
                } else if km.commandKeyPressed {
                    appDelegate!.resetStates()
                    Defaults.reset(.displays)
                    dc.displays = [:]
                } else {
                    resetAllSettings()
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
                .fill(colorScheme == .dark ? Color.peach : Color.sunYellow)
                .shadow(color: Color.blackMauve.opacity(colorScheme == .dark ? 0.5 : 0.2), radius: 8, x: 0, y: 6)
        )
        .padding(.bottom, 20)
        .foregroundColor(Color.blackMauve)
    }

    func bg(optionsMenuOverflow _: Bool) -> some View {
        ZStack {
            VisualEffectBlur(
                material: .hudWindow,
                blendingMode: .behindWindow,
                state: .active
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color.blackMauve.opacity(0.4) : Color.white.opacity(0.6))
        }
        .shadow(color: Color.blackMauve.opacity(colorScheme == .dark ? 0.5 : 0.2), radius: 8, x: 0, y: 6)
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
