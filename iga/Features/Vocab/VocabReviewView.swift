// IGA/Features/Vocab/VocabReviewView.swift

import SwiftUI

// MARK: - Vocab Review View

/// Enhanced flashcard-style vocabulary review interface
struct VocabReviewView: View {
    @Bindable var session: VocabReviewSession
    let onComplete: () -> Void

    @State private var cardOffset: CGFloat = 0
    @State private var cardRotation: Double = 0
    @State private var showHint = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressHeader

            if session.isComplete {
                sessionCompleteView
            } else if let word = session.currentWord {
                // Flashcard
                flashcardView(word)

                Spacer()

                // Answer buttons
                if session.showingAnswer {
                    qualityButtons
                } else {
                    showAnswerButton
                }
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: Theme.Spacing.xs) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(height: 4)

                    Rectangle()
                        .fill(Theme.Colors.primary)
                        .frame(width: geometry.size.width * session.progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: session.progress)
                }
            }
            .frame(height: 4)

            // Stats
            HStack {
                Text("\(session.currentIndex + 1) of \(session.words.count)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let word = session.currentWord {
                    LearningStatusBadge(status: word.learningStatus)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Flashcard View

    private func flashcardView(_ word: VocabWord) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            // Card
            VStack(spacing: Theme.Spacing.xl) {
                // Word
                Text(word.headword)
                    .font(.system(size: 36, weight: .bold, design: .serif))

                Text(word.posAbbreviation)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(Theme.CornerRadius.small)

                if session.showingAnswer {
                    Divider()
                        .padding(.horizontal, Theme.Spacing.xl)

                    // Definition
                    Text(word.definition)
                        .font(Theme.Typography.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Example
                    Text("\"\(word.example)\"")
                        .font(Theme.Typography.body)
                        .italic()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Synonyms
                    if !word.synonyms.isEmpty {
                        HStack {
                            Text("Synonyms:")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                            Text(word.synonyms.prefix(4).joined(separator: ", "))
                                .font(Theme.Typography.caption)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.background)
            .cornerRadius(Theme.CornerRadius.large)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal, Theme.Spacing.lg)
            .offset(x: cardOffset)
            .rotationEffect(.degrees(cardRotation))

            // Retrievability indicator
            if let lastReviewed = word.lastReviewed {
                RetrievabilityIndicator(
                    retrievability: word.retrievability,
                    lastReviewed: lastReviewed,
                    stability: word.stability
                )
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !session.showingAnswer {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    session.showAnswer()
                }
            }
        }
    }

    // MARK: - Show Answer Button

    private var showAnswerButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                session.showAnswer()
            }
        } label: {
            Text("Show Answer")
                .font(Theme.Typography.bodyBold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.Colors.primary)
                .foregroundStyle(.white)
                .cornerRadius(Theme.CornerRadius.medium)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.lg)
    }

    // MARK: - Quality Buttons

    private var qualityButtons: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("How well did you remember?")
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: Theme.Spacing.sm) {
                qualityButton(.forgot, color: Theme.Colors.error)
                qualityButton(.hard, color: Theme.Colors.warning)
                qualityButton(.good, color: Theme.Colors.success)
                qualityButton(.easy, color: Theme.Colors.info)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.lg)
    }

    private func qualityButton(_ quality: ReviewQuality, color: Color) -> some View {
        Button {
            Task {
                await session.recordQuality(quality)
            }
        } label: {
            VStack(spacing: 4) {
                Text(quality.displayName)
                    .font(Theme.Typography.bodyBold)

                if let word = session.currentWord {
                    let nextInterval = estimateNextInterval(word: word, quality: quality)
                    Text(nextInterval)
                        .font(Theme.Typography.caption)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .cornerRadius(Theme.CornerRadius.medium)
        }
    }

    private func estimateNextInterval(word: VocabWord, quality: ReviewQuality) -> String {
        // Rough estimate of next interval
        let isCorrect = quality.rawValue >= 2
        if !isCorrect {
            return quality == .forgot ? "1h" : "4h"
        }

        let currentStability = max(0.5, word.stability)
        let multiplier: Double
        switch quality {
        case .easy: multiplier = 3.5
        case .good: multiplier = 2.5
        case .hard: multiplier = 1.3
        case .forgot: multiplier = 0.2
        }

        let newStability = word.stability == 0
            ? (quality == .easy ? 4.0 : 1.0)
            : currentStability * multiplier

        let days = newStability * 0.9
        if days < 1 {
            return "\(Int(days * 24))h"
        } else if days < 30 {
            return "\(Int(days))d"
        } else {
            return "\(Int(days / 30))mo"
        }
    }

    // MARK: - Session Complete View

    private var sessionCompleteView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.Colors.success)

            Text("Review Complete!")
                .font(Theme.Typography.title)

            Text("You reviewed \(session.words.count) words")
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Done") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
        }
    }
}

// MARK: - Learning Status Badge

struct LearningStatusBadge: View {
    let status: VocabLearningStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption)
            Text(status.rawValue)
                .font(Theme.Typography.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .foregroundStyle(statusColor)
        .cornerRadius(Theme.CornerRadius.small)
    }

    private var statusColor: Color {
        switch status {
        case .new: return .gray
        case .learning: return Theme.Colors.info
        case .relearning: return Theme.Colors.warning
        case .mastered: return Theme.Colors.success
        }
    }
}

// MARK: - Retrievability Indicator

struct RetrievabilityIndicator: View {
    let retrievability: Double
    let lastReviewed: Date
    let stability: Double

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            // Retrievability bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    Rectangle()
                        .fill(retrievabilityColor)
                        .frame(width: geometry.size.width * min(retrievability, 1.0))
                }
                .cornerRadius(2)
            }
            .frame(height: 6)
            .frame(width: 150)

            HStack(spacing: Theme.Spacing.sm) {
                Text("\(Int(retrievability * 100))% retention")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)

                Text("·")
                    .foregroundStyle(.tertiary)

                Text(lastReviewedText)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var retrievabilityColor: Color {
        if retrievability >= 0.9 {
            return Theme.Colors.success
        } else if retrievability >= 0.7 {
            return Theme.Colors.info
        } else if retrievability >= 0.5 {
            return Theme.Colors.warning
        } else {
            return Theme.Colors.error
        }
    }

    private var lastReviewedText: String {
        let interval = Date().timeIntervalSince(lastReviewed)
        let hours = Int(interval / 3600)

        if hours < 1 {
            return "Just now"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else {
            let days = hours / 24
            return "\(days)d ago"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VocabReviewView(
            session: {
                let session = VocabReviewSession()
                session.loadWords(VocabWord.previewList)
                return session
            }(),
            onComplete: {}
        )
    }
}
