import Defaults
import SwiftUI

struct BlackoutPopoverHeaderView: View {
    @Default(.neverShowBlackoutPopover) var neverShowBlackoutPopover

    var body: some View {
        HStack {
            Text("BlackOut")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)
            Spacer()
            if lunarProActive || lunarProOnTrial {
                Text("Click anywhere to hide")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            } else {
                SwiftUI.Button("Needs Lunar Pro") {
                    showCheckout()
                    appDelegate?.windowController?.window?.makeKeyAndOrderFront(nil)
                }.buttonStyle(FlatButton(color: Color.red, textColor: .white))
            }
        }
    }
}
