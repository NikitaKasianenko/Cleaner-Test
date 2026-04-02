//
//  CacheManager.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 31.03.2026.
//

import Foundation

final class CacheManager {
    private let fileManager = FileManager.default
    
    private var cacheURL: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("categories_cache.json")
    }
    
    func save(categories: [MediaCategory]) async {
        let localCacheURL = self.cacheURL
        
        await Task.detached(priority: .background) {
            do {
                let data = try JSONEncoder().encode(categories)
                try data.write(to: localCacheURL)
                print("Cache saved successfully on disk")
            } catch {
                print("Failed to save cache: \(error)")
            }
        }.value
    }
    
    func loadCachedCategories() async -> [MediaCategory]? {
            let localCacheURL = self.cacheURL
            
            guard fileManager.fileExists(atPath: localCacheURL.path) else { return nil }
            
            return await Task.detached(priority: .userInitiated) {
                do {
                    let data = try Data(contentsOf: localCacheURL)
                    let categories = try JSONDecoder().decode([MediaCategory].self, from: data)
                    return categories
                } catch {
                    print("Failed to load cache: \(error)")
                    return nil
                }
            }.value
        }
    
    
    func clearCache() {
        try? fileManager.removeItem(at: cacheURL)
    }
}
