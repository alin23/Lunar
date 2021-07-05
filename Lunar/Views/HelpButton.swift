//
//  HelpButton.swift
//  Lunar
//
//  Created by Alin on 14/06/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Cocoa
import Down

let STYLESHEET = """
p, ul, ol, li, a {
    font-family: 'SF Compact Text', -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Avenir, sans-serif;
    font-size: 14px;
}

ul, ol, li:last-child {
    margin-bottom: 10px;
}

div.spacer {
    margin-top: 1px;
    margin-bottom: 1px;
    width: 100%;
}

div.spacer.h1 {
    height: 1px;
}

div.spacer.h2 {
    height: 2px;
}

div.spacer.h3 {
    height: 3px;
}

div.spacer.h4 {
    height: 4px;
}

div.spacer.h5 {
    height: 5px;
}

div.spacer.h6 {
    height: 6px;
}

div.spacer.h7 {
    height: 7px;
}

div.spacer.h8 {
    height: 8px;
}

div.spacer.h9 {
    height: 9px;
}

div.spacer.h10 {
    height: 10px;
}

a {
    margin-bottom: 1px;
    margin-top: 1px;
}

h1 {
    font-size: 24px;
}
h2 {
    font-size: 22px;
}
h3 {
    font-size: 20px;
}
h4 {
    font-size: 18px;
}
h5 {
    font-size: 17px;
}
h6 {
    font-size: 15px;
}

h1, h2, h3, h4 {
    margin-top: 10px;
    margin-bottom: 8px;
    font-family: Menlo, monospace;
    font-weight: bold;
}

h3, h4 {
    margin-bottom: 4px;
}

pre, code {
    font-family: Menlo, monospace;
    color: hsl(345, 80%, 42%);
    font-weight: 600;
}
"""

let DARK_STYLESHEET = """
\(STYLESHEET)

p, ul, ol, li, a, h1, h2, h3, h4, h5, h6 {
    color: white !important;
}

pre, code {
    color: hsl(345, 100%, 62%);
}
"""

class HelpButton: PopoverButton<HelpPopoverController> {
    var link: String?

    override var popoverKey: String {
        "help"
    }

    @IBInspectable var helpText: String = ""

    func getParsedHelpText() -> NSAttributedString? {
        guard let popover = POPOVERS[popoverKey]! else { return nil }
        let down = Down(markdownString: helpText)

        do {
            return try down.toAttributedString(
                .smartUnsafe,
                stylesheet: popover.appearance?.name == NSAppearance.Name.vibrantDark ? DARK_STYLESHEET : STYLESHEET
            )
        } catch {
            log.error("Markdown error: \(error)")
            return nil
        }
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
