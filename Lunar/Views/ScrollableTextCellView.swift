//
//  ScrollableTextCellView.swift
//  Lunar
//
//  Created by Alin on 16/04/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

class ScrollableTextCellView: NSTableCellView {
    @IBOutlet weak var scrollableField: ScrollableTextField!
    @IBOutlet weak var scrollableCaption: ScrollableTextFieldCaption!
}
