//
//  AppRootView.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//

import SwiftUI
import Combine

@main
struct CleanerApp: App {
    @StateObject private var env = AppEnvironment.live
 
    var body: some Scene {
        WindowGroup {
            ZStack {
                if env.router.hasCompletedOnboarding {
                    MainView()
                        .transition(.opacity)
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            .environmentObject(env)
            .environmentObject(env.router)
        }
    }
}
 
#Preview("Onboarding") {
    let env = AppEnvironment.preview()
    env.router.hasCompletedOnboarding = false
 
    return ZStack {
        OnboardingView()
    }
    .environmentObject(env)
    .environmentObject(env.router)
}
 
#Preview("Main — onboarding done") {
    let env = AppEnvironment.preview()
    env.router.hasCompletedOnboarding = true
    env.router.hasPhotoAccess = true
 
    return ZStack {
        MainView()
    }
    .environmentObject(env)
    .environmentObject(env.router)
}
 
