// IGA/Features/TutorChat/TutorChatView.swift

import SwiftUI

// MARK: - Tutor Chat View

/// Main view for the GRE tutor chat interface
struct TutorChatView: View {
    @State private var viewModel: TutorChatViewModel

    init(viewModel: TutorChatViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    @MainActor
    init() {
        _viewModel = State(initialValue: TutorChatViewModel())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                messagesList

                // Error banner if present
                if let error = viewModel.error {
                    ErrorBanner(
                        message: error.localizedDescription,
                        retryAction: { Task { await viewModel.retryLastMessage() } },
                        dismissAction: { viewModel.dismissError() }
                    )
                    .padding(Theme.Spacing.md)
                }

                // Input area
                inputArea
            }
            .navigationTitle("GRE Tutor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.startNewConversation()
                    } label: {
                        Image(systemName: "plus.message")
                    }
                }
            }
        }
        .task {
            await viewModel.loadHistory()
        }
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Ask your tutor...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.sm)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(Theme.CornerRadius.large)
                .disabled(viewModel.isStreaming)

            Button {
                Task {
                    await viewModel.sendMessage()
                }
            } label: {
                Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(
                        viewModel.inputText.isEmpty && !viewModel.isStreaming
                            ? .gray
                            : Theme.Colors.primaryFallback
                    )
            }
            .disabled(viewModel.inputText.isEmpty && !viewModel.isStreaming)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background)
    }
}

// MARK: - Message Bubble

/// Individual message bubble in the chat
struct MessageBubble: View {
    let message: DisplayMessage

    private var alignment: Alignment {
        message.isUser ? .trailing : .leading
    }

    private var backgroundColor: Color {
        message.isUser ? Theme.Colors.userBubble : Theme.Colors.assistantBubble
    }

    private var textColor: Color {
        message.isUser ? .white : .primary
    }

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 50) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                // Message content
                HStack {
                    if message.isStreaming && message.content.isEmpty {
                        StreamingIndicator()
                    } else {
                        Text(message.content)
                            .font(Theme.Typography.messageText)
                            .foregroundColor(textColor)
                            .textSelection(.enabled)
                    }

                    if message.isStreaming && !message.content.isEmpty {
                        StreamingIndicator()
                            .padding(.leading, 4)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(backgroundColor)
                .cornerRadius(Theme.CornerRadius.large)

                // Timestamp
                Text(message.timeString)
                    .font(Theme.Typography.timestamp)
                    .foregroundColor(.secondary)
            }

            if !message.isUser { Spacer(minLength: 50) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.isUser ? "You" : "Tutor"): \(message.content)")
    }
}

// MARK: - Question Context Banner

/// Shows when discussing a specific question
struct QuestionContextBanner: View {
    let question: Question
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Discussing:")
                    .font(Theme.Typography.caption)
                    .foregroundColor(.secondary)

                Text(question.stem.prefix(50) + (question.stem.count > 50 ? "..." : ""))
                    .font(Theme.Typography.callout)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.secondaryBackground)
    }
}

// MARK: - Preview

#Preview {
    TutorChatView(viewModel: .preview)
}
