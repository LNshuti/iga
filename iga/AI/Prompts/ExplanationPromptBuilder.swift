// IGA/AI/Prompts/ExplanationPromptBuilder.swift

import Foundation

/// Builds prompts for generating explanations for GRE questions
/// Tailored to the user's selected answer and learning history
struct ExplanationPromptBuilder {

    // MARK: - System Prompt

    static let systemPrompt = """
    You are an expert GRE instructor providing clear, concise explanations for practice questions.

    EXPLANATION GUIDELINES:
    - Start with whether the answer is correct or incorrect
    - Explain the correct reasoning step by step
    - If the student chose incorrectly, explain why their choice is wrong and contrast it with the correct answer
    - Highlight the key concept or skill being tested
    - Provide a brief strategy tip for similar questions
    - Keep explanations under 150 words unless the question requires more detail

    FORMAT:
    - Use clear paragraph structure
    - For math: show the solution process with clear notation (a/b for fractions, x^2 for exponents)
    - For verbal: explain word meanings and contextual clues
    - End with a "Tip:" for tackling similar questions

    TONE:
    - Encouraging but honest
    - Focus on learning, not judgment
    - Use "we" language to create partnership feeling
    """

    // MARK: - Explanation Request

    /// Build messages for generating an explanation
    /// - Parameters:
    ///   - question: The question to explain
    ///   - selectedIndex: Index of the user's selected answer (nil if not answered)
    ///   - isCorrect: Whether the user's answer was correct
    ///   - userHistory: Optional summary of user's performance history
    /// - Returns: Array of ChatMessage for the API request
    static func buildMessages(
        question: Question,
        selectedIndex: Int?,
        isCorrect: Bool?,
        userHistory: UserHistorySummary? = nil
    ) -> [ChatMessage] {
        var systemContent = systemPrompt

        // Add user history context if available
        if let history = userHistory {
            systemContent += "\n\nSTUDENT CONTEXT:\n\(history.toPromptContext())"
        }

        let messages: [ChatMessage] = [
            ChatMessage(role: .system, content: systemContent),
            ChatMessage(role: .user, content: buildUserPrompt(
                question: question,
                selectedIndex: selectedIndex,
                isCorrect: isCorrect
            ))
        ]

        return messages
    }

    /// Build the user prompt with question details
    private static func buildUserPrompt(
        question: Question,
        selectedIndex: Int?,
        isCorrect: Bool?
    ) -> String {
        var prompt = """
        Please explain this \(question.section.displayName) question:

        QUESTION:
        \(question.stem)

        CHOICES:
        \(formatChoices(question.choices, correctIndex: question.correctIndex, selectedIndex: selectedIndex))

        CORRECT ANSWER: \(choiceLetter(question.correctIndex)) - \(question.choices[question.correctIndex])
        """

        if let selected = selectedIndex {
            prompt += "\nSTUDENT SELECTED: \(choiceLetter(selected)) - \(question.choices[selected])"
            if let correct = isCorrect {
                prompt += " (\(correct ? "CORRECT" : "INCORRECT"))"
            }
        }

        if let rationale = question.rationale {
            prompt += "\n\nREFERENCE RATIONALE (for accuracy check):\n\(rationale)"
        }

        return prompt
    }

    /// Format choices with indicators for correct/selected
    private static func formatChoices(
        _ choices: [String],
        correctIndex: Int,
        selectedIndex: Int?
    ) -> String {
        choices.enumerated().map { index, choice in
            var line = "\(choiceLetter(index)). \(choice)"
            if index == correctIndex {
                line += " [CORRECT]"
            }
            if index == selectedIndex && index != correctIndex {
                line += " [SELECTED]"
            }
            return line
        }.joined(separator: "\n")
    }

    private static func choiceLetter(_ index: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return index < letters.count ? letters[index] : "\(index + 1)"
    }

    // MARK: - Quick Explanation (Shorter)

    /// Build a shorter explanation request (for inline hints)
    static func buildQuickExplanation(question: Question) -> [ChatMessage] {
        let systemPrompt = """
        Provide a very brief (2-3 sentences) explanation of the correct answer.
        Focus on the key insight needed to solve the problem.
        """

        let userPrompt = """
        Question: \(question.stem)
        Correct Answer: \(choiceLetter(question.correctIndex)). \(question.choices[question.correctIndex])

        Give a quick explanation.
        """

        return [
            ChatMessage(role: .system, content: systemPrompt),
            ChatMessage(role: .user, content: userPrompt)
        ]
    }

    // MARK: - Comparative Explanation

    /// Build an explanation comparing two answer choices
    static func buildComparisonExplanation(
        question: Question,
        choiceA: Int,
        choiceB: Int
    ) -> [ChatMessage] {
        let systemPrompt = """
        Compare these two answer choices and explain why one is better than the other.
        Be specific about the reasoning for each choice.
        """

        let userPrompt = """
        Question: \(question.stem)

        Compare these choices:
        \(choiceLetter(choiceA)). \(question.choices[choiceA])
        \(choiceLetter(choiceB)). \(question.choices[choiceB])

        The correct answer is: \(choiceLetter(question.correctIndex))

        Explain why \(choiceLetter(question.correctIndex)) is correct and \(choiceLetter(choiceA == question.correctIndex ? choiceB : choiceA)) is not.
        """

        return [
            ChatMessage(role: .system, content: systemPrompt),
            ChatMessage(role: .user, content: userPrompt)
        ]
    }
}

// MARK: - User History Summary

/// Summary of user's learning history for personalized explanations
struct UserHistorySummary {
    var overallAccuracy: Double?
    var sectionAccuracies: [QuestionSection: Double]?
    var weakTopics: [String]?
    var strongTopics: [String]?
    var recentMistakePatterns: [String]?

    func toPromptContext() -> String {
        var parts: [String] = []

        if let accuracy = overallAccuracy {
            parts.append("Overall accuracy: \(Int(accuracy * 100))%")
        }

        if let sections = sectionAccuracies {
            let sectionStr = sections.map { "\($0.key.displayName): \(Int($0.value * 100))%" }
            parts.append("By section: \(sectionStr.joined(separator: ", "))")
        }

        if let weak = weakTopics, !weak.isEmpty {
            parts.append("Needs practice with: \(weak.joined(separator: ", "))")
        }

        if let strong = strongTopics, !strong.isEmpty {
            parts.append("Strong in: \(strong.joined(separator: ", "))")
        }

        if let patterns = recentMistakePatterns, !patterns.isEmpty {
            parts.append("Recent mistake patterns: \(patterns.joined(separator: "; "))")
        }

        return parts.isEmpty ? "No prior history available." : parts.joined(separator: "\n")
    }
}
