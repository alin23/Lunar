import Defaults
import SwiftUI

struct AllDisplaysView: View {
    @ObservedObject var display: Display = ALL_DISPLAYS
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors
    @Default(.showSliderValues) var showSliderValues
    @Default(.mergeBrightnessContrast) var mergeBrightnessContrast

    @ViewBuilder var softwareSliders: some View {
        if display.subzero {
            BigSurSlider(
                percentage: $display.softwareBrightness,
                image: "moon.circle.fill",
                color: Colors.subzero.opacity(0.7),
                backgroundColor: Colors.subzero.opacity(colorScheme == .dark ? 0.1 : 0.2),
                knobColor: Colors.subzero,
                showValue: $showSliderValues
            )
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(display.name)
                .font(.system(size: 22, weight: .black))
                .padding(.bottom, 6)

            if mergeBrightnessContrast {
                BigSurSlider(
                    percentage: $display.preciseBrightnessContrast.f,
                    image: "sun.max.fill",
                    colorBinding: .constant(colors.accent),
                    backgroundColorBinding: .constant(colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues
                )
                softwareSliders
            } else {
                BigSurSlider(
                    percentage: $display.preciseBrightness.f,
                    image: "sun.max.fill",
                    colorBinding: .constant(colors.accent),
                    backgroundColorBinding: .constant(colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues
                )
                softwareSliders
                BigSurSlider(
                    percentage: $display.preciseContrast.f,
                    image: "circle.righthalf.fill",
                    colorBinding: .constant(colors.accent),
                    backgroundColorBinding: .constant(colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues
                )
            }
        }
    }
}
