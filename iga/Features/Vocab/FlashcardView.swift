// IGA/Features/Vocab/FlashcardView.swift

import SwiftUI

// MARK: - Flashcard Review View

/// View for reviewing vocabulary with flashcards
struct FlashcardReviewView: View {
    @Bindable var session: VocabReviewSession
    let onComplete: () -> Void
    let onRecordQuality: (ReviewQuality) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar

            if session.isComplete {
                completionView
            } else if let word = session.currentWord {
                flashcardContent(word)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                Rectangle()
                    .fill(Theme.Colors.primaryFallback)
                    .frame(width: geometry.size.width * session.progress)
                    .animation(Theme.Animation.standard, value: session.progress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Flashcard Content

    private func flashcardContent(_ word: VocabWord) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            // Flashcard
            FlashcardFront(
                word: word,
                showingBack: session.showingAnswer
            )
            .onTapGesture {
                if !session.showingAnswer {
                    session.showAnswer()
                }
            }

            Spacer()

            // Action buttons
            if session.showingAnswer {
                qualityButtons
            } else {
                showAnswerButton
            }
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Show Answer Button

    private var showAnswerButton: some View {
        Button("Show Answer") {
            session.showAnswer()
        }
        .buttonStyle(PrimaryButtonStyle())
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quality Buttons

    private var qualityButtons: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("How well did you know it?")
                .font(Theme.Typography.callout)
                .foregroundColor(.secondary)

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ReviewQuality.allCases, id: \.rawValue) { quality in
                    qualityButton(quality)
                }
            }
        }
    }

    private func qualityButton(_ quality: ReviewQuality) -> some View {
        Button {
            onRecordQuality(quality)
        } label: {
            VStack(spacing: 4) {
                Text(quality.displayName)
                    .font(Theme.Typography.bodyBold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(qualityColor(quality).opacity(0.2))
            .foregroundColor(qualityColor(quality))
            .cornerRadius(Theme.CornerRadius.medium)
        }
    }

    private func qualityColor(_ quality: ReviewQuality) -> Color {
        switch quality {
        case .forgot: return Theme.Colors.error
        case .hard: return Theme.Colors.warning
        case .good: return Theme.Colors.success
        case .easy: return Theme.Colors.info
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.success)

            Text("Review Complete!")
                .font(Theme.Typography.title)

            Text("You've reviewed \(session.words.count) words")
                .font(Theme.Typography.body)
                .foregroundColor(.secondary)

            Spacer()

            Button("Done", action: onComplete)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
        }
        .padding(Theme.Spacing.lg)
    }
}

// MARK: - Flashcard Front

struct FlashcardFront: View {
    let word: VocabWord
    let showingBack: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if showingBack {
                // Back of card - show all info
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    // Word and POS
                    HStack(alignment: .firstTextBaseline) {
                        Text(word.headword)
                            .font(Theme.Typography.title)

                        Text(word.posAbbreviation)
                            .font(Theme.Typography.callout)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Definition
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Definition")
                            .font(Theme.Typography.caption)
                            .foregroundColor(.secondary)
                        Text(word.definition)
                            .font(Theme.Typography.body)
                    }

                    // Example
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Example")
                            .font(Theme.Typography.caption)
                            .foregroundColor(.secondary)
                        Text(word.example)
                            .font(Theme.Typography.callout)
                            .italic()
                    }

                    // Synonyms
                    if !word.synonyms.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Synonyms")
                                .font(Theme.Typography.caption)
                                .foregroundColor(.secondary)
                            Text(word.synonyms.joined(separator: ", "))
                                .font(Theme.Typography.callout)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Front of card - just the word
                VStack(spacing: Theme.Spacing.sm) {
                    Text(word.headword)
                        .font(.system(size: 36, weight: .bold))

                    Text(word.posAbbreviation)
                        .font(Theme.Typography.title3)
                        .foregroundColor(.secondary)

                    Spacer()
                        .frame(height: Theme.Spacing.lg)

                    Text("Tap to reveal")
                        .font(Theme.Typography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.xl)
        .themeShadow(Theme.Shadows.medium)
        .animation(Theme.Animation.standard, value: showingBack)
    }
}

// MARK: - Single Flashcard View

/// Standalone flashcard for a single word
struct SingleFlashcardView: View {
    let word: VocabWord
    @State private var isFlipped = false

    var body: some View {
        FlashcardFront(word: word, showingBack: isFlipped)
            .onTapGesture {
                withAnimation(Theme.Animation.standard) {
                    isFlipped.toggle()
                }
            }
    }
}

// MARK: - Preview

#Preview {
    let session = VocabReviewSession()

    return FlashcardReviewView(
        session: session,
        onComplete: {},
        onRecordQuality: { _ in }
    )
    .onAppear {
        session.loadWords(VocabWord.previewList)
    }
}
