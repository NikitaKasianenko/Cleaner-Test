//
//  MediaItem.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//

import Foundation
import Photos

// Модель однієї фотографії для UI
struct MediaItem: Identifiable, Hashable {
    let id = UUID()
    let asset: PHAsset
    var fileSize: Double = 0.0
    var isSelected: Bool = false
    var isBest: Bool = false
}

// Модель групи (для екрану Duplicate Photos)
struct MediaGroup: Identifiable, Hashable {
    let id = UUID()
    var items: [MediaItem]
    
    // Допоміжна властивість: чи всі елементи в групі вибрані?
    var isAllSelected: Bool {
            // 1. Відфільтровуємо всі фотографії, які НЕ є "Best" (ті, що можна виділяти)
            let selectableItems = items.filter { !$0.isBest }
            
            // 2. Перевіряємо, чи всі ВОНИ виділені
            return !selectableItems.isEmpty && selectableItems.allSatisfy { $0.isSelected }
        }
}
