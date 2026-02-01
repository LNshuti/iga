// IGA/Config/AppConfig.swift

import Foundation

/// Centralized configuration loaded from build settings and Info.plist
/// Never hardcode secrets; always load from environment or xcconfig
enum AppConfig {

    // MARK: - API Configuration

    /// Base URL for Cerebras inference API
    /// Hardcoded since this is not a secret and xcconfig URL escaping is problematic
    static let cerebrasBaseURL: URL = URL(string: "https://api.cerebras.ai/v1")!

    /// API key for Cerebras authentication
    /// Returns nil if not configured, allowing graceful degradation
    static var cerebrasAPIKey: String? {
        guard let key = Bundle.main.infoDictionary?["CEREBRAS_API_KEY"] as? String,
              !key.isEmpty else {
            return ProcessInfo.processInfo.environment["CEREBRAS_API_KEY"]
        }
        return key
    }

    /// Model ID for text generation (chat, explanations)
    static var textModelID: String {
        Bundle.main.infoDictionary?["TEXT_MODEL_ID"] as? String ?? "llama3.1-70b"
    }

    /// Model ID for embeddings (vocabulary similarity)
    static var embeddingModelID: String {
        Bundle.main.infoDictionary?["EMBEDDING_MODEL_ID"] as? String ?? "text-embedding"
    }

    /// Optional reranker model ID
    static var rerankerModelID: String? {
        let id = Bundle.main.infoDictionary?["RERANKER_MODEL_ID"] as? String
        return id?.isEmpty == false ? id : nil
    }

    // MARK: - Feature Flags

    /// Whether AI features are available (API key configured)
    static var isAIEnabled: Bool {
        cerebrasAPIKey != nil
    }

    /// Debug mode for additional logging
    static var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Timeouts and Limits

    /// HTTP request timeout in seconds
    static let requestTimeout: TimeInterval = 30

    /// Maximum tokens for generated responses
    static let maxGenerationTokens: Int = 1024

    /// Maximum tokens for explanation responses
    static let maxExplanationTokens: Int = 512

    /// Retry attempts for transient failures
    static let maxRetryAttempts: Int = 3

    /// Base delay for exponential backoff (seconds)
    static let retryBaseDelay: TimeInterval = 1.0

    // MARK: - Practice Settings

    /// Default time per question in seconds (timed mode)
    static let defaultQuestionTimeLimit: Int = 90

    /// Questions per practice session
    static let questionsPerSession: Int = 10

    // MARK: - Spaced Repetition

    /// Minimum interval between reviews (hours)
    static let minReviewInterval: TimeInterval = 4 * 3600

    /// Maximum interval between reviews (days)
    static let maxReviewInterval: TimeInterval = 30 * 24 * 3600
}

// MARK: - Bundle Extension for Config Access

extension Bundle {
    /// Safely retrieve a configuration value from Info.plist
    func configValue(forKey key: String) -> String? {
        infoDictionary?[key] as? String
    }
}
