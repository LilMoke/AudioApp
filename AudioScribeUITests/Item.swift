//
//  Item.swift
//  AudioScribe
//
//  Created by Tony Scamurra on 7/2/25.
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
