// IGA/Features/Vocab/VocabViewModel.swift

import Foundation
import SwiftUI

// MARK: - Vocabulary View Model

/// ViewModel for vocabulary learning features
@MainActor
@Observable
final class VocabViewModel {

    // MARK: - State

    private(set) var words: [VocabWord] = []
    private(set) var filteredWords: [VocabWord] = []
    var selectedWord: VocabWord?
    private(set) var relatedWords: [VocabWord] = []
    private(set) var stats: VocabStats?
    private(set) var isLoading = false
    private(set) var error: Error?

    // Review session
    private(set) var reviewSession: VocabReviewSession?
    private(set) var isReviewing = false

    // Search and filter
    var searchText = "" {
        didSet { applyFilter() }
    }

    // MARK: - Dependencies

    private let dataStore: DataStore
    private let spacedRepetition: SpacedRepetitionEngine
    private let inferenceClient: InferenceClient?

    // MARK: - Initialization

    init(
        dataStore: DataStore = .shared,
        spacedRepetition: SpacedRepetitionEngine = SpacedRepetitionEngine(),
        inferenceClient: InferenceClient? = nil
    ) {
        self.dataStore = dataStore
        self.spacedRepetition = spacedRepetition
        self.inferenceClient = inferenceClient
    }

    // MARK: - Loading

    /// Load all vocabulary words
    func loadWords() async {
        isLoading = true
        error = nil

        do {
            words = try dataStore.fetchVocabWords()
            applyFilter()
            stats = await spacedRepetition.calculateStats(words: words)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Refresh stats
    func refreshStats() async {
        stats = await spacedRepetition.calculateStats(words: words)
    }

    // MARK: - Filtering

    private func applyFilter() {
        if searchText.isEmpty {
            filteredWords = words
        } else {
            let query = searchText.lowercased()
            filteredWords = words.filter { word in
                word.headword.lowercased().contains(query) ||
                word.definition.lowercased().contains(query) ||
                word.synonyms.contains { $0.lowercased().contains(query) }
            }
        }
    }

    // MARK: - Word Selection

    /// Select a word to view details
    func selectWord(_ word: VocabWord) async {
        selectedWord = word
        relatedWords = []

        // Load related words
        relatedWords = await spacedRepetition.findSimilarWords(to: word, among: words, topK: 5)
    }

    /// Clear selection
    func clearSelection() {
        selectedWord = nil
        relatedWords = []
    }

    // MARK: - Review Session

    /// Start a review session with due words
    func startReviewSession() async {
        let dueWords = await spacedRepetition.getDueWords(from: words, limit: 20)

        if dueWords.isEmpty {
            // No words due, offer to review random words
            let randomWords = Array(words.shuffled().prefix(10))
            reviewSession = VocabReviewSession()
            reviewSession?.loadWords(randomWords)
        } else {
            reviewSession = VocabReviewSession()
            reviewSession?.loadWords(dueWords)
        }

        isReviewing = true
    }

    /// End the current review session
    func endReviewSession() async {
        isReviewing = false
        reviewSession = nil
        await refreshStats()
    }

    /// Record a review quality
    func recordReview(quality: ReviewQuality) async {
        guard let session = reviewSession else { return }
        await session.recordQuality(quality)

        // Check if session is complete
        if session.isComplete {
            try? dataStore.save()
            await refreshStats()
        }
    }

    // MARK: - AI Features

    /// Generate AI context for a word
    func generateWordContext(for word: VocabWord) async -> String? {
        guard let client = inferenceClient, client.isConfigured else {
            return nil
        }

        let prompt = """
        Provide 2-3 additional example sentences using the word "\(word.headword)" in different contexts.
        Also mention any common GRE word pairs or related concepts.
        Keep it concise (under 100 words).
        """

        let messages = [
            ChatMessage(role: .system, content: "You are a GRE vocabulary tutor. Provide helpful context for vocabulary words."),
            ChatMessage(role: .user, content: prompt)
        ]

        let request = GenerationRequest(
            messages: messages,
            maxTokens: 200,
            temperature: 0.7
        )

        do {
            let response = try await client.generate(request: request)
            return response.content
        } catch {
            return nil
        }
    }

    // MARK: - Statistics

    /// Get words due for review count
    var dueCount: Int {
        stats?.dueForReview ?? 0
    }

    /// Get mastered words count
    var masteredCount: Int {
        stats?.mastered ?? 0
    }

    /// Dismiss error
    func dismissError() {
        error = nil
    }
}

// MARK: - Preview Support

extension VocabViewModel {
    static var preview: VocabViewModel {
        let vm = VocabViewModel(
            dataStore: .preview,
            inferenceClient: MockInferenceClient()
        )
        vm.words = VocabWord.previewList
        vm.filteredWords = VocabWord.previewList
        vm.stats = VocabStats(
            totalWords: 100,
            dueForReview: 15,
            learning: 30,
            mastered: 45,
            averageEaseFactor: 2.3
        )
        return vm
    }
}
