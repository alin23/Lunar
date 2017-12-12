//
//  DDC.swift
//  Adaptivo
//
//  Created by Alin on 02/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Foundation
import CoreGraphics

struct DDCReadResult {
    var controlID: UInt8
    var maxValue: UInt8
    var currentValue: UInt8
}


class DDC {
    static func findExternalDisplays() -> [CGDirectDisplayID] {
        var displayIDs = [CGDirectDisplayID]()
        for screen in NSScreen.screens
        {
            if screen.deviceDescription[NSDeviceDescriptionKey.isScreen]! as! String == "YES" {
                let screenNumber = CGDirectDisplayID(truncating: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber)
                if CGDisplayIsBuiltin(screenNumber) == 1 {
                    continue
                }
                displayIDs.append(screenNumber)
            }
        }
        return displayIDs
    }
    
    static func write (displayID: CGDirectDisplayID, controlID : UInt8, newValue : UInt8) -> Bool {
        var command = DDCWriteCommand(
            control_id: controlID, new_value: newValue
        )
        
        let result = DDCWrite(displayID, &command)
        print("Command \(String(command.new_value)): \(String(result))")
        
        return result
    }
    
    static func read (displayID: CGDirectDisplayID, controlID: UInt8) -> DDCReadResult {
        var command = DDCReadCommand(
            control_id: controlID, success: false, max_value: 0, current_value: 0
        )
        DDCRead(displayID, &command)
        print("Current Value: \(String(command.current_value))")
        return DDCReadResult(
            controlID: controlID,
            maxValue: command.max_value,
            currentValue: command.current_value
        )
    }
    
    static func test (displayID: CGDirectDisplayID) -> (Bool, EDID) {
        var edid = EDID()
        let result = EDIDTest(displayID, &edid)
        print("EDID Test for Display \(String(displayID)) - \(String(result))")
        return (result, edid)
    }
    
    static func getDisplayName(for displayID: CGDirectDisplayID) -> String {
        let (result, edid) = test(displayID: displayID)
        print("Test EDID... \(String(result))")
        
        var tmp = edid.descriptors
        let descriptors = [descriptor](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))
        
        if let nameDescriptor = descriptors.first(where: { (des) in
            des.text.type == 0xFC
        }) {
            var tmp = nameDescriptor.text.data
            let nameChars = [Int8](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))
            if let name = NSString(bytes: nameChars, length: 13, encoding: String.Encoding.utf8.rawValue) as String? {
                print("Descriptor: \(name)")
                return name
            }
        }
        return "Monitor"
    }
    
    static func setBrightness(for displayID: CGDirectDisplayID, brightness: UInt8) -> Bool {
        return self.write(displayID: displayID, controlID: UInt8(BRIGHTNESS), newValue: brightness)
    }
    
    static func readBrightness(for displayID: CGDirectDisplayID) -> DDCReadResult {
        return self.read(displayID: displayID, controlID: UInt8(BRIGHTNESS))
    }
    
    static func readContrast(for displayID: CGDirectDisplayID) -> DDCReadResult {
        return self.read(displayID: displayID, controlID: UInt8(CONTRAST))
    }
    
    static func setContrast(for displayID: CGDirectDisplayID, contrast: UInt8) -> Bool {
        return self.write(displayID: displayID, controlID: UInt8(CONTRAST), newValue: contrast)
    }
    
    static func reset(displayID: CGDirectDisplayID) -> Bool {
        return self.write(displayID: displayID, controlID: UInt8(RESET), newValue: 100)
    }
}

