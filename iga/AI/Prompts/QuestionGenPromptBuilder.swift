// IGA/AI/Prompts/QuestionGenPromptBuilder.swift

import Foundation

/// Builds prompts for AI-generated GRE questions
/// Used for admin/development purposes to expand question bank
struct QuestionGenPromptBuilder {

    // MARK: - System Prompt

    static let systemPrompt = """
    You are an expert GRE question writer. Generate high-quality practice questions that match the style and difficulty of the actual GRE exam.

    QUESTION QUALITY STANDARDS:
    - Questions must be unambiguous with exactly one correct answer
    - Distractors (wrong answers) should be plausible and target common misconceptions
    - Difficulty should match the specified level (1-5 scale)
    - Questions should test genuine understanding, not trick memory

    QUANTITATIVE QUESTIONS:
    - Cover arithmetic, algebra, geometry, and data analysis
    - Include word problems that require interpretation
    - Ensure numerical answers are distinct and unambiguous
    - Use realistic quantities and scenarios

    VERBAL QUESTIONS:
    - Vocabulary questions should use graduate-level words
    - Reading passages should be appropriately complex
    - Sentence completion should have clear contextual clues
    - Text completion blanks should have logically determinable answers

    OUTPUT FORMAT:
    You must respond with valid JSON matching this schema exactly.
    """

    // MARK: - Question Generation

    /// Build messages for generating a new question
    /// - Parameters:
    ///   - section: Target section (quant/verbal)
    ///   - topics: Specific topics to cover
    ///   - difficulty: Target difficulty (1-5)
    ///   - avoidSimilarTo: Optional stems to avoid similarity with
    /// - Returns: Array of ChatMessage for the API request
    static func buildMessages(
        section: QuestionSection,
        topics: [String],
        difficulty: Int,
        avoidSimilarTo: [String]? = nil
    ) -> [ChatMessage] {
        let userPrompt = buildUserPrompt(
            section: section,
            topics: topics,
            difficulty: difficulty,
            avoidSimilarTo: avoidSimilarTo
        )

        return [
            ChatMessage(role: .system, content: systemPrompt),
            ChatMessage(role: .user, content: userPrompt)
        ]
    }

    private static func buildUserPrompt(
        section: QuestionSection,
        topics: [String],
        difficulty: Int,
        avoidSimilarTo: [String]?
    ) -> String {
        var prompt = """
        Generate a \(section.displayName) question with these specifications:

        SECTION: \(section.rawValue)
        TOPICS: \(topics.joined(separator: ", "))
        DIFFICULTY: \(difficulty)/5
        NUMBER OF CHOICES: 5

        """

        if let avoid = avoidSimilarTo, !avoid.isEmpty {
            prompt += """

            AVOID SIMILARITY TO THESE QUESTIONS:
            \(avoid.enumerated().map { "- \($0.element)" }.joined(separator: "\n"))

            """
        }

        prompt += """

        Respond with JSON in this exact format:
        {
          "id": "gen-YYYYMMDD-XXXX",
          "section": "\(section.rawValue)",
          "stem": "The question text here",
          "choices": ["Choice A", "Choice B", "Choice C", "Choice D", "Choice E"],
          "correctIndex": 0,
          "topics": \(topics),
          "difficulty": \(difficulty),
          "source": "ai-generated",
          "rationale": "Explanation of the correct answer and why other choices are wrong"
        }

        Important:
        - correctIndex is 0-based (0 = first choice)
        - rationale should explain the solution clearly
        - stem should be complete and unambiguous
        """

        return prompt
    }

    // MARK: - Batch Generation

    /// Build messages for generating multiple questions at once
    static func buildBatchMessages(
        section: QuestionSection,
        topics: [String],
        difficulties: [Int],
        count: Int
    ) -> [ChatMessage] {
        let userPrompt = """
        Generate \(count) unique \(section.displayName) questions covering these topics: \(topics.joined(separator: ", "))

        Difficulty distribution: \(difficulties.map(String.init).joined(separator: ", "))

        Respond with a JSON array of question objects. Each object should have:
        - id: unique identifier (format: "gen-YYYYMMDD-XXXX")
        - section: "\(section.rawValue)"
        - stem: the question text
        - choices: array of 5 choices
        - correctIndex: 0-based index of correct answer
        - topics: array of relevant topics
        - difficulty: 1-5 rating
        - source: "ai-generated"
        - rationale: explanation of correct answer

        Ensure all questions are unique and cover different aspects of the topics.
        """

        return [
            ChatMessage(role: .system, content: systemPrompt),
            ChatMessage(role: .user, content: userPrompt)
        ]
    }

    // MARK: - Question Improvement

    /// Build messages for improving an existing question
    static func buildImprovementMessages(
        question: Question,
        feedback: String
    ) -> [ChatMessage] {
        let userPrompt = """
        Improve this GRE question based on the feedback provided.

        CURRENT QUESTION:
        Section: \(question.section.rawValue)
        Stem: \(question.stem)
        Choices: \(question.choices.enumerated().map { "\($0.offset): \($0.element)" }.joined(separator: ", "))
        Correct Answer Index: \(question.correctIndex)
        Difficulty: \(question.difficulty)

        FEEDBACK:
        \(feedback)

        Respond with the improved question in JSON format (same schema as original).
        Explain what you changed and why in the rationale field.
        """

        return [
            ChatMessage(role: .system, content: systemPrompt),
            ChatMessage(role: .user, content: userPrompt)
        ]
    }
}

// MARK: - Response Parsing

extension QuestionGenPromptBuilder {
    /// Parse a generated question from JSON response
    /// - Parameter json: JSON string from the model
    /// - Returns: Parsed Question or nil if parsing fails
    static func parseGeneratedQuestion(from json: String) -> Question? {
        guard let data = json.data(using: .utf8) else { return nil }

        do {
            let decoded = try JSONDecoder().decode(GeneratedQuestion.self, from: data)
            return Question(
                id: decoded.id,
                section: QuestionSection(rawValue: decoded.section) ?? .quant,
                stem: decoded.stem,
                choices: decoded.choices,
                correctIndex: decoded.correctIndex,
                topics: decoded.topics,
                difficulty: decoded.difficulty,
                source: decoded.source,
                rationale: decoded.rationale
            )
        } catch {
            print("Failed to parse generated question: \(error)")
            return nil
        }
    }
}

/// Intermediate type for parsing generated questions
private struct GeneratedQuestion: Decodable {
    let id: String
    let section: String
    let stem: String
    let choices: [String]
    let correctIndex: Int
    let topics: [String]
    let difficulty: Int
    let source: String
    let rationale: String
}
