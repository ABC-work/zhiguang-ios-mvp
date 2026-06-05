import Foundation
import Photos
import Combine

@MainActor
final class PermissionStateStore: ObservableObject {
    @Published var state: PermissionState = .notDetermined

    var isFull: Bool { state == .full }
    var isLimited: Bool { state == .limited }
    var isDenied: Bool { state == .denied }
    var canProceed: Bool { state == .full || state == .limited }

    init() {
        refreshFromSystem()
    }

    func refreshFromSystem() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        state = PermissionState(from: status)
    }

    func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        state = PermissionState(from: status)
    }
}

extension PermissionState {
    init(from status: PHAuthorizationStatus) {
        switch status {
        case .authorized:             self = .full
        case .limited:                self = .limited
        case .denied, .restricted:    self = .denied
        default:                      self = .notDetermined
        }
    }
}
