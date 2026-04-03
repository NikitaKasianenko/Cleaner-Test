//
//  MediaMapper.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 01.04.2026.
//

import Foundation
import Photos
 
enum MediaMapper {
 
    // for (Screenshots, Live Photos, Screen Recordings)
    static func mapToItems(
        _ fetchResult: PHFetchResult<PHAsset>,
        sizeService: any FileSizeServiceProtocol
    ) async -> [MediaItem] {
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }
 
        await sizeService.prefetch(assets: assets)
 
        var items: [MediaItem] = []
        for asset in assets {
            items.append(MediaItem(
                asset: asset,
                fileSize: await sizeService.sizeInMB(for: asset),
                isSelected: false,
                isBest: false
            ))
        }
        return items
    }
 
    static func mapToGroups(
        _ assetGroups: [[PHAsset]],
        sizeService: any FileSizeServiceProtocol
    ) async -> [MediaGroup] {
        let allAssets = assetGroups.flatMap { $0 }
        await sizeService.prefetch(assets: allAssets)
 
        var groups: [MediaGroup] = []
        for assetGroup in assetGroups {
            let sorted = assetGroup.sorted {
                ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
            }
            var items: [MediaItem] = []
            for (index, asset) in sorted.enumerated() {
                let isBest = index == 0
                items.append(MediaItem(
                    asset: asset,
                    fileSize: await sizeService.sizeInMB(for: asset),
                    isSelected: !isBest,
                    isBest: isBest
                ))
            }
            groups.append(MediaGroup(items: items))
        }
 
        return groups.sorted {
            ($0.items.first?.asset.creationDate ?? .distantPast) >
            ($1.items.first?.asset.creationDate ?? .distantPast)
        }
    }
}
 
