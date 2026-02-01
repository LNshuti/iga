// IGA/Data/Models/Session.swift

import Foundation
import SwiftData

// MARK: - Session Mode

/// Practice session modes
enum SessionMode: String, Codable, CaseIterable, Sendable {
    case timed = "timed"
    case untimed = "untimed"
    case review = "review"

    var displayName: String {
        switch self {
        case .timed: return "Timed Practice"
        case .untimed: return "Untimed Practice"
        case .review: return "Review Mode"
        }
    }

    var icon: String {
        switch self {
        case .timed: return "timer"
        case .untimed: return "infinity"
        case .review: return "book"
        }
    }
}

// MARK: - Session Model

/// A practice session containing multiple questions
@Model
final class Session {
    /// Unique identifier
    @Attribute(.unique) var id: String

    /// Session mode (timed, untimed, review)
    var modeRaw: String

    /// When the session started
    var startedAt: Date

    /// When the session was completed (nil if in progress)
    var completedAt: Date?

    /// Question IDs in order
    var questionIds: [String]

    /// User's answers (index corresponds to questionIds)
    var answers: [Int?]

    /// Time spent on each question in seconds
    var timesSpent: [Int]

    /// Section filter (nil = mixed)
    var sectionFilterRaw: String?

    /// Topics filter
    var topicFilters: [String]

    /// Difficulty range
    var minDifficulty: Int
    var maxDifficulty: Int

    var mode: SessionMode {
        get { SessionMode(rawValue: modeRaw) ?? .untimed }
        set { modeRaw = newValue.rawValue }
    }

    var sectionFilter: QuestionSection? {
        get {
            guard let raw = sectionFilterRaw else { return nil }
            return QuestionSection(rawValue: raw)
        }
        set { sectionFilterRaw = newValue?.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        mode: SessionMode = .untimed,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        questionIds: [String] = [],
        answers: [Int?] = [],
        timesSpent: [Int] = [],
        sectionFilter: QuestionSection? = nil,
        topicFilters: [String] = [],
        minDifficulty: Int = 1,
        maxDifficulty: Int = 5
    ) {
        self.id = id
        self.modeRaw = mode.rawValue
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.questionIds = questionIds
        self.answers = answers
        self.timesSpent = timesSpent
        self.sectionFilterRaw = sectionFilter?.rawValue
        self.topicFilters = topicFilters
        self.minDifficulty = minDifficulty
        self.maxDifficulty = maxDifficulty
    }

    /// Number of questions in the session
    var totalQuestions: Int {
        questionIds.count
    }

    /// Number of answered questions
    var answeredCount: Int {
        answers.compactMap { $0 }.count
    }

    /// Whether the session is complete
    var isComplete: Bool {
        completedAt != nil
    }

    /// Progress as a percentage (0-1)
    var progress: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(answeredCount) / Double(totalQuestions)
    }

    /// Record an answer for a question
    func recordAnswer(questionIndex: Int, answerIndex: Int?, timeSpent: Int) {
        guard questionIndex >= 0 && questionIndex < questionIds.count else { return }

        // Expand arrays if needed
        while answers.count <= questionIndex {
            answers.append(nil)
        }
        while timesSpent.count <= questionIndex {
            timesSpent.append(0)
        }

        answers[questionIndex] = answerIndex
        timesSpent[questionIndex] = timeSpent
    }
}

// MARK: - Session Item

/// Represents a single question attempt within a session
struct SessionItem: Identifiable, Codable {
    let id: String
    let questionId: String
    var selectedIndex: Int?
    var isCorrect: Bool?
    var timeSpent: Int // seconds
    var viewedExplanation: Bool

    init(
        id: String = UUID().uuidString,
        questionId: String,
        selectedIndex: Int? = nil,
        isCorrect: Bool? = nil,
        timeSpent: Int = 0,
        viewedExplanation: Bool = false
    ) {
        self.id = id
        self.questionId = questionId
        self.selectedIndex = selectedIndex
        self.isCorrect = isCorrect
        self.timeSpent = timeSpent
        self.viewedExplanation = viewedExplanation
    }
}

// MARK: - Session Preview Data

extension Session {
    /// Sample session for previews
    static func makePreview() -> Session {
        Session(
            id: "preview-session-1",
            mode: .untimed,
            startedAt: Date().addingTimeInterval(-3600),
            questionIds: ["q-1", "q-2", "q-3"],
            answers: [2, 1, nil],
            timesSpent: [45, 60, 0],
            sectionFilter: .quant
        )
    }
}
