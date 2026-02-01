// IGA/Data/Models/SubskillMasteryState.swift

import Foundation
import SwiftData

// MARK: - Subskill Mastery State

/// Tracks mastery state for a single subskill using IRT + BKT
@Model
final class SubskillMasteryState {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Subskill identifier (e.g., "Q-AL")
    var subskillID: String

    // MARK: - IRT State

    /// Current ability estimate (theta)
    /// Range: typically -3 to +3
    var thetaEstimate: Double

    /// Standard error of theta estimate
    /// Lower = more confident
    var thetaSE: Double

    // MARK: - BKT State

    /// Probability the skill is known P(L)
    /// Range: 0 to 1
    var pKnown: Double

    /// Learning rate P(T) - probability of learning per opportunity
    /// Adapts based on performance
    var pLearn: Double

    /// Forgetting rate P(F) - probability of forgetting per day
    var pForget: Double

    // MARK: - Statistics

    /// Total attempts on this subskill
    var attemptCount: Int

    /// Total correct answers
    var correctCount: Int

    /// Last practice timestamp
    var lastPracticed: Date?

    /// When this mastery state was created
    var createdAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        subskillID: String,
        thetaEstimate: Double = 0.0,
        thetaSE: Double = 1.0,
        pKnown: Double = 0.3,
        pLearn: Double = 0.10,
        pForget: Double = 0.02,
        attemptCount: Int = 0,
        correctCount: Int = 0,
        lastPracticed: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.subskillID = subskillID
        self.thetaEstimate = thetaEstimate
        self.thetaSE = thetaSE
        self.pKnown = pKnown
        self.pLearn = pLearn
        self.pForget = pForget
        self.attemptCount = attemptCount
        self.correctCount = correctCount
        self.lastPracticed = lastPracticed
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    /// Current mastery level derived from pKnown
    var masteryLevel: MasteryLevel {
        MasteryLevel.from(pKnown: pKnown)
    }

    /// Accuracy rate (0 to 1)
    var accuracy: Double {
        guard attemptCount > 0 else { return 0 }
        return Double(correctCount) / Double(attemptCount)
    }

    /// Days since last practice (nil if never practiced)
    var daysSinceLastPractice: Int? {
        guard let last = lastPracticed else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }

    /// Whether this subskill needs review (decay risk)
    var needsReview: Bool {
        guard let days = daysSinceLastPractice else { return true }
        // Risk increases with days and inversely with mastery
        let riskThreshold = masteryLevel == .mastered ? 7 : 3
        return days >= riskThreshold
    }

    /// Subskill enum (if valid)
    var subskill: Subskill? {
        Subskill(rawValue: subskillID)
    }

    // MARK: - Updates

    /// Record an attempt and update statistics
    func recordAttempt(isCorrect: Bool, timestamp: Date = Date()) {
        attemptCount += 1
        if isCorrect {
            correctCount += 1
        }
        lastPracticed = timestamp
    }

    /// Update theta estimate from IRT
    func updateTheta(theta: Double, se: Double) {
        thetaEstimate = theta
        thetaSE = se
    }

    /// Update BKT state
    func updateBKT(pKnown: Double, pLearn: Double? = nil) {
        self.pKnown = max(0, min(1, pKnown))
        if let newPLearn = pLearn {
            self.pLearn = max(0.05, min(0.20, newPLearn))
        }
    }
}

// MARK: - Factory Methods

extension SubskillMasteryState {
    /// Create initial mastery states for all subskills
    static func createAllSubskills() -> [SubskillMasteryState] {
        Subskill.allCases.map { subskill in
            SubskillMasteryState(subskillID: subskill.rawValue)
        }
    }

    /// Create from diagnostic result
    static func fromDiagnostic(
        subskillID: String,
        theta: Double,
        se: Double,
        attemptCount: Int,
        correctCount: Int
    ) -> SubskillMasteryState {
        // Derive initial pKnown from theta
        // Map theta (-3 to +3) to pKnown (0.1 to 0.9)
        let pKnown = 0.5 + (theta / 6.0) * 0.8  // theta=0 → 0.5, theta=3 → 0.9
        let clampedPKnown = max(0.1, min(0.9, pKnown))

        return SubskillMasteryState(
            subskillID: subskillID,
            thetaEstimate: theta,
            thetaSE: se,
            pKnown: clampedPKnown,
            attemptCount: attemptCount,
            correctCount: correctCount,
            lastPracticed: Date()
        )
    }
}

// MARK: - Preview Data

extension SubskillMasteryState {
    static var preview: SubskillMasteryState {
        SubskillMasteryState(
            subskillID: Subskill.qAlgebra.rawValue,
            thetaEstimate: 0.5,
            thetaSE: 0.25,
            pKnown: 0.65,
            attemptCount: 25,
            correctCount: 18,
            lastPracticed: Date().addingTimeInterval(-86400)  // Yesterday
        )
    }

    static var previewList: [SubskillMasteryState] {
        [
            SubskillMasteryState(
                subskillID: Subskill.qArithmetic.rawValue,
                thetaEstimate: 0.8,
                thetaSE: 0.20,
                pKnown: 0.78,
                attemptCount: 30,
                correctCount: 24,
                lastPracticed: Date()
            ),
            SubskillMasteryState(
                subskillID: Subskill.qAlgebra.rawValue,
                thetaEstimate: -0.3,
                thetaSE: 0.30,
                pKnown: 0.42,
                attemptCount: 15,
                correctCount: 8,
                lastPracticed: Date().addingTimeInterval(-172800)  // 2 days ago
            ),
            SubskillMasteryState(
                subskillID: Subskill.vSentenceEquiv.rawValue,
                thetaEstimate: 1.2,
                thetaSE: 0.18,
                pKnown: 0.88,
                attemptCount: 40,
                correctCount: 35,
                lastPracticed: Date()
            )
        ]
    }
}
