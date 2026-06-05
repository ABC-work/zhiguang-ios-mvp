import SwiftUI

// MARK: - App Dependencies Container
class AppDependencies: ObservableObject {
    let scanStateCache = ScanStateCache()
    let photoLibraryService: PhotoLibraryServiceProtocol = PhotoLibraryService()
    let scoringEngine = ScoringEngine()
    let albumSaveService: AlbumSaveServiceProtocol = AlbumSaveService()
}

@main
struct ZhiguangApp: App {
    @StateObject private var permissionStore = PermissionStateStore()
    @StateObject private var babyProfileStore = BabyProfileStore()
    @StateObject private var appDeps = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(permissionStore)
                .environmentObject(babyProfileStore)
                .environmentObject(appDeps)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var permissionStore: PermissionStateStore
    @EnvironmentObject var babyProfileStore: BabyProfileStore
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingView(path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    route.view(path: $path)
                }
        }
        .onAppear { permissionStore.refreshFromSystem() }
    }
}

// MARK: - App Routes
enum AppRoute: Hashable {
    case permission
    case babyProfile(isNewBaby: Bool)
    case scanning(babyId: UUID)
    case results(babyId: UUID)
    case saveComplete(babyId: UUID, savedCount: Int)
    case manualUpload

    @ViewBuilder
    func view(path: Binding<NavigationPath>) -> some View {
        switch self {
        case .permission:
            PermissionView(path: path)
        case .babyProfile(let isNew):
            BabyProfileView(path: path, isNewBaby: isNew)
        case .scanning(let babyId):
            ScanningView(path: path, babyId: babyId)
        case .results(let babyId):
            ResultsView(path: path, babyId: babyId)
        case .saveComplete(let babyId, let count):
            SaveCompleteView(path: path, babyId: babyId, savedCount: count)
        case .manualUpload:
            ManualUploadView(path: path)
        }
    }
}
