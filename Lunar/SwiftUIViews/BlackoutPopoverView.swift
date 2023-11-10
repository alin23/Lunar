import Defaults
import SwiftUI

struct BlackoutPopoverView: View {
    @State var hasDDC: Bool
    @Default(.hotkeys) var hotkeys
    @Default(.newBlackOutDisconnect) var newBlackOutDisconnect

    var body: some View {
        ZStack {
            Color.black.brightness(0.02).scaleEffect(1.5)
            VStack(alignment: .leading, spacing: 10) {
                BlackoutPopoverHeaderView().padding(.bottom)
                if DC.activeDisplayCount == 1 {
                    BlackoutPopoverRowView(action: "Make screen black", hotkeyText: hotkeyText(id: .blackOut), actionInfo: "(without disabling it)")
                } else {
                    if newBlackOutDisconnect, #available(macOS 13, *) {
                        BlackoutPopoverRowView(action: "Disconnect screen", hotkeyText: hotkeyText(id: .blackOut), actionInfo: "(free up GPU)")
                    } else {
                        BlackoutPopoverRowView(action: "Soft power off", hotkeyText: hotkeyText(id: .blackOut), actionInfo: "(disables screen by mirroring)")
                    }
                    BlackoutPopoverRowView(
                        modifiers: ["Shift"],
                        action: "Make screen black",
                        hotkeyText: hotkeyText(id: .blackOutNoMirroring),
                        actionInfo: "(without disabling it)"
                    )
                    BlackoutPopoverRowView(
                        modifiers: ["Option", "Shift"],
                        action: "Make other screens black",
                        hotkeyText: hotkeyText(id: .blackOutOthers),
                        actionInfo: "(keep this one visible)"
                    )

                    #if arch(arm64)
                        if #available(macOS 13, *) {
                            Divider().background(Color.white.opacity(0.2))
                            if newBlackOutDisconnect {
                                BlackoutPopoverRowView(modifiers: ["Command"], action: "Soft power off", hotkeyText: "", actionInfo: "(disables screen by mirroring)")
                                    .colorMultiply(Color.orange)
                            } else {
                                BlackoutPopoverRowView(
                                    modifiers: ["Command"],
                                    action: "Disconnect screen",
                                    hotkeyText: "",
                                    actionInfo: "(free up GPU)"
                                )
                                .colorMultiply(Color.orange)
                            }
                        }
                    #endif
                }

                if hasDDC {
                    BlackoutPopoverRowView(
                        modifiers: ["Option"],
                        action: "Hardware power off",
                        hotkeyText: hotkeyText(id: .blackOutPowerOff),
                        actionInfo: "(uses DDC)"
                    )
                    .colorMultiply(Color.red)
                }
                Divider().background(Color.white.opacity(0.2))
                BlackoutPopoverRowView(modifiers: ["Control"], action: "Show this help menu")
                    .colorMultiply(Color.peach)

                HStack(spacing: 7) {
                    Text("Press")
                    Text("⌘ Command")
                        .padding(.vertical, 3)
                        .padding(.horizontal, 5)
                        .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color.white))
                        .foregroundColor(.black)
                    Text("more than 8 times in a row to force turn on all displays and reset BlackOut")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.1)))
                .colorMultiply(Color.peach)
                .padding(.top)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }.preferredColorScheme(.light)
    }

    func hotkeyText(id: HotkeyIdentifier) -> String {
        guard let h = hotkeys.first(where: { $0.identifier == id.rawValue }), h.isEnabled else { return "" }
        return h.keyCombo.keyEquivalentModifierMaskString + h.keyCombo.keyEquivalent
    }
}
