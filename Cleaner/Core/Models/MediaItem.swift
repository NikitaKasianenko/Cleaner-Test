//
//  MediaItem.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//

import Foundation
import Photos

struct MediaItem: Identifiable, Hashable {
    let id = UUID()
    let asset: PHAsset
    var fileSize: Double = 0.0
    var isSelected: Bool = false
    var isBest: Bool = false
}

struct MediaGroup: Identifiable, Hashable {
    let id = UUID()
    var items: [MediaItem]
    
    var isAllSelected: Bool {
            let selectableItems = items.filter { !$0.isBest }
            return !selectableItems.isEmpty && selectableItems.allSatisfy { $0.isSelected }
        }
}
