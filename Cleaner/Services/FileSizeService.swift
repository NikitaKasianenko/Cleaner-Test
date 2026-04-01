// FileSizeService.swift
// Single responsibility: tell you how large a PHAsset is, in MB.
// Caches results in UserDefaults so repeated lookups (e.g. reloading a screen) are instant.

import Foundation
import Photos

protocol FileSizeServiceProtocol: Sendable {
    func sizeInMB(for asset: PHAsset) -> Double
    func clearCache()
}

final class FileSizeService: FileSizeServiceProtocol, @unchecked Sendable {

    private let cacheKey = "PhotoSizeCache"

    private var memoryCache: [String: Double] = [:]
    private var isDirty = false
    private let lock = NSLock()

    init() {
        let saved = UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: Double] ?? [:]
        memoryCache = saved
    }

    func sizeInMB(for asset: PHAsset) -> Double {
        lock.lock()
        defer { lock.unlock() }

        let id = asset.localIdentifier
        if let cached = memoryCache[id] { return cached }

        let resources = PHAssetResource.assetResources(for: asset)
        let bytes = resources.first?.value(forKey: "fileSize") as? CLong ?? 0
        let mb = Double(bytes) / (1024.0 * 1024.0)

        memoryCache[id] = mb
        isDirty = true

        if memoryCache.count % 50 == 0 {
            let snapshot = memoryCache
            Task.detached(priority: .background) {
                UserDefaults.standard.set(snapshot, forKey: self.cacheKey)
            }
            isDirty = false
        }

        return mb
    }

    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        memoryCache.removeAll()
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    func flush() {
        lock.lock()
        guard isDirty else { lock.unlock(); return }
        let snapshot = memoryCache
        isDirty = false
        lock.unlock()
        UserDefaults.standard.set(snapshot, forKey: cacheKey)
    }
}
