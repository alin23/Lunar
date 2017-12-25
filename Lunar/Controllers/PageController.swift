//
//  PageController.swift
//  Lunar
//
//  Created by Alin on 30/11/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Foundation
import NSPageControl

class PageController: NSPageController, NSPageControllerDelegate {
    @IBOutlet var userDefaultsController: NSUserDefaultsController!
    var pageControl = NSPageControl()
    override var arrangedObjects: [Any] {
        didSet {
            pageControl.numberOfPages = arrangedObjects.count
        }
    }
    
    override var selectedIndex: Int {
        didSet {
            pageControl.currentPage = selectedIndex
        }
    }
    
    private func setupPageControl(_ selectedIndex: Int) {
        let width: CGFloat = 200
        let x: CGFloat = (view.frame.width - width) / 2
        pageControl.frame = CGRect(x: x, y: 20, width: 200, height: 20)
        pageControl.currentPageIndicatorTintColor = #colorLiteral(red: 1, green: 0.8625625372, blue: 0.594591558, alpha: 1)
        pageControl.pageIndicatorTintColor = #colorLiteral(red: 0.262745098, green: 0.2901960784, blue: 0.368627451, alpha: 0.1979258363)
        pageControl.hidesForSinglePage = true
        view.addSubview(pageControl)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        setupPageControl(selectedIndex)
        if !brightnessAdapter.displays.isEmpty {
            arrangedObjects = brightnessAdapter.displays.values.sorted(by: { (d1, d2) -> Bool in
                d1.active && !d2.active
            })
        } else {
            arrangedObjects = [GENERIC_DISPLAY]
        }
        selectedIndex = 0
        
    }
    func pageController(_ pageController: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier {
        return NSPageController.ObjectIdentifier(String(describing: (object as! Display).id))
    }
    
    func pageController(_ pageController: NSPageController, viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier) -> NSViewController {
        let vc = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle:nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "displayViewController")) as! DisplayViewController
        let displayId = CGDirectDisplayID(identifier.rawValue)!
        if displayId != GENERIC_DISPLAY.id {
            vc.display = brightnessAdapter.displays[displayId]
        } else {
            vc.display = GENERIC_DISPLAY
        }
        return vc
    }
    
    override func scrollWheel(with event: NSEvent) {
        let lastIndex = arrangedObjects.count - 1
        if arrangedObjects.count > 1 && ((selectedIndex < lastIndex && event.scrollingDeltaX < 0) || (selectedIndex == lastIndex && event.scrollingDeltaX > 0)) {
            super.scrollWheel(with: event)
        }
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}

