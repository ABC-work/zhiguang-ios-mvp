// ZhiguangTests/Features/BabyProfileViewModelTests.swift
import XCTest
@testable import Zhiguang

final class BabyProfileViewModelTests: XCTestCase {
    func test_canProceed_falseWhenNicknameEmpty() {
        let vm = BabyProfileViewModel(store: BabyProfileStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        vm.nickname = ""
        XCTAssertFalse(vm.canProceed)
    }

    func test_canProceed_trueWhenNicknameNonEmpty() {
        let vm = BabyProfileViewModel(store: BabyProfileStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        vm.nickname = "小豆豆"
        XCTAssertTrue(vm.canProceed)
    }

    func test_tryProceed_setsNicknameError_whenEmpty() {
        let vm = BabyProfileViewModel(store: BabyProfileStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        vm.nickname = ""
        let proceeded = vm.tryProceed()
        XCTAssertFalse(proceeded)
        XCTAssertTrue(vm.showNicknameError)
    }

    func test_tryProceed_savesProfile_whenValid() {
        let store = BabyProfileStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let vm = BabyProfileViewModel(store: store)
        vm.nickname = "小橙子"
        let proceeded = vm.tryProceed()
        XCTAssertTrue(proceeded)
        XCTAssertEqual(store.profiles.first?.nickname, "小橙子")
    }
}
