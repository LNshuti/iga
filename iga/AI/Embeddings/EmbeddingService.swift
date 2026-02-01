// IGA/AI/Embeddings/EmbeddingService.swift

import Foundation

// MARK: - Embedding Service

/// Service for generating and comparing embeddings for vocabulary words
/// Used for semantic similarity in spaced repetition and related words
actor EmbeddingService {
    private let inferenceClient: InferenceClient?
    private var cache: [String: [Double]] = [:]

    init(inferenceClient: InferenceClient? = nil) {
        self.inferenceClient = inferenceClient
    }

    // MARK: - Generate Embeddings

    /// Generate embedding for a single text
    /// - Parameter text: Text to embed
    /// - Returns: Embedding vector
    func embed(_ text: String) async throws -> [Double] {
        // Check cache first
        if let cached = cache[text] {
            return cached
        }

        guard let client = inferenceClient, client.isConfigured else {
            throw EmbeddingError.notConfigured
        }

        let request = EmbeddingRequest(texts: [text])
        let response = try await client.embed(request: request)

        guard let embedding = response.embeddings.first else {
            throw EmbeddingError.emptyResponse
        }

        cache[text] = embedding
        return embedding
    }

    /// Generate embeddings for multiple texts
    /// - Parameter texts: Array of texts to embed
    /// - Returns: Array of embedding vectors
    func embedBatch(_ texts: [String]) async throws -> [[Double]] {
        guard let client = inferenceClient, client.isConfigured else {
            throw EmbeddingError.notConfigured
        }

        // Check which texts need embedding
        var uncached: [String] = []
        var results: [String: [Double]] = [:]

        for text in texts {
            if let cached = cache[text] {
                results[text] = cached
            } else {
                uncached.append(text)
            }
        }

        // Fetch uncached embeddings
        if !uncached.isEmpty {
            let request = EmbeddingRequest(texts: uncached)
            let response = try await client.embed(request: request)

            for (index, text) in uncached.enumerated() {
                if index < response.embeddings.count {
                    let embedding = response.embeddings[index]
                    cache[text] = embedding
                    results[text] = embedding
                }
            }
        }

        // Return in original order
        return texts.compactMap { results[$0] }
    }

    // MARK: - Similarity

    /// Calculate cosine similarity between two embeddings
    /// - Parameters:
    ///   - a: First embedding vector
    ///   - b: Second embedding vector
    /// - Returns: Similarity score between -1 and 1 (1 = identical)
    func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Double = 0
        var normA: Double = 0
        var normB: Double = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    /// Find the most similar items to a query
    /// - Parameters:
    ///   - queryEmbedding: Embedding to compare against
    ///   - candidates: Array of (id, embedding) tuples
    ///   - topK: Number of results to return
    /// - Returns: Array of (id, similarity) tuples, sorted by similarity descending
    func findSimilar(
        to queryEmbedding: [Double],
        among candidates: [(String, [Double])],
        topK: Int = 5
    ) -> [(String, Double)] {
        candidates
            .map { (id, embedding) in
                (id, cosineSimilarity(queryEmbedding, embedding))
            }
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map { ($0.0, $0.1) }
    }

    // MARK: - Vocabulary Helpers

    /// Generate embedding for a vocabulary word
    /// Combines the word, definition, and example for richer semantics
    func embedVocabWord(_ word: VocabWord) async throws -> [Double] {
        let text = "\(word.headword): \(word.definition). Example: \(word.example)"
        return try await embed(text)
    }

    /// Find vocabulary words similar to a given word
    func findSimilarWords(
        to word: VocabWord,
        among allWords: [VocabWord],
        topK: Int = 5
    ) async throws -> [VocabWord] {
        // Get embedding for the target word
        let targetEmbedding: [Double]
        if let existing = word.embedding {
            targetEmbedding = existing
        } else {
            targetEmbedding = try await embedVocabWord(word)
        }

        // Get embeddings for all candidates
        let candidates: [(String, [Double])] = try await allWords
            .filter { $0.id != word.id }
            .asyncCompactMap { w in
                if let embedding = w.embedding {
                    return (w.id, embedding)
                }
                do {
                    let embedding = try await embedVocabWord(w)
                    return (w.id, embedding)
                } catch {
                    return nil
                }
            }

        // Find similar
        let similarIds = findSimilar(to: targetEmbedding, among: candidates, topK: topK)
            .map { $0.0 }

        // Return words in similarity order
        let idToWord = Dictionary(uniqueKeysWithValues: allWords.map { ($0.id, $0) })
        return similarIds.compactMap { idToWord[$0] }
    }

    // MARK: - Cache Management

    /// Clear the embedding cache
    func clearCache() {
        cache.removeAll()
    }

    /// Get cache statistics
    var cacheStats: (count: Int, approximateSize: Int) {
        let count = cache.count
        // Approximate size: each Double is 8 bytes
        let avgEmbeddingSize = cache.values.first?.count ?? 0
        let approximateSize = count * avgEmbeddingSize * 8
        return (count, approximateSize)
    }
}

// MARK: - Errors

enum EmbeddingError: LocalizedError {
    case notConfigured
    case emptyResponse
    case dimensionMismatch

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Embedding service is not configured. Check API settings."
        case .emptyResponse:
            return "Received empty embedding response from server."
        case .dimensionMismatch:
            return "Embedding dimensions do not match."
        }
    }
}

// MARK: - Async Helpers

extension Sequence {
    /// Async compactMap that processes items concurrently
    func asyncCompactMap<T>(
        _ transform: @Sendable (Element) async throws -> T?
    ) async rethrows -> [T] {
        var results: [T] = []
        for element in self {
            if let transformed = try await transform(element) {
                results.append(transformed)
            }
        }
        return results
    }
}
