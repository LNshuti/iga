// IGA/Data/Models/Message.swift

import Foundation
import SwiftData

// MARK: - Chat Message for Tutor

/// Represents a message in the tutor chat conversation
@Model
final class TutorMessage {
    /// Unique identifier
    @Attribute(.unique) var id: String

    /// Message role (user or assistant)
    var roleRaw: String

    /// Message content
    var content: String

    /// When the message was created
    var timestamp: Date

    /// Whether this message is currently being streamed
    @Transient var isStreaming: Bool = false

    /// Associated question ID (if discussing a specific question)
    var relatedQuestionId: String?

    var role: ChatMessage.Role {
        get { ChatMessage.Role(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        role: ChatMessage.Role,
        content: String,
        timestamp: Date = Date(),
        relatedQuestionId: String? = nil
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.content = content
        self.timestamp = timestamp
        self.relatedQuestionId = relatedQuestionId
    }

    /// Convert to ChatMessage for API requests
    func toChatMessage() -> ChatMessage {
        ChatMessage(role: role, content: content)
    }
}

// MARK: - Display Message

/// A lightweight message representation for display
struct DisplayMessage: Identifiable, Equatable {
    let id: String
    let role: ChatMessage.Role
    var content: String
    let timestamp: Date
    var isStreaming: Bool

    init(
        id: String = UUID().uuidString,
        role: ChatMessage.Role,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }

    /// Whether this is a user message
    var isUser: Bool {
        role == .user
    }

    /// Whether this is an assistant message
    var isAssistant: Bool {
        role == .assistant
    }

    /// Formatted time string
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    /// Convert to ChatMessage for API
    func toChatMessage() -> ChatMessage {
        ChatMessage(role: role, content: content)
    }
}

// MARK: - Conversation

/// A collection of messages forming a conversation
struct Conversation: Identifiable {
    let id: String
    var messages: [DisplayMessage]
    var title: String?
    let createdAt: Date
    var lastMessageAt: Date

    init(
        id: String = UUID().uuidString,
        messages: [DisplayMessage] = [],
        title: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.messages = messages
        self.title = title
        self.createdAt = createdAt
        self.lastMessageAt = messages.last?.timestamp ?? createdAt
    }

    /// Add a new message to the conversation
    mutating func addMessage(_ message: DisplayMessage) {
        messages.append(message)
        lastMessageAt = message.timestamp
    }

    /// Get messages as ChatMessage array for API
    func toChatMessages() -> [ChatMessage] {
        messages.map { $0.toChatMessage() }
    }

    /// Generate a title from the first user message
    mutating func generateTitle() {
        guard title == nil,
              let firstUserMessage = messages.first(where: { $0.isUser }) else {
            return
        }
        // Take first 50 characters of the first user message
        let text = firstUserMessage.content
        title = String(text.prefix(50)) + (text.count > 50 ? "..." : "")
    }
}

// MARK: - Preview Data

extension DisplayMessage {
    static var previewUser: DisplayMessage {
        DisplayMessage(
            id: "preview-user-1",
            role: .user,
            content: "Can you help me understand how to solve systems of linear equations?",
            timestamp: Date().addingTimeInterval(-120)
        )
    }

    static var previewAssistant: DisplayMessage {
        DisplayMessage(
            id: "preview-assistant-1",
            role: .assistant,
            content: """
            Of course! Systems of linear equations can be solved using several methods. Let me walk you through the main approaches:

            **1. Substitution Method**
            - Solve one equation for one variable
            - Substitute into the other equation
            - Solve for the remaining variable

            **2. Elimination Method**
            - Multiply equations to match coefficients
            - Add or subtract to eliminate a variable
            - Solve for the remaining variable

            Which method would you like to explore first? Or would you prefer to see an example problem?
            """,
            timestamp: Date().addingTimeInterval(-60)
        )
    }

    static var previewList: [DisplayMessage] {
        [previewUser, previewAssistant]
    }
}
