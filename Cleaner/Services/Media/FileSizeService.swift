//
//  FileSizeService.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 01.04.2026.
//


import Foundation
import Photos

protocol FileSizeServiceProtocol {
    func sizeInMB(for asset: PHAsset) async -> Double
    func prefetch(assets: [PHAsset]) async
    func clearCache()
}

private actor FileSizeCache {
    private var cache: [String: Double] = [:]
    private let userDefaultsKey = "PhotoSizeCache"

    init() {
        cache = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: Double] ?? [:]
    }

    func get(_ id: String) -> Double? { cache[id] }

    func missingAssets(from assets: [PHAsset]) -> [PHAsset] {
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

final class FileSizeService: FileSizeServiceProtocol, @unchecked Sendable {

    private let storage = FileSizeCache()

    func sizeInMB(for asset: PHAsset) async -> Double {
        await storage.get(asset.localIdentifier) ?? 0
    }

    func prefetch(assets: [PHAsset]) async {
        let missing = await storage.missingAssets(from: assets)
        guard !missing.isEmpty else { return }

        let results = await withTaskGroup(of: (String, Double).self) { group in
            for asset in missing {
                group.addTask {
                    let mb = Self.readSizeInMB(for: asset)
                    return (asset.localIdentifier, mb)
                }
            }
            var dict: [String: Double] = [:]
            for await (id, mb) in group { dict[id] = mb }
            return dict
        }

        await storage.store(results)
    }

    func clearCache() {
        Task { await storage.clear() }
    }

    private nonisolated static func readSizeInMB(for asset: PHAsset) -> Double {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else { return 0 }
        let bytes = resource.value(forKey: "fileSize") as? CLong ?? 0
        return Double(bytes) / (1024.0 * 1024.0)
    }
}
