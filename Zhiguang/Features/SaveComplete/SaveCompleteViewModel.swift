// Zhiguang/Features/SaveComplete/SaveCompleteViewModel.swift
import Foundation
import UIKit

@MainActor
final class SaveCompleteViewModel: ObservableObject {
    enum SaveState {
        case saving
        case success(count: Int)
        case partialFailure(succeeded: Int, failed: Int, failedIds: [String])
        case fullFailure(AlbumSaveFailureReason)
    }

    @Published var saveState: SaveState = .saving
    @Published var toast: String?
    @Published var showHomeButton = false

    private let babyId: UUID
    private let selectedIds: [String]
    private let saveService: AlbumSaveServiceProtocol
    private let cache: ScanStateCache

    init(babyId: UUID, selectedIds: [String],
         saveService: AlbumSaveServiceProtocol = AlbumSaveService(),
         cache: ScanStateCache = .init()) {
        self.babyId = babyId
        self.selectedIds = selectedIds
        self.saveService = saveService
        self.cache = cache
    }

    func performSave() async {
        saveState = .saving
        let result = await saveService.save(assetIds: selectedIds)
        if result.isFullSuccess {
            saveState = .success(count: result.succeeded.count)
        } else if result.isPartialSuccess {
            saveState = .partialFailure(
                succeeded: result.succeeded.count,
                failed: result.failed.count,
                failedIds: result.failed.map(\.assetId)
            )
        } else {
            let reason = result.failed.first?.reason ?? .unknown
            saveState = .fullFailure(reason)
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func openSystemPhotos() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }
}
