import Defaults
import Sparkle
import SwiftUI

// MARK: - UpdateCheckInterval

enum UpdateCheckInterval: Int {
    case daily = 86400
    case everyThreeDays = 259_200
    case weekly = 604_800
    case monthly = 2_592_000
}

import Paddle

// MARK: - LicenseView

struct LicenseView: View {
    @State var product: PADProduct? = lunarProProduct

    @Default(.lunarProActive) var lunarProActive
    @Default(.lunarProOnTrial) var lunarProOnTrial

    var body: some View {
        HStack {
            Text("Licence:")
                .font(.system(size: 12, weight: .medium))
            Text(lunarProOnTrial ? "trial" : (lunarProActive ? "active" : "inactive"))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(lunarProOnTrial ? Color.peach : (lunarProActive ? Color.lightGreen : Color.red))
                )
                .foregroundColor(lunarProOnTrial ? .black : (lunarProActive ? .black : .white))

            if lunarProOnTrial, let days = product?.trialDaysRemaining {
                VStack(spacing: -3) {
                    Text("\(days) days")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                    Text("remaining")
                        .font(.system(size: 7, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(days.intValue > 7 ? Color.lightGreen : (days.intValue > 3 ? Color.peach : Color.red))
                )
                .foregroundColor(days.intValue > 7 ? .black : (days.intValue > 3 ? .black : .white))
            }
            Spacer()

            if lunarProOnTrial {
                SwiftUI.Button("Buy") { showCheckout() }
                    .buttonStyle(FlatButton(
                        color: Color.fg.warm.opacity(0.9),
                        textColor: Color.inverted,
                        horizontalPadding: 6,
                        verticalPadding: 3
                    ))
                    .font(.system(size: 12, weight: .semibold))
            }
            SwiftUI.Button((lunarProActive && !lunarProOnTrial) ? "Manage" : "Activate") { showLicenseActivation() }
                .buttonStyle(FlatButton(color: Color.fg.warm.opacity(0.9), textColor: Color.inverted, horizontalPadding: 6, verticalPadding: 3))
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(Color.fg.warm.opacity(0.6))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.fg.warm.opacity(0.03)))
        .onAppear { product = lunarProProduct }
    }

}

// MARK: - VersionView

struct VersionView: View {
    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var beta: Binding<Bool> = Binding(
        get: { Defaults[.updateChannel] != .release },
        set: { Defaults[.updateChannel] = $0 ? .beta : .release }
    )

    @Default(.checkForUpdate) var checkForUpdates
    @Default(.updateCheckInterval) var updateCheckInterval
    @Default(.updateChannel) var updateChannel
    @Default(.silentUpdate) var silentUpdate

    @ObservedObject var updater: SPUUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Version:")
                    .font(.system(size: 12, weight: .medium))
                Text(Bundle.main.version)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))

                Spacer()

                SwiftUI.Button("Check for updates") { updater.checkForUpdates() }
                    .buttonStyle(FlatButton(
                        color: Color.fg.warm.opacity(0.9),
                        textColor: Color.inverted,
                        horizontalPadding: 6,
                        verticalPadding: 3
                    ))
                    .font(.system(size: 12, weight: .semibold))
            }
            Divider().padding(.vertical, 2).opacity(0.5)
            HStack(spacing: 3) {
                Toggle("Check automatically", isOn: $checkForUpdates)
                    .toggleStyle(CheckboxToggleStyle(style: .circle))
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                SwiftUI.Button("Daily") {
                    checkForUpdates = true
                    updateCheckInterval = UpdateCheckInterval.daily.rawValue
                }
                .buttonStyle(PickerButton(
                    horizontalPadding: 6,
                    verticalPadding: 3,
                    enumValue: $updateCheckInterval,
                    onValue: UpdateCheckInterval.daily.rawValue
                ))
                .font(.system(size: 12, weight: .semibold))
                .disabled(!checkForUpdates)

                SwiftUI.Button("Weekly") {
                    checkForUpdates = true
                    updateCheckInterval = UpdateCheckInterval.weekly.rawValue
                }
                .buttonStyle(PickerButton(
                    horizontalPadding: 6,
                    verticalPadding: 3,
                    enumValue: $updateCheckInterval,
                    onValue: UpdateCheckInterval.weekly.rawValue
                ))
                .font(.system(size: 12, weight: .semibold))
                .disabled(!checkForUpdates)

                SwiftUI.Button("Monthly") {
                    checkForUpdates = true
                    updateCheckInterval = UpdateCheckInterval.monthly.rawValue
                }
                .buttonStyle(PickerButton(
                    horizontalPadding: 6,
                    verticalPadding: 3,
                    enumValue: $updateCheckInterval,
                    onValue: UpdateCheckInterval.monthly.rawValue
                ))
                .font(.system(size: 12, weight: .semibold))
                .disabled(!checkForUpdates)
            }
            Divider().padding(.vertical, 2).opacity(0.5)
            Toggle("Update to beta builds", isOn: beta)
                .toggleStyle(CheckboxToggleStyle(style: .circle))
                .font(.system(size: 12, weight: .medium))
            Toggle("Install updates silently in the background", isOn: $silentUpdate)
                .toggleStyle(CheckboxToggleStyle(style: .circle))
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(Color.fg.warm.opacity(0.6))
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.fg.warm.opacity(0.03)))
    }

}

// MARK: - MenuDensityView

struct MenuDensityView: View {
    @Default(.menuDensity) var menuDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Text("Menu density")
                    .font(.system(size: 12, weight: .medium))
                Spacer()

                SwiftUI.Button("Clean") { menuDensity = .clean }
                    .buttonStyle(PickerButton(horizontalPadding: 6, verticalPadding: 3, enumValue: $menuDensity, onValue: .clean))
                    .font(.system(size: 12, weight: .semibold))

                SwiftUI.Button("Comfortable") { menuDensity = .comfortable }
                    .buttonStyle(PickerButton(horizontalPadding: 6, verticalPadding: 3, enumValue: $menuDensity, onValue: .comfortable))
                    .font(.system(size: 12, weight: .semibold))

                SwiftUI.Button("Dense") { menuDensity = .dense }
                    .buttonStyle(PickerButton(horizontalPadding: 6, verticalPadding: 3, enumValue: $menuDensity, onValue: .dense))
                    .font(.system(size: 12, weight: .semibold))
            }
            HStack(spacing: 3) {
                Text("Click on")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                HStack(spacing: 2) {
                    Image(systemName: "gear.circle.fill").font(.system(size: 10, weight: .semibold))
                    Text("Settings")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.primary.opacity(0.15)))
                Text("at the top for more granular settings")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }.opacity(0.7)
        }
        .foregroundColor(Color.fg.warm.opacity(0.6))
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.fg.warm.opacity(0.03)))
        .onChange(of: menuDensity) { density in
            let dense = density == .dense
            let comfy = density == .comfortable
            let clean = density == .clean

            withAnimation(.fastSpring) {
                Defaults[.showSliderValues] = dense || comfy
                Defaults[.showVolumeSlider] = dense
                Defaults[.showOrientationInQuickActions] = dense
                Defaults[.showInputInQuickActions] = dense || comfy
                Defaults[.showStandardPresets] = dense || comfy
                Defaults[.showCustomPresets] = dense
                Defaults[.showXDRSelector] = dense || comfy
                Defaults[.showHeaderOnHover] = clean
                Defaults[.showFooterOnHover] = clean
            }
        }
    }

}

extension Bundle {
    var version: String {
        (infoDictionary?["CFBundleVersion"] as? String) ?? "1.0.0"
    }
}

// MARK: - SPUUpdater + ObservableObject

extension SPUUpdater: ObservableObject {}

// MARK: - DetailToggleStyle

struct DetailToggleStyle: ToggleStyle {
    init(style: Style = .circle) {
        self.style = style
    }

    enum Style {
        case square, circle, empty

        var sfSymbolName: String {
            switch self {
            case .empty:
                ""
            case .square:
                ".square"
            case .circle:
                ".circle"
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
                Image(
                    systemName: configuration
                        .isOn ? "arrowtriangle.up\(style.sfSymbolName).fill" : "arrowtriangle.down\(style.sfSymbolName).fill"
                )
                .imageScale(.medium)
                configuration.label
            }
        })
        .contentShape(Rectangle())
        .buttonStyle(PlainButtonStyle()) // remove any implicit styling from the button
        .disabled(!isEnabled)
    }
}
