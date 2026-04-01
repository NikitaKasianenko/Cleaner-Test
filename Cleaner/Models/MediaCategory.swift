// MediaCategory.swift
// Now uses CategoryTitle enum instead of a raw String.
// The subtitle (e.g. "1746 Items") is still a plain String because it changes at runtime.

import Foundation

struct MediaCategory: Identifiable, Codable, Hashable {
    var id = UUID()
    let type: CategoryTitle   // ← was: let title: String
    let subtitle: String
    let isLocked: Bool

    // Convenience pass-throughs so call-sites don't have to reach into .type
    var title:    String { type.rawValue }
    var iconName: String { type.iconName }
    var isGrouped: Bool  { type.isGrouped }
}
