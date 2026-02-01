// IGA/Features/Practice/QuestionView.swift

import SwiftUI

// MARK: - Question View

/// Standalone view for displaying a single question
struct QuestionView: View {
    let question: Question
    @Binding var selectedIndex: Int?
    let showResult: Bool
    let onSubmit: () -> Void
    let onAskTutor: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Header with section and difficulty
            HStack {
                SectionBadge(section: question.section)

                Spacer()

                DifficultyBadge(difficulty: question.difficulty)
            }

            // Question stem
            Text(question.stem)
                .font(Theme.Typography.questionStem)
                .fixedSize(horizontal: false, vertical: true)

            // Topics (optional display)
            if !question.topics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(question.topics, id: \.self) { topic in
                            Text(topic.replacingOccurrences(of: "-", with: " ").capitalized)
                                .font(Theme.Typography.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, Theme.Spacing.xxs)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(Theme.CornerRadius.pill)
                        }
                    }
                }
            }

            // Answer choices
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    ChoiceRow(
                        index: index,
                        text: choice,
                        isSelected: selectedIndex == index,
                        isCorrect: showResult ? question.correctIndex == index : nil,
                        showResult: showResult,
                        onTap: {
                            if !showResult {
                                selectedIndex = index
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Section Badge

struct SectionBadge: View {
    let section: QuestionSection

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: section.icon)
            Text(section.displayName)
        }
        .font(Theme.Typography.caption)
        .foregroundColor(Theme.Colors.sectionColor(section))
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Colors.sectionColor(section).opacity(0.1))
        .cornerRadius(Theme.CornerRadius.small)
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: Int

    private var label: String {
        switch difficulty {
        case 1: return "Easy"
        case 2: return "Medium-Easy"
        case 3: return "Medium"
        case 4: return "Medium-Hard"
        case 5: return "Hard"
        default: return "Unknown"
        }
    }

    private var color: Color {
        switch difficulty {
        case 1: return .green
        case 2: return .teal
        case 3: return .blue
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= difficulty ? color : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
            Text(label)
                .font(Theme.Typography.caption)
        }
        .foregroundColor(color)
    }
}

// MARK: - Question Card

/// Card-style container for a question
struct QuestionCard: View {
    let question: Question
    @Binding var selectedIndex: Int?
    let showResult: Bool

    var body: some View {
        QuestionView(
            question: question,
            selectedIndex: $selectedIndex,
            showResult: showResult,
            onSubmit: {},
            onAskTutor: {}
        )
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background)
        .cornerRadius(Theme.CornerRadius.large)
        .themeShadow(Theme.Shadows.medium)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            QuestionView(
                question: .preview,
                selectedIndex: .constant(nil),
                showResult: false,
                onSubmit: {},
                onAskTutor: {}
            )

            QuestionView(
                question: .preview,
                selectedIndex: .constant(2),
                showResult: true,
                onSubmit: {},
                onAskTutor: {}
            )
        }
        .padding()
    }
}
