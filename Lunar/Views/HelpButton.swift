//
//  HelpButton.swift
//  Lunar
//
//  Created by Alin on 14/06/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa
import SwiftyMarkdown

func getMD(dark: Bool = false) -> SwiftyMarkdown {
    let md = SwiftyMarkdown(string: "")

    md.h1.fontSize = 24
    md.h2.fontSize = 22
    md.h3.fontSize = 20
    md.h4.fontSize = 18
    md.h5.fontSize = 17
    md.h6.fontSize = 15

    md.h1.fontName = "Menlo-Bold"
    md.h2.fontName = "Menlo-Bold"
    md.h3.fontName = "Menlo-Bold"
    md.h4.fontName = "Menlo-Bold"
    md.h5.fontName = "SFCompactText-Bold"
    md.h6.fontName = "SFCompactText-Bold"

    md.body.fontName = "SFCompactText-Regular"
    md.body.fontSize = 14

    md.bold.fontName = "SFCompactText-Bold"
    md.bold.fontSize = 14

    md.italic.fontName = "SFCompactText-MediumItalic"
    if dark {
        md.italic.color = lunarYellow
    } else {
        md.italic.color = violet
    }
    md.italic.fontSize = 13

    md.code.fontName = "Menlo-Bold"
    md.code.color = red

    return md
}

let MD: SwiftyMarkdown = getMD()
let DARK_MD: SwiftyMarkdown = getMD(dark: true)

class HelpButton: PopoverButton<HelpPopoverController> {
    var link: String?

    override var popoverKey: String {
        "help"
    }

    @IBInspectable var helpText: String = ""

    func getParsedHelpText() -> NSAttributedString? {
        guard let popover = POPOVERS[popoverKey]! else { return nil }

        return MD.attributedString(from: helpText)
    }

    override func mouseDown(with event: NSEvent) {
        if !helpText.isEmpty,
           let parsedHelpText = getParsedHelpText(),
           let c = popoverController
        {
            c.helpTextField?.attributedStringValue = parsedHelpText
            if let link = self.link {
                c.onClick = {
                    if let url = URL(string: link) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        super.mouseDown(with: event)
    }
}
