//
//  Item.swift
//  CityWalk
//
//  Created by 卢绎文 on 2025/4/25.
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
