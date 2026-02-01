// IGA/Features/Home/HomeView.swift

import SwiftUI

// MARK: - Home View

/// Main tab-based navigation for the IGA app
struct HomeView: View {
    @State private var selectedTab: Tab = .practice

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
    }
}

// MARK: - Stats View

/// View for displaying user progress and statistics
struct StatsView: View {
    @State private var progress: UserProgress?
    @State private var isLoading = true

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
    }

    private func progressContent(_ progress: UserProgress) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
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
        } catch {
            progress = nil
        }
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}
