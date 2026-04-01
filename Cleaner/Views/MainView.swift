//
//  MainView.swift
//  Cleaner
//

import SwiftUI

struct MainView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppRouter.self) private var router

    @State private var categories: [MediaCategory] = []

    let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack(path: Bindable(router).path) {
            VStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(categories) { category in
                        Button {
                            if router.hasPhotoAccess {
                                router.navigate(to: .categoryDetail(category))
                            } else {
                                Task {
                                    await router.requestPhotoAccess()
                                    if router.hasPhotoAccess {
                                        router.navigate(to: .categoryDetail(category))
                                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                                        await MainActor.run {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                }
                            }
                        } label: {
                            CategoryCell(category: category, hasAccess: router.hasPhotoAccess)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)

                Spacer()
            }
            .navigationTitle("Media")
            .background(Color(UIColor.systemGray6))
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .categoryDetail(let category):
                    CategoryDetailView(
                        store: CategoryDetailStore(
                            category: category,
                            service: env.mediaService
                        )
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .galleryChanged)) { _ in
            Task {
                categories = await env.mediaService.fetchCategories()
            }
        }
        .task {
            categories = await env.mediaService.fetchCategories()
        }
    }
}


struct CategoryCell: View {
    let category: MediaCategory
    let hasAccess: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(category.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .padding(.horizontal, 13)
                .padding(.top, 13)

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text(category.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                if hasAccess {
                    Text(category.subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 235/255, green: 87/255, blue: 87/255))
                        .frame(width: 24, height: 24)
                        .background(Color(red: 235/255, green: 87/255, blue: 87/255).opacity(0.15))
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

//#Preview {
//    MainView()
//        .environment(AppEnvironment.preview())
//        .environment(AppRouter())
//}
