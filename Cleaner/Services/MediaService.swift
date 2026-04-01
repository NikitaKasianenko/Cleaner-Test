//
//  MediaService.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//

import SwiftUI
import Photos

// 1. Протокол для абстракции
protocol MediaServiceProtocol {
    func fetchCategories() async -> [MediaCategory]
    func fetchCategoryDetails(for category: MediaCategory) async -> [MediaGroup]
    func updateCategoryStats(for categoryTitle: String, newCount: Int)
}

// 3. Настройка Environment для внедрения зависимостей (DI)
private struct MediaServiceKey: EnvironmentKey {
    static let defaultValue: any MediaServiceProtocol = MediaService()
}

extension EnvironmentValues {
    var mediaService: any MediaServiceProtocol {
        get { self[MediaServiceKey.self] }
        set { self[MediaServiceKey.self] = newValue }
    }
}

final class MediaService: MediaServiceProtocol, @unchecked Sendable {
    
    private let cacheManager = CacheManager()
    private let duplicateAnalyzer: DuplicateAnalyzerProtocol = DuplicateAnalyzerService()
    private let similarAnalyzer: SimilarAnalyzerProtocol = SimilarAnalyzerService()
    private var galleryObserver: GalleryObserver?
    
    init() {

            self.galleryObserver = GalleryObserver(onGalleryChanged: { [weak self] in
                print("🔄 [System] Галерея змінилася! Скидаємо кеші...")
                
                // Скидаємо кеш головного екрана
                self?.cacheManager.clearCache()
                DispatchQueue.main.async {
                                NotificationCenter.default.post(name: Notification.Name("GalleryChanged"), object: nil)
                }
            })
        }
    
    private func getSystemPhotosCount() -> Int {
            return PHAsset.fetchAssets(with: PHFetchOptions()).count
        }
    
    func fetchCategories() async -> [MediaCategory] {
            let currentSystemCount = getSystemPhotosCount()
            let lastSystemCount = UserDefaults.standard.integer(forKey: "LastSystemTotalCount")
            let cachedCategories = await cacheManager.loadCachedCategories()
            
            // СЦЕНАРІЙ А: Кеш є, але кількість фотографій на пристрої змінилася (Холодний старт)
            if let cached = cachedCategories, currentSystemCount != lastSystemCount {
                print("🔄 [Service] Зміни в галереї виявлено! Віддаємо кеш, оновлюємо у фоні...")
                
                // Запускаємо фонове оновлення, не блокуючи Головний екран
                Task {
                    let freshData = await performFullGalleryAnalysis()
                    
                    // Оновлюємо кеш та запам'ятовуємо нове загальне число
                    await cacheManager.save(categories: freshData)
                    UserDefaults.standard.set(currentSystemCount, forKey: "LastSystemTotalCount")
                    
                    // Сигналізуємо Головному екрану, що треба тихо перемалювати цифри
                    await MainActor.run {
                        NotificationCenter.default.post(name: Notification.Name("GalleryChanged"), object: nil)
                    }
                }
                
                return cached // Миттєво віддаємо старий кеш для швидкості
            }
            
            // СЦЕНАРІЙ Б: Все абсолютно актуально (змін не було)
            if let cached = cachedCategories, currentSystemCount == lastSystemCount {
                return cached
            }
            
            // СЦЕНАРІЙ В: Найперший запуск додатка (кешу ще не існує)
            print("⚙️ [Service] Кешу немає. Запускаємо повний аналіз...")
            let freshData = await performFullGalleryAnalysis()
            await cacheManager.save(categories: freshData)
            UserDefaults.standard.set(currentSystemCount, forKey: "LastSystemTotalCount")
            
            return freshData
        }


        // 4. МЕТОД ДЛЯ ТОЧКОВОГО ОНОВЛЕННЯ З СЕРЕДИНИ КАТЕГОРІЇ
        func updateCategoryStats(for categoryTitle: String, newCount: Int) {
            Task {
                // Беремо поточний кеш (бо він може бути вже відмальований)
                guard var currentCategories = await cacheManager.loadCachedCategories() else { return }
                
                if let index = currentCategories.firstIndex(where: { $0.title == categoryTitle }) {
                    // Оновлюємо ТІЛЬКИ текст однієї категорії
                    let updatedCategory = MediaCategory(
                        id: currentCategories[index].id,
                        title: currentCategories[index].title,
                        subtitle: "\(newCount) Items",
                        iconName: currentCategories[index].iconName,
                        isLocked: currentCategories[index].isLocked
                    )
                    currentCategories[index] = updatedCategory
                    
                    // Зберігаємо і кажемо UI оновитись
                    await cacheManager.save(categories: currentCategories)
                    await MainActor.run {
                        NotificationCenter.default.post(name: Notification.Name("GalleryChanged"), object: nil)
                    }
                }
            }
        }

    // MARK: - Головний двигун аналізу
    private func performFullGalleryAnalysis() async -> [MediaCategory] {
            var categories: [MediaCategory] = []
            
            let screenshots = fetchSystemCategory(subtype: .photoScreenshot)
            let livePhotos = fetchSystemCategory(subtype: .photoLive)
            let screenRecordings = fetchSystemCategory(subtype: .videoScreenRecording)
            
            categories.append(MediaCategory(title: "Screenshots", subtitle: "\(screenshots.count) Items", iconName: "ScreenShoots", isLocked: false))
            categories.append(MediaCategory(title: "Live Photos", subtitle: "\(livePhotos.count) Items", iconName: "LivePhotos", isLocked: false))
            categories.append(MediaCategory(title: "Screen Recordings", subtitle: "\(screenRecordings.count) Items", iconName: "ScreenRecordings", isLocked: false))
            
            // --- ЗАПУСКАЄМО ВАЖКІ АНАЛІЗАТОРИ ПАРАЛЕЛЬНО ---
            // Використовуємо async let, щоб вони працювали одночасно, а не чекали один одного!
            async let duplicatesTask = duplicateAnalyzer.findExactDuplicates()
            async let similarPhotosTask = similarAnalyzer.findSimilarPhotos()
            async let similarVideosTask = similarAnalyzer.findSimilarVideos()
            
            // Чекаємо результатів обох
            let duplicateGroups = await duplicatesTask
            let similarGroups = await similarPhotosTask
            let similarVideoGroups = await similarVideosTask
            
            // Рахуємо кількість фоток
            let totalDuplicatePhotos = duplicateGroups.reduce(0) { $0 + $1.count }
            let totalSimilarPhotos = similarGroups.reduce(0) { $0 + $1.count }
            let totalSimilarVideos = similarVideoGroups.reduce(0) { $0 + $1.count }
            
            // Додаємо в масив
            categories.insert(MediaCategory(title: "Duplicate Photos", subtitle: "\(totalDuplicatePhotos) Items", iconName: "DublicatePhotos", isLocked: false), at: 0)
                
            categories.insert(MediaCategory(title: "Similar Photos", subtitle: "\(totalSimilarPhotos) Items", iconName: "SimilarPhotos", isLocked: false), at: 1)
                
            categories.append(MediaCategory(title: "Similar Videos", subtitle: "\(totalSimilarVideos) Items", iconName: "SimilarVideos", isLocked: false))
                
            return categories
        }
    
    // MARK: - Допоміжні методи запитів до Photos
    
    nonisolated private func fetchSystemCategory(subtype: PHAssetMediaSubtype) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        // Магія Apple: фільтруємо базу даних напряму за допомогою предиката
        options.predicate = NSPredicate(format: "(mediaSubtype & %d) != 0", subtype.rawValue)
        
        // Якщо це відео, шукаємо у відео, інакше у фотографіях
        let mediaType: PHAssetMediaType = subtype == .videoScreenRecording ? .video : .image
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            options.predicate!,
            NSPredicate(format: "mediaType == %d", mediaType.rawValue)
        ])
        
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        return PHAsset.fetchAssets(with: options)
    }
    
    func fetchCategoryDetails(for category: MediaCategory) async -> [MediaGroup] {
            // Обов'язково йдемо у фон, щоб крутилка ProgressView не зависала на 2000 фотографіях!
            return await Task.detached(priority: .userInitiated) {
                
                var resultGroups: [MediaGroup] = []
                
                // 1. ДІСТАЄМО КЕШ РОЗМІРІВ (ID -> Мегабайти)
                var sizeCache = UserDefaults.standard.dictionary(forKey: "PhotoSizeCache") as? [String: Double] ?? [:]
                var cacheWasUpdated = false
                
                // 2. РОЗУМНА ФУНКЦІЯ ДЛЯ ОТРИМАННЯ РОЗМІРУ
                let getSize: (PHAsset) -> Double = { asset in
                    let id = asset.localIdentifier
                    
                    // Якщо є в кеші — віддаємо миттєво
                    if let cachedSize = sizeCache[id] {
                        return cachedSize
                    }
                    
                    // Якщо немає — рахуємо по-справжньому
                    let resources = PHAssetResource.assetResources(for: asset)
                    let unsignedInt64 = resources.first?.value(forKey: "fileSize") as? CLong
                    let sizeInMB = Double(unsignedInt64 ?? 0) / (1024.0 * 1024.0)
                    
                    // Зберігаємо і ставимо прапорець
                    sizeCache[id] = sizeInMB
                    cacheWasUpdated = true
                    
                    return sizeInMB
                }
                
                // 3. ТВІЙ КРАСИВИЙ СВІТЧ (передаємо getSize в хелпери)
                switch category.title {
                case "Screenshots":
                    let items = self.mapFetchResultToItems(self.fetchSystemCategory(subtype: .photoScreenshot), sizeProvider: getSize)
                    resultGroups.append(MediaGroup(items: items))

                case "Live Photos":
                    let items = self.mapFetchResultToItems(self.fetchSystemCategory(subtype: .photoLive), sizeProvider: getSize)
                    resultGroups.append(MediaGroup(items: items))

                case "Screen Recordings":
                    let items = self.mapFetchResultToItems(self.fetchSystemCategory(subtype: .videoScreenRecording), sizeProvider: getSize)
                    resultGroups.append(MediaGroup(items: items))

                case "Duplicate Photos":
                    let assetGroups = await self.duplicateAnalyzer.findExactDuplicates()
                    resultGroups = self.mapAssetGroupsToMediaGroups(assetGroups, sizeProvider: getSize)

                case "Similar Photos":
                    let assetGroups = await self.similarAnalyzer.findSimilarPhotos()
                    resultGroups = self.mapAssetGroupsToMediaGroups(assetGroups, sizeProvider: getSize)

                case "Similar Videos":
                    // ВИПРАВЛЕНО: тут має бути similarVideoAnalyzer!
                    let assetGroups = await self.similarAnalyzer.findSimilarVideos()
                    resultGroups = self.mapAssetGroupsToMediaGroups(assetGroups, sizeProvider: getSize)

                default:
                    break
                }
                
                // 4. ЗБЕРІГАЄМО КЕШ, ЯКЩО БУЛИ НОВІ ФОТО
                if cacheWasUpdated {
                    UserDefaults.standard.set(sizeCache, forKey: "PhotoSizeCache")
                    print("✅ [Cache] Оновлено кеш розмірів для \(sizeCache.count) файлів")
                }

                return resultGroups
            }.value
        }
        
        // MARK: - Хелпери для мапінгу (перетворення)
        
        // Для звичайних списків (Скріншоти, Лайви)
    nonisolated private func mapFetchResultToItems(_ fetchResult: PHFetchResult<PHAsset>, sizeProvider: @escaping (PHAsset) -> Double) -> [MediaItem] {
            var items: [MediaItem] = []
            fetchResult.enumerateObjects { asset, _, _ in
                // Використовуємо передану функцію для отримання розміру
                let sizeInMB = sizeProvider(asset)
                items.append(MediaItem(asset: asset, fileSize: sizeInMB, isSelected: false, isBest: false))
            }
            return items
        }
        
        // Для згрупованих списків (Дублікати) — ТУТ ЛОГІКА ДИЗАЙНУ!
    nonisolated private func mapAssetGroupsToMediaGroups(_ assetGroups: [[PHAsset]], sizeProvider: @escaping (PHAsset) -> Double) -> [MediaGroup] {
            var groups: [MediaGroup] = []
            
            for assetGroup in assetGroups {
                var items: [MediaItem] = []
                
                // 1. Сортуємо фотографії ВСЕРЕДИНІ групи (найстаріше або найновіше = Best)
                // Зазвичай найкращим (Best) вважається найперше зроблене фото, тому ascending: true
                let sortedAssetGroup = assetGroup.sorted {
                    ($0.creationDate ?? Date.distantPast) < ($1.creationDate ?? Date.distantPast)
                }
                
                for (index, asset) in sortedAssetGroup.enumerated() {
                    let sizeInMB = sizeProvider(asset)
                    let isBest = (index == 0)
                    let isSelected = !isBest
                    
                    items.append(MediaItem(asset: asset, fileSize: sizeInMB, isSelected: isSelected, isBest: isBest))
                }
                groups.append(MediaGroup(items: items))
            }
            
            // 2. Сортуємо САМІ ГРУПИ між собою, щоб найновіші дублікати (за датою) були на самому верху екрана
            groups.sort { group1, group2 in
                let date1 = group1.items.first?.asset.creationDate ?? Date.distantPast
                let date2 = group2.items.first?.asset.creationDate ?? Date.distantPast
                return date1 > date2 // Descending: від нових до старих
            }
            
            return groups
        }
        
        // Швидкий спосіб дізнатися вагу файлу без його завантаження з iCloud
    nonisolated private func getFileSizeInMB(for asset: PHAsset) -> Double {
            let resources = PHAssetResource.assetResources(for: asset)
            guard let resource = resources.first else { return 0.0 }
            
            // Використовуємо KVC для швидкого доступу до метаданих розміру
            let unsignedInt64 = resource.value(forKey: "fileSize") as? CLong
            let sizeInBytes = Double(unsignedInt64 ?? 0)
            
            return sizeInBytes / (1024.0 * 1024.0) // Переводимо байти в Мегабайти
        }
    
}
