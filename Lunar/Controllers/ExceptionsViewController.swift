//
//  ExceptionsViewController.swift
//  Lunar
//
//  Created by Alin on 29/01/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Cocoa

class ExceptionsViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet var arrayController: NSArrayController!
    @IBOutlet weak var brightnessColumn: NSTableColumn!
    @IBOutlet weak var contrastColumn: NSTableColumn!
    
    func setup() {
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        arrayController.managedObjectContext = datastore.context
        tableView.headerView = nil
    }
    
}
