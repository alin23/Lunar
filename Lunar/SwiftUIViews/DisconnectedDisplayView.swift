#if arch(arm64)
    import Defaults
    import SwiftUI

    @available(macOS 13, *)
    struct ReconnectButtonView: View {
        @State var display: CGDirectDisplayID
        @State var hovering = false
        @State var off = true

        var body: some View {
            HStack(spacing: 2) {
                SwiftUI.Button(action: {
                    off = false
                    DC.autoBlackoutPause = true
                    DC.en(display)
                }) {
                    Image(systemName: "power").font(.system(size: 10, weight: .heavy))
                }
                .buttonStyle(FlatButton(
                    color: off ? Color.gray : Color.red,
                    circle: true,
                    horizontalPadding: 3,
                    verticalPadding: 3
                ))
                .onHover { h in withAnimation { hovering = h } }
                Text("Connect")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(hovering ? 1 : 0)
            }
            .frame(width: 100, alignment: .leading)
        }
    }

    @available(macOS 13, *)
    struct DisconnectedDisplayView: View {
        @State var id: CGDirectDisplayID
        @State var name: String
        @State var possibly = false

        @ObservedObject var display: Display

        @Default(.autoBlackoutBuiltin) var autoBlackoutBuiltin

        var body: some View {
            VStack(spacing: 1) {
                HStack(alignment: .top, spacing: -10) {
                    Text(name)
                        .font(.system(size: 22, weight: .black))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.bg.primary.opacity(0.5)))

                    ReconnectButtonView(display: id)
                        .offset(y: -8)
                }.offset(x: 45)

                Text(possibly ? "Possibly disconnected" : "Disconnected")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))

                if display.id == id, !display.isSidecar, !display.isAirplay {
                    let binding = !display.isMacBook
                        ? $display.keepDisconnected
                        : Binding<Bool>(
                            get: { autoBlackoutBuiltin },
                            set: {
                                autoBlackoutBuiltin = $0
                                display.keepDisconnected = $0
                            }
                        )
                    VStack {
                        SettingsToggle(
                            text: "Auto Disconnect",
                            setting: binding,
                            color: nil,
                            help: !display.isMacBook
                                ? """
                                The display might come back on by itself after standby/wake or when
                                reconnecting the monitor cable.

                                This option will automatically disconnect the display whenever that
                                happens, until you reconnect the display manually using the power button.

                                Note: Press ⌘ Command more than 8 times in a row to force connect all displays.
                                """
                                : """
                                Turns off the built-in screen automatically when a monitor is connected and turns
                                it back on when the last monitor is disconnected.

                                Keeps the screen disconnected between standby/wake or lid open/close states.

                                Note: Press ⌘ Command more than 8 times in a row to force connect all displays.
                                """
                        )
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
                    .padding(.vertical, 3)
                }
            }
        }
    }

#endif
