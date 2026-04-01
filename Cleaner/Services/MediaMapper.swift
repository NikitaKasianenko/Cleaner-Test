// MediaMapper.swift
// Pure, stateless functions: PHAsset(s) → MediaItem / MediaGroup.
// No protocol needed — it has no side effects and no state to mock.
// Testable: just call the static functions with test data.

import Foundation
import Photos

enum MediaMapper {

    // for (Screenshots, Live Photos, Screen Recordings)
    static func mapToItems(
        _ fetchResult: PHFetchResult<PHAsset>,
        sizeService: any FileSizeServiceProtocol
    ) -> [MediaItem] {
        var items: [MediaItem] = []
        fetchResult.enumerateObjects { asset, _, _ in
            items.append(MediaItem(
                asset: asset,
                fileSize: sizeService.sizeInMB(for: asset),
                isSelected: false,
                isBest: false
            ))
        }
        return items
    }

    // for (Duplicate Photos, Similar Photos, Similar Videos)
    static func mapToGroups(
        _ assetGroups: [[PHAsset]],
        sizeService: any FileSizeServiceProtocol
    ) -> [MediaGroup] {
        var groups: [MediaGroup] = []

        for assetGroup in assetGroups {
            let sorted = assetGroup.sorted {
                ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
            }

            let items: [MediaItem] = sorted.enumerated().map { index, asset in
                let isBest = (index == 0)
                return MediaItem(
                    asset: asset,
                    fileSize: sizeService.sizeInMB(for: asset),
                    isSelected: !isBest,
                    isBest: isBest
                )
            }
            groups.append(MediaGroup(items: items))
        }

        return groups.sorted {
            let d1 = $0.items.first?.asset.creationDate ?? .distantPast
            let d2 = $1.items.first?.asset.creationDate ?? .distantPast
            return d1 > d2
        }
    }
}
