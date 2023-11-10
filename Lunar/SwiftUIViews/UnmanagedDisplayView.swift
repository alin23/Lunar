import SwiftUI

struct UnmanagedDisplayView: View {
    @ObservedObject var display: Display

    var body: some View {
        VStack(spacing: 1) {
            HStack(alignment: .top, spacing: -10) {
                Text(display.name)
                    .font(.system(size: 22, weight: .black))
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.bg.primary.opacity(0.5)))

                ManageButtonView(display: display)
                    .offset(y: -8)
            }.offset(x: 45)
            Text("Not managed").font(.system(size: 10, weight: .semibold, design: .rounded))
        }
    }
}
