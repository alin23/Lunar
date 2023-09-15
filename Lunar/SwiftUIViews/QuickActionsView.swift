import SwiftUI

struct QuickActionsView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        QuickActionsMenuView(menuBarIcon: appDelegate!.statusItemButtonController!)
            .environmentObject(appDelegate!.env)
            .colors(colorScheme == .dark ? .dark : .light)
            .focusable(false)
    }
}
