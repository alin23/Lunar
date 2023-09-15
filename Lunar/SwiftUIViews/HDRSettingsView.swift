import Defaults
import SwiftUI

struct HDRSettingsView: View {
    @ObservedObject var dc: DisplayController = DC

    @Default(.hdrWorkaround) var hdrWorkaround
    @Default(.xdrContrast) var xdrContrast
    @Default(.xdrContrastFactor) var xdrContrastFactor
    @Default(.subzeroContrast) var subzeroContrast
    @Default(.subzeroContrastFactor) var subzeroContrastFactor
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
                    if DC.activeDisplayList.contains(where: \.supportsGammaByDefault) {
                        SettingsToggle(
                            text: "Enhance contrast in Sub-zero Dimming", setting: $subzeroContrast,
                            help: """
                            Improve readability in very low light by increasing contrast.
                            This option is especially useful when using apps with light backgrounds.

                            Note: works only when using a single display
                            """
                        )
                        let binding = Binding<Float>(
                            get: { subzeroContrastFactor / 5.0 },
                            set: { subzeroContrastFactor = $0 * 5.0 }
                        )
                        HStack {
                            BigSurSlider(
                                percentage: binding,
                                image: "circle.lefthalf.filled",
                                color: Colors.lightGray,
                                backgroundColor: Colors.grayMauve.opacity(0.1),
                                knobColor: Colors.lightGray,
                                showValue: .constant(false),
                                disabled: !$subzeroContrast
                            )
                            .padding(.leading)

                            SwiftUI.Button("Reset") { subzeroContrastFactor = 1.75 }
                                .buttonStyle(FlatButton(
                                    color: Colors.lightGray,
                                    textColor: Colors.darkGray,
                                    radius: 10,
                                    verticalPadding: 3
                                ))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .disabled(!subzeroContrast)
                        }
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
                text: "Enable Dark Mode when enabling XDR", setting: $enableDarkModeXDR.animation(.fastSpring),
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
