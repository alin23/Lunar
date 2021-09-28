//
//  Theme.swift
//  Lunar
//
//  Created by Alin on 26/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

let mauve = #colorLiteral(red: 0.1921568627, green: 0.1647058824, blue: 0.2980392157, alpha: 1)
let darkMauve = #colorLiteral(red: 0.1529411765, green: 0.1411764706, blue: 0.1921568627, alpha: 1)
let violet = #colorLiteral(red: 0.2431372553, green: 0.2431372553, blue: 0.4392156899, alpha: 1)
let lunarYellow = #colorLiteral(red: 1, green: 0.8352941275, blue: 0.5254902244, alpha: 1)
let sunYellow = #colorLiteral(red: 0.9921568627, green: 0.7921568627, blue: 0.2274509804, alpha: 1)
let orange = #colorLiteral(red: 1, green: 0.6532859206, blue: 0.4175746441, alpha: 1)
let peach = #colorLiteral(red: 0.9982646108, green: 0.7837697268, blue: 0.5843595266, alpha: 1)
let green = #colorLiteral(red: 0.3294117647, green: 0.8274509804, blue: 0.5058823529, alpha: 1)
let blue = #colorLiteral(red: 0.0862745098, green: 0.4823529412, blue: 1, alpha: 1)
let red = #colorLiteral(red: 0.9490196078, green: 0.2, blue: 0.262745098, alpha: 1)
let errorRed = #colorLiteral(red: 0.968627451, green: 0, blue: 0.01568627451, alpha: 1)
let dullRed = #colorLiteral(red: 0.8352941275, green: 0.3647058904, blue: 0.360784322, alpha: 1)
let gray = #colorLiteral(red: 0.9254902005, green: 0.9294117689, blue: 0.9450980425, alpha: 1)
let white = NSColor(deviceWhite: 1.0, alpha: 1.0)
let faceLightColor = white.blended(withFraction: 0.15, of: orange) ?? white

let bgColor = white
let hotkeysBgColor = darkMauve
let settingsBgColor = lunarYellow
let logoColor = lunarYellow
let settingsDividerColor = white.withAlphaComponent(0.3)

var darkMode: Bool {
    appDelegate?.darkMode ?? false
}

var dropdownArrowColor: NSColor { darkMode ? white.withAlphaComponent(0.7) : orange.withAlphaComponent(0.7) }
var dropdownArrowSecondaryColor: NSColor { darkMode ? white.withAlphaComponent(0.7) : mauve.withAlphaComponent(0.5) }

var scrollableTextFieldCaptionColor: NSColor { darkMode ? white.withAlphaComponent(0.7) : mauve.withAlphaComponent(0.7) }

var scrollableTextFieldColor: NSColor { darkMode ? lunarYellow : lunarYellow.shadow(withLevel: 0.05) ?? lunarYellow }
var scrollableTextFieldColorHover: NSColor { darkMode ? orange : lunarYellow.highlight(withLevel: 0.1) ?? lunarYellow }
var scrollableTextFieldColorLight: NSColor { darkMode ? white : lunarYellow.highlight(withLevel: 0.3) ?? lunarYellow }

let scrollableTextFieldColorWhite = white
let scrollableTextFieldColorHoverWhite = mauve.withAlphaComponent(0.7)
let scrollableTextFieldColorLightWhite = mauve.withAlphaComponent(0.9)

let scrollableCaptionColorWhite = mauve.withAlphaComponent(0.5)

let scrollableTextFieldColorOnBlack = sunYellow
let scrollableTextFieldColorHoverOnBlack = lunarYellow
let scrollableTextFieldColorLightOnBlack = white
let scrollableCaptionColorOnBlack = white

var scrollableViewLabelColor: NSColor { darkMode ? white.withAlphaComponent(0.9) : mauve.withAlphaComponent(0.35) }

// MARK: - ButtonColor

enum ButtonColor: Int {
    case bgOn
    case bgOnHover
    case bgOff
    case bgOffHover
    case labelOn
    case labelOnHover
    case labelOff
    case labelOffHover
}

var lockButtonBgOn: NSColor { darkMode ? red.withAlphaComponent(0.8) : red.withAlphaComponent(0.8) }
var lockButtonLabelOn: NSColor { darkMode ? white : white }
var lockButtonBgOff: NSColor { darkMode ? lunarYellow.withAlphaComponent(0.4) : gray.withAlphaComponent(0.8) }
var lockButtonLabelOff: NSColor { darkMode ? white.withAlphaComponent(0.75) : mauve.withAlphaComponent(0.45) }

var enableButtonBgOn: NSColor { darkMode ? sunYellow.withAlphaComponent(0.8) : lunarYellow }
var enableButtonLabelOn: NSColor { darkMode ? darkMauve : darkMauve.withAlphaComponent(0.8) }
var enableButtonBgOff: NSColor { darkMode ? lunarYellow.withAlphaComponent(0.4) : gray }
var enableButtonLabelOff: NSColor { darkMode ? white.withAlphaComponent(0.5) : mauve.withAlphaComponent(0.45) }

let hotkeyColor: [HoverState: [String: NSColor]] = [
    .hover: [
        "background": white.withAlphaComponent(0.4),
        "tint": lunarYellow,
        "tintDisabled": white.withAlphaComponent(0.4),
        "tintRecording": red.highlight(withLevel: 0.4) ?? red,
    ],
    .noHover: [
        "background": white.withAlphaComponent(0.3),
        "tint": lunarYellow.withAlphaComponent(0.9),
        "tintDisabled": white.withAlphaComponent(0.4),
        "tintRecording": red.highlight(withLevel: 0.4) ?? red,
    ],
]
let offStateButtonLabelColor: [HoverState: [Page: NSColor]] = [
    .hover: [
        .hotkeys: mauve,
        .settings: lunarYellow,
        .display: mauve,

        .hotkeysReset: white,
        .displayReset: white,
        .settingsReset: white,
    ],
    .noHover: [
        .hotkeys: white,
        .settings: mauve.withAlphaComponent(0.7),
        .display: mauve.withAlphaComponent(0.55),

        .hotkeysReset: white.withAlphaComponent(0.8),
        .settingsReset: mauve.withAlphaComponent(0.7),
        .displayReset: mauve.withAlphaComponent(0.55),
    ],
]
let onStateButtonLabelColor: [HoverState: [Page: NSColor]] = [
    .hover: [
        .hotkeys: mauve,
        .settings: lunarYellow,
        .display: mauve,

        .hotkeysReset: mauve,
        .settingsReset: lunarYellow,
        .displayReset: mauve,
    ],
    .noHover: [
        .hotkeys: white,
        .settings: white,
        .display: mauve.withAlphaComponent(0.55),

        .hotkeysReset: white,
        .settingsReset: white,
        .displayReset: darkMauve,

        .displayBrightnessRange: mauve,
        .displayAlgorithm: mauve,
    ],
]

let offStateButtonColor: [HoverState: [Page: NSColor]] = [
    .hover: [
        .hotkeys: lunarYellow.withAlphaComponent(0.9),
        .settings: mauve.withAlphaComponent(0.5),
        .display: lunarYellow,

        .hotkeysReset: red,
        .settingsReset: red,
        .displayReset: red,

        .displayBrightnessRange: green.withAlphaComponent(0.8),
        .displayAlgorithm: lunarYellow.withAlphaComponent(0.8),
    ],
    .noHover: [
        .hotkeys: lunarYellow.withAlphaComponent(0.3),
        .settings: white.withAlphaComponent(0.3),
        .display: gray,

        .hotkeysReset: red.withAlphaComponent(0.4),
        .settingsReset: white.withAlphaComponent(0.2),
        .displayReset: gray.withAlphaComponent(0.6),

        .displayBrightnessRange: gray.withAlphaComponent(0.8),
        .displayAlgorithm: gray.withAlphaComponent(0.8),
    ],
]

let onStateButtonColor: [HoverState: [Page: NSColor]] = [
    .hover: [
        .hotkeys: lunarYellow.withAlphaComponent(0.9),
        .settings: mauve,
        .display: lunarYellow,

        .hotkeysReset: lunarYellow.withAlphaComponent(0.9),
        .settingsReset: red.withAlphaComponent(0.8),
        .displayReset: red.withAlphaComponent(0.8),

        .displayBrightnessRange: red.withAlphaComponent(0.8),
        .displayAlgorithm: red.withAlphaComponent(0.8),
    ],
    .noHover: [
        .hotkeys: lunarYellow.withAlphaComponent(0.3),
        .settings: mauve.withAlphaComponent(0.6),
        .display: gray,

        .hotkeysReset: lunarYellow.withAlphaComponent(0.3),
        .settingsReset: red.withAlphaComponent(0.8),
        .displayReset: red.withAlphaComponent(0.8),

        .displayBrightnessRange: green.withAlphaComponent(0.8),
        .displayAlgorithm: lunarYellow.withAlphaComponent(0.8),
    ],
]

let buttonDotColor: [AdaptiveModeKey: NSColor] = [
    .sync: green,
    .location: lunarYellow,
    .manual: red,
    .sensor: blue,
    .clock: orange,
]

let xColor = red
let removeButtonColor = red.highlight(withLevel: 0.3) ?? red

let contrastGraphColor = lunarYellow
let brightnessGraphColor = violet
var xAxisLabelColor: NSColor { darkMode ? white.withAlphaComponent(0.6) : mauve.withAlphaComponent(0.5) }

let contrastGraphColorYellow = white
let brightnessGraphColorYellow = lunarYellow.shadow(withLevel: 0.3) ?? lunarYellow
let xAxisLabelColorYellow = NSColor.black.withAlphaComponent(0.5)
