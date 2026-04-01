//
//  AppRootView.swift
//  Cleaner
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
