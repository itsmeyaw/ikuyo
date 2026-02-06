//
//  Item.swift
//  Ikuyo
//
//  Created by Yudhistira Wibowo on 01.08.25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
