import Foundation
import Photos

// MARK: - Result types
enum AlbumSaveFailureReason {
    case permissionDenied
    case storageFull
    case unknown
}

struct AlbumSaveFailure {
    var assetId: String
    var reason: AlbumSaveFailureReason
}

struct AlbumSaveResult {
    var succeeded: [String]
    var failed: [AlbumSaveFailure]
    var isFullSuccess: Bool { failed.isEmpty }
    var isPartialSuccess: Bool { !succeeded.isEmpty && !failed.isEmpty }
    var isFullFailure: Bool { succeeded.isEmpty && !failed.isEmpty }
}

// MARK: - Protocol
protocol AlbumSaveServiceProtocol {
    func save(assetIds: [String]) async -> AlbumSaveResult
}

// MARK: - Live Implementation
actor AlbumSaveService: AlbumSaveServiceProtocol {
    func save(assetIds: [String]) async -> AlbumSaveResult {
        guard let albumId = await ensureAlbumExists() else {
            return AlbumSaveResult(
                succeeded: [],
                failed: assetIds.map { AlbumSaveFailure(assetId: $0, reason: .permissionDenied) }
            )
        }
        var succeeded: [String] = []
        var failed: [AlbumSaveFailure] = []
        for assetId in assetIds {
            if await copyAsset(id: assetId, toAlbumId: albumId) {
                succeeded.append(assetId)
            } else {
                failed.append(AlbumSaveFailure(assetId: assetId, reason: .unknown))
            }
        }
        return AlbumSaveResult(succeeded: succeeded, failed: failed)
    }

    private func ensureAlbumExists() async -> String? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", Constants.Album.name)
        let existing = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: fetchOptions)
        if let album = existing.firstObject { return album.localIdentifier }

        var identifier: String?
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCollectionChangeRequest
                    .creationRequestForAssetCollection(withTitle: Constants.Album.name)
                identifier = req.placeholderForCreatedAssetCollection.localIdentifier
            }
        } catch { return nil }
        return identifier
    }

    private func copyAsset(id: String, toAlbumId albumId: String) async -> Bool {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject else { return false }
        let albums = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumId], options: nil)
        guard let album = albums.firstObject else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                guard let req = PHAssetCollectionChangeRequest(for: album) else { return }
                req.addAssets([asset] as NSFastEnumeration)
            }
            return true
        } catch { return false }
    }
}
