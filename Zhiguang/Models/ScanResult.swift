import Foundation

struct ScanResult: Identifiable, Codable {
    var id: UUID
    var babyProfileId: UUID
    var createdAt: Date
    var scannedCount: Int
    var selectedAssetIds: [String]
    var rejectedAssetIds: [String]
    var allCandidateIds: [String]

    init(id: UUID = UUID(), babyProfileId: UUID, createdAt: Date = .now,
         scannedCount: Int, selectedAssetIds: [String],
         rejectedAssetIds: [String] = [], allCandidateIds: [String]) {
        self.id = id
        self.babyProfileId = babyProfileId
        self.createdAt = createdAt
        self.scannedCount = scannedCount
        self.selectedAssetIds = selectedAssetIds
        self.rejectedAssetIds = rejectedAssetIds
        self.allCandidateIds = allCandidateIds
    }

    mutating func remove(assetId: String) {
        selectedAssetIds.removeAll { $0 == assetId }
        if !rejectedAssetIds.contains(assetId) {
            rejectedAssetIds.append(assetId)
        }
    }

    mutating func restore(assetId: String) {
        rejectedAssetIds.removeAll { $0 == assetId }
        if !selectedAssetIds.contains(assetId) {
            selectedAssetIds.append(assetId)
        }
    }
}

#if DEBUG
extension ScanResult {
    static func stub(selectedIds: [String]) -> ScanResult {
        ScanResult(
            babyProfileId: UUID(),
            scannedCount: selectedIds.count,
            selectedAssetIds: selectedIds,
            allCandidateIds: selectedIds
        )
    }
}
#endif
