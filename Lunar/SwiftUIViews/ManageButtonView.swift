import SwiftUI

struct ManageButtonView: View {
    @State var display: Display
    @State var hovering = false
    @State var off = true

    var body: some View {
        HStack(spacing: 2) {
            SwiftUI.Button(action: {
                off = false
                display.unmanaged = false
            }) {
                Image(systemName: "power").font(.system(size: 10, weight: .heavy))
            }
            .buttonStyle(FlatButton(
                color: off ? Color.gray : Color.red,
                circle: true,
                horizontalPadding: 3,
                verticalPadding: 3
            ))
            Text("Unignore")
                .font(.system(size: 10, weight: .semibold))
                .opacity(hovering ? 1 : 0)
        }
        .onHover { h in withAnimation { hovering = h } }
        .frame(width: 100, alignment: .leading)
    }
}
