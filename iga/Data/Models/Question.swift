// IGA/Data/Models/Question.swift

import Foundation
import SwiftData

// MARK: - Question Section

/// GRE test sections
enum QuestionSection: String, Codable, CaseIterable, Sendable {
    case quant = "quant"
    case verbal = "verbal"
    case awa = "awa"

    var displayName: String {
        switch self {
        case .quant: return "Quantitative"
        case .verbal: return "Verbal"
        case .awa: return "Analytical Writing"
        }
    }

    var icon: String {
        switch self {
        case .quant: return "function"
        case .verbal: return "text.book.closed"
        case .awa: return "pencil.and.outline"
        }
    }
}

// MARK: - Question Model

/// A GRE practice question with multiple choice answers
@Model
final class Question {
    /// Unique identifier
    @Attribute(.unique) var id: String

    /// Section (quant, verbal, awa)
    var sectionRaw: String

    /// Question text (supports markdown for math notation)
    var stem: String

    /// Available answer choices
    var choices: [String]

    /// Index of the correct answer (0-based)
    var correctIndex: Int

    /// Topics/tags for this question
    var topics: [String]

    /// Difficulty rating (1-5)
    var difficulty: Int

    /// Source of the question (seed, ai-generated, user-created)
    var source: String

    /// Optional explanation/rationale
    var rationale: String?

    /// When the question was added
    var createdAt: Date

    /// Computed property for section enum
    var section: QuestionSection {
        get { QuestionSection(rawValue: sectionRaw) ?? .quant }
        set { sectionRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        section: QuestionSection,
        stem: String,
        choices: [String],
        correctIndex: Int,
        topics: [String] = [],
        difficulty: Int = 3,
        source: String = "seed",
        rationale: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sectionRaw = section.rawValue
        self.stem = stem
        self.choices = choices
        self.correctIndex = correctIndex
        self.topics = topics
        self.difficulty = difficulty
        self.source = source
        self.rationale = rationale
        self.createdAt = createdAt
    }

    /// Check if a given answer index is correct
    func isCorrect(_ answerIndex: Int) -> Bool {
        answerIndex == correctIndex
    }

    /// Get the correct answer text
    var correctAnswer: String {
        guard correctIndex >= 0 && correctIndex < choices.count else {
            return ""
        }
        return choices[correctIndex]
    }
}

// MARK: - Question for JSON Import

/// Decodable structure for importing questions from JSON
struct QuestionData: Codable {
    let id: String
    let section: String
    let stem: String
    let choices: [String]
    let correctIndex: Int
    let topics: [String]
    let difficulty: Int
    let source: String
    let rationale: String?

    func toQuestion() -> Question {
        Question(
            id: id,
            section: QuestionSection(rawValue: section) ?? .quant,
            stem: stem,
            choices: choices,
            correctIndex: correctIndex,
            topics: topics,
            difficulty: difficulty,
            source: source,
            rationale: rationale
        )
    }
}

// MARK: - Question Preview Data

extension Question {
    /// Sample question for previews
    static var preview: Question {
        Question(
            id: "preview-1",
            section: .quant,
            stem: "If 3x + 2 = 17, what is the value of x?",
            choices: ["3", "4", "5", "6", "7"],
            correctIndex: 2,
            topics: ["linear-equations", "algebra"],
            difficulty: 2,
            source: "seed",
            rationale: "Subtract 2 from both sides: 3x = 15. Divide by 3: x = 5."
        )
    }

    /// Multiple sample questions for previews
    static var previewList: [Question] {
        [
            preview,
            Question(
                id: "preview-2",
                section: .verbal,
                stem: "The scientist's _____ approach to research ensured that every hypothesis was rigorously tested before publication.",
                choices: ["haphazard", "methodical", "cavalier", "arbitrary", "impetuous"],
                correctIndex: 1,
                topics: ["vocabulary", "sentence-completion"],
                difficulty: 3,
                source: "seed",
                rationale: "The context clues 'rigorously tested' indicate a careful, systematic approach, making 'methodical' the best choice."
            ),
            Question(
                id: "preview-3",
                section: .quant,
                stem: "A circle has a radius of 5. What is its area?",
                choices: ["10π", "15π", "20π", "25π", "50π"],
                correctIndex: 3,
                topics: ["geometry", "circles"],
                difficulty: 1,
                source: "seed",
                rationale: "Area = πr² = π(5)² = 25π"
            )
        ]
    }
}
