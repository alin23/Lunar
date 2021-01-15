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
let green = #colorLiteral(red: 0.3294117647, green: 0.8274509804, blue: 0.5058823529, alpha: 1)
let blue = #colorLiteral(red: 0.0862745098, green: 0.4823529412, blue: 1, alpha: 1)
let red = #colorLiteral(red: 0.9490196078, green: 0.2, blue: 0.262745098, alpha: 1)
let gray = #colorLiteral(red: 0.9254902005, green: 0.9294117689, blue: 0.9450980425, alpha: 1)
let white = NSColor(deviceWhite: 1.0, alpha: 1.0)

let bgColor = white
let hotkeysBgColor = darkMauve
let settingsBgColor = lunarYellow
let logoColor = lunarYellow
let settingsDividerColor = white.withAlphaComponent(0.3)

let scrollableTextFieldCaptionColor = mauve.withAlphaComponent(0.7)

let scrollableTextFieldColor = lunarYellow.shadow(withLevel: 0.05) ?? lunarYellow
let scrollableTextFieldColorHover = lunarYellow.highlight(withLevel: 0.1) ?? lunarYellow
let scrollableTextFieldColorLight = lunarYellow.highlight(withLevel: 0.3) ?? lunarYellow

let scrollableTextFieldColorWhite = white
let scrollableTextFieldColorHoverWhite = mauve.withAlphaComponent(0.7)
let scrollableTextFieldColorLightWhite = mauve.withAlphaComponent(0.9)

let scrollableCaptionColorWhite = mauve.withAlphaComponent(0.5)

let scrollableViewLabelColor = mauve.withAlphaComponent(0.35)

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

let lockButtonBgOn = red.withAlphaComponent(0.8)
let lockButtonBgOnHover = lockButtonBgOn.highlight(withLevel: 0.2) ?? lockButtonBgOn
let lockButtonLabelOn = white
let lockButtonBgOff = gray.withAlphaComponent(0.8)
let lockButtonBgOffHover = lockButtonBgOn.highlight(withLevel: 0.4) ?? lockButtonBgOn
let lockButtonLabelOff = mauve.withAlphaComponent(0.45)

let currentPageIndicatorTintColor = lunarYellow.withAlphaComponent(0.35)
let pageIndicatorTintColor = mauve.withAlphaComponent(0.15)

let hotkeyColor: [HoverState: [String: NSColor]] = [
    .hover: [
        "background": white.withAlphaComponent(0.4),
        "tint": lunarYellow,
        "tintDisabled": white.withAlphaComponent(0.9),
        "tintRecording": red.highlight(withLevel: 0.4) ?? red,
    ],
    .noHover: [
        "background": white.withAlphaComponent(0.3),
        "tint": lunarYellow.withAlphaComponent(0.9),
        "tintDisabled": white.withAlphaComponent(0.7),
        "tintRecording": red.highlight(withLevel: 0.4) ?? red,
    ],
]
let offStateButtonLabelColor: [HoverState: [Page: NSColor]] = [
    .hover: [
        .hotkeys: mauve,
        .settings: lunarYellow,
        .display: mauve,
    ],
    .noHover: [
        .hotkeys: white,
        .settings: mauve.withAlphaComponent(0.7),
        .display: mauve.withAlphaComponent(0.35),
    ],
]
let onStateButtonLabelColor: [HoverState: [Page: NSColor]] = [
    .hover: [
        .hotkeys: mauve,
        .settings: lunarYellow,
        .display: mauve,
    ],
    .noHover: [
        .hotkeys: white,
        .settings: white,
        .display: mauve.withAlphaComponent(0.35),
        .displayBrightnessRange: mauve,
        .displayAlgorithm: mauve,
    ],
]

let offStateButtonColor: [HoverState: [Page: NSColor]] = [
    .hover: [
        .hotkeys: lunarYellow.withAlphaComponent(0.9),
        .settings: mauve.withAlphaComponent(0.5),
        .display: lunarYellow,
        .displayBrightnessRange: green.withAlphaComponent(0.8),
        .displayAlgorithm: lunarYellow.withAlphaComponent(0.8),
    ],
    .noHover: [
        .hotkeys: lunarYellow.withAlphaComponent(0.3),
        .settings: white.withAlphaComponent(0.3),
        .display: gray,
        .displayBrightnessRange: gray.withAlphaComponent(0.8),
        .displayAlgorithm: gray.withAlphaComponent(0.8),
    ],
]

let onStateButtonColor: [HoverState: [Page: NSColor]] = [
    .hover: [
        .hotkeys: lunarYellow.withAlphaComponent(0.9),
        .settings: mauve,
        .display: lunarYellow,
        .displayBrightnessRange: red.withAlphaComponent(0.8),
        .displayAlgorithm: red.withAlphaComponent(0.8),
    ],
    .noHover: [
        .hotkeys: lunarYellow.withAlphaComponent(0.3),
        .settings: mauve.withAlphaComponent(0.6),
        .display: gray,
        .displayBrightnessRange: green.withAlphaComponent(0.8),
        .displayAlgorithm: lunarYellow.withAlphaComponent(0.8),
    ],
]

let buttonDotColor: [AdaptiveModeKey: NSColor] = [
    .sync: green,
    .location: lunarYellow,
    .manual: red,
    .sensor: blue,
]

let xColor = red
let removeButtonColor = red.highlight(withLevel: 0.3) ?? red

let contrastGraphColor = lunarYellow
let brightnessGraphColor = violet
let xAxisLabelColor = mauve.withAlphaComponent(0.5)

let contrastGraphColorYellow = white
let brightnessGraphColorYellow = lunarYellow.shadow(withLevel: 0.3) ?? lunarYellow
let xAxisLabelColorYellow = NSColor.black.withAlphaComponent(0.5)
