// IGA/Features/AWA/AWALabView.swift

import SwiftUI

// MARK: - AWA Lab View

/// Analytical Writing Assessment practice with AI scoring
struct AWALabView: View {
    @State private var viewModel = AWALabViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch viewModel.state {
            case .promptSelection:
                promptSelectionView
            case .outlining:
                outliningView
            case .writing:
                writingView
            case .scoring:
                scoringView
            case .results:
                resultsView
            }
        }
        .navigationTitle(viewModel.state == .promptSelection ? "AWA Lab" : "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.state != .promptSelection)
    }

    // MARK: - Prompt Selection

    private var promptSelectionView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Header
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.Colors.primary)

                    Text("Analytical Writing")
                        .font(Theme.Typography.title)

                    Text("Practice the Issue essay with AI-powered scoring and feedback.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Theme.Spacing.xl)

                // Format info
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Essay Format")
                        .font(Theme.Typography.title3)

                    infoRow(icon: "clock", title: "Time Limit", value: "30 minutes")
                    infoRow(icon: "doc.text", title: "Task", value: "Analyze an Issue")
                    infoRow(icon: "textformat.size", title: "Recommended", value: "400-600 words")
                    infoRow(icon: "star", title: "Score Range", value: "0-6")
                }
                .cardStyle()

                // Prompt selection
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Select a Prompt")
                        .font(Theme.Typography.title3)

                    ForEach(viewModel.availablePrompts, id: \.id) { prompt in
                        promptCard(prompt)
                    }
                }
                .cardStyle()

                // Options
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Options")
                        .font(Theme.Typography.title3)

                    Toggle("Show timer", isOn: $viewModel.showTimer)
                    Toggle("Use outline assistant", isOn: $viewModel.useOutline)
                }
                .cardStyle()
            }
            .padding(Theme.Spacing.md)
        }
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
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

    private func promptCard(_ prompt: AWAPrompt) -> some View {
        Button {
            viewModel.selectPrompt(prompt)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(prompt.topic)
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(prompt.category)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Label("Difficulty: \(prompt.difficulty)/5", systemImage: "chart.bar")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Outlining View

    private var outliningView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Prompt display
                if let prompt = viewModel.selectedPrompt {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Prompt")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)

                        Text(prompt.fullText)
                            .font(Theme.Typography.body)
                    }
                    .cardStyle()
                }

                // Outline sections
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Plan Your Essay")
                        .font(Theme.Typography.title3)

                    outlineSection(
                        title: "Your Position",
                        placeholder: "What is your stance on this issue?",
                        text: $viewModel.outlinePosition
                    )

                    outlineSection(
                        title: "Main Argument 1",
                        placeholder: "Your first supporting point...",
                        text: $viewModel.outlineArg1
                    )

                    outlineSection(
                        title: "Main Argument 2",
                        placeholder: "Your second supporting point...",
                        text: $viewModel.outlineArg2
                    )

                    outlineSection(
                        title: "Counterargument",
                        placeholder: "What might someone argue against your position?",
                        text: $viewModel.outlineCounter
                    )

                    outlineSection(
                        title: "Conclusion Angle",
                        placeholder: "How will you wrap up your essay?",
                        text: $viewModel.outlineConclusion
                    )
                }
                .cardStyle()

                // Start writing button
                Button {
                    viewModel.startWriting()
                } label: {
                    Text("Start Writing")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    viewModel.skipOutline()
                } label: {
                    Text("Skip Outline")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(Theme.Spacing.md)
        }
        .navigationTitle("Outline")
    }

    private func outlineSection(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
    }

    // MARK: - Writing View

    private var writingView: some View {
        VStack(spacing: 0) {
            // Header
            writingHeader

            // Prompt (collapsible)
            if viewModel.showPromptInWriting {
                promptBanner
            }

            // Writing area
            TextEditor(text: $viewModel.essayText)
                .font(.system(.body, design: .serif))
                .padding(Theme.Spacing.sm)
                .scrollContentBackground(.hidden)
                .background(Theme.Colors.background)

            // Footer with word count and submit
            writingFooter
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    viewModel.showPromptInWriting.toggle()
                } label: {
                    Image(systemName: viewModel.showPromptInWriting ? "eye.slash" : "eye")
                }
            }
        }
    }

    private var writingHeader: some View {
        HStack {
            if viewModel.showTimer {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "clock")
                    Text(viewModel.formattedTimeRemaining)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(viewModel.remainingSeconds < 300 ? Theme.Colors.error : .primary)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(Theme.CornerRadius.small)
            }

            Spacer()

            Text("\(viewModel.wordCount) words")
                .font(Theme.Typography.caption)
                .foregroundStyle(wordCountColor)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background)
    }

    private var promptBanner: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let prompt = viewModel.selectedPrompt {
                Text(prompt.fullText)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.secondaryBackground)
    }

    private var writingFooter: some View {
        HStack {
            // Word count indicator
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(wordCountColor)
                    .frame(width: 8, height: 8)
                Text(wordCountStatus)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.submitEssay()
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Submit")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.wordCount < 100)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Theme.Colors.secondaryBackground),
            alignment: .top
        )
    }

    private var wordCountColor: Color {
        let count = viewModel.wordCount
        if count < 200 { return Theme.Colors.error }
        if count < 400 { return Theme.Colors.warning }
        if count <= 600 { return Theme.Colors.success }
        return Theme.Colors.warning
    }

    private var wordCountStatus: String {
        let count = viewModel.wordCount
        if count < 200 { return "Too short" }
        if count < 400 { return "Keep writing" }
        if count <= 600 { return "Good length" }
        return "Consider trimming"
    }

    // MARK: - Scoring View

    private var scoringView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing your essay...")
                .font(Theme.Typography.title3)

            Text("Our AI is evaluating your argument structure, evidence, and writing quality.")
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding(Theme.Spacing.md)
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Score header
                if let feedback = viewModel.feedback {
                    VStack(spacing: Theme.Spacing.md) {
                        Text("Your Score")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)

                        ZStack {
                            Circle()
                                .stroke(Theme.Colors.secondaryBackground, lineWidth: 8)
                                .frame(width: 120, height: 120)

                            Circle()
                                .trim(from: 0, to: CGFloat(feedback.score) / 6.0)
                                .stroke(scoreColor(feedback.score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 2) {
                                Text(String(format: "%.1f", feedback.score))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                Text("/ 6.0")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(scoreDescription(feedback.score))
                            .font(Theme.Typography.bodyBold)
                            .foregroundStyle(scoreColor(feedback.score))
                    }
                    .padding(.top, Theme.Spacing.xl)

                    // Dimension scores
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Score Breakdown")
                            .font(Theme.Typography.title3)

                        dimensionRow(title: "Thesis Clarity", score: feedback.thesisClarity)
                        dimensionRow(title: "Argument Development", score: feedback.argumentDevelopment)
                        dimensionRow(title: "Evidence & Examples", score: feedback.evidenceQuality)
                        dimensionRow(title: "Organization", score: feedback.organization)
                        dimensionRow(title: "Language & Style", score: feedback.languageStyle)
                        dimensionRow(title: "Grammar & Mechanics", score: feedback.grammarMechanics)
                    }
                    .cardStyle()

                    // Feedback comments
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Feedback")
                            .font(Theme.Typography.title3)

                        ForEach(feedback.comments, id: \.self) { comment in
                            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                Image(systemName: "quote.opening")
                                    .foregroundStyle(Theme.Colors.primary)
                                    .font(.caption)
                                Text(comment)
                                    .font(Theme.Typography.body)
                            }
                        }
                    }
                    .cardStyle()

                    // Suggestions
                    if !feedback.suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Suggestions for Improvement")
                                .font(Theme.Typography.title3)

                            ForEach(feedback.suggestions, id: \.self) { suggestion in
                                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                    Image(systemName: "lightbulb")
                                        .foregroundStyle(Theme.Colors.warning)
                                    Text(suggestion)
                                        .font(Theme.Typography.body)
                                }
                            }
                        }
                        .cardStyle()
                    }
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
                        viewModel.tryAnotherPrompt()
                    } label: {
                        Text("Try Another Prompt")
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

    private func dimensionRow(title: String, score: Double) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 2) {
                ForEach(0..<6) { i in
                    Circle()
                        .fill(Double(i) < score ? scoreColor(score) : Theme.Colors.secondaryBackground)
                        .frame(width: 10, height: 10)
                }
            }
            Text(String(format: "%.1f", score))
                .font(Theme.Typography.bodyBold)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 5.0 { return Theme.Colors.success }
        if score >= 4.0 { return Theme.Colors.info }
        if score >= 3.0 { return Theme.Colors.warning }
        return Theme.Colors.error
    }

    private func scoreDescription(_ score: Double) -> String {
        if score >= 5.5 { return "Outstanding" }
        if score >= 5.0 { return "Strong" }
        if score >= 4.0 { return "Adequate" }
        if score >= 3.0 { return "Limited" }
        if score >= 2.0 { return "Seriously Flawed" }
        return "Fundamentally Deficient"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AWALabView()
    }
}
