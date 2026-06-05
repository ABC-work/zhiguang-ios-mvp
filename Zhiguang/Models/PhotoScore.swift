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

    init(assetId: String, totalScore: Float = 0) {
        self.assetId = assetId
        self.totalScore = totalScore
    }
}
