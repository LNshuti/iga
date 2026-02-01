// IGA/Features/Progress/MasteryDashboardView.swift

import SwiftUI

// MARK: - Mastery Dashboard View

/// Displays detailed mastery information across all subskills
struct MasteryDashboardView: View {
    @State private var masteryStates: [SubskillMasteryState] = []
    @State private var isLoading = true
    @State private var selectedSection: QuestionSection? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if isLoading {
                        LoadingView()
                    } else {
                        // Section filter
                        sectionPicker

                        // Overall mastery summary
                        overallMasteryCard

                        // Subskill breakdown
                        subskillBreakdown

                        // Recommendations
                        if !recommendedSubskills.isEmpty {
                            recommendationsCard
                        }
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Skill Mastery")
        }
        .task {
            await loadMasteryStates()
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        Picker("Section", selection: $selectedSection) {
            Text("All").tag(nil as QuestionSection?)
            Text("Quantitative").tag(QuestionSection.quant as QuestionSection?)
            Text("Verbal").tag(QuestionSection.verbal as QuestionSection?)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Overall Mastery Card

    private var overallMasteryCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Text("Overall Mastery")
                    .font(Theme.Typography.title3)
                Spacer()
            }

            HStack(spacing: Theme.Spacing.xl) {
                // Quant mastery
                VStack(spacing: Theme.Spacing.sm) {
                    MasteryRing(progress: quantMasteryProgress, color: Theme.Colors.quant, size: 80)
                    Text("Quant")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(quantMasteryProgress * 100))%")
                        .font(Theme.Typography.bodyBold)
                }

                // Verbal mastery
                VStack(spacing: Theme.Spacing.sm) {
                    MasteryRing(progress: verbalMasteryProgress, color: Theme.Colors.verbal, size: 80)
                    Text("Verbal")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(verbalMasteryProgress * 100))%")
                        .font(Theme.Typography.bodyBold)
                }

                // Combined
                VStack(spacing: Theme.Spacing.sm) {
                    MasteryRing(progress: overallMasteryProgress, color: Theme.Colors.primary, size: 80)
                    Text("Overall")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(overallMasteryProgress * 100))%")
                        .font(Theme.Typography.bodyBold)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Subskill Breakdown

    private var subskillBreakdown: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Subskill Details")
                .font(Theme.Typography.title3)

            ForEach(filteredMasteryStates, id: \.subskillID) { state in
                SubskillMasteryRow(state: state)
            }
        }
        .cardStyle()
    }

    // MARK: - Recommendations Card

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Theme.Colors.warning)
                Text("Focus Areas")
                    .font(Theme.Typography.title3)
            }

            Text("These subskills need the most attention based on your mastery levels:")
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)

            ForEach(recommendedSubskills, id: \.subskillID) { state in
                RecommendedSubskillRow(state: state)
            }
        }
        .padding()
        .background(Theme.Colors.warning.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.large)
    }

    // MARK: - Computed Properties

    private var filteredMasteryStates: [SubskillMasteryState] {
        guard let section = selectedSection else {
            return masteryStates.sorted { $0.subskillID < $1.subskillID }
        }

        let subskillIDs = section == .quant
            ? Subskill.quantSubskills.map { $0.rawValue }
            : Subskill.verbalSubskills.map { $0.rawValue }

        return masteryStates
            .filter { subskillIDs.contains($0.subskillID) }
            .sorted { $0.subskillID < $1.subskillID }
    }

    private var quantMasteryProgress: Double {
        let quantStates = masteryStates.filter { state in
            Subskill.quantSubskills.map { $0.rawValue }.contains(state.subskillID)
        }
        guard !quantStates.isEmpty else { return 0 }
        return quantStates.map { $0.pKnown }.reduce(0, +) / Double(quantStates.count)
    }

    private var verbalMasteryProgress: Double {
        let verbalStates = masteryStates.filter { state in
            Subskill.verbalSubskills.map { $0.rawValue }.contains(state.subskillID)
        }
        guard !verbalStates.isEmpty else { return 0 }
        return verbalStates.map { $0.pKnown }.reduce(0, +) / Double(verbalStates.count)
    }

    private var overallMasteryProgress: Double {
        guard !masteryStates.isEmpty else { return 0 }
        return masteryStates.map { $0.pKnown }.reduce(0, +) / Double(masteryStates.count)
    }

    private var recommendedSubskills: [SubskillMasteryState] {
        masteryStates
            .filter { $0.masteryLevel == .novice || $0.masteryLevel == .developing }
            .sorted { $0.pKnown < $1.pKnown }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Data Loading

    private func loadMasteryStates() async {
        isLoading = true
        do {
            masteryStates = try DataStore.shared.fetchOrCreateAllMasteryStates()
        } catch {
            print("Failed to load mastery states: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Subskill Mastery Row

struct SubskillMasteryRow: View {
    let state: SubskillMasteryState

    private var subskill: Subskill? {
        Subskill(rawValue: state.subskillID)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon
            if let subskill = subskill {
                Image(systemName: subskill.icon)
                    .font(.title3)
                    .foregroundStyle(subskill.section == .quant ? Theme.Colors.quant : Theme.Colors.verbal)
                    .frame(width: 32)
            }

            // Name and stats
            VStack(alignment: .leading, spacing: 2) {
                Text(subskill?.name ?? state.subskillID)
                    .font(Theme.Typography.body)

                HStack(spacing: Theme.Spacing.sm) {
                    Text("\(state.attemptCount) attempts")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)

                    if state.attemptCount > 0 {
                        Text("\(Int(state.accuracy * 100))% accuracy")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Mastery badge
            MasteryBadge(level: state.masteryLevel)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Recommended Subskill Row

struct RecommendedSubskillRow: View {
    let state: SubskillMasteryState

    private var subskill: Subskill? {
        Subskill(rawValue: state.subskillID)
    }

    var body: some View {
        NavigationLink {
            PracticeView(subskillFilter: state.subskillID)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subskill?.name ?? state.subskillID)
                        .font(Theme.Typography.body)

                    Text("\(Int(state.pKnown * 100))% mastery")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Practice")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.primary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mastery Ring

struct MasteryRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 8)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Mastery Badge

struct MasteryBadge: View {
    let level: MasteryLevel

    var body: some View {
        Text(level.name)
            .font(Theme.Typography.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.2))
            .foregroundStyle(badgeColor)
            .cornerRadius(Theme.CornerRadius.small)
    }

    private var badgeColor: Color {
        switch level {
        case .novice: return Theme.Colors.error
        case .developing: return Theme.Colors.warning
        case .proficient: return Theme.Colors.info
        case .mastered: return Theme.Colors.success
        }
    }
}

// MARK: - Preview

#Preview {
    MasteryDashboardView()
}
