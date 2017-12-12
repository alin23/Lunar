//
//  Display.swift
//  Adaptivo
//
//  Created by Alin on 05/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa

let MIN_BRIGHTNESS: UInt8 = 10
let MAX_BRIGHTNESS: UInt8 = 100
let MIN_CONTRAST: UInt8 = 30
let MAX_CONTRAST: UInt8 = 90


class Display: NSObject, NSCoding {
    var name: String
    var id: CGDirectDisplayID
    var active: Bool
    var minBrightness: UInt8
    var maxBrightness: UInt8
    var minContrast: UInt8
    var maxContrast: UInt8
    
    var brightness: UInt8 {
        get {
            return DDC.readBrightness(for: self.id).currentValue
        }
        set {
            let _ = DDC.setBrightness(for: self.id, brightness: newValue)
        }
    }
    var contrast: UInt8 {
        get {
            return DDC.readContrast(for: self.id).currentValue
        }
        set {
            let _ = DDC.setContrast(for: self.id, contrast: newValue)
        }
    }
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("displays")
    
    init(id: CGDirectDisplayID, name: String? = nil, active: Bool = false, minBrightness: UInt8? = MIN_BRIGHTNESS, maxBrightness: UInt8? = MAX_BRIGHTNESS, minContrast: UInt8? = MIN_CONTRAST, maxContrast: UInt8? = MAX_CONTRAST) {
        self.id = id
        self.name = name ?? DDC.getDisplayName(for: id)
        self.active = active
        self.minBrightness = minBrightness ?? MIN_BRIGHTNESS
        self.maxBrightness = maxBrightness ?? MAX_BRIGHTNESS
        self.minContrast = minContrast ?? MIN_CONTRAST
        self.maxContrast = maxContrast ?? MAX_CONTRAST
    }
    
    //MARK: NSCoding
    func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: "id")
        aCoder.encode(name, forKey: "name")
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        guard let id = aDecoder.decodeObject(forKey: "id") as? CGDirectDisplayID else {
            log.error("Unable to decode the id for a Display object.")
            return nil
        }
        
        let name = aDecoder.decodeObject(forKey: "name") as? String
        let minBrightness = aDecoder.decodeObject(forKey: "minBrightness") as? UInt8
        let maxBrightness = aDecoder.decodeObject(forKey: "maxBrightness") as? UInt8
        let minContrast = aDecoder.decodeObject(forKey: "minContrast") as? UInt8
        let maxContrast = aDecoder.decodeObject(forKey: "maxContrast") as? UInt8
        
        self.init(id: id, name: name, minBrightness: minBrightness, maxBrightness: maxBrightness, minContrast: minContrast, maxContrast: maxContrast)
    }
}
