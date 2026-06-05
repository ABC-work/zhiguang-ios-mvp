// Zhiguang/Features/Scanning/ScanningViewModel.swift
import Foundation

@MainActor
final class ScanningViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning(stage: String, progress: Double)
        case noBabyFound
        case emptyLibrary
        case done(ScanResult)
        case failed(String)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.noBabyFound, .noBabyFound), (.emptyLibrary, .emptyLibrary): return true
            case (.scanning(let a, _), .scanning(let b, _)): return a == b
            case (.done(let a), .done(let b)): return a.babyProfileId == b.babyProfileId
            case (.failed(let a), .failed(let b)): return a == b
            default: return false
            }
        }
    }

    @Published var phase: Phase = .idle
    @Published var scannedCount = 0

    let babyId: UUID
    private let photoService: PhotoLibraryServiceProtocol
    private let scoringEngine: ScoringEngine
    private let cache: ScanStateCache

    init(babyId: UUID,
         photoService: PhotoLibraryServiceProtocol,
         scoringEngine: ScoringEngine,
         cache: ScanStateCache) {
        self.babyId = babyId
        self.photoService = photoService
        self.scoringEngine = scoringEngine
        self.cache = cache
    }

    func startScan() async {
        phase = .scanning(stage: "读取照片…", progress: 0)
        let assets = await photoService.fetchCandidateAssets()
        guard !assets.isEmpty else { phase = .emptyLibrary; return }

        phase = .scanning(stage: "识别人像…", progress: 0.2)
        scannedCount = 0
        let scores = await scoringEngine.score(assets: assets) { [weak self] assetId in
            await MainActor.run { self?.scannedCount += 1 }
            return await self?.photoService.loadThumbnail(for: assetId, size: CGSize(width: 100, height: 100))
        }

        phase = .scanning(stage: "生成 Top 20…", progress: 0.9)
        let top = await scoringEngine.selectTop(scores, max: Constants.Scan.maxResultCount)

        if top.isEmpty { phase = .noBabyFound; return }

        let result = ScanResult(
            babyProfileId: babyId,
            scannedCount: assets.count,
            selectedAssetIds: top.map(\.assetId),
            allCandidateIds: top.map(\.assetId)
        )
        cache.save(result, for: babyId)
        phase = .done(result)
    }

    func cancel() {
        phase = .idle
    }
}
