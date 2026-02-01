// IGA/Features/Practice/AdaptiveEngine.swift

import Foundation

// MARK: - Adaptive Engine

/// Selects questions based on user performance using Elo-style ratings
/// Implements a simplified IRT (Item Response Theory) heuristic
actor AdaptiveEngine {

    // MARK: - Configuration

    /// K-factor for rating changes (higher = more volatile)
    private let kFactor: Double = 32.0

    /// Default rating for new topics
    private let defaultRating: Double = 1000.0

    /// Target accuracy (questions should be challenging but achievable)
    private let targetAccuracy: Double = 0.7

    // MARK: - State

    private var topicRatings: [String: Double] = [:]
    private var questionHistory: [String: Bool] = [:] // questionId: wasCorrect

    // MARK: - Initialization

    init(initialRatings: [String: Double] = [:]) {
        self.topicRatings = initialRatings
    }

    // MARK: - Question Selection

    /// Select the next question based on adaptive criteria
    /// - Parameters:
    ///   - candidates: Available questions to choose from
    ///   - recentQuestionIds: Recently asked questions to avoid
    /// - Returns: The selected question, or nil if no suitable question found
    func selectNextQuestion(
        from candidates: [Question],
        avoiding recentQuestionIds: Set<String> = []
    ) -> Question? {
        // Filter out recent questions
        let available = candidates.filter { !recentQuestionIds.contains($0.id) }
        guard !available.isEmpty else {
            return candidates.randomElement() // Fallback to any question
        }

        // Score each question based on:
        // 1. Topic weakness (prefer weaker topics)
        // 2. Difficulty appropriateness
        // 3. Variety (prefer different topics from recent questions)

        let scored = available.map { question -> (Question, Double) in
            let score = calculateQuestionScore(question)
            return (question, score)
        }

        // Sort by score (higher = better choice)
        let sorted = scored.sorted { $0.1 > $1.1 }

        // Add some randomness to avoid predictability
        let topChoices = Array(sorted.prefix(3))
        return topChoices.randomElement()?.0 ?? available.randomElement()
    }

    /// Calculate a selection score for a question
    private func calculateQuestionScore(_ question: Question) -> Double {
        var score: Double = 0

        // Factor 1: Topic weakness (lower rating = higher score)
        let avgTopicRating = question.topics
            .compactMap { topicRatings[$0] ?? defaultRating }
            .reduce(0, +) / max(Double(question.topics.count), 1)

        // Invert so lower ratings get higher scores
        let weaknessScore = (2000 - avgTopicRating) / 1000
        score += weaknessScore * 3.0 // Weight for importance

        // Factor 2: Difficulty appropriateness
        // Map difficulty (1-5) to a 0-1 scale, prefer middle difficulty
        let targetDifficulty = estimateAppropriateDifficulty(forTopicRating: avgTopicRating)
        let difficultyDiff = abs(Double(question.difficulty) - targetDifficulty)
        let difficultyScore = 1.0 - (difficultyDiff / 5.0)
        score += difficultyScore * 2.0

        // Factor 3: Freshness (prefer questions not recently answered)
        if questionHistory[question.id] == nil {
            score += 1.0 // Bonus for unseen questions
        }

        return score
    }

    /// Estimate appropriate difficulty based on topic rating
    private func estimateAppropriateDifficulty(forTopicRating rating: Double) -> Double {
        // Map rating to difficulty:
        // Low rating (< 800) -> difficulty 1-2
        // Medium rating (800-1200) -> difficulty 2-4
        // High rating (> 1200) -> difficulty 4-5
        switch rating {
        case ..<800:
            return 1.5
        case 800..<1000:
            return 2.5
        case 1000..<1200:
            return 3.5
        default:
            return 4.5
        }
    }

    // MARK: - Rating Updates

    /// Update ratings after answering a question
    /// - Parameters:
    ///   - question: The answered question
    ///   - wasCorrect: Whether the answer was correct
    func recordAnswer(question: Question, wasCorrect: Bool) {
        questionHistory[question.id] = wasCorrect

        // Update rating for each topic
        for topic in question.topics {
            updateTopicRating(topic: topic, wasCorrect: wasCorrect, difficulty: question.difficulty)
        }
    }

    /// Update rating for a single topic
    private func updateTopicRating(topic: String, wasCorrect: Bool, difficulty: Int) {
        let currentRating = topicRatings[topic] ?? defaultRating

        // Calculate expected probability based on rating and difficulty
        // Higher difficulty = lower expected success for same rating
        let difficultyFactor = Double(difficulty) / 3.0 // Normalize around 1.0
        let expectedProbability = 1.0 / (1.0 + pow(10, (1000 - currentRating) / 400.0 * difficultyFactor))

        // Actual result
        let actual: Double = wasCorrect ? 1.0 : 0.0

        // Update rating
        let newRating = currentRating + kFactor * (actual - expectedProbability)

        // Clamp to reasonable bounds
        topicRatings[topic] = max(0, min(2000, newRating))
    }

    // MARK: - Accessors

    /// Get current rating for a topic
    func rating(for topic: String) -> Double {
        topicRatings[topic] ?? defaultRating
    }

    /// Get all topic ratings
    func allRatings() -> [String: Double] {
        topicRatings
    }

    /// Get topics sorted by weakness
    func weakestTopics(count: Int = 5) -> [String] {
        topicRatings
            .sorted { $0.value < $1.value }
            .prefix(count)
            .map { $0.key }
    }

    /// Get topics sorted by strength
    func strongestTopics(count: Int = 5) -> [String] {
        topicRatings
            .sorted { $0.value > $1.value }
            .prefix(count)
            .map { $0.key }
    }

    /// Load ratings from user progress
    func loadRatings(from progress: UserProgress) {
        topicRatings = progress.topicRatings
    }

    /// Export ratings to save
    func exportRatings() -> [String: Double] {
        topicRatings
    }

    // MARK: - Statistics

    /// Calculate overall mastery level (0-1)
    func overallMastery() -> Double {
        guard !topicRatings.isEmpty else { return 0 }
        let avg = topicRatings.values.reduce(0, +) / Double(topicRatings.count)
        return min(avg / 1500, 1.0) // 1500 = "mastery" threshold
    }

    /// Get count of attempted questions
    func attemptedCount() -> Int {
        questionHistory.count
    }

    /// Get accuracy rate
    func accuracyRate() -> Double {
        guard !questionHistory.isEmpty else { return 0 }
        let correct = questionHistory.values.filter { $0 }.count
        return Double(correct) / Double(questionHistory.count)
    }
}

// MARK: - Question Difficulty Helpers

extension Question {
    /// Display text for difficulty level
    var difficultyText: String {
        switch difficulty {
        case 1: return "Easy"
        case 2: return "Medium Easy"
        case 3: return "Medium"
        case 4: return "Medium Hard"
        case 5: return "Hard"
        default: return "Unknown"
        }
    }

    /// Color for difficulty level
    var difficultyColor: String {
        switch difficulty {
        case 1: return "green"
        case 2: return "teal"
        case 3: return "blue"
        case 4: return "orange"
        case 5: return "red"
        default: return "gray"
        }
    }
}
