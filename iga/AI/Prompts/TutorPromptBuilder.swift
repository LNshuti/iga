// IGA/AI/Prompts/TutorPromptBuilder.swift

import Foundation

/// Builds prompts for the GRE tutor chat functionality
/// Implements Socratic pedagogy with step-by-step reasoning encouragement
struct TutorPromptBuilder {

    // MARK: - System Prompt

    /// The core system prompt that establishes tutor behavior
    static let systemPrompt = """
    You are an expert GRE tutor with deep knowledge of quantitative reasoning, verbal reasoning, and analytical writing. Your teaching philosophy:

    APPROACH:
    - Use the Socratic method: guide students to discover answers through thoughtful questions
    - Never reveal solutions immediately; help students build reasoning skills
    - Adapt your explanations to the student's demonstrated level
    - Celebrate correct reasoning while gently correcting misconceptions

    QUANTITATIVE:
    - Break complex problems into manageable steps
    - Emphasize pattern recognition and problem-solving strategies
    - Use clear mathematical notation: fractions as a/b, exponents as x^2, sqrt for square roots
    - Highlight common GRE quantitative traps and shortcuts

    VERBAL:
    - Focus on context clues and word relationships
    - Teach vocabulary through etymology and word families
    - Explain reading comprehension strategies: main idea, author's tone, inference
    - Help with sentence equivalence and text completion techniques

    GENERAL GUIDELINES:
    - Keep responses concise but thorough (aim for 100-200 words unless more detail is requested)
    - Use bullet points for multi-step explanations
    - Acknowledge when a question is ambiguous or has multiple valid interpretations
    - If you're uncertain about something, say so honestly
    - Never make up GRE facts or statistics

    Remember: Your goal is to build independent problem-solvers, not to simply provide answers.
    """

    // MARK: - Context Building

    /// Build a full message list for a tutor conversation
    /// - Parameters:
    ///   - conversationHistory: Previous messages in the conversation
    ///   - userMessage: The current user message
    ///   - context: Optional additional context (e.g., current question being discussed)
    /// - Returns: Array of ChatMessage for the API request
    static func buildMessages(
        conversationHistory: [ChatMessage] = [],
        userMessage: String,
        context: TutorContext? = nil
    ) -> [ChatMessage] {
        var messages: [ChatMessage] = []

        // Add system prompt with optional context
        var systemContent = systemPrompt
        if let ctx = context {
            systemContent += "\n\n" + ctx.toSystemAddendum()
        }
        messages.append(ChatMessage(role: .system, content: systemContent))

        // Add conversation history
        messages.append(contentsOf: conversationHistory)

        // Add current user message
        messages.append(ChatMessage(role: .user, content: userMessage))

        return messages
    }

    /// Build a message list for a specific GRE question discussion
    /// - Parameters:
    ///   - question: The GRE question being discussed
    ///   - userQuery: What the user is asking about the question
    ///   - previousMessages: Previous discussion about this question
    /// - Returns: Array of ChatMessage for the API request
    static func buildQuestionDiscussion(
        question: Question,
        userQuery: String,
        previousMessages: [ChatMessage] = []
    ) -> [ChatMessage] {
        let context = TutorContext(
            currentQuestion: question,
            section: question.section
        )
        return buildMessages(
            conversationHistory: previousMessages,
            userMessage: userQuery,
            context: context
        )
    }
}

// MARK: - Tutor Context

/// Additional context to augment the tutor's system prompt
struct TutorContext {
    var currentQuestion: Question?
    var section: QuestionSection?
    var recentTopics: [String]?
    var userStrengths: [String]?
    var userWeaknesses: [String]?

    func toSystemAddendum() -> String {
        var parts: [String] = []

        if let question = currentQuestion {
            parts.append("""
            CURRENT QUESTION CONTEXT:
            Section: \(question.section.displayName)
            Stem: \(question.stem)
            Choices: \(question.choices.enumerated().map { "\(choiceLetter($0.offset)). \($0.element)" }.joined(separator: "; "))
            Topics: \(question.topics.joined(separator: ", "))
            Difficulty: \(question.difficulty)/5
            """)
        }

        if let section = section, currentQuestion == nil {
            parts.append("FOCUS AREA: \(section.displayName) questions")
        }

        if let topics = recentTopics, !topics.isEmpty {
            parts.append("RECENTLY STUDIED: \(topics.joined(separator: ", "))")
        }

        if let strengths = userStrengths, !strengths.isEmpty {
            parts.append("STUDENT STRENGTHS: \(strengths.joined(separator: ", "))")
        }

        if let weaknesses = userWeaknesses, !weaknesses.isEmpty {
            parts.append("AREAS FOR IMPROVEMENT: \(weaknesses.joined(separator: ", "))")
        }

        return parts.joined(separator: "\n\n")
    }

    private func choiceLetter(_ index: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return index < letters.count ? letters[index] : "\(index + 1)"
    }
}

// MARK: - Conversation Starters

extension TutorPromptBuilder {
    /// Suggested conversation starters for different scenarios
    static let greetingPrompts = [
        "Hi! I'm your GRE tutor. What would you like to work on today?",
        "Welcome back! Ready to tackle some GRE prep?",
        "Hello! I'm here to help you ace the GRE. What's on your mind?"
    ]

    static let quantStarters = [
        "Let's start with a quantitative problem. Would you like to focus on algebra, geometry, or data interpretation?",
        "Ready for some math? I can help with problem-solving strategies or specific question types.",
    ]

    static let verbalStarters = [
        "Let's work on verbal reasoning. Would you like to focus on vocabulary, reading comprehension, or text completion?",
        "Ready to strengthen your verbal skills? We can work on word relationships, passage analysis, or sentence equivalence.",
    ]
}
