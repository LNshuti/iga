// IGA/Tests/FeatureTests/AdaptiveEngineTests.swift

import XCTest
@testable import IGA

final class AdaptiveEngineTests: XCTestCase {

    // MARK: - Question Selection Tests

    func testSelectNextQuestionFromCandidates() async {
        // Given
        let engine = AdaptiveEngine()
        let candidates = Question.previewList

        // When
        let selected = await engine.selectNextQuestion(from: candidates)

        // Then
        XCTAssertNotNil(selected)
        XCTAssertTrue(candidates.contains { $0.id == selected?.id })
    }

    func testSelectNextQuestionAvoidsRecent() async {
        // Given
        let engine = AdaptiveEngine()
        let candidates = Question.previewList
        let recentIds = Set(candidates.prefix(2).map { $0.id })

        // When
        let selected = await engine.selectNextQuestion(
            from: candidates,
            avoiding: recentIds
        )

        // Then
        XCTAssertNotNil(selected)
        if let selected = selected {
            XCTAssertFalse(recentIds.contains(selected.id))
        }
    }

    func testSelectNextQuestionWithAllAvoided() async {
        // Given
        let engine = AdaptiveEngine()
        let candidates = Question.previewList
        let allIds = Set(candidates.map { $0.id })

        // When - all questions are avoided
        let selected = await engine.selectNextQuestion(
            from: candidates,
            avoiding: allIds
        )

        // Then - should still return something (fallback)
        XCTAssertNotNil(selected)
    }

    func testSelectNextQuestionEmptyCandidates() async {
        // Given
        let engine = AdaptiveEngine()

        // When
        let selected = await engine.selectNextQuestion(from: [])

        // Then
        XCTAssertNil(selected)
    }

    // MARK: - Rating Update Tests

    func testRecordCorrectAnswer() async {
        // Given
        let engine = AdaptiveEngine()
        let question = Question.preview

        // When
        await engine.recordAnswer(question: question, wasCorrect: true)

        // Then
        for topic in question.topics {
            let rating = await engine.rating(for: topic)
            XCTAssertGreaterThan(rating, 1000) // Should increase from default
        }
    }

    func testRecordIncorrectAnswer() async {
        // Given
        let engine = AdaptiveEngine()
        let question = Question.preview

        // When
        await engine.recordAnswer(question: question, wasCorrect: false)

        // Then
        for topic in question.topics {
            let rating = await engine.rating(for: topic)
            XCTAssertLessThan(rating, 1000) // Should decrease from default
        }
    }

    func testMultipleAnswersUpdateRatings() async {
        // Given
        let engine = AdaptiveEngine()
        let question = Question.preview

        // When - answer correctly 3 times
        for _ in 0..<3 {
            await engine.recordAnswer(question: question, wasCorrect: true)
        }

        // Then
        for topic in question.topics {
            let rating = await engine.rating(for: topic)
            XCTAssertGreaterThan(rating, 1050) // Should be significantly higher
        }
    }

    // MARK: - Topic Rating Tests

    func testDefaultRating() async {
        // Given
        let engine = AdaptiveEngine()

        // When
        let rating = await engine.rating(for: "unknown-topic")

        // Then
        XCTAssertEqual(rating, 1000) // Default rating
    }

    func testInitialRatings() async {
        // Given
        let initialRatings = ["algebra": 1200.0, "geometry": 800.0]
        let engine = AdaptiveEngine(initialRatings: initialRatings)

        // When/Then
        let algebraRating = await engine.rating(for: "algebra")
        XCTAssertEqual(algebraRating, 1200)

        let geometryRating = await engine.rating(for: "geometry")
        XCTAssertEqual(geometryRating, 800)
    }

    func testWeakestTopics() async {
        // Given
        let initialRatings = [
            "algebra": 1200.0,
            "geometry": 800.0,
            "vocabulary": 1100.0,
            "reading": 900.0,
            "data-analysis": 1000.0
        ]
        let engine = AdaptiveEngine(initialRatings: initialRatings)

        // When
        let weakest = await engine.weakestTopics(count: 3)

        // Then
        XCTAssertEqual(weakest.count, 3)
        XCTAssertEqual(weakest[0], "geometry") // Lowest rating
        XCTAssertTrue(weakest.contains("reading"))
    }

    func testStrongestTopics() async {
        // Given
        let initialRatings = [
            "algebra": 1200.0,
            "geometry": 800.0,
            "vocabulary": 1100.0
        ]
        let engine = AdaptiveEngine(initialRatings: initialRatings)

        // When
        let strongest = await engine.strongestTopics(count: 2)

        // Then
        XCTAssertEqual(strongest.count, 2)
        XCTAssertEqual(strongest[0], "algebra") // Highest rating
    }

    // MARK: - Statistics Tests

    func testOverallMastery() async {
        // Given
        let initialRatings = [
            "algebra": 1500.0,
            "geometry": 1500.0
        ]
        let engine = AdaptiveEngine(initialRatings: initialRatings)

        // When
        let mastery = await engine.overallMastery()

        // Then
        XCTAssertEqual(mastery, 1.0) // Both at mastery threshold
    }

    func testOverallMasteryEmpty() async {
        // Given
        let engine = AdaptiveEngine()

        // When
        let mastery = await engine.overallMastery()

        // Then
        XCTAssertEqual(mastery, 0)
    }

    func testAttemptedCount() async {
        // Given
        let engine = AdaptiveEngine()
        let questions = Question.previewList

        // When
        for question in questions {
            await engine.recordAnswer(question: question, wasCorrect: Bool.random())
        }

        // Then
        let count = await engine.attemptedCount()
        XCTAssertEqual(count, questions.count)
    }

    func testAccuracyRate() async {
        // Given
        let engine = AdaptiveEngine()
        let question = Question.preview

        // When - 3 correct, 1 incorrect
        await engine.recordAnswer(question: question, wasCorrect: true)
        await engine.recordAnswer(question: question, wasCorrect: true)
        await engine.recordAnswer(question: question, wasCorrect: true)
        await engine.recordAnswer(question: question, wasCorrect: false)

        // Then
        let accuracy = await engine.accuracyRate()
        XCTAssertEqual(accuracy, 0.75, accuracy: 0.01)
    }

    // MARK: - Export/Import Tests

    func testExportRatings() async {
        // Given
        let initialRatings = ["algebra": 1100.0, "geometry": 950.0]
        let engine = AdaptiveEngine(initialRatings: initialRatings)

        // When
        let exported = await engine.exportRatings()

        // Then
        XCTAssertEqual(exported["algebra"], 1100.0)
        XCTAssertEqual(exported["geometry"], 950.0)
    }
}
