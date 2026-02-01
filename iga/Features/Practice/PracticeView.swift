// IGA/Features/Practice/PracticeView.swift

import SwiftUI

// MARK: - Practice View

/// Main view for GRE practice sessions
struct PracticeView: View {
    @State private var viewModel: PracticeViewModel
    private let subskillFilter: String?
    private let autoStart: Bool

    init(viewModel: PracticeViewModel) {
        _viewModel = State(initialValue: viewModel)
        self.subskillFilter = nil
        self.autoStart = false
    }

    @MainActor
    init() {
        _viewModel = State(initialValue: PracticeViewModel())
        self.subskillFilter = nil
        self.autoStart = false
    }

    /// Initialize with a specific subskill to practice
    @MainActor
    init(subskillFilter: String) {
        let vm = PracticeViewModel()
        vm.subskillFilter = subskillFilter
        _viewModel = State(initialValue: vm)
        self.subskillFilter = subskillFilter
        self.autoStart = true
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSessionComplete {
                    SessionCompleteView(
                        stats: viewModel.sessionStats,
                        onRestart: { Task { await viewModel.startSession() } },
                        onExit: {}
                    )
                } else if let question = viewModel.currentQuestion {
                    questionView(question)
                } else {
                    sessionSetupView
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            if autoStart {
                await viewModel.startSession()
            }
        }
    }

    private var navigationTitle: String {
        if let filter = subskillFilter,
           let subskill = Subskill(rawValue: filter) {
            return "Practice: \(subskill.shortName)"
        }
        return "Practice"
    }

    // MARK: - Session Setup

    private var sessionSetupView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.primaryFallback)

            Text("Ready to Practice?")
                .font(Theme.Typography.title)

            Text("Choose your practice mode and start improving your GRE score.")
                .font(Theme.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Mode selection
            VStack(spacing: Theme.Spacing.md) {
                modeButton(mode: .untimed, icon: "infinity", title: "Untimed Practice", description: "Take your time to think through each question")

                modeButton(mode: .timed, icon: "timer", title: "Timed Practice", description: "90 seconds per question, like the real GRE")
            }
            .padding(.horizontal)

            Spacer()

            Button("Start Practice") {
                Task { await viewModel.startSession() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
        }
        .padding()
    }

    private func modeButton(mode: SessionMode, icon: String, title: String, description: String) -> some View {
        Button {
            viewModel.mode = mode
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.bodyBold)
                    Text(description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.mode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.primaryFallback)
                }
            }
            .padding(Theme.Spacing.md)
            .background(
                viewModel.mode == mode
                    ? Theme.Colors.primaryFallback.opacity(0.1)
                    : Theme.Colors.secondaryBackground
            )
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(
                        viewModel.mode == mode ? Theme.Colors.primaryFallback : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Question View

    private func questionView(_ question: Question) -> some View {
        VStack(spacing: 0) {
            // Progress and timer bar
            progressBar

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Section badge
                    sectionBadge(question.section)

                    // Question stem
                    Text(question.stem)
                        .font(Theme.Typography.questionStem)
                        .fixedSize(horizontal: false, vertical: true)

                    // Choices
                    ChoiceList(
                        choices: question.choices,
                        selectedIndex: Binding(
                            get: { viewModel.selectedAnswer },
                            set: { viewModel.selectAnswer($0 ?? -1) }
                        ),
                        correctIndex: viewModel.hasSubmitted ? question.correctIndex : nil,
                        showResult: viewModel.hasSubmitted,
                        isEnabled: !viewModel.hasSubmitted
                    )

                    // Error banner
                    if let error = viewModel.error {
                        ErrorBanner(
                            message: error.localizedDescription,
                            retryAction: { Task { await viewModel.loadExplanation() } },
                            dismissAction: { viewModel.dismissError() }
                        )
                    }

                    // Explanation (after submission)
                    if viewModel.hasSubmitted {
                        explanationSection
                    }
                }
                .padding(Theme.Spacing.md)
            }

            // Bottom action bar
            actionBar
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack {
            // Question counter
            Text("\(viewModel.currentIndex + 1) / \(viewModel.questions.count)")
                .font(Theme.Typography.bodyBold)
                .foregroundColor(.secondary)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Theme.Colors.primaryFallback)
                        .frame(width: geometry.size.width * viewModel.progress, height: 4)
                        .animation(Theme.Animation.standard, value: viewModel.progress)
                }
            }
            .frame(height: 4)

            // Timer or elapsed time
            if viewModel.isTimed {
                TimerView(
                    totalSeconds: AppConfig.defaultQuestionTimeLimit,
                    remainingSeconds: $viewModel.remainingSeconds,
                    onTimeUp: { viewModel.onTimeUp() }
                )
            } else {
                StopwatchView(elapsedSeconds: $viewModel.elapsedSeconds)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
    }

    // MARK: - Section Badge

    private func sectionBadge(_ section: QuestionSection) -> some View {
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

    // MARK: - Explanation Section

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Explanation")
                    .font(Theme.Typography.bodyBold)
                Spacer()
            }

            if viewModel.isLoadingExplanation {
                HStack {
                    StreamingIndicator()
                    Text("Generating explanation...")
                        .font(Theme.Typography.callout)
                        .foregroundColor(.secondary)
                }
            } else if let explanation = viewModel.explanation {
                Text(explanation)
                    .font(Theme.Typography.body)
            } else {
                Button("Show Explanation") {
                    Task { await viewModel.loadExplanation() }
                }
                .font(Theme.Typography.bodyBold)
                .foregroundColor(Theme.Colors.primaryFallback)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            if viewModel.hasSubmitted {
                Button("Next Question") {
                    viewModel.nextQuestion()
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Submit Answer") {
                    Task { await viewModel.submitAnswer() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.selectedAnswer == nil)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background)
    }
}

// MARK: - Session Complete View

struct SessionCompleteView: View {
    let stats: SessionStats
    let onRestart: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // Celebration icon
            Image(systemName: stats.accuracy >= 0.7 ? "star.fill" : "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(stats.accuracy >= 0.7 ? .yellow : Theme.Colors.primaryFallback)

            Text("Session Complete!")
                .font(Theme.Typography.title)

            // Stats
            VStack(spacing: Theme.Spacing.md) {
                statsRow(label: "Score", value: "\(stats.correct)/\(stats.total)")
                statsRow(label: "Accuracy", value: "\(stats.accuracyPercentage)%")
                statsRow(label: "Avg. Time", value: "\(stats.averageTime)s")
            }
            .padding()
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.large)

            Spacer()

            // Actions
            VStack(spacing: Theme.Spacing.sm) {
                Button("Practice Again", action: onRestart)
                    .buttonStyle(PrimaryButtonStyle())

                Button("Done", action: onExit)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
        }
        .padding()
    }

    private func statsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.bodyBold)
        }
    }
}

// MARK: - Preview

#Preview {
    PracticeView(viewModel: .preview)
}
