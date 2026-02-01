// IGA/Data/Models/Attempt.swift

import Foundation
import SwiftData

// MARK: - Attempt

/// Records a single question attempt with timing and ability tracking
@Model
final class Attempt {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Question that was attempted
    var questionID: String

    /// Session this attempt belongs to
    var sessionID: UUID

    /// Selected answer index (nil if skipped)
    var selectedAnswer: Int?

    /// Whether the answer was correct
    var isCorrect: Bool

    /// Time spent on this question (milliseconds)
    var responseTimeMs: Int

    /// Number of hints used (0-5)
    var hintsUsed: Int

    /// When the attempt was made
    var timestamp: Date

    /// Primary subskill tested
    var subskillID: String

    // MARK: - Ability Tracking

    /// Theta estimate before this attempt
    var thetaBefore: Double?

    /// Theta estimate after this attempt
    var thetaAfter: Double?

    /// P(Known) before this attempt
    var pKnownBefore: Double?

    /// P(Known) after this attempt
    var pKnownAfter: Double?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        questionID: String,
        sessionID: UUID,
        selectedAnswer: Int? = nil,
        isCorrect: Bool,
        responseTimeMs: Int,
        hintsUsed: Int = 0,
        timestamp: Date = Date(),
        subskillID: String,
        thetaBefore: Double? = nil,
        thetaAfter: Double? = nil,
        pKnownBefore: Double? = nil,
        pKnownAfter: Double? = nil
    ) {
        self.id = id
        self.questionID = questionID
        self.sessionID = sessionID
        self.selectedAnswer = selectedAnswer
        self.isCorrect = isCorrect
        self.responseTimeMs = responseTimeMs
        self.hintsUsed = hintsUsed
        self.timestamp = timestamp
        self.subskillID = subskillID
        self.thetaBefore = thetaBefore
        self.thetaAfter = thetaAfter
        self.pKnownBefore = pKnownBefore
        self.pKnownAfter = pKnownAfter
    }

    // MARK: - Computed Properties

    /// Response time in seconds
    var responseTimeSeconds: Double {
        Double(responseTimeMs) / 1000.0
    }

    /// Whether hints were used
    var usedHints: Bool {
        hintsUsed > 0
    }

    /// Whether the question was skipped
    var wasSkipped: Bool {
        selectedAnswer == nil
    }

    /// Theta change from this attempt
    var thetaDelta: Double? {
        guard let before = thetaBefore, let after = thetaAfter else { return nil }
        return after - before
    }

    /// P(Known) change from this attempt
    var pKnownDelta: Double? {
        guard let before = pKnownBefore, let after = pKnownAfter else { return nil }
        return after - before
    }

    /// Subskill enum (if valid)
    var subskill: Subskill? {
        Subskill(rawValue: subskillID)
    }
}

// MARK: - Attempt Summary

/// Lightweight summary of an attempt for analytics
struct AttemptSummary: Codable, Sendable {
    let questionID: String
    let isCorrect: Bool
    let responseTimeMs: Int
    let hintsUsed: Int
    let subskillID: String
    let timestamp: Date

    init(from attempt: Attempt) {
        self.questionID = attempt.questionID
        self.isCorrect = attempt.isCorrect
        self.responseTimeMs = attempt.responseTimeMs
        self.hintsUsed = attempt.hintsUsed
        self.subskillID = attempt.subskillID
        self.timestamp = attempt.timestamp
    }
}

// MARK: - Preview Data

extension Attempt {
    static var preview: Attempt {
        Attempt(
            questionID: "q-preview-1",
            sessionID: UUID(),
            selectedAnswer: 2,
            isCorrect: true,
            responseTimeMs: 45000,
            hintsUsed: 0,
            subskillID: Subskill.qAlgebra.rawValue,
            thetaBefore: 0.3,
            thetaAfter: 0.4
        )
    }

    static var previewList: [Attempt] {
        let sessionID = UUID()
        return [
            Attempt(
                questionID: "q-1",
                sessionID: sessionID,
                selectedAnswer: 2,
                isCorrect: true,
                responseTimeMs: 45000,
                subskillID: Subskill.qAlgebra.rawValue
            ),
            Attempt(
                questionID: "q-2",
                sessionID: sessionID,
                selectedAnswer: 1,
                isCorrect: false,
                responseTimeMs: 90000,
                hintsUsed: 1,
                subskillID: Subskill.qGeometry.rawValue
            ),
            Attempt(
                questionID: "q-3",
                sessionID: sessionID,
                selectedAnswer: 0,
                isCorrect: true,
                responseTimeMs: 30000,
                subskillID: Subskill.vSentenceEquiv.rawValue
            )
        ]
    }
}
