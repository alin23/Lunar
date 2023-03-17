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
    @State var color: Color? = Colors.blackMauve
    @State var help: String?
    @State var helpShown = false

    var body: some View {
        HStack {
            Toggle(text, isOn: $setting)
                .toggleStyle(CheckboxToggleStyle(style: .circle))
                .foregroundColor(color)
            if let help {
                SwiftUI.Button(action: { helpShown = true }) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 12, weight: .black))
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
        }.frame(height: 14)
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
        color: Color = Color.primary.opacity(0.8),
        hoverColor: Color = Color.primary,
        multiplyColor: Color = Color.white,
        scale: CGFloat = 1,
        thickness: CGFloat = 2,
        font: Font = .body.bold()
    ) {
        _color = State(initialValue: color)
        _hoverColor = State(initialValue: hoverColor)
        _multiplyColor = State(initialValue: multiplyColor)
        _scale = State(initialValue: scale)
        _thickness = State(initialValue: thickness)
        _font = State(initialValue: font)
    }

    @Environment(\.isEnabled) var isEnabled

    @State var color = Color.primary.opacity(0.8)
    @State var hoverColor: Color = .primary
    @State var multiplyColor: Color = .white
    @State var scale: CGFloat = 1
    @State var thickness: CGFloat = 2
    @State var font: Font = .body.bold()

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

}

// MARK: - FlatButton

struct FlatButton: ButtonStyle {
    init(
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
        pressedBinding: Binding<Bool>? = nil,
        horizontalPadding: CGFloat = 8,
        verticalPadding: CGFloat = 4,
        stretch: Bool = false
    ) {
        _color = colorBinding ?? .constant(color ?? Colors.lightGold)
        _textColor = textColorBinding ?? .constant(textColor ?? Colors.blackGray)
        _hoverColor = hoverColorBinding ?? .constant(hoverColor ?? Colors.lightGold)
        _width = .constant(width)
        _height = .constant(height)
        _circle = .constant(circle)
        _radius = .constant(radius)
        _pressed = pressedBinding ?? .constant(false)
        _horizontalPadding = horizontalPadding.state
        _verticalPadding = verticalPadding.state
        _stretch = State(initialValue: stretch)
    }

    @Environment(\.colors) var colors
    @Environment(\.isEnabled) var isEnabled

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
    @State var horizontalPadding: CGFloat = 8
    @State var verticalPadding: CGFloat = 4
    @State var stretch = false

    func makeBody(configuration: Configuration) -> some View {
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
            .scaleEffect(configuration.isPressed && isEnabled ? 1.02 : scale)
            .colorMultiply(configuration.isPressed && isEnabled ? pressedColor : colorMultiply)
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
                guard isEnabled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    colorMultiply = hover ? hoverColor : .white
                    scale = hover ? 1.07 : 1
                }
            })
            .contrast(!isEnabled ? 0.3 : 1.0)
    }

}

// MARK: - PickerButton

struct PickerButton<T: Equatable>: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.colors) var colors
    @Environment(\.colorScheme) var colorScheme

    @State var color = Color.primary.opacity(0.15)
    @State var onColor: Color? = nil
    var offColor: Binding<Color>?
    @State var onTextColor: Color? = nil
    @State var offTextColor = Color.secondary
    @State var horizontalPadding: CGFloat = 8
    @State var verticalPadding: CGFloat = 4
    @State var brightness = 0.0
    @State var scale: CGFloat = 1
    @State var hoverColor = Color.white
    @Binding var enumValue: T
    @State var onValue: T

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(
                enumValue == onValue
                    ? (onTextColor ?? (colorScheme == .dark ? colors.accent : Color.white))
                    : offTextColor
            )
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        enumValue == onValue
                            ? (onColor ?? Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.9))
                            : (offColor?.wrappedValue ?? color.opacity(colorScheme == .dark ? 0.5 : 0.8))
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
                    hoverColor = hover ? colors.accent : .white
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
}

// MARK: - SizedPopUpButton

final class SizedPopUpButton: NSPopUpButton {
    var width: CGFloat?
    var height: CGFloat?

    override var intrinsicContentSize: NSSize {
        guard let width, let height else {
            return super.intrinsicContentSize
        }

        return NSSize(width: width, height: height)
    }
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
        button.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
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
            selection = content.first(where: { $0.name == inputName }) ?? selection
        }

        button.width = width
        button.height = height

        setTitleAndImage(button)
    }
}
