// Zhiguang/Features/BabyProfile/BabyProfileView.swift
import SwiftUI

struct BabyProfileView: View {
    @Binding var path: NavigationPath
    let isNewBaby: Bool
    @EnvironmentObject var babyStore: BabyProfileStore
    @StateObject private var vm: BabyProfileViewModel
    @State private var showDatePicker = false

    init(path: Binding<NavigationPath>, isNewBaby: Bool) {
        self._path = path
        self.isNewBaby = isNewBaby
        self._vm = StateObject(wrappedValue: BabyProfileViewModel(store: BabyProfileStore()))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("填写宝宝信息，帮助 AI 更准确地识别照片")
                    .font(.footnote).foregroundColor(.secondary)

                // Nickname field
                VStack(alignment: .leading, spacing: 6) {
                    Label("宝宝昵称", systemImage: "person.fill")
                        .font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                    HStack {
                        TextField("请输入昵称", text: $vm.nickname)
                            .onChange(of: vm.nickname) { _, _ in
                                if !vm.nickname.isEmpty { vm.showNicknameError = false }
                            }
                        if !vm.nickname.isEmpty {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(vm.showNicknameError ? Color.red : Color.clear, lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    if vm.showNicknameError {
                        Text("请填写宝宝昵称，用于照片分组")
                            .font(.caption).foregroundColor(.red)
                    }
                }

                // Birthday field
                VStack(alignment: .leading, spacing: 6) {
                    Label("出生日期", systemImage: "calendar")
                        .font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                    Button {
                        showDatePicker.toggle()
                    } label: {
                        HStack {
                            Text(vm.birthday.map { $0.formatted(date: .long, time: .omitted) } ?? "选择日期")
                                .foregroundColor(vm.birthday == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    if showDatePicker {
                        DatePicker("", selection: Binding(
                            get: { vm.birthday ?? Date() },
                            set: { vm.birthday = $0 }
                        ), in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    }
                    Text("完善生日可精准筛选对应月龄成长照片")
                        .font(.caption).foregroundColor(.secondary)
                }

                // Gender picker
                VStack(alignment: .leading, spacing: 6) {
                    Label("性别", systemImage: "person.2.fill")
                        .font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                    HStack(spacing: 10) {
                        ForEach([nil, BabyProfile.Gender.boy, .girl] as [BabyProfile.Gender?], id: \.self) { g in
                            Button {
                                vm.gender = g
                            } label: {
                                Text(genderLabel(for: g))
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(vm.gender == g ? Color(hex: "6C63FF").opacity(0.3) : Color.secondary.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(vm.gender == g ? Color(hex: "6C63FF") : Color.clear, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(isNewBaby ? "新增宝宝" : "宝宝资料")
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("跳过") {
                    navigateNext()
                }
                .foregroundColor(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "下一步，开始扫描") {
                if vm.tryProceed(), let id = vm.currentProfileId() {
                    path.append(AppRoute.scanning(babyId: id))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onDisappear { vm.saveDraft() }
    }

    private func navigateNext() {
        let _ = vm.tryProceed()
        if let id = vm.currentProfileId() {
            path.append(AppRoute.scanning(babyId: id))
        }
    }

    private func genderLabel(for gender: BabyProfile.Gender?) -> String {
        switch gender {
        case .boy: return "👦 男宝"
        case .girl: return "👧 女宝"
        case nil: return "暂不填"
        }
    }
}
