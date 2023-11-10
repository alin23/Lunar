import Defaults
import SwiftUI

struct PowerOffButtonView: View {
    @ObservedObject var display: Display
    @ObservedObject var km = KM
    @State var showPopover = false
    @Default(.newBlackOutDisconnect) var newBlackOutDisconnect
    @Default(.neverShowBlackoutPopover) var neverShowBlackoutPopover
    @Default(.allowBlackOutOnSingleScreen) var allowBlackOutOnSingleScreen

    @State var hovering = false
    @StateObject var poweringOff: ExpiringBool = false

    var actionText: String {
        if km.controlKeyPressed {
            if km.commandKeyPressed, !display.blackOutEnabled, DC.activeDisplayCount > 1 {
                return "Ignore"
            }
            return "Show Help"
        }

        if display.blackOutEnabled {
            return "Power On"
        }

        if allowBlackOutOnSingleScreen, DC.activeDisplayCount == 1 {
            if km.optionKeyPressed {
                return display.hasDDC ? "Power Off" : "Needs DDC"
            }
            return "Darken"
        }

        if km.optionKeyPressed {
            if km.shiftKeyPressed {
                return "Focus"
            }
            return display.hasDDC ? "Power Off" : "Needs DDC"
        }

        if km.shiftKeyPressed {
            return "Darken"
        }

        #if arch(arm64)
            if #available(macOS 13, *), km.commandKeyPressed {
                return newBlackOutDisconnect ? "BlackOut" : "Disconnect"
            }

            return newBlackOutDisconnect ? "Disconnect" : "BlackOut"
        #else
            return "BlackOut"
        #endif
    }

    var color: Color {
        if poweringOff.value || display.blackOutEnabled {
            return Color.gray
        }

        if km.controlKeyPressed {
            return Color.peach
        }

        if DC.activeDisplayCount == 1 {
            return Color.dynamicRed
        }

        if km.optionKeyPressed, !km.shiftKeyPressed, !display.hasDDC {
            return Color.gray
        }
        return Color.dynamicRed
    }

    var body: some View {
        HStack(spacing: 2) {
            SwiftUI.Button(action: {
                if km.controlKeyPressed, km.commandKeyPressed, DC.activeDisplayCount > 1 {
                    display.unmanaged = true
                    return
                }

                guard !KM.controlKeyPressed,
                      lunarProActive || lunarProOnTrial || (KM.optionKeyPressed && !KM.shiftKeyPressed)
                else {
                    showPopover = true
                    return
                }

                guard neverShowBlackoutPopover else {
                    showPopover = true
                    return
                }

                poweringOff.set(true, expireAfter: 1)
                if display.blackOutEnabled {
                    display.powerOn()
                } else {
                    display.powerOff()
                }
            }) {
                Image(systemName: "power").font(.system(size: 10, weight: .heavy))
            }

            .buttonStyle(FlatButton(
                color: color,
                circle: true,
                horizontalPadding: 3,
                verticalPadding: 3
            ))
            .popover(isPresented: $showPopover) {
                BlackoutPopoverView(hasDDC: display.hasDDC).onDisappear {
                    if !neverShowBlackoutPopover {
                        neverShowBlackoutPopover = true
                    }
                }
            }
            .onHover { h in withAnimation { hovering = h } }
            .disabled((km.optionKeyPressed && !km.shiftKeyPressed && !display.hasDDC) || poweringOff.value)

            Text(actionText)
                .font(.system(size: 10, weight: .semibold))
                .opacity(hovering ? 1 : 0)
        }
        .frame(width: 100, alignment: .leading)
    }
}
