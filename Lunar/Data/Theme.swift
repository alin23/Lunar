//
//  Theme.swift
//  Lunar
//
//  Created by Alin on 26/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

let mauve = #colorLiteral(red: 0.1921568627, green: 0.1647058824, blue: 0.2980392157, alpha: 1)
let violet = #colorLiteral(red: 0.2431372553, green: 0.2431372553, blue: 0.4392156899, alpha: 1)
let lunarYellow = #colorLiteral(red: 1, green: 0.8352941275, blue: 0.5254902244, alpha: 1)
let green = #colorLiteral(red: 0.3294117647, green: 0.8274509804, blue: 0.5058823529, alpha: 1)
let red = #colorLiteral(red: 0.9490196078, green: 0.2, blue: 0.262745098, alpha: 1)
let gray = #colorLiteral(red: 0.9254902005, green: 0.9294117689, blue: 0.9450980425, alpha: 1)
let white = NSColor(deviceWhite: 1.0, alpha: 1.0)

let bgColor = white
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

let adaptiveButtonBgOn = lunarYellow
let adaptiveButtonBgOnHover = lunarYellow.highlight(withLevel: 0.2)!
let adaptiveButtonLabelOn = mauve
let adaptiveButtonBgOff = gray
let adaptiveButtonBgOffHover = lunarYellow
let adaptiveButtonLabelOff = mauve.withAlphaComponent(0.25)

let currentPageIndicatorTintColor = lunarYellow.withAlphaComponent(0.35)
let pageIndicatorTintColor = mauve.withAlphaComponent(0.15)

let stateButtonLabelColorDisplay = mauve.withAlphaComponent(0.25)
let stateButtonLabelColorHoverDisplay = mauve
let stateButtonColorDisplay = gray
let stateButtonColorHoverDisplay = lunarYellow

let stateButtonLabelColorSettings = mauve.withAlphaComponent(0.7)
let stateButtonLabelColorHoverSettings = lunarYellow
let stateButtonColorSettings = white.withAlphaComponent(0.3)
let stateButtonColorHoverSettings = mauve.withAlphaComponent(0.5)

var stateButtonLabelColor = stateButtonLabelColorDisplay
var stateButtonLabelColorHover = stateButtonLabelColorHoverDisplay
var stateButtonColor = stateButtonColorDisplay
var stateButtonColorHover = stateButtonColorHoverDisplay

let onButtonColor = green
let offButtonColor = red

let xColor = red
let removeButtonColor = red.highlight(withLevel: 0.3)!

let contrastGraphColor = lunarYellow
let brightnessGraphColor = violet
let xAxisLabelColor = mauve.withAlphaComponent(0.5)

let contrastGraphColorYellow = white
let brightnessGraphColorYellow = violet
let xAxisLabelColorYellow = NSColor.black.withAlphaComponent(0.5)
