// PhotoLibraryService.swift
// Single responsibility: query the Photos database.
// Zero knowledge of MediaCategory, caching, or UI models.

import Foundation
import Photos

protocol PhotoLibraryServiceProtocol: Sendable {
    func fetchAssets(subtype: PHAssetMediaSubtype) -> PHFetchResult<PHAsset>
    func totalAssetsCount() -> Int
}

final class PhotoLibraryService: PhotoLibraryServiceProtocol, @unchecked Sendable {

    func fetchAssets(subtype: PHAssetMediaSubtype) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()

        let subtypePredicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            subtype.rawValue
        )
        let mediaType: PHAssetMediaType = (subtype == .videoScreenRecording) ? .video : .image
        let typePredicate = NSPredicate(format: "mediaType == %d", mediaType.rawValue)

        options.predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [subtypePredicate, typePredicate]
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        return PHAsset.fetchAssets(with: options)
    }

    func totalAssetsCount() -> Int {
        PHAsset.fetchAssets(with: PHFetchOptions()).count
    }
}
