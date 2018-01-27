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
    var viewControllers: [NSPageController.ObjectIdentifier: DisplayViewController] = [:]
    
    private func setupPageControl(_ selectedIndex: Int) {
        let width: CGFloat = 200
        let x: CGFloat = (view.frame.width - width) / 2
        pageControl.frame = CGRect(x: x, y: 20, width: 200, height: 20)
        pageControl.currentPageIndicatorTintColor = currentPageIndicatorTintColor
        pageControl.pageIndicatorTintColor = pageIndicatorTintColor
        pageControl.hidesForSinglePage = true
        view.addSubview(pageControl)
    }
    
    func deleteDisplay() {
        if selectedIndex == 0 {
            if selectedIndex < arrangedObjects.count {
                navigateForward(nil)
            }
        } else {
            navigateBack(nil)
        }
        let displayToDelete = arrangedObjects[selectedIndex] as! Display
        let identifier = NSPageController.ObjectIdentifier(String(describing: displayToDelete.id))
        viewControllers.removeValue(forKey: identifier)
        arrangedObjects.remove(at: selectedIndex)
        datastore.context.delete(displayToDelete)
        datastore.save()
    }
    
    func setup() {
        delegate = self
        viewControllers.removeAll(keepingCapacity: false)
        setupPageControl(selectedIndex)
        if !brightnessAdapter.displays.isEmpty
        {
            arrangedObjects = brightnessAdapter.displays.values.sorted(by: { (d1, d2) -> Bool in
                d1.active && !d2.active
            })
        } else {
            arrangedObjects = [GENERIC_DISPLAY]
        }
        selectedIndex = 0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    func pageController(_ pageController: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier {
        return NSPageController.ObjectIdentifier(String(describing: (object as! Display).id))
    }
    
    func pageController(_ pageController: NSPageController, viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier) -> NSViewController {
        if viewControllers[identifier] == nil {
            viewControllers[identifier] = NSStoryboard.main!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "displayViewController")) as? DisplayViewController
        }
        let displayId = CGDirectDisplayID(identifier.rawValue)!
        if displayId != GENERIC_DISPLAY.id {
            viewControllers[identifier]!.display = brightnessAdapter.displays[displayId]
        } else {
            viewControllers[identifier]!.display = GENERIC_DISPLAY
        }
        return viewControllers[identifier]!
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

