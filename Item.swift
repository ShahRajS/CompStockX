//
//  Item.swift
//  StockComp
//
//  Created by Raj Shah on 8/21/25.
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
