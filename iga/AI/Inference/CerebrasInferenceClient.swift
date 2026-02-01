// IGA/AI/Inference/CerebrasInferenceClient.swift

import Foundation

/// Concrete implementation of InferenceClient for Cerebras-backed API
/// Uses OpenAI-compatible JSON format with Bearer token authentication
final class CerebrasInferenceClient: InferenceClient, @unchecked Sendable {

    private let baseURL: URL
    private let apiKey: String
    private let textModel: String
    private let embeddingModel: String
    private let session: URLSession

    /// Initialize with configuration
    /// - Parameters:
    ///   - baseURL: API base URL (e.g., https://api.cerebras.ai/v1)
    ///   - apiKey: Bearer token for authentication
    ///   - textModel: Model ID for text generation
    ///   - embeddingModel: Model ID for embeddings
    ///   - session: URLSession to use (injectable for testing)
    init(
        baseURL: URL = AppConfig.cerebrasBaseURL,
        apiKey: String,
        textModel: String = AppConfig.textModelID,
        embeddingModel: String = AppConfig.embeddingModelID,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.textModel = textModel
        self.embeddingModel = embeddingModel
        self.session = session
    }

    /// Convenience initializer using AppConfig
    /// Returns nil if API key is not configured
    static func fromConfig() -> CerebrasInferenceClient? {
        guard let apiKey = AppConfig.cerebrasAPIKey else {
            return nil
        }
        return CerebrasInferenceClient(apiKey: apiKey)
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    // MARK: - Text Generation

    func generate(request: GenerationRequest) async throws -> GenerationResponse {
        let endpoint = baseURL.appendingPathComponent("chat/completions")
        var urlRequest = try buildRequest(for: endpoint)

        let body = ChatCompletionRequest(
            model: textModel,
            messages: request.messages.map { APIMessage(role: $0.role.rawValue, content: $0.content) },
            maxTokens: request.maxTokens,
            temperature: request.temperature,
            stream: false
        )

        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await performRequest(urlRequest)
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let choice = decoded.choices.first else {
            throw InferenceError.invalidResponse
        }

        return GenerationResponse(
            content: choice.message.content,
            finishReason: choice.finishReason,
            usage: decoded.usage
        )
    }

    // MARK: - Streaming Generation

    func stream(request: GenerationRequest) async throws -> AsyncThrowingStream<String, Error> {
        let endpoint = baseURL.appendingPathComponent("chat/completions")
        var urlRequest = try buildRequest(for: endpoint)

        let body = ChatCompletionRequest(
            model: textModel,
            messages: request.messages.map { APIMessage(role: $0.role.rawValue, content: $0.content) },
            maxTokens: request.maxTokens,
            temperature: request.temperature,
            stream: true
        )

        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await session.bytes(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InferenceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            // For error responses, read the body for error message
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            throw parseHTTPError(statusCode: httpResponse.statusCode, data: errorData)
        }

        let decoder = StreamingDecoder()

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        let tokens = await decoder.processChunk(Data((line + "\n").utf8))
                        for token in tokens {
                            continuation.yield(token)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Embeddings

    func embed(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        let endpoint = baseURL.appendingPathComponent("embeddings")
        var urlRequest = try buildRequest(for: endpoint)

        let body = EmbeddingAPIRequest(
            model: request.model ?? embeddingModel,
            input: request.texts
        )

        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await performRequest(urlRequest)
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(EmbeddingAPIResponse.self, from: data)
        let embeddings = decoded.data.sorted { $0.index < $1.index }.map { $0.embedding }

        return EmbeddingResponse(embeddings: embeddings)
    }

    // MARK: - Private Helpers

    private func buildRequest(for endpoint: URL) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = AppConfig.requestTimeout
        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 0..<AppConfig.maxRetryAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                return (data, response)
            } catch let error as URLError {
                lastError = error

                // Don't retry non-retryable errors
                guard error.code == .timedOut ||
                      error.code == .networkConnectionLost ||
                      error.code == .notConnectedToInternet else {
                    throw mapURLError(error)
                }

                // Exponential backoff
                if attempt < AppConfig.maxRetryAttempts - 1 {
                    let delay = AppConfig.retryBaseDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }

        throw lastError.map { mapURLError($0 as! URLError) } ?? InferenceError.unknown(NSError())
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InferenceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw parseHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    private func parseHTTPError(statusCode: Int, data: Data) -> InferenceError {
        // Try to parse error message from response
        let message: String?
        if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            message = errorResponse.error.message
        } else {
            message = String(data: data, encoding: .utf8)
        }

        switch statusCode {
        case 401:
            return .httpError(statusCode: statusCode, message: "Invalid API key")
        case 429:
            return .rateLimited(retryAfter: nil)
        case 500..<600:
            return .serverError(message ?? "Internal server error")
        default:
            return .httpError(statusCode: statusCode, message: message)
        }
    }

    private func mapURLError(_ error: URLError) -> InferenceError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .networkUnavailable
        case .timedOut:
            return .timeout
        case .cancelled:
            return .cancelled
        default:
            return .unknown(error)
        }
    }
}

// MARK: - API Request/Response Types

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [APIMessage]
    let maxTokens: Int
    let temperature: Double
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case stream
    }
}

private struct APIMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: TokenUsage?

    struct Choice: Decodable {
        let index: Int
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Decodable {
        let role: String
        let content: String
    }
}

private struct EmbeddingAPIRequest: Encodable {
    let model: String
    let input: [String]
}

private struct EmbeddingAPIResponse: Decodable {
    let object: String
    let data: [EmbeddingData]
    let model: String
    let usage: EmbeddingUsage

    struct EmbeddingData: Decodable {
        let object: String
        let embedding: [Double]
        let index: Int
    }

    struct EmbeddingUsage: Decodable {
        let promptTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

private struct APIErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
        let type: String?
        let code: String?
    }
}
