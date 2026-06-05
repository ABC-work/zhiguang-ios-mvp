// Zhiguang/Features/Permission/PermissionViewModel.swift
import Foundation
import UIKit

@MainActor
final class PermissionViewModel: ObservableObject {
    @Published var showDeniedAlert = false
    @Published var isRequesting = false

    private let permissionStore: PermissionStateStore

    init(permissionStore: PermissionStateStore) {
        self.permissionStore = permissionStore
    }

    func requestPermission() async {
        isRequesting = true
        await permissionStore.requestAccess()
        isRequesting = false
        if permissionStore.isDenied {
            showDeniedAlert = true
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
