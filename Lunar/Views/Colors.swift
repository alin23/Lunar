import AppKit
import Cocoa
import Foundation
import SwiftUI

let XDR_BLUE = Color.xdr
let SUBZERO_RED = Color.subzero

public struct FG {
    var gray: Color {
        if #available(macOS 12.0, *) {
            Color(light: Color.darkGray, dark: Color.lightGray)
        } else {
            NSAppearance.currentDrawing().isDark ? Color.lightGray : Color.darkGray
        }
    }
    var primary: Color {
        if #available(macOS 12.0, *) {
            Color(light: Color.black, dark: Color.white)
        } else {
            NSAppearance.currentDrawing().isDark ? Color.white : Color.black
        }
    }
    var warm: Color {
        if #available(macOS 12.0, *) {
            Color(light: Color.warmBlack, dark: Color.warmWhite)
        } else {
            NSAppearance.currentDrawing().isDark ? Color.warmWhite : Color.warmBlack
        }
    }
}

// MARK: - BG

public struct BG {
    var gray: Color {
        if #available(macOS 12.0, *) {
            Color(light: Color.darkGray, dark: Color.lightGray)
        } else {
            NSAppearance.currentDrawing().isDark ? Color.lightGray : Color.darkGray
        }
    }
    var primary: Color {
        if #available(macOS 12.0, *) {
            Color(light: Color.white, dark: Color.black)
        } else {
            NSAppearance.currentDrawing().isDark ? Color.black : Color.white
        }
    }
    var warm: Color {
        if #available(macOS 12.0, *) {
            Color(light: Color.warmWhite, dark: Color.warmBlack)
        } else {
            NSAppearance.currentDrawing().isDark ? Color.warmBlack : Color.warmWhite
        }
    }
}

public extension Color {
    var ns: NSColor { NSColor(self) }

    static var translucid: Color { Color.fg.warm.opacity(0.05) }
    static var translucidDark: Color { Color.bg.warm.opacity(0.05) }

    static let darkGray = Color(hue: 0, saturation: 0.01, brightness: 0.32)
    static let blackGray = Color(hue: 0.03, saturation: 0.12, brightness: 0.18)
    static let lightGray = Color(hue: 0, saturation: 0.0, brightness: 0.92)

    static let warmWhite = Color(hue: 20, saturation: 0.07, brightness: 0.95)
    static let warmBlack = Color(hue: 20, saturation: 0.15, brightness: 0.18)

    static let hotRed = Color(hue: 0.98, saturation: 0.82, brightness: 1.00)
    static let pinkishRed = Color(hue: 0.96, saturation: 0.86, brightness: 0.98)
    static let lightGold = Color(hue: 0.09, saturation: 0.28, brightness: 0.94)

    static let scarlet = Color(hue: 0.98, saturation: 0.82, brightness: 1.00)
    static let saffron = Color(hue: 0.11, saturation: 0.82, brightness: 1.00)

    static let lightMauve = Color(hue: 0.95, saturation: 0.39, brightness: 0.93)
    static let grayMauve = Color(hue: 252 / 360, saturation: 0.29, brightness: 0.43)
    static let mauve = Color(hue: 252 / 360, saturation: 0.29, brightness: 0.23)
    static let pinkMauve = Color(hue: 0.95, saturation: 0.76, brightness: 0.42)
    static let blackMauve = Color(hue: 252 / 360, saturation: 0.08, brightness: 0.12)
    static let golden = Color(hue: 39 / 360, saturation: 1.0, brightness: 0.64)
    static let sunYellow = Color(hue: 0.1, saturation: 0.57, brightness: 1.00)
    static let peach = Color(hue: 0.08, saturation: 0.42, brightness: 1.00)
    static let calmBlue = Color(hue: 214 / 360, saturation: 0.7, brightness: 0.84)
    static let calmGreen = Color(hue: 0.36, saturation: 0.80, brightness: 0.78)
    static let lightGreen = Color(hue: 141 / 360, saturation: 0.50, brightness: 0.83)

    static let xdr = Color(hue: 0.61, saturation: 0.26, brightness: 0.78)
    static let subzero = Color(hue: 0.98, saturation: 0.56, brightness: 1.00)

    static let bg = BG()
    static let fg = FG()

    static var dynamicRed: Color {
        if #available(macOS 12.0, *) {
            Color(light: Color.hotRed, dark: Color.pinkishRed)
        } else {
            NSAppearance.currentDrawing().isDark ? Color.pinkishRed : Color.hotRed
        }
    }
    static var highContrast: Color {
        if #available(macOS 12.0, *) {
            Color(light: Color.black, dark: Color.white)
        } else {
            NSAppearance.currentDrawing().isDark ? Color.white : Color.black
        }
    }
    static var invertedGray: Color {
        if #available(macOS 12.0, *) {
            Color(light: Color.lightGray, dark: Color.darkGray)
        } else {
            NSAppearance.currentDrawing().isDark ? Color.darkGray : Color.lightGray
        }
    }
    static var dynamicGray: Color {
        if #available(macOS 12.0, *) {
            Color(light: Color.darkGray, dark: Color.lightGray)
        } else {
            NSAppearance.currentDrawing().isDark ? Color.lightGray : Color.darkGray
        }
    }
    static var mauvish: Color {
        if #available(macOS 12.0, *) {
            Color(light: Color.pinkMauve, dark: Color.lightMauve)
        } else {
            NSAppearance.currentDrawing().isDark ? Color.lightMauve : Color.pinkMauve
        }
    }
    static var dynamicYellow: Color {
        if #available(macOS 12.0, *) {
            Color(light: .lunarYellow, dark: .peach)
        } else {
            NSAppearance.currentDrawing().isDark ? Color.peach : Color.lunarYellow
        }
    }
}

@available(macOS 12.0, *)
public extension Color {
    init(light: Color, dark: Color) {
        self.init(light: NSColor(light), dark: NSColor(dark))
    }

    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            switch appearance.name {
            case .aqua,
                 .vibrantLight,
                 .accessibilityHighContrastAqua,
                 .accessibilityHighContrastVibrantLight:
                return light

            case .darkAqua,
                 .vibrantDark,
                 .accessibilityHighContrastDarkAqua,
                 .accessibilityHighContrastVibrantDark:
                return dark

            default:
                assertionFailure("Unknown appearance: \(appearance.name)")
                return light
            }
        }))
    }
}
