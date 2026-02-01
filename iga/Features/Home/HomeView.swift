// IGA/Features/Home/HomeView.swift

import SwiftUI

// MARK: - Home View

/// Main tab-based navigation for the IGA app
struct HomeView: View {
    @State private var selectedTab: Tab = .practice
    @State private var showDiagnostic = false
    @State private var userProgress: UserProgress?
    @State private var diagnosticViewModel: DiagnosticViewModel?
    @State private var hasSkippedDiagnostic = false

    enum Tab: Hashable {
        case practice
        case tutor
        case vocab
        case progress
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Practice Tab
            PracticeView()
                .tabItem {
                    Label("Practice", systemImage: "list.bullet.clipboard")
                }
                .tag(Tab.practice)

            // Tutor Chat Tab
            TutorChatView()
                .tabItem {
                    Label("Tutor", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(Tab.tutor)

            // Vocabulary Tab
            VocabListView()
                .tabItem {
                    Label("Vocab", systemImage: "text.book.closed")
                }
                .tag(Tab.vocab)

            // Progress Tab
            StatsView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.progress)
        }
        .tint(Theme.Colors.primaryFallback)
        .task {
            await checkDiagnosticStatus()
        }
        .sheet(isPresented: $showDiagnostic) {
            if let viewModel = diagnosticViewModel {
                DiagnosticView(viewModel: viewModel)
            }
        }
        .overlay {
            if shouldShowDiagnosticPrompt {
                diagnosticPromptOverlay
            }
        }
    }

    /// Check if user needs to complete diagnostic
    private var shouldShowDiagnosticPrompt: Bool {
        guard let progress = userProgress else { return false }
        return !progress.hasCompletedDiagnostic && !showDiagnostic && !hasSkippedDiagnostic
    }

    /// Prompt overlay for diagnostic
    private var diagnosticPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundStyle(Theme.Colors.primary)

                Text("Welcome to IGA!")
                    .font(Theme.Typography.title)

                Text("Before you start practicing, let's assess your current GRE skill level. This 25-35 minute diagnostic will create a personalized study plan just for you.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: Theme.Spacing.md) {
                    Button {
                        startDiagnostic()
                    } label: {
                        Text("Take Diagnostic")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        skipDiagnostic()
                    } label: {
                        Text("Skip for now")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.background)
            .cornerRadius(Theme.CornerRadius.large)
            .padding(Theme.Spacing.xl)
        }
    }

    /// Check if user has completed diagnostic
    private func checkDiagnosticStatus() async {
        do {
            userProgress = try DataStore.shared.fetchOrCreateUserProgress()
        } catch {
            print("Failed to fetch user progress: \(error)")
        }
    }

    /// Start the diagnostic assessment
    private func startDiagnostic() {
        diagnosticViewModel = DiagnosticViewModel()
        showDiagnostic = true
    }

    /// Skip diagnostic for now
    private func skipDiagnostic() {
        // User chose to skip - dismiss the prompt for this session
        // They can still take the diagnostic later from the progress tab
        hasSkippedDiagnostic = true
    }
}

// MARK: - Stats View

/// View for displaying user progress and statistics
struct StatsView: View {
    @State private var progress: UserProgress?
    @State private var isLoading = true
    @State private var showDiagnostic = false
    @State private var diagnosticViewModel: DiagnosticViewModel?
    @State private var latestDiagnostic: DiagnosticResult?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if isLoading {
                        LoadingView()
                    } else if let progress {
                        progressContent(progress)
                    } else {
                        emptyState
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Progress")
        }
        .task {
            await loadProgress()
        }
        .sheet(isPresented: $showDiagnostic) {
            if let viewModel = diagnosticViewModel {
                DiagnosticView(viewModel: viewModel)
            }
        }
    }

    private func progressContent(_ progress: UserProgress) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Diagnostic card
            diagnosticCard(progress)

            // Quick access links
            quickAccessSection

            // Overall stats card
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Text("Overall Performance")
                        .font(Theme.Typography.title3)
                    Spacer()
                }

                HStack(spacing: Theme.Spacing.xl) {
                    AccuracyRing(
                        correct: progress.totalCorrect,
                        total: progress.totalAttempted,
                        size: 100
                    )

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        statRow(label: "Questions", value: "\(progress.totalAttempted)")
                        statRow(label: "Correct", value: "\(progress.totalCorrect)")
                        statRow(label: "Streak", value: "\(progress.currentStreak) days")
                        statRow(label: "Time", value: formatTime(progress.totalTimeSpent))
                    }
                }
            }
            .cardStyle()

            // Section breakdown
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Text("By Section")
                        .font(Theme.Typography.title3)
                    Spacer()
                }

                HStack(spacing: Theme.Spacing.md) {
                    sectionCard(
                        section: .quant,
                        correct: progress.quantCorrect,
                        total: progress.quantAttempted
                    )

                    sectionCard(
                        section: .verbal,
                        correct: progress.verbalCorrect,
                        total: progress.verbalAttempted
                    )
                }
            }
            .cardStyle()

            // Topic strengths
            if !progress.topicRatings.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    HStack {
                        Text("Topic Ratings")
                            .font(Theme.Typography.title3)
                        Spacer()
                    }

                    ForEach(sortedTopics(progress.topicRatings), id: \.topic) { rating in
                        topicRow(rating)
                    }
                }
                .cardStyle()
            }

            // Vocabulary progress
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Text("Vocabulary")
                        .font(Theme.Typography.title3)
                    Spacer()
                }

                HStack {
                    Text("Words Mastered")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(progress.vocabMastered)")
                        .font(Theme.Typography.bodyBold)
                }
            }
            .cardStyle()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "chart.bar")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No progress yet")
                .font(Theme.Typography.title3)

            Text("Start practicing to see your stats here!")
                .font(Theme.Typography.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.bodyBold)
        }
    }

    private func sectionCard(section: QuestionSection, correct: Int, total: Int) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: section.icon)
                .font(.title2)
                .foregroundColor(Theme.Colors.sectionColor(section))

            Text(section.displayName)
                .font(Theme.Typography.caption)

            AccuracyRing(correct: correct, total: total, size: 60)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func topicRow(_ rating: TopicRating) -> some View {
        HStack {
            Text(rating.topic.replacingOccurrences(of: "-", with: " ").capitalized)
                .font(Theme.Typography.body)

            Spacer()

            Text(rating.level)
                .font(Theme.Typography.caption)
                .foregroundColor(.secondary)

            MiniProgressRing(progress: rating.rating / 2000)
        }
    }

    private func sortedTopics(_ ratings: [String: Double]) -> [TopicRating] {
        ratings
            .map { TopicRating(topic: $0.key, rating: $0.value) }
            .sorted { $0.rating > $1.rating }
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func loadProgress() async {
        isLoading = true
        do {
            progress = try DataStore.shared.fetchOrCreateUserProgress()
            latestDiagnostic = try DataStore.shared.fetchLatestDiagnosticResult()
        } catch {
            progress = nil
            latestDiagnostic = nil
        }
        isLoading = false
    }

    /// Quick access navigation section
    private var quickAccessSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                NavigationLink {
                    MasteryDashboardView()
                } label: {
                    QuickAccessCard(
                        icon: "chart.bar.fill",
                        title: "Skill Mastery",
                        color: Theme.Colors.quant
                    )
                }

                NavigationLink {
                    StudyPlanView()
                } label: {
                    QuickAccessCard(
                        icon: "calendar",
                        title: "Study Plan",
                        color: Theme.Colors.verbal
                    )
                }
            }

            HStack(spacing: Theme.Spacing.md) {
                NavigationLink {
                    ErrorLogView()
                } label: {
                    QuickAccessCard(
                        icon: "exclamationmark.circle.fill",
                        title: "Mistake Journal",
                        color: Theme.Colors.error
                    )
                }

                NavigationLink {
                    ExamModeView()
                } label: {
                    QuickAccessCard(
                        icon: "timer",
                        title: "Exam Mode",
                        color: Theme.Colors.warning
                    )
                }
            }

            HStack(spacing: Theme.Spacing.md) {
                NavigationLink {
                    AWALabView()
                } label: {
                    QuickAccessCard(
                        icon: "pencil.and.outline",
                        title: "AWA Lab",
                        color: Theme.Colors.info
                    )
                }

                NavigationLink {
                    CalculatorView()
                } label: {
                    QuickAccessCard(
                        icon: "function",
                        title: "Calculator",
                        color: Theme.Colors.quant
                    )
                }
            }
        }
    }

    /// Diagnostic status card
    private func diagnosticCard(_ progress: UserProgress) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Text("Diagnostic Assessment")
                    .font(Theme.Typography.title3)
                Spacer()

                if progress.hasCompletedDiagnostic {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.success)
                }
            }

            if let diagnostic = latestDiagnostic {
                // Show diagnostic results
                HStack(spacing: Theme.Spacing.xl) {
                    VStack(spacing: Theme.Spacing.xs) {
                        Text("\(diagnostic.estimatedQuantScore)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.quant)
                        Text("Quant")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: Theme.Spacing.xs) {
                        Text("\(diagnostic.estimatedVerbalScore)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.verbal)
                        Text("Verbal")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: Theme.Spacing.xs) {
                        Text("\(diagnostic.estimatedTotalScore)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.primary)
                        Text("Total")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if progress.diagnosticIsStale {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.Colors.warning)
                        Text("Your diagnostic is over 30 days old. Consider retaking it.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Retake Diagnostic") {
                    diagnosticViewModel = DiagnosticViewModel()
                    showDiagnostic = true
                }
                .buttonStyle(.bordered)
            } else {
                // Prompt to take diagnostic
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.Colors.primary)

                    Text("Take the diagnostic assessment to get personalized score estimates and study recommendations.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Take Diagnostic") {
                        diagnosticViewModel = DiagnosticViewModel()
                        showDiagnostic = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Quick Access Card

struct QuickAccessCard: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}
