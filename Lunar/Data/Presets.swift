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
    var id: String
    var configs: [PresetConfig]

    static func == (lhs: Preset, rhs: Preset) -> Bool {
        lhs.id == rhs.id
    }

    static func delete(id: String) {
        Defaults[.presets] = Defaults[.presets].filter { $0.id != id }
    }

    func apply() {
        for config in configs {
            guard let display = displayController.activeDisplaysBySerial[config.id] else { continue }
            display.preciseBrightness = config.brightness
            display.preciseContrast = config.contrast
        }
    }

    func delete() {
        Defaults[.presets] = Defaults[.presets].without(self)
    }
}

// MARK: - PresetConfig

struct PresetConfig: Codable, Defaults.Serializable, Hashable, Equatable, Identifiable {
    var id: String
    var brightness: Double
    var contrast: Double
}

// MARK: - ErrorTextView

struct ErrorTextView: View {
    @State var error: String

    var body: some View {
        Text(error).font(.system(size: 16, weight: .medium))
            .foregroundColor(.black)
            .frame(maxWidth: 340, alignment: .topLeading)
            .truncationMode(.middle)
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

    @State var error = ""
    @State var showError = false
    @State var hoveringPreset = ""
    @State var presetName = ""

    @Default(.presets) var presets

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .center, spacing: -2) {
                    Text("Custom").font(.system(size: 10, weight: .bold)).opacity(0.7)
                    Text("Presets").font(.system(size: 12, weight: .heavy)).opacity(0.7)
                }
                Spacer()

                TextField("Preset Name", text: $presetName, onCommit: save)
                    .onReceive(Just(presetName)) { _ in limitText(9) }
                    .textFieldStyle(PaddedTextFieldStyle(backgroundColor: .primary.opacity(0.1)))
                    .frame(width: 100)

                SwiftUI.Button("Save preset") { save() }
                    .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .popover(isPresented: $showError) { ErrorPopoverView(error: $error) }
                    .onChange(of: error, perform: onError(_:))
            }

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
                        }.onHover { hovering in
                            withAnimation(.fastTransition) {
                                hoveringPreset = hovering ? preset.id : ""
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
        .padding(.horizontal, MENU_HORIZONTAL_PADDING)
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
        presets.append(Preset(
            id: presetName,
            configs: displayController.activeDisplayList.map {
                PresetConfig(id: $0.serial, brightness: $0.preciseBrightness, contrast: $0.preciseContrast)
            }
        ))
        presetName = ""
    }

    func limitText(_ upper: Int) {
        if presetName.count > upper {
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
