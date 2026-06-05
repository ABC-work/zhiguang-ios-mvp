// Zhiguang/Features/BabyProfile/BabyProfileViewModel.swift
import Foundation
import Combine

@MainActor
final class BabyProfileViewModel: ObservableObject {
    @Published var nickname: String = ""
    @Published var birthday: Date? = nil
    @Published var gender: BabyProfile.Gender? = nil
    @Published var showNicknameError = false

    var canProceed: Bool { !nickname.trimmingCharacters(in: .whitespaces).isEmpty }

    private let store: BabyProfileStore
    private var editingProfile: BabyProfile?

    init(store: BabyProfileStore, prefillFrom profile: BabyProfile? = nil) {
        self.store = store
        if let p = profile ?? store.draft {
            nickname = p.nickname
            birthday = p.birthday
            gender = p.gender
            editingProfile = p
        }
    }

    /// Returns true if validation passes and profile was saved
    @discardableResult
    func tryProceed() -> Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showNicknameError = true
            return false
        }
        showNicknameError = false
        let profile: BabyProfile
        if var existing = editingProfile {
            existing.nickname = trimmed
            existing.birthday = birthday
            existing.gender = gender
            store.update(existing)
            profile = existing
        } else {
            let new = BabyProfile(nickname: trimmed, birthday: birthday, gender: gender)
            store.add(new)
            profile = new
        }
        store.clearDraft()
        return true
    }

    func saveDraft() {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let draft = BabyProfile(nickname: trimmed, birthday: birthday, gender: gender)
        store.saveDraft(draft)
    }

    func currentProfileId() -> UUID? {
        store.profiles.last?.id
    }
}
