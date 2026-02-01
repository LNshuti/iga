// IGA/Features/Diagnostic/DiagnosticViewModel.swift

import Foundation
import SwiftUI

// MARK: - Diagnostic View Model

/// Manages the diagnostic assessment flow
@MainActor
@Observable
final class DiagnosticViewModel {
    // MARK: - Dependencies

    private let dataStore: DataStore
    private let engine = DiagnosticEngine()

    // MARK: - State

    var state: DiagnosticState = .notStarted
    var currentQuestion: Question?
    var selectedAnswer: Int?
    var showFeedback: Bool = false
    var isLoading: Bool = false

    // MARK: - Session Tracking

    private var progress: [String: SubskillProgress] = [:]
    private var seenQuestionIDs: Set<String> = []
    private var allQuestions: [String: Question] = [:]
    private var sessionID: UUID = UUID()
    private var startTime: Date?
    private var questionStartTime: Date?

    // MARK: - Computed Properties

    var totalQuestionsAnswered: Int {
        progress.values.reduce(0) { $0 + $1.attempts.count }
    }

    var estimatedTotalQuestions: Int {
        // 9 subskills × ~4 questions each = ~36
        let baseEstimate = 36
        let answered = totalQuestionsAnswered
        let remaining = max(5, baseEstimate - answered)
        return answered + remaining
    }

    var progressPercentage: Double {
        let estimated = Double(estimatedTotalQuestions)
        guard estimated > 0 else { return 0 }
        return Double(totalQuestionsAnswered) / estimated
    }

    var currentSectionName: String {
        guard let question = currentQuestion,
              let subskill = Subskill(rawValue: question.primarySubskill) else {
            return "Diagnostic"
        }
        return subskill.section.displayName
    }

    // MARK: - Initialization

    init(dataStore: DataStore = .shared) {
        self.dataStore = dataStore
    }

    // MARK: - Lifecycle

    /// Start the diagnostic assessment
    func startDiagnostic() async {
        isLoading = true
        startTime = Date()
        sessionID = UUID()

        // Initialize progress for all subskills
        for subskill in Subskill.allCases {
            progress[subskill.rawValue] = SubskillProgress()
        }

        // Load all questions
        do {
            let questions = try dataStore.fetchQuestions()
            allQuestions = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
        } catch {
            state = .error("Failed to load questions: \(error.localizedDescription)")
            isLoading = false
            return
        }

        // Select first question
        await loadNextQuestion()

        state = .inProgress(
            questionNumber: 1,
            totalEstimated: estimatedTotalQuestions
        )
        isLoading = false
    }

    /// Load the next question
    private func loadNextQuestion() async {
        questionStartTime = Date()
        selectedAnswer = nil
        showFeedback = false

        currentQuestion = await engine.selectNextItem(
            progress: progress,
            availableItems: Array(allQuestions.values),
            seenQuestionIDs: seenQuestionIDs
        )

        if currentQuestion == nil {
            // No more questions available, complete diagnostic
            await completeDiagnostic()
        }
    }

    // MARK: - Answer Handling

    /// Select an answer (before submitting)
    func selectAnswer(_ index: Int) {
        selectedAnswer = index
    }

    /// Submit the selected answer
    func submitAnswer() async {
        guard let question = currentQuestion,
              let selected = selectedAnswer else { return }

        // Calculate response time
        let responseTimeMs = Int((Date().timeIntervalSince(questionStartTime ?? Date())) * 1000)

        // Create attempt summary
        let isCorrect = question.isCorrect(selected)
        let attemptSummary = AttemptSummary(
            from: Attempt(
                questionID: question.id,
                sessionID: sessionID,
                selectedAnswer: selected,
                isCorrect: isCorrect,
                responseTimeMs: responseTimeMs,
                subskillID: question.primarySubskill
            )
        )

        // Record the seen question
        seenQuestionIDs.insert(question.id)

        // Process the answer
        progress = await engine.processAnswer(
            progress: progress,
            question: question,
            attempt: attemptSummary,
            allQuestions: allQuestions
        )

        // Show brief feedback
        showFeedback = true

        // Check if complete
        if await engine.isComplete(progress: progress) {
            // Delay briefly to show feedback, then complete
            try? await Task.sleep(for: .milliseconds(800))
            await completeDiagnostic()
        } else {
            // Continue to next question after brief delay
            try? await Task.sleep(for: .milliseconds(600))
            await loadNextQuestion()

            state = .inProgress(
                questionNumber: totalQuestionsAnswered + 1,
                totalEstimated: estimatedTotalQuestions
            )
        }
    }

    // MARK: - Completion

    /// Complete the diagnostic and generate results
    private func completeDiagnostic() async {
        isLoading = true

        let totalTimeSeconds = Int(Date().timeIntervalSince(startTime ?? Date()))

        // Generate result
        let result = await engine.generateResult(
            progress: progress,
            totalTimeSeconds: totalTimeSeconds
        )

        // Save to database
        do {
            dataStore.insertDiagnosticResult(result)

            // Create mastery states from result
            let masteryStates = await engine.createMasteryStates(from: result)
            for state in masteryStates {
                dataStore.insertMasteryState(state)
            }

            // Update user progress
            let userProgress = try dataStore.fetchOrCreateUserProgress()
            userProgress.recordDiagnosticCompletion(diagnosticID: result.id)

            try dataStore.save()
        } catch {
            state = .error("Failed to save results: \(error.localizedDescription)")
            isLoading = false
            return
        }

        state = .completed(result)
        isLoading = false
    }

    // MARK: - Skip/Cancel

    /// Skip the current question (counts as incorrect)
    func skipQuestion() async {
        guard let question = currentQuestion else { return }

        let responseTimeMs = Int((Date().timeIntervalSince(questionStartTime ?? Date())) * 1000)

        let attemptSummary = AttemptSummary(
            from: Attempt(
                questionID: question.id,
                sessionID: sessionID,
                selectedAnswer: nil,
                isCorrect: false,
                responseTimeMs: responseTimeMs,
                subskillID: question.primarySubskill
            )
        )

        seenQuestionIDs.insert(question.id)

        progress = await engine.processAnswer(
            progress: progress,
            question: question,
            attempt: attemptSummary,
            allQuestions: allQuestions
        )

        await loadNextQuestion()

        state = .inProgress(
            questionNumber: totalQuestionsAnswered + 1,
            totalEstimated: estimatedTotalQuestions
        )
    }

    /// Cancel the diagnostic (no results saved)
    func cancelDiagnostic() {
        state = .notStarted
        progress = [:]
        seenQuestionIDs = []
        currentQuestion = nil
    }
}

// MARK: - Preview

extension DiagnosticViewModel {
    static var preview: DiagnosticViewModel {
        let vm = DiagnosticViewModel(dataStore: .preview)
        vm.currentQuestion = Question.preview
        vm.state = .inProgress(questionNumber: 5, totalEstimated: 36)
        return vm
    }
}
