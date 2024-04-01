//
//  QuickActionsViewController.swift
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

enum MenuDensity: String, Codable, Defaults.Serializable {
    case clean
    case comfortable
    case dense
}

final class EnvState: ObservableObject {
    @Published var menuWidth: CGFloat = MENU_WIDTH
    @Published var menuHeight: CGFloat = 100
    @Published var menuMaxHeight: CGFloat = (NSScreen.main?.visibleFrame.height ?? 600) - 50

    @Published var hoveringSlider = false
    @Published var draggingSlider = false
    @Published var optionsTab: OptionsTab = .layout

    @Published var recording = false
}

enum OptionsTab: String, Defaults.Serializable {
    case layout
    case advanced
    case hdr
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

let MENU_WIDTH: CGFloat = 320
let OPTIONS_MENU_WIDTH: CGFloat = 390
let FULL_OPTIONS_MENU_WIDTH: CGFloat = 412
let MENU_CLEAN_WIDTH: CGFloat = 300
let MENU_HORIZONTAL_PADDING: CGFloat = 24
let MENU_VERTICAL_PADDING: CGFloat = 40
let FULL_MENU_WIDTH: CGFloat = MENU_WIDTH + (MENU_HORIZONTAL_PADDING * 2)

struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct QuickActionsView_Previews: PreviewProvider {
    static var previews: some View {
        QuickActionsView()
    }
}
