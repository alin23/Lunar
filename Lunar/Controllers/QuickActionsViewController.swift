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

// MARK: - FlatButton

public struct FlatButton: ButtonStyle {
    // MARK: Lifecycle

    public init(
        color: Color? = nil,
        textColor: Color? = nil,
        hoverColor: Color? = nil,
        colorBinding: Binding<Color>? = nil,
        textColorBinding: Binding<Color>? = nil,
        hoverColorBinding: Binding<Color>? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        circle: Bool = false,
        radius: CGFloat = 8,
        pressedBinding: Binding<Bool>? = nil
    ) {
        _color = colorBinding ?? .constant(color ?? Colors.lightGold)
        _textColor = textColorBinding ?? .constant(textColor ?? Colors.blackGray)
        _hoverColor = hoverColorBinding ?? .constant(hoverColor ?? Colors.lightGold)
        _width = .constant(width)
        _height = .constant(height)
        _circle = .constant(circle)
        _radius = .constant(radius)
        _pressed = pressedBinding ?? .constant(false)
    }

    // MARK: Public

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(textColor)
            .padding(.vertical, 4.0)
            .padding(.horizontal, 8.0)
            .frame(minWidth: width, idealWidth: width, minHeight: height, idealHeight: height, alignment: .center)
            .background(
                circle
                    ?
                    AnyView(
                        Circle().fill(color)
                            .frame(minWidth: width, idealWidth: width, minHeight: height, idealHeight: height, alignment: .center)
                    )
                    : AnyView(
                        RoundedRectangle(
                            cornerRadius: radius,
                            style: .continuous
                        ).fill(color).frame(minWidth: width, idealWidth: width, minHeight: height, idealHeight: height, alignment: .center)
                    )

            ).colorMultiply(configuration.isPressed ? pressedColor : colorMultiply)
            .scaleEffect(configuration.isPressed ? 1.02 : scale)
            .onAppear {
                pressedColor = hoverColor.blended(withFraction: 0.5, of: .white)
            }
            .onChange(of: pressed) { newPressed in
                if newPressed {
                    withAnimation(.interactiveSpring()) {
                        colorMultiply = hoverColor
                        scale = 1.05
                    }
                } else {
                    withAnimation(.interactiveSpring()) {
                        colorMultiply = .white
                        scale = 1.0
                    }
                }
            }
            .onHover(perform: { hover in
                withAnimation(.easeOut(duration: 0.2)) {
                    colorMultiply = hover ? hoverColor : .white
                    scale = hover ? 1.05 : 1
                }
            })
    }

    // MARK: Internal

    @Environment(\.colors) var colors

    @Binding var color: Color
    @Binding var textColor: Color
    @State var colorMultiply: Color = .white
    @State var scale: CGFloat = 1.0
    @Binding var hoverColor: Color
    @State var pressedColor: Color = .white
    @Binding var width: CGFloat?
    @Binding var height: CGFloat?
    @Binding var circle: Bool
    @Binding var radius: CGFloat
    @Binding var pressed: Bool
}

// MARK: - PickerButton

public struct PickerButton<T: Equatable>: ButtonStyle {
    // MARK: Public

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(enumValue == onValue ? (onTextColor ?? colors.accent) : offTextColor)
            .padding(.vertical, horizontalPadding)
            .padding(.horizontal, verticalPadding)
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                ).fill(enumValue == onValue ? color : (offColor ?? color.opacity(0.5)))

            ).scaleEffect(scale).colorMultiply(hoverColor)
            .contentShape(Rectangle())
            .onHover(perform: { hover in
                guard enumValue != onValue else {
                    hoverColor = .white
                    scale = 1.0
                    return
                }
                withAnimation(.easeOut(duration: 0.1)) {
                    hoverColor = hover ? colors.accent : .white
                    scale = hover ? 1.05 : 1.0
                }
            })
    }

    // MARK: Internal

    @Environment(\.colors) var colors

    @State var color = Color.primary.opacity(0.1)
    @State var offColor: Color? = nil
    @State var onTextColor: Color? = nil
    @State var offTextColor = Color.secondary
    @State var horizontalPadding: CGFloat = 4
    @State var verticalPadding: CGFloat = 8
    @State var brightness = 0.0
    @State var scale: CGFloat = 1
    @State var hoverColor = Color.white
    @Binding var enumValue: T
    @State var onValue: T
}

public extension Color {
    func blended(withFraction fraction: CGFloat, of color: Color) -> Color {
        let color1 = NSColor(self)
        let color2 = NSColor(color)

        guard let blended = color1.blended(withFraction: fraction, of: color2)
        else { return self }

        return Color(blended)
    }
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

// MARK: - DisplayRowView

struct DisplayRowView: View {
    @ObservedObject var display: Display
    @Environment(\.colors) var colors
    @Default(.showSliderValues) var showSliderValues
    @Default(.showInputInQuickActions) var showInputInQuickActions

    var softwareSliders: some View {
        Group {
            if display.enhanced {
                BigSurSlider(
                    percentage: $display.xdrBrightness,
                    image: "speedometer",
                    color: Colors.green.blended(withFraction: 0.2, of: .white),
                    backgroundColor: Colors.green.opacity(0.1),
                    showValue: $showSliderValues
                )
            }
            if display.subzero {
                BigSurSlider(
                    percentage: $display.softwareBrightness,
                    image: "moon.circle.fill",
                    color: Colors.red.blended(withFraction: 0.2, of: .white),
                    backgroundColor: Colors.red.opacity(0.1),
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
                    backgroundColor: colors.accent.opacity(0.1),
                    showValue: $showSliderValues
                )
                softwareSliders
            } else {
                BigSurSlider(
                    percentage: $display.preciseBrightness.f,
                    image: "sun.max.fill",
                    color: colors.accent,
                    backgroundColor: colors.accent.opacity(0.1),
                    showValue: $showSliderValues
                )
                softwareSliders
                BigSurSlider(
                    percentage: $display.preciseContrast.f,
                    image: "circle.righthalf.fill",
                    color: colors.accent,
                    backgroundColor: colors.accent.opacity(0.1),
                    showValue: $showSliderValues
                )
            }

            if display.hasDDC, display.showVolumeSlider {
                BigSurSlider(
                    percentage: $display.preciseVolume.f,
                    image: "speaker.2.fill",
                    color: colors.accent,
                    backgroundColor: colors.accent.opacity(0.1),
                    showValue: $showSliderValues
                )
            }

            if display.hasDDC, showInputInQuickActions {
                Dropdown(
                    selection: $display.inputSource,
                    width: 120,
                    height: 20,
                    noValueText: "Video Input",
                    noValueImage: "input",
                    content: .constant(InputSource.mostUsed)
                )
                .frame(width: 120, height: 20, alignment: .center)
                .padding(.vertical, 3)
            }

            if display.showOrientation {
                rotationSelector.padding(.vertical, 3)
            }

            if let app = display.appPreset {
                SwiftUI.Button("App Preset: \(app.name)") {
                    app.runningApps?.first?.activate()
                }
                .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .secondary))
                .font(.system(size: 9, weight: .bold))
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

extension NSButton {
    override open var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }
}

// MARK: - CheckboxToggleStyle

struct CheckboxToggleStyle: ToggleStyle {
    enum Style {
        case square, circle

        // MARK: Internal

        var sfSymbolName: String {
            switch self {
            case .square:
                return "square"
            case .circle:
                return "circle"
            }
        }
    }

    @Environment(\.isEnabled) var isEnabled
    let style: Style // custom param

    func makeBody(configuration: Configuration) -> some View {
        SwiftUI.Button(action: {
            configuration.isOn.toggle() // toggle the state binding
        }, label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.\(style.sfSymbolName).fill" : style.sfSymbolName)
                    .imageScale(.medium)
                configuration.label
            }
        })
        .buttonStyle(PlainButtonStyle()) // remove any implicit styling from the button
        .disabled(!isEnabled)
    }
}

// MARK: - SettingsToggle

struct SettingsToggle: View {
    @State var text: String
    @Binding var setting: Bool

    var body: some View {
        Toggle(text, isOn: $setting)
            .toggleStyle(CheckboxToggleStyle(style: .circle))
            .foregroundColor(.primary)
            .padding(.vertical, 0.5)
    }
}

extension Animation {
    #if os(iOS)
        static var fastTransition = Animation.easeOut(duration: 0.1)
    #else
        static var fastTransition = Animation.interactiveSpring(dampingFraction: 0.7)
    #endif
    static var fastSpring = Animation.interactiveSpring(dampingFraction: 0.7)
    static var jumpySpring = Animation.spring(response: 0.4, dampingFraction: 0.45)
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

// MARK: - Nameable

protocol Nameable {
    var name: String { get set }
    var image: String? { get }
}

// MARK: - SizedPopUpButton

class SizedPopUpButton: NSPopUpButton {
    var width: CGFloat?
    var height: CGFloat?

    override var intrinsicContentSize: NSSize {
        guard let width = width, let height = height else {
            return super.intrinsicContentSize
        }

        return NSSize(width: width, height: height)
    }
}

// MARK: - Dropdown

struct Dropdown<T: Nameable>: NSViewRepresentable {
    class Coordinator: NSObject {
        // MARK: Lifecycle

        init(_ popUpButton: Dropdown) {
            button = popUpButton
        }

        // MARK: Internal

        var button: Dropdown
        var observer: Cancellable?
        lazy var defaultMenuItem: NSMenuItem = {
            let m = NSMenuItem(title: button.noValueText ?? "", action: nil, keyEquivalent: "")
            m.isHidden = true
            m.isEnabled = true
            m.identifier = NSUserInterfaceItemIdentifier("DEFAULT_MENU_ITEM")
            if let image = button.noValueImage {
                m.image = NSImage(named: image)
            }

            return m
        }()
    }

    @Binding var selection: T
    @State var width: CGFloat?
    @State var height: CGFloat?
    @State var noValueText: String?
    @State var noValueImage: String?

    @Binding var content: [T]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeMenuItems(context: Context) -> [NSMenuItem] {
        content.map { input -> NSMenuItem in
            let item = NSMenuItem(title: input.name, action: nil, keyEquivalent: "")
            item.identifier = NSUserInterfaceItemIdentifier(rawValue: input.name)
            if let image = input.image {
                item.image = NSImage(named: image)
            }

            return item
        } + [context.coordinator.defaultMenuItem]
    }

    func makeNSView(context: Context) -> SizedPopUpButton {
        let button = SizedPopUpButton()
        button.width = width
        button.height = height

        button.bezelStyle = .inline
        button.imagePosition = .imageLeading
        button.usesSingleLineMode = true
        button.autoenablesItems = false
        button.alignment = .center

        let menu = NSMenu()
        menu.items = makeMenuItems(context: context)

        button.menu = menu
        button.select(menu.items.first(where: { $0.title == selection.name }) ?? context.coordinator.defaultMenuItem)
        context.coordinator.observer = button.selectedTitlePublisher.sink { inputName in
            guard let inputName = inputName else { return }
            selection = content.first(where: { $0.name == inputName }) ?? selection
        }
        return button
    }

    func updateNSView(_ button: SizedPopUpButton, context: Context) {
        guard let menu = button.menu else { return }
        menu.items = makeMenuItems(context: context)
        button.select(menu.items.first(where: { $0.title == selection.name }) ?? context.coordinator.defaultMenuItem)
        context.coordinator.observer = button.selectedTitlePublisher.sink { inputName in
            guard let inputName = inputName else { return }
            selection = content.first(where: { $0.name == inputName }) ?? selection
        }

        button.width = width
        button.height = height
    }
}

// MARK: - QuickActionsMenuView

struct QuickActionsMenuView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors
    @ObservedObject var dc: DisplayController = displayController
    @State var displays: [Display] = displayController.activeDisplayList
    @State var cursorDisplay: Display? = displayController.cursorDisplay
    @State var layoutShown = false

    var body: some View {
        VStack {
            if layoutShown {
                QuickActionsLayoutView()
                    .padding(.bottom)
                Divider().padding(.bottom)
            }

            HStack {
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

            if let d = cursorDisplay {
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
            }.padding(.top)

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
        .frame(width: 300, alignment: .top)
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .padding(.top, 20)
        .background(
            ZStack {
                VisualEffectBlur(material: colorScheme == .dark ? .hudWindow : .menu, blendingMode: .behindWindow, state: .active)
                    .cornerRadius(18)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .shadow(color: Colors.blackMauve.opacity(colorScheme == .dark ? 0.5 : 0.3), radius: 4, x: 0, y: 4)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill((colorScheme == .dark ? Colors.blackMauve : Color.white).opacity(0.4))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .brightness(colorScheme == .dark ? 0.0 : 0.5)
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
