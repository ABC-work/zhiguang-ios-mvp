// Zhiguang/Features/Permission/PermissionView.swift
import SwiftUI
import UIKit

struct PermissionView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var permissionStore: PermissionStateStore
    @State private var isRequesting = false
    @State private var showDeniedAlert = false
    @State private var showManualUploadSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Explanation
            VStack(spacing: 16) {
                Text("📂").font(.system(size: 56))
                Text("需要访问您的相册")
                    .font(.title2).fontWeight(.heavy)
                Text("稚光需要读取您的照片，在本地识别并筛选宝宝照片")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.horizontal, 24)

            // Commitments card
            VStack(alignment: .leading, spacing: 12) {
                Text("我们承诺").font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                commitment(icon: "checkmark.circle.fill", text: "所有分析在设备本地完成")
                commitment(icon: "checkmark.circle.fill", text: "照片不会自动上传到服务器")
                commitment(icon: "checkmark.circle.fill", text: "不会删除您的任何照片")
            }
            .padding(16)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer()

            // Buttons
            VStack(spacing: 10) {
                PrimaryButton(title: "授权访问相册", isLoading: isRequesting) {
                    Task {
                        isRequesting = true
                        await permissionStore.requestAccess()
                        isRequesting = false
                        if permissionStore.isDenied {
                            showDeniedAlert = true
                        }
                    }
                }
                Button("查看完整隐私政策") {}
                    .font(.footnote).foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .onChange(of: permissionStore.state) { _, newState in
            if newState == .full || newState == .limited {
                path.append(AppRoute.babyProfile(isNewBaby: false))
            }
        }
        .alert("相册权限未开启", isPresented: $showDeniedAlert) {
            Button("前往系统设置") { openSystemSettings() }
            Button("手动上传单张照片") { showManualUploadSheet = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("缺少相册权限无法自动扫描。可去设置开启，或手动传图")
        }
        .sheet(isPresented: $showManualUploadSheet) {
            ManualUploadView(path: $path)
        }
        .onAppear {
            permissionStore.refreshFromSystem()
            if permissionStore.canProceed {
                path.append(AppRoute.babyProfile(isNewBaby: false))
            }
        }
    }

    private func commitment(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(.green)
            Text(text).font(.subheadline)
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
