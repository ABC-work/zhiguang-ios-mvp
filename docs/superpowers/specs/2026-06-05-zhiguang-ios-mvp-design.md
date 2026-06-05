# 稚光 iOS MVP · 设计规格文档

**版本**：v3  
**日期**：2026-06-05  
**技术栈**：SwiftUI + PhotoKit + Vision · iOS 16+ · MVVM  
**参考文件**：`docs/design/navigation-flow.html`、`docs/design/mockups.html`

---

## 1. 产品目标

用户授权相册后，App 在本地扫描最近 90 天或最近 1000 张照片（取并集），自动挑出宝宝照片中质量最高的 20 张，用户可手动移除/恢复，并一键保存到系统相册「稚光精选」。

**核心验证点**：AI 精选是否能明显减少父母挑照片的时间。

**明确不做（MVP 范围外）**：
- 云备份、家庭账号、跨设备同步
- 长辈专属分享页、语音留言
- 成长节点自动成册
- 视频片段提取
- 会员体系
- 系统照片删除/清理功能
- 手动补选照片进入 Top 20

---

## 2. 技术决策

| 项目 | 决策 |
|---|---|
| 框架 | SwiftUI（纯原生） |
| 相册读取 | PhotoKit（`PHPhotoLibrary`） |
| 图像分析 | Vision（`VNDetectFaceRectanglesRequest`、`VNDetectFaceLandmarksRequest`） |
| 架构模式 | MVVM，ViewModel 用 `@MainActor + ObservableObject`，Services 用 `actor` |
| 最低 iOS 版本 | iOS 16 |
| 扫描范围 | 最近 90 天 OR 最近 1000 张，取并集（上限 1000 张） |
| 本地存储 | UserDefaults（轻量状态）+ FileManager（扫描缓存） |
| 手动补选 | 不支持 |

---

## 3. 页面导航流程

**标准顺序（首次用户）**：

```
PAGE 1 启动说明页
    ↓ 点击「开始整理」
PAGE 3 相册权限页
    ↓ 完全授权 / 部分授权
PAGE 2 宝宝资料页（昵称必填）
    ↓ 点击「下一步」
PAGE 4 扫描进度页
    ↓ 扫描完成
PAGE 5 宝宝 Top 20 结果页
    ↓ 点击「保存精选」
PAGE 6 保存完成页
```

**设计理由**：权限前置（PAGE 3 先于 PAGE 2）符合 Apple 审核规范，用户理解「授权相册才能识别宝宝照片」，授权意愿更高，规避因权限弹窗时机不合理被拒审风险。

### 特殊路径

| 场景 | 行为 |
|---|---|
| 老用户冷启动（已授权 + 有数据） | 启动页 → 直接跳 PAGE 5 结果页 |
| 引导中途冷启动 | 从中断页继续（权限断点→权限页，资料断点→资料页，扫描断点→扫描页） |
| 完全授权 | 正常流程，无 Banner |
| 部分授权 | 放行，全链路挂载黄色 Banner，不可关闭，权限恢复后自动消失 |
| 拒绝权限 | 弹窗：①去系统设置 ②手动上传单张照片（折中方案） |
| 从系统设置返回 | 强制落回权限页，重新触发授权弹窗 |
| 后续系统关闭权限 | 从任意页面切回 App，弹窗拦截，跳转权限页 |
| 「重新整理」 | 有权限 → 直接进扫描页；权限失效 → 先落权限页 |
| 新增宝宝 | 结果页/保存页入口 → 资料页（昵称必填，草稿自动回填）→ 独立触发扫描 → 独立 Top 20 |
| 多宝宝切换 | 结果页顶部下拉，切换时缓存各自筛选状态，不重置 |

---

## 4. 各页面规格

### PAGE 1 · 启动说明页

**目的**：让用户理解 App 本地处理、不上传云端的核心理念。

**内容**：
- 标题：「从几千张照片里，挑出宝宝最值得留下的 20 张」
- 4 个要点：自动扫描 / AI 识别 / 本地处理 / 一键保存
- 主按钮：开始整理
- 底部：查看隐私说明（可跳转完整隐私政策，合规锚点 1/3）
- 底部小字：「所有图片仅本地设备处理，不上传云端，符合 Apple 隐私规范」

**返回用户**：已授权 + 有数据 → 冷启动直接跳结果页，不显示本页。

**设置入口**（后续版本）：设置页内提供「重新走新手引导」开关。

---

### PAGE 3 · 相册权限页（流程第 2 步）

**目的**：申请系统相册读取权限，提前说明用途，提升授权率。

**权限弹窗前说明文案**：
> 稚光需要访问您的照片，用于在本地分析并筛选宝宝照片。所有处理默认在您的设备上完成，照片不会自动上传。

**三种权限分支**：

| 结果 | 行为 |
|---|---|
| 完全授权 | 正常进入宝宝资料页，无任何提示 |
| 部分授权 | 放行，文案「仅可访问部分相册，扫描范围受限，筛选结果可能不完整」；全局 PermissionState 标记为 `.limited`；全链路 Banner 透传 |
| 拒绝权限 | 弹窗双选项：①【前往系统设置开启权限】②【手动上传单张照片】 |

**权限失效回流**：用户从系统设置返回 App → 弹窗提示 → 重新触发授权，强制落回本页，不允许向下走流程。

**合规**：底部可查看完整隐私政策（合规锚点 2/3）。

---

### PAGE 2 · 宝宝资料页（流程第 3 步）

**字段规格**：

| 字段 | 规则 |
|---|---|
| 昵称 | **必填**。空值点击「下一步」触发输入框红框 + 悬浮提示「请填写宝宝昵称，用于照片分组」。不禁用按钮 |
| 生日 | 可选。字段下方小字「完善生日可精准筛选对应月龄成长照片」 |
| 性别 | 可选（男宝 / 女宝 / 暂不填） |

**草稿**：新增宝宝中途退出时，本地缓存已填信息，下次进入自动回填。

**新增宝宝入口**：从 PAGE 5 / PAGE 6 点击「新增宝宝」跳转本页，填写完成后独立触发扫描，生成对应宝宝的独立 Top 20。

---

### PAGE 4 · 扫描进度页

**UI 元素**：
- 右上角常驻【取消】按钮（取消后：有历史数据 → 结果页；新宝宝首次扫描 → 资料页）
- 大数字显示「已扫描 / 总数」
- 进度条（渐变色）
- 阶段列表：读取照片 / 过滤截图·二维码 / 识别人像 / 清晰度评分 / 生成 Top 20
- 底部：「🔒 所有分析在设备本地完成，照片不会上传」

**部分授权**：页面底部固定悬浮小字「当前仅获取部分相册，部分照片无法被扫描识别」。

**中途退出**：本地缓存扫描进度（`ScanStateCache`），下次进入续扫，不从头重来。

**异常分支**：

| 场景 | 处理 |
|---|---|
| 相册为空 | 展示空页面 + 双按钮：①【前往系统相册添加图片】 ②【手动上传单张照片】 |
| 未识别到宝宝照片 | 弹窗三选项：①【调整宝宝信息】→ 跳资料页 ②【全量扩容扫描】→ 原地重扫 ③【取消，返回上次结果】 |
| 扫描失败 | 提示错误原因 + 重试按钮 |

---

### PAGE 5 · 宝宝 Top 20 结果页

**展示内容**：
- 顶部宝宝切换下拉（多宝宝时）
- 部分授权 Banner（固定，不可关闭）
- 推荐理由 Tag 行：笑脸清晰 / 眼睛睁开 / 画质出色 / 亲子合影 / 同组最佳 / 生日场景
- 照片 Grid（3列）：缩略图 + 评分角标 + 移除按钮
- 已移除照片置灰，点击可恢复
- 底部：保存精选 按钮

**操作规格**：
- 移除：照片置灰，名额不自动补位
- 恢复：点击置灰照片恢复
- 预览大图：点击照片（非移除按钮区域）全屏预览
- 不支持手动从相册补选

**多宝宝切换**：切换时缓存各自的移除/精选状态，不重置。

**新增宝宝跳转前置校验**：若当前权限为 `.limited` 或 `.denied`，弹窗提醒「相册权限不完整，新增宝宝扫描会缺失部分照片，建议先开启全量权限」，提供：①先开启权限 ②继续新增（扫描可能不完整）。

**空状态**（全部移除后）：展示「暂无宝宝照片」+ 双按钮：①重新全量扫描 ②新增宝宝。

---

### PAGE 6 · 保存完成页

**成功状态**：
- 展示已保存数量 + 「稚光精选」相册名称
- 按钮：在系统相册查看 / 分享给家人 / 新增宝宝
- 文字入口：重新整理

**分享状态**：
- 成功：留存本页，Toast「分享完成」+ 出现【回到首页】快捷按钮
- 用户取消：Toast「分享已取消」，不跳转不刷新
- 系统失败：Toast「分享失败，请重试」，不跳转

**重新整理分支**：
- 权限有效 → 直接进扫描页（跳过权限页和资料页）
- 权限失效 → 落权限页，重新授权后进扫描页

**失败状态精细化**：

| 失败原因 | 处理 |
|---|---|
| 相册写入权限不足 | 展示原因 + 【前往设置开启相册写入权限】 |
| 手机存储空间已满 | 提示 + 【去系统清理存储】 |
| 系统未知报错 | 错误文案 + 【重试保存】，停留当前页 |
| 部分照片保存失败 | 「X 张成功 / Y 张失败」+ 【重试失败项】 |

---

## 5. 数据模型

```swift
// 权限状态（全局透传）
enum PermissionState {
    case full       // 完全授权
    case limited    // 部分授权
    case denied     // 拒绝
    case notDetermined
}

struct BabyProfile: Identifiable, Codable {
    var id: UUID
    var nickname: String          // 必填
    var birthday: Date?           // 可选
    var gender: Gender?           // 可选
    enum Gender: String, Codable { case boy, girl }
}

struct PhotoAsset: Identifiable {
    var id: String                // PHAsset.localIdentifier
    var uri: String
    var width: Int
    var height: Int
    var creationDate: Date?
    var mediaType: PHAssetMediaType
}

struct PhotoScore {
    var assetId: String
    var totalScore: Float         // 综合分 0-10
    var faceScore: Float          // 人脸置信度
    var sharpnessScore: Float     // 清晰度
    var expressionScore: Float    // 表情
    var compositionScore: Float   // 构图
    var duplicatePenalty: Float   // 连拍惩罚（负值）
    var reasons: [String]         // 推荐理由文案
}

struct ScanResult: Identifiable, Codable {
    var id: UUID
    var babyProfileId: UUID
    var createdAt: Date
    var scannedCount: Int
    var selectedAssetIds: [String]   // 当前精选（移除后减少）
    var rejectedAssetIds: [String]   // 用户主动移除的
    var allCandidateIds: [String]    // 所有候选（含移除的，用于恢复）
}
```

---

## 6. 项目结构

```
ZhiguangApp/
├── App/
│   └── ZhiguangApp.swift
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── OnboardingViewModel.swift
│   ├── Permission/
│   │   ├── PermissionView.swift
│   │   └── PermissionViewModel.swift
│   ├── BabyProfile/
│   │   ├── BabyProfileView.swift
│   │   └── BabyProfileViewModel.swift
│   ├── Scanning/
│   │   ├── ScanningView.swift
│   │   └── ScanningViewModel.swift
│   ├── Results/
│   │   ├── ResultsView.swift
│   │   ├── ResultsViewModel.swift
│   │   └── PhotoCardView.swift
│   ├── SaveComplete/
│   │   ├── SaveCompleteView.swift
│   │   └── SaveCompleteViewModel.swift
│   └── ManualUpload/
│       ├── ManualUploadView.swift
│       └── ManualUploadViewModel.swift
├── Services/
│   ├── PhotoLibraryService.swift    // PhotoKit 封装，actor
│   ├── ScoringEngine.swift          // Vision 评分，actor
│   ├── AlbumSaveService.swift       // 写入「稚光精选」
│   ├── ScanStateCache.swift         // 断点续扫，本地持久化
│   ├── PermissionStateStore.swift   // 全局权限状态，ObservableObject
│   └── BabyProfileStore.swift       // 多宝宝数据 + 草稿管理
├── Models/
│   ├── BabyProfile.swift
│   ├── PhotoAsset.swift
│   ├── PhotoScore.swift
│   ├── ScanResult.swift
│   └── PermissionState.swift
└── Shared/
    ├── Components/
    │   ├── PermissionBanner.swift   // 全链路黄色 Banner 组件
    │   ├── PrimaryButton.swift
    │   └── ToastView.swift
    ├── Extensions/
    └── Constants.swift
```

---

### PAGE M · 手动上传单张（降级方案）

**触发入口**：
1. PAGE 3 拒绝权限弹窗 → 选择②「手动上传单张照片」
2. PAGE 4 相册为空 → 选择②「手动上传单张照片」

**目的**：为拒绝授权或相册为空的用户提供折中路径，不强制走全相册扫描。

**UI 规格**：
- 中央虚线上传区域，点击触发系统图片选择器（`PHPickerViewController`，仅允许单张 image）
- 说明文案：「可多次上传，逐张添加宝宝照片，AI 将对每张照片单独评分」
- 底部提示：「去设置开启全相册权限（推荐）」

**行为**：
- 每次选择一张图片，完成 Vision 评分后展示该张照片的评分和推荐理由
- 可累积上传多张，累积结果与正常扫描结果合并进入结果页展示
- 不触发全量扫描流程

---

## 7. 评分算法

### 7.1 扫描范围

读取 PHAsset，筛选条件：`creationDate >= 90天前` OR `按时间倒序前1000张`，取并集，上限 1000 张，仅取 `mediaType == .image`。

### 7.2 预过滤

- 过滤截图：`PHAsset.mediaSubtype` 包含 `.photoScreenshot`
- 过滤二维码/文档：通过缩略图尺寸比例过滤极端长宽比

### 7.3 清晰度评分

对每张照片生成 100×100 缩略图，计算拉普拉斯方差：
- 方差 < 阈值（待标定，建议 50）：直接丢弃
- 方差值归一化为 0-10 分

### 7.4 人脸检测（VNDetectFaceRectanglesRequest）

- 无人脸：丢弃
- 人脸数量和面积占画面比例 → `faceScore`（0-10）

### 7.5 表情评分（VNDetectFaceLandmarksRequest）

- 眼睛开合度（landmarks.leftEye / rightEye）
- 嘴角曲率（landmarks.outerLips）
- 综合为 `expressionScore`（0-10）

### 7.6 构图评分

- 人脸边界框是否完全在画面内（部分出界扣分）
- 人脸中心距画面中心的偏移比例
- 归一化为 `compositionScore`（0-10）

### 7.7 连拍分组

- 按 `creationDate` 排序，时间差 < 2 秒视为同组
- 同组内按总分排序，最多保留 2 张
- 其余照片 `duplicatePenalty = -2.0`（参与排序但拉低）

### 7.8 综合评分

```swift
totalScore = faceScore * 0.30
           + sharpnessScore * 0.25
           + expressionScore * 0.20
           + compositionScore * 0.15
           + sceneScore * 0.10
           + duplicatePenalty
```

排序后取前 20 张，照片数量不足 20 张时按实际数量生成。

---

## 8. 权限全链路规则

| 权限状态 | 冷启动行为 | 全链路 Banner | 退出重进 |
|---|---|---|---|
| 完全授权 | 有数据直跳结果页 | 无 Banner | 正常 |
| 部分授权 | 有数据直跳结果页 | 全页面顶部固定黄色 Banner，不可关闭，权限恢复后自动消失 | 冷启动保留 Banner |
| 拒绝权限 | 有数据仍停权限页 | 弹窗常驻，无法往下走 | 每次冷启动强制拦截权限页 |

`PermissionStateStore` 作为 `@EnvironmentObject` 注入根视图，全链路访问。

---

## 9. 合规要求

1. **隐私协议三锚点**：启动页 / 权限页 / 设置页，均可查看完整隐私政策
2. **权限弹窗前置说明**：iOS 系统弹窗前，App 内先展示说明文案
3. **相册读取 Info.plist**：`NSPhotoLibraryUsageDescription` 必须填写，文案需明确说明本地处理
4. **相册写入 Info.plist**：`NSPhotoLibraryAddUsageDescription`
5. **禁止删除用户照片**：App 内不出现任何删除/清理系统照片的功能
6. **默认不上传**：所有照片处理在设备本地完成，不自动上传

---

## 10. 异常状态一览

| 场景 | 处理方式 |
|---|---|
| 拒绝相册读取权限 | 双选项：去设置 / 手动上传单张 |
| 部分授权 | 放行 + 全链路 Banner 提示 |
| 相册为空 | 空页面 + 双路径按钮 |
| 扫描照片少于 20 张 | 按实际数量生成，不阻塞保存 |
| 未识别到宝宝照片 | 三选项弹窗（调整信息 / 全量扫描 / 取消） |
| 扫描中途退出 | 本地缓存进度，下次续扫 |
| 结果页全部移除 | 空状态双按钮（重新扫描 / 新增宝宝） |
| 新增宝宝时权限不全 | 前置校验弹窗 |
| 保存失败（权限不足） | 提示 + 去设置按钮 |
| 保存失败（存储已满） | 提示 + 去清理存储 |
| 保存失败（未知错误） | 提示 + 重试按钮，停留当前页 |
| 部分照片保存失败 | 成功/失败数量展示 + 重试失败项 |
| 分享取消 | Toast 提示，不跳转 |
| 分享失败 | Toast 提示，不跳转 |

---

## 11. 验收标准

- [ ] 新用户可完整走通：启动 → 权限 → 资料 → 扫描 → 结果 → 保存
- [ ] 首次用户在 3 分钟内完成授权、扫描并看到 Top 20（测试集：≤1000 张）
- [ ] 读取 1000 张照片时 App 不崩溃、不明显卡死
- [ ] 扫描页有明确进度条和阶段文案
- [ ] 扫描中途退出后可续扫
- [ ] 部分授权时全链路 Banner 正确展示且不可关闭
- [ ] 拒绝权限时弹窗双选项正常跳转
- [ ] 拒绝权限冷启动停在权限页
- [ ] 从系统设置返回落回权限页并重新触发授权
- [ ] 昵称为空点击下一步触发内联错误提示（非禁用按钮）
- [ ] 扫描完成后生成最多 20 张推荐照片
- [ ] 每张推荐照片至少展示 1 个推荐理由
- [ ] 用户可移除和恢复推荐照片
- [ ] 结果全部移除后展示空状态双按钮
- [ ] 用户可保存结果到系统相册「稚光精选」
- [ ] 保存失败展示对应失败原因和操作入口
- [ ] 保存成功后系统相册中能看到「稚光精选」
- [ ] 分享成功/取消/失败分别展示对应 Toast
- [ ] 所有照片默认不上传，不出现系统照片删除功能

---

## 12. 建议成功指标（埋点）

- Top 20 保存率
- 推荐采纳率（AI 推荐中用户最终保留比例）
- 扫描完成率
- 扫描平均耗时
- 相册权限授权率（完全授权 vs 部分授权 vs 拒绝）
- 保存失败率及失败原因分布
- 用户手动移除比例
- 未识别到宝宝照片比例
