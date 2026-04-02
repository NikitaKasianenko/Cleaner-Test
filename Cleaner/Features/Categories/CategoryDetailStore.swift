//
//  CategoryDetailStore.swift
//  Cleaner
//
//  Created by Nykyta Kasianenko on 31.03.2026.
//


import SwiftUI
import Photos

@MainActor
@Observable
class CategoryDetailStore {
    var category: MediaCategory

    var items: [MediaItem] = []
    var groups: [MediaGroup] = []

    var isLoading: Bool = true
    var showingDeleteAlert = false

    @ObservationIgnored
    private let service: any MediaServiceProtocol

    init(category: MediaCategory, service: any MediaServiceProtocol) {
        self.category = category
        self.service = service
    }

    var isGroupedLayout: Bool { category.isGrouped }

    var selectedItemsCount: Int {
        isGroupedLayout
            ? groups.flatMap { $0.items }.filter { $0.isSelected }.count
            : items.filter { $0.isSelected }.count
    }

    var selectedItemsSize: Double {
        isGroupedLayout
            ? groups.flatMap { $0.items }.filter { $0.isSelected }.reduce(0) { $0 + $1.fileSize }
            : items.filter { $0.isSelected }.reduce(0) { $0 + $1.fileSize }
    }

    var isAnySelected: Bool { selectedItemsCount > 0 }

    var isAllSelected: Bool {
        if isGroupedLayout {
            let selectable = groups.flatMap { $0.items }.filter { !$0.isBest }
            return !selectable.isEmpty && selectable.allSatisfy { $0.isSelected }
        } else {
            return !items.isEmpty && items.allSatisfy { $0.isSelected }
        }
    }

    var totalPhotosCount: Int {
        isGroupedLayout ? groups.reduce(0) { $0 + $1.items.count } : items.count
    }

    var totalStorageString: String {
        let totalMB = isGroupedLayout
            ? groups.flatMap { $0.items }.reduce(0) { $0 + $1.fileSize }
            : items.reduce(0) { $0 + $1.fileSize }

        return totalMB >= 1024
            ? String(format: "%.1f GB", totalMB / 1024.0)
            : String(format: "%.1f MB", totalMB)
    }

    // MARK: - Load

    func loadData() async {
        self.isLoading = true
        let fetchedGroups = await service.fetchCategoryDetails(for: category)

        if isGroupedLayout {
            self.groups = fetchedGroups
        } else {
            self.items = fetchedGroups.first?.items ?? []
        }

        withAnimation { self.isLoading = false }
    }

    // MARK: - Selection

    func toggleSelection(for itemID: UUID) {
        if isGroupedLayout {
            for gIndex in groups.indices {
                if let iIndex = groups[gIndex].items.firstIndex(where: { $0.id == itemID }) {
                    groups[gIndex].items[iIndex].isSelected.toggle()
                    break
                }
            }
        } else {
            if let index = items.firstIndex(where: { $0.id == itemID }) {
                items[index].isSelected.toggle()
            }
        }
    }

    func toggleGroupSelection(for groupID: UUID) {
        guard let gIndex = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let newValue = !groups[gIndex].isAllSelected

        for iIndex in groups[gIndex].items.indices {
            if newValue && groups[gIndex].items[iIndex].isBest { continue }
            groups[gIndex].items[iIndex].isSelected = newValue
        }
    }

    func toggleSelectAll() {
        let newValue = !isAllSelected
        if isGroupedLayout {
            for gIndex in groups.indices {
                for iIndex in groups[gIndex].items.indices {
                    if newValue && groups[gIndex].items[iIndex].isBest { continue }
                    groups[gIndex].items[iIndex].isSelected = newValue
                }
            }
        } else {
            for index in items.indices {
                items[index].isSelected = newValue
            }
        }
    }

    func deleteSelectedItems() {
        let assetsToDelete: [PHAsset] = isGroupedLayout
            ? groups.flatMap { $0.items }.filter { $0.isSelected }.map { $0.asset }
            : items.filter { $0.isSelected }.map { $0.asset }

        guard !assetsToDelete.isEmpty else { return }

        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
                }
                handleSuccessfulDeletion(assets: assetsToDelete)
            } catch {
                print("Delete failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleSuccessfulDeletion(assets: [PHAsset]) {
        let deletedIds = Set(assets.map { $0.localIdentifier })

        withAnimation(.easeInOut) {
            if isGroupedLayout {
                for i in groups.indices {
                    groups[i].items.removeAll { deletedIds.contains($0.asset.localIdentifier) }
                }
                groups.removeAll { $0.items.count <= 1 }
            } else {
                items.removeAll { deletedIds.contains($0.asset.localIdentifier) }
            }
        }

        Task {
            await service.updateCategoryStats(for: category.type, newCount: totalPhotosCount)
        }
        self.showingDeleteAlert = false
    }
}
