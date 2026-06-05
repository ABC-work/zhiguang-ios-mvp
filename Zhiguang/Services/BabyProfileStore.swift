import Foundation
import Combine

@MainActor
final class BabyProfileStore: ObservableObject {
    @Published private(set) var profiles: [BabyProfile] = []
    @Published private(set) var draft: BabyProfile?

    private let defaults: UserDefaults
    private let profilesKey = "babyProfiles"
    private let draftKey = "babyProfileDraft"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ profile: BabyProfile) {
        profiles.append(profile)
        save()
    }

    func update(_ profile: BabyProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
            save()
        }
    }

    func saveDraft(_ profile: BabyProfile) {
        draft = profile
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: draftKey)
        }
    }

    func clearDraft() {
        draft = nil
        defaults.removeObject(forKey: draftKey)
    }

    private func load() {
        if let data = defaults.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([BabyProfile].self, from: data) {
            profiles = decoded
        }
        if let data = defaults.data(forKey: draftKey),
           let decoded = try? JSONDecoder().decode(BabyProfile.self, from: data) {
            draft = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: profilesKey)
        }
    }
}
