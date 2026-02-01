// IGA/Shared/Components/ChoiceRow.swift

import SwiftUI

// MARK: - Choice Row

/// A row displaying a single answer choice
struct ChoiceRow: View {
    let index: Int
    let text: String
    let isSelected: Bool
    let isCorrect: Bool?
    let showResult: Bool
    let onTap: () -> Void

    private var letter: String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return index < letters.count ? letters[index] : "\(index + 1)"
    }

    private var backgroundColor: Color {
        if showResult {
            if isCorrect == true {
                return Theme.Colors.correct.opacity(0.15)
            } else if isSelected && isCorrect == false {
                return Theme.Colors.incorrect.opacity(0.15)
            }
        }
        return isSelected ? Theme.Colors.selected.opacity(0.1) : Theme.Colors.unselected
    }

    private var borderColor: Color {
        if showResult {
            if isCorrect == true {
                return Theme.Colors.correct
            } else if isSelected && isCorrect == false {
                return Theme.Colors.incorrect
            }
        }
        return isSelected ? Theme.Colors.selected : Color.gray.opacity(0.3)
    }

    private var letterBackgroundColor: Color {
        if showResult {
            if isCorrect == true {
                return Theme.Colors.correct
            } else if isSelected && isCorrect == false {
                return Theme.Colors.incorrect
            }
        }
        return isSelected ? Theme.Colors.selected : Color.gray.opacity(0.3)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                // Letter indicator
                Text(letter)
                    .font(Theme.Typography.bodyBold)
                    .foregroundColor(isSelected || showResult ? .white : .primary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(letterBackgroundColor)
                    )

                // Choice text
                Text(text)
                    .font(Theme.Typography.choiceText)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Result indicator
                if showResult {
                    if isCorrect == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.Colors.correct)
                    } else if isSelected && isCorrect == false {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.incorrect)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(backgroundColor)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choice \(letter): \(text)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(showResult && isCorrect == true ? "Correct answer" : "")
    }
}

// MARK: - Choice List

/// A list of all choices for a question
struct ChoiceList: View {
    let choices: [String]
    @Binding var selectedIndex: Int?
    let correctIndex: Int?
    let showResult: Bool
    let isEnabled: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                ChoiceRow(
                    index: index,
                    text: choice,
                    isSelected: selectedIndex == index,
                    isCorrect: correctIndex == index ? true : (selectedIndex == index ? false : nil),
                    showResult: showResult,
                    onTap: {
                        if isEnabled {
                            withAnimation(Theme.Animation.quick) {
                                selectedIndex = index
                            }
                        }
                    }
                )
                .disabled(!isEnabled)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Unanswered state
        ChoiceRow(
            index: 0,
            text: "The first answer choice",
            isSelected: false,
            isCorrect: nil,
            showResult: false,
            onTap: {}
        )

        // Selected state
        ChoiceRow(
            index: 1,
            text: "The selected answer choice",
            isSelected: true,
            isCorrect: nil,
            showResult: false,
            onTap: {}
        )

        // Correct answer revealed
        ChoiceRow(
            index: 2,
            text: "The correct answer",
            isSelected: false,
            isCorrect: true,
            showResult: true,
            onTap: {}
        )

        // Wrong answer selected
        ChoiceRow(
            index: 3,
            text: "Wrong answer selected",
            isSelected: true,
            isCorrect: false,
            showResult: true,
            onTap: {}
        )
    }
    .padding()
}
