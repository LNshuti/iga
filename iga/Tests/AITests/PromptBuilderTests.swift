// IGA/Tests/AITests/PromptBuilderTests.swift

import XCTest
@testable import IGA

final class PromptBuilderTests: XCTestCase {

    // MARK: - Tutor Prompt Builder Tests

    func testTutorSystemPromptContent() {
        // Verify system prompt contains key pedagogical elements
        let systemPrompt = TutorPromptBuilder.systemPrompt

        XCTAssertTrue(systemPrompt.contains("Socratic"))
        XCTAssertTrue(systemPrompt.contains("GRE"))
        XCTAssertTrue(systemPrompt.contains("step-by-step"))
        XCTAssertTrue(systemPrompt.lowercased().contains("never reveal"))
    }

    func testTutorBuildMessages() {
        // Given
        let userMessage = "How do I solve this algebra problem?"

        // When
        let messages = TutorPromptBuilder.buildMessages(
            conversationHistory: [],
            userMessage: userMessage,
            context: nil
        )

        // Then
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, .system)
        XCTAssertEqual(messages[1].role, .user)
        XCTAssertEqual(messages[1].content, userMessage)
    }

    func testTutorBuildMessagesWithHistory() {
        // Given
        let history = [
            ChatMessage(role: .user, content: "What is x?"),
            ChatMessage(role: .assistant, content: "Let's think about this...")
        ]
        let userMessage = "I think x = 5"

        // When
        let messages = TutorPromptBuilder.buildMessages(
            conversationHistory: history,
            userMessage: userMessage,
            context: nil
        )

        // Then
        XCTAssertEqual(messages.count, 4) // system + 2 history + user
        XCTAssertEqual(messages[1].role, .user)
        XCTAssertEqual(messages[2].role, .assistant)
        XCTAssertEqual(messages[3].content, userMessage)
    }

    func testTutorBuildMessagesWithContext() {
        // Given
        let question = Question.preview
        let context = TutorContext(currentQuestion: question, section: .quant)
        let userMessage = "Help me with this"

        // When
        let messages = TutorPromptBuilder.buildMessages(
            conversationHistory: [],
            userMessage: userMessage,
            context: context
        )

        // Then
        XCTAssertEqual(messages.count, 2)
        // System prompt should contain question info
        XCTAssertTrue(messages[0].content.contains("CURRENT QUESTION"))
        XCTAssertTrue(messages[0].content.contains(question.stem))
    }

    func testTutorQuestionDiscussion() {
        // Given
        let question = Question.preview
        let query = "Why is option C correct?"

        // When
        let messages = TutorPromptBuilder.buildQuestionDiscussion(
            question: question,
            userQuery: query,
            previousMessages: []
        )

        // Then
        XCTAssertGreaterThanOrEqual(messages.count, 2)
        XCTAssertEqual(messages.last?.content, query)
    }

    // MARK: - Explanation Prompt Builder Tests

    func testExplanationBuildMessages() {
        // Given
        let question = Question.preview

        // When
        let messages = ExplanationPromptBuilder.buildMessages(
            question: question,
            selectedIndex: 2,
            isCorrect: true,
            userHistory: nil
        )

        // Then
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, .system)
        XCTAssertEqual(messages[1].role, .user)

        // User prompt should contain question details
        let userPrompt = messages[1].content
        XCTAssertTrue(userPrompt.contains(question.stem))
        XCTAssertTrue(userPrompt.contains("CORRECT ANSWER"))
    }

    func testExplanationWithIncorrectAnswer() {
        // Given
        let question = Question.preview // correctIndex = 2

        // When
        let messages = ExplanationPromptBuilder.buildMessages(
            question: question,
            selectedIndex: 0, // Wrong answer
            isCorrect: false,
            userHistory: nil
        )

        // Then
        let userPrompt = messages[1].content
        XCTAssertTrue(userPrompt.contains("INCORRECT"))
        XCTAssertTrue(userPrompt.contains("STUDENT SELECTED"))
    }

    func testExplanationWithUserHistory() {
        // Given
        let question = Question.preview
        let history = UserHistorySummary(
            overallAccuracy: 0.75,
            weakTopics: ["algebra", "geometry"],
            strongTopics: ["vocabulary"]
        )

        // When
        let messages = ExplanationPromptBuilder.buildMessages(
            question: question,
            selectedIndex: 2,
            isCorrect: true,
            userHistory: history
        )

        // Then
        let systemPrompt = messages[0].content
        XCTAssertTrue(systemPrompt.contains("STUDENT CONTEXT"))
        XCTAssertTrue(systemPrompt.contains("75%"))
    }

    func testQuickExplanation() {
        // Given
        let question = Question.preview

        // When
        let messages = ExplanationPromptBuilder.buildQuickExplanation(question: question)

        // Then
        XCTAssertEqual(messages.count, 2)
        // System prompt should request brief explanation
        XCTAssertTrue(messages[0].content.contains("brief") || messages[0].content.contains("2-3 sentences"))
    }

    // MARK: - Question Generation Prompt Builder Tests

    func testQuestionGenBuildMessages() {
        // Given
        let section = QuestionSection.quant
        let topics = ["algebra", "linear-equations"]
        let difficulty = 3

        // When
        let messages = QuestionGenPromptBuilder.buildMessages(
            section: section,
            topics: topics,
            difficulty: difficulty,
            avoidSimilarTo: nil
        )

        // Then
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, .system)

        let userPrompt = messages[1].content
        XCTAssertTrue(userPrompt.contains("quant") || userPrompt.contains("Quantitative"))
        XCTAssertTrue(userPrompt.contains("algebra"))
        XCTAssertTrue(userPrompt.contains("3"))
    }

    func testQuestionGenWithAvoidance() {
        // Given
        let avoidStems = ["What is x + 1?", "If y = 5, what is 2y?"]

        // When
        let messages = QuestionGenPromptBuilder.buildMessages(
            section: .quant,
            topics: ["algebra"],
            difficulty: 2,
            avoidSimilarTo: avoidStems
        )

        // Then
        let userPrompt = messages[1].content
        XCTAssertTrue(userPrompt.contains("AVOID SIMILARITY"))
        XCTAssertTrue(userPrompt.contains("What is x + 1?"))
    }

    // MARK: - Context Tests

    func testTutorContextSerialization() {
        // Given
        let context = TutorContext(
            currentQuestion: nil,
            section: .verbal,
            recentTopics: ["vocabulary", "reading"],
            userStrengths: ["analogies"],
            userWeaknesses: ["sentence-completion"]
        )

        // When
        let addendum = context.toSystemAddendum()

        // Then
        XCTAssertTrue(addendum.contains("Verbal"))
        XCTAssertTrue(addendum.contains("vocabulary"))
        XCTAssertTrue(addendum.contains("analogies"))
        XCTAssertTrue(addendum.contains("sentence-completion"))
    }

    func testUserHistorySummaryFormatting() {
        // Given
        let history = UserHistorySummary(
            overallAccuracy: 0.80,
            sectionAccuracies: [.quant: 0.75, .verbal: 0.85],
            weakTopics: ["geometry"],
            strongTopics: ["vocabulary"],
            recentMistakePatterns: ["Calculation errors"]
        )

        // When
        let context = history.toPromptContext()

        // Then
        XCTAssertTrue(context.contains("80%"))
        XCTAssertTrue(context.contains("geometry"))
        XCTAssertTrue(context.contains("vocabulary"))
        XCTAssertTrue(context.contains("Calculation errors"))
    }
}
