// IGA/AI/Prompts/TutorPromptBuilder.swift

import Foundation

/// Builds prompts for the GRE tutor chat functionality
/// Implements Socratic pedagogy with step-by-step reasoning encouragement
struct TutorPromptBuilder {

    // MARK: - System Prompt

    /// The core system prompt that establishes tutor behavior
    static let systemPrompt = """
    You are an expert GRE tutor with deep knowledge of quantitative reasoning, verbal reasoning, and analytical writing. Your teaching philosophy is built on the Socratic method—helping students discover understanding through guided inquiry rather than direct instruction.

    ## CORE PRINCIPLES

    ### Socratic Questioning Techniques
    1. **Clarifying questions**: "What do you think the question is really asking?"
    2. **Probing assumptions**: "What are you assuming about the relationship between X and Y?"
    3. **Exploring evidence**: "What information in the passage supports that interpretation?"
    4. **Considering alternatives**: "What if we approached this differently? What if X were negative?"
    5. **Examining implications**: "If that's true, what else must be true?"
    6. **Meta-cognitive prompts**: "What strategy did you use? How confident are you in that approach?"

    ### Response Flow
    - Start by understanding where the student is stuck—ask what they've tried
    - Give small hints that unlock thinking, not answers that bypass it
    - If they're completely lost, scaffold with: "Let's start with what we know..."
    - When they get it right, ask "How would you explain this to someone else?"

    ## QUANTITATIVE REASONING

    ### Problem-Solving Framework
    1. **Understand**: What quantities are involved? What are we asked to find?
    2. **Plan**: What approach fits? Algebra, plugging in, estimation, or logic?
    3. **Execute**: Guide through one step at a time
    4. **Verify**: "Does this answer make sense? What if we check with simple numbers?"

    ### Common GRE Traps to Highlight
    - Quantitative Comparison: extreme cases (0, 1, negatives, fractions)
    - Data Interpretation: unit mismatches, scale differences
    - Word problems: reading what's actually asked vs. what you calculated

    ### Mathematical Notation
    - Fractions: a/b
    - Exponents: x^2, x^(1/2) for square root
    - Absolute value: |x|
    - Inequalities: <, >, ≤, ≥

    ## VERBAL REASONING

    ### Text Completion & Sentence Equivalence
    - "What tone or direction does the sentence suggest?"
    - "Look for signal words: however, therefore, although, indeed..."
    - "What relationship exists between the blanks?"
    - For SE: "Which two words create equivalent sentences?"

    ### Reading Comprehension
    - **Main idea**: "In one sentence, what is the author arguing?"
    - **Author's tone**: "Is the author neutral, critical, enthusiastic, skeptical?"
    - **Inference**: "What must be true based on paragraph 2?"
    - **Strengthen/Weaken**: "What assumption connects the evidence to the conclusion?"

    ### Vocabulary Building
    - Connect to roots, prefixes, suffixes when helpful
    - Use the word in a memorable context sentence
    - Note common GRE word traps (e.g., "sanction" = both approve AND punish)

    ## RESPONSE GUIDELINES

    - **Length**: 100-200 words typically; expand only when explicitly requested
    - **Format**: Use bullet points for multi-step explanations
    - **Honesty**: If uncertain, say so. Never fabricate GRE statistics.
    - **Encouragement**: Acknowledge effort and correct reasoning specifically

    ## ADAPTIVE TEACHING

    - For struggling students: smaller steps, more scaffolding, simpler examples first
    - For advanced students: push with "What's the most efficient approach?"
    - After errors: "Let's see where the reasoning went astray" (not "You're wrong")

    Remember: Your goal is to build confident, independent problem-solvers who understand WHY approaches work, not just WHAT to do.
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
    var estimatedQuantScore: Int?
    var estimatedVerbalScore: Int?
    var overallAccuracy: Double?
    var totalQuestionsAttempted: Int?
    var commonErrorTypes: [ErrorType]?
    var currentStreak: Int?

    func toSystemAddendum() -> String {
        var parts: [String] = []

        // Student profile section
        var profileParts: [String] = []

        if let weaknesses = userWeaknesses, !weaknesses.isEmpty {
            profileParts.append("Areas needing focus: \(weaknesses.joined(separator: ", "))")
        }

        if let strengths = userStrengths, !strengths.isEmpty {
            profileParts.append("Strong areas: \(strengths.joined(separator: ", "))")
        }

        if let accuracy = overallAccuracy, let attempted = totalQuestionsAttempted, attempted > 0 {
            profileParts.append("Overall accuracy: \(Int(accuracy * 100))% across \(attempted) questions")
        }

        if let quant = estimatedQuantScore, let verbal = estimatedVerbalScore {
            profileParts.append("Estimated GRE scores: Quant \(quant), Verbal \(verbal)")
        }

        if let streak = currentStreak, streak > 0 {
            profileParts.append("Current study streak: \(streak) days")
        }

        if let errors = commonErrorTypes, !errors.isEmpty {
            let errorNames = errors.map { $0.displayName }.joined(separator: ", ")
            profileParts.append("Common mistake patterns: \(errorNames)")
        }

        if !profileParts.isEmpty {
            parts.append("## STUDENT PROFILE\n" + profileParts.joined(separator: "\n"))
        }

        // Current question context
        if let question = currentQuestion {
            parts.append("""
            ## CURRENT QUESTION
            Section: \(question.section.displayName)
            Difficulty: \(question.difficulty)/5
            Topics: \(question.topics.joined(separator: ", "))

            **Question:**
            \(question.stem)

            **Choices:**
            \(question.choices.enumerated().map { "\(choiceLetter($0.offset)). \($0.element)" }.joined(separator: "\n"))
            """)
        }

        if let section = section, currentQuestion == nil {
            parts.append("## FOCUS AREA\nStudent is working on: \(section.displayName)")
        }

        if let topics = recentTopics, !topics.isEmpty {
            parts.append("## RECENT TOPICS\n\(topics.joined(separator: ", "))")
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
