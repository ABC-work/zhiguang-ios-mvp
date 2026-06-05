# 稚光 iOS MVP · Xcode 接入步骤

## 1. 创建 Xcode 项目

1. 打开 Xcode → File → New → Project → iOS → App
2. 配置：
   - Product Name: `Zhiguang`
   - Bundle Identifier: `com.abc-work.zhiguang`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Include Tests: ✅
3. Deployment Target: **iOS 16.0**
4. 保存到本地，然后将 `Zhiguang/` 目录下所有 `.swift` 文件拖入 Xcode 项目

## 2. Info.plist 权限 Keys

在 Xcode → Target → Info 页面添加：

| Key | Value |
|---|---|
| NSPhotoLibraryUsageDescription | 稚光需要访问您的照片，用于在本地分析并筛选宝宝照片。所有处理默认在您的设备上完成，照片不会自动上传。 |
| NSPhotoLibraryAddUsageDescription | 稚光需要将精选照片保存到系统相册「稚光精选」。 |

## 3. 目录结构

将 repo 中 `Zhiguang/` 目录下所有文件添加到 Xcode 项目，按以下 Group 组织：

```
Zhiguang (项目根)
├── Models/
├── Services/
├── Shared/
│   └── Components/
└── Features/
    ├── Onboarding/
    ├── Permission/
    ├── BabyProfile/
    ├── Scanning/
    ├── Results/
    ├── SaveComplete/
    └── ManualUpload/
```

## 4. 验收

Build (Cmd+B) → 无编译错误  
Test (Cmd+U) → 所有单元测试通过  
Run on Simulator → 完整走通引导流程
