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
    font-family: 'SF Compact Text', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen-Sans, Ubuntu, Cantarell, 'Helvetica Neue', Helvetica, Arial, sans-serif;
}

ul, ol {
    margin-bottom: 10px;
}

a {
    margin-bottom: 1px;
    margin-top: 1px;
}

h1, h2 {
    padding-top: 10px;
    margin-bottom: 8px;
    font-family: Menlo, monospace;
    font-weight: bold;
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

class HelpButton: NSButton {
    var link: String?
    var trackingArea: NSTrackingArea!
    var buttonShadow: NSShadow!

    @IBInspectable var helpText: String = ""

    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?

    func getParsedHelpText() -> NSAttributedString? {
        guard let popover = helpPopover else { return nil }
        let down = Down(markdownString: helpText)

        do {
            return try down.toAttributedString(.default, stylesheet: popover.appearance?.name == NSAppearance.Name.vibrantDark ? DARK_STYLESHEET : STYLESHEET)
        } catch {
            log.error("Markdown error: \(error)")
            return nil
        }
    }

    func setup() {
        let buttonSize = frame
        wantsLayer = true

        setFrameSize(NSSize(width: buttonSize.width, height: buttonSize.width))
        layer?.cornerRadius = frame.width / 2
        layer?.backgroundColor = .clear
        alphaValue = 0.2

        buttonShadow = shadow
        shadow = nil

        trackingArea = NSTrackingArea(rect: visibleRect, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseDown(with _: NSEvent) {
        guard let popover = helpPopover else { return }

        if popover.isShown {
            popover.close()
            return
        }

        if let c = popover.contentViewController as? HelpPopoverController, !helpText.isEmpty, let parsedHelpText = getParsedHelpText() {
            c.helpTextField?.attributedStringValue = parsedHelpText
            if let link = self.link {
                c.onClick = {
                    if let url = URL(string: link) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            popover.show(relativeTo: visibleRect, of: self, preferredEdge: .maxY)
            popover.becomeFirstResponder()
        }
    }

    override func mouseEntered(with _: NSEvent) {
        if !isEnabled { return }

        layer?.add(fadeTransition(duration: 0.1), forKey: "transition")
        alphaValue = 0.7
        shadow = buttonShadow

        onMouseEnter?()
    }

    override func mouseExited(with _: NSEvent) {
        if !isEnabled { return }

        layer?.add(fadeTransition(duration: 0.2), forKey: "transition")
        alphaValue = 0.2
        shadow = nil

        onMouseExit?()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
