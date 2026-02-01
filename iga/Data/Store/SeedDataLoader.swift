// IGA/Data/Store/SeedDataLoader.swift

import Foundation
import SwiftData

// MARK: - Seed Data Loader

/// Loads seed data from bundled JSON files into the database
@MainActor
struct SeedDataLoader {
    private let dataStore: DataStore

    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    // MARK: - Load All Seed Data

    /// Load all seed data if not already loaded
    func loadSeedDataIfNeeded() async throws {
        // Check if we already have questions
        let existingQuestions = try dataStore.fetchQuestions()
        if existingQuestions.isEmpty {
            try await loadQuestions()
        }

        // Check if we already have vocab words
        let existingVocab = try dataStore.fetchVocabWords()
        if existingVocab.isEmpty {
            try await loadVocabulary()
        }
    }

    // MARK: - Load Questions

    /// Load questions from bundled JSON file
    func loadQuestions() async throws {
        guard let url = Bundle.main.url(forResource: "questions", withExtension: "json") else {
            print("[SeedDataLoader] questions.json not found in bundle")
            return
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let questionsData = try decoder.decode([QuestionData].self, from: data)

        for questionData in questionsData {
            let question = questionData.toQuestion()
            dataStore.insertQuestion(question)
        }

        try dataStore.save()
        print("[SeedDataLoader] Loaded \(questionsData.count) questions")
    }

    // MARK: - Load Vocabulary

    /// Load vocabulary words from bundled JSON file
    func loadVocabulary() async throws {
        guard let url = Bundle.main.url(forResource: "vocab", withExtension: "json") else {
            print("[SeedDataLoader] vocab.json not found in bundle")
            return
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let vocabData = try decoder.decode([VocabWordData].self, from: data)

        for wordData in vocabData {
            let word = wordData.toVocabWord()
            dataStore.insertVocabWord(word)
        }

        try dataStore.save()
        print("[SeedDataLoader] Loaded \(vocabData.count) vocabulary words")
    }

    // MARK: - Load From Custom JSON

    /// Load questions from a JSON string (for testing or custom imports)
    func loadQuestions(from jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw SeedDataError.invalidJSON
        }

        let decoder = JSONDecoder()
        let questionsData = try decoder.decode([QuestionData].self, from: data)

        for questionData in questionsData {
            let question = questionData.toQuestion()
            dataStore.insertQuestion(question)
        }

        try dataStore.save()
    }

    /// Load vocabulary from a JSON string
    func loadVocabulary(from jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw SeedDataError.invalidJSON
        }

        let decoder = JSONDecoder()
        let vocabData = try decoder.decode([VocabWordData].self, from: data)

        for wordData in vocabData {
            let word = wordData.toVocabWord()
            dataStore.insertVocabWord(word)
        }

        try dataStore.save()
    }
}

// MARK: - Errors

enum SeedDataError: LocalizedError {
    case fileNotFound(String)
    case invalidJSON
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename):
            return "Seed data file not found: \(filename)"
        case .invalidJSON:
            return "Invalid JSON data"
        case .decodingError(let error):
            return "Failed to decode seed data: \(error.localizedDescription)"
        }
    }
}

// MARK: - Bundle Extension for Seed Data

extension Bundle {
    /// Check if seed data files exist
    var hasSeedData: Bool {
        url(forResource: "questions", withExtension: "json") != nil &&
        url(forResource: "vocab", withExtension: "json") != nil
    }
}
