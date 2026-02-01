// IGA/Tests/AITests/InferenceClientTests.swift

import XCTest
@testable import IGA

final class InferenceClientTests: XCTestCase {

    // MARK: - Mock Client Tests

    func testMockClientGenerate() async throws {
        // Given
        let mockClient = MockInferenceClient()
        mockClient.mockResponse = "Test response for GRE question"

        let request = GenerationRequest(
            messages: [
                ChatMessage(role: .user, content: "What is 2 + 2?")
            ],
            maxTokens: 100,
            temperature: 0.7
        )

        // When
        let response = try await mockClient.generate(request: request)

        // Then
        XCTAssertEqual(response.content, "Test response for GRE question")
        XCTAssertEqual(response.finishReason, "stop")
        XCTAssertNotNil(response.usage)
    }

    func testMockClientStream() async throws {
        // Given
        let mockClient = MockInferenceClient()
        mockClient.mockResponse = "This is a streaming test"
        mockClient.streamDelay = .milliseconds(10)

        let request = GenerationRequest(
            messages: [
                ChatMessage(role: .user, content: "Stream test")
            ],
            stream: true
        )

        // When
        let stream = try await mockClient.stream(request: request)
        var tokens: [String] = []
        for try await token in stream {
            tokens.append(token)
        }

        // Then
        XCTAssertFalse(tokens.isEmpty)
        let fullResponse = tokens.joined()
        XCTAssertTrue(fullResponse.contains("This"))
        XCTAssertTrue(fullResponse.contains("streaming"))
    }

    func testMockClientEmbed() async throws {
        // Given
        let mockClient = MockInferenceClient()
        mockClient.mockEmbeddings = [[0.1, 0.2, 0.3, 0.4, 0.5]]

        let request = EmbeddingRequest(texts: ["ephemeral", "transient"])

        // When
        let response = try await mockClient.embed(request: request)

        // Then
        XCTAssertEqual(response.embeddings.count, 2)
        XCTAssertEqual(response.embeddings[0], [0.1, 0.2, 0.3, 0.4, 0.5])
    }

    func testMockClientFailure() async {
        // Given
        let mockClient = MockInferenceClient()
        mockClient.shouldFail = true
        mockClient.failureError = .networkUnavailable

        let request = GenerationRequest(
            messages: [ChatMessage(role: .user, content: "Test")]
        )

        // When/Then
        do {
            _ = try await mockClient.generate(request: request)
            XCTFail("Expected error to be thrown")
        } catch let error as InferenceError {
            XCTAssertEqual(error.localizedDescription, InferenceError.networkUnavailable.localizedDescription)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Request Construction Tests

    func testGenerationRequestDefaults() {
        // Given
        let messages = [ChatMessage(role: .user, content: "Hello")]

        // When
        let request = GenerationRequest(messages: messages)

        // Then
        XCTAssertEqual(request.messages.count, 1)
        XCTAssertEqual(request.temperature, 0.7)
        XCTAssertFalse(request.stream)
    }

    func testChatMessageEquality() {
        // Given
        let message1 = ChatMessage(role: .user, content: "Hello")
        let message2 = ChatMessage(role: .user, content: "Hello")
        let message3 = ChatMessage(role: .assistant, content: "Hello")

        // Then
        XCTAssertEqual(message1, message2)
        XCTAssertNotEqual(message1, message3)
    }

    // MARK: - Error Tests

    func testInferenceErrorDescriptions() {
        // Test that all errors have meaningful descriptions
        let errors: [InferenceError] = [
            .notConfigured,
            .networkUnavailable,
            .invalidURL,
            .invalidResponse,
            .httpError(statusCode: 500, message: "Server error"),
            .timeout,
            .cancelled,
            .rateLimited(retryAfter: 60),
            .serverError("Something went wrong")
        ]

        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testRetryableErrors() {
        XCTAssertTrue(InferenceError.timeout.isRetryable)
        XCTAssertTrue(InferenceError.networkUnavailable.isRetryable)
        XCTAssertTrue(InferenceError.serverError("Error").isRetryable)
        XCTAssertTrue(InferenceError.httpError(statusCode: 500, message: nil).isRetryable)
        XCTAssertTrue(InferenceError.httpError(statusCode: 429, message: nil).isRetryable)

        XCTAssertFalse(InferenceError.notConfigured.isRetryable)
        XCTAssertFalse(InferenceError.invalidURL.isRetryable)
        XCTAssertFalse(InferenceError.httpError(statusCode: 400, message: nil).isRetryable)
    }
}
