// IGA/Features/Exam/ExamModeView.swift

import SwiftUI

// MARK: - Exam Mode View

/// Full-length GRE practice test with authentic timing
struct ExamModeView: View {
    @State private var viewModel = ExamModeViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch viewModel.state {
            case .setup:
                examSetupView
            case .inProgress:
                examInProgressView
            case .sectionBreak:
                sectionBreakView
            case .completed:
                examResultsView
            }
        }
        .navigationTitle(viewModel.state == .setup ? "Exam Mode" : "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.state != .setup)
    }

    // MARK: - Setup View

    private var examSetupView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Header
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.Colors.primary)

                    Text("Practice Test")
                        .font(Theme.Typography.title)

                    Text("Simulate real GRE conditions with timed sections and authentic question formats.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Theme.Spacing.xl)

                // Test format info
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Test Format")
                        .font(Theme.Typography.title3)

                    formatRow(icon: "clock", title: "Total Time", value: "~1 hour 15 min")
                    formatRow(icon: "function", title: "Quantitative", value: "2 sections × 21 min")
                    formatRow(icon: "text.book.closed", title: "Verbal", value: "2 sections × 18 min")
                    formatRow(icon: "number", title: "Questions", value: "~50 total")
                }
                .cardStyle()

                // Options
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Options")
                        .font(Theme.Typography.title3)

                    Toggle("Full-length test", isOn: $viewModel.isFullLength)

                    if !viewModel.isFullLength {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Quick Practice")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)

                            Picker("Section", selection: $viewModel.selectedSection) {
                                Text("Quant Only").tag(QuestionSection.quant)
                                Text("Verbal Only").tag(QuestionSection.verbal)
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    Toggle("Show timer", isOn: $viewModel.showTimer)
                    Toggle("Allow review within section", isOn: $viewModel.allowReview)
                }
                .cardStyle()

                // Tips
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Tips for Best Results")
                        .font(Theme.Typography.title3)

                    tipRow(icon: "bell.slash", text: "Silence notifications")
                    tipRow(icon: "clock.badge.checkmark", text: "Set aside uninterrupted time")
                    tipRow(icon: "pencil.and.paper", text: "Have scratch paper ready")
                    tipRow(icon: "brain", text: "Treat it like the real test")
                }
                .cardStyle()

                // Start button
                Button {
                    Task { await viewModel.startExam() }
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Practice Test")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, Theme.Spacing.md)
            }
            .padding(Theme.Spacing.md)
        }
    }

    private func formatRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(Theme.Colors.success)
                .frame(width: 24)
            Text(text)
                .font(Theme.Typography.body)
        }
    }

    // MARK: - In Progress View

    private var examInProgressView: some View {
        VStack(spacing: 0) {
            // Header bar
            examHeaderBar

            // Question content
            if let question = viewModel.currentQuestion {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Question stem
                        Text(question.stem)
                            .font(Theme.Typography.body)
                            .padding(Theme.Spacing.md)

                        // Answer choices
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                                ExamChoiceRow(
                                    letter: choiceLetter(index),
                                    text: choice,
                                    isSelected: viewModel.selectedAnswer == index,
                                    isFlagged: false
                                ) {
                                    viewModel.selectAnswer(index)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }

            // Navigation bar
            examNavigationBar
        }
    }

    private var examHeaderBar: some View {
        HStack {
            // Section info
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentSectionName)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                Text("Question \(viewModel.currentQuestionIndex + 1) of \(viewModel.totalQuestionsInSection)")
                    .font(Theme.Typography.bodyBold)
            }

            Spacer()

            // Timer
            if viewModel.showTimer {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "clock")
                    Text(viewModel.formattedTimeRemaining)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(viewModel.remainingSeconds < 60 ? Theme.Colors.error : .primary)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(Theme.CornerRadius.small)
            }

            // Flag button
            Button {
                viewModel.toggleFlag()
            } label: {
                Image(systemName: viewModel.isCurrentQuestionFlagged ? "flag.fill" : "flag")
                    .foregroundStyle(viewModel.isCurrentQuestionFlagged ? Theme.Colors.warning : .secondary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background)
    }

    private var examNavigationBar: some View {
        HStack {
            // Previous button
            Button {
                viewModel.previousQuestion()
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
            }
            .disabled(!viewModel.canGoPrevious)

            Spacer()

            // Question navigator
            Button {
                viewModel.showQuestionNavigator = true
            } label: {
                Text("Review")
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(Theme.CornerRadius.small)
            }

            Spacer()

            // Next/Submit button
            if viewModel.isLastQuestionInSection {
                Button {
                    viewModel.submitSection()
                } label: {
                    HStack {
                        Text("Submit Section")
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    viewModel.nextQuestion()
                } label: {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Theme.Colors.secondaryBackground),
            alignment: .top
        )
        .sheet(isPresented: $viewModel.showQuestionNavigator) {
            questionNavigatorSheet
        }
    }

    private var questionNavigatorSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: Theme.Spacing.sm) {
                    ForEach(0..<viewModel.totalQuestionsInSection, id: \.self) { index in
                        Button {
                            viewModel.goToQuestion(index)
                            viewModel.showQuestionNavigator = false
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                    .fill(questionCellColor(index))
                                    .frame(width: 44, height: 44)

                                Text("\(index + 1)")
                                    .font(Theme.Typography.bodyBold)
                                    .foregroundStyle(index == viewModel.currentQuestionIndex ? .white : .primary)

                                if viewModel.isFlagged(index) {
                                    Image(systemName: "flag.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.Colors.warning)
                                        .offset(x: 12, y: -12)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Question Navigator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.showQuestionNavigator = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func questionCellColor(_ index: Int) -> Color {
        if index == viewModel.currentQuestionIndex {
            return Theme.Colors.primary
        } else if viewModel.isAnswered(index) {
            return Theme.Colors.success.opacity(0.3)
        } else {
            return Theme.Colors.secondaryBackground
        }
    }

    private func choiceLetter(_ index: Int) -> String {
        ["A", "B", "C", "D", "E", "F"][index]
    }

    // MARK: - Section Break View

    private var sectionBreakView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.success)

            Text("Section Complete!")
                .font(Theme.Typography.title)

            Text("Take a short break before continuing to the next section.")
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Next: \(viewModel.nextSectionName)")
                    .font(Theme.Typography.bodyBold)
                Text("\(viewModel.nextSectionQuestionCount) questions • \(viewModel.nextSectionTimeMinutes) minutes")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.continueToNextSection()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
        .padding(Theme.Spacing.md)
    }

    // MARK: - Results View

    private var examResultsView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Header
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.Colors.success)

                    Text("Test Complete!")
                        .font(Theme.Typography.title)

                    Text("Great job completing the practice test.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Theme.Spacing.xl)

                // Score estimates
                if let results = viewModel.results {
                    VStack(spacing: Theme.Spacing.md) {
                        Text("Estimated Scores")
                            .font(Theme.Typography.title3)

                        HStack(spacing: Theme.Spacing.xl) {
                            scoreBox(
                                label: "Quant",
                                score: results.quantScore,
                                color: Theme.Colors.quant
                            )

                            scoreBox(
                                label: "Verbal",
                                score: results.verbalScore,
                                color: Theme.Colors.verbal
                            )

                            scoreBox(
                                label: "Total",
                                score: results.totalScore,
                                color: Theme.Colors.primary
                            )
                        }
                    }
                    .cardStyle()

                    // Performance breakdown
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Performance")
                            .font(Theme.Typography.title3)

                        performanceRow(
                            label: "Questions Attempted",
                            value: "\(results.questionsAttempted)"
                        )
                        performanceRow(
                            label: "Correct Answers",
                            value: "\(results.correctAnswers)"
                        )
                        performanceRow(
                            label: "Accuracy",
                            value: "\(results.accuracyPercentage)%"
                        )
                        performanceRow(
                            label: "Total Time",
                            value: results.formattedTotalTime
                        )
                        performanceRow(
                            label: "Avg Time/Question",
                            value: results.formattedAvgTime
                        )
                    }
                    .cardStyle()
                }

                // Actions
                VStack(spacing: Theme.Spacing.md) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        viewModel.reviewMistakes()
                    } label: {
                        Text("Review Mistakes")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.top, Theme.Spacing.md)
            }
            .padding(Theme.Spacing.md)
        }
    }

    private func scoreBox(label: String, score: Int, color: Color) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("\(score)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func performanceRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.bodyBold)
        }
    }
}

// MARK: - Exam Choice Row

struct ExamChoiceRow: View {
    let letter: String
    let text: String
    let isSelected: Bool
    let isFlagged: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                // Letter circle
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.Colors.primary : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 32, height: 32)

                    if isSelected {
                        Circle()
                            .fill(Theme.Colors.primary)
                            .frame(width: 24, height: 24)
                    }

                    Text(letter)
                        .font(Theme.Typography.bodyBold)
                        .foregroundStyle(isSelected ? .white : .primary)
                }

                // Choice text
                Text(text)
                    .font(Theme.Typography.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(Theme.Spacing.md)
            .background(isSelected ? Theme.Colors.primary.opacity(0.1) : Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ExamModeView()
    }
}
