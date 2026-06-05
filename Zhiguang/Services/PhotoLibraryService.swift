import Foundation
import Photos
import UIKit

// MARK: - Protocol
protocol PhotoLibraryServiceProtocol {
    func fetchCandidateAssets() async -> [PhotoAsset]
    func loadThumbnail(for assetId: String, size: CGSize) async -> CGImage?
    func loadFullImage(for assetId: String) async -> CGImage?
}

// MARK: - Live Implementation
actor PhotoLibraryService: PhotoLibraryServiceProtocol {
    func fetchCandidateAssets() async -> [PhotoAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )

        let allPhotos = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        allPhotos.enumerateObjects { asset, _, stop in
            assets.append(asset)
            if assets.count >= Constants.Scan.maxPhotoCount { stop.pointee = true }
        }

        return assets
            .filter { !$0.mediaSubtypes.contains(.photoScreenshot) }
            .map { PhotoAsset(from: $0) }
    }

    func loadThumbnail(for assetId: String, size: CGSize) async -> CGImage? {
        await withCheckedContinuation { continuation in
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = result.firstObject else {
                continuation.resume(returning: nil); return
            }
            let opts = PHImageRequestOptions()
            opts.isSynchronous = false
            opts.deliveryMode = .fastFormat
            opts.resizeMode = .fast
            PHImageManager.default().requestImage(
                for: asset, targetSize: size,
                contentMode: .aspectFit, options: opts
            ) { image, _ in
                continuation.resume(returning: image?.cgImage)
            }
        }
    }

    func loadFullImage(for assetId: String) async -> CGImage? {
        await withCheckedContinuation { continuation in
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = result.firstObject else {
                continuation.resume(returning: nil); return
            }
            let opts = PHImageRequestOptions()
            opts.isSynchronous = false
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset, targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit, options: opts
            ) { image, _ in
                continuation.resume(returning: image?.cgImage)
            }
        }
    }
}
