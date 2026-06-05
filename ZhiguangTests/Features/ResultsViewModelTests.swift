// ZhiguangTests/Features/ResultsViewModelTests.swift
import XCTest
@testable import Zhiguang

@MainActor
final class ResultsViewModelTests: XCTestCase {
    func test_remove_photo_updatesSelectedAndRejected() {
        let cache = ScanStateCache(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let babyId = UUID()
        let result = ScanResult(babyProfileId: babyId, scannedCount: 3,
                                selectedAssetIds: ["a","b","c"], allCandidateIds: ["a","b","c"])
        cache.save(result, for: babyId)
        let vm = ResultsViewModel(babyId: babyId, cache: cache)
        vm.remove(assetId: "b")
        XCTAssertFalse(vm.selectedIds.contains("b"))
        XCTAssertTrue(vm.rejectedIds.contains("b"))
    }

    func test_restore_photo() {
        let cache = ScanStateCache(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let babyId = UUID()
        let result = ScanResult(babyProfileId: babyId, scannedCount: 3,
                                selectedAssetIds: ["a","c"],
                                rejectedAssetIds: ["b"],
                                allCandidateIds: ["a","b","c"])
        cache.save(result, for: babyId)
        let vm = ResultsViewModel(babyId: babyId, cache: cache)
        vm.restore(assetId: "b")
        XCTAssertTrue(vm.selectedIds.contains("b"))
        XCTAssertFalse(vm.rejectedIds.contains("b"))
    }

    func test_isEmpty_whenAllRemoved() {
        let cache = ScanStateCache(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let babyId = UUID()
        let result = ScanResult(babyProfileId: babyId, scannedCount: 1,
                                selectedAssetIds: ["a"], allCandidateIds: ["a"])
        cache.save(result, for: babyId)
        let vm = ResultsViewModel(babyId: babyId, cache: cache)
        vm.remove(assetId: "a")
        XCTAssertTrue(vm.isEmpty)
    }
}
