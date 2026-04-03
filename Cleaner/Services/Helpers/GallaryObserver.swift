//
//  GallaryObserver.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 31.03.2026.
//

import Foundation
import Photos

final class GalleryObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {

    private let onPhotosRemoved: @Sendable () -> Void
    private let onPhotosAdded:   @Sendable () -> Void

    init(
        onPhotosRemoved: @escaping @Sendable () -> Void,
        onPhotosAdded:   @escaping @Sendable () -> Void
    ) {
        self.onPhotosRemoved = onPhotosRemoved
        self.onPhotosAdded   = onPhotosAdded
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        let allAssets = PHAsset.fetchAssets(with: PHFetchOptions())

        guard let details = changeInstance.changeDetails(for: allAssets),
              details.hasIncrementalChanges else { return }

        if !details.insertedObjects.isEmpty {
            onPhotosAdded()
        } else if !details.removedObjects.isEmpty {
            onPhotosRemoved()
        }
    }
}
