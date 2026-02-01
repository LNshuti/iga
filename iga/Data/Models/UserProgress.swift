// IGA/Data/Models/UserProgress.swift

import Foundation
import SwiftData

// MARK: - User Progress Model

/// Tracks overall user progress and statistics
@Model
final class UserProgress {
    /// Unique identifier (single instance per user)
    @Attribute(.unique) var id: String

    /// Total questions attempted
    var totalAttempted: Int

    /// Total correct answers
    var totalCorrect: Int

    /// Current streak (consecutive days with practice)
    var currentStreak: Int

    /// Longest streak ever achieved
    var longestStreak: Int

    /// Last practice date (for streak calculation)
    var lastPracticeDate: Date?

    /// Total time spent practicing (seconds)
    var totalTimeSpent: Int

    /// Sessions completed
    var sessionsCompleted: Int

    /// Topic-specific ratings (Elo-style)
    var topicRatings: [String: Double]

    /// Section-specific stats
    var quantAttempted: Int
    var quantCorrect: Int
    var verbalAttempted: Int
    var verbalCorrect: Int

    /// Vocabulary words mastered
    var vocabMastered: Int

    /// When the user started
    var createdAt: Date

    init(
        id: String = "default-user",
        totalAttempted: Int = 0,
        totalCorrect: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastPracticeDate: Date? = nil,
        totalTimeSpent: Int = 0,
        sessionsCompleted: Int = 0,
        topicRatings: [String: Double] = [:],
        quantAttempted: Int = 0,
        quantCorrect: Int = 0,
        verbalAttempted: Int = 0,
        verbalCorrect: Int = 0,
        vocabMastered: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.totalAttempted = totalAttempted
        self.totalCorrect = totalCorrect
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastPracticeDate = lastPracticeDate
        self.totalTimeSpent = totalTimeSpent
        self.sessionsCompleted = sessionsCompleted
        self.topicRatings = topicRatings
        self.quantAttempted = quantAttempted
        self.quantCorrect = quantCorrect
        self.verbalAttempted = verbalAttempted
        self.verbalCorrect = verbalCorrect
        self.vocabMastered = vocabMastered
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    /// Overall accuracy percentage
    var overallAccuracy: Double {
        guard totalAttempted > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAttempted)
    }

    /// Quantitative accuracy percentage
    var quantAccuracy: Double {
        guard quantAttempted > 0 else { return 0 }
        return Double(quantCorrect) / Double(quantAttempted)
    }

    /// Verbal accuracy percentage
    var verbalAccuracy: Double {
        guard verbalAttempted > 0 else { return 0 }
        return Double(verbalCorrect) / Double(verbalAttempted)
    }

    /// Average time per question (seconds)
    var averageTimePerQuestion: Int {
        guard totalAttempted > 0 else { return 0 }
        return totalTimeSpent / totalAttempted
    }

    /// Topics sorted by rating (weakest first)
    var weakestTopics: [String] {
        topicRatings.sorted { $0.value < $1.value }.prefix(5).map { $0.key }
    }

    /// Topics sorted by rating (strongest first)
    var strongestTopics: [String] {
        topicRatings.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
    }

    // MARK: - Updates

    /// Record a question attempt
    func recordAttempt(
        section: QuestionSection,
        topics: [String],
        isCorrect: Bool,
        timeSpent: Int
    ) {
        totalAttempted += 1
        totalTimeSpent += timeSpent

        if isCorrect {
            totalCorrect += 1
        }

        switch section {
        case .quant:
            quantAttempted += 1
            if isCorrect { quantCorrect += 1 }
        case .verbal:
            verbalAttempted += 1
            if isCorrect { verbalCorrect += 1 }
        case .awa:
            break
        }

        // Update topic ratings
        for topic in topics {
            updateTopicRating(topic: topic, isCorrect: isCorrect)
        }

        // Update streak
        updateStreak()
    }

    /// Update Elo-style rating for a topic
    private func updateTopicRating(topic: String, isCorrect: Bool) {
        let currentRating = topicRatings[topic] ?? 1000.0
        let k: Double = 32.0 // K-factor for rating changes
        let expected: Double = 0.5 // Assuming medium difficulty

        let actual: Double = isCorrect ? 1.0 : 0.0
        let newRating = currentRating + k * (actual - expected)

        topicRatings[topic] = max(0, newRating) // Don't go negative
    }

    /// Update practice streak
    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = lastPracticeDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysBetween == 0 {
                // Same day, no change
            } else if daysBetween == 1 {
                // Consecutive day
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                // Streak broken
                currentStreak = 1
            }
        } else {
            // First practice
            currentStreak = 1
        }

        lastPracticeDate = Date()
    }
}

// MARK: - Topic Rating

/// Represents a topic with its rating for display
struct TopicRating: Identifiable {
    let id: String
    let topic: String
    let rating: Double

    init(topic: String, rating: Double) {
        self.id = topic
        self.topic = topic
        self.rating = rating
    }

    var level: String {
        switch rating {
        case ..<800: return "Beginner"
        case 800..<1000: return "Developing"
        case 1000..<1200: return "Proficient"
        case 1200..<1400: return "Advanced"
        default: return "Expert"
        }
    }
}

// MARK: - UserProgress Preview Data

extension UserProgress {
    /// Sample progress for previews
    static var preview: UserProgress {
        let progress = UserProgress(
            id: "preview-user",
            totalAttempted: 150,
            totalCorrect: 112,
            currentStreak: 7,
            longestStreak: 14,
            lastPracticeDate: Date(),
            totalTimeSpent: 9000,
            sessionsCompleted: 15,
            topicRatings: [
                "algebra": 1150,
                "geometry": 980,
                "vocabulary": 1250,
                "reading-comprehension": 1100,
                "data-interpretation": 850
            ],
            quantAttempted: 80,
            quantCorrect: 56,
            verbalAttempted: 70,
            verbalCorrect: 56,
            vocabMastered: 45
        )
        return progress
    }
}
