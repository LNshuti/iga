// IGA/Features/Practice/PracticeViewModel.swift

import Foundation
import SwiftUI

// MARK: - Practice View Model

/// ViewModel for GRE practice sessions
@MainActor
@Observable
final class PracticeViewModel {

    // MARK: - State

    private(set) var currentQuestion: Question?
    private(set) var questions: [Question] = []
    private(set) var currentIndex: Int = 0
    private(set) var selectedAnswer: Int?
    private(set) var hasSubmitted: Bool = false
    private(set) var explanation: String?
    private(set) var isLoadingExplanation: Bool = false
    private(set) var error: InferenceError?

    // Session state
    private(set) var session: Session?
    private(set) var isSessionComplete: Bool = false

    // Timer state
    var remainingSeconds: Int = 0
    var elapsedSeconds: Int = 0
    private(set) var isTimed: Bool = false

    // MARK: - Dependencies

    private let dataStore: DataStore
    private let inferenceClient: InferenceClient
    private let adaptiveEngine: AdaptiveEngine

    // MARK: - Configuration

    var mode: SessionMode = .untimed
    var sectionFilter: QuestionSection?
    var topicFilters: [String] = []
    var questionCount: Int = AppConfig.questionsPerSession

    // MARK: - Initialization

    init(
        dataStore: DataStore = .shared,
        inferenceClient: InferenceClient? = nil,
        adaptiveEngine: AdaptiveEngine = AdaptiveEngine()
    ) {
        self.dataStore = dataStore
        self.inferenceClient = inferenceClient ?? CerebrasInferenceClient.fromConfig() ?? MockInferenceClient()
        self.adaptiveEngine = adaptiveEngine
    }

    // MARK: - Session Management

    /// Start a new practice session
    func startSession() async {
        do {
            // Load questions from store
            var allQuestions: [Question]

            if let section = sectionFilter {
                allQuestions = try dataStore.fetchQuestions(section: section)
            } else if !topicFilters.isEmpty {
                allQuestions = try dataStore.fetchQuestions(topics: topicFilters)
            } else {
                allQuestions = try dataStore.fetchQuestions()
            }

            // Use adaptive engine to select questions
            var selected: [Question] = []
            var recentIds: Set<String> = []

            for _ in 0..<min(questionCount, allQuestions.count) {
                if let next = await adaptiveEngine.selectNextQuestion(from: allQuestions, avoiding: recentIds) {
                    selected.append(next)
                    recentIds.insert(next.id)
                }
            }

            // Fallback to random if adaptive didn't return enough
            if selected.count < questionCount {
                let remaining = allQuestions.filter { !recentIds.contains($0.id) }
                selected.append(contentsOf: remaining.shuffled().prefix(questionCount - selected.count))
            }

            questions = selected

            // Create session
            session = Session(
                mode: mode,
                questionIds: questions.map { $0.id },
                sectionFilter: sectionFilter,
                topicFilters: topicFilters
            )

            if let session {
                dataStore.insertSession(session)
            }

            // Initialize state
            currentIndex = 0
            currentQuestion = questions.first
            selectedAnswer = nil
            hasSubmitted = false
            explanation = nil
            isSessionComplete = false

            // Timer setup
            isTimed = mode == .timed
            if isTimed {
                remainingSeconds = AppConfig.defaultQuestionTimeLimit
            }
            elapsedSeconds = 0

        } catch {
            self.error = .unknown(error)
        }
    }

    // MARK: - Answer Handling

    /// Select an answer choice
    func selectAnswer(_ index: Int) {
        guard !hasSubmitted else { return }
        selectedAnswer = index
    }

    /// Submit the current answer
    func submitAnswer() async {
        guard let question = currentQuestion,
              let answer = selectedAnswer else { return }

        hasSubmitted = true

        // Record in session
        session?.recordAnswer(
            questionIndex: currentIndex,
            answerIndex: answer,
            timeSpent: elapsedSeconds
        )

        // Update adaptive engine
        let isCorrect = question.isCorrect(answer)
        await adaptiveEngine.recordAnswer(question: question, wasCorrect: isCorrect)

        // Update user progress
        do {
            let progress = try dataStore.fetchOrCreateUserProgress()
            progress.recordAttempt(
                section: question.section,
                topics: question.topics,
                isCorrect: isCorrect,
                timeSpent: elapsedSeconds
            )
            try dataStore.save()
        } catch {
            print("Failed to update progress: \(error)")
        }
    }

    /// Load AI-generated explanation
    func loadExplanation() async {
        guard let question = currentQuestion else { return }

        isLoadingExplanation = true
        error = nil

        do {
            let messages = ExplanationPromptBuilder.buildMessages(
                question: question,
                selectedIndex: selectedAnswer,
                isCorrect: selectedAnswer.map { question.isCorrect($0) }
            )

            let request = GenerationRequest(
                messages: messages,
                maxTokens: AppConfig.maxExplanationTokens,
                temperature: 0.5,
                stream: false
            )

            let response = try await inferenceClient.generate(request: request)
            explanation = response.content

        } catch let inferenceError as InferenceError {
            error = inferenceError
            // Fall back to stored rationale if available
            explanation = currentQuestion?.rationale
        } catch {
            self.error = .unknown(error)
            explanation = currentQuestion?.rationale
        }

        isLoadingExplanation = false
    }

    /// Move to the next question
    func nextQuestion() {
        guard currentIndex < questions.count - 1 else {
            completeSession()
            return
        }

        currentIndex += 1
        currentQuestion = questions[currentIndex]
        selectedAnswer = nil
        hasSubmitted = false
        explanation = nil
        elapsedSeconds = 0

        if isTimed {
            remainingSeconds = AppConfig.defaultQuestionTimeLimit
        }
    }

    /// Move to the previous question (review mode)
    func previousQuestion() {
        guard currentIndex > 0 else { return }

        currentIndex -= 1
        currentQuestion = questions[currentIndex]

        // Restore previous answer state
        if let answers = session?.answers, currentIndex < answers.count {
            selectedAnswer = answers[currentIndex]
            hasSubmitted = selectedAnswer != nil
        }
        explanation = nil
    }

    /// Handle time running out
    func onTimeUp() {
        if !hasSubmitted {
            // Auto-submit with no answer
            hasSubmitted = true
            session?.recordAnswer(
                questionIndex: currentIndex,
                answerIndex: nil,
                timeSpent: remainingSeconds
            )
        }
    }

    /// Complete the session
    private func completeSession() {
        session?.completedAt = Date()
        try? dataStore.save()
        isSessionComplete = true
    }

    // MARK: - Computed Properties

    /// Current progress (0-1)
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(questions.count)
    }

    /// Whether the current answer is correct
    var isCurrentAnswerCorrect: Bool? {
        guard hasSubmitted, let answer = selectedAnswer, let question = currentQuestion else {
            return nil
        }
        return question.isCorrect(answer)
    }

    /// Session statistics
    var sessionStats: SessionStats {
        guard let session else {
            return SessionStats(correct: 0, total: 0, averageTime: 0)
        }

        let answered = session.answers.compactMap { $0 }
        let correct = zip(answered, questions).filter { answer, question in
            question.isCorrect(answer)
        }.count

        let times = session.timesSpent.filter { $0 > 0 }
        let avgTime = times.isEmpty ? 0 : times.reduce(0, +) / times.count

        return SessionStats(
            correct: correct,
            total: answered.count,
            averageTime: avgTime
        )
    }

    /// Dismiss error
    func dismissError() {
        error = nil
    }
}

// MARK: - Session Stats

struct SessionStats {
    let correct: Int
    let total: Int
    let averageTime: Int

    var accuracy: Double {
        guard total > 0 else { return 0 }
        return Double(correct) / Double(total)
    }

    var accuracyPercentage: Int {
        Int(accuracy * 100)
    }
}

// MARK: - Preview Support

extension PracticeViewModel {
    static var preview: PracticeViewModel {
        let vm = PracticeViewModel(
            dataStore: .preview,
            inferenceClient: MockInferenceClient()
        )
        vm.questions = Question.previewList
        vm.currentQuestion = Question.preview
        return vm
    }
}
