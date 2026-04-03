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
            RootView()
                .environmentObject(env)
                .environmentObject(env.router)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var router: AppRouter
 
    var body: some View {
        ZStack {
            if router.hasCompletedOnboarding {
                MainView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: router.hasCompletedOnboarding)
    }
}
 
#Preview("Onboarding") {
    let env = AppEnvironment.preview()
    env.router.hasCompletedOnboarding = false
 
    return RootView()
        .environmentObject(env)
        .environmentObject(env.router)
}
 
#Preview("Main") {
    let env = AppEnvironment.preview()
    env.router.hasCompletedOnboarding = true
    env.router.hasPhotoAccess = true
 
    return RootView()
        .environmentObject(env)
        .environmentObject(env.router)
}
