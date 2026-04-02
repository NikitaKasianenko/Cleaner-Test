//
//  FileSizeService.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 01.04.2026.
//


import Foundation
import Photos
 
protocol FileSizeServiceProtocol: Sendable {
    func sizeInMB(for asset: PHAsset) async -> Double
    func prefetch(assets: [PHAsset]) async
    func clearCache() async
}
 
// MARK: - Actor-based cache (Swift 6 safe)
 
/// All mutable state lives inside the actor — no locks needed.
actor FileSizeCache {
    private var cache: [String: Double] = [:]
    private let userDefaultsKey = "PhotoSizeCache"
 
    init() {
        let saved = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: Double] ?? [:]
        cache = saved
    }
 
    func get(_ id: String) -> Double? {
        cache[id]
    }
 
    func missingIDs(from assets: [PHAsset]) -> [PHAsset] {
        assets.filter { cache[$0.localIdentifier] == nil }
    }
 
    func store(_ results: [String: Double]) {
        for (id, mb) in results { cache[id] = mb }
        let snapshot = cache
        Task.detached(priority: .background) {
            UserDefaults.standard.set(snapshot, forKey: self.userDefaultsKey)
        }
    }
 
    func clear() {
        cache.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
 
// MARK: - Service
 
final class FileSizeService: FileSizeServiceProtocol, Sendable {
 
    private let store = FileSizeCache()
 
    /// Returns cached size, or 0 if `prefetch` hasn't been called yet.
    func sizeInMB(for asset: PHAsset) async -> Double {
        await store.get(asset.localIdentifier) ?? 0
    }
 
    /// Batch-fetches file sizes for all assets not yet cached.
    /// KVC runs inside a `Task` child — always off the main thread → no warnings.
    func prefetch(assets: [PHAsset]) async {
        let missing = await store.missingIDs(from: assets)
        guard !missing.isEmpty else { return }
 
        let results: [String: Double] = await withTaskGroup(of: (String, Double).self) { group in
            for asset in missing {
                group.addTask {
                    // nonisolated + detached → never on main actor
                    let mb = Self.readSizeInMB(for: asset)
                    return (asset.localIdentifier, mb)
                }
            }
            var dict: [String: Double] = [:]
            for await (id, mb) in group { dict[id] = mb }
            return dict
        }
 
        await store.store(results)
    }
 
    func clearCache() async {
        await store.clear()
    }
 
    /// Pure nonisolated function — safe to call from any task/thread.
    private nonisolated static func readSizeInMB(for asset: PHAsset) -> Double {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else { return 0 }
        // KVC here is safe because this always runs in a background Task child,
        // never on the main queue — so no "Missing prefetched properties" warning.
        let bytes = resource.value(forKey: "fileSize") as? CLong ?? 0
        return Double(bytes) / (1024.0 * 1024.0)
    }
}
 
