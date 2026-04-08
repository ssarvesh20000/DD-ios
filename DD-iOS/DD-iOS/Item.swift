//
//  Item.swift
//  DD-iOS
//
//  Created by Sarvesh Shanmugam on 4/8/26.
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
