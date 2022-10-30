//
//  Presets.swift
//  Lunar
//
//  Created by Alin Panaitiu on 21.03.2022.
//  Copyright © 2022 Alin. All rights reserved.
//

import Combine
import Defaults
import Foundation
import SwiftUI

// MARK: - Preset

struct Preset: Codable, Defaults.Serializable, Hashable, Equatable, Identifiable {
    // MARK: Lifecycle

    init(id: String, key: Int, configs: [PresetConfig]) {
        self.id = id
        self.key = key
        self.configs = configs
        hotkey = getHotkey()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        configs = try container.decode([PresetConfig].self, forKey: .configs)

        key = (try container.decodeIfPresent(Int.self, forKey: .key)) ?? 0
        hotkey = getHotkey()
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
        case id
        case key
        case configs
    }

    var id: String
    var key: Int
    var configs: [PresetConfig]

    var hotkey: PersistentHotkey?

    static func == (lhs: Preset, rhs: Preset) -> Bool {
        lhs.id == rhs.id
    }

    static func delete(id: String) {
        if let hotkey = CachedDefaults[.presets].first(where: { $0.id == id })?.hotkey {
            hotkey.delete()
        }
        CachedDefaults[.presets] = CachedDefaults[.presets].filter { $0.id != id }
    }

    func getHotkey() -> PersistentHotkey? {
        guard let keyCombo = KeyCombo(QWERTYKeyCode: key, cocoaModifiers: [.control, .command]) else { return nil }
        let hotkey = PersistentHotkey("\(PersistentHotkey.PRESET_PREFIX)\(id)", dict: [
            .keyCode: key,
            .enabled: 1,
            .modifiers: keyCombo.modifiers,
            .allowsHold: 0,
        ]).with { hk in
            guard let preset = CachedDefaults[.presets].first(where: { $0.key == hk.keyCombo.QWERTYKeyCode }) else {
                CachedDefaults[.hotkeys] = CachedDefaults[.hotkeys].filter { $0.identifier != hk.identifier }
                hk.unregister()
                return
            }
            preset.apply()
        }
        hotkey.register()
        hotkey.save()

        return hotkey
    }

    func apply() {
        displayController.disable()
        for config in configs {
            guard let display = displayController.activeDisplaysBySerial[config.id] else { continue }
            display.preciseBrightness = config.brightness
            display.preciseContrast = config.contrast
            if config.brightness <= 0.01 {
                display.softwareBrightness = config.softwareBrightness.f
            }
        }
    }

    func delete() {
        CachedDefaults[.presets] = CachedDefaults[.presets].without(self)
        hotkey?.delete()
    }
}

// MARK: - PresetConfig

struct PresetConfig: Codable, Defaults.Serializable, Hashable, Equatable, Identifiable {
    // MARK: Lifecycle

    init(id: String, brightness: Double, contrast: Double, softwareBrightness: Double) {
        self.id = id
        self.brightness = brightness
        self.contrast = contrast
        self.softwareBrightness = softwareBrightness
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        brightness = try container.decode(Double.self, forKey: .brightness)
        contrast = try container.decode(Double.self, forKey: .contrast)

        softwareBrightness = (try container.decodeIfPresent(Double.self, forKey: .softwareBrightness)) ?? 1.0
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
        case id
        case brightness
        case contrast
        case softwareBrightness
    }

    var id: String
    var brightness: Double
    var contrast: Double
    var softwareBrightness: Double
}

// MARK: - ErrorTextView

struct ErrorTextView: View {
    @State var error: String

    var body: some View {
        Text(error).font(.system(size: 16, weight: .medium))
            .foregroundColor(.black)
            .frame(width: 340, alignment: .topLeading)
    }
}

// MARK: - ErrorPopoverView

struct ErrorPopoverView: View {
    @Binding var error: String

    var body: some View {
        ZStack {
            Color.red.brightness(0.4).scaleEffect(1.5)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Error").font(.system(size: 24, weight: .heavy)).foregroundColor(.black).padding(.trailing)
                    Spacer()
                    SwiftUI.Button(
                        action: { error = "" },
                        label: { Image(systemName: "xmark.circle.fill").font(.system(size: 18, weight: .semibold)) }
                    )
                    .buttonStyle(FlatButton(color: .clear, textColor: .black, circle: true))
                }
                ErrorTextView(error: error)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .preferredColorScheme(.light)
        .onDisappear { error = "" }
    }
}

// MARK: - CustomPresetsView

struct CustomPresetsView: View {
    static var errorCloser: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }

    @EnvironmentObject var env: EnvState
    @Environment(\.colors) var colors

    @State var error = ""
    @State var showError = false
    @State var hoveringPreset = ""
    @State var presetName = ""
    @State var presetKey: Int = Key.p.QWERTYKeyCode.i
    @State var presetKeyChanged = false

    @Default(.presets) var presets

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .center, spacing: -2) {
                    Text("Custom").font(.system(size: 12, weight: .bold)).opacity(0.7)
                    Text("Presets").font(.system(size: 12, weight: .heavy)).opacity(0.7)
                }

                Spacer()
                HStack(spacing: 1) {
                    Text("⌃")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .offset(x: 0, y: 2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.1)))
                        .foregroundColor(Color.gray)
                    Text("⌘")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.1)))
                        .foregroundColor(Color.gray)
                    DynamicKey(keyCode: $presetKey)
                }.frame(minWidth: 90, alignment: .trailing)
                TextField("Preset Name", text: $presetName)
                    .onReceive(Just(presetName)) { name in
                        limitText(10)
                        if !presetKeyChanged, let char = name.first(
                            where: { $0.isASCII && CharacterSet.alphanumerics.contains($0.unicodeScalars.first!) }
                        ), let key = Key(character: String(char), virtualKeyCode: nil) {
                            presetKey = key.QWERTYKeyCode.i
                        }
                    }
                    .textFieldStyle(PaddedTextFieldStyle(backgroundColor: .primary.opacity(0.1)))
                    .frame(width: 100)

                SwiftUI.Button("Save") { save() }
                    .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .popover(isPresented: $showError) { ErrorPopoverView(error: $error) }
                    .onChange(of: error, perform: onError(_:))
            }.frame(maxWidth: .infinity)

            if !presets.isEmpty {
                LazyVGrid(columns: [.init(), .init(), .init()]) {
                    ForEach(presets) { preset in
                        ZStack(alignment: .topLeading) {
                            SwiftUI.Button(preset.id) {
                                preset.apply()
                            }
                            .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary, stretch: true))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))

                            SwiftUI.Button(action: { preset.delete() }) {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 14, weight: .bold))
                            }
                            .buttonStyle(FlatButton(color: .clear, textColor: .red, circle: true))
                            .opacity(hoveringPreset == preset.id ? 1.0 : 0.0)
                            .offset(x: -15, y: -10)

                            Text(DynamicKey.keyString(preset.key))
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(colors.fg.gray))
                                .foregroundColor(colors.bg.gray)
                                .offset(x: -6, y: -6)
                                .opacity(hoveringPreset == preset.id ? 0.0 : 1.0)
                        }.onHover { hovering in
                            withAnimation(.fastTransition) {
                                hoveringPreset = hovering ? preset.id : ""
                            }
                        }
                    }
                }
            }
        }.onChange(of: env.recording) { newRecording in
            if !newRecording { presetKeyChanged = true }
        }
    }

    func save() {
        guard !presetName.isEmpty else {
            error = "Preset name is empty"
            return
        }
        guard !presets.contains(where: { $0.id == presetName }) else {
            error = "Preset '\(presetName)' already exists"
            return
        }
        guard !presets.contains(where: { $0.key == presetKey }) else {
            let preset = presets.first { $0.key == presetKey }
            error = "Preset with hotkey \(DynamicKey.keyString(presetKey)) already exists: \(preset?.id ?? "")"
            return
        }

        presets.append(Preset(
            id: presetName,
            key: presetKey,
            configs: displayController.activeDisplayList.map {
                PresetConfig(
                    id: $0.serial,
                    brightness: $0.preciseBrightness,
                    contrast: $0.preciseContrast,
                    softwareBrightness: cap($0.softwareBrightness, minVal: 0.0, maxVal: 1.0).d
                )
            }
        ))

        presetName = ""
        presetKey = Key.p.QWERTYKeyCode.i
        presetKeyChanged = false
    }

    func limitText(_ upper: Int) {
        if presetName.count > upper {
            error = "Preset name should contain a maximum of \(upper) characters"
            presetName = String(presetName.prefix(upper))
        }
    }

    func onError(_ error: String) {
        if !error.isEmpty {
            showPopover()
        } else {
            showError = false
        }
    }

    func showPopover() {
        showError = true
        CustomPresetsView.errorCloser = mainAsyncAfter(ms: 4000) {
            showError = false
            error = ""
        }
    }
}

// MARK: - CustomPresetsView_Previews

struct CustomPresetsView_Previews: PreviewProvider {
    static var previews: some View {
        CustomPresetsView()
    }
}

import Carbon
import Magnet
import Sauce

// MARK: - DynamicKey

struct DynamicKey: View {
    static let darkHoverColor = Colors.peach
    static let lightHoverColor = Colors.lunarYellow

    @EnvironmentObject var env: EnvState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors

    @Binding var keyCode: Int
    @State var recordingColor = Color.white
    @State var color = Color.primary.opacity(0.1)
    @State var textColor = Color.primary
    @State var recording = false
    @State var hoverColor = Self.darkHoverColor
    @State var fontSize: CGFloat = 13
    @State var width: CGFloat? = nil
    @Default(.menuBarClosed) var menuBarClosed

    var body: some View {
        SwiftUI.Button(DynamicKey.keyString(keyCode)) {
            if env.recording, !recording {
                env.recording = false
                return
            }
            recording.toggle()
        }.buttonStyle(
            FlatButton(colorBinding: $color, textColorBinding: $textColor, hoverColorBinding: $hoverColor, width: width)
        )
        .font(.system(size: fontSize, weight: .bold, design: .monospaced))
        .colorMultiply(recordingColor)
        .background(recording ? KeyEventHandling(recording: $recording, key: $keyCode) : nil)
        .cornerRadius(6)
        .onHover { hovering in
            guard !recording else { return }
            withAnimation(.fastTransition) {
                textColor = hovering ? (colorScheme == .dark ? .white : .gray) : Color.primary
                color = hovering ? .white.opacity(0.2) : Color.primary.opacity(0.1)
            }
        }
        .onAppear { hoverColor = colorScheme == .dark ? Self.darkHoverColor : Self.lightHoverColor }
        .onChange(of: recording) { newRecording in
            env.recording = newRecording
            hoverColor = newRecording ? .white : (colorScheme == .dark ? Self.darkHoverColor : Self.lightHoverColor)
            textColor = newRecording ? .white : Color.primary
            color = newRecording ? .white.opacity(0.2) : Color.primary.opacity(0.1)
            withAnimation(.fastTransition) {
                recordingColor = newRecording ? Colors.red : .white
            }
        }
        .onChange(of: colorScheme) { hoverColor = $0 == .dark ? Self.darkHoverColor : Self.lightHoverColor }
        .onChange(of: menuBarClosed) { if $0 { recording = false } }
        .onChange(of: env.recording) { newRecording in
            if recording, !newRecording {
                recording = false
            }
        }
        .onDisappear { recording = false }
        .onExitCommand { recording = false }
    }

    static func keyString(_ keyCode: Int) -> String {
        switch keyCode {
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        default: return Key(QWERTYKeyCode: keyCode.i)?.rawValue.uppercased() ?? ""
        }
    }
}

// MARK: - KeyEventHandling

struct KeyEventHandling: NSViewRepresentable {
    class Coordinator: NSObject {
        // MARK: Lifecycle

        init(_ handler: KeyEventHandling) {
            eventHandler = handler
        }

        // MARK: Internal

        var eventHandler: KeyEventHandling
    }

    class KeyView: NSView {
        dynamic var context: Context?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard let context else {
                return
            }

            guard event.keyCode != kVK_Escape.u16 else {
                #if DEBUG
                    print("Cancel Recording")
                #endif

                context.coordinator.eventHandler.recording = false
                return
            }
            guard KeyEventHandling.ALLOWED_KEYS.contains(event.keyCode.i) else { return }

            #if DEBUG
                print("End Recording: \(event.keyCode)")
            #endif

            context.coordinator.eventHandler.recording = false
            context.coordinator.eventHandler.key = event.keyCode.i
        }
    }

    static let NUMBER_KEYS = [
        kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
    ]
    static let ALLOWED_KEYS = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15,
        kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
        kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_E, kVK_ANSI_R, kVK_ANSI_T, kVK_ANSI_Y, kVK_ANSI_U, kVK_ANSI_I, kVK_ANSI_O, kVK_ANSI_P,
        kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_D, kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L,
        kVK_ANSI_Z, kVK_ANSI_X, kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_B, kVK_ANSI_N, kVK_ANSI_M,
    ]

    @Binding var recording: Bool
    @Binding var key: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.context = context
        DispatchQueue.main.async { // wait till next event cycle
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? KeyView)?.context = context
    }
}
