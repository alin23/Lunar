import SwiftUI

struct RawValueView: View {
    @Binding var value: Double?
    @State var icon: String
    @State var decimals: UInt8 = 0

    var body: some View {
        if let v = value?.str(decimals: decimals) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                Text(v)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.07)))
        } else {
            EmptyView()
        }
    }
}

struct RawValuesView: View {
    @ObservedObject var display: Display

    var body: some View {
        if display.lastRawBrightness != nil || display.lastRawContrast != nil || display.lastRawVolume != nil {
            HStack(spacing: 0) {
                Text("Raw Values").font(.system(size: 11, weight: .semibold, design: .monospaced))
                Spacer()
                HStack(spacing: 4) {
                    RawValueView(
                        value: $display.lastRawBrightness,
                        icon: "sun.max.fill",
                        decimals: display.control is AppleNativeControl && (display.lastRawBrightness ?? 0 <= 1) ? 2 : 0
                    )
                    RawValueView(value: $display.lastRawContrast, icon: "circle.righthalf.fill")
                    RawValueView(value: $display.lastRawVolume, icon: "speaker.2.fill")
                }.fixedSize()
            }.foregroundColor(.secondary).padding(.horizontal, 3)
        } else {
            EmptyView()
        }
    }
}
