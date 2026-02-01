// IGA/Features/TutorChat/TutorChatViewModel.swift

import Foundation
import SwiftUI

// MARK: - Tutor Chat ViewModel

/// ViewModel for the GRE tutor chat interface
@MainActor
@Observable
final class TutorChatViewModel {
    // MARK: - State

    private(set) var messages: [DisplayMessage] = []
    private(set) var isLoading = false
    private(set) var isStreaming = false
    private(set) var error: InferenceError?

    var inputText = ""

    // MARK: - Dependencies

    private let inferenceClient: InferenceClient
    private let dataStore: DataStore?

    // MARK: - Context

    var currentQuestion: Question?
    private var conversationHistory: [ChatMessage] = []
    private var masteryContext: MasteryContext?

    // MARK: - Initialization

    init(
        inferenceClient: InferenceClient? = nil,
        dataStore: DataStore? = nil
    ) {
        self.inferenceClient = inferenceClient ?? CerebrasInferenceClient.fromConfig() ?? MockInferenceClient()
        self.dataStore = dataStore
    }

    // MARK: - Actions

    /// Send a message to the tutor
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Clear input immediately
        inputText = ""
        error = nil

        // Add user message
        let userMessage = DisplayMessage(
            role: .user,
            content: text
        )
        messages.append(userMessage)

        // Prepare for assistant response
        let assistantMessage = DisplayMessage(
            role: .assistant,
            content: "",
            isStreaming: true
        )
        messages.append(assistantMessage)
        isStreaming = true

        do {
            // Build messages for API
            let apiMessages = buildAPIMessages(userMessage: text)

            // Create request
            let request = GenerationRequest(
                messages: apiMessages,
                maxTokens: AppConfig.maxGenerationTokens,
                temperature: 0.7,
                stream: true
            )

            // Stream response
            let stream = try await inferenceClient.stream(request: request)

            var fullResponse = ""
            for try await token in stream {
                fullResponse += token
                updateLastMessage(content: fullResponse, isStreaming: true)
            }

            // Finalize response
            updateLastMessage(content: fullResponse, isStreaming: false)

            // Update conversation history
            conversationHistory.append(ChatMessage(role: .user, content: text))
            conversationHistory.append(ChatMessage(role: .assistant, content: fullResponse))

            // Persist to store if available
            saveMessages(userContent: text, assistantContent: fullResponse)

        } catch let inferenceError as InferenceError {
            error = inferenceError
            removeLastMessage()
        } catch {
            self.error = .unknown(error)
            removeLastMessage()
        }

        isStreaming = false
    }

    /// Send a message about a specific question
    func askAboutQuestion(_ question: Question, query: String) async {
        currentQuestion = question
        inputText = query
        await sendMessage()
    }

    /// Start a new conversation
    func startNewConversation() {
        messages.removeAll()
        conversationHistory.removeAll()
        currentQuestion = nil
        error = nil

        // Add welcome message
        let welcome = DisplayMessage(
            role: .assistant,
            content: TutorPromptBuilder.greetingPrompts.randomElement() ?? "Hello! How can I help you prepare for the GRE today?"
        )
        messages.append(welcome)
    }

    /// Retry the last failed message
    func retryLastMessage() async {
        guard let lastUserMessage = messages.last(where: { $0.role == .user }) else { return }

        // Remove the failed assistant message
        if messages.last?.role == .assistant && messages.last?.content.isEmpty == true {
            messages.removeLast()
        }

        // Resend
        inputText = lastUserMessage.content
        messages.removeLast() // Remove the user message, it will be re-added
        await sendMessage()
    }

    /// Clear error state
    func dismissError() {
        error = nil
    }

    // MARK: - Private Helpers

    private func buildAPIMessages(userMessage: String) -> [ChatMessage] {
        let context = buildTutorContext()

        if let question = currentQuestion {
            var contextWithQuestion = context
            contextWithQuestion.currentQuestion = question
            contextWithQuestion.section = question.section

            return TutorPromptBuilder.buildMessages(
                conversationHistory: conversationHistory,
                userMessage: userMessage,
                context: contextWithQuestion
            )
        } else {
            return TutorPromptBuilder.buildMessages(
                conversationHistory: conversationHistory,
                userMessage: userMessage,
                context: context
            )
        }
    }

    /// Build TutorContext from mastery data
    private func buildTutorContext() -> TutorContext {
        guard let context = masteryContext else {
            return TutorContext()
        }

        return TutorContext(
            currentQuestion: currentQuestion,
            section: nil,
            recentTopics: nil,
            userStrengths: context.strongestSubskills,
            userWeaknesses: context.weakestSubskills,
            estimatedQuantScore: context.estimatedQuantScore,
            estimatedVerbalScore: context.estimatedVerbalScore,
            overallAccuracy: context.overallAccuracy,
            totalQuestionsAttempted: context.totalQuestionsAttempted,
            commonErrorTypes: context.commonErrorTypes,
            currentStreak: context.currentStreak
        )
    }

    private func updateLastMessage(content: String, isStreaming: Bool) {
        guard !messages.isEmpty else { return }
        messages[messages.count - 1].content = content
        messages[messages.count - 1].isStreaming = isStreaming
    }

    private func removeLastMessage() {
        if !messages.isEmpty {
            messages.removeLast()
        }
    }

    private func saveMessages(userContent: String, assistantContent: String) {
        guard let store = dataStore else { return }

        let userMsg = TutorMessage(
            role: .user,
            content: userContent,
            relatedQuestionId: currentQuestion?.id
        )
        let assistantMsg = TutorMessage(
            role: .assistant,
            content: assistantContent,
            relatedQuestionId: currentQuestion?.id
        )

        store.insertTutorMessage(userMsg)
        store.insertTutorMessage(assistantMsg)
        try? store.save()
    }

    /// Load conversation history from store
    func loadHistory() async {
        guard let store = dataStore else { return }

        do {
            let storedMessages = try store.fetchTutorMessages()
            messages = storedMessages.map { msg in
                DisplayMessage(
                    id: msg.id,
                    role: msg.role,
                    content: msg.content,
                    timestamp: msg.timestamp
                )
            }

            conversationHistory = storedMessages.map { $0.toChatMessage() }

            // Load mastery context for personalized advice
            await loadMasteryContext()

            // Add welcome if no history
            if messages.isEmpty {
                startNewConversation()
            }
        } catch {
            startNewConversation()
        }
    }

    /// Load mastery context for personalized tutoring
    private func loadMasteryContext() async {
        guard let store = dataStore else { return }

        do {
            let masteryStates = try store.fetchOrCreateAllMasteryStates()
            let userProgress = try store.fetchOrCreateUserProgress()
            let diagnosticResult = try store.fetchLatestDiagnosticResult()

            // Find weakest subskills
            let weakest = masteryStates
                .sorted { $0.pKnown < $1.pKnown }
                .prefix(3)
                .compactMap { Subskill(rawValue: $0.subskillID)?.name }

            // Find strongest subskills
            let strongest = masteryStates
                .sorted { $0.pKnown > $1.pKnown }
                .prefix(2)
                .compactMap { Subskill(rawValue: $0.subskillID)?.name }

            // Calculate overall accuracy
            let overallAccuracy = userProgress.totalAttempted > 0
                ? Double(userProgress.totalCorrect) / Double(userProgress.totalAttempted)
                : 0

            // Find common error types from mistake journal
            var commonErrorTypes: [ErrorType]? = nil
            if let errorStats = try? store.calculateErrorStats(),
               errorStats.totalErrors > 0 {
                // Get top 2 most common error types
                let topErrors = errorStats.byType
                    .sorted { $0.value > $1.value }
                    .prefix(2)
                    .map { $0.key }
                if !topErrors.isEmpty {
                    commonErrorTypes = Array(topErrors)
                }
            }

            masteryContext = MasteryContext(
                weakestSubskills: Array(weakest),
                strongestSubskills: Array(strongest),
                overallAccuracy: overallAccuracy,
                estimatedQuantScore: diagnosticResult?.estimatedQuantScore,
                estimatedVerbalScore: diagnosticResult?.estimatedVerbalScore,
                totalQuestionsAttempted: userProgress.totalAttempted,
                currentStreak: userProgress.currentStreak,
                commonErrorTypes: commonErrorTypes
            )
        } catch {
            masteryContext = nil
        }
    }

    /// Generate context string for AI prompt
    private func buildContextString() -> String? {
        guard let context = masteryContext else { return nil }

        var parts: [String] = []

        if !context.weakestSubskills.isEmpty {
            parts.append("Areas needing work: \(context.weakestSubskills.joined(separator: ", "))")
        }

        if !context.strongestSubskills.isEmpty {
            parts.append("Strong areas: \(context.strongestSubskills.joined(separator: ", "))")
        }

        if context.totalQuestionsAttempted > 0 {
            parts.append("Overall accuracy: \(Int(context.overallAccuracy * 100))% across \(context.totalQuestionsAttempted) questions")
        }

        if let quant = context.estimatedQuantScore, let verbal = context.estimatedVerbalScore {
            parts.append("Estimated scores: Quant \(quant), Verbal \(verbal)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }
}

// MARK: - Mastery Context

/// Context about user's current mastery for personalized tutoring
struct MasteryContext {
    let weakestSubskills: [String]
    let strongestSubskills: [String]
    let overallAccuracy: Double
    let estimatedQuantScore: Int?
    let estimatedVerbalScore: Int?
    let totalQuestionsAttempted: Int
    let currentStreak: Int
    let commonErrorTypes: [ErrorType]?
}

// MARK: - Preview Support

extension TutorChatViewModel {
    static var preview: TutorChatViewModel {
        let vm = TutorChatViewModel(
            inferenceClient: MockInferenceClient()
        )
        vm.messages = DisplayMessage.previewList
        return vm
    }
}
