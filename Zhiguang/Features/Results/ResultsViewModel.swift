// Zhiguang/Features/Results/ResultsViewModel.swift
import Foundation
import Photos

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published private(set) var selectedIds: [String] = []
    @Published private(set) var rejectedIds: [String] = []
    @Published private(set) var allCandidateIds: [String] = []
    @Published var thumbnails: [String: CGImage] = [:]

    var isEmpty: Bool { selectedIds.isEmpty }

    let babyId: UUID
    private let cache: ScanStateCache
    private let photoService: PhotoLibraryServiceProtocol

    init(babyId: UUID,
         cache: ScanStateCache = .init(),
         photoService: PhotoLibraryServiceProtocol = PhotoLibraryService()) {
        self.babyId = babyId
        self.cache = cache
        self.photoService = photoService
        loadFromCache()
    }

    func remove(assetId: String) {
        selectedIds.removeAll { $0 == assetId }
        if !rejectedIds.contains(assetId) { rejectedIds.append(assetId) }
        persistState()
    }

    func restore(assetId: String) {
        rejectedIds.removeAll { $0 == assetId }
        if !selectedIds.contains(assetId) { selectedIds.append(assetId) }
        persistState()
    }

    func loadThumbnails() async {
        for id in allCandidateIds {
            if thumbnails[id] == nil,
               let img = await photoService.loadThumbnail(for: id, size: CGSize(width: 200, height: 200)) {
                thumbnails[id] = img
            }
        }
    }

    // MARK: Private
    private func loadFromCache() {
        guard let result = cache.load(for: babyId) else { return }
        selectedIds = result.selectedAssetIds
        rejectedIds = result.rejectedAssetIds
        allCandidateIds = result.allCandidateIds
    }

    private func persistState() {
        guard var result = cache.load(for: babyId) else { return }
        result.selectedAssetIds = selectedIds
        result.rejectedAssetIds = rejectedIds
        cache.save(result, for: babyId)
    }
}
