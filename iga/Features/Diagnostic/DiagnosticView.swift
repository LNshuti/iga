// IGA/Features/Diagnostic/DiagnosticView.swift

import SwiftUI

// MARK: - Diagnostic View

/// Main view for the diagnostic assessment
struct DiagnosticView: View {
    @Bindable var viewModel: DiagnosticViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .notStarted:
                    welcomeView

                case .inProgress(let questionNumber, let totalEstimated):
                    questionView(questionNumber: questionNumber, total: totalEstimated)

                case .completed(let result):
                    DiagnosticResultView(result: result) {
                        dismiss()
                    }

                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Diagnostic Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .inProgress = viewModel.state {
                        Button("Cancel") {
                            viewModel.cancelDiagnostic()
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundStyle(Theme.Colors.primary)

            VStack(spacing: Theme.Spacing.md) {
                Text("Diagnostic Assessment")
                    .font(Theme.Typography.title)

                Text("This adaptive assessment will measure your current abilities across all GRE subskills to create a personalized study plan.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                featureRow(icon: "clock", text: "Takes about 25-35 minutes")
                featureRow(icon: "chart.bar", text: "Adapts to your level")
                featureRow(icon: "target", text: "Identifies your strengths and gaps")
                featureRow(icon: "list.bullet.clipboard", text: "Generates personalized recommendations")
            }
            .padding()
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.large)

            Spacer()

            Button {
                Task {
                    await viewModel.startDiagnostic()
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Begin Assessment")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading)
        }
        .padding()
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 24)

            Text(text)
                .font(Theme.Typography.body)
        }
    }

    // MARK: - Question View

    private func questionView(questionNumber: Int, total: Int) -> some View {
        VStack(spacing: 0) {
            // Progress bar
            VStack(spacing: Theme.Spacing.xs) {
                ProgressView(value: viewModel.progressPercentage)
                    .tint(Theme.Colors.primary)

                HStack {
                    Text("Question \(questionNumber)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(viewModel.currentSectionName)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.primary)
                }
            }
            .padding()

            Divider()

            // Question content
            if let question = viewModel.currentQuestion {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Stem
                        Text(question.stem)
                            .font(Theme.Typography.questionStem)
                            .padding(.horizontal)

                        // Choices
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(question.choices.indices, id: \.self) { index in
                                choiceButton(
                                    text: question.choices[index],
                                    index: index,
                                    isSelected: viewModel.selectedAnswer == index,
                                    isCorrect: viewModel.showFeedback ? question.isCorrect(index) : nil,
                                    showFeedback: viewModel.showFeedback
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }

                // Actions
                VStack(spacing: Theme.Spacing.md) {
                    Divider()

                    HStack(spacing: Theme.Spacing.md) {
                        Button("Skip") {
                            Task {
                                await viewModel.skipQuestion()
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Submit") {
                            Task {
                                await viewModel.submitAnswer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.selectedAnswer == nil || viewModel.showFeedback)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            } else {
                Spacer()
                ProgressView("Loading question...")
                Spacer()
            }
        }
    }

    private func choiceButton(
        text: String,
        index: Int,
        isSelected: Bool,
        isCorrect: Bool?,
        showFeedback: Bool
    ) -> some View {
        Button {
            if !showFeedback {
                viewModel.selectAnswer(index)
            }
        } label: {
            HStack {
                Text(choiceLetter(for: index))
                    .font(Theme.Typography.bodyBold)
                    .frame(width: 28, height: 28)
                    .background(choiceLetterBackground(isSelected: isSelected, isCorrect: isCorrect))
                    .cornerRadius(14)

                Text(text)
                    .font(Theme.Typography.choiceText)
                    .multilineTextAlignment(.leading)

                Spacer()

                if showFeedback {
                    if isCorrect == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.success)
                    } else if isSelected && isCorrect == false {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.Colors.error)
                    }
                }
            }
            .padding()
            .background(choiceBackground(isSelected: isSelected, isCorrect: isCorrect))
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(choiceBorder(isSelected: isSelected, isCorrect: isCorrect), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(showFeedback)
    }

    private func choiceLetter(for index: Int) -> String {
        String(UnicodeScalar(65 + index)!)  // A, B, C, D, E
    }

    private func choiceLetterBackground(isSelected: Bool, isCorrect: Bool?) -> Color {
        if let correct = isCorrect {
            return correct ? Theme.Colors.success : (isSelected ? Theme.Colors.error : Color.clear)
        }
        return isSelected ? Theme.Colors.primary : Color.clear
    }

    private func choiceBackground(isSelected: Bool, isCorrect: Bool?) -> Color {
        if let correct = isCorrect {
            return correct ? Theme.Colors.success.opacity(0.1) :
                   (isSelected ? Theme.Colors.error.opacity(0.1) : Theme.Colors.secondaryBackground)
        }
        return isSelected ? Theme.Colors.primary.opacity(0.1) : Theme.Colors.secondaryBackground
    }

    private func choiceBorder(isSelected: Bool, isCorrect: Bool?) -> Color {
        if let correct = isCorrect {
            return correct ? Theme.Colors.success : (isSelected ? Theme.Colors.error : Color.clear)
        }
        return isSelected ? Theme.Colors.primary : Color.clear
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.error)

            Text("Something went wrong")
                .font(Theme.Typography.title2)

            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await viewModel.startDiagnostic()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    DiagnosticView(viewModel: DiagnosticViewModel.preview)
}
