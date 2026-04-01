//
//  MainView.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//

import SwiftUI

struct MainView: View {
    // Получаем зависимости из окружения
    @Environment(\.mediaService) private var service
    @Environment(AppRouter.self) private var router
    
    // Локальный стейт для данных
    @State private var categories: [MediaCategory] = []
    
    let columns = [
        GridItem(.flexible(),spacing: 6),
        GridItem(.flexible())
    ]
    
    var body: some View
    {
            // Bindable потрібен, щоб NavigationStack міг змінювати шлях роутера (наприклад, при свайпі "назад")
            NavigationStack(path: Bindable(router).path) {
                VStack(spacing: 0) {
                    
                    // --- СІТКА КАТЕГОРІЙ ---
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(categories) { category in
                            
                            // 1. РОБИМО КЛІТИНКУ КЛІКАБЕЛЬНОЮ
                            Button {
                                if router.hasPhotoAccess {
                                    // Якщо доступ є — просто переходимо
                                    router.navigate(to: .categoryDetail(category))
                                } else {
                                    // Якщо доступу немає — намагаємося його отримати
                                    Task {
                                        await router.requestPhotoAccess()
                                        
                                        // Перевіряємо статус ПІСЛЯ запиту
                                        if router.hasPhotoAccess {
                                            // Юзер щойно погодився — пускаємо всередину
                                            router.navigate(to: .categoryDetail(category))
                                        } else {
                                            // Юзер відмовив (або вже відмовляв раніше і попап не з'явився).
                                            // Відкриваємо Налаштування iPhone!
                                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                                await MainActor.run {
                                                    UIApplication.shared.open(url)
                                                }
                                            }
                                        }
                                    }
                                }
                            } label: {
                                CategoryCell(category: category, hasAccess: router.hasPhotoAccess)
                            }
                            // ВАЖЛИВО: Цей модифікатор забороняє iOS фарбувати весь текст і картинку в стандартний синій колір кнопки
                            .buttonStyle(.plain)
                            
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    
                    Spacer()
                    

//                    Button(action: {
//                        router.resetData()
//                    }){
//                        Text("Clear Data")
//                            .font(.system(size: 18, weight: .semibold))
//                            .foregroundColor(.white)
//                            .frame(maxWidth: .infinity)
//                            .frame(height: 56)
//                            .background(Color(red: 73/255, green: 90/255, blue: 233/255))
//                            .cornerRadius(16)
//                            .padding(.horizontal, 24)
//                            .padding(.bottom, 32)
//                    }
                }
                .navigationTitle("Media")
                .background(Color(UIColor.systemGray6))
                
                // 2. ВКАЗУЄМО, ЩО ВІДКРИВАТИ ПРИ ПЕРЕХОДІ
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .categoryDetail(let category):
                        // Створюємо екран деталей і передаємо йому новий Store з обраною категорією
                        CategoryDetailView(store: CategoryDetailStore(category: category, service: service))
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GalleryChanged"))) { _ in
                Task {
                    categories = await service.fetchCategories()
                }
            }
        
            .task {
                categories = await service.fetchCategories()
            }
        }
    }

struct CategoryCell: View {
    let category: MediaCategory
    let hasAccess: Bool // 1. ДОДАЛИ ПАРАМЕТР ДОСТУПУ
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            Image(category.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .padding(.horizontal, 13)
                .padding(.top, 13)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 6) { // Трохи збільшив spacing для замочка
                Text(category.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                // 2. НОВА ЛОГІКА: Показуємо текст АБО замочок
                if hasAccess {
                    Text(category.subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                } else {
                    // Малюємо замочок як на твоєму дизайні
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 235/255, green: 87/255, blue: 87/255)) // Червоний колір
                        .frame(width: 24, height: 24)
                        .background(Color(red: 235/255, green: 87/255, blue: 87/255).opacity(0.15)) // Світло-червоний фон
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 134)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    MainView()
        .environment(AppRouter()) // Даем роутер
        // Если ты использовал EnvironmentValues для сервиса, превью подхватит MockMediaService автоматически!
}
