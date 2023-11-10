import SwiftUI

struct PresetButtonView: View {
    @State var percent: Int8

    var body: some View {
        SwiftUI.Button("\(percent)%") {
            appDelegate!.setLightPercent(percent: percent)
        }
        .buttonStyle(FlatButton(color: Color.fg.warm.opacity(0.05), textColor: Color.fg.warm))
        .font(.system(size: 12, weight: .medium, design: .monospaced))
    }
}
