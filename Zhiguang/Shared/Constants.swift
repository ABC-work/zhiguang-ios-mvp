import Foundation

enum Constants {
    enum Album {
        static let name = "稚光精选"
    }
    enum Scan {
        static let maxPhotoCount = 1000
        static let dayRange = 90
        static let batchSize = 50
        static let burstIntervalSeconds: TimeInterval = 2.0
        static let maxResultCount = 20
        static let maxPerBurstGroup = 2
        static let sharpnessThreshold: Double = 50.0
    }
    enum UserDefaultsKey {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastPermissionState = "lastPermissionState"
    }
}
