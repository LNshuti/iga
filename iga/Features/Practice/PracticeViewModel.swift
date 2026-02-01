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

    // IRT/BKT state
    private var currentTheta: Double = 0.0
    private var sessionHistory: SessionHistory = SessionHistory()
    private var masteryStates: [String: SubskillMasteryState] = [:]
    private var allQuestions: [String: Question] = [:]
    private var questionStartTime: Date?

    // MARK: - Dependencies

    private let dataStore: DataStore
    private let inferenceClient: InferenceClient
    private let irtEngine: IRTEngine
    private let bktEngine: BKTEngine

    // MARK: - Configuration

    var mode: SessionMode = .untimed
    var sectionFilter: QuestionSection?
    var topicFilters: [String] = []
    var questionCount: Int = AppConfig.questionsPerSession
    var subskillFilter: String?

    // MARK: - Initialization

    init(
        dataStore: DataStore = .shared,
        inferenceClient: InferenceClient? = nil,
        irtEngine: IRTEngine = IRTEngine(),
        bktEngine: BKTEngine = BKTEngine()
    ) {
        self.dataStore = dataStore
        self.inferenceClient = inferenceClient ?? CerebrasInferenceClient.fromConfig() ?? MockInferenceClient()
        self.irtEngine = irtEngine
        self.bktEngine = bktEngine
    }

    // MARK: - Session Management

    /// Start a new practice session
    func startSession() async {
        do {
            // Load questions from store
            var questionList: [Question]

            if let section = sectionFilter {
                questionList = try dataStore.fetchQuestions(section: section)
            } else if !topicFilters.isEmpty {
                questionList = try dataStore.fetchQuestions(topics: topicFilters)
            } else {
                questionList = try dataStore.fetchQuestions()
            }

            // Filter by subskill if specified
            if let subskill = subskillFilter {
                questionList = questionList.filter { $0.subskillIDs.contains(subskill) || $0.primarySubskill == subskill }
            }

            // Build question lookup
            allQuestions = Dictionary(uniqueKeysWithValues: questionList.map { ($0.id, $0) })

            // Load mastery states for initial theta estimation
            let states = try dataStore.fetchOrCreateAllMasteryStates()
            masteryStates = Dictionary(uniqueKeysWithValues: states.map { ($0.subskillID, $0) })

            // Estimate initial theta from mastery states
            currentTheta = estimateInitialTheta()

            // Reset session history
            sessionHistory = SessionHistory()

            // Map SessionMode to IRTSelectionMode
            let irtMode: IRTSelectionMode
            switch mode {
            case .timed:
                irtMode = .learning
            case .untimed:
                irtMode = .learning
            case .review:
                irtMode = .review
            }

            // Use IRT engine to select questions adaptively
            var selected: [Question] = []
            for _ in 0..<min(questionCount, questionList.count) {
                if let next = await irtEngine.selectNextItem(
                    theta: currentTheta,
                    availableItems: questionList,
                    sessionHistory: sessionHistory,
                    mode: irtMode
                ) {
                    selected.append(next)
                    sessionHistory.seenQuestionIDs.insert(next.id)
                }
            }

            // Fallback to random if IRT didn't return enough
            if selected.count < questionCount {
                let remaining = questionList.filter { !sessionHistory.seenQuestionIDs.contains($0.id) }
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
            questionStartTime = Date()

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

    /// Estimate initial theta from mastery states
    private func estimateInitialTheta() -> Double {
        let relevantStates: [SubskillMasteryState]

        if let subskill = subskillFilter,
           let state = masteryStates[subskill] {
            relevantStates = [state]
        } else if let section = sectionFilter {
            let subskills = section == .quant ? Subskill.quantSubskills : Subskill.verbalSubskills
            relevantStates = subskills.compactMap { masteryStates[$0.rawValue] }
        } else {
            relevantStates = Array(masteryStates.values)
        }

        guard !relevantStates.isEmpty else { return 0.0 }

        // Weight by attempt count (more data = more reliable)
        var weightedSum = 0.0
        var totalWeight = 0.0

        for state in relevantStates {
            let weight = Double(max(1, state.attemptCount))
            weightedSum += state.thetaEstimate * weight
            totalWeight += weight
        }

        return totalWeight > 0 ? weightedSum / totalWeight : 0.0
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
              let answer = selectedAnswer,
              let sess = session else { return }

        hasSubmitted = true

        // Calculate response time
        let responseTimeMs = Int((Date().timeIntervalSince(questionStartTime ?? Date())) * 1000)

        // Record in session
        sess.recordAnswer(
            questionIndex: currentIndex,
            answerIndex: answer,
            timeSpent: elapsedSeconds
        )

        let isCorrect = question.isCorrect(answer)
        let subskillID = question.primarySubskill

        // Get current mastery state for theta tracking
        let masteryState = masteryStates[subskillID]
        let thetaBefore = masteryState?.thetaEstimate ?? currentTheta
        let pKnownBefore = masteryState?.pKnown ?? 0.5

        // Create attempt record
        let attempt = Attempt(
            questionID: question.id,
            sessionID: UUID(uuidString: sess.id) ?? UUID(),
            selectedAnswer: answer,
            isCorrect: isCorrect,
            responseTimeMs: responseTimeMs,
            subskillID: subskillID,
            thetaBefore: thetaBefore,
            pKnownBefore: pKnownBefore
        )

        // Create attempt summary for IRT
        let attemptSummary = AttemptSummary(from: attempt)
        sessionHistory.recordAttempt(attemptSummary, question: question)

        // Update theta estimate using IRT
        let (newTheta, newSE) = await irtEngine.estimateAbility(
            attempts: sessionHistory.attempts,
            questions: allQuestions,
            prior: (currentTheta, 1.0)
        )
        currentTheta = newTheta

        // Update mastery state using BKT
        if var state = masteryStates[subskillID] {
            let (newPKnown, newPLearn) = await bktEngine.updateMastery(
                state: state,
                correct: isCorrect,
                responseTimeMs: responseTimeMs,
                expectedTimeMs: question.timeBenchmarkSeconds * 1000,
                timestamp: Date()
            )

            // Update state
            state.thetaEstimate = newTheta
            state.thetaSE = newSE
            state.pKnown = newPKnown
            state.pLearn = newPLearn
            state.attemptCount += 1
            if isCorrect { state.correctCount += 1 }
            state.lastPracticed = Date()

            masteryStates[subskillID] = state

            // Update attempt with after values
            attempt.thetaAfter = newTheta
            attempt.pKnownAfter = newPKnown
        }

        // Persist to database
        do {
            dataStore.insertAttempt(attempt)

            // Log error if incorrect
            if !isCorrect {
                let errorEntry = ErrorLogEntry.fromAttempt(
                    attempt,
                    correctAnswer: question.correctIndex
                )
                dataStore.insertErrorLogEntry(errorEntry)
            }

            // Update user progress
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
        questionStartTime = Date()

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

        // Persist changes (SwiftData tracks mastery state changes automatically)
        do {
            try dataStore.save()
        } catch {
            print("Failed to save session: \(error)")
        }

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

    /// Current estimated theta (ability level)
    var estimatedTheta: Double {
        currentTheta
    }

    /// Get estimated GRE score for a section
    func estimatedScore(for section: QuestionSection) async -> (score: Int, lower: Int, upper: Int) {
        await irtEngine.estimateScaledScore(theta: currentTheta, section: section)
    }

    /// Get mastery level for a subskill
    func masteryLevel(for subskillID: String) -> MasteryLevel? {
        masteryStates[subskillID]?.masteryLevel
    }

    /// Get all mastery states for display
    var allMasteryStates: [SubskillMasteryState] {
        Array(masteryStates.values).sorted { $0.subskillID < $1.subskillID }
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
