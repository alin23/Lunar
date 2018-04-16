//
//  ConfigurationViewController.swift
//  Lunar
//
//  Created by Alin on 16/04/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

class ConfigurationViewController: NSViewController {

    @IBOutlet weak var noonDurationField: ScrollableTextField!
    @IBOutlet weak var noonDurationCaption: ScrollableTextFieldCaption!
    
    @IBOutlet weak var daylightExtensionField: ScrollableTextField!
    @IBOutlet weak var daylightExtensionCaption: ScrollableTextFieldCaption!
    
    func setup() {
        noonDurationField.integerValue = datastore.defaults.noonDurationMinutes
        daylightExtensionField.integerValue = datastore.defaults.daylightExtensionMinutes
        
        noonDurationField?.onValueChanged = { (value: Int) in
            datastore.defaults.set(value, forKey: "noonDurationMinutes")
        }
        daylightExtensionField?.onValueChanged = { (value: Int) in
            datastore.defaults.set(value, forKey: "daylightExtensionMinutes")
        }
        
        noonDurationField?.caption = noonDurationCaption
        daylightExtensionField?.caption = daylightExtensionCaption
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
}
