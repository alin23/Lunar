import SwiftUI

struct PaddedPopoverView<Content>: View where Content: View {
    @State var background: AnyView

    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            background.scaleEffect(1.5)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }.preferredColorScheme(.light)
    }
}
