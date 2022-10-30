//
//  HelpButton.swift
//  Lunar
//
//  Created by Alin on 14/06/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa
import SwiftyMarkdown

func getMD(dark: Bool = false, stylize: ((SwiftyMarkdown) -> Void)? = nil) -> SwiftyMarkdown {
    let md = SwiftyMarkdown(string: "")

    md.h1.fontSize = 24
    md.h2.fontSize = 22
    md.h3.fontSize = 20
    md.h4.fontSize = 18
    md.h5.fontSize = 17
    md.h6.fontSize = 15

    md.body.fontSize = 14
    md.bold.fontSize = 14
    md.italic.fontSize = 13

    md.h1.fontName = "Menlo-Bold"
    md.h2.fontName = "Menlo-Bold"
    md.h3.fontName = "Menlo-Bold"
    md.h4.fontName = "Menlo-Bold"
    md.h5.fontName = "SFCompactText-Bold"
    md.h6.fontName = "SFCompactText-Bold"

    md.body.fontName = "SFCompactText-Regular"

    md.bold.fontName = "SFCompactText-Bold"

    md.italic.fontName = "SFCompactText-MediumItalic"
    if dark {
        md.italic.color = lunarYellow
    } else {
        md.italic.color = violet
    }

    md.code.fontName = "Menlo-Bold"
    md.code.color = red

    stylize?(md)
    return md
}

let MD: SwiftyMarkdown = getMD()
let DARK_MD: SwiftyMarkdown = getMD(dark: true)
var MARKDOWN: SwiftyMarkdown { darkMode ? DARK_MD : MD }

let MENU_MD: SwiftyMarkdown = getMD { md in
    md.body.fontSize = 13
    md.bold.fontSize = 13
    md.italic.fontSize = 13
    md.code.fontSize = 12
    md.code.color = .tertiaryLabelColor
}

let MENU_DARK_MD: SwiftyMarkdown = getMD(dark: true) { md in
    md.body.fontSize = 13
    md.bold.fontSize = 13
    md.italic.fontSize = 13
    md.code.fontSize = 12
    md.code.color = .tertiaryLabelColor
}

var MENU_MARKDOWN: SwiftyMarkdown { darkMode ? MENU_DARK_MD : MENU_MD }

// MARK: - OnboardingHelpButton

class OnboardingHelpButton: HelpButton {
    let md: SwiftyMarkdown = {
        let md = getMD(dark: true)
        md.body.fontSize = 15
        md.bold.fontSize = 15
        md.italic.fontSize = 15
        md.code.fontSize = 15
        md.link.fontSize = 15

        md.code.color = sunYellow
        md.bold.color = peach

        return md
    }()

    override func getParsedHelpText() -> NSAttributedString? {
        md.attributedString(from: helpText)
    }

    override func mouseDown(with event: NSEvent) {
        popover?.appearance = NSAppearance(named: .vibrantDark)
        super.mouseDown(with: event)
    }

    override func open(edge: NSRectEdge = .maxY) {
        setParsedHelpText()
        popover?.appearance = NSAppearance(named: .vibrantDark)
        super.open(edge: edge)
    }
}

// MARK: - HelpButton

class HelpButton: PopoverButton<HelpPopoverController> {
    var link: String?

    @IBInspectable var helpText = ""

    override var popoverKey: String {
        "help"
    }

    func getParsedHelpText() -> NSAttributedString? {
        guard let popover = POPOVERS[popoverKey]! else { return nil }

        let md = (popover.appearance == nil || popover.appearance!.name == .vibrantLight) ? MD : DARK_MD
        return md.attributedString(from: helpText)
    }

    func setParsedHelpText() {
        if !helpText.isEmpty,
           let parsedHelpText = getParsedHelpText(),
           let c = popoverController
        {
            c.helpTextField?.attributedStringValue = parsedHelpText
            if let link {
                c.onClick = {
                    if let url = URL(string: link) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        setParsedHelpText()
        super.mouseDown(with: event)
    }
}
