//
//  CategoryDetailView.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 30.03.2026.
//

import SwiftUI

struct CategoryDetailView: View {
    // Підключаємо наш "мозок"
    @State var store: CategoryDetailStore
        
    @Environment(\.dismiss) private var dismiss
    
    // Налаштування сітки (2 колонки)
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            // Фон екрана (світло-сірий)
            Color(UIColor.systemGray6).ignoresSafeArea()
            
            VStack(spacing: 0) {
                            headerView
                            
                            // НОВА ЛОГІКА ВІДОБРАЖЕННЯ:
                            if store.isLoading {
                                
                                // 1. Показуємо крутилку, поки сервіс аналізує фотографії
                                Spacer()
                                ProgressView("Аналізуємо медіатеку...")
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(1.2)
                                Spacer()
                                
                            } else if store.items.isEmpty && store.groups.isEmpty {
                                
                                // 2. Показуємо Empty State ТІЛЬКИ якщо завантаження закінчилось, а фоток реально нема
                                emptyStateView
                                
                            } else if store.isGroupedLayout {
                                // 3. Згрупована сітка (дублікати)
                                groupedGrid
                            } else {
                                // 4. Звичайна сітка
                                photoGrid
                            }
                        }
            // 4. Плаваюча кнопка видалення (з'являється тільки якщо щось вибрано)
            if store.isAnySelected {
                VStack {
                    Spacer()
                    deleteButton
                }
                .ignoresSafeArea(.all, edges: .bottom) // Щоб кнопка гарно виглядала знизу
            }
        }
        .alert("\"Fast Cleaner\" wants to delete photos", isPresented: $store.showingDeleteAlert) {
            
            // Кнопка скасування (роль .cancel робить її стандартною і безпечною)
            Button("Cancel", role: .cancel) { }
            
            // Кнопка видалення (роль .destructive автоматично зробить її червоною або системною для небезпечних дій)
            Button("Delete", role: .destructive) {
                withAnimation {
                    // Викликаємо функцію очищення
                    store.deleteSelectedItems()
                }
            }
            
        } message: {
            // Текст-підказка під заголовком
            Text("You can restore them later from your gallery if needed.")
        }
        // Ховаємо стандартний системний бар, бо ми намалювали свій красивий
        .navigationBarHidden(true)
        .task {
                    print("📱 [View] Екран з'явився! Викликаємо store.loadRealData()")
                    await store.loadData()
                    print("📱 [View] store.loadRealData() завершив роботу")
                }
    }
}

// MARK: - Шматочки Інтерфейсу (UI Components)
extension CategoryDetailView {
    
    // --- ВЕРХНЯ ПАНЕЛЬ (HEADER) ---
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Кнопка Назад та Select All
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                // Кнопка виділення (тільки якщо є фото)
                if !store.items.isEmpty || !store.groups.isEmpty {
                    Button(action: { store.toggleSelectAll() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text(store.isAllSelected ? "Deselect all" : "Select all")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                        )
                    }
                }
            }
            
            // Заголовок (Назва категорії)
            Text(store.category.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
            
            let isVideoCategory = store.category.title.contains("Video") || store.category.title.contains("Recording")
            let iconName = isVideoCategory ? "video.fill" : "photo.fill"
            let mediaTypeName = isVideoCategory ? "Videos" : "Photos"
                        
            // Інфо-бейджики (Кількість і розмір)
            HStack(spacing: 12) {
                infoBadge(icon: iconName, text: "\(store.totalPhotosCount) \(mediaTypeName)")
                infoBadge(icon: "externaldrive.fill", text: store.totalStorageString)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
    
    // Маленький бейджик для шапки
    private func infoBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.gray)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(UIColor.systemGray5), lineWidth: 1)
        )
    }
    
    // --- EMPTY STATE (ПОРОЖНІЙ ЕКРАН) ---
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            
            Text("Your device is clean")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
            
            Text("There are no photos on your device.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer()
            Spacer() // Трохи піднімаємо текст вище центру
        }
    }
    
    // --- СІТКА ФОТОГРАФІЙ (FLOW LAYOUT) ---
    private var photoGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.items) { item in
                    // Клітинка з фотографією
                    photoCell(for: item)
                    // Обробка натискання на всю клітинку
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.toggleSelection(for: item.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Місце для синьої кнопки
        }
    }
    
    // --- ЗГРУПОВАНА СІТКА (ДЛЯ DUPLICATE PHOTOS) ---
        private var groupedGrid: some View {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 24) { // Відстань між групами
                    ForEach(store.groups) { group in
                        VStack(spacing: 12) {
                            
                            // Шапка групи ("2 Duplicate" та "Deselect All")
                            HStack {
                                Text("\(group.items.count) Duplicate")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation { store.toggleGroupSelection(for: group.id) }
                                }) {
                                    Text(group.isAllSelected ? "Deselect All" : "Select All")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray) // Сірий колір як на макеті
                                }
                            }
                            
                            // Сітка фотографій всередині групи
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(group.items) { item in
                                    photoCell(for: item)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        
        // --- ОКРЕМА КЛІТИНКА ФОТОГРАФІЇ ---
        // (Я виніс її в окрему функцію, щоб не дублювати код для звичайної і згрупованої сітки)
        private func photoCell(for item: MediaItem) -> some View {
            ZStack(alignment: .bottomTrailing) {
                
                AssetImageView(asset: item.asset)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .cornerRadius(12)
                                .clipped()
                
                // Чекбокс виділення
                Group {
                    if item.isSelected {
                        // 1. Вибраний стан (зафарбований синій з галочкою)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold)) // Менший розмір галочки
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24) // Чіткі розміри квадрата
                            .background(Color(red: 73/255, green: 90/255, blue: 233/255)) // Фірмовий синій
                            .clipShape(RoundedRectangle(cornerRadius: 6)) // Закруглення кутів
                    } else {
                        // 2. Невибраний стан (синій контур)
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 73/255, green: 90/255, blue: 233/255), lineWidth: 2.5) // Синій контур
                            .frame(width: 24, height: 24) // Чіткі розміри
                    }
                }
                .padding(10)
                
                // БЕЙДЖИК "BEST" (В лівому нижньому куті)
                if item.isBest {
                    VStack {
                        Spacer()
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Best")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(Color(red: 73/255, green: 90/255, blue: 233/255)) // Фірмовий синій
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .cornerRadius(6)
                            .padding(10)
                            
                            Spacer()
                        }
                    }
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.toggleSelection(for: item.id)
                }
            }
        }
    
    // --- КНОПКА ВИДАЛЕННЯ ---
    private var deleteButton: some View {
        Button(action: {
            store.showingDeleteAlert = true
        }) {
            Text("Delete \(store.selectedItemsCount) photos (\(String(format: "%.1f", store.selectedItemsSize)) MB)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(red: 73/255, green: 90/255, blue: 233/255)) // Твій фірмовий синій
                .cornerRadius(16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        // Плавна поява кнопки
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Preview
//#Preview {
//    let testCategory = MediaCategory(title: "Duplicate Photos", subtitle: "1746 Items", iconName: "LivePhotos", isLocked: false)
//    
//    // Передаємо просто як параметр
//    CategoryDetailView(store: CategoryDetailStore(category: testCategory))
//}
