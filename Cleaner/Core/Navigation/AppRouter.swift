//
//  AppRouter.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//


import SwiftUI
import Combine

enum AppRoute: Hashable {
    case categoryDetail(MediaCategory)
}

class AppRouter: ObservableObject {
    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasSeenOnBoarding")
    @Published var hasPhotoAccess: Bool = false
    @Published var path = NavigationPath()
 
    private let permissionService: any PhotoPermissionServiceProtocol = PhotoPermissionService()
 
    init() {
        self.hasPhotoAccess = permissionService.checkPermission() == .granted
    }
 
    func requestPhotoAccess() async {
        let status = await permissionService.requestPermission()
        await MainActor.run {
            self.hasPhotoAccess = (status == .granted)
        }
    }
 
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnBoarding")
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.5)) {
                self.hasCompletedOnboarding = true
            }
        }
    }
 
    func resetData() {
        UserDefaults.standard.removeObject(forKey: "hasSeenOnBoarding")
        withAnimation(.easeInOut(duration: 0.5)) {
            hasCompletedOnboarding = false
            path.removeLast(path.count)
        }
    }
 
    func navigate(to route: AppRoute) {
        path.append(route)
    }
}
