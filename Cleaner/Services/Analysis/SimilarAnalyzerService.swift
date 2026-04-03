//
//  SimilarAnalyzerService.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 31.03.2026.
//

import Foundation
import Photos

protocol SimilarAnalyzerProtocol {
    func findSimilarPhotos() async -> [[PHAsset]]
    func findSimilarVideos() async -> [[PHAsset]]
}

final class SimilarAnalyzerService: SimilarAnalyzerProtocol,@unchecked Sendable {
    
    private let photoTimeThreshold: TimeInterval = 2.0
    private let videoTimeThreshold: TimeInterval = 5.0
    
    
    func findSimilarPhotos() async -> [[PHAsset]] {
        return await Task.detached(priority: .userInitiated) {
            
            let fetchOptions = PHFetchOptions()
            // ТУТ ВАЖЛИВО: Сортуємо від найстаріших до найновіших, щоб йти по часовій шкалі
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            var similarGroups: [[PHAsset]] = []
            var currentGroup: [PHAsset] = []
            var previousDate: Date? = nil
            
            // Пробігаємося по всіх фотографіях у хронологічному порядку
            allPhotos.enumerateObjects { (asset, index, _) in
                guard let currentDate = asset.creationDate else { return }
                
                if let prevDate = previousDate {
                    // Рахуємо різницю в часі між поточною і попередньою фотографією
                    let timeDifference = currentDate.timeIntervalSince(prevDate)
                    
                    if timeDifference <= self.photoTimeThreshold {
                        // Якщо інтервал маленький, додаємо в поточну групу "схожих"
                        currentGroup.append(asset)
                    } else {
                        // Якщо пройшло багато часу, закриваємо поточну групу
                        if currentGroup.count > 1 {
                            similarGroups.append(currentGroup)
                        }
                        // І починаємо нову групу з поточної фотографії
                        currentGroup = [asset]
                    }
                } else {
                    // Це найперша фотографія, просто додаємо її в нову групу
                    currentGroup.append(asset)
                }
                
                previousDate = currentDate
                
                // Перевірка для останнього елемента
                if index == allPhotos.count - 1 && currentGroup.count > 1 {
                    similarGroups.append(currentGroup)
                }
            }
            
            // Перевертаємо масив, щоб найновіші групи були зверху (як зазвичай люблять юзери)
            return similarGroups.reversed()
        }.value
    }
    
    func findSimilarVideos() async -> [[PHAsset]] {
            return await Task.detached(priority: .userInitiated) {
                
                let fetchOptions = PHFetchOptions()
                // Важливо: сортуємо за часом створення
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                // ТУТ ГОЛОВНА РІЗНИЦЯ: Шукаємо тільки відео!
                let allVideos = PHAsset.fetchAssets(with: .video, options: fetchOptions)
                
                var similarGroups: [[PHAsset]] = []
                var currentGroup: [PHAsset] = []
                var previousDate: Date? = nil
                
                // Пробігаємося по всіх відео
                allVideos.enumerateObjects { (asset, index, _) in
                    guard let currentDate = asset.creationDate else { return }
                    
                    if let prevDate = previousDate {
                        let timeDifference = currentDate.timeIntervalSince(prevDate)
                        
                        if timeDifference <= self.videoTimeThreshold {
                            currentGroup.append(asset)
                        } else {
                            if currentGroup.count > 1 {
                                similarGroups.append(currentGroup)
                            }
                            currentGroup = [asset]
                        }
                    } else {
                        currentGroup.append(asset)
                    }
                    
                    previousDate = currentDate
                    
                    if index == allVideos.count - 1 && currentGroup.count > 1 {
                        similarGroups.append(currentGroup)
                    }
                }
                
                return similarGroups.reversed()
            }.value
        }
}
