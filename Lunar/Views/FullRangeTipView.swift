//
//  FullRangeTipView.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.04.2022.
//  Copyright © 2022 Alin. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - FullRangeTipView

struct FullRangeTipView: View {
    var body: some View {
        PaddedPopoverView(background: AnyView(Color.white.brightness(0.05))) {
            Text("Full Range XDR Brightness")
                .font(.title.bold())
            Text("""
            This option unlocks the full range of brightness so you can take advantage
            of the high power LEDs in your screen.

            It uses a different approach than the one used by the **XDR** button,
            with the following key differences:

              - It doesn't clip colors in HDR content
              - The system adaptive brightness keeps working
              - There's no lag when going from SDR to XDR brightness

            Downsides:

              - It only works on MacBook Pro XDR screens
              - The screen will flash one or two times when toggling it
            """)

            Text("""
            The system will still adapt the maximum nits of brightness based on the ambient
            light, so you might get a max of 800 nits in a dark room and 1600 nits in sunlight.

            Disabling the system adaptive brightness will turn off this behaviour.
            """)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .modifier(RoundBG(radius: 8, color: .black.opacity(0.1), shadowSize: 0))

            Text("*Note: you can always Ctrl-click this button to see this tip again*")
        }
    }
}

// MARK: - FullRangeTipView_Previews

struct FullRangeTipView_Previews: PreviewProvider {
    static var previews: some View {
        FullRangeTipView()
    }
}
