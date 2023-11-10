#if arch(arm64)
    import Combine
    import Defaults
    import SwiftUI

    struct NitsTextField: View {
        @Binding var nits: Double
        @State var placeholder: String
        @ObservedObject var display: Display
        @State var editing = false

        @Default(.syncMode) var syncMode

        var editPopover: some View {
            PaddedPopoverView(background: Color.peach.any) {
                VStack {
                    Text("\(placeholder.titleCase())imum nits")
                        .font(.title.bold())
                    Text("for \(display.name)")

                    TextField("nits", value: $nits, formatter: NumberFormatter.shared(decimals: 0, padding: 0))
                        .onReceive(Just(nits)) { _ in
                            display.nitsEditPublisher.send(true)
                        }
                        .textFieldStyle(PaddedTextFieldStyle(backgroundColor: Color.translucid))
                        .font(.system(size: 20, weight: .bold, design: .monospaced).leading(.tight))
                        .lineLimit(1)
                        .frame(width: 70)
                        .multilineTextAlignment(.center)
                        .padding(.vertical)

                    Text("Value estimated from monitor\nfirmware data and user input")
                        .font(.system(size: 12, weight: .medium, design: .rounded).leading(.tight))
                        .foregroundColor(Color.grayMauve.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
        }

        var body: some View {
            if syncMode, SyncMode.isUsingNits() {
                let disabled = display.isNative && (placeholder == "max" || display.isActiveSyncSource)
                SwiftUI.Button(action: { editing = true }) {
                    VStack(spacing: -3) {
                        Text(nits.str(decimals: 0))
                            .font(.system(size: 10, weight: .bold, design: .monospaced).leading(.tight))
                        Text("nits")
                            .font(.system(size: 8, weight: .semibold, design: .rounded).leading(.tight))
                    }
                }
                .buttonStyle(FlatButton(color: Color.translucid, textColor: .fg.warm.opacity(0.6)))
                .frame(width: 50)
                .popover(isPresented: $editing) { editPopover }
                .disabled(disabled)
                .help(disabled ? "Managed by the system" : "")
            }
        }
    }

#endif
