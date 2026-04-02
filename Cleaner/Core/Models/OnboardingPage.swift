//
//  OnboardingPage.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//

import Foundation

struct OnboardingPage: Identifiable {
    let id = UUID()
    let image: String
    let title: String
    let description: String
}

let onboardingPages: [OnboardingPage] = [
    OnboardingPage(image: "onboarding1", title: "Clean your Storage", description: "Pick the best & delete the rest"),
    OnboardingPage(image: "onboarding2", title: "Detect Similar Photos", description: "Clean similar photos & videos, save your storage space on your phone."),
    OnboardingPage(image: "onboarding3", title: "Video Compressor", description: "Find large videos or media files and compress them to free up storage space")
]
