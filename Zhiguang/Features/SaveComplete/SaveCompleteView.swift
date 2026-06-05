// Zhiguang/Features/SaveComplete/SaveCompleteView.swift
import SwiftUI

struct SaveCompleteView: View {
    @Binding var path: NavigationPath
    let babyId: UUID
    let savedCount: Int
    @EnvironmentObject var deps: AppDependencies
    @StateObject private var vm: SaveCompleteViewModel

    init(path: Binding<NavigationPath>, babyId: UUID, savedCount: Int) {
        self._path = path
        self.babyId = babyId
        self.savedCount = savedCount
        // selectedIds loaded from cache — deps not available in init, so load lazily
        self._vm = StateObject(wrappedValue: SaveCompleteViewModel(
            babyId: babyId,
            selectedIds: []
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            switch vm.saveState {
            case .saving:
                savingContent
            case .success(let count):
                successContent(count: count)
            case .partialFailure(let ok, let fail, _):
                partialFailureContent(ok: ok, failed: fail)
            case .fullFailure(let reason):
                fullFailureContent(reason: reason)
            }
            Spacer()
        }
        .navigationTitle("").navigationBarHidden(true)
        .toast(message: $vm.toast)
        .task {
            // Load selected IDs from cache, then save
            let result = deps.scanStateCache.load(for: babyId)
            let ids = result?.selectedAssetIds ?? []
            let svc = deps.albumSaveService
            let cache = deps.scanStateCache
            // Re-create VM with real data
            // (MVP simplification: use the injected service directly)
            let saveResult = await svc.save(assetIds: ids)
            if saveResult.isFullSuccess {
                vm.saveState = .success(count: saveResult.succeeded.count)
            } else if saveResult.isPartialSuccess {
                vm.saveState = .partialFailure(
                    succeeded: saveResult.succeeded.count,
                    failed: saveResult.failed.count,
                    failedIds: saveResult.failed.map(\.assetId)
                )
            } else {
                let reason = saveResult.failed.first?.reason ?? .unknown
                vm.saveState = .fullFailure(reason)
            }
        }
    }

    private var savingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("正在保存精选照片…").foregroundColor(.secondary)
        }
    }

    private func successContent(count: Int) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color(hex: "6C63FF"), lineWidth: 2)
                    .frame(width: 80, height: 80)
                Text("✨").font(.system(size: 36))
            }
            Text("已保存 \(count) 张").font(.title).fontWeight(.heavy)
            Text("精选照片已存入系统相册").foregroundColor(.secondary)
            Label("稚光精选", systemImage: "photo.on.rectangle")
                .font(.subheadline).foregroundColor(Color(hex: "A78BFA"))
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Color(hex: "6C63FF").opacity(0.15))
                .clipShape(Capsule())

            Spacer().frame(height: 24)

            VStack(spacing: 10) {
                PrimaryButton(title: "在系统相册查看") { vm.openSystemPhotos() }
                HStack(spacing: 10) {
                    Button("分享给家人") {
                        vm.toast = "分享功能即将上线"
                    }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
                    Button("新增宝宝") { path.append(AppRoute.babyProfile(isNewBaby: true)) }
                        .buttonStyle(.bordered).frame(maxWidth: .infinity)
                }
                if vm.showHomeButton {
                    Button("回到首页") { path = NavigationPath() }
                        .buttonStyle(.borderless).foregroundColor(.secondary)
                }
                Button("重新整理") {
                    path.append(AppRoute.scanning(babyId: babyId))
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
        }
    }

    private func partialFailureContent(ok: Int, failed: Int) -> some View {
        VStack(spacing: 16) {
            Text("⚠️").font(.system(size: 48))
            Text("部分保存失败").font(.title2).fontWeight(.heavy)
            Text("\(ok) 张成功 / \(failed) 张失败").foregroundColor(.secondary)
            Spacer().frame(height: 8)
            PrimaryButton(title: "重试失败的 \(failed) 张") {
                Task { await vm.performSave() }
            }
            .padding(.horizontal, 24)
            Button("跳过，查看已保存的照片") { vm.openSystemPhotos() }
                .foregroundColor(.secondary)
        }
    }

    private func fullFailureContent(reason: AlbumSaveFailureReason) -> some View {
        VStack(spacing: 16) {
            Text("❌").font(.system(size: 48))
            Text("保存失败").font(.title2).fontWeight(.heavy)
            Group {
                switch reason {
                case .permissionDenied:
                    Text("相册写入权限不足").foregroundColor(.secondary)
                case .storageFull:
                    Text("手机存储空间已满").foregroundColor(.secondary)
                case .unknown:
                    Text("发生未知错误").foregroundColor(.secondary)
                }
            }
            Spacer().frame(height: 8)
            VStack(spacing: 10) {
                switch reason {
                case .permissionDenied:
                    PrimaryButton(title: "前往设置开启相册写入权限") { vm.openSettings() }
                case .storageFull:
                    PrimaryButton(title: "去系统清理存储") { vm.openSettings() }
                case .unknown:
                    PrimaryButton(title: "重试保存") { Task { await vm.performSave() } }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}
