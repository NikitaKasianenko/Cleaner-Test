//
//  OnboardingView.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//

import SwiftUI

struct OnboardingView: View {
    // Достаем роутер из Environment
    @Environment(AppRouter.self) private var router
    @State private var currentPage = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { index in
                    OnboardingPageView(page: onboardingPages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0..<onboardingPages.count, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? Color.blue : Color(UIColor.systemGray5))
                        .frame(width: currentPage == index ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .padding(.top, 30)
            .padding(.bottom, 24)
            
            Button(action: {
                if currentPage < onboardingPages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    // Запускаємо асинхронне завдання
                    Task {
                        // 1. Чекаємо, поки юзер натисне "Дозволити" або "Відхилити"
                        await router.requestPhotoAccess()
                        
                        // 2. Незалежно від його вибору, пускаємо його в додаток
                        router.completeOnboarding()
                    }
                }
            }) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color(red: 73/255, green: 90/255, blue: 233/255))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color.white)
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image(page.image)
                .resizable()
                .scaledToFit()
                .frame(height: 498)
                .padding(.bottom, 22)
            
            Text(page.title)
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            
            Text(page.description)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 8)
                .fixedSize(horizontal: false, vertical: true)
            
            
            Spacer()
        }
        .padding(.top, 44)
    }
}

#Preview {
    // Даем превьюшке фейковый роутер, чтобы она не ругалась
    OnboardingView()
        .environment(AppRouter())
}
