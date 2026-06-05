import SwiftUI

@main
struct ZhiguangApp: App {
    @StateObject private var permissionStore = PermissionStateStore()
    @StateObject private var babyProfileStore = BabyProfileStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(permissionStore)
                .environmentObject(babyProfileStore)
                .preferredColorScheme(.dark)
        }
    }
}
