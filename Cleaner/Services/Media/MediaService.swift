//
//  MediaService.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 31.03.2026.
//


import SwiftUI
import Photos

protocol MediaServiceProtocol: Sendable {
    func fetchCategories() async -> [MediaCategory]
    func fetchCategoryDetails(for category: MediaCategory) async -> [MediaGroup]
    func updateCategoryStats(for type: CategoryTitle, newCount: Int) async
}

// MARK: - Actor-based details cache

actor DetailsCacheStore {
    private var cache: [CategoryTitle: [MediaGroup]] = [:]

    func get(_ type: CategoryTitle) -> [MediaGroup]? {
        cache[type]
    }

    func set(_ type: CategoryTitle, groups: [MediaGroup]) {
        cache[type] = groups
    }

    func invalidate(_ type: CategoryTitle) {
        cache.removeValue(forKey: type)
    }

    func invalidateAll() {
        cache.removeAll()
    }
}

// MARK: - Service

final class MediaService: MediaServiceProtocol, Sendable {

    private let libraryService: any PhotoLibraryServiceProtocol
    private let cacheManager: CacheManager
    private let duplicateAnalyzer: any DuplicateAnalyzerProtocol
    private let similarAnalyzer: any SimilarAnalyzerProtocol
    private let fileSizeService: any FileSizeServiceProtocol
    private let detailsCache = DetailsCacheStore()

    // GalleryObserver is set once after init — nonisolated storage is fine
    private nonisolated(unsafe) var galleryObserver: GalleryObserver?

    init(
        libraryService: any PhotoLibraryServiceProtocol,
        cacheManager: CacheManager,
        duplicateAnalyzer: any DuplicateAnalyzerProtocol,
        similarAnalyzer: any SimilarAnalyzerProtocol,
        fileSizeService: any FileSizeServiceProtocol
    ) {
        self.libraryService    = libraryService
        self.cacheManager      = cacheManager
        self.duplicateAnalyzer = duplicateAnalyzer
        self.similarAnalyzer   = similarAnalyzer
        self.fileSizeService   = fileSizeService
    }

    // MARK: - Fetch categories (main screen)

    func fetchCategories() async -> [MediaCategory] {
        setupObserver()

        let currentCount     = libraryService.totalAssetsCount()
        let lastCount        = UserDefaults.standard.integer(forKey: "LastSystemTotalCount")
        let cachedCategories = await cacheManager.loadCachedCategories()

        if let cached = cachedCategories, currentCount == lastCount {
            return cached
        }

        if let cached = cachedCategories, currentCount != lastCount {
            Task {
                await detailsCache.invalidateAll()
                let fresh = await fullAnalysis()
                await cacheManager.save(categories: fresh)
                UserDefaults.standard.set(currentCount, forKey: "LastSystemTotalCount")
            }
            return cached
        }

        await detailsCache.invalidateAll()
        let fresh = await fullAnalysis()
        await cacheManager.save(categories: fresh)
        UserDefaults.standard.set(currentCount, forKey: "LastSystemTotalCount")
        return fresh
    }

    // MARK: - Fetch details (category screen)

    func fetchCategoryDetails(for category: MediaCategory) async -> [MediaGroup] {
        if let cached = await detailsCache.get(category.type) {
            return cached
        }

        let result = await computeDetails(for: category)
        await detailsCache.set(category.type, groups: result)
        return result
    }

    func updateCategoryStats(for type: CategoryTitle, newCount: Int) async {
        guard var categories = await cacheManager.loadCachedCategories() else { return }
        guard let index = categories.firstIndex(where: { $0.type == type }) else { return }

        categories[index] = MediaCategory(
            id:       categories[index].id,
            type:     type,
            subtitle: "\(newCount) Items",
            isLocked: categories[index].isLocked
        )
        await cacheManager.save(categories: categories)
        await detailsCache.invalidate(type)
    }

    // MARK: - Private

    private func computeDetails(for category: MediaCategory) async -> [MediaGroup] {
        switch category.type {
        case .screenshots:
            return await MediaMapper.mapToItems(
                libraryService.fetchAssets(subtype: .photoScreenshot),
                sizeService: fileSizeService
            ).toSingleGroup()

        case .livePhotos:
            return await MediaMapper.mapToItems(
                libraryService.fetchAssets(subtype: .photoLive),
                sizeService: fileSizeService
            ).toSingleGroup()

        case .screenRecordings:
            return await MediaMapper.mapToItems(
                libraryService.fetchAssets(subtype: .videoScreenRecording),
                sizeService: fileSizeService
            ).toSingleGroup()

        case .duplicatePhotos:
            let groups = await duplicateAnalyzer.findExactDuplicates()
            return await MediaMapper.mapToGroups(groups, sizeService: fileSizeService)

        case .similarPhotos:
            let groups = await similarAnalyzer.findSimilarPhotos()
            return await MediaMapper.mapToGroups(groups, sizeService: fileSizeService)

        case .similarVideos:
            let groups = await similarAnalyzer.findSimilarVideos()
            return await MediaMapper.mapToGroups(groups, sizeService: fileSizeService)
        }
    }

    private func fullAnalysis() async -> [MediaCategory] {
        let screenshots      = libraryService.fetchAssets(subtype: .photoScreenshot)
        let livePhotos       = libraryService.fetchAssets(subtype: .photoLive)
        let screenRecordings = libraryService.fetchAssets(subtype: .videoScreenRecording)

        async let duplicatesTask     = duplicateAnalyzer.findExactDuplicates()
        async let similarPhotosTask  = similarAnalyzer.findSimilarPhotos()
        async let similarVideosTask  = similarAnalyzer.findSimilarVideos()

        let duplicateGroups    = await duplicatesTask
        let similarGroups      = await similarPhotosTask
        let similarVideoGroups = await similarVideosTask

        return CategoryTitle.orderedCases.map { type in
            let count: Int
            switch type {
            case .duplicatePhotos:  count = duplicateGroups.reduce(0) { $0 + $1.count }
            case .similarPhotos:    count = similarGroups.reduce(0) { $0 + $1.count }
            case .similarVideos:    count = similarVideoGroups.reduce(0) { $0 + $1.count }
            case .screenshots:      count = screenshots.count
            case .livePhotos:       count = livePhotos.count
            case .screenRecordings: count = screenRecordings.count
            }
            return MediaCategory(type: type, subtitle: "\(count) Items", isLocked: false)
        }
    }

    private func setupObserver() {
        guard galleryObserver == nil else { return }

        self.galleryObserver = GalleryObserver(
            onPhotosRemoved: {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .galleryChanged, object: nil)
                }
            },
            onPhotosAdded: { [weak self] in
                self?.cacheManager.clearCache()
                Task { await self?.detailsCache.invalidateAll() }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .galleryChanged, object: nil)
                }
            }
        )
    }
}

private extension Array where Element == MediaItem {
    func toSingleGroup() -> [MediaGroup] {
        isEmpty ? [] : [MediaGroup(items: self)]
    }
}

extension Notification.Name {
    static let galleryChanged = Notification.Name("GalleryChanged")
}
