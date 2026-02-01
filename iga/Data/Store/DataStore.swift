// IGA/Data/Store/DataStore.swift

import Foundation
import SwiftData

// MARK: - Data Store

/// Central data store for managing all persistent data
@MainActor
@Observable
final class DataStore {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    /// Shared instance for the app
    static let shared: DataStore = {
        do {
            return try DataStore()
        } catch {
            fatalError("Failed to initialize DataStore: \(error)")
        }
    }()

    init(inMemory: Bool = false) throws {
        let schema = Schema([
            Question.self,
            VocabWord.self,
            Session.self,
            UserProgress.self,
            TutorMessage.self,
            SubskillMasteryState.self,
            Attempt.self,
            DiagnosticResult.self,
            ErrorLogEntry.self
        ])

        // Use versioned store name to handle schema migrations cleanly
        // Bump this version when schema changes significantly
        let storeName = "IGA_v3.store"

        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            // Use custom store URL with version
            let url = URL.applicationSupportDirectory
                .appending(path: storeName)
            configuration = ModelConfiguration(
                schema: schema,
                url: url
            )
        }

        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext
    }

    // MARK: - Questions

    /// Fetch all questions
    func fetchQuestions() throws -> [Question] {
        let descriptor = FetchDescriptor<Question>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch questions by section
    func fetchQuestions(section: QuestionSection) throws -> [Question] {
        let sectionRaw = section.rawValue
        let descriptor = FetchDescriptor<Question>(
            predicate: #Predicate { $0.sectionRaw == sectionRaw },
            sortBy: [SortDescriptor(\.difficulty)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch questions by topics
    func fetchQuestions(topics: [String], difficulty: ClosedRange<Int>? = nil) throws -> [Question] {
        var descriptor = FetchDescriptor<Question>()

        if let diffRange = difficulty {
            let minDiff = diffRange.lowerBound
            let maxDiff = diffRange.upperBound
            descriptor.predicate = #Predicate {
                $0.difficulty >= minDiff && $0.difficulty <= maxDiff
            }
        }

        let allQuestions = try modelContext.fetch(descriptor)

        // Filter by topics (checking if any topic matches)
        return allQuestions.filter { question in
            !Set(question.topics).isDisjoint(with: Set(topics))
        }
    }

    /// Fetch a single question by ID
    func fetchQuestion(id: String) throws -> Question? {
        let descriptor = FetchDescriptor<Question>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Insert a new question
    func insertQuestion(_ question: Question) {
        modelContext.insert(question)
    }

    // MARK: - Vocabulary

    /// Fetch all vocabulary words
    func fetchVocabWords() throws -> [VocabWord] {
        let descriptor = FetchDescriptor<VocabWord>(
            sortBy: [SortDescriptor(\.headword)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch vocabulary words due for review
    func fetchVocabDueForReview() throws -> [VocabWord] {
        let now = Date()
        let descriptor = FetchDescriptor<VocabWord>(
            predicate: #Predicate {
                $0.nextReview == nil || $0.nextReview! <= now
            },
            sortBy: [SortDescriptor(\.nextReview)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch a single vocab word by ID
    func fetchVocabWord(id: String) throws -> VocabWord? {
        let descriptor = FetchDescriptor<VocabWord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Insert a new vocabulary word
    func insertVocabWord(_ word: VocabWord) {
        modelContext.insert(word)
    }

    // MARK: - Sessions

    /// Fetch all sessions
    func fetchSessions() throws -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch active (incomplete) sessions
    func fetchActiveSessions() throws -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.completedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Insert a new session
    func insertSession(_ session: Session) {
        modelContext.insert(session)
    }

    // MARK: - User Progress

    /// Fetch or create user progress
    func fetchOrCreateUserProgress() throws -> UserProgress {
        let descriptor = FetchDescriptor<UserProgress>(
            predicate: #Predicate { $0.id == "default-user" }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let newProgress = UserProgress(id: "default-user")
        modelContext.insert(newProgress)
        return newProgress
    }

    // MARK: - Tutor Messages

    /// Fetch all tutor messages
    func fetchTutorMessages() throws -> [TutorMessage] {
        let descriptor = FetchDescriptor<TutorMessage>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Clear all tutor messages (new conversation)
    func clearTutorMessages() throws {
        let messages = try fetchTutorMessages()
        for message in messages {
            modelContext.delete(message)
        }
    }

    /// Insert a tutor message
    func insertTutorMessage(_ message: TutorMessage) {
        modelContext.insert(message)
    }

    // MARK: - Subskill Mastery States

    /// Fetch all mastery states
    func fetchMasteryStates() throws -> [SubskillMasteryState] {
        let descriptor = FetchDescriptor<SubskillMasteryState>(
            sortBy: [SortDescriptor(\.subskillID)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch mastery state for a specific subskill
    func fetchMasteryState(subskillID: String) throws -> SubskillMasteryState? {
        let descriptor = FetchDescriptor<SubskillMasteryState>(
            predicate: #Predicate { $0.subskillID == subskillID }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Fetch or create mastery states for all subskills
    func fetchOrCreateAllMasteryStates() throws -> [SubskillMasteryState] {
        let existing = try fetchMasteryStates()
        let existingIDs = Set(existing.map { $0.subskillID })

        var allStates = existing

        // Create missing states
        for subskill in Subskill.allCases {
            if !existingIDs.contains(subskill.rawValue) {
                let newState = SubskillMasteryState(subskillID: subskill.rawValue)
                modelContext.insert(newState)
                allStates.append(newState)
            }
        }

        return allStates
    }

    /// Insert a mastery state
    func insertMasteryState(_ state: SubskillMasteryState) {
        modelContext.insert(state)
    }

    // MARK: - Attempts

    /// Fetch all attempts
    func fetchAttempts() throws -> [Attempt] {
        let descriptor = FetchDescriptor<Attempt>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch attempts for a specific session
    func fetchAttempts(sessionID: UUID) throws -> [Attempt] {
        let descriptor = FetchDescriptor<Attempt>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch attempts for a specific subskill
    func fetchAttempts(subskillID: String, limit: Int? = nil) throws -> [Attempt] {
        var descriptor = FetchDescriptor<Attempt>(
            predicate: #Predicate { $0.subskillID == subskillID },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        return try modelContext.fetch(descriptor)
    }

    /// Fetch recent attempts (last N days)
    func fetchRecentAttempts(days: Int = 7) throws -> [Attempt] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<Attempt>(
            predicate: #Predicate { $0.timestamp >= cutoffDate },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Insert an attempt
    func insertAttempt(_ attempt: Attempt) {
        modelContext.insert(attempt)
    }

    // MARK: - Diagnostic Results

    /// Fetch all diagnostic results
    func fetchDiagnosticResults() throws -> [DiagnosticResult] {
        let descriptor = FetchDescriptor<DiagnosticResult>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch the most recent diagnostic result
    func fetchLatestDiagnosticResult() throws -> DiagnosticResult? {
        var descriptor = FetchDescriptor<DiagnosticResult>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Fetch diagnostic result by ID
    func fetchDiagnosticResult(id: UUID) throws -> DiagnosticResult? {
        let descriptor = FetchDescriptor<DiagnosticResult>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Insert a diagnostic result
    func insertDiagnosticResult(_ result: DiagnosticResult) {
        modelContext.insert(result)
    }

    // MARK: - Error Log

    /// Fetch all error log entries
    func fetchErrorLogEntries() throws -> [ErrorLogEntry] {
        let descriptor = FetchDescriptor<ErrorLogEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch unreviewed error log entries
    func fetchUnreviewedErrors() throws -> [ErrorLogEntry] {
        let descriptor = FetchDescriptor<ErrorLogEntry>(
            predicate: #Predicate { !$0.hasReviewed },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch errors by subskill
    func fetchErrors(subskillID: String) throws -> [ErrorLogEntry] {
        let descriptor = FetchDescriptor<ErrorLogEntry>(
            predicate: #Predicate { $0.subskillID == subskillID },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch errors by type
    func fetchErrors(type: ErrorType) throws -> [ErrorLogEntry] {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<ErrorLogEntry>(
            predicate: #Predicate { $0.errorTypeRaw == typeRaw },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Insert an error log entry
    func insertErrorLogEntry(_ entry: ErrorLogEntry) {
        modelContext.insert(entry)
    }

    /// Calculate error statistics
    func calculateErrorStats() throws -> ErrorStats {
        let allErrors = try fetchErrorLogEntries()

        var byType: [ErrorType: Int] = [:]
        var bySubskill: [String: Int] = [:]
        var reviewedCount = 0
        var retriedCorrectCount = 0

        for error in allErrors {
            byType[error.errorType, default: 0] += 1
            bySubskill[error.subskillID, default: 0] += 1

            if error.hasReviewed {
                reviewedCount += 1
                if error.retriedCorrectly == true {
                    retriedCorrectCount += 1
                }
            }
        }

        return ErrorStats(
            totalErrors: allErrors.count,
            reviewedCount: reviewedCount,
            retriedCorrectCount: retriedCorrectCount,
            byType: byType,
            bySubskill: bySubskill
        )
    }

    // MARK: - Save

    /// Save any pending changes
    func save() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
}

// MARK: - Preview Support

extension DataStore {
    /// Create an in-memory store for previews
    static var preview: DataStore {
        do {
            let store = try DataStore(inMemory: true)

            // Insert sample data
            for question in Question.previewList {
                store.modelContext.insert(question)
            }

            for word in VocabWord.previewList {
                store.modelContext.insert(word)
            }

            let progress = UserProgress.preview
            store.modelContext.insert(progress)

            return store
        } catch {
            fatalError("Failed to create preview DataStore: \(error)")
        }
    }
}
