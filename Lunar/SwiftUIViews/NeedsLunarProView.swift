import SwiftUI

struct NeedsLunarProView: View {
    var body: some View {
        PaddedPopoverView(background: Color.red.brightness(0.1).any) {
            HStack(spacing: 4) {
                Text("Needs a")
                    .foregroundColor(.black.opacity(0.8))
                    .font(.system(size: 16, weight: .semibold))
                SwiftUI.Button("Lunar Pro") { appDelegate!.getLunarPro(appDelegate!) }
                    .buttonStyle(FlatButton(color: .black.opacity(0.3), textColor: .white))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("licence")
                    .foregroundColor(.black.opacity(0.8))
                    .font(.system(size: 16, weight: .semibold))
            }
        }
    }
}
