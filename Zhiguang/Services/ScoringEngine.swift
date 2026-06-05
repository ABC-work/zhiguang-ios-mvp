import Foundation
import Vision
import CoreImage
import CoreGraphics

actor ScoringEngine {

    // MARK: - Public API
    func score(assets: [PhotoAsset],
               thumbnailProvider: @Sendable (String) async -> CGImage?) async -> [PhotoScore] {
        var scores: [PhotoScore] = []

        for batch in assets.chunked(into: Constants.Scan.batchSize) {
            for asset in batch {
                guard let thumbnail = await thumbnailProvider(asset.id) else { continue }
                let sharpness = sharpnessScore(for: thumbnail)
                guard sharpness > 0 else { continue }

                var score = PhotoScore(assetId: asset.id)
                score.sharpnessScore = sharpness

                let faceResult = await detectFaces(in: thumbnail)
                guard faceResult.hasFace else { continue }

                score.faceScore = faceResult.faceScore
                score.expressionScore = faceResult.expressionScore
                score.compositionScore = faceResult.compositionScore
                score.reasons = faceResult.reasons
                score.totalScore = computeTotal(score)
                scores.append(score)
            }
        }

        let assetMap = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
        let groups = groupBursts(scores.compactMap { assetMap[$0.assetId] })
        scores = applyBurstPenalty(scores: scores, groups: groups)
        return scores
    }

    // MARK: - Sharpness (Laplacian via CIEdges)
    func sharpnessScore(for image: CGImage) -> Float {
        let variance = laplacianVariance(image)
        guard variance >= Constants.Scan.sharpnessThreshold else { return 0 }
        let normalized = min(Float((variance - Constants.Scan.sharpnessThreshold) / 450.0 * 10.0), 10.0)
        return max(normalized, 0)
    }

    // MARK: - Burst Grouping
    func groupBursts(_ assets: [PhotoAsset]) -> [[PhotoAsset]] {
        guard !assets.isEmpty else { return [] }
        let sorted = assets.sorted {
            ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
        }
        var groups: [[PhotoAsset]] = [[sorted[0]]]
        for asset in sorted.dropFirst() {
            let prev = groups[groups.count - 1].last!
            let interval = (asset.creationDate ?? .now)
                .timeIntervalSince(prev.creationDate ?? .now)
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
        Array(scores.sorted { $0.adjustedTotal > $1.adjustedTotal }.prefix(count))
    }

    // MARK: - Private: Laplacian Variance
    private func laplacianVariance(_ image: CGImage) -> Double {
        let ciImage = CIImage(cgImage: image)
        let filtered = ciImage.applyingFilter("CIEdges")
        let ctx = CIContext()
        guard let cgFiltered = ctx.createCGImage(filtered, from: filtered.extent),
              let data = cgFiltered.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return 0 }
        let len = CFDataGetLength(data)
        var sum: Double = 0
        var sumSq: Double = 0
        for i in 0..<len {
            let v = Double(ptr[i])
            sum += v
            sumSq += v * v
        }
        let n = Double(len)
        guard n > 0 else { return 0 }
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
            let request = VNDetectFaceLandmarksRequest { req, _ in
                guard let observations = req.results as? [VNFaceObservation],
                      let face = observations.first else {
                    continuation.resume(returning: FaceResult(
                        hasFace: false, faceScore: 0,
                        expressionScore: 0, compositionScore: 0, reasons: []))
                    return
                }
                let size = CGSize(width: image.width, height: image.height)
                let faceScore = self.computeFaceScore(face, imageSize: size)
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
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }

    private func computeFaceScore(_ face: VNFaceObservation, imageSize: CGSize) -> Float {
        let area = face.boundingBox.width * face.boundingBox.height
        return Float(min(area * 40.0, 1.0) * 10.0)
    }

    private func computeExpressionScore(_ face: VNFaceObservation) -> Float {
        guard let landmarks = face.landmarks else { return 5.0 }
        var score: Float = 5.0
        if landmarks.outerLips != nil { score += 2.5 }
        if landmarks.leftEye != nil && landmarks.rightEye != nil { score += 2.5 }
        return min(score, 10.0)
    }

    private func computeCompositionScore(_ face: VNFaceObservation) -> Float {
        let box = face.boundingBox
        let withinFrame = box.minX >= 0 && box.minY >= 0 &&
                          box.maxX <= 1 && box.maxY <= 1
        let centerDist = hypot(box.midX - 0.5, box.midY - 0.5)
        let centerScore = Float(max(0.0, 1.0 - centerDist * 2.0))
        return (withinFrame ? 5.0 : 2.0) + centerScore * 5.0
    }

    private func computeTotal(_ score: PhotoScore) -> Float {
        score.faceScore       * 0.30 +
        score.sharpnessScore  * 0.25 +
        score.expressionScore * 0.20 +
        score.compositionScore * 0.15
    }

    private func applyBurstPenalty(scores: [PhotoScore],
                                    groups: [[PhotoAsset]]) -> [PhotoScore] {
        var result = scores
        var indexMap: [String: Int] = [:]
        for (i, s) in scores.enumerated() { indexMap[s.assetId] = i }

        for group in groups where group.count > 1 {
            let ranked = group
                .compactMap { asset -> (String, Float)? in
                    guard let idx = indexMap[asset.id] else { return nil }
                    return (asset.id, result[idx].adjustedTotal)
                }
                .sorted { $0.1 > $1.1 }

            for (rank, (assetId, _)) in ranked.enumerated() {
                if rank >= Constants.Scan.maxPerBurstGroup,
                   let idx = indexMap[assetId] {
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
