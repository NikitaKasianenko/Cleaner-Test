//
//  MediaCategory.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//

import Foundation

struct MediaCategory: Identifiable,Codable,Hashable {
    var id = UUID()
    let title: String
    let subtitle: String
    let iconName: String
    let isLocked: Bool
}
