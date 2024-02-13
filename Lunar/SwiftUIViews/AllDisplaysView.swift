import Defaults
import SwiftUI

struct AllDisplaysView: View {
    @ObservedObject var display: Display = ALL_DISPLAYS
    @Environment(\.colorScheme) var colorScheme

    @Default(.showSliderValues) var showSliderValues
    @Default(.mergeBrightnessContrast) var mergeBrightnessContrast

    @ViewBuilder var softwareSliders: some View {
        if display.subzero {
            BigSurSlider(
                percentage: $display.softwareBrightness,
                image: "moon.circle.fill",
                color: Color.subzero.opacity(0.7),
                backgroundColor: Color.subzero.opacity(colorScheme == .dark ? 0.1 : 0.2),
                knobColor: Color.subzero,
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
                    colorBinding: .constant(Color.peach),
                    backgroundColorBinding: .constant(Color.peach.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues
                )
                softwareSliders
            } else {
                BigSurSlider(
                    percentage: $display.preciseBrightness.f,
                    image: "sun.max.fill",
                    colorBinding: .constant(Color.peach),
                    backgroundColorBinding: .constant(Color.peach.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues
                )
                softwareSliders
                BigSurSlider(
                    percentage: $display.preciseContrast.f,
                    image: "circle.righthalf.fill",
                    colorBinding: .constant(Color.peach),
                    backgroundColorBinding: .constant(Color.peach.opacity(colorScheme == .dark ? 0.1 : 0.4)),
                    showValue: $showSliderValues
                )
            }
        }
    }
}
