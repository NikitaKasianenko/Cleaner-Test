//
//  PhotoPermissionService.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//

import Foundation
import Photos

enum PermissionStatus {
    case unknown
    case granted
    case denied
}

protocol PhotoPermissionServiceProtocol {
    func checkPermission() -> PermissionStatus
    func requestPermission() async -> PermissionStatus
}

struct PhotoPermissionService: PhotoPermissionServiceProtocol {
    
    func checkPermission() -> PermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return map(status)
    }
    
    func requestPermission() async -> PermissionStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return map(status)
    }
    
    private func map(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized, .limited:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}
