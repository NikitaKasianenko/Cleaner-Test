//
//  CategoryDetailView.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 31.03.2026.
//


import SwiftUI

struct CategoryDetailView: View {
    @State var store: CategoryDetailStore
    @Environment(\.dismiss) private var dismiss

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            Color(UIColor.systemGray6).ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                if store.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    Spacer()
                } else if store.items.isEmpty && store.groups.isEmpty {
                    emptyStateView
                } else if store.isGroupedLayout {
                    groupedGrid
                } else {
                    photoGrid
                }
            }

            if store.isAnySelected {
                VStack {
                    Spacer()
                    deleteButton
                }
                .ignoresSafeArea(.all, edges: .bottom)
            }
        }
        .alert("\"Fast Cleaner\" wants to delete photos", isPresented: $store.showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation { store.deleteSelectedItems() }
            }
        } message: {
            Text("You can restore them later from your gallery if needed.")
        }
        .navigationBarHidden(true)
        .task {
            await store.loadData()
        }
    }
}


extension CategoryDetailView {

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
                Spacer()
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

            Text(store.category.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)

            let isVideo = store.category.type.isVideoCategory
            HStack(spacing: 12) {
                infoBadge(
                    icon: isVideo ? "video.fill" : "photo.fill",
                    text: "\(store.totalPhotosCount) \(isVideo ? "Videos" : "Photos")"
                )
                infoBadge(icon: "externaldrive.fill", text: store.totalStorageString)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }

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
            Spacer()
        }
    }

    private var photoGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.items) { item in
                    photoCell(for: item)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    private var groupedGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 24) {
                ForEach(store.groups) { group in
                    VStack(spacing: 12) {
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
                                    .foregroundColor(.gray)
                            }
                        }
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

    private func photoCell(for item: MediaItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            AssetImageView(asset: item.asset)
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(12)
                .clipped()

            // Checkbox
            Group {
                if item.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color(red: 73/255, green: 90/255, blue: 233/255))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(red: 73/255, green: 90/255, blue: 233/255), lineWidth: 2.5)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(10)

            // Best badge
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
                        .foregroundColor(Color(red: 73/255, green: 90/255, blue: 233/255))
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

    private var deleteButton: some View {
        Button(action: { store.showingDeleteAlert = true }) {
            Text("Delete \(store.selectedItemsCount) photos (\(String(format: "%.1f", store.selectedItemsSize)) MB)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(red: 73/255, green: 90/255, blue: 233/255))
                .cornerRadius(16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}


#Preview("Grouped — Duplicates") {
    let env = AppEnvironment.preview(
        mediaService: MockMediaService(
            groups: MockMediaService.mockGroups
        )
    )
    let category = MediaCategory(
        type: .duplicatePhotos,
        subtitle: "6 Items",
        isLocked: false
    )
    return CategoryDetailView(
        store: CategoryDetailStore(
            category: category,
            service: env.mediaService
        )
    )
    .environment(env)
    .environment(env.router)
}

#Preview("Flat — Screenshots") {
    let env = AppEnvironment.preview(
        mediaService: MockMediaService(
            groups: MockMediaService.mockGroups
        )
    )
    let category = MediaCategory(
        type: .screenshots,
        subtitle: "3 Items",
        isLocked: false
    )
    return CategoryDetailView(
        store: CategoryDetailStore(
            category: category,
            service: env.mediaService
        )
    )
    .environment(env)
    .environment(env.router)
}

#Preview("Empty") {
    let env = AppEnvironment.preview(
        mediaService: MockMediaService(groups: [])
    )
    let category = MediaCategory(
        type: .duplicatePhotos,
        subtitle: "0 Items",
        isLocked: false
    )
    return CategoryDetailView(
        store: CategoryDetailStore(
            category: category,
            service: env.mediaService
        )
    )
    .environment(env)
    .environment(env.router)
}
