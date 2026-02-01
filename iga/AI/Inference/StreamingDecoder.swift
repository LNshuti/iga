// IGA/AI/Inference/StreamingDecoder.swift

import Foundation

/// Decodes Server-Sent Events (SSE) stream from OpenAI-compatible APIs
/// Handles the text/event-stream format with "data:" prefixed lines
actor StreamingDecoder {

    private var buffer: String = ""

    /// Process incoming data chunk and extract complete events
    /// - Parameter data: Raw data chunk from the stream
    /// - Returns: Array of parsed content strings from complete events
    func processChunk(_ data: Data) -> [String] {
        guard let chunk = String(data: data, encoding: .utf8) else {
            return []
        }

        buffer += chunk
        var results: [String] = []

        // Process complete lines (ending with \n)
        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[buffer.startIndex..<newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])

            if let content = parseLine(line) {
                results.append(content)
            }
        }

        return results
    }

    /// Parse a single SSE line
    /// - Parameter line: A complete line from the stream
    /// - Returns: Extracted content if the line contains a delta, nil otherwise
    private func parseLine(_ line: String) -> String? {
        // Skip empty lines and comments
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(":") else {
            return nil
        }

        // Check for stream termination
        if trimmed == "data: [DONE]" {
            return nil
        }

        // Extract JSON from "data: {...}" format
        guard trimmed.hasPrefix("data:") else {
            return nil
        }

        let jsonString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        guard !jsonString.isEmpty else {
            return nil
        }

        // Parse the JSON to extract delta content
        return parseStreamJSON(jsonString)
    }

    /// Parse OpenAI-compatible streaming JSON format
    /// - Parameter json: JSON string from the data field
    /// - Returns: The text content from the delta, if present
    private func parseStreamJSON(_ json: String) -> String? {
        guard let data = json.data(using: .utf8) else {
            return nil
        }

        do {
            let parsed = try JSONDecoder().decode(StreamChunk.self, from: data)
            return parsed.choices.first?.delta.content
        } catch {
            // Log parsing errors in debug mode
            #if DEBUG
            print("[StreamingDecoder] Failed to parse: \(json), error: \(error)")
            #endif
            return nil
        }
    }

    /// Reset the decoder state
    func reset() {
        buffer = ""
    }
}

// MARK: - Stream Response Types

/// OpenAI-compatible streaming chunk format
private struct StreamChunk: Decodable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [StreamChoice]
}

private struct StreamChoice: Decodable {
    let index: Int
    let delta: StreamDelta
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index
        case delta
        case finishReason = "finish_reason"
    }
}

private struct StreamDelta: Decodable {
    let role: String?
    let content: String?
}
