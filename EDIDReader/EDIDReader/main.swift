//
//  main.swift
//  EDIDReader
//
//  Created by Alin on 29/03/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Foundation

func printEdid(_ data: Data) {
    let edid = data.map { $0 }.str(length: 128)
    let id = data[77 ..< 90].map { $0 }.str(length: 13)
    print("      EDID: \(edid)")
    print("      ID: \(id)\n")
}

func printDetails(_ id: CGDirectDisplayID) {
    let sn = CGDisplaySerialNumber(id)
    let model = CGDisplayModelNumber(id)
    let vendor = CGDisplayVendorNumber(id)

    print("    S/N: \(sn.str())")
    print("    Model Number: \(model.str())")
    print("    Vendor: \(vendor.str())\n")

    let idData = DDC.getDisplayIdentificationData(displayID: id)
    let name = DDC.getDisplayName(for: id)
    let serial = DDC.getDisplaySerial(for: id)

    print("    Name: \(name)")
    print("    Serial: \(serial)\n")

    print("    Display unique ID: \(idData)\n")

    if let data = DDC.getEdidData(displayID: id) {
        print("    Raw data (guess match):")
        printEdid(data)
    }
}

if let id = DDC.getBuiltinDisplay() {
    print("Built-in display:")
    printDetails(id)
}

DDC.findExternalDisplays().forEach { id in
    print("External displays:")
    printDetails(id)
}

print("Raw data:")
DDC.getEdidData().forEach { data in
    printEdid(data)
}
