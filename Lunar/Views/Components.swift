//
//  Components.swift
//
//
//  Created by Alin Panaitiu on 18.03.2022.
//

import Cocoa
import Combine
import Defaults
import Foundation
import SwiftUI

// MARK: - SettingsToggle

struct SettingsToggle: View {
    @State var text: String
    @Binding var setting: Bool
    @State var color: Color? = Color.blackMauve
    @State var help: String?
    @State var helpShown = false
    @State var mode: AdaptiveModeKey? = nil

    var modeColor: Color? {
        guard let mode else { return nil }

        switch mode {
        case .sync:
            return Color.green
        case .sensor:
            return Color.blue
        case .location:
            return Color.lunarYellow
        case .clock:
            return Color.orange
        case .manual:
            return Color.red
        case .auto:
            return Color.blackMauve
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(alignment: .center) {
                Toggle(text, isOn: $setting)
                    .toggleStyle(CheckboxToggleStyle(style: .circle))
                    .foregroundColor(color)
                if let help {
                    SwiftUI.Button(action: { helpShown = true }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 13, weight: .black))
                            .imageScale(.medium)
                    }
                    .buttonStyle(FlatButton(
                        color: .clear,
                        textColor: .gray.opacity(0.7),
                        hoverColor: .blue,
                        circle: true,
                        horizontalPadding: 0,
                        verticalPadding: 0
                    ))
                    .popover(isPresented: $helpShown, arrowEdge: .bottom) {
                        PaddedPopoverView(background: AnyView(Color.white)) {
                            Text(help)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            if let modeColor {
                Circle().size(width: 8, height: 8).fill(modeColor)
                    .offset(x: -15, y: 4)
            }
        }.frame(height: 14, alignment: .leading)
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

extension NSButton {
    override open var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }
}

extension Float {
    var inc: Float {
        get { self + 0.5 }
        set {}
    }

    var dec: Float {
        get { self - 0.5 }
        set {}
    }
}

extension Color {
    func blended(withFraction fraction: CGFloat, of color: Color) -> Color {
        let color1 = NSColor(self)
        let color2 = NSColor(color)

        guard let blended = color1.blended(withFraction: fraction, of: color2)
        else { return self }

        return Color(blended)
    }
}

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`(_ condition: @autoclosure () -> Bool, transform: (Self) -> some View) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }
}

struct OutlineButton: ButtonStyle {
    init(
        color: Color = Color.fg.warm.opacity(0.8),
        hoverColor: Color = Color.fg.warm,
        multiplyColor: Color = Color.white,
        scale: CGFloat = 1,
        thickness: CGFloat = 2,
        font: Font = .body.bold()
    ) {
        _multiplyColor = State(initialValue: multiplyColor)
        _scale = State(initialValue: scale)
        self.color = color
        self.hoverColor = hoverColor
        self.thickness = thickness
        self.font = font
    }

    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .font(font)
            .foregroundColor(color)
            .padding(.vertical, 2.0)
            .padding(.horizontal, 8.0)
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                ).stroke(color, lineWidth: thickness)
            ).scaleEffect(scale).colorMultiply(multiplyColor)
            .contentShape(Rectangle())
            .onHover(perform: { hover in
                guard isEnabled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    multiplyColor = hover ? hoverColor : .white
                    scale = hover ? 1.02 : 1.0
                }
            })
            .onChange(of: isEnabled) { e in
                if !e {
                    withAnimation(.easeOut(duration: 0.2)) {
                        multiplyColor = .white
                        scale = 1.0
                    }
                }
            }
    }

    @State private var multiplyColor: Color = .white
    @State private var scale: CGFloat = 1

    private var color = Color.fg.warm.opacity(0.8)
    private var hoverColor: Color = .fg.warm
    private var thickness: CGFloat = 2
    private var font: Font = .body.bold()

}

// MARK: - FlatButton

struct FlatButton: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    var color: Color = .translucid
    var textColor: Color = .fg.warm
    var hoverColor: Color = .lightGold
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var circle = false
    var radius: CGFloat = 8
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 4
    var stretch = false

    @State private var pressedColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        var scale: CGFloat {
            guard isEnabled else { return 1.0 }
            if configuration.isPressed { return 1.02 }
            if hovering { return 1.07 }
            return 1.0
        }
        var tint: Color {
            guard isEnabled else { return .white }
            if configuration.isPressed { return pressedColor }
            if hovering { return hoverColor }
            return .white
        }

        configuration
            .label
            .foregroundColor(textColor)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(
                minWidth: width,
                idealWidth: width,
                maxWidth: stretch ? .infinity : nil,
                minHeight: height,
                idealHeight: height,
                alignment: .center
            )
            .background(
                circle
                    ?
                    AnyView(
                        Circle().fill(color)
                            .frame(
                                minWidth: width,
                                idealWidth: width,
                                maxWidth: stretch ? .infinity : nil,
                                minHeight: height,
                                idealHeight: height,
                                alignment: .center
                            )
                    )
                    : AnyView(
                        RoundedRectangle(
                            cornerRadius: radius,
                            style: .continuous
                        ).fill(color).frame(
                            minWidth: width,
                            idealWidth: width,
                            maxWidth: stretch ? .infinity : nil,
                            minHeight: height,
                            idealHeight: height,
                            alignment: .center
                        )
                    )
            )
            .scaleEffect(scale)
            .colorMultiply(tint)
            .onAppear {
                pressedColor = hoverColor.blended(withFraction: 0.5, of: .white)
            }
            .onHover(perform: { hover in
                guard isEnabled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    hovering = hover
                }
            })
            .contrast(!isEnabled ? 0.3 : 1.0)
    }
    @State var hovering = false

}

// MARK: - PickerButton

struct PickerButton<T: Equatable>: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.colorScheme) var colorScheme

    var color = Color.translucid
    var onColor: Color? = nil
    var offColor: Color? = nil
    var onTextColor: Color? = nil
    var offTextColor = Color.secondary
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 4
    var brightness = 0.0
    var radius: CGFloat = 8
    @State var scale: CGFloat = 1
    @State var hoverColor = Color.white
    @Binding var enumValue: T
    var onValue: T

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(
                enumValue == onValue
                    ? (onTextColor ?? (colorScheme == .dark ? Color.peach : Color.white))
                    : offTextColor
            )
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        enumValue == onValue
                            ? (onColor ?? Color.fg.warm.opacity(colorScheme == .dark ? 0.15 : 0.9))
                            : (offColor ?? color.opacity(colorScheme == .dark ? 0.5 : 0.8))
                    )

            ).scaleEffect(scale).colorMultiply(hoverColor)
            .contentShape(Rectangle())
            .onHover(perform: { hover in
                guard isEnabled else { return }
                guard enumValue != onValue else {
                    hoverColor = .white
                    scale = 1.0
                    return
                }
                withAnimation(.easeOut(duration: 0.1)) {
                    hoverColor = hover ? Color.peach : .white
                    scale = hover ? 1.05 : 1.0
                }
            })
            .opacity(isEnabled ? 1 : 0.7)
    }

}

// MARK: - CheckboxToggleStyle

struct CheckboxToggleStyle: ToggleStyle {
    enum Style {
        case square, circle

        var sfSymbolName: String {
            switch self {
            case .square:
                "square"
            case .circle:
                "circle"
            }
        }
    }

    @Environment(\.isEnabled) var isEnabled

    let style: Style // custom param

    func makeBody(configuration: Configuration) -> some View {
        SwiftUI.Button(action: {
            configuration.isOn.toggle() // toggle the state binding
        }, label: {
            HStack(spacing: 3) {
                Image(systemName: configuration.isOn ? "checkmark.\(style.sfSymbolName).fill" : style.sfSymbolName)
                    .imageScale(.medium)
                configuration.label
            }
        })
        .buttonStyle(PlainButtonStyle()) // remove any implicit styling from the button
        .disabled(!isEnabled)
    }
}

// MARK: - Nameable

protocol Nameable {
    var name: String { get set }
    var image: String? { get }
    var tag: Int? { get }
    var enabled: Bool { get }

    var isSeparator: Bool { get }
}

// MARK: - SizedPopUpButton

final class SizedPopUpButton: NSPopUpButton {
    override var intrinsicContentSize: NSSize {
        guard let width, let height else {
            return super.intrinsicContentSize
        }

        return NSSize(width: width, height: height)
    }

    var width: CGFloat?
    var height: CGFloat?

}

// MARK: - Dropdown

struct Dropdown<T: Nameable>: NSViewRepresentable {
    final class Coordinator: NSObject {
        init(_ popUpButton: Dropdown) {
            button = popUpButton
        }

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
    @State var markdown = false

    @Binding var content: [T]

    var title: Binding<String>?
    var image: Binding<String>?
    var validate: ((NSMenuItem) -> Bool)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeMenuItems(context: Context) -> [NSMenuItem] {
        content.map { input -> NSMenuItem in
            guard !input.isSeparator else {
                return NSMenuItem.separator()
            }

            let item = NSMenuItem(title: input.name, action: nil, keyEquivalent: "")
            item.identifier = NSUserInterfaceItemIdentifier(rawValue: input.name)
            if let image = input.image {
                item.image = NSImage(named: image)
            }
            if let tag = input.tag {
                item.tag = tag
            }

            if let validate {
                item.isEnabled = validate(item)
            } else {
                item.isEnabled = input.enabled
            }

            if markdown {
                item.attributedTitle = MENU_MARKDOWN.attributedString(from: item.title)
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
        button.font = .systemFont(ofSize: 11, weight: .bold)
        button.contentTintColor = Color.fg.warm.ns.withAlphaComponent(0.8)
        button.isBordered = false

        let menu = NSMenu()
        menu.items = makeMenuItems(context: context)

        button.menu = menu
        button.select(menu.items.first(where: { $0.title == selection.name }) ?? context.coordinator.defaultMenuItem)
        context.coordinator.observer = button.selectedTitlePublisher.sink { inputName in
            guard let inputName else { return }
            selection = content.first(where: { $0.name == inputName }) ?? selection
        }
        setTitleAndImage(button)
        return button
    }

    func setTitleAndImage(_ button: SizedPopUpButton) {
        guard let title = title?.wrappedValue else { return }
        button.title = title
        button.attributedTitle = title.attributedString
        if let image = image?.wrappedValue, let item = button.selectedItem {
            item.image = NSImage(named: image)
            if !content.contains(where: { $0.name == title }) {
                item.isHidden = true
                item.isEnabled = true
            }
        }
    }

    func updateNSView(_ button: SizedPopUpButton, context: Context) {
        guard let menu = button.menu else { return }
        menu.items = makeMenuItems(context: context)
        button.select(menu.items.first(where: { $0.title == selection.name }) ?? context.coordinator.defaultMenuItem)
        context.coordinator.observer = button.selectedTitlePublisher.sink { inputName in
            guard let inputName else { return }
            selection = content.first(where: { $0.name == inputName.split(separator: "\t").first?.s ?? inputName }) ?? selection
        }

        button.width = width
        button.height = height

        setTitleAndImage(button)
    }
}

func roundRect(_ radius: CGFloat, fill: Color) -> some View {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
        .fill(fill)
}

func roundRect(_ radius: CGFloat, stroke: Color) -> some View {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
        .stroke(stroke)
}

struct RoundBG: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    var radius: CGFloat
    var verticalPadding: CGFloat?
    var horizontalPadding: CGFloat?
    var color: Color
    var shadowSize: CGFloat

    func body(content: Content) -> some View {
        let verticalPadding = verticalPadding ?? radius / 2
        content
            .padding(.horizontal, horizontalPadding ?? verticalPadding * 2.2)
            .padding(.vertical, verticalPadding)
            .background(
                roundRect(radius, fill: color)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.75 : 0.25), radius: shadowSize, x: 0, y: shadowSize / 2)
            )
    }

}

// MARK: - HelpTag

struct HelpTag: View {
    @Binding var isPresented: Bool

    var text: String
    var offset: CGSize

    var body: some View {
        if isPresented {
            Text(text)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .modifier(RoundBG(radius: 4, verticalPadding: 2.5, horizontalPadding: 6, color: .bg.primary, shadowSize: 2))
                .foregroundColor(.fg.warm)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
                .fixedSize()
                .offset(offset)
                .zIndex(100)
        }
    }

}

extension View {
    func helpTag(isPresented: Binding<Bool>, alignment: Alignment = .center, offset: CGSize = .zero, _ text: String) -> some View {
        overlay(HelpTag(isPresented: isPresented, text: text, offset: offset), alignment: alignment)
    }

    func bottomHelpTag(isPresented: Binding<Bool>, _ text: String) -> some View {
        helpTag(isPresented: isPresented, alignment: .bottom, offset: CGSize(width: 0, height: 15), text)
    }

    func topHelpTag(isPresented: Binding<Bool>, _ text: String) -> some View {
        helpTag(isPresented: isPresented, alignment: .top, offset: CGSize(width: 0, height: -15), text)
    }
}
