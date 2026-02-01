// IGA/Data/Models/DiagnosticResult.swift

import Foundation
import SwiftData

// MARK: - Subskill Estimate

/// Estimate for a single subskill from diagnostic
struct SubskillEstimate: Codable, Sendable {
    /// Ability estimate (theta)
    let theta: Double

    /// Standard error of estimate
    let standardError: Double

    /// Number of items administered
    let itemCount: Int

    /// Accuracy on those items
    let accuracy: Double

    /// Whether estimate is confident (SE < 0.3)
    var isConfident: Bool {
        standardError < 0.3
    }

    /// Estimated mastery level
    var estimatedMasteryLevel: MasteryLevel {
        // Map theta to pKnown, then to mastery level
        let pKnown = 0.5 + (theta / 6.0) * 0.8
        return MasteryLevel.from(pKnown: max(0.1, min(0.9, pKnown)))
    }
}

// MARK: - Diagnostic Result

/// Snapshot of a completed diagnostic assessment
@Model
final class DiagnosticResult {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// When the diagnostic was completed
    var completedAt: Date

    /// Per-subskill estimates (stored as JSON Data)
    var subskillEstimatesData: Data

    /// Overall quant theta (average of quant subskills)
    var overallQuantTheta: Double

    /// Overall verbal theta (average of verbal subskills)
    var overallVerbalTheta: Double

    /// Recommended focus areas (subskill IDs)
    var recommendedFocusAreas: [String]

    /// Total time spent on diagnostic (seconds)
    var totalTimeSeconds: Int

    /// Total items administered
    var totalItemCount: Int

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        completedAt: Date = Date(),
        subskillEstimates: [String: SubskillEstimate],
        overallQuantTheta: Double,
        overallVerbalTheta: Double,
        recommendedFocusAreas: [String],
        totalTimeSeconds: Int
    ) {
        self.id = id
        self.completedAt = completedAt
        self.overallQuantTheta = overallQuantTheta
        self.overallVerbalTheta = overallVerbalTheta
        self.recommendedFocusAreas = recommendedFocusAreas
        self.totalTimeSeconds = totalTimeSeconds
        self.totalItemCount = subskillEstimates.values.reduce(0) { $0 + $1.itemCount }

        // Encode estimates to Data
        let encoder = JSONEncoder()
        self.subskillEstimatesData = (try? encoder.encode(subskillEstimates)) ?? Data()
    }

    // MARK: - Computed Properties

    /// Decoded subskill estimates
    var subskillEstimates: [String: SubskillEstimate] {
        let decoder = JSONDecoder()
        return (try? decoder.decode([String: SubskillEstimate].self, from: subskillEstimatesData)) ?? [:]
    }

    /// Overall combined theta
    var overallTheta: Double {
        (overallQuantTheta + overallVerbalTheta) / 2.0
    }

    /// Estimated GRE scaled score for quant (130-170)
    var estimatedQuantScore: Int {
        thetaToScaledScore(overallQuantTheta, section: .quant)
    }

    /// Estimated GRE scaled score for verbal (130-170)
    var estimatedVerbalScore: Int {
        thetaToScaledScore(overallVerbalTheta, section: .verbal)
    }

    /// Total estimated score
    var estimatedTotalScore: Int {
        estimatedQuantScore + estimatedVerbalScore
    }

    /// Formatted duration string
    var formattedDuration: String {
        let minutes = totalTimeSeconds / 60
        let seconds = totalTimeSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Weakest subskills (lowest theta)
    var weakestSubskills: [String] {
        subskillEstimates
            .sorted { $0.value.theta < $1.value.theta }
            .prefix(3)
            .map { $0.key }
    }

    /// Strongest subskills (highest theta)
    var strongestSubskills: [String] {
        subskillEstimates
            .sorted { $0.value.theta > $1.value.theta }
            .prefix(3)
            .map { $0.key }
    }

    // MARK: - Score Conversion

    /// Convert theta to GRE scaled score
    private func thetaToScaledScore(_ theta: Double, section: QuestionSection) -> Int {
        // Lookup table approximation
        // theta: -3 to +3 maps to score: 130 to 170
        let normalized = (theta + 3) / 6.0  // 0 to 1
        let score = 130 + normalized * 40
        return max(130, min(170, Int(score.rounded())))
    }
}

// MARK: - Factory Methods

extension DiagnosticResult {
    /// Create from subskill progress data
    static func create(
        from progress: [String: (theta: Double, se: Double, attempts: Int, correct: Int)],
        totalTimeSeconds: Int
    ) -> DiagnosticResult {
        var estimates: [String: SubskillEstimate] = [:]

        for (subskillID, data) in progress {
            let accuracy = data.attempts > 0 ? Double(data.correct) / Double(data.attempts) : 0
            estimates[subskillID] = SubskillEstimate(
                theta: data.theta,
                standardError: data.se,
                itemCount: data.attempts,
                accuracy: accuracy
            )
        }

        // Calculate section averages
        let quantIDs = Subskill.quantSubskills.map { $0.rawValue }
        let verbalIDs = Subskill.verbalSubskills.map { $0.rawValue }

        let quantThetas = quantIDs.compactMap { estimates[$0]?.theta }
        let verbalThetas = verbalIDs.compactMap { estimates[$0]?.theta }

        let quantAvg = quantThetas.isEmpty ? 0 : quantThetas.reduce(0, +) / Double(quantThetas.count)
        let verbalAvg = verbalThetas.isEmpty ? 0 : verbalThetas.reduce(0, +) / Double(verbalThetas.count)

        // Find weakest areas
        let weakest = estimates
            .sorted { $0.value.theta < $1.value.theta }
            .prefix(3)
            .map { $0.key }

        return DiagnosticResult(
            subskillEstimates: estimates,
            overallQuantTheta: quantAvg,
            overallVerbalTheta: verbalAvg,
            recommendedFocusAreas: Array(weakest),
            totalTimeSeconds: totalTimeSeconds
        )
    }
}

// MARK: - Preview Data

extension DiagnosticResult {
    static var preview: DiagnosticResult {
        let estimates: [String: SubskillEstimate] = [
            "Q-AR": SubskillEstimate(theta: 0.8, standardError: 0.25, itemCount: 4, accuracy: 0.75),
            "Q-AL": SubskillEstimate(theta: -0.3, standardError: 0.30, itemCount: 4, accuracy: 0.50),
            "Q-GE": SubskillEstimate(theta: 0.5, standardError: 0.28, itemCount: 3, accuracy: 0.67),
            "Q-WP": SubskillEstimate(theta: 0.2, standardError: 0.32, itemCount: 4, accuracy: 0.50),
            "Q-DA": SubskillEstimate(theta: 0.6, standardError: 0.27, itemCount: 4, accuracy: 0.75),
            "V-SE": SubskillEstimate(theta: 1.0, standardError: 0.22, itemCount: 4, accuracy: 0.75),
            "V-TC": SubskillEstimate(theta: 0.7, standardError: 0.26, itemCount: 4, accuracy: 0.75),
            "V-RC-D": SubskillEstimate(theta: 0.4, standardError: 0.30, itemCount: 3, accuracy: 0.67),
            "V-RC-S": SubskillEstimate(theta: 0.3, standardError: 0.32, itemCount: 3, accuracy: 0.67)
        ]

        return DiagnosticResult(
            subskillEstimates: estimates,
            overallQuantTheta: 0.36,
            overallVerbalTheta: 0.60,
            recommendedFocusAreas: ["Q-AL", "Q-WP", "V-RC-S"],
            totalTimeSeconds: 1800
        )
    }
}
