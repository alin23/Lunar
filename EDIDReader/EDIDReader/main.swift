//
//  main.swift
//  EDIDReader
//
//  Created by Alin on 29/03/2019.
//  Copyright © 2019 Alin. All rights reserved.
//

import Foundation

DDC.findExternalDisplays().forEach {
    DDC.printTextDescriptors(displayID: $0)
}
