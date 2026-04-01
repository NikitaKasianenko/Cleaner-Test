// CategoryTitle.swift
// Replaces all the hardcoded String comparisons scattered across the codebase.
// A typo in "Duplicate Photos" used to silently break an entire screen — never again.

import Foundation

enum CategoryTitle: String, CaseIterable, Codable {
    case duplicatePhotos  = "Duplicate Photos"
    case similarPhotos    = "Similar Photos"
    case similarVideos    = "Similar Videos"
    case screenshots      = "Screenshots"
    case livePhotos       = "Live Photos"
    case screenRecordings = "Screen Recordings"

    // One place to update icons — no more hunting across files
    var iconName: String {
        switch self {
        case .duplicatePhotos:  return "DublicatePhotos"
        case .similarPhotos:    return "SimilarPhotos"
        case .similarVideos:    return "SimilarVideos"
        case .screenshots:      return "ScreenShoots"
        case .livePhotos:       return "LivePhotos"
        case .screenRecordings: return "ScreenRecordings"
        }
    }

    // Drives isGroupedLayout in CategoryDetailStore — no more .contains("Duplicate")
    var isGrouped: Bool {
        switch self {
        case .duplicatePhotos, .similarPhotos, .similarVideos: return true
        case .screenshots, .livePhotos, .screenRecordings:     return false
        }
    }

    // Drives the media-type badge icon in CategoryDetailView
    var isVideoCategory: Bool {
        switch self {
        case .similarVideos, .screenRecordings: return true
        default:                                return false
        }
    }

    // Display order on the main screen
    static var orderedCases: [CategoryTitle] {
        [.duplicatePhotos, .similarPhotos, .screenshots, .livePhotos, .screenRecordings, .similarVideos]
    }
}
