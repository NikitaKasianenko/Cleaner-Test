// MediaService.swift
// Now a thin orchestrator. It composes the services and runs the analysis.
// It does NOT know how to fetch from Photos, compute file sizes, or map models —
// those responsibilities now live in dedicated services.

import SwiftUI
import Photos

// MARK: - Protocol

protocol MediaServiceProtocol: Sendable {
    func fetchCategories() async -> [MediaCategory]
    func fetchCategoryDetails(for category: MediaCategory) async -> [MediaGroup]
    func updateCategoryStats(for type: CategoryTitle, newCount: Int) async
}

// MARK: - Implementation

final class MediaService: MediaServiceProtocol, @unchecked Sendable {

    private let libraryService: any PhotoLibraryServiceProtocol
    private let cacheManager: CacheManager
    private let duplicateAnalyzer: any DuplicateAnalyzerProtocol
    private let similarAnalyzer: any SimilarAnalyzerProtocol
    private let fileSizeService: any FileSizeServiceProtocol
    private var galleryObserver: GalleryObserver?

    init(
        libraryService: any PhotoLibraryServiceProtocol,
        cacheManager: CacheManager,
        duplicateAnalyzer: any DuplicateAnalyzerProtocol,
        similarAnalyzer: any SimilarAnalyzerProtocol,
        fileSizeService: any FileSizeServiceProtocol
    ) {
        self.libraryService   = libraryService
        self.cacheManager     = cacheManager
        self.duplicateAnalyzer = duplicateAnalyzer
        self.similarAnalyzer  = similarAnalyzer
        self.fileSizeService  = fileSizeService

        self.galleryObserver = GalleryObserver { [weak cacheManager] in
            cacheManager?.clearCache()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .galleryChanged, object: nil)
            }
        }
    }

    // MARK: - Fetch categories (main screen)

    func fetchCategories() async -> [MediaCategory] {
        let currentCount  = libraryService.totalAssetsCount()
        let lastCount     = UserDefaults.standard.integer(forKey: "LastSystemTotalCount")
        let cachedCategories = await cacheManager.loadCachedCategories()

        // if gallery do not changed
        if let cached = cachedCategories, currentCount == lastCount {
            return cached
        }

        // if gallery changed - return stale data immediately
        // refresh silently in the background
        if let cached = cachedCategories, currentCount != lastCount {
            Task {
                let fresh = await fullAnalysis()
                await cacheManager.save(categories: fresh)
                UserDefaults.standard.set(currentCount, forKey: "LastSystemTotalCount")
                
            }
            return cached
        }

        // first launch - wait for full analysis
        let fresh = await fullAnalysis()
        await cacheManager.save(categories: fresh)
        UserDefaults.standard.set(currentCount, forKey: "LastSystemTotalCount")
        return fresh
    }

    // MARK: - Fetch details (category screen)

    func fetchCategoryDetails(for category: MediaCategory) async -> [MediaGroup] {
        switch category.type {

        case .screenshots:
            let items = MediaMapper.mapToItems(
                libraryService.fetchAssets(subtype: .photoScreenshot),
                sizeService: fileSizeService
            )
            return [MediaGroup(items: items)]

        case .livePhotos:
            let items = MediaMapper.mapToItems(
                libraryService.fetchAssets(subtype: .photoLive),
                sizeService: fileSizeService
            )
            return [MediaGroup(items: items)]

        case .screenRecordings:
            let items = MediaMapper.mapToItems(
                libraryService.fetchAssets(subtype: .videoScreenRecording),
                sizeService: fileSizeService
            )
            return [MediaGroup(items: items)]

        case .duplicatePhotos:
            let groups = await duplicateAnalyzer.findExactDuplicates()
            return MediaMapper.mapToGroups(groups, sizeService: fileSizeService)

        case .similarPhotos:
            let groups = await similarAnalyzer.findSimilarPhotos()
            return MediaMapper.mapToGroups(groups, sizeService: fileSizeService)

        case .similarVideos:
            let groups = await similarAnalyzer.findSimilarVideos()
            return MediaMapper.mapToGroups(groups, sizeService: fileSizeService)
        }
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
    }

    private func fullAnalysis() async -> [MediaCategory] {
        let screenshots     = libraryService.fetchAssets(subtype: .photoScreenshot)
        let livePhotos      = libraryService.fetchAssets(subtype: .photoLive)
        let screenRecordings = libraryService.fetchAssets(subtype: .videoScreenRecording)

        // run in parallel
        async let duplicatesTask     = duplicateAnalyzer.findExactDuplicates()
        async let similarPhotosTask  = similarAnalyzer.findSimilarPhotos()
        async let similarVideosTask  = similarAnalyzer.findSimilarVideos()

        let duplicateGroups  = await duplicatesTask
        let similarGroups    = await similarPhotosTask
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
}

extension Notification.Name {
    static let galleryChanged = Notification.Name("GalleryChanged")
}
