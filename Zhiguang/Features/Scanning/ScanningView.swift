// Zhiguang/Features/Scanning/ScanningView.swift
import SwiftUI

struct ScanningView: View {
    @Binding var path: NavigationPath
    let babyId: UUID
    @EnvironmentObject var permissionStore: PermissionStateStore
    @EnvironmentObject var deps: AppDependencies
    @StateObject private var vm: ScanningViewModel

    init(path: Binding<NavigationPath>, babyId: UUID) {
        self._path = path
        self.babyId = babyId
        // vm initialized in onAppear with real deps
        self._vm = StateObject(wrappedValue: ScanningViewModel(
            babyId: babyId,
            photoService: PhotoLibraryService(),
            scoringEngine: ScoringEngine(),
            cache: ScanStateCache()
        ))
    }

    var body: some View {
        VStack(spacing: 24) {
            if permissionStore.isLimited {
                PermissionBanner()
            }

            switch vm.phase {
            case .idle:
                ProgressView()

            case .scanning(let stage, let progress):
                scanningContent(stage: stage, progress: progress)

            case .noBabyFound:
                noBabyFoundContent

            case .emptyLibrary:
                emptyLibraryContent

            case .done:
                Color.clear.onAppear {
                    path.append(AppRoute.results(babyId: babyId))
                }

            case .failed(let msg):
                VStack(spacing: 16) {
                    Text("❌").font(.system(size: 48))
                    Text("扫描失败").font(.title2).fontWeight(.heavy)
                    Text(msg).foregroundColor(.secondary)
                    PrimaryButton(title: "重试") { Task { await vm.startScan() } }
                        .padding(.horizontal, 24)
                }
            }
        }
        .navigationTitle("正在分析")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("取消") { vm.cancel(); path.removeLast() }
                    .foregroundColor(.secondary)
            }
        }
        .task { await vm.startScan() }
    }

    private func scanningContent(stage: String, progress: Double) -> some View {
        VStack(spacing: 20) {
            Text("\(vm.scannedCount)")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
            Text("已扫描").font(.caption).foregroundColor(.secondary)
            ProgressView(value: progress)
                .tint(Color(hex: "6C63FF"))
                .padding(.horizontal, 24)
            Text(stage).font(.footnote).foregroundColor(.secondary)
            Spacer()
            Text("🔒 所有分析在设备本地完成，照片不会上传")
                .font(.caption).foregroundColor(Color(hex: "6C63FF"))
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(hex: "6C63FF").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var noBabyFoundContent: some View {
        VStack(spacing: 16) {
            Text("😶").font(.system(size: 56))
            Text("未发现宝宝照片").font(.title2).fontWeight(.heavy)
            Text("在扫描范围内没有找到宝宝的清晰照片")
                .font(.subheadline).foregroundColor(.secondary)
            Spacer()
            VStack(spacing: 10) {
                PrimaryButton(title: "调整宝宝信息") {
                    path.append(AppRoute.babyProfile(isNewBaby: false))
                }
                Button("全量扩容扫描") { Task { await vm.startScan() } }
                    .buttonStyle(.bordered)
                Button("取消，返回上次结果") { path.removeLast() }
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var emptyLibraryContent: some View {
        VStack(spacing: 16) {
            Text("📭").font(.system(size: 56))
            Text("相册为空").font(.title2).fontWeight(.heavy)
            Text("暂无系统照片，前往相册添加图片后再试")
                .font(.subheadline).foregroundColor(.secondary)
            Spacer()
            VStack(spacing: 10) {
                Button("手动上传单张照片") { path.append(AppRoute.manualUpload) }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
        }
    }
}
