// IGA/AI/Inference/InferenceError.swift

import Foundation

/// Errors that can occur during inference operations
enum InferenceError: LocalizedError {
    case notConfigured
    case networkUnavailable
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(underlying: Error)
    case streamingError(String)
    case timeout
    case cancelled
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI features are not configured. Please add your API key."
        case .networkUnavailable:
            return "No internet connection. AI features require network access."
        case .invalidURL:
            return "Invalid API endpoint configuration."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .httpError(let code, let message):
            if let msg = message {
                return "Server error (\(code)): \(msg)"
            }
            return "Server error: HTTP \(code)"
        case .decodingError(let error):
            return "Failed to process response: \(error.localizedDescription)"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        case .timeout:
            return "Request timed out. Please try again."
        case .cancelled:
            return "Request was cancelled."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Please wait \(Int(seconds)) seconds."
            }
            return "Rate limited. Please try again later."
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .timeout, .networkUnavailable, .serverError:
            return true
        case .rateLimited:
            return true
        case .httpError(let code, _):
            return code >= 500 || code == 429
        default:
            return false
        }
    }
}
