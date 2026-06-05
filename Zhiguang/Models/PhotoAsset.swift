import Foundation
import Photos

struct PhotoAsset: Identifiable {
    var id: String
    var creationDate: Date?
    var pixelWidth: Int
    var pixelHeight: Int

    init(from asset: PHAsset) {
        self.id = asset.localIdentifier
        self.creationDate = asset.creationDate
        self.pixelWidth = asset.pixelWidth
        self.pixelHeight = asset.pixelHeight
    }

    #if DEBUG
    init(id: String, creationDate: Date?, pixelWidth: Int, pixelHeight: Int) {
        self.id = id
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
    #endif
}
