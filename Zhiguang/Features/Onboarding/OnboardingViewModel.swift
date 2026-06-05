// Zhiguang/Features/Onboarding/OnboardingViewModel.swift
import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    private let defaults: UserDefaults

    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Constants.UserDefaultsKey.hasCompletedOnboarding)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func markOnboardingComplete() {
        defaults.set(true, forKey: Constants.UserDefaultsKey.hasCompletedOnboarding)
    }
}
