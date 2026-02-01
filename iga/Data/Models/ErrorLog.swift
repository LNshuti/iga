// IGA/Data/Models/ErrorLog.swift

import Foundation
import SwiftData

// MARK: - Error Type

/// Categories of common GRE mistakes
enum ErrorType: String, Codable, CaseIterable, Sendable {
    case conceptual = "conceptual"       // Didn't understand the concept
    case careless = "careless"           // Knew it but made a silly mistake
    case timePressure = "time_pressure"  // Ran out of time
    case misread = "misread"             // Misread the question or answer
    case calculation = "calculation"     // Arithmetic/calculation error
    case vocabulary = "vocabulary"       // Didn't know the word
    case strategy = "strategy"           // Used wrong approach
    case unknown = "unknown"             // Not categorized

    var displayName: String {
        switch self {
        case .conceptual: return "Conceptual Gap"
        case .careless: return "Careless Error"
        case .timePressure: return "Time Pressure"
        case .misread: return "Misread Question"
        case .calculation: return "Calculation Error"
        case .vocabulary: return "Vocabulary Gap"
        case .strategy: return "Wrong Strategy"
        case .unknown: return "Uncategorized"
        }
    }

    var icon: String {
        switch self {
        case .conceptual: return "brain.head.profile"
        case .careless: return "exclamationmark.triangle"
        case .timePressure: return "timer"
        case .misread: return "eye.slash"
        case .calculation: return "function"
        case .vocabulary: return "textformat.abc"
        case .strategy: return "arrow.triangle.branch"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .conceptual: return "purple"
        case .careless: return "orange"
        case .timePressure: return "red"
        case .misread: return "yellow"
        case .calculation: return "blue"
        case .vocabulary: return "green"
        case .strategy: return "teal"
        case .unknown: return "gray"
        }
    }
}

// MARK: - Error Log Entry

/// A logged mistake for review and analysis
@Model
final class ErrorLogEntry {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Question that was answered incorrectly
    var questionID: String

    /// Attempt that recorded this error
    var attemptID: UUID

    /// Error type classification
    var errorTypeRaw: String

    /// User's selected answer
    var selectedAnswer: Int

    /// Correct answer
    var correctAnswer: Int

    /// User's notes about their mistake
    var userNotes: String?

    /// Whether user has reviewed this error
    var hasReviewed: Bool

    /// Whether user got it right on retry
    var retriedCorrectly: Bool?

    /// When the error occurred
    var timestamp: Date

    /// When user last reviewed this error
    var lastReviewedAt: Date?

    /// Subskill this error relates to
    var subskillID: String

    /// Response time (ms) - useful for time pressure analysis
    var responseTimeMs: Int

    // MARK: - Computed Properties

    var errorType: ErrorType {
        get { ErrorType(rawValue: errorTypeRaw) ?? .unknown }
        set { errorTypeRaw = newValue.rawValue }
    }

    var subskill: Subskill? {
        Subskill(rawValue: subskillID)
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        questionID: String,
        attemptID: UUID,
        errorType: ErrorType = .unknown,
        selectedAnswer: Int,
        correctAnswer: Int,
        userNotes: String? = nil,
        hasReviewed: Bool = false,
        retriedCorrectly: Bool? = nil,
        timestamp: Date = Date(),
        lastReviewedAt: Date? = nil,
        subskillID: String,
        responseTimeMs: Int
    ) {
        self.id = id
        self.questionID = questionID
        self.attemptID = attemptID
        self.errorTypeRaw = errorType.rawValue
        self.selectedAnswer = selectedAnswer
        self.correctAnswer = correctAnswer
        self.userNotes = userNotes
        self.hasReviewed = hasReviewed
        self.retriedCorrectly = retriedCorrectly
        self.timestamp = timestamp
        self.lastReviewedAt = lastReviewedAt
        self.subskillID = subskillID
        self.responseTimeMs = responseTimeMs
    }

    // MARK: - Factory Methods

    /// Create from an attempt
    static func fromAttempt(
        _ attempt: Attempt,
        correctAnswer: Int,
        inferredType: ErrorType? = nil
    ) -> ErrorLogEntry {
        // Infer error type based on context
        let errorType: ErrorType
        if let inferred = inferredType {
            errorType = inferred
        } else {
            // Auto-infer based on response time
            let avgTime = 90_000 // 90 seconds typical
            if attempt.responseTimeMs > avgTime * 2 {
                errorType = .timePressure
            } else if attempt.responseTimeMs < 15_000 {
                errorType = .careless // Very fast = likely careless
            } else {
                errorType = .unknown
            }
        }

        return ErrorLogEntry(
            questionID: attempt.questionID,
            attemptID: attempt.id,
            errorType: errorType,
            selectedAnswer: attempt.selectedAnswer ?? -1,
            correctAnswer: correctAnswer,
            subskillID: attempt.subskillID,
            responseTimeMs: attempt.responseTimeMs
        )
    }
}

// MARK: - Error Statistics

/// Aggregated error statistics
struct ErrorStats {
    let totalErrors: Int
    let reviewedCount: Int
    let retriedCorrectCount: Int
    let byType: [ErrorType: Int]
    let bySubskill: [String: Int]

    var reviewRate: Double {
        guard totalErrors > 0 else { return 0 }
        return Double(reviewedCount) / Double(totalErrors)
    }

    var retrySuccessRate: Double {
        guard reviewedCount > 0 else { return 0 }
        return Double(retriedCorrectCount) / Double(reviewedCount)
    }

    var mostCommonErrorType: ErrorType? {
        byType.max(by: { $0.value < $1.value })?.key
    }

    var weakestSubskill: String? {
        bySubskill.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Preview Data

extension ErrorLogEntry {
    static var preview: ErrorLogEntry {
        ErrorLogEntry(
            questionID: "q-preview-1",
            attemptID: UUID(),
            errorType: .conceptual,
            selectedAnswer: 1,
            correctAnswer: 2,
            userNotes: "Forgot to account for negative numbers",
            hasReviewed: false,
            subskillID: Subskill.qAlgebra.rawValue,
            responseTimeMs: 95000
        )
    }

    static var previewList: [ErrorLogEntry] {
        [
            ErrorLogEntry(
                questionID: "q-1",
                attemptID: UUID(),
                errorType: .conceptual,
                selectedAnswer: 1,
                correctAnswer: 3,
                hasReviewed: true,
                retriedCorrectly: true,
                subskillID: Subskill.qAlgebra.rawValue,
                responseTimeMs: 120000
            ),
            ErrorLogEntry(
                questionID: "q-2",
                attemptID: UUID(),
                errorType: .careless,
                selectedAnswer: 0,
                correctAnswer: 2,
                hasReviewed: false,
                subskillID: Subskill.qArithmetic.rawValue,
                responseTimeMs: 45000
            ),
            ErrorLogEntry(
                questionID: "q-3",
                attemptID: UUID(),
                errorType: .vocabulary,
                selectedAnswer: 2,
                correctAnswer: 4,
                hasReviewed: false,
                subskillID: Subskill.vTextCompletion.rawValue,
                responseTimeMs: 60000
            )
        ]
    }
}
