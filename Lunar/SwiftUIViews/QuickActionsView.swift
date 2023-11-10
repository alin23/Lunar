import SwiftUI

struct QuickActionsView: View {
    var body: some View {
        QuickActionsMenuView(menuBarIcon: appDelegate!.statusItemButtonController!)
            .environmentObject(appDelegate!.env)
            .focusable(false)
    }
}
