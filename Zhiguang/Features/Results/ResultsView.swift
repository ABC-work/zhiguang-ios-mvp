// Zhiguang/Features/Results/ResultsView.swift
import SwiftUI

struct ResultsView: View {
    @Binding var path: NavigationPath
    let babyId: UUID
    @EnvironmentObject var permissionStore: PermissionStateStore
    @EnvironmentObject var babyStore: BabyProfileStore
    @EnvironmentObject var deps: AppDependencies
    @StateObject private var vm: ResultsViewModel
    @State private var toast: String?

    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    init(path: Binding<NavigationPath>, babyId: UUID) {
        self._path = path
        self.babyId = babyId
        self._vm = StateObject(wrappedValue: ResultsViewModel(babyId: babyId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if permissionStore.isLimited { PermissionBanner() }

            if vm.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(vm.allCandidateIds, id: \.self) { id in
                            PhotoCardView(
                                assetId: id,
                                thumbnail: vm.thumbnails[id],
                                isRejected: vm.rejectedIds.contains(id),
                                onRemove: { vm.remove(assetId: id) },
                                onRestore: { vm.restore(assetId: id) }
                            )
                        }
                    }
                    .padding(4)
                }

                if !vm.selectedIds.isEmpty {
                    PrimaryButton(title: "保存精选到相册") {
                        path.append(AppRoute.saveComplete(
                            babyId: babyId,
                            savedCount: vm.selectedIds.count
                        ))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("精选 \(vm.selectedIds.count) 张")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("新增宝宝") { handleAddNewBaby() }
            }
        }
        .toast(message: $toast)
        .task { await vm.loadThumbnails() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("📭").font(.system(size: 64))
            Text("暂无宝宝照片").font(.title2).fontWeight(.heavy)
            Text("已移除全部推荐照片").font(.subheadline).foregroundColor(.secondary)
            Spacer()
            VStack(spacing: 10) {
                PrimaryButton(title: "重新全量扫描") {
                    path.append(AppRoute.scanning(babyId: babyId))
                }
                Button("新增宝宝") { handleAddNewBaby() }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
        }
    }

    private func handleAddNewBaby() {
        if !permissionStore.isFull {
            toast = "相册权限不完整，扫描结果可能缺失部分照片"
        }
        path.append(AppRoute.babyProfile(isNewBaby: true))
    }
}
