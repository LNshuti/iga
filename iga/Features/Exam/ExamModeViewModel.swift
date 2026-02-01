// IGA/Features/Exam/ExamModeViewModel.swift

import Foundation
import SwiftUI

// MARK: - Exam State

enum ExamState {
    case setup
    case inProgress
    case sectionBreak
    case completed
}

// MARK: - Exam Section

struct ExamSection {
    let type: QuestionSection
    let questions: [Question]
    let timeLimitSeconds: Int
    var answers: [Int?]
    var flagged: Set<Int>
    var timeSpent: Int

    var questionCount: Int { questions.count }
    var timeMinutes: Int { timeLimitSeconds / 60 }
}

// MARK: - Exam Results

struct ExamResults {
    let quantScore: Int
    let verbalScore: Int
    let questionsAttempted: Int
    let correctAnswers: Int
    let totalTimeSeconds: Int
    let avgTimePerQuestion: Int

    var totalScore: Int { quantScore + verbalScore }

    var accuracyPercentage: Int {
        guard questionsAttempted > 0 else { return 0 }
        return Int(Double(correctAnswers) / Double(questionsAttempted) * 100)
    }

    var formattedTotalTime: String {
        let hours = totalTimeSeconds / 3600
        let minutes = (totalTimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }

    var formattedAvgTime: String {
        let minutes = avgTimePerQuestion / 60
        let seconds = avgTimePerQuestion % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

// MARK: - Exam Mode View Model

@MainActor
@Observable
final class ExamModeViewModel {
    // MARK: - State

    private(set) var state: ExamState = .setup
    private(set) var currentQuestion: Question?
    private(set) var selectedAnswer: Int?
    private(set) var results: ExamResults?

    var showQuestionNavigator = false

    // Setup options
    var isFullLength = true
    var selectedSection: QuestionSection = .quant
    var showTimer = true
    var allowReview = true

    // Timer
    private(set) var remainingSeconds: Int = 0
    private var timerTask: Task<Void, Never>?

    // Exam data
    private var sections: [ExamSection] = []
    private var currentSectionIndex = 0
    private var currentQuestionIndexInSection = 0
    private var examStartTime: Date?

    // MARK: - Dependencies

    private let dataStore: DataStore
    private let irtEngine: IRTEngine

    // MARK: - Initialization

    init(dataStore: DataStore = .shared, irtEngine: IRTEngine = IRTEngine()) {
        self.dataStore = dataStore
        self.irtEngine = irtEngine
    }

    // MARK: - Computed Properties

    var currentSectionName: String {
        guard currentSectionIndex < sections.count else { return "" }
        return sections[currentSectionIndex].type.displayName
    }

    var currentQuestionIndex: Int {
        currentQuestionIndexInSection
    }

    var totalQuestionsInSection: Int {
        guard currentSectionIndex < sections.count else { return 0 }
        return sections[currentSectionIndex].questionCount
    }

    var isLastQuestionInSection: Bool {
        currentQuestionIndexInSection == totalQuestionsInSection - 1
    }

    var canGoPrevious: Bool {
        allowReview && currentQuestionIndexInSection > 0
    }

    var isCurrentQuestionFlagged: Bool {
        guard currentSectionIndex < sections.count else { return false }
        return sections[currentSectionIndex].flagged.contains(currentQuestionIndexInSection)
    }

    var formattedTimeRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var nextSectionName: String {
        let nextIndex = currentSectionIndex + 1
        guard nextIndex < sections.count else { return "" }
        return sections[nextIndex].type.displayName
    }

    var nextSectionQuestionCount: Int {
        let nextIndex = currentSectionIndex + 1
        guard nextIndex < sections.count else { return 0 }
        return sections[nextIndex].questionCount
    }

    var nextSectionTimeMinutes: Int {
        let nextIndex = currentSectionIndex + 1
        guard nextIndex < sections.count else { return 0 }
        return sections[nextIndex].timeMinutes
    }

    // MARK: - Setup

    func startExam() async {
        do {
            // Load questions
            if isFullLength {
                sections = try await buildFullExam()
            } else {
                sections = try await buildSingleSection(selectedSection)
            }

            guard !sections.isEmpty else { return }

            // Initialize exam
            examStartTime = Date()
            currentSectionIndex = 0
            currentQuestionIndexInSection = 0

            // Start first section
            startSection()

            state = .inProgress
        } catch {
            print("Failed to start exam: \(error)")
        }
    }

    private func buildFullExam() async throws -> [ExamSection] {
        var examSections: [ExamSection] = []

        // Quant Section 1 (21 min, 12-15 questions)
        let quantQuestions1 = try dataStore.fetchQuestions(section: .quant)
            .shuffled()
            .prefix(12)
        examSections.append(ExamSection(
            type: .quant,
            questions: Array(quantQuestions1),
            timeLimitSeconds: 21 * 60,
            answers: Array(repeating: nil, count: quantQuestions1.count),
            flagged: [],
            timeSpent: 0
        ))

        // Verbal Section 1 (18 min, 12-15 questions)
        let verbalQuestions1 = try dataStore.fetchQuestions(section: .verbal)
            .shuffled()
            .prefix(12)
        examSections.append(ExamSection(
            type: .verbal,
            questions: Array(verbalQuestions1),
            timeLimitSeconds: 18 * 60,
            answers: Array(repeating: nil, count: verbalQuestions1.count),
            flagged: [],
            timeSpent: 0
        ))

        // Quant Section 2 (21 min)
        let quantQuestions2 = try dataStore.fetchQuestions(section: .quant)
            .filter { !quantQuestions1.map(\.id).contains($0.id) }
            .shuffled()
            .prefix(12)
        examSections.append(ExamSection(
            type: .quant,
            questions: Array(quantQuestions2),
            timeLimitSeconds: 21 * 60,
            answers: Array(repeating: nil, count: quantQuestions2.count),
            flagged: [],
            timeSpent: 0
        ))

        // Verbal Section 2 (18 min)
        let verbalQuestions2 = try dataStore.fetchQuestions(section: .verbal)
            .filter { !verbalQuestions1.map(\.id).contains($0.id) }
            .shuffled()
            .prefix(12)
        examSections.append(ExamSection(
            type: .verbal,
            questions: Array(verbalQuestions2),
            timeLimitSeconds: 18 * 60,
            answers: Array(repeating: nil, count: verbalQuestions2.count),
            flagged: [],
            timeSpent: 0
        ))

        return examSections
    }

    private func buildSingleSection(_ section: QuestionSection) async throws -> [ExamSection] {
        let timeLimit = section == .quant ? 21 * 60 : 18 * 60
        let questions = try dataStore.fetchQuestions(section: section)
            .shuffled()
            .prefix(15)

        return [ExamSection(
            type: section,
            questions: Array(questions),
            timeLimitSeconds: timeLimit,
            answers: Array(repeating: nil, count: questions.count),
            flagged: [],
            timeSpent: 0
        )]
    }

    private func startSection() {
        guard currentSectionIndex < sections.count else { return }

        let section = sections[currentSectionIndex]
        remainingSeconds = section.timeLimitSeconds
        currentQuestionIndexInSection = 0
        loadCurrentQuestion()
        startTimer()
    }

    private func loadCurrentQuestion() {
        guard currentSectionIndex < sections.count else { return }
        let section = sections[currentSectionIndex]

        guard currentQuestionIndexInSection < section.questions.count else { return }
        currentQuestion = section.questions[currentQuestionIndexInSection]
        selectedAnswer = section.answers[currentQuestionIndexInSection]
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled && remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled {
                    remainingSeconds -= 1
                    if remainingSeconds == 0 {
                        onTimeUp()
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func onTimeUp() {
        // Auto-submit section when time runs out
        submitSection()
    }

    // MARK: - Navigation

    func selectAnswer(_ index: Int) {
        selectedAnswer = index
        guard currentSectionIndex < sections.count else { return }
        sections[currentSectionIndex].answers[currentQuestionIndexInSection] = index
    }

    func nextQuestion() {
        guard currentQuestionIndexInSection < totalQuestionsInSection - 1 else { return }
        currentQuestionIndexInSection += 1
        loadCurrentQuestion()
    }

    func previousQuestion() {
        guard canGoPrevious else { return }
        currentQuestionIndexInSection -= 1
        loadCurrentQuestion()
    }

    func goToQuestion(_ index: Int) {
        guard allowReview, index >= 0, index < totalQuestionsInSection else { return }
        currentQuestionIndexInSection = index
        loadCurrentQuestion()
    }

    func toggleFlag() {
        guard currentSectionIndex < sections.count else { return }

        if sections[currentSectionIndex].flagged.contains(currentQuestionIndexInSection) {
            sections[currentSectionIndex].flagged.remove(currentQuestionIndexInSection)
        } else {
            sections[currentSectionIndex].flagged.insert(currentQuestionIndexInSection)
        }
    }

    func isFlagged(_ index: Int) -> Bool {
        guard currentSectionIndex < sections.count else { return false }
        return sections[currentSectionIndex].flagged.contains(index)
    }

    func isAnswered(_ index: Int) -> Bool {
        guard currentSectionIndex < sections.count else { return false }
        return sections[currentSectionIndex].answers[index] != nil
    }

    // MARK: - Section Management

    func submitSection() {
        stopTimer()

        // Record time spent
        sections[currentSectionIndex].timeSpent = sections[currentSectionIndex].timeLimitSeconds - remainingSeconds

        // Check if more sections
        if currentSectionIndex < sections.count - 1 {
            state = .sectionBreak
        } else {
            completeExam()
        }
    }

    func continueToNextSection() {
        currentSectionIndex += 1
        startSection()
        state = .inProgress
    }

    // MARK: - Completion

    private func completeExam() {
        // Calculate results
        var totalCorrect = 0
        var totalAttempted = 0
        var quantCorrect = 0
        var quantAttempted = 0
        var verbalCorrect = 0
        var verbalAttempted = 0
        var totalTime = 0

        for section in sections {
            totalTime += section.timeSpent

            for (index, answer) in section.answers.enumerated() {
                if let answer = answer {
                    totalAttempted += 1
                    let question = section.questions[index]
                    if question.isCorrect(answer) {
                        totalCorrect += 1
                        if section.type == .quant {
                            quantCorrect += 1
                        } else {
                            verbalCorrect += 1
                        }
                    }
                    if section.type == .quant {
                        quantAttempted += 1
                    } else {
                        verbalAttempted += 1
                    }
                }
            }
        }

        // Calculate scaled scores (simplified - actual GRE uses IRT)
        let quantAccuracy = quantAttempted > 0 ? Double(quantCorrect) / Double(quantAttempted) : 0
        let verbalAccuracy = verbalAttempted > 0 ? Double(verbalCorrect) / Double(verbalAttempted) : 0

        let quantScore = Int(130 + quantAccuracy * 40)  // 130-170 scale
        let verbalScore = Int(130 + verbalAccuracy * 40)

        results = ExamResults(
            quantScore: quantScore,
            verbalScore: verbalScore,
            questionsAttempted: totalAttempted,
            correctAnswers: totalCorrect,
            totalTimeSeconds: totalTime,
            avgTimePerQuestion: totalAttempted > 0 ? totalTime / totalAttempted : 0
        )

        state = .completed
    }

    func reviewMistakes() {
        // Navigate to error log or show mistakes
        // For now, this is a placeholder
    }
}
