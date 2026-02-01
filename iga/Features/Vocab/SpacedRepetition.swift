// IGA/Features/Vocab/SpacedRepetition.swift

import Foundation

// MARK: - Spaced Repetition Engine

/// Implements the SM-2 algorithm for spaced repetition vocabulary learning
/// Reference: https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
actor SpacedRepetitionEngine {

    // MARK: - Configuration

    /// Minimum ease factor to prevent intervals from becoming too short
    private let minEaseFactor: Double = 1.3

    /// Maximum interval in days
    private let maxIntervalDays: Int = 365

    /// Initial ease factor for new cards
    private let initialEaseFactor: Double = 2.5

    // MARK: - State

    private let dataStore: DataStore?
    private let embeddingService: EmbeddingService?

    init(dataStore: DataStore? = nil, embeddingService: EmbeddingService? = nil) {
        self.dataStore = dataStore
        self.embeddingService = embeddingService
    }

    // MARK: - Review Processing

    /// Process a review for a vocabulary word
    /// - Parameters:
    ///   - word: The word being reviewed
    ///   - quality: Quality of recall (0-3)
    /// - Returns: The updated word with new scheduling
    func processReview(word: VocabWord, quality: ReviewQuality) -> VocabWord {
        // Update repetition count
        var newRepetitions = word.repetitions
        var newEaseFactor = word.easeFactor
        var newInterval = word.interval

        if quality.rawValue >= 2 {
            // Correct response
            switch word.repetitions {
            case 0:
                newInterval = 1 // 1 hour
            case 1:
                newInterval = 6 // 6 hours
            default:
                // Calculate new interval using ease factor
                let hours = Double(word.interval) * word.easeFactor
                newInterval = min(Int(hours), maxIntervalDays * 24)
            }
            newRepetitions += 1
        } else {
            // Incorrect response - reset
            newRepetitions = 0
            newInterval = 1
        }

        // Update ease factor based on quality
        let q = Double(quality.rawValue)
        newEaseFactor = word.easeFactor + (0.1 - (3 - q) * (0.08 + (3 - q) * 0.02))
        newEaseFactor = max(minEaseFactor, newEaseFactor)

        // Calculate next review date
        let nextReview = Date().addingTimeInterval(Double(newInterval) * 3600)

        // Update word
        word.repetitions = newRepetitions
        word.easeFactor = newEaseFactor
        word.interval = newInterval
        word.lastReviewed = Date()
        word.nextReview = nextReview

        return word
    }

    // MARK: - Due Words

    /// Get words due for review, optionally sorted by similarity to a query
    /// - Parameters:
    ///   - words: All available words
    ///   - limit: Maximum number to return
    /// - Returns: Words due for review, sorted by priority
    func getDueWords(from words: [VocabWord], limit: Int = 20) -> [VocabWord] {
        let now = Date()

        // Filter to due words
        let due = words.filter { word in
            guard let nextReview = word.nextReview else { return true }
            return nextReview <= now
        }

        // Sort by priority (overdue first, then by ease factor)
        let sorted = due.sorted { a, b in
            let aOverdue = a.nextReview?.timeIntervalSince(now) ?? Double.infinity
            let bOverdue = b.nextReview?.timeIntervalSince(now) ?? Double.infinity

            if aOverdue != bOverdue {
                return aOverdue < bOverdue // More overdue first
            }

            return a.easeFactor < b.easeFactor // Lower ease factor (harder) first
        }

        return Array(sorted.prefix(limit))
    }

    // MARK: - Statistics

    /// Calculate learning statistics
    func calculateStats(words: [VocabWord]) -> VocabStats {
        let now = Date()

        let due = words.filter { $0.nextReview == nil || $0.nextReview! <= now }
        let learning = words.filter { $0.repetitions > 0 && $0.repetitions < 5 }
        let mastered = words.filter { $0.repetitions >= 5 && $0.easeFactor >= 2.0 }

        let avgEase = words.isEmpty ? 0 : words.reduce(0) { $0 + $1.easeFactor } / Double(words.count)

        return VocabStats(
            totalWords: words.count,
            dueForReview: due.count,
            learning: learning.count,
            mastered: mastered.count,
            averageEaseFactor: avgEase
        )
    }

    // MARK: - Similar Words

    /// Find words similar to a given word using embeddings
    func findSimilarWords(to word: VocabWord, among allWords: [VocabWord], topK: Int = 5) async -> [VocabWord] {
        guard let service = embeddingService else {
            // Fallback: return random words
            return Array(allWords.filter { $0.id != word.id }.shuffled().prefix(topK))
        }

        do {
            return try await service.findSimilarWords(to: word, among: allWords, topK: topK)
        } catch {
            // Fallback on error
            return Array(allWords.filter { $0.id != word.id }.shuffled().prefix(topK))
        }
    }
}

// MARK: - Vocabulary Statistics

struct VocabStats {
    let totalWords: Int
    let dueForReview: Int
    let learning: Int
    let mastered: Int
    let averageEaseFactor: Double

    var masteryPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(mastered) / Double(totalWords)
    }

    var progressPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(mastered + learning) / Double(totalWords)
    }
}

// MARK: - Review Session

/// Manages a vocabulary review session
@MainActor
@Observable
final class VocabReviewSession {
    private(set) var words: [VocabWord] = []
    private(set) var currentIndex: Int = 0
    private(set) var isComplete: Bool = false
    private(set) var showingAnswer: Bool = false

    var currentWord: VocabWord? {
        guard currentIndex < words.count else { return nil }
        return words[currentIndex]
    }

    var progress: Double {
        guard !words.isEmpty else { return 0 }
        return Double(currentIndex) / Double(words.count)
    }

    private let engine: SpacedRepetitionEngine

    init(engine: SpacedRepetitionEngine = SpacedRepetitionEngine()) {
        self.engine = engine
    }

    func loadWords(_ words: [VocabWord]) {
        self.words = words
        currentIndex = 0
        isComplete = false
        showingAnswer = false
    }

    func showAnswer() {
        showingAnswer = true
    }

    func recordQuality(_ quality: ReviewQuality) async {
        guard let word = currentWord else { return }

        _ = await engine.processReview(word: word, quality: quality)

        nextWord()
    }

    private func nextWord() {
        showingAnswer = false

        if currentIndex < words.count - 1 {
            currentIndex += 1
        } else {
            isComplete = true
        }
    }

    func restart() {
        currentIndex = 0
        isComplete = false
        showingAnswer = false
    }
}
