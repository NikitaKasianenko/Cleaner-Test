//
//  AppRootView.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//

import SwiftUI

@main
struct CleanerApp: App {
    // Создаем роутер один раз на все приложение
    @State private var router = AppRouter()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if router.hasCompletedOnboarding {
                    MainView()
                        .transition(.opacity)
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            // Передаем роутер во все дочерние View
            .environment(router)
        }
    }
}


