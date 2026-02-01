// IGA/AI/Inference/InferenceClient.swift

import Foundation

// MARK: - Request/Response Types

/// A message in a conversation
struct ChatMessage: Codable, Equatable, Sendable {
    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }

    let role: Role
    let content: String

    init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

/// Request for text generation
struct GenerationRequest: Sendable {
    let messages: [ChatMessage]
    let maxTokens: Int
    let temperature: Double
    let stream: Bool

    init(
        messages: [ChatMessage],
        maxTokens: Int = AppConfig.maxGenerationTokens,
        temperature: Double = 0.7,
        stream: Bool = false
    ) {
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.stream = stream
    }
}

/// Response from text generation
struct GenerationResponse: Sendable {
    let content: String
    let finishReason: String?
    let usage: TokenUsage?
}

/// Token usage statistics
struct TokenUsage: Codable, Sendable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

/// Request for embeddings
struct EmbeddingRequest: Sendable {
    let texts: [String]
    let model: String?

    init(texts: [String], model: String? = nil) {
        self.texts = texts
        self.model = model
    }
}

/// Response containing embeddings
struct EmbeddingResponse: Sendable {
    let embeddings: [[Double]]
}

// MARK: - Inference Client Protocol

/// Protocol for AI inference operations
/// Implement this protocol to support different inference backends
protocol InferenceClient: Sendable {

    /// Generate a text response (non-streaming)
    /// - Parameter request: The generation request with messages and parameters
    /// - Returns: The generated text response
    func generate(request: GenerationRequest) async throws -> GenerationResponse

    /// Generate a streaming text response
    /// - Parameter request: The generation request (stream flag will be set to true)
    /// - Returns: An async stream of text tokens
    func stream(request: GenerationRequest) async throws -> AsyncThrowingStream<String, Error>

    /// Generate embeddings for texts
    /// - Parameter request: The embedding request with texts
    /// - Returns: Array of embedding vectors
    func embed(request: EmbeddingRequest) async throws -> EmbeddingResponse

    /// Check if the client is properly configured and ready
    var isConfigured: Bool { get }
}

// MARK: - Mock Client for Testing/Preview

/// A mock inference client for testing and SwiftUI previews
final class MockInferenceClient: InferenceClient, @unchecked Sendable {
    var isConfigured: Bool = true
    var mockResponse: String = "This is a mock response for testing."
    var mockEmbeddings: [[Double]] = [[0.1, 0.2, 0.3]]
    var shouldFail: Bool = false
    var failureError: InferenceError = .serverError("Mock error")
    var streamDelay: Duration = .milliseconds(50)

    func generate(request: GenerationRequest) async throws -> GenerationResponse {
        if shouldFail { throw failureError }
        try await Task.sleep(for: .milliseconds(100))
        return GenerationResponse(
            content: mockResponse,
            finishReason: "stop",
            usage: TokenUsage(promptTokens: 10, completionTokens: 20, totalTokens: 30)
        )
    }

    func stream(request: GenerationRequest) async throws -> AsyncThrowingStream<String, Error> {
        if shouldFail { throw failureError }

        let words = mockResponse.split(separator: " ").map(String.init)
        let delay = streamDelay

        return AsyncThrowingStream { continuation in
            Task {
                for word in words {
                    try await Task.sleep(for: delay)
                    continuation.yield(word + " ")
                }
                continuation.finish()
            }
        }
    }

    func embed(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        if shouldFail { throw failureError }
        // Return mock embeddings matching input count
        let embeddings = request.texts.map { _ in mockEmbeddings[0] }
        return EmbeddingResponse(embeddings: embeddings)
    }
}
