// Zhiguang/Features/Onboarding/OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    @Binding var path: NavigationPath
    @StateObject private var vm = OnboardingViewModel()
    @EnvironmentObject var permissionStore: PermissionStateStore
    @EnvironmentObject var babyProfileStore: BabyProfileStore

    private let bullets: [(icon: String, text: String)] = [
        ("camera.fill", "自动扫描最近相册，无需手动挑选"),
        ("brain.head.profile", "AI 识别宝宝照片，过滤模糊和重复"),
        ("lock.shield.fill", "所有处理在设备本地完成，不上传"),
        ("square.and.arrow.down.fill", "一键保存到「稚光精选」相册"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            // Hero
            Text("🌟").font(.system(size: 64)).padding(.bottom, 16)
            Text("从几千张照片里\n挑出宝宝最值得留的 20 张")
                .font(.title2).fontWeight(.heavy)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            Text("本地分析，照片不会默认上传")
                .font(.subheadline).foregroundColor(.secondary)
                .padding(.bottom, 32)

            // Bullets
            VStack(alignment: .leading, spacing: 14) {
                ForEach(bullets, id: \.text) { bullet in
                    HStack(spacing: 14) {
                        Image(systemName: bullet.icon)
                            .frame(width: 24)
                            .foregroundColor(Color(hex: "A78BFA"))
                        Text(bullet.text).font(.subheadline)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // CTA
            VStack(spacing: 10) {
                PrimaryButton(title: "开始整理") {
                    vm.markOnboardingComplete()
                    path.append(AppRoute.permission)
                }
                Button("查看隐私说明") {
                    // No-op for MVP
                }
                .font(.footnote).foregroundColor(.secondary)

                Text("所有图片仅本地设备处理，不上传云端")
                    .font(.caption2).foregroundColor(Color.secondary.opacity(0.6))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationBarHidden(true)
    }
}
