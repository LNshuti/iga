// IGA/Tests/DataTests/SeedDataTests.swift

import XCTest
@testable import IGA

final class SeedDataTests: XCTestCase {

    // MARK: - Question Data Tests

    func testQuestionDataDecoding() throws {
        // Given
        let json = """
        {
            "id": "test-001",
            "section": "quant",
            "stem": "What is 2 + 2?",
            "choices": ["2", "3", "4", "5", "6"],
            "correctIndex": 2,
            "topics": ["arithmetic"],
            "difficulty": 1,
            "source": "test",
            "rationale": "2 + 2 = 4"
        }
        """
        let data = json.data(using: .utf8)!

        // When
        let decoded = try JSONDecoder().decode(QuestionData.self, from: data)

        // Then
        XCTAssertEqual(decoded.id, "test-001")
        XCTAssertEqual(decoded.section, "quant")
        XCTAssertEqual(decoded.stem, "What is 2 + 2?")
        XCTAssertEqual(decoded.choices.count, 5)
        XCTAssertEqual(decoded.correctIndex, 2)
        XCTAssertEqual(decoded.difficulty, 1)
    }

    func testQuestionDataToQuestion() throws {
        // Given
        let questionData = QuestionData(
            id: "test-002",
            section: "verbal",
            stem: "Choose the synonym of 'ephemeral'",
            choices: ["permanent", "fleeting", "static", "eternal", "lasting"],
            correctIndex: 1,
            topics: ["vocabulary", "synonyms"],
            difficulty: 2,
            source: "test",
            rationale: "Ephemeral means lasting for a short time"
        )

        // When
        let question = questionData.toQuestion()

        // Then
        XCTAssertEqual(question.id, "test-002")
        XCTAssertEqual(question.section, .verbal)
        XCTAssertEqual(question.correctIndex, 1)
        XCTAssertTrue(question.isCorrect(1))
        XCTAssertFalse(question.isCorrect(0))
    }

    func testQuestionSections() {
        // Test section enum
        XCTAssertEqual(QuestionSection.quant.displayName, "Quantitative")
        XCTAssertEqual(QuestionSection.verbal.displayName, "Verbal")
        XCTAssertEqual(QuestionSection.awa.displayName, "Analytical Writing")

        // Test raw values
        XCTAssertEqual(QuestionSection(rawValue: "quant"), .quant)
        XCTAssertEqual(QuestionSection(rawValue: "verbal"), .verbal)
        XCTAssertNil(QuestionSection(rawValue: "invalid"))
    }

    // MARK: - Vocab Data Tests

    func testVocabWordDataDecoding() throws {
        // Given
        let json = """
        {
            "id": "vocab-001",
            "headword": "ephemeral",
            "pos": "adjective",
            "definition": "lasting for a very short time",
            "example": "The ephemeral beauty of cherry blossoms.",
            "synonyms": ["fleeting", "transient", "brief"]
        }
        """
        let data = json.data(using: .utf8)!

        // When
        let decoded = try JSONDecoder().decode(VocabWordData.self, from: data)

        // Then
        XCTAssertEqual(decoded.headword, "ephemeral")
        XCTAssertEqual(decoded.partOfSpeech, "adjective")
        XCTAssertEqual(decoded.synonyms.count, 3)
    }

    func testVocabWordDataToVocabWord() throws {
        // Given
        let vocabData = VocabWordData(
            id: "vocab-002",
            headword: "ubiquitous",
            partOfSpeech: "adjective",
            definition: "present everywhere",
            example: "Smartphones are ubiquitous.",
            synonyms: ["omnipresent", "pervasive"]
        )

        // When
        let word = vocabData.toVocabWord()

        // Then
        XCTAssertEqual(word.headword, "ubiquitous")
        XCTAssertEqual(word.posAbbreviation, "adj.")
        XCTAssertEqual(word.synonyms.count, 2)
        XCTAssertTrue(word.isDueForReview) // New word should be due
    }

    func testVocabWordPOSAbbreviation() {
        // Test part of speech abbreviations
        let noun = VocabWord(
            headword: "test",
            partOfSpeech: "noun",
            definition: "test",
            example: "test"
        )
        XCTAssertEqual(noun.posAbbreviation, "n.")

        let verb = VocabWord(
            headword: "test",
            partOfSpeech: "verb",
            definition: "test",
            example: "test"
        )
        XCTAssertEqual(verb.posAbbreviation, "v.")

        let adj = VocabWord(
            headword: "test",
            partOfSpeech: "adjective",
            definition: "test",
            example: "test"
        )
        XCTAssertEqual(adj.posAbbreviation, "adj.")

        let adv = VocabWord(
            headword: "test",
            partOfSpeech: "adverb",
            definition: "test",
            example: "test"
        )
        XCTAssertEqual(adv.posAbbreviation, "adv.")
    }

    // MARK: - Preview Data Tests

    func testQuestionPreviewData() {
        // Test that preview data is valid
        let preview = Question.preview
        XCTAssertFalse(preview.id.isEmpty)
        XCTAssertFalse(preview.stem.isEmpty)
        XCTAssertEqual(preview.choices.count, 5)
        XCTAssertTrue(preview.correctIndex >= 0 && preview.correctIndex < preview.choices.count)
    }

    func testQuestionPreviewList() {
        // Test preview list
        let list = Question.previewList
        XCTAssertGreaterThanOrEqual(list.count, 2)

        // Check all have unique IDs
        let ids = Set(list.map { $0.id })
        XCTAssertEqual(ids.count, list.count)
    }

    func testVocabPreviewData() {
        // Test that preview data is valid
        let preview = VocabWord.preview
        XCTAssertFalse(preview.headword.isEmpty)
        XCTAssertFalse(preview.definition.isEmpty)
        XCTAssertFalse(preview.synonyms.isEmpty)
    }

    // MARK: - Session Data Tests

    func testSessionModes() {
        XCTAssertEqual(SessionMode.timed.displayName, "Timed Practice")
        XCTAssertEqual(SessionMode.untimed.displayName, "Untimed Practice")
        XCTAssertEqual(SessionMode.review.displayName, "Review Mode")

        XCTAssertEqual(SessionMode(rawValue: "timed"), .timed)
        XCTAssertEqual(SessionMode(rawValue: "untimed"), .untimed)
    }

    func testSessionProgress() {
        // Given
        let session = Session.makePreview()

        // When
        session.recordAnswer(questionIndex: 0, answerIndex: 2, timeSpent: 30)

        // Then
        XCTAssertEqual(session.answeredCount, 1)
        XCTAssertGreaterThan(session.progress, 0)
    }

    // MARK: - Review Quality Tests

    func testReviewQualityValues() {
        XCTAssertEqual(ReviewQuality.forgot.rawValue, 0)
        XCTAssertEqual(ReviewQuality.hard.rawValue, 1)
        XCTAssertEqual(ReviewQuality.good.rawValue, 2)
        XCTAssertEqual(ReviewQuality.easy.rawValue, 3)

        XCTAssertEqual(ReviewQuality.allCases.count, 4)
    }
}
