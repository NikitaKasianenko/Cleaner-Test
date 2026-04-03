//
//  MediaCategory.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 31.03.2026.
//

import Foundation

struct MediaCategory: Identifiable, Codable, Hashable {
    var id = UUID()
    let type: CategoryTitle
    let subtitle: String
    let isLocked: Bool

    var title:    String { type.rawValue }
    var iconName: String { type.iconName }
    var isGrouped: Bool  { type.isGrouped }
}
