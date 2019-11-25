//
//  Theme.swift
//  Lunar
//
//  Created by Alin on 26/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

let mauve = #colorLiteral(red: 0.1921568627, green: 0.1647058824, blue: 0.2980392157, alpha: 1)
let darkMauve = #colorLiteral(red: 0.1512770126, green: 0.14105705, blue: 0.1921568627, alpha: 1)
let violet = #colorLiteral(red: 0.2431372553, green: 0.2431372553, blue: 0.4392156899, alpha: 1)
let lunarYellow = #colorLiteral(red: 1, green: 0.8352941275, blue: 0.5254902244, alpha: 1)
let sunYellow = #colorLiteral(red: 0.991425693, green: 0.7912780643, blue: 0.2255264819, alpha: 1)
let green = #colorLiteral(red: 0.3294117647, green: 0.8274509804, blue: 0.5058823529, alpha: 1)
let red = #colorLiteral(red: 0.9490196078, green: 0.2, blue: 0.262745098, alpha: 1)
let gray = #colorLiteral(red: 0.9254902005, green: 0.9294117689, blue: 0.9450980425, alpha: 1)
let white = NSColor(deviceWhite: 1.0, alpha: 1.0)

let bgColor = white
let hotkeysBgColor = darkMauve
let settingsBgColor = lunarYellow
let logoColor = lunarYellow
let settingsDividerColor = white.withAlphaComponent(0.3)

let scrollableTextFieldCaptionColor = mauve.withAlphaComponent(0.7)
let adaptiveButtonLabelColor = mauve

let scrollableTextFieldColor = lunarYellow.shadow(withLevel: 0.05)!
let scrollableTextFieldColorHover = lunarYellow.highlight(withLevel: 0.1)!
let scrollableTextFieldColorLight = lunarYellow.highlight(withLevel: 0.3)!

let scrollableTextFieldColorWhite = white
let scrollableTextFieldColorHoverWhite = mauve.withAlphaComponent(0.7)
let scrollableTextFieldColorLightWhite = mauve.withAlphaComponent(0.9)

let scrollableCaptionColorWhite = mauve.withAlphaComponent(0.5)

let scrollableViewLabelColor = mauve.withAlphaComponent(0.35)

let adaptiveButtonBgOn = lunarYellow.withAlphaComponent(0.8)
let adaptiveButtonBgOnHover = adaptiveButtonBgOn.highlight(withLevel: 0.2)!
let adaptiveButtonLabelOn = mauve
let adaptiveButtonBgOff = gray.withAlphaComponent(0.8)
let adaptiveButtonBgOffHover = adaptiveButtonBgOn
let adaptiveButtonLabelOff = mauve.withAlphaComponent(0.25)

let lockButtonBgOn = red.withAlphaComponent(0.8)
let lockButtonBgOnHover = lockButtonBgOn.highlight(withLevel: 0.2)!
let lockButtonLabelOn = white
let lockButtonBgOff = gray.withAlphaComponent(0.8)
let lockButtonBgOffHover = lockButtonBgOn.highlight(withLevel: 0.4)!
let lockButtonLabelOff = mauve.withAlphaComponent(0.45)

let currentPageIndicatorTintColor = lunarYellow.withAlphaComponent(0.35)
let pageIndicatorTintColor = mauve.withAlphaComponent(0.15)

let hotkeyColor: [HoverState: [String: NSColor]] = [
    .hover: [
        "background": white.withAlphaComponent(0.4),
        "tint": lunarYellow,
        "tintDisabled": white.withAlphaComponent(0.9),
        "tintRecording": red.highlight(withLevel: 0.4)!,
    ],
    .noHover: [
        "background": white.withAlphaComponent(0.3),
        "tint": lunarYellow.withAlphaComponent(0.9),
        "tintDisabled": white.withAlphaComponent(0.7),
        "tintRecording": red.highlight(withLevel: 0.4)!,
    ],
]
let stateButtonLabelColor: [HoverState: [Page: NSColor]] = [
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
let stateButtonColor: [HoverState: [Page: NSColor]] = [
    .hover: [
        .hotkeys: lunarYellow.withAlphaComponent(0.9),
        .settings: mauve.withAlphaComponent(0.5),
        .display: lunarYellow,
    ],
    .noHover: [
        .hotkeys: lunarYellow.withAlphaComponent(0.3),
        .settings: white.withAlphaComponent(0.3),
        .display: gray,
    ],
]

let buttonDotColor: [AdaptiveMode: NSColor] = [
    .sync: green,
    .location: lunarYellow,
    .manual: red,
]

let xColor = red
let removeButtonColor = red.highlight(withLevel: 0.3)!

let contrastGraphColor = lunarYellow
let brightnessGraphColor = violet
let xAxisLabelColor = mauve.withAlphaComponent(0.5)

let contrastGraphColorYellow = white
let brightnessGraphColorYellow = lunarYellow.shadow(withLevel: 0.3)!
let xAxisLabelColorYellow = NSColor.black.withAlphaComponent(0.5)
