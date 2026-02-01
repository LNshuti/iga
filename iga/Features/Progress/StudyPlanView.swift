// IGA/Features/Progress/StudyPlanView.swift

import SwiftUI

// MARK: - Study Plan View

/// Displays a personalized study plan based on diagnostic results and mastery
struct StudyPlanView: View {
    @State private var masteryStates: [SubskillMasteryState] = []
    @State private var diagnosticResult: DiagnosticResult?
    @State private var userProgress: UserProgress?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if isLoading {
                        LoadingView()
                    } else {
                        // Goal section
                        goalSection

                        // Today's focus
                        todaysFocusSection

                        // Weekly plan
                        weeklyPlanSection

                        // Progress toward goal
                        progressSection
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Study Plan")
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Goal Section

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(Theme.Colors.primary)
                Text("Your Goal")
                    .font(Theme.Typography.title3)
            }

            if let diagnostic = diagnosticResult {
                HStack(spacing: Theme.Spacing.xl) {
                    VStack(spacing: Theme.Spacing.xs) {
                        Text("Current")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                        Text("\(diagnostic.estimatedTotalScore)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    }

                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    VStack(spacing: Theme.Spacing.xs) {
                        Text("Target")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                        Text("\(targetScore)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.primary)
                    }

                    Spacer()

                    VStack(spacing: Theme.Spacing.xs) {
                        Text("Gap")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                        Text("+\(targetScore - diagnostic.estimatedTotalScore)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.warning)
                    }
                }
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Complete the diagnostic assessment to set your target score")
                        .font(Theme.Typography.body)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        DiagnosticView(viewModel: DiagnosticViewModel())
                    } label: {
                        Text("Take Diagnostic")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Today's Focus Section

    private var todaysFocusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)
                Text("Today's Focus")
                    .font(Theme.Typography.title3)
            }

            if todaysFocusSubskills.isEmpty {
                Text("Complete more practice to get personalized recommendations")
                    .font(Theme.Typography.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(todaysFocusSubskills, id: \.subskillID) { state in
                    TodaysFocusRow(state: state)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Weekly Plan Section

    private var weeklyPlanSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Theme.Colors.info)
                Text("This Week")
                    .font(Theme.Typography.title3)
            }

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(weeklyPlan, id: \.day) { day in
                    WeeklyPlanRow(plan: day)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Theme.Colors.success)
                Text("Progress This Week")
                    .font(Theme.Typography.title3)
            }

            HStack(spacing: Theme.Spacing.lg) {
                ProgressMetric(
                    icon: "checkmark.circle",
                    value: "\(weeklyAttempts)",
                    label: "Questions",
                    color: Theme.Colors.primary
                )

                ProgressMetric(
                    icon: "clock",
                    value: formatTime(weeklyTimeSpent),
                    label: "Study Time",
                    color: Theme.Colors.info
                )

                ProgressMetric(
                    icon: "percent",
                    value: "\(Int(weeklyAccuracy * 100))%",
                    label: "Accuracy",
                    color: Theme.Colors.success
                )
            }
        }
        .cardStyle()
    }

    // MARK: - Computed Properties

    private var targetScore: Int {
        // Default target: current + 20 points, capped at 340
        let current = diagnosticResult?.estimatedTotalScore ?? 300
        return min(340, current + 20)
    }

    private var todaysFocusSubskills: [SubskillMasteryState] {
        // Get subskills that need work, prioritized by:
        // 1. Forgetting risk (haven't practiced recently)
        // 2. Low mastery
        let now = Date()

        return masteryStates
            .filter { $0.masteryLevel != .mastered }
            .sorted { state1, state2 in
                let daysSince1 = state1.lastPracticed.map { now.timeIntervalSince($0) / 86400 } ?? 100
                let daysSince2 = state2.lastPracticed.map { now.timeIntervalSince($0) / 86400 } ?? 100

                // Prioritize by combination of days since practice and low mastery
                let score1 = daysSince1 * (1 - state1.pKnown)
                let score2 = daysSince2 * (1 - state2.pKnown)
                return score1 > score2
            }
            .prefix(3)
            .map { $0 }
    }

    private var weeklyPlan: [DailyPlan] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)

        // Generate plan for rest of week
        var plans: [DailyPlan] = []

        for dayOffset in 0..<7 {
            let dayIndex = (weekday - 1 + dayOffset) % 7
            let dayName = calendar.weekdaySymbols[dayIndex]
            let isToday = dayOffset == 0

            // Assign focus based on day pattern
            let focus: String
            let subskills: [String]

            switch dayIndex {
            case 0: // Sunday - Review
                focus = "Review Week"
                subskills = ["Mixed Review"]
            case 1, 3, 5: // Mon, Wed, Fri - Quant
                focus = "Quantitative"
                subskills = Subskill.quantSubskills.prefix(2).map { $0.shortName }
            case 2, 4: // Tue, Thu - Verbal
                focus = "Verbal"
                subskills = Subskill.verbalSubskills.prefix(2).map { $0.shortName }
            case 6: // Saturday - Practice Test
                focus = "Practice Test"
                subskills = ["Full Section"]
            default:
                focus = "Practice"
                subskills = []
            }

            plans.append(DailyPlan(
                day: dayName,
                focus: focus,
                subskills: subskills,
                isToday: isToday,
                isCompleted: false
            ))
        }

        return plans
    }

    private var weeklyAttempts: Int {
        // Would calculate from actual attempts in the week
        userProgress?.totalAttempted ?? 0
    }

    private var weeklyTimeSpent: Int {
        // Would calculate from actual time in the week
        userProgress?.totalTimeSpent ?? 0
    }

    private var weeklyAccuracy: Double {
        guard let progress = userProgress, progress.totalAttempted > 0 else { return 0 }
        return Double(progress.totalCorrect) / Double(progress.totalAttempted)
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        do {
            masteryStates = try DataStore.shared.fetchOrCreateAllMasteryStates()
            diagnosticResult = try DataStore.shared.fetchLatestDiagnosticResult()
            userProgress = try DataStore.shared.fetchOrCreateUserProgress()
        } catch {
            print("Failed to load study plan data: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Supporting Types

struct DailyPlan: Identifiable {
    let id = UUID()
    let day: String
    let focus: String
    let subskills: [String]
    let isToday: Bool
    let isCompleted: Bool
}

// MARK: - Today's Focus Row

struct TodaysFocusRow: View {
    let state: SubskillMasteryState

    private var subskill: Subskill? {
        Subskill(rawValue: state.subskillID)
    }

    var body: some View {
        NavigationLink {
            PracticeView(subskillFilter: state.subskillID)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(subskillColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: subskill?.icon ?? "questionmark")
                        .foregroundStyle(subskillColor)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(subskill?.name ?? state.subskillID)
                        .font(Theme.Typography.body)

                    HStack(spacing: Theme.Spacing.sm) {
                        Text("\(Int(state.pKnown * 100))% mastery")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)

                        if let lastPracticed = state.lastPracticed {
                            Text(lastPracticedText(lastPracticed))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Text("Start")
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(Theme.Colors.primary)
            }
            .padding()
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }

    private var subskillColor: Color {
        guard let subskill = subskill else { return Theme.Colors.primary }
        return subskill.section == .quant ? Theme.Colors.quant : Theme.Colors.verbal
    }

    private func lastPracticedText(_ date: Date) -> String {
        let days = Int(Date().timeIntervalSince(date) / 86400)
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }
}

// MARK: - Weekly Plan Row

struct WeeklyPlanRow: View {
    let plan: DailyPlan

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Day indicator
            VStack(spacing: 2) {
                Text(String(plan.day.prefix(3)))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(plan.isToday ? Theme.Colors.primary : .secondary)

                if plan.isToday {
                    Circle()
                        .fill(Theme.Colors.primary)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 40)

            // Focus area
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.focus)
                    .font(Theme.Typography.body)
                    .foregroundStyle(plan.isToday ? .primary : .secondary)

                Text(plan.subskills.joined(separator: ", "))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Status
            if plan.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Colors.success)
            } else if plan.isToday {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(Theme.Colors.primary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .opacity(plan.isToday ? 1.0 : 0.6)
    }
}

// MARK: - Progress Metric

struct ProgressMetric: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(Theme.Typography.bodyBold)

            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    StudyPlanView()
}
