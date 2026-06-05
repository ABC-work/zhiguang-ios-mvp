import Foundation

final class ScanStateCache {
    private let defaults: UserDefaults
    private let resultPrefix = "scanResult."
    private let progressPrefix = "scanProgress."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ result: ScanResult, for babyId: UUID) {
        if let data = try? JSONEncoder().encode(result) {
            defaults.set(data, forKey: resultPrefix + babyId.uuidString)
        }
    }

    func load(for babyId: UUID) -> ScanResult? {
        guard let data = defaults.data(forKey: resultPrefix + babyId.uuidString) else { return nil }
        return try? JSONDecoder().decode(ScanResult.self, from: data)
    }

    func clear(for babyId: UUID) {
        defaults.removeObject(forKey: resultPrefix + babyId.uuidString)
        defaults.removeObject(forKey: progressPrefix + babyId.uuidString)
    }

    func saveProgress(scannedCount: Int, babyId: UUID) {
        defaults.set(scannedCount, forKey: progressPrefix + babyId.uuidString)
    }

    func loadProgress(for babyId: UUID) -> Int {
        defaults.integer(forKey: progressPrefix + babyId.uuidString)
    }
}
