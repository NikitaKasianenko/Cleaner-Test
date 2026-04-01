//
//  DuplicateAnalyzerService.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 31.03.2026.
//

import Foundation
import Photos

protocol DuplicateAnalyzerProtocol {
    func findExactDuplicates() async -> [[PHAsset]]
}

final class DuplicateAnalyzerService: DuplicateAnalyzerProtocol,@unchecked Sendable {
    
    func findExactDuplicates() async -> [[PHAsset]] {
        return await Task.detached(priority: .userInitiated) {
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var groupedAssets: [String: [PHAsset]] = [:]
            
            allPhotos.enumerateObjects { (asset, _, _) in
                guard let creationDate = asset.creationDate else { return }
                
                let timeKey = Int(creationDate.timeIntervalSince1970)
                let resolutionKey = "\(asset.pixelWidth)x\(asset.pixelHeight)"
                let uniqueHash = "\(timeKey)_\(resolutionKey)"
                
                groupedAssets[uniqueHash, default: []].append(asset)
            }
            
            let duplicatesOnly = groupedAssets.values.filter { $0.count > 1 }
            
            return Array(duplicatesOnly)
        }.value
    }
}
