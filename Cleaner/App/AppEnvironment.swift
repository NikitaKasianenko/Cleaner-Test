//
//  AppEnvironment.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 31.03.2026.
//


import SwiftUI
import Photos

@Observable
final class AppEnvironment {

    let mediaService: any MediaServiceProtocol
    let router: AppRouter

    static let live = AppEnvironment(
        mediaService: MediaService(
            libraryService: PhotoLibraryService(),
            cacheManager: CacheManager(),
            duplicateAnalyzer: DuplicateAnalyzerService(),
            similarAnalyzer: SimilarAnalyzerService(),
            fileSizeService: FileSizeService()
        )
    )

    private init(mediaService: any MediaServiceProtocol) {
        self.mediaService = mediaService
        self.router = AppRouter()
    }

    static func preview(
        mediaService: any MediaServiceProtocol = MockMediaService()
    ) -> AppEnvironment {
        AppEnvironment(mediaService: mediaService)
    }
}

final class MockMediaService: MediaServiceProtocol {

    var stubbedCategories: [MediaCategory]
    var stubbedGroups: [MediaGroup]
    var delay: UInt64
    
    static var previewAssets: [PHAsset] {
            let options = PHFetchOptions()
            options.fetchLimit = 6
            let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
            
            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }
            return assets
        }

    init(
        categories: [MediaCategory] = MockMediaService.defaultCategories,
        groups: [MediaGroup] = [],
        delay: UInt64 = 300_000_000
    ) {
        self.stubbedCategories = categories
        self.stubbedGroups     = groups
        self.delay             = delay
    }

    func fetchCategories() async -> [MediaCategory] {
        try? await Task.sleep(nanoseconds: delay)
        return stubbedCategories
    }

    func fetchCategoryDetails(for category: MediaCategory) async -> [MediaGroup] {
        try? await Task.sleep(nanoseconds: delay)
        return stubbedGroups
    }

    func updateCategoryStats(for type: CategoryTitle, newCount: Int) async {
        if let i = stubbedCategories.firstIndex(where: { $0.type == type }) {
            stubbedCategories[i] = MediaCategory(
                type:     type,
                subtitle: "\(newCount) Items",
                isLocked: false
            )
        }
    }

    static let mockGroups: [MediaGroup] = {
            // Створюємо 3 віртуальні групи дублікатів
            return (1...3).map { groupIndex in
                let itemsCount = Int.random(in: 2...4) // По 2-4 фото в групі
                
                let items = (0..<itemsCount).map { itemIndex in
                    MediaItem(
                        asset: MockPHAsset(),
                        fileSize: Double.random(in: 1.5...5.0), // Випадкові мегабайти
                        isSelected: itemIndex != 0, // Виділяємо всі, крім першого
                        isBest: itemIndex == 0      // Перший робимо "Best"
                    )
                }
                return MediaGroup(items: items)
            }
        }()

    static let defaultCategories: [MediaCategory] = [
        MediaCategory(type: .duplicatePhotos,  subtitle: "124 Items", isLocked: false),
        MediaCategory(type: .similarPhotos,    subtitle: "318 Items", isLocked: false),
        MediaCategory(type: .screenshots,      subtitle: "57 Items",  isLocked: false),
        MediaCategory(type: .livePhotos,       subtitle: "89 Items",  isLocked: false),
        MediaCategory(type: .screenRecordings, subtitle: "12 Items",  isLocked: false),
        MediaCategory(type: .similarVideos,    subtitle: "34 Items",  isLocked: false),
    ]

    static let emptyCategories: [MediaCategory] = CategoryTitle.orderedCases.map {
        MediaCategory(type: $0, subtitle: "0 Items", isLocked: false)
    }

    static let lockedCategories: [MediaCategory] = CategoryTitle.orderedCases.map {
        MediaCategory(type: $0, subtitle: "— Items", isLocked: true)
    }
}

final class MockPHAsset: PHAsset, @unchecked Sendable {
    private let _fakeID = UUID().uuidString
    
    override var localIdentifier: String {
        return _fakeID
    }
}
