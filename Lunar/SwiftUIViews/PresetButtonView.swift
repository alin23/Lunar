import SwiftUI

struct PresetButtonView: View {
    @State var percent: Int8

    var body: some View {
        SwiftUI.Button("\(percent)%") {
            appDelegate!.setLightPercent(percent: percent)
        }
        .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary))
        .font(.system(size: 12, weight: .medium, design: .monospaced))
    }
}
