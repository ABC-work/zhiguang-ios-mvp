// Zhiguang/Features/ManualUpload/ManualUploadView.swift
import SwiftUI
import PhotosUI

struct ManualUploadView: View {
    @Binding var path: NavigationPath
    @StateObject private var vm = ManualUploadViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("无需授权全部相册，单张上传即可使用 AI 评分")
                    .font(.footnote).foregroundColor(.secondary)
                    .padding(.horizontal, 24)

                PhotosPicker(selection: $vm.selectedItems, maxSelectionCount: 1, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "6C63FF"))
                        Text("点击选择照片").fontWeight(.bold)
                        Text("支持从相册选择单张照片").font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color.secondary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            .foregroundColor(.secondary)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                }
                .onChange(of: vm.selectedItems) { _, _ in Task { await vm.processSelected() } }

                if vm.isProcessing {
                    ProgressView("处理中…")
                }

                if !vm.uploadedImages.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(vm.uploadedImages, id: \.id) { item in
                                Image(item.image, scale: 1, label: Text(""))
                                    .resizable().scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                Spacer()

                Button("去设置开启全相册权限（推荐）") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .font(.footnote).foregroundColor(Color(hex: "6C63FF"))
            }
            .navigationTitle("上传照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { path.removeLast() }
                }
            }
        }
    }
}
