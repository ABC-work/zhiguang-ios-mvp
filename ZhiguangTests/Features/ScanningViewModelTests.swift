// ZhiguangTests/Features/ScanningViewModelTests.swift
import XCTest
@testable import Zhiguang

final class MockPhotoLibraryService: PhotoLibraryServiceProtocol {
    var stubAssets: [PhotoAsset] = []
    func fetchCandidateAssets() async -> [PhotoAsset] { stubAssets }
    func loadThumbnail(for assetId: String, size: CGSize) async -> CGImage? { nil }
    func loadFullImage(for assetId: String) async -> CGImage? { nil }
}

@MainActor
final class ScanningViewModelTests: XCTestCase {
    func test_initialState_isIdle() {
        let vm = ScanningViewModel(
            babyId: UUID(),
            photoService: MockPhotoLibraryService(),
            scoringEngine: ScoringEngine(),
            cache: ScanStateCache(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        )
        XCTAssertEqual(vm.phase, .idle)
    }

    func test_scan_emptyLibrary_producesEmptyResult() async {
        let mock = MockPhotoLibraryService()
        mock.stubAssets = []
        let vm = ScanningViewModel(
            babyId: UUID(),
            photoService: mock,
            scoringEngine: ScoringEngine(),
            cache: ScanStateCache(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        )
        await vm.startScan()
        XCTAssertEqual(vm.phase, .emptyLibrary)
    }
}
