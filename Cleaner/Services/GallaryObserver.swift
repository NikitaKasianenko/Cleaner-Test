//
//  GallaryObserver.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 31.03.2026.
//
import SwiftUI
import Photos

final class GalleryObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    
    public let onGalleryChanged: @Sendable () -> Void
    
    init(onGalleryChanged: @escaping @Sendable () -> Void) {
        self.onGalleryChanged = onGalleryChanged
            super.init()
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        onGalleryChanged()
    }
}
