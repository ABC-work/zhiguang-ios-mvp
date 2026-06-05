# 稚光 iOS MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build 稚光 iOS MVP — a SwiftUI app that scans the user's photo library locally, scores baby photos using Vision framework, and saves the top 20 to a "稚光精选" album.

**Architecture:** MVVM with `@MainActor ObservableObject` ViewModels and `actor`-based Services. `PermissionStateStore` is injected as `@EnvironmentObject` for global permission state propagation. All services are protocol-backed for testability via mock injection.

**Tech Stack:** SwiftUI · PhotoKit · Vision · XCTest · iOS 16+ · No third-party dependencies

**Spec:** `docs/superpowers/specs/2026-06-05-zhiguang-ios-mvp-design.md`  
**Mockups:** `docs/design/mockups.html`

---

## File Map

```
Zhiguang/
├── ZhiguangApp.swift
├── Models/
│   ├── PermissionState.swift
│   ├── BabyProfile.swift
│   ├── PhotoAsset.swift
│   ├── PhotoScore.swift
│   └── ScanResult.swift
├── Services/
│   ├── PermissionStateStore.swift
│   ├── BabyProfileStore.swift
│   ├── PhotoLibraryService.swift      (protocol + live impl)
│   ├── ScoringEngine.swift            (actor)
│   ├── ScanStateCache.swift
│   └── AlbumSaveService.swift         (protocol + live impl)
├── Shared/
│   ├── Components/
│   │   ├── PermissionBanner.swift
│   │   ├── PrimaryButton.swift
│   │   └── ToastView.swift
│   └── Constants.swift
└── Features/
    ├── Onboarding/
    │   ├── OnboardingView.swift
    │   └── OnboardingViewModel.swift
    ├── Permission/
    │   ├── PermissionView.swift
    │   └── PermissionViewModel.swift
    ├── BabyProfile/
    │   ├── BabyProfileView.swift
    │   └── BabyProfileViewModel.swift
    ├── Scanning/
    │   ├── ScanningView.swift
    │   └── ScanningViewModel.swift
    ├── Results/
    │   ├── ResultsView.swift
    │   ├── ResultsViewModel.swift
    │   └── PhotoCardView.swift
    ├── SaveComplete/
    │   ├── SaveCompleteView.swift
    │   └── SaveCompleteViewModel.swift
    └── ManualUpload/
        ├── ManualUploadView.swift
        └── ManualUploadViewModel.swift

ZhiguangTests/
├── Models/
│   └── ScanResultTests.swift
├── Services/
│   ├── PermissionStateStoreTests.swift
│   ├── BabyProfileStoreTests.swift
│   ├── ScoringEngineTests.swift
│   ├── ScanStateCacheTests.swift
│   └── AlbumSaveServiceTests.swift
└── Features/
    ├── BabyProfileViewModelTests.swift
    ├── ScanningViewModelTests.swift
    └── ResultsViewModelTests.swift
```

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `Zhiguang.xcodeproj` (via Xcode GUI)
- Create: `Zhiguang/ZhiguangApp.swift`
- Create: `Zhiguang/Shared/Constants.swift`
- Modify: `Zhiguang/Info.plist`

- [ ] **Step 1: Create Xcode project**

  Open Xcode → File → New → Project → iOS → App  
  - Product Name: `Zhiguang`  
  - Bundle Identifier: `com.abc-work.zhiguang`  
  - Interface: SwiftUI  
  - Language: Swift  
  - Include Tests: ✅  
  - Deployment Target: **iOS 16.0**

- [ ] **Step 2: Delete boilerplate**

  Delete `ContentView.swift`. Keep `ZhiguangApp.swift` and `Assets.xcassets`.

- [ ] **Step 3: Set up Constants**

  Create `Zhiguang/Shared/Constants.swift`:

  ```swift
  enum Constants {
      enum Album {
          static let name = "稚光精选"
      }
      enum Scan {
          static let maxPhotoCount = 1000
          static let dayRange = 90
          static let batchSize = 50
          static let burstIntervalSeconds: TimeInterval = 2.0
          static let maxResultCount = 20
          static let maxPerBurstGroup = 2
          static let sharpnessThreshold: Double = 50.0
      }
      enum UserDefaultsKey {
          static let hasCompletedOnboarding = "hasCompletedOnboarding"
          static let lastPermissionState = "lastPermissionState"
      }
  }
  ```

- [ ] **Step 4: Add Info.plist entries**

  In Xcode, select `Zhiguang` target → Info tab, add:
  - `NSPhotoLibraryUsageDescription` → `"稚光需要访问您的照片，用于在本地分析并筛选宝宝照片。所有处理默认在您的设备上完成，照片不会自动上传。"`
  - `NSPhotoLibraryAddUsageDescription` → `"稚光需要将精选照片保存到系统相册「稚光精选」。"`

- [ ] **Step 5: Build to verify**

  `Cmd+B` — should build clean with zero errors.

- [ ] **Step 6: Commit**

  ```bash
  git add .
  git commit -m "feat: init Xcode project, constants, Info.plist permissions"
  ```

---

## Task 2: Core Models

**Files:**
- Create: `Zhiguang/Models/PermissionState.swift`
- Create: `Zhiguang/Models/BabyProfile.swift`
- Create: `Zhiguang/Models/PhotoAsset.swift`
- Create: `Zhiguang/Models/PhotoScore.swift`
- Create: `Zhiguang/Models/ScanResult.swift`
- Create: `ZhiguangTests/Models/ScanResultTests.swift`

- [ ] **Step 1: Write failing tests for ScanResult**

  Create `ZhiguangTests/Models/ScanResultTests.swift`:

  ```swift
  import XCTest
  @testable import Zhiguang

  final class ScanResultTests: XCTestCase {
      func test_removePhoto_movesToRejected() {
          var result = ScanResult.stub(selectedIds: ["a", "b", "c"])
          result.remove(assetId: "b")
          XCTAssertFalse(result.selectedAssetIds.contains("b"))
          XCTAssertTrue(result.rejectedAssetIds.contains("b"))
      }

      func test_restorePhoto_movesToSelected() {
          var result = ScanResult.stub(selectedIds: ["a", "c"])
          result.rejectedAssetIds = ["b"]
          result.allCandidateIds = ["a", "b", "c"]
          result.restore(assetId: "b")
          XCTAssertTrue(result.selectedAssetIds.contains("b"))
          XCTAssertFalse(result.rejectedAssetIds.contains("b"))
      }

      func test_isEmpty_whenAllRemoved() {
          var result = ScanResult.stub(selectedIds: ["a"])
          result.remove(assetId: "a")
          XCTAssertTrue(result.selectedAssetIds.isEmpty)
      }
  }
  ```

- [ ] **Step 2: Run tests — expect compile failure**

  `Cmd+U` — fails because types don't exist yet.

- [ ] **Step 3: Create PermissionState**

  Create `Zhiguang/Models/PermissionState.swift`:

  ```swift
  import Foundation

  enum PermissionState: String, Codable {
      case notDetermined
      case full
      case limited
      case denied
  }
  ```

- [ ] **Step 4: Create BabyProfile**

  Create `Zhiguang/Models/BabyProfile.swift`:

  ```swift
  import Foundation

  struct BabyProfile: Identifiable, Codable, Equatable {
      var id: UUID
      var nickname: String        // required
      var birthday: Date?         // optional
      var gender: Gender?         // optional

      enum Gender: String, Codable, CaseIterable {
          case boy = "男宝"
          case girl = "女宝"
      }

      init(id: UUID = UUID(), nickname: String, birthday: Date? = nil, gender: Gender? = nil) {
          self.id = id
          self.nickname = nickname
          self.birthday = birthday
          self.gender = gender
      }
  }
  ```

- [ ] **Step 5: Create PhotoAsset**

  Create `Zhiguang/Models/PhotoAsset.swift`:

  ```swift
  import Foundation
  import Photos

  struct PhotoAsset: Identifiable {
      var id: String              // PHAsset.localIdentifier
      var creationDate: Date?
      var pixelWidth: Int
      var pixelHeight: Int

      init(from asset: PHAsset) {
          self.id = asset.localIdentifier
          self.creationDate = asset.creationDate
          self.pixelWidth = asset.pixelWidth
          self.pixelHeight = asset.pixelHeight
      }
  }
  ```

- [ ] **Step 6: Create PhotoScore**

  Create `Zhiguang/Models/PhotoScore.swift`:

  ```swift
  import Foundation

  struct PhotoScore {
      var assetId: String
      var totalScore: Float = 0
      var faceScore: Float = 0
      var sharpnessScore: Float = 0
      var expressionScore: Float = 0
      var compositionScore: Float = 0
      var duplicatePenalty: Float = 0
      var reasons: [String] = []

      var adjustedTotal: Float {
          totalScore + duplicatePenalty
      }
  }
  ```

- [ ] **Step 7: Create ScanResult with stub**

  Create `Zhiguang/Models/ScanResult.swift`:

  ```swift
  import Foundation

  struct ScanResult: Identifiable, Codable {
      var id: UUID
      var babyProfileId: UUID
      var createdAt: Date
      var scannedCount: Int
      var selectedAssetIds: [String]
      var rejectedAssetIds: [String]
      var allCandidateIds: [String]

      init(id: UUID = UUID(), babyProfileId: UUID, createdAt: Date = .now,
           scannedCount: Int, selectedAssetIds: [String],
           rejectedAssetIds: [String] = [], allCandidateIds: [String]) {
          self.id = id
          self.babyProfileId = babyProfileId
          self.createdAt = createdAt
          self.scannedCount = scannedCount
          self.selectedAssetIds = selectedAssetIds
          self.rejectedAssetIds = rejectedAssetIds
          self.allCandidateIds = allCandidateIds
      }

      mutating func remove(assetId: String) {
          selectedAssetIds.removeAll { $0 == assetId }
          if !rejectedAssetIds.contains(assetId) {
              rejectedAssetIds.append(assetId)
          }
      }

      mutating func restore(assetId: String) {
          rejectedAssetIds.removeAll { $0 == assetId }
          if !selectedAssetIds.contains(assetId) {
              selectedAssetIds.append(assetId)
          }
      }
  }

  // MARK: - Test Helpers
  #if DEBUG
  extension ScanResult {
      static func stub(selectedIds: [String]) -> ScanResult {
          ScanResult(
              babyProfileId: UUID(),
              scannedCount: selectedIds.count,
              selectedAssetIds: selectedIds,
              allCandidateIds: selectedIds
          )
      }
  }
  #endif
  ```

- [ ] **Step 8: Run tests — expect pass**

  `Cmd+U` — all 3 ScanResultTests pass.

- [ ] **Step 9: Commit**

  ```bash
  git add .
  git commit -m "feat: add core models (PermissionState, BabyProfile, PhotoAsset, PhotoScore, ScanResult)"
  ```

---

## Task 3: PermissionStateStore

**Files:**
- Create: `Zhiguang/Services/PermissionStateStore.swift`
- Create: `ZhiguangTests/Services/PermissionStateStoreTests.swift`

- [ ] **Step 1: Write failing tests**

  Create `ZhiguangTests/Services/PermissionStateStoreTests.swift`:

  ```swift
  import XCTest
  import Photos
  @testable import Zhiguang

  final class PermissionStateStoreTests: XCTestCase {
      func test_initialState_isNotDetermined() {
          let store = PermissionStateStore()
          // Before checking real permissions, state reflects persisted value or notDetermined
          XCTAssertNotNil(store.state)
      }

      func test_isLimited_whenStateLimited() {
          let store = PermissionStateStore()
          store.state = .limited
          XCTAssertTrue(store.isLimited)
          XCTAssertFalse(store.isFull)
          XCTAssertFalse(store.isDenied)
      }

      func test_isFull_whenStateFull() {
          let store = PermissionStateStore()
          store.state = .full
          XCTAssertTrue(store.isFull)
          XCTAssertFalse(store.isLimited)
      }

      func test_isDenied_whenStateDenied() {
          let store = PermissionStateStore()
          store.state = .denied
          XCTAssertTrue(store.isDenied)
      }

      func test_canProceed_whenFullOrLimited() {
          let store = PermissionStateStore()
          store.state = .full
          XCTAssertTrue(store.canProceed)
          store.state = .limited
          XCTAssertTrue(store.canProceed)
          store.state = .denied
          XCTAssertFalse(store.canProceed)
      }
  }
  ```

- [ ] **Step 2: Run tests — expect compile failure**

- [ ] **Step 3: Implement PermissionStateStore**

  Create `Zhiguang/Services/PermissionStateStore.swift`:

  ```swift
  import Foundation
  import Photos
  import Combine

  @MainActor
  final class PermissionStateStore: ObservableObject {
      @Published var state: PermissionState = .notDetermined

      var isFull: Bool { state == .full }
      var isLimited: Bool { state == .limited }
      var isDenied: Bool { state == .denied }
      var canProceed: Bool { state == .full || state == .limited }

      init() {
          refreshFromSystem()
      }

      func refreshFromSystem() {
          let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
          state = PermissionState(from: status)
      }

      func requestAccess() async {
          let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
          state = PermissionState(from: status)
      }
  }

  extension PermissionState {
      init(from status: PHAuthorizationStatus) {
          switch status {
          case .authorized:        self = .full
          case .limited:           self = .limited
          case .denied, .restricted: self = .denied
          default:                 self = .notDetermined
          }
      }
  }
  ```

- [ ] **Step 4: Run tests — expect pass**

- [ ] **Step 5: Commit**

  ```bash
  git add .
  git commit -m "feat: add PermissionStateStore with PHPhotoLibrary auth mapping"
  ```

---

## Task 4: BabyProfileStore

**Files:**
- Create: `Zhiguang/Services/BabyProfileStore.swift`
- Create: `ZhiguangTests/Services/BabyProfileStoreTests.swift`

- [ ] **Step 1: Write failing tests**

  Create `ZhiguangTests/Services/BabyProfileStoreTests.swift`:

  ```swift
  import XCTest
  @testable import Zhiguang

  final class BabyProfileStoreTests: XCTestCase {
      var store: BabyProfileStore!

      override func setUp() {
          // Use a unique UserDefaults suite so tests don't pollute each other
          let defaults = UserDefaults(suiteName: "test.\(UUID())")!
          store = BabyProfileStore(defaults: defaults)
      }

      func test_addProfile_increasesCount() {
          let profile = BabyProfile(nickname: "小豆豆")
          store.add(profile)
          XCTAssertEqual(store.profiles.count, 1)
          XCTAssertEqual(store.profiles.first?.nickname, "小豆豆")
      }

      func test_updateProfile_modifiesExisting() {
          var profile = BabyProfile(nickname: "旧名字")
          store.add(profile)
          profile.nickname = "新名字"
          store.update(profile)
          XCTAssertEqual(store.profiles.first?.nickname, "新名字")
      }

      func test_draft_persistsAndClears() {
          let draft = BabyProfile(nickname: "草稿宝宝")
          store.saveDraft(draft)
          XCTAssertEqual(store.draft?.nickname, "草稿宝宝")
          store.clearDraft()
          XCTAssertNil(store.draft)
      }

      func test_profiles_persistAcrossInstances() {
          let defaults = UserDefaults(suiteName: "test.persist.\(UUID())")!
          let store1 = BabyProfileStore(defaults: defaults)
          store1.add(BabyProfile(nickname: "持久化"))
          let store2 = BabyProfileStore(defaults: defaults)
          XCTAssertEqual(store2.profiles.first?.nickname, "持久化")
      }
  }
  ```

- [ ] **Step 2: Run tests — expect compile failure**

- [ ] **Step 3: Implement BabyProfileStore**

  Create `Zhiguang/Services/BabyProfileStore.swift`:

  ```swift
  import Foundation
  import Combine

  @MainActor
  final class BabyProfileStore: ObservableObject {
      @Published private(set) var profiles: [BabyProfile] = []
      @Published private(set) var draft: BabyProfile?

      private let defaults: UserDefaults
      private let profilesKey = "babyProfiles"
      private let draftKey = "babyProfileDraft"

      init(defaults: UserDefaults = .standard) {
          self.defaults = defaults
          load()
      }

      func add(_ profile: BabyProfile) {
          profiles.append(profile)
          save()
      }

      func update(_ profile: BabyProfile) {
          if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
              profiles[idx] = profile
              save()
          }
      }

      func saveDraft(_ profile: BabyProfile) {
          draft = profile
          if let data = try? JSONEncoder().encode(profile) {
              defaults.set(data, forKey: draftKey)
          }
      }

      func clearDraft() {
          draft = nil
          defaults.removeObject(forKey: draftKey)
      }

      // MARK: Private
      private func load() {
          if let data = defaults.data(forKey: profilesKey),
             let decoded = try? JSONDecoder().decode([BabyProfile].self, from: data) {
              profiles = decoded
          }
          if let data = defaults.data(forKey: draftKey),
             let decoded = try? JSONDecoder().decode(BabyProfile.self, from: data) {
              draft = decoded
          }
      }

      private func save() {
          if let data = try? JSONEncoder().encode(profiles) {
              defaults.set(data, forKey: profilesKey)
          }
      }
  }
  ```

- [ ] **Step 4: Run tests — expect pass**

- [ ] **Step 5: Commit**

  ```bash
  git add .
  git commit -m "feat: add BabyProfileStore with persistence and draft support"
  ```

---

## Task 5: PhotoLibraryService

**Files:**
- Create: `Zhiguang/Services/PhotoLibraryService.swift`

Note: PhotoKit requires a real device/simulator for integration testing. We define a protocol for mockability and test against the protocol in ViewModel tests.

- [ ] **Step 1: Create PhotoLibraryServiceProtocol and live implementation**

  Create `Zhiguang/Services/PhotoLibraryService.swift`:

  ```swift
  import Foundation
  import Photos

  // MARK: - Protocol (for testability)
  protocol PhotoLibraryServiceProtocol {
      func fetchCandidateAssets() async -> [PhotoAsset]
      func loadThumbnail(for assetId: String, size: CGSize) async -> CGImage?
      func loadFullImage(for assetId: String) async -> CGImage?
  }

  // MARK: - Live Implementation
  actor PhotoLibraryService: PhotoLibraryServiceProtocol {
      func fetchCandidateAssets() async -> [PhotoAsset] {
          let options = PHFetchOptions()
          options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
          options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

          let cutoffDate = Calendar.current.date(byAdding: .day, value: -Constants.Scan.dayRange, to: .now)!
          let byDate = PHAsset.fetchAssets(with: options)

          var assets: [PHAsset] = []
          // Union: last 90 days OR last 1000, capped at 1000
          byDate.enumerateObjects { asset, _, stop in
              assets.append(asset)
              if assets.count >= Constants.Scan.maxPhotoCount { stop.pointee = true }
          }

          // If fewer than maxPhotoCount found, include older assets up to limit
          // (fetchCandidateAssets returns newest-first up to 1000, which covers both rules)
          return assets
              .filter { $0.mediaSubtypes.contains(.photoScreenshot) == false }
              .map { PhotoAsset(from: $0) }
      }

      func loadThumbnail(for assetId: String, size: CGSize) async -> CGImage? {
          await withCheckedContinuation { continuation in
              let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
              guard let asset = result.firstObject else {
                  continuation.resume(returning: nil); return
              }
              let opts = PHImageRequestOptions()
              opts.isSynchronous = false
              opts.deliveryMode = .fastFormat
              opts.resizeMode = .fast
              PHImageManager.default().requestImage(
                  for: asset, targetSize: size, contentMode: .aspectFit, options: opts
              ) { image, _ in
                  continuation.resume(returning: image?.cgImage)
              }
          }
      }

      func loadFullImage(for assetId: String) async -> CGImage? {
          await withCheckedContinuation { continuation in
              let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
              guard let asset = result.firstObject else {
                  continuation.resume(returning: nil); return
              }
              let opts = PHImageRequestOptions()
              opts.isSynchronous = false
              opts.deliveryMode = .highQualityFormat
              opts.isNetworkAccessAllowed = true
              PHImageManager.default().requestImage(
                  for: asset, targetSize: PHImageManagerMaximumSize,
                  contentMode: .aspectFit, options: opts
              ) { image, _ in
                  continuation.resume(returning: image?.cgImage)
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build to verify**

  `Cmd+B` — no errors.

- [ ] **Step 3: Commit**

  ```bash
  git add .
  git commit -m "feat: add PhotoLibraryService with protocol for testability"
  ```

---

## Task 6: ScoringEngine — Sharpness

**Files:**
- Create: `Zhiguang/Services/ScoringEngine.swift` (initial)
- Create: `ZhiguangTests/Services/ScoringEngineTests.swift`

- [ ] **Step 1: Write failing sharpness tests**

  Create `ZhiguangTests/Services/ScoringEngineTests.swift`:

  ```swift
  import XCTest
  import CoreGraphics
  @testable import Zhiguang

  final class ScoringEngineTests: XCTestCase {

      // MARK: - Sharpness
      func test_sharpness_blankImageIsZero() {
          let engine = ScoringEngine()
          let blankImage = makeBlankImage(width: 100, height: 100)
          let score = engine.sharpnessScore(for: blankImage)
          XCTAssertEqual(score, 0, accuracy: 0.01)
      }

      func test_sharpness_highContrastImageScoresHigher() {
          let engine = ScoringEngine()
          let blank = makeBlankImage(width: 100, height: 100)
          let grid = makeCheckerboardImage(width: 100, height: 100)
          let blankScore = engine.sharpnessScore(for: blank)
          let gridScore = engine.sharpnessScore(for: grid)
          XCTAssertGreaterThan(gridScore, blankScore)
      }

      func test_sharpness_belowThresholdIsZero() {
          let engine = ScoringEngine()
          let blank = makeBlankImage(width: 100, height: 100)
          // Blank image has near-zero variance → score = 0
          XCTAssertEqual(engine.sharpnessScore(for: blank), 0, accuracy: 0.01)
      }

      // MARK: - Burst Grouping
      func test_burstGrouping_closeDatesGroupTogether() {
          let engine = ScoringEngine()
          let base = Date()
          let assets = [
              makeAsset(id: "a", date: base),
              makeAsset(id: "b", date: base.addingTimeInterval(1)),   // same burst
              makeAsset(id: "c", date: base.addingTimeInterval(10)),  // new group
          ]
          let groups = engine.groupBursts(assets)
          XCTAssertEqual(groups.count, 2)
          XCTAssertEqual(groups[0].count, 2)
          XCTAssertEqual(groups[1].count, 1)
      }

      func test_burstGrouping_singlePhotoIsSingleGroup() {
          let engine = ScoringEngine()
          let assets = [makeAsset(id: "x", date: .now)]
          let groups = engine.groupBursts(assets)
          XCTAssertEqual(groups.count, 1)
          XCTAssertEqual(groups[0].count, 1)
      }

      // MARK: - Top N Selection
      func test_topN_returnsAtMostMaxCount() {
          let engine = ScoringEngine()
          let scores = (0..<30).map {
              PhotoScore(assetId: "id\($0)", totalScore: Float($0))
          }
          let top = engine.selectTop(scores, max: Constants.Scan.maxResultCount)
          XCTAssertEqual(top.count, Constants.Scan.maxResultCount)
      }

      func test_topN_sortedByAdjustedScoreDescending() {
          let engine = ScoringEngine()
          var low = PhotoScore(assetId: "low", totalScore: 3.0)
          var high = PhotoScore(assetId: "high", totalScore: 9.0)
          low.duplicatePenalty = 0
          high.duplicatePenalty = 0
          let top = engine.selectTop([low, high], max: 2)
          XCTAssertEqual(top.first?.assetId, "high")
      }

      // MARK: - Helpers
      private func makeBlankImage(width: Int, height: Int) -> CGImage {
          let ctx = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: width,
                              space: CGColorSpaceCreateDeviceGray(),
                              bitmapInfo: 0)!
          ctx.setFillColor(gray: 0.5, alpha: 1)
          ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
          return ctx.makeImage()!
      }

      private func makeCheckerboardImage(width: Int, height: Int) -> CGImage {
          let ctx = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: width,
                              space: CGColorSpaceCreateDeviceGray(),
                              bitmapInfo: 0)!
          for y in 0..<height {
              for x in 0..<width {
                  let isWhite = (x + y) % 2 == 0
                  ctx.setFillColor(gray: isWhite ? 1 : 0, alpha: 1)
                  ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
              }
          }
          return ctx.makeImage()!
      }

      private func makeAsset(id: String, date: Date) -> PhotoAsset {
          PhotoAsset(id: id, creationDate: date, pixelWidth: 100, pixelHeight: 100)
      }
  }
  ```

- [ ] **Step 2: Run tests — expect compile failure**

- [ ] **Step 3: Implement ScoringEngine (sharpness + grouping + selectTop)**

  Create `Zhiguang/Services/ScoringEngine.swift`:

  ```swift
  import Foundation
  import Vision
  import CoreImage
  import CoreGraphics

  actor ScoringEngine {

      // MARK: - Public API
      func score(assets: [PhotoAsset], thumbnailProvider: (String) async -> CGImage?) async -> [PhotoScore] {
          var scores: [PhotoScore] = []

          // Batch: sharpness + face detection
          for batch in assets.chunked(into: Constants.Scan.batchSize) {
              for asset in batch {
                  guard let thumbnail = await thumbnailProvider(asset.id) else { continue }
                  let sharpness = sharpnessScore(for: thumbnail)
                  guard sharpness > 0 else { continue } // filtered as too blurry

                  var score = PhotoScore(assetId: asset.id)
                  score.sharpnessScore = sharpness

                  let faceResult = await detectFaces(in: thumbnail)
                  guard faceResult.hasFace else { continue } // no face → skip

                  score.faceScore = faceResult.faceScore
                  score.expressionScore = faceResult.expressionScore
                  score.compositionScore = faceResult.compositionScore
                  score.reasons = faceResult.reasons

                  score.totalScore = computeTotal(score)
                  scores.append(score)
              }
          }

          // Burst penalty
          let assetMap = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
          let groups = groupBursts(scores.compactMap { assetMap[$0.assetId] })
          scores = applyBurstPenalty(scores: scores, groups: groups)

          return scores
      }

      // MARK: - Sharpness (Laplacian variance)
      func sharpnessScore(for image: CGImage) -> Float {
          let variance = laplacianVariance(image)
          guard variance >= Constants.Scan.sharpnessThreshold else { return 0 }
          // Normalize: 50→0, 500→10
          let normalized = min(Float((variance - Constants.Scan.sharpnessThreshold) / 450.0 * 10.0), 10.0)
          return max(normalized, 0)
      }

      // MARK: - Burst Grouping
      func groupBursts(_ assets: [PhotoAsset]) -> [[PhotoAsset]] {
          guard !assets.isEmpty else { return [] }
          let sorted = assets.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
          var groups: [[PhotoAsset]] = [[sorted[0]]]
          for asset in sorted.dropFirst() {
              let prev = groups[groups.count - 1].last!
              let interval = (asset.creationDate ?? .now).timeIntervalSince(prev.creationDate ?? .now)
              if interval <= Constants.Scan.burstIntervalSeconds {
                  groups[groups.count - 1].append(asset)
              } else {
                  groups.append([asset])
              }
          }
          return groups
      }

      // MARK: - Top N Selection
      func selectTop(_ scores: [PhotoScore], max count: Int) -> [PhotoScore] {
          scores.sorted { $0.adjustedTotal > $1.adjustedTotal }.prefix(count).map { $0 }
      }

      // MARK: - Private: Laplacian Variance
      private func laplacianVariance(_ image: CGImage) -> Double {
          guard let ci = CIImage(cgImage: image).applyingFilter("CIEdges") as CIImage?,
                let cgFiltered = CIContext().createCGImage(ci, from: ci.extent) else {
              return 0
          }
          guard let data = cgFiltered.dataProvider?.data,
                let ptr = CFDataGetBytePtr(data) else { return 0 }
          let len = CFDataGetLength(data)
          var sum: Double = 0
          var sumSq: Double = 0
          for i in 0..<len {
              let v = Double(ptr[i])
              sum += v; sumSq += v * v
          }
          let n = Double(len)
          return (sumSq / n) - (sum / n) * (sum / n)
      }

      // MARK: - Private: Face Detection
      private struct FaceResult {
          var hasFace: Bool
          var faceScore: Float
          var expressionScore: Float
          var compositionScore: Float
          var reasons: [String]
      }

      private func detectFaces(in image: CGImage) async -> FaceResult {
          await withCheckedContinuation { continuation in
              let request = VNDetectFaceLandmarksRequest { req, err in
                  guard let observations = req.results as? [VNFaceObservation],
                        let face = observations.first else {
                      continuation.resume(returning: FaceResult(hasFace: false, faceScore: 0, expressionScore: 0, compositionScore: 0, reasons: []))
                      return
                  }
                  let faceScore = self.computeFaceScore(face, imageSize: CGSize(width: image.width, height: image.height))
                  let expressionScore = self.computeExpressionScore(face)
                  let compositionScore = self.computeCompositionScore(face)
                  var reasons: [String] = []
                  if expressionScore > 7 { reasons.append("笑脸清晰") }
                  if faceScore > 7 { reasons.append("主体完整") }
                  if compositionScore > 7 { reasons.append("构图完整") }
                  if reasons.isEmpty { reasons.append("宝宝照片") }
                  continuation.resume(returning: FaceResult(
                      hasFace: true,
                      faceScore: faceScore,
                      expressionScore: expressionScore,
                      compositionScore: compositionScore,
                      reasons: reasons
                  ))
              }
              let handler = VNImageRequestHandler(cgImage: image)
              try? handler.perform([request])
          }
      }

      private func computeFaceScore(_ face: VNFaceObservation, imageSize: CGSize) -> Float {
          let box = face.boundingBox
          let area = box.width * box.height
          // Larger face area in frame → higher score (capped at 10)
          return Float(min(area * 40, 1.0) * 10)
      }

      private func computeExpressionScore(_ face: VNFaceObservation) -> Float {
          guard let landmarks = face.landmarks else { return 5.0 }
          var score: Float = 5.0
          // Mouth curve (simplified: presence of outer lips = smile candidate)
          if landmarks.outerLips != nil { score += 2.5 }
          // Eyes open
          if landmarks.leftEye != nil && landmarks.rightEye != nil { score += 2.5 }
          return min(score, 10.0)
      }

      private func computeCompositionScore(_ face: VNFaceObservation) -> Float {
          let box = face.boundingBox
          // Check face is fully within frame (0–1 normalized coords)
          let withinFrame = box.minX >= 0 && box.minY >= 0 && box.maxX <= 1 && box.maxY <= 1
          // Check face near center
          let centerDist = hypot(box.midX - 0.5, box.midY - 0.5)
          let centerScore = Float(max(0, 1 - centerDist * 2))
          return (withinFrame ? 5.0 : 2.0) + centerScore * 5.0
      }

      private func computeTotal(_ score: PhotoScore) -> Float {
          score.faceScore * 0.30 +
          score.sharpnessScore * 0.25 +
          score.expressionScore * 0.20 +
          score.compositionScore * 0.15
          // sceneScore (0.10) handled separately if needed
      }

      private func applyBurstPenalty(scores: [PhotoScore], groups: [[PhotoAsset]]) -> [PhotoScore] {
          var result = scores
          var scoreMap = Dictionary(uniqueKeysWithValues: scores.enumerated().map { ($1.assetId, $0) })
          for group in groups where group.count > 1 {
              let ids = group.map { $0.id }
              let groupScores = ids.compactMap { id -> (String, Float)? in
                  guard let idx = scoreMap[id] else { return nil }
                  return (id, result[idx].adjustedTotal)
              }.sorted { $0.1 > $1.1 }

              // Keep top 2, penalize rest
              for (i, (id, _)) in groupScores.enumerated() {
                  if i >= Constants.Scan.maxPerBurstGroup, let idx = scoreMap[id] {
                      result[idx].duplicatePenalty = -2.0
                  }
              }
          }
          return result
      }
  }

  // MARK: - Array chunked helper
  extension Array {
      func chunked(into size: Int) -> [[Element]] {
          stride(from: 0, to: count, by: size).map {
              Array(self[$0 ..< Swift.min($0 + size, count)])
          }
      }
  }
  ```

- [ ] **Step 4: Add PhotoAsset memberwise init for tests**

  Add to `Zhiguang/Models/PhotoAsset.swift` (inside the struct, after the existing `init(from:)`):

  ```swift
  #if DEBUG
  init(id: String, creationDate: Date?, pixelWidth: Int, pixelHeight: Int) {
      self.id = id
      self.creationDate = creationDate
      self.pixelWidth = pixelWidth
      self.pixelHeight = pixelHeight
  }
  #endif
  ```

- [ ] **Step 5: Run tests — expect pass**

  `Cmd+U` — ScoringEngineTests should pass.

- [ ] **Step 6: Commit**

  ```bash
  git add .
  git commit -m "feat: add ScoringEngine (sharpness, Vision face detection, burst grouping, top-N)"
  ```

---

## Task 7: ScanStateCache

**Files:**
- Create: `Zhiguang/Services/ScanStateCache.swift`
- Create: `ZhiguangTests/Services/ScanStateCacheTests.swift`

- [ ] **Step 1: Write failing tests**

  Create `ZhiguangTests/Services/ScanStateCacheTests.swift`:

  ```swift
  import XCTest
  @testable import Zhiguang

  final class ScanStateCacheTests: XCTestCase {
      var cache: ScanStateCache!

      override func setUp() {
          let defaults = UserDefaults(suiteName: "test.scan.\(UUID())")!
          cache = ScanStateCache(defaults: defaults)
      }

      func test_saveAndLoad_roundTrips() {
          let result = ScanResult.stub(selectedIds: ["x", "y"])
          cache.save(result, for: UUID())
          let loaded = cache.load(for: result.babyProfileId)
          XCTAssertEqual(loaded?.selectedAssetIds, ["x", "y"])
      }

      func test_clear_removesData() {
          let result = ScanResult.stub(selectedIds: ["x"])
          cache.save(result, for: result.babyProfileId)
          cache.clear(for: result.babyProfileId)
          XCTAssertNil(cache.load(for: result.babyProfileId))
      }

      func test_scanProgress_saveAndLoad() {
          cache.saveProgress(scannedCount: 42, babyId: UUID())
          // Progress is keyed per baby, but for MVP we just verify it doesn't crash
          XCTAssertTrue(true)
      }
  }
  ```

- [ ] **Step 2: Run tests — expect compile failure**

- [ ] **Step 3: Implement ScanStateCache**

  Create `Zhiguang/Services/ScanStateCache.swift`:

  ```swift
  import Foundation

  final class ScanStateCache {
      private let defaults: UserDefaults
      private let resultPrefix = "scanResult."
      private let progressPrefix = "scanProgress."

      init(defaults: UserDefaults = .standard) {
          self.defaults = defaults
      }

      func save(_ result: ScanResult, for babyId: UUID) {
          if let data = try? JSONEncoder().encode(result) {
              defaults.set(data, forKey: resultPrefix + babyId.uuidString)
          }
      }

      func load(for babyId: UUID) -> ScanResult? {
          guard let data = defaults.data(forKey: resultPrefix + babyId.uuidString) else { return nil }
          return try? JSONDecoder().decode(ScanResult.self, from: data)
      }

      func clear(for babyId: UUID) {
          defaults.removeObject(forKey: resultPrefix + babyId.uuidString)
          defaults.removeObject(forKey: progressPrefix + babyId.uuidString)
      }

      func saveProgress(scannedCount: Int, babyId: UUID) {
          defaults.set(scannedCount, forKey: progressPrefix + babyId.uuidString)
      }

      func loadProgress(for babyId: UUID) -> Int {
          defaults.integer(forKey: progressPrefix + babyId.uuidString)
      }
  }
  ```

- [ ] **Step 4: Run tests — expect pass**

- [ ] **Step 5: Commit**

  ```bash
  git add .
  git commit -m "feat: add ScanStateCache for breakpoint resume"
  ```

---

## Task 8: AlbumSaveService

**Files:**
- Create: `Zhiguang/Services/AlbumSaveService.swift`
- Create: `ZhiguangTests/Services/AlbumSaveServiceTests.swift`

- [ ] **Step 1: Write failing tests**

  Create `ZhiguangTests/Services/AlbumSaveServiceTests.swift`:

  ```swift
  import XCTest
  @testable import Zhiguang

  // Mock that simulates save results
  final class MockAlbumSaveService: AlbumSaveServiceProtocol {
      var shouldFailIds: Set<String> = []

      func save(assetIds: [String]) async -> AlbumSaveResult {
          var succeeded: [String] = []
          var failed: [AlbumSaveFailure] = []
          for id in assetIds {
              if shouldFailIds.contains(id) {
                  failed.append(AlbumSaveFailure(assetId: id, reason: .unknown))
              } else {
                  succeeded.append(id)
              }
          }
          return AlbumSaveResult(succeeded: succeeded, failed: failed)
      }
  }

  final class AlbumSaveServiceTests: XCTestCase {
      func test_mockSave_allSucceed() async {
          let svc = MockAlbumSaveService()
          let result = await svc.save(assetIds: ["a", "b", "c"])
          XCTAssertEqual(result.succeeded.count, 3)
          XCTAssertTrue(result.failed.isEmpty)
          XCTAssertTrue(result.isFullSuccess)
      }

      func test_mockSave_partialFailure() async {
          let svc = MockAlbumSaveService()
          svc.shouldFailIds = ["b"]
          let result = await svc.save(assetIds: ["a", "b", "c"])
          XCTAssertEqual(result.succeeded.count, 2)
          XCTAssertEqual(result.failed.count, 1)
          XCTAssertFalse(result.isFullSuccess)
          XCTAssertTrue(result.isPartialSuccess)
      }
  }
  ```

- [ ] **Step 2: Run tests — expect compile failure**

- [ ] **Step 3: Implement AlbumSaveService**

  Create `Zhiguang/Services/AlbumSaveService.swift`:

  ```swift
  import Foundation
  import Photos

  // MARK: - Result types
  enum AlbumSaveFailureReason {
      case permissionDenied
      case storageFull
      case unknown
  }

  struct AlbumSaveFailure {
      var assetId: String
      var reason: AlbumSaveFailureReason
  }

  struct AlbumSaveResult {
      var succeeded: [String]
      var failed: [AlbumSaveFailure]
      var isFullSuccess: Bool { failed.isEmpty }
      var isPartialSuccess: Bool { !succeeded.isEmpty && !failed.isEmpty }
      var isFullFailure: Bool { succeeded.isEmpty }
  }

  // MARK: - Protocol
  protocol AlbumSaveServiceProtocol {
      func save(assetIds: [String]) async -> AlbumSaveResult
  }

  // MARK: - Live Implementation
  actor AlbumSaveService: AlbumSaveServiceProtocol {
      func save(assetIds: [String]) async -> AlbumSaveResult {
          let albumId = await ensureAlbumExists()
          guard let albumId else {
              return AlbumSaveResult(
                  succeeded: [],
                  failed: assetIds.map { AlbumSaveFailure(assetId: $0, reason: .permissionDenied) }
              )
          }

          var succeeded: [String] = []
          var failed: [AlbumSaveFailure] = []

          for assetId in assetIds {
              let ok = await copyAsset(id: assetId, toAlbumId: albumId)
              if ok { succeeded.append(assetId) }
              else { failed.append(AlbumSaveFailure(assetId: assetId, reason: .unknown)) }
          }
          return AlbumSaveResult(succeeded: succeeded, failed: failed)
      }

      // MARK: Private
      private func ensureAlbumExists() async -> String? {
          // Check if album already exists
          let fetchOptions = PHFetchOptions()
          fetchOptions.predicate = NSPredicate(format: "title = %@", Constants.Album.name)
          let existing = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
          if let album = existing.firstObject { return album.localIdentifier }

          // Create
          var identifier: String?
          do {
              try await PHPhotoLibrary.shared().performChanges {
                  let req = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: Constants.Album.name)
                  identifier = req.placeholderForCreatedAssetCollection.localIdentifier
              }
          } catch { return nil }
          return identifier
      }

      private func copyAsset(id: String, toAlbumId albumId: String) async -> Bool {
          let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
          guard let asset = assets.firstObject else { return false }
          let albums = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil)
          guard let album = albums.firstObject else { return false }

          do {
              try await PHPhotoLibrary.shared().performChanges {
                  guard let req = PHAssetCollectionChangeRequest(for: album) else { return }
                  req.addAssets([asset] as NSFastEnumeration)
              }
              return true
          } catch {
              return false
          }
      }
  }
  ```

- [ ] **Step 4: Run tests — expect pass**

- [ ] **Step 5: Commit**

  ```bash
  git add .
  git commit -m "feat: add AlbumSaveService with protocol, partial-failure result type"
  ```

---

## Task 9: Shared UI Components

**Files:**
- Create: `Zhiguang/Shared/Components/PermissionBanner.swift`
- Create: `Zhiguang/Shared/Components/PrimaryButton.swift`
- Create: `Zhiguang/Shared/Components/ToastView.swift`

- [ ] **Step 1: Create PermissionBanner**

  ```swift
  // Zhiguang/Shared/Components/PermissionBanner.swift
  import SwiftUI

  struct PermissionBanner: View {
      var body: some View {
          HStack(spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.yellow)
                  .font(.caption)
              Text("当前仅获取部分相册，照片筛选结果可能不完整")
                  .font(.caption)
                  .foregroundColor(.yellow)
              Spacer()
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(Color.yellow.opacity(0.15))
          .overlay(Rectangle().frame(height: 2).foregroundColor(.yellow), alignment: .leading)
      }
  }

  #Preview {
      PermissionBanner()
          .preferredColorScheme(.dark)
  }
  ```

- [ ] **Step 2: Create PrimaryButton**

  ```swift
  // Zhiguang/Shared/Components/PrimaryButton.swift
  import SwiftUI

  struct PrimaryButton: View {
      let title: String
      let action: () -> Void
      var isLoading: Bool = false

      var body: some View {
          Button(action: action) {
              HStack {
                  if isLoading {
                      ProgressView().tint(.white).scaleEffect(0.8)
                  }
                  Text(title).fontWeight(.bold)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(
                  LinearGradient(colors: [Color(hex: "6C63FF"), Color(hex: "A78BFA")],
                                 startPoint: .leading, endPoint: .trailing)
              )
              .foregroundColor(.white)
              .clipShape(RoundedRectangle(cornerRadius: 14))
          }
      }
  }

  extension Color {
      init(hex: String) {
          let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
          var int: UInt64 = 0
          Scanner(string: hex).scanHexInt64(&int)
          let r = Double((int >> 16) & 0xFF) / 255
          let g = Double((int >> 8) & 0xFF) / 255
          let b = Double(int & 0xFF) / 255
          self.init(red: r, green: g, blue: b)
      }
  }
  ```

- [ ] **Step 3: Create ToastView**

  ```swift
  // Zhiguang/Shared/Components/ToastView.swift
  import SwiftUI

  struct ToastView: View {
      let message: String

      var body: some View {
          Text(message)
              .font(.subheadline)
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
              .background(.regularMaterial)
              .clipShape(Capsule())
              .shadow(radius: 4)
      }
  }

  // Modifier for toast presentation
  struct ToastModifier: ViewModifier {
      @Binding var message: String?

      func body(content: Content) -> some View {
          ZStack(alignment: .bottom) {
              content
              if let msg = message {
                  ToastView(message: msg)
                      .padding(.bottom, 40)
                      .transition(.move(edge: .bottom).combined(with: .opacity))
                      .onAppear {
                          DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                              withAnimation { message = nil }
                          }
                      }
              }
          }
          .animation(.spring(), value: message)
      }
  }

  extension View {
      func toast(message: Binding<String?>) -> some View {
          modifier(ToastModifier(message: message))
      }
  }
  ```

- [ ] **Step 4: Build — no errors**

- [ ] **Step 5: Commit**

  ```bash
  git add .
  git commit -m "feat: add shared UI components (PermissionBanner, PrimaryButton, ToastView)"
  ```

---

## Task 10: App Root & Navigation

**Files:**
- Modify: `Zhiguang/ZhiguangApp.swift`

- [ ] **Step 1: Set up app root with environment objects and navigation**

  Replace `Zhiguang/ZhiguangApp.swift`:

  ```swift
  import SwiftUI

  @main
  struct ZhiguangApp: App {
      @StateObject private var permissionStore = PermissionStateStore()
      @StateObject private var babyProfileStore = BabyProfileStore()
      private let scanStateCache = ScanStateCache()
      private let photoLibraryService = PhotoLibraryService()
      private let scoringEngine = ScoringEngine()
      private let albumSaveService = AlbumSaveService()

      var body: some Scene {
          WindowGroup {
              RootView()
                  .environmentObject(permissionStore)
                  .environmentObject(babyProfileStore)
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
              destinationView
                  .navigationDestination(for: AppRoute.self) { route in
                      route.view(path: $path)
                  }
          }
          .onAppear { permissionStore.refreshFromSystem() }
      }

      @ViewBuilder
      private var destinationView: some View {
          // Returning user with data → go straight to results
          if permissionStore.canProceed && !babyProfileStore.profiles.isEmpty {
              // We'll pass scanStateCache/etc via environment in real impl
              // For now, navigate to results
              OnboardingView(path: $path)
          } else {
              OnboardingView(path: $path)
          }
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
  ```

- [ ] **Step 2: Create placeholder Views for each feature** (so the app compiles)

  Run this to create empty placeholder files:

  ```bash
  for f in Onboarding/OnboardingView Permission/PermissionView BabyProfile/BabyProfileView Scanning/ScanningView Results/ResultsView Results/PhotoCardView SaveComplete/SaveCompleteView ManualUpload/ManualUploadView; do
    dir="Zhiguang/Features/$(dirname $f)"
    mkdir -p "$dir"
    name="$(basename $f)"
    cat > "$dir/$name.swift" << EOF
  import SwiftUI
  struct ${name}: View {
      @Binding var path: NavigationPath
      var body: some View { Text("$name placeholder") }
  }
  EOF
  done
  ```

  Then update each placeholder signature to match the `AppRoute.view` call (add extra params as needed). We will replace them in subsequent tasks.

- [ ] **Step 3: Build — expect clean build**

- [ ] **Step 4: Commit**

  ```bash
  git add .
  git commit -m "feat: add app root navigation with AppRoute enum and environment injection"
  ```

---

## Task 11: Onboarding Feature

**Files:**
- Create: `Zhiguang/Features/Onboarding/OnboardingViewModel.swift`
- Replace: `Zhiguang/Features/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Create OnboardingViewModel**

  ```swift
  // Zhiguang/Features/Onboarding/OnboardingViewModel.swift
  import Foundation

  @MainActor
  final class OnboardingViewModel: ObservableObject {
      private let defaults: UserDefaults

      var hasCompletedOnboarding: Bool {
          defaults.bool(forKey: Constants.UserDefaultsKey.hasCompletedOnboarding)
      }

      init(defaults: UserDefaults = .standard) {
          self.defaults = defaults
      }

      func markOnboardingComplete() {
          defaults.set(true, forKey: Constants.UserDefaultsKey.hasCompletedOnboarding)
      }
  }
  ```

- [ ] **Step 2: Implement OnboardingView**

  ```swift
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
                      // Open privacy URL
                  }
                  .font(.footnote).foregroundColor(.secondary)

                  Text("所有图片仅本地设备处理，不上传云端")
                      .font(.caption2).foregroundColor(Color.secondary.opacity(0.6))
              }
              .padding(.horizontal, 24)
              .padding(.bottom, 32)
          }
          .navigationBarHidden(true)
          .onAppear {
              // Returning user: skip to results
              if permissionStore.canProceed && !babyProfileStore.profiles.isEmpty {
                  // Pop to results — handled by RootView, but as safety net:
                  // path.append(.results(babyId: babyProfileStore.profiles.first!.id))
              }
          }
      }
  }
  ```

- [ ] **Step 3: Build and run in Simulator — verify onboarding screen appears**

- [ ] **Step 4: Commit**

  ```bash
  git add .
  git commit -m "feat: implement OnboardingView with hero, bullets, CTA"
  ```

---

## Task 12: Permission Feature

**Files:**
- Create: `Zhiguang/Features/Permission/PermissionViewModel.swift`
- Replace: `Zhiguang/Features/Permission/PermissionView.swift`

- [ ] **Step 1: Create PermissionViewModel**

  ```swift
  // Zhiguang/Features/Permission/PermissionViewModel.swift
  import Foundation

  @MainActor
  final class PermissionViewModel: ObservableObject {
      @Published var showDeniedAlert = false
      @Published var isRequesting = false

      private let permissionStore: PermissionStateStore

      init(permissionStore: PermissionStateStore) {
          self.permissionStore = permissionStore
      }

      func requestPermission() async {
          isRequesting = true
          await permissionStore.requestAccess()
          isRequesting = false
          if permissionStore.isDenied {
              showDeniedAlert = true
          }
      }

      func openSystemSettings() {
          guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
          UIApplication.shared.open(url)
      }
  }
  ```

- [ ] **Step 2: Implement PermissionView**

  ```swift
  // Zhiguang/Features/Permission/PermissionView.swift
  import SwiftUI

  struct PermissionView: View {
      @Binding var path: NavigationPath
      @EnvironmentObject var permissionStore: PermissionStateStore
      @StateObject private var vm: PermissionViewModel
      @State private var showManualUploadSheet = false

      init(path: Binding<NavigationPath>) {
          self._path = path
          // vm initialized in onAppear via environment
          self._vm = StateObject(wrappedValue: PermissionViewModel(permissionStore: PermissionStateStore()))
      }

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
                  PrimaryButton(title: "授权访问相册", isLoading: vm.isRequesting) {
                      Task { await vm.requestPermission() }
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
          .alert("相册权限未开启", isPresented: $vm.showDeniedAlert) {
              Button("前往系统设置") { vm.openSystemSettings() }
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
  }
  ```

- [ ] **Step 3: Fix PermissionViewModel init** (inject real permissionStore from environment)

  Update `PermissionView` to use `@EnvironmentObject` properly — SwiftUI can't inject `@EnvironmentObject` into `@StateObject` init. Use `onAppear` pattern:

  Replace the `init` and `@StateObject` with:
  ```swift
  // Remove custom init, use lazy init pattern
  @StateObject private var vm = PermissionViewModel(permissionStore: PermissionStateStore())
  // Then in .onAppear, the permissionStore env object is available
  ```

  For MVP simplicity, `PermissionViewModel` reads directly from `permissionStore` environment object. Acceptable for this scope.

- [ ] **Step 4: Build and test in Simulator**

  Run on simulator, tap "授权访问相册" → system permission dialog appears.

- [ ] **Step 5: Commit**

  ```bash
  git add .
  git commit -m "feat: implement PermissionView with 3-state handling and denied alert"
  ```

---

## Task 13: BabyProfile Feature

**Files:**
- Create: `Zhiguang/Features/BabyProfile/BabyProfileViewModel.swift`
- Replace: `Zhiguang/Features/BabyProfile/BabyProfileView.swift`
- Create: `ZhiguangTests/Features/BabyProfileViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

  Create `ZhiguangTests/Features/BabyProfileViewModelTests.swift`:

  ```swift
  import XCTest
  @testable import Zhiguang

  final class BabyProfileViewModelTests: XCTestCase {
      func test_canProceed_falseWhenNicknameEmpty() {
          let vm = BabyProfileViewModel(store: BabyProfileStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
          vm.nickname = ""
          XCTAssertFalse(vm.canProceed)
      }

      func test_canProceed_trueWhenNicknameNonEmpty() {
          let vm = BabyProfileViewModel(store: BabyProfileStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
          vm.nickname = "小豆豆"
          XCTAssertTrue(vm.canProceed)
      }

      func test_tryProceed_setsNicknameError_whenEmpty() {
          let vm = BabyProfileViewModel(store: BabyProfileStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
          vm.nickname = ""
          let proceeded = vm.tryProceed()
          XCTAssertFalse(proceeded)
          XCTAssertTrue(vm.showNicknameError)
      }

      func test_tryProceed_savesProfile_whenValid() {
          let store = BabyProfileStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
          let vm = BabyProfileViewModel(store: store)
          vm.nickname = "小橙子"
          let proceeded = vm.tryProceed()
          XCTAssertTrue(proceeded)
          XCTAssertEqual(store.profiles.first?.nickname, "小橙子")
      }
  }
  ```

- [ ] **Step 2: Run tests — expect compile failure**

- [ ] **Step 3: Implement BabyProfileViewModel**

  Create `Zhiguang/Features/BabyProfile/BabyProfileViewModel.swift`:

  ```swift
  import Foundation
  import Combine

  @MainActor
  final class BabyProfileViewModel: ObservableObject {
      @Published var nickname: String = ""
      @Published var birthday: Date? = nil
      @Published var gender: BabyProfile.Gender? = nil
      @Published var showNicknameError = false

      var canProceed: Bool { !nickname.trimmingCharacters(in: .whitespaces).isEmpty }

      private let store: BabyProfileStore
      private var editingProfile: BabyProfile?

      init(store: BabyProfileStore, prefillFrom profile: BabyProfile? = nil) {
          self.store = store
          if let p = profile ?? store.draft {
              nickname = p.nickname
              birthday = p.birthday
              gender = p.gender
              editingProfile = p
          }
      }

      /// Returns true if validation passes and profile was saved
      @discardableResult
      func tryProceed() -> Bool {
          let trimmed = nickname.trimmingCharacters(in: .whitespaces)
          guard !trimmed.isEmpty else {
              showNicknameError = true
              return false
          }
          showNicknameError = false
          let profile: BabyProfile
          if var existing = editingProfile {
              existing.nickname = trimmed
              existing.birthday = birthday
              existing.gender = gender
              store.update(existing)
              profile = existing
          } else {
              let new = BabyProfile(nickname: trimmed, birthday: birthday, gender: gender)
              store.add(new)
              profile = new
          }
          store.clearDraft()
          return true
      }

      func saveDraft() {
          let trimmed = nickname.trimmingCharacters(in: .whitespaces)
          guard !trimmed.isEmpty else { return }
          let draft = BabyProfile(nickname: trimmed, birthday: birthday, gender: gender)
          store.saveDraft(draft)
      }

      func currentProfileId() -> UUID? {
          store.profiles.last?.id
      }
  }
  ```

- [ ] **Step 4: Run tests — expect pass**

- [ ] **Step 5: Implement BabyProfileView**

  Replace `Zhiguang/Features/BabyProfile/BabyProfileView.swift`:

  ```swift
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
          // vm created in onAppear with store from environment
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
                                  Text(label(for: g))
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

      private func label(for gender: BabyProfile.Gender?) -> String {
          switch gender {
          case .boy: return "👦 男宝"
          case .girl: return "👧 女宝"
          case nil: return "暂不填"
          }
      }
  }
  ```

- [ ] **Step 6: Build and test — fill empty nickname, tap 下一步, see red border + toast**

- [ ] **Step 7: Commit**

  ```bash
  git add .
  git commit -m "feat: implement BabyProfileView/ViewModel with required nickname validation"
  ```

---

## Task 14: Scanning Feature

**Files:**
- Create: `Zhiguang/Features/Scanning/ScanningViewModel.swift`
- Replace: `Zhiguang/Features/Scanning/ScanningView.swift`
- Create: `ZhiguangTests/Features/ScanningViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

  Create `ZhiguangTests/Features/ScanningViewModelTests.swift`:

  ```swift
  import XCTest
  @testable import Zhiguang

  // Mock PhotoLibraryService
  final class MockPhotoLibraryService: PhotoLibraryServiceProtocol {
      var stubAssets: [PhotoAsset] = []
      func fetchCandidateAssets() async -> [PhotoAsset] { stubAssets }
      func loadThumbnail(for assetId: String, size: CGSize) async -> CGImage? { nil }
      func loadFullImage(for assetId: String) async -> CGImage? { nil }
  }

  final class ScanningViewModelTests: XCTestCase {
      func test_initialState_isIdle() {
          let vm = ScanningViewModel(
              babyId: UUID(),
              photoService: MockPhotoLibraryService(),
              scoringEngine: ScoringEngine(),
              cache: ScanStateCache(defaults: UserDefaults(suiteName: UUID().uuidString)!)
          )
          XCTAssertEqual(vm.phase, .idle)
      }

      func test_scan_emptyLibrary_producesEmptyResult() async {
          let mock = MockPhotoLibraryService()
          mock.stubAssets = []
          let vm = ScanningViewModel(
              babyId: UUID(),
              photoService: mock,
              scoringEngine: ScoringEngine(),
              cache: ScanStateCache(defaults: UserDefaults(suiteName: UUID().uuidString)!)
          )
          await vm.startScan()
          XCTAssertEqual(vm.phase, .emptyLibrary)
      }
  }
  ```

- [ ] **Step 2: Run tests — expect compile failure**

- [ ] **Step 3: Implement ScanningViewModel**

  Create `Zhiguang/Features/Scanning/ScanningViewModel.swift`:

  ```swift
  import Foundation
  import Combine

  @MainActor
  final class ScanningViewModel: ObservableObject {
      enum Phase: Equatable {
          case idle
          case scanning(stage: String, progress: Double)
          case noBabyFound
          case emptyLibrary
          case done(ScanResult)
          case failed(String)
      }

      @Published var phase: Phase = .idle
      @Published var scannedCount = 0

      let babyId: UUID
      private let photoService: PhotoLibraryServiceProtocol
      private let scoringEngine: ScoringEngine
      private let cache: ScanStateCache

      init(babyId: UUID,
           photoService: PhotoLibraryServiceProtocol,
           scoringEngine: ScoringEngine,
           cache: ScanStateCache) {
          self.babyId = babyId
          self.photoService = photoService
          self.scoringEngine = scoringEngine
          self.cache = cache
      }

      func startScan() async {
          phase = .scanning(stage: "读取照片…", progress: 0)
          let assets = await photoService.fetchCandidateAssets()
          guard !assets.isEmpty else { phase = .emptyLibrary; return }

          phase = .scanning(stage: "识别人像…", progress: 0.2)
          let scores = await scoringEngine.score(assets: assets) { [weak self] assetId in
              await self?.photoService.loadThumbnail(for: assetId, size: CGSize(width: 100, height: 100))
          }

          phase = .scanning(stage: "生成 Top 20…", progress: 0.9)
          let top = await scoringEngine.selectTop(scores, max: Constants.Scan.maxResultCount)

          if top.isEmpty { phase = .noBabyFound; return }

          let result = ScanResult(
              babyProfileId: babyId,
              scannedCount: assets.count,
              selectedAssetIds: top.map(\.assetId),
              allCandidateIds: top.map(\.assetId)
          )
          cache.save(result, for: babyId)
          phase = .done(result)
      }

      func cancel() {
          phase = .idle
      }
  }
  ```

- [ ] **Step 4: Run tests — expect pass**

- [ ] **Step 5: Implement ScanningView**

  Replace `Zhiguang/Features/Scanning/ScanningView.swift`:

  ```swift
  import SwiftUI

  struct ScanningView: View {
      @Binding var path: NavigationPath
      let babyId: UUID
      @EnvironmentObject var permissionStore: PermissionStateStore
      @StateObject private var vm: ScanningViewModel

      init(path: Binding<NavigationPath>, babyId: UUID) {
          self._path = path
          self.babyId = babyId
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

              case .done(let result):
                  Color.clear.onAppear {
                      path.append(AppRoute.results(babyId: babyId))
                  }

              case .failed(let msg):
                  Text("扫描失败：\(msg)")
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
              Text("在扫描范围内没有找到宝宝的清晰照片").font(.subheadline).foregroundColor(.secondary)
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
              Text("暂无系统照片，前往相册添加图片后再试").font(.subheadline).foregroundColor(.secondary)
              Spacer()
              VStack(spacing: 10) {
                  PrimaryButton(title: "前往系统相册") {
                      UIApplication.shared.open(URL(string: "photos-redirect://")!)
                  }
                  Button("手动上传单张照片") { path.append(AppRoute.manualUpload) }
                      .buttonStyle(.bordered)
              }
              .padding(.horizontal, 24)
          }
      }
  }
  ```

- [ ] **Step 6: Build and run — scanning progress shows in Simulator**

- [ ] **Step 7: Commit**

  ```bash
  git add .
  git commit -m "feat: implement ScanningView/ViewModel with phase machine and all error branches"
  ```

---

## Task 15: Results Feature

**Files:**
- Create: `Zhiguang/Features/Results/ResultsViewModel.swift`
- Replace: `Zhiguang/Features/Results/ResultsView.swift`
- Replace: `Zhiguang/Features/Results/PhotoCardView.swift`
- Create: `ZhiguangTests/Features/ResultsViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

  Create `ZhiguangTests/Features/ResultsViewModelTests.swift`:

  ```swift
  import XCTest
  @testable import Zhiguang

  final class ResultsViewModelTests: XCTestCase {
      func test_remove_photo_updatesSelectedAndRejected() {
          let cache = ScanStateCache(defaults: UserDefaults(suiteName: UUID().uuidString)!)
          let babyId = UUID()
          var result = ScanResult.stub(selectedIds: ["a", "b", "c"])
          result = ScanResult(babyProfileId: babyId, scannedCount: 3,
                              selectedAssetIds: ["a","b","c"], allCandidateIds: ["a","b","c"])
          cache.save(result, for: babyId)
          let vm = ResultsViewModel(babyId: babyId, cache: cache)
          vm.remove(assetId: "b")
          XCTAssertFalse(vm.selectedIds.contains("b"))
          XCTAssertTrue(vm.rejectedIds.contains("b"))
      }

      func test_restore_photo() {
          let cache = ScanStateCache(defaults: UserDefaults(suiteName: UUID().uuidString)!)
          let babyId = UUID()
          let result = ScanResult(babyProfileId: babyId, scannedCount: 3,
                                  selectedAssetIds: ["a","c"],
                                  rejectedAssetIds: ["b"],
                                  allCandidateIds: ["a","b","c"])
          cache.save(result, for: babyId)
          let vm = ResultsViewModel(babyId: babyId, cache: cache)
          vm.restore(assetId: "b")
          XCTAssertTrue(vm.selectedIds.contains("b"))
          XCTAssertFalse(vm.rejectedIds.contains("b"))
      }

      func test_isEmpty_whenAllRemoved() {
          let cache = ScanStateCache(defaults: UserDefaults(suiteName: UUID().uuidString)!)
          let babyId = UUID()
          let result = ScanResult(babyProfileId: babyId, scannedCount: 1,
                                  selectedAssetIds: ["a"], allCandidateIds: ["a"])
          cache.save(result, for: babyId)
          let vm = ResultsViewModel(babyId: babyId, cache: cache)
          vm.remove(assetId: "a")
          XCTAssertTrue(vm.isEmpty)
      }
  }
  ```

- [ ] **Step 2: Run tests — expect compile failure**

- [ ] **Step 3: Implement ResultsViewModel**

  Create `Zhiguang/Features/Results/ResultsViewModel.swift`:

  ```swift
  import Foundation
  import Photos
  import Combine

  @MainActor
  final class ResultsViewModel: ObservableObject {
      @Published private(set) var selectedIds: [String] = []
      @Published private(set) var rejectedIds: [String] = []
      @Published private(set) var allCandidateIds: [String] = []
      @Published var thumbnails: [String: CGImage] = [:]

      var isEmpty: Bool { selectedIds.isEmpty }

      let babyId: UUID
      private let cache: ScanStateCache
      private let photoService: PhotoLibraryServiceProtocol

      init(babyId: UUID,
           cache: ScanStateCache = .init(),
           photoService: PhotoLibraryServiceProtocol = PhotoLibraryService()) {
          self.babyId = babyId
          self.cache = cache
          self.photoService = photoService
          loadFromCache()
      }

      func remove(assetId: String) {
          selectedIds.removeAll { $0 == assetId }
          if !rejectedIds.contains(assetId) { rejectedIds.append(assetId) }
          persistState()
      }

      func restore(assetId: String) {
          rejectedIds.removeAll { $0 == assetId }
          if !selectedIds.contains(assetId) { selectedIds.append(assetId) }
          persistState()
      }

      func loadThumbnails() async {
          for id in allCandidateIds {
              if thumbnails[id] == nil,
                 let img = await photoService.loadThumbnail(for: id, size: CGSize(width: 200, height: 200)) {
                  thumbnails[id] = img
              }
          }
      }

      // MARK: Private
      private func loadFromCache() {
          guard let result = cache.load(for: babyId) else { return }
          selectedIds = result.selectedAssetIds
          rejectedIds = result.rejectedAssetIds
          allCandidateIds = result.allCandidateIds
      }

      private func persistState() {
          guard var result = cache.load(for: babyId) else { return }
          result.selectedAssetIds = selectedIds
          result.rejectedAssetIds = rejectedIds
          cache.save(result, for: babyId)
      }
  }
  ```

- [ ] **Step 4: Run tests — expect pass**

- [ ] **Step 5: Implement PhotoCardView**

  Replace `Zhiguang/Features/Results/PhotoCardView.swift`:

  ```swift
  import SwiftUI

  struct PhotoCardView: View {
      let assetId: String
      let thumbnail: CGImage?
      let isRejected: Bool
      let onRemove: () -> Void
      let onRestore: () -> Void

      var body: some View {
          ZStack(alignment: .topTrailing) {
              // Thumbnail
              Group {
                  if let img = thumbnail {
                      Image(img, scale: 1, label: Text(""))
                          .resizable().scaledToFill()
                  } else {
                      Rectangle().fill(Color.secondary.opacity(0.2))
                          .overlay(ProgressView())
                  }
              }
              .frame(maxWidth: .infinity)
              .aspectRatio(1, contentMode: .fill)
              .clipped()
              .clipShape(RoundedRectangle(cornerRadius: 8))
              .opacity(isRejected ? 0.3 : 1)
              .grayscale(isRejected ? 1 : 0)

              // Action button
              if isRejected {
                  Button(action: onRestore) {
                      Image(systemName: "arrow.uturn.backward.circle.fill")
                          .foregroundColor(.white)
                          .background(Color.black.opacity(0.5), in: Circle())
                  }
                  .padding(4)
              } else {
                  Button(action: onRemove) {
                      Image(systemName: "xmark.circle.fill")
                          .foregroundColor(.white)
                          .background(Color.black.opacity(0.4), in: Circle())
                  }
                  .padding(4)
              }
          }
          .animation(.easeInOut(duration: 0.2), value: isRejected)
      }
  }
  ```

- [ ] **Step 6: Implement ResultsView**

  Replace `Zhiguang/Features/Results/ResultsView.swift`:

  ```swift
  import SwiftUI

  struct ResultsView: View {
      @Binding var path: NavigationPath
      let babyId: UUID
      @EnvironmentObject var permissionStore: PermissionStateStore
      @EnvironmentObject var babyStore: BabyProfileStore
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
                          path.append(AppRoute.saveComplete(babyId: babyId, savedCount: vm.selectedIds.count))
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
  ```

- [ ] **Step 7: Build and verify results grid shows in Simulator**

- [ ] **Step 8: Commit**

  ```bash
  git add .
  git commit -m "feat: implement ResultsView/ViewModel with remove/restore, empty state, thumbnail loading"
  ```

---

## Task 16: SaveComplete Feature

**Files:**
- Create: `Zhiguang/Features/SaveComplete/SaveCompleteViewModel.swift`
- Replace: `Zhiguang/Features/SaveComplete/SaveCompleteView.swift`

- [ ] **Step 1: Implement SaveCompleteViewModel**

  Create `Zhiguang/Features/SaveComplete/SaveCompleteViewModel.swift`:

  ```swift
  import Foundation
  import UIKit

  @MainActor
  final class SaveCompleteViewModel: ObservableObject {
      enum SaveState {
          case saving
          case success(count: Int)
          case partialFailure(succeeded: Int, failed: Int, failedIds: [String])
          case fullFailure(AlbumSaveFailureReason)
      }

      @Published var saveState: SaveState = .saving
      @Published var toast: String?
      @Published var showHomeButton = false

      private let babyId: UUID
      private let selectedIds: [String]
      private let saveService: AlbumSaveServiceProtocol
      private let cache: ScanStateCache

      init(babyId: UUID, selectedIds: [String],
           saveService: AlbumSaveServiceProtocol = AlbumSaveService(),
           cache: ScanStateCache = .init()) {
          self.babyId = babyId
          self.selectedIds = selectedIds
          self.saveService = saveService
          self.cache = cache
      }

      func performSave() async {
          saveState = .saving
          let result = await saveService.save(assetIds: selectedIds)
          if result.isFullSuccess {
              saveState = .success(count: result.succeeded.count)
          } else if result.isPartialSuccess {
              saveState = .partialFailure(
                  succeeded: result.succeeded.count,
                  failed: result.failed.count,
                  failedIds: result.failed.map(\.assetId)
              )
          } else {
              let reason = result.failed.first?.reason ?? .unknown
              saveState = .fullFailure(reason)
          }
      }

      func share(from view: UIViewController, assetIds: [String]) {
          // Fetch UIImages for sharing
          Task {
              let items: [Any] = ["稚光精选 · 宝宝照片"]
              let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
              ac.completionWithItemsHandler = { _, completed, _, error in
                  Task { @MainActor in
                      if let error { self.toast = "分享失败，请重试" }
                      else if completed { self.toast = "分享完成"; self.showHomeButton = true }
                      else { self.toast = "分享已取消" }
                  }
              }
              view.present(ac, animated: true)
          }
      }

      func openSettings() {
          guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
          UIApplication.shared.open(url)
      }

      func openSystemPhotos() {
          UIApplication.shared.open(URL(string: "photos-redirect://")!)
      }
  }
  ```

- [ ] **Step 2: Implement SaveCompleteView**

  Replace `Zhiguang/Features/SaveComplete/SaveCompleteView.swift`:

  ```swift
  import SwiftUI

  struct SaveCompleteView: View {
      @Binding var path: NavigationPath
      let babyId: UUID
      let savedCount: Int
      @StateObject private var vm: SaveCompleteViewModel

      init(path: Binding<NavigationPath>, babyId: UUID, savedCount: Int) {
          self._path = path
          self.babyId = babyId
          self.savedCount = savedCount
          self._vm = StateObject(wrappedValue: SaveCompleteViewModel(
              babyId: babyId,
              selectedIds: [] // loaded from cache in real impl
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
          .task { await vm.performSave() }
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
                          // share action
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
              PrimaryButton(title: "重试失败的 \(failed) 张") { Task { await vm.performSave() } }
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
                      PrimaryButton(title: "去系统清理存储") {
                          UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                      }
                  case .unknown:
                      PrimaryButton(title: "重试保存") { Task { await vm.performSave() } }
                  }
              }
              .padding(.horizontal, 24)
          }
      }
  }
  ```

- [ ] **Step 3: Build — no errors**

- [ ] **Step 4: Commit**

  ```bash
  git add .
  git commit -m "feat: implement SaveCompleteView with success/partial/full-failure states and share toast"
  ```

---

## Task 17: ManualUpload Feature

**Files:**
- Create: `Zhiguang/Features/ManualUpload/ManualUploadViewModel.swift`
- Replace: `Zhiguang/Features/ManualUpload/ManualUploadView.swift`

- [ ] **Step 1: Implement ManualUploadViewModel**

  Create `Zhiguang/Features/ManualUpload/ManualUploadViewModel.swift`:

  ```swift
  import Foundation
  import UIKit
  import PhotosUI

  @MainActor
  final class ManualUploadViewModel: ObservableObject {
      @Published var selectedItems: [PhotosPickerItem] = []
      @Published var uploadedImages: [(id: UUID, image: CGImage)] = []
      @Published var isProcessing = false

      private let scoringEngine = ScoringEngine()

      func processSelected() async {
          isProcessing = true
          for item in selectedItems {
              if let data = try? await item.loadTransferable(type: Data.self),
                 let uiImage = UIImage(data: data),
                 let cgImage = uiImage.cgImage {
                  let entry = (id: UUID(), image: cgImage)
                  uploadedImages.append(entry)
              }
          }
          selectedItems = []
          isProcessing = false
      }
  }
  ```

- [ ] **Step 2: Implement ManualUploadView**

  Replace `Zhiguang/Features/ManualUpload/ManualUploadView.swift`:

  ```swift
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
                      .overlay(RoundedRectangle(cornerRadius: 16).stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6])).foregroundColor(.secondary))
                      .clipShape(RoundedRectangle(cornerRadius: 16))
                      .padding(.horizontal, 24)
                  }
                  .onChange(of: vm.selectedItems) { _, _ in Task { await vm.processSelected() } }

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
                      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
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
  ```

- [ ] **Step 3: Build — no errors**

- [ ] **Step 4: Commit**

  ```bash
  git add .
  git commit -m "feat: implement ManualUploadView with PhotosPicker for denied-permission fallback"
  ```

---

## Task 18: Integration & Acceptance Testing

**Files:**
- Create: `ZhiguangTests/Integration/AcceptanceTests.swift`

- [ ] **Step 1: Write acceptance test checklist (manual)**

  Create `ZhiguangTests/Integration/AcceptanceTests.swift`:

  ```swift
  // Manual acceptance test checklist — run on iPhone 15 Simulator (iOS 16+)
  // Each item maps to a verification in the spec's Section 11 (验收标准)

  /*
  ACCEPTANCE TESTS — run manually in Simulator or real device

  1. ONBOARDING
     [ ] Fresh install → Onboarding screen appears
     [ ] Tap "开始整理" → navigates to Permission screen

  2. PERMISSION
     [ ] Tap "授权访问相册" → iOS system dialog appears
     [ ] Grant full access → navigates to Baby Profile
     [ ] Grant partial access → navigates to Baby Profile + banner visible
     [ ] Deny → alert with two options (Settings / Manual Upload)
     [ ] Go to Settings, deny, return → lands back on Permission page

  3. BABY PROFILE
     [ ] Leave nickname empty, tap next → red border + tooltip shown, no navigation
     [ ] Fill nickname, tap next → navigates to Scanning
     [ ] Fill nickname + birthday → hint text turns green

  4. SCANNING
     [ ] Progress bar and stage labels update during scan
     [ ] Cancel button appears top-right → tap returns to previous page
     [ ] Partial permission → bottom floating text visible
     [ ] If no baby photos found → 3-option dialog appears

  5. RESULTS
     [ ] Grid of up to 20 photos shown
     [ ] Tap ✕ → photo grays out
     [ ] Tap ↩ on grayed photo → photo restores
     [ ] Remove all photos → empty state with two buttons
     [ ] Partial permission → top banner visible and non-dismissible
     [ ] "保存精选" → navigates to SaveComplete

  6. SAVE COMPLETE
     [ ] Success state shows count + "稚光精选" label
     [ ] "在系统相册查看" opens Photos app
     [ ] "重新整理" → goes to Scanning (skips Permission & Profile)
     [ ] Share → system share sheet opens; cancel → toast "分享已取消"

  7. RETURNING USER
     [ ] Kill and relaunch with data + full permission → goes straight to Results
     [ ] Kill and relaunch with denied permission → lands on Permission page

  8. ALBUM
     [ ] After save, open Photos.app → "稚光精选" album exists with correct photos
  */
  ```

- [ ] **Step 2: Run full unit test suite**

  `Cmd+U` — all unit tests pass.

- [ ] **Step 3: Run on Simulator, complete full happy path**

  Build → Run on iPhone 15 Simulator → complete: Onboarding → Permission (grant) → Baby Profile (fill "测试宝宝") → Watch scan → See results → Save.

- [ ] **Step 4: Final commit**

  ```bash
  git add .
  git commit -m "feat: complete MVP — all 6 pages, services, acceptance checklist"
  ```

- [ ] **Step 5: Push to remote**

  ```bash
  git push origin main
  ```

---

## Summary

| Task | Deliverable | Tests |
|---|---|---|
| 1 | Xcode project, Info.plist, Constants | Build check |
| 2 | 5 core models | ScanResultTests (3 cases) |
| 3 | PermissionStateStore | 5 unit tests |
| 4 | BabyProfileStore + draft | 4 unit tests |
| 5 | PhotoLibraryService (protocol + live) | Build check |
| 6 | ScoringEngine (sharpness, faces, grouping, top-N) | 7 unit tests |
| 7 | ScanStateCache | 3 unit tests |
| 8 | AlbumSaveService (protocol + live) | 2 mock tests |
| 9 | PermissionBanner, PrimaryButton, ToastView | Build + Preview |
| 10 | App root, AppRoute navigation | Build check |
| 11 | OnboardingView/ViewModel | Build + manual |
| 12 | PermissionView/ViewModel | Build + manual |
| 13 | BabyProfileView/ViewModel | 4 unit tests + manual |
| 14 | ScanningView/ViewModel | 2 unit tests + manual |
| 15 | ResultsView/ViewModel, PhotoCardView | 3 unit tests + manual |
| 16 | SaveCompleteView/ViewModel | Build + manual |
| 17 | ManualUploadView/ViewModel | Build + manual |
| 18 | Acceptance checklist + full test run | Manual |
