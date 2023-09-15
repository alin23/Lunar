import SwiftUI

struct BlackoutPopoverRowView: View {
    @State var modifiers: [String] = []
    @State var action: String
    @State var hotkeyText = ""
    @State var actionInfo = ""

    var body: some View {
        HStack {
            Text((modifiers + ["Click"]).joined(separator: " + ")).font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                ).frame(width: 200, alignment: .leading)
            HStack {
                if !hotkeyText.isEmpty {
                    Text("or").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.5))
                    Text(hotkeyText).font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .kerning(3)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }.frame(width: 100, alignment: .leading)
            HStack {
                Text(action)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                if !actionInfo.isEmpty {
                    Text(actionInfo)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
}
