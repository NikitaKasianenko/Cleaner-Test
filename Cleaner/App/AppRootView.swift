//
//  AppRootView.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//

import SwiftUI

@main
struct CleanerApp: App {
    @State private var env = AppEnvironment.live

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
            .environment(env)
            .environment(env.router)
        }
    }
}

 
#Preview("Onboarding") {
    let env = AppEnvironment.preview()
    env.router.hasCompletedOnboarding = false
 
    return ZStack {
        OnboardingView()
    }
    .environment(env)
    .environment(env.router)
}
 
#Preview("Main — onboarding done") {
    let env = AppEnvironment.preview()
    env.router.hasCompletedOnboarding = true
    env.router.hasPhotoAccess = true
 
    return ZStack {
        MainView()
    }
    .environment(env)
    .environment(env.router)
}
