// IGA/Data/Models/VocabWord.swift

import Foundation
import SwiftData

// MARK: - Vocabulary Word Model

/// A GRE vocabulary word with definition, examples, and learning metadata
@Model
final class VocabWord {
    /// Unique identifier
    @Attribute(.unique) var id: String

    /// The vocabulary word
    var headword: String

    /// Part of speech (noun, verb, adjective, etc.)
    var partOfSpeech: String

    /// Primary definition
    var definition: String

    /// Example sentence using the word
    var example: String

    /// Synonyms for the word
    var synonyms: [String]

    /// Optional embedding vector for semantic similarity
    var embedding: [Double]?

    /// When the word was added
    var createdAt: Date

    /// Spaced repetition data
    var lastReviewed: Date?
    var nextReview: Date?
    var easeFactor: Double
    var interval: Int // in hours
    var repetitions: Int

    init(
        id: String = UUID().uuidString,
        headword: String,
        partOfSpeech: String,
        definition: String,
        example: String,
        synonyms: [String] = [],
        embedding: [Double]? = nil,
        createdAt: Date = Date(),
        lastReviewed: Date? = nil,
        nextReview: Date? = nil,
        easeFactor: Double = 2.5,
        interval: Int = 0,
        repetitions: Int = 0
    ) {
        self.id = id
        self.headword = headword
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.example = example
        self.synonyms = synonyms
        self.embedding = embedding
        self.createdAt = createdAt
        self.lastReviewed = lastReviewed
        self.nextReview = nextReview
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
    }

    /// Formatted part of speech display
    var posAbbreviation: String {
        switch partOfSpeech.lowercased() {
        case "noun": return "n."
        case "verb": return "v."
        case "adjective": return "adj."
        case "adverb": return "adv."
        default: return partOfSpeech
        }
    }

    /// Check if the word is due for review
    var isDueForReview: Bool {
        guard let nextReview else { return true }
        return nextReview <= Date()
    }
}

// MARK: - Vocabulary Word for JSON Import

/// Decodable structure for importing vocabulary from JSON
struct VocabWordData: Codable {
    let id: String
    let headword: String
    let partOfSpeech: String
    let definition: String
    let example: String
    let synonyms: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case headword
        case partOfSpeech = "pos"
        case definition
        case example
        case synonyms
    }

    func toVocabWord() -> VocabWord {
        VocabWord(
            id: id,
            headword: headword,
            partOfSpeech: partOfSpeech,
            definition: definition,
            example: example,
            synonyms: synonyms
        )
    }
}

// MARK: - Review Quality

/// Quality rating for spaced repetition
enum ReviewQuality: Int, CaseIterable {
    case forgot = 0      // Complete blackout
    case hard = 1        // Struggled significantly
    case good = 2        // Correct with effort
    case easy = 3        // Effortless recall

    var displayName: String {
        switch self {
        case .forgot: return "Forgot"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }

    var color: String {
        switch self {
        case .forgot: return "red"
        case .hard: return "orange"
        case .good: return "green"
        case .easy: return "blue"
        }
    }
}

// MARK: - VocabWord Preview Data

extension VocabWord {
    /// Sample word for previews
    static var preview: VocabWord {
        VocabWord(
            id: "preview-1",
            headword: "ephemeral",
            partOfSpeech: "adjective",
            definition: "lasting for a very short time",
            example: "The ephemeral beauty of cherry blossoms draws millions of visitors each spring.",
            synonyms: ["fleeting", "transient", "momentary", "brief", "short-lived"]
        )
    }

    /// Multiple sample words for previews
    static var previewList: [VocabWord] {
        [
            preview,
            VocabWord(
                id: "preview-2",
                headword: "ubiquitous",
                partOfSpeech: "adjective",
                definition: "present, appearing, or found everywhere",
                example: "Smartphones have become ubiquitous in modern society.",
                synonyms: ["omnipresent", "pervasive", "universal", "widespread"]
            ),
            VocabWord(
                id: "preview-3",
                headword: "ameliorate",
                partOfSpeech: "verb",
                definition: "to make something bad or unsatisfactory better",
                example: "The new policies were designed to ameliorate the effects of poverty.",
                synonyms: ["improve", "enhance", "better", "alleviate", "mitigate"]
            ),
            VocabWord(
                id: "preview-4",
                headword: "perfunctory",
                partOfSpeech: "adjective",
                definition: "carried out with minimum effort or reflection",
                example: "He gave the report a perfunctory glance before signing off on it.",
                synonyms: ["cursory", "superficial", "mechanical", "routine", "hasty"]
            )
        ]
    }
}
