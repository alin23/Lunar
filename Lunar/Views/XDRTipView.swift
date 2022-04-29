//
//  XDRTipView.swift
//  Lunar
//
//  Created by Alin Panaitiu on 29.04.2022.
//  Copyright © 2022 Alin. All rights reserved.
//

import Foundation
import FuzzyFind
import SwiftUI

// MARK: - XDRTipView

struct XDRTipView: View {
    var body: some View {
        PaddedPopoverView(background: AnyView(Color.white.brightness(0.05))) {
            HStack(spacing: 10) {
                VStack(spacing: 6) {
                    Image(systemName: "sun.max")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("F2")
                        .foregroundColor(.white)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.black.opacity(0.9)))
                .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 3)
                VStack(alignment: .leading, spacing: 0) {
                    Text("You can also enable XDR by pressing the Brightness Up key")
                        .foregroundColor(.black)
                        .font(.system(size: 14, weight: .regular))

                    Text("one more time after already reaching 100% brightness")
                        .foregroundColor(.black)
                        .font(.system(size: 14, weight: .regular))
                }
            }
        }
    }
}

// MARK: - XDRTipView_Previews

struct XDRTipView_Previews: PreviewProvider {
    static var previews: some View {
        XDRTipView()
    }
}
