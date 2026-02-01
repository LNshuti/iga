// IGA/Features/Progress/ErrorLogView.swift

import SwiftUI

// MARK: - Error Log View

/// Displays the user's mistake journal for review
struct ErrorLogView: View {
    @State private var errors: [ErrorLogEntry] = []
    @State private var questions: [String: Question] = [:]
    @State private var isLoading = true
    @State private var selectedFilter: ErrorFilter = .all
    @State private var stats: ErrorStats?

    enum ErrorFilter: String, CaseIterable {
        case all = "All"
        case unreviewed = "Unreviewed"
        case conceptual = "Conceptual"
        case careless = "Careless"
        case timePressure = "Time Pressure"

        var errorType: ErrorType? {
            switch self {
            case .all, .unreviewed: return nil
            case .conceptual: return .conceptual
            case .careless: return .careless
            case .timePressure: return .timePressure
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if isLoading {
                        LoadingView()
                    } else if errors.isEmpty {
                        emptyState
                    } else {
                        // Stats summary
                        if let stats = stats {
                            statsSummary(stats)
                        }

                        // Filter chips
                        filterChips

                        // Error list
                        errorList
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Mistake Journal")
            .task {
                await loadErrors()
            }
        }
    }

    // MARK: - Stats Summary

    private func statsSummary(_ stats: ErrorStats) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Text("Your Mistakes")
                    .font(Theme.Typography.title3)
                Spacer()
            }

            HStack(spacing: Theme.Spacing.lg) {
                statBox(
                    value: "\(stats.totalErrors)",
                    label: "Total",
                    color: Theme.Colors.error
                )

                statBox(
                    value: "\(stats.reviewedCount)",
                    label: "Reviewed",
                    color: Theme.Colors.info
                )

                statBox(
                    value: "\(Int(stats.retrySuccessRate * 100))%",
                    label: "Fixed",
                    color: Theme.Colors.success
                )
            }

            // Most common error type
            if let commonType = stats.mostCommonErrorType {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: commonType.icon)
                        .foregroundStyle(.orange)
                    Text("Most common: \(commonType.displayName)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .cardStyle()
    }

    private func statBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ErrorFilter.allCases, id: \.self) { filter in
                    filterChip(filter)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
        }
    }

    private func filterChip(_ filter: ErrorFilter) -> some View {
        Button {
            selectedFilter = filter
            Task { await loadErrors() }
        } label: {
            Text(filter.rawValue)
                .font(Theme.Typography.caption)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    selectedFilter == filter
                        ? Theme.Colors.primaryFallback
                        : Theme.Colors.secondaryBackground
                )
                .foregroundStyle(
                    selectedFilter == filter ? .white : .primary
                )
                .cornerRadius(Theme.CornerRadius.pill)
        }
    }

    // MARK: - Error List

    private var errorList: some View {
        LazyVStack(spacing: Theme.Spacing.md) {
            ForEach(errors, id: \.id) { error in
                errorCard(error)
            }
        }
    }

    private func errorCard(_ error: ErrorLogEntry) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header
            HStack {
                // Error type badge
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: error.errorType.icon)
                    Text(error.errorType.displayName)
                }
                .font(Theme.Typography.caption)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(errorTypeColor(error.errorType).opacity(0.15))
                .foregroundStyle(errorTypeColor(error.errorType))
                .cornerRadius(Theme.CornerRadius.small)

                Spacer()

                // Date
                Text(error.timestamp, style: .relative)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            // Question preview (if available)
            if let question = questions[error.questionID] {
                Text(question.stem)
                    .font(Theme.Typography.body)
                    .lineLimit(3)

                // Your answer vs correct
                HStack(spacing: Theme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your answer")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                        Text(error.selectedAnswer >= 0 && error.selectedAnswer < question.choices.count
                             ? question.choices[error.selectedAnswer]
                             : "Skipped")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.error)
                            .lineLimit(1)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Correct")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                        Text(error.correctAnswer < question.choices.count
                             ? question.choices[error.correctAnswer]
                             : "N/A")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.success)
                            .lineLimit(1)
                    }
                }
            }

            // Subskill
            if let subskill = error.subskill {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: subskill.section == .quant ? "function" : "text.book.closed")
                        .font(.caption)
                    Text(subskill.name)
                        .font(Theme.Typography.caption)
                }
                .foregroundStyle(.secondary)
            }

            // Review status
            HStack {
                if error.hasReviewed {
                    if error.retriedCorrectly == true {
                        Label("Fixed", systemImage: "checkmark.circle.fill")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.success)
                    } else {
                        Label("Reviewed", systemImage: "eye.fill")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.info)
                    }
                } else {
                    Label("Not reviewed", systemImage: "exclamationmark.circle")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.warning)
                }

                Spacer()

                // Practice button
                NavigationLink {
                    if let question = questions[error.questionID] {
                        PracticeView(subskillFilter: question.primarySubskill)
                    }
                } label: {
                    Text("Practice")
                        .font(Theme.Typography.caption)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.primaryFallback)
                        .foregroundStyle(.white)
                        .cornerRadius(Theme.CornerRadius.small)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func errorTypeColor(_ type: ErrorType) -> Color {
        switch type {
        case .conceptual: return .purple
        case .careless: return .orange
        case .timePressure: return .red
        case .misread: return .yellow
        case .calculation: return .blue
        case .vocabulary: return .green
        case .strategy: return .teal
        case .unknown: return .gray
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.success)

            Text("No mistakes yet!")
                .font(Theme.Typography.title3)

            Text("Keep practicing and we'll track any errors here for you to review.")
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }

    // MARK: - Data Loading

    private func loadErrors() async {
        isLoading = true

        do {
            // Load errors based on filter
            switch selectedFilter {
            case .all:
                errors = try DataStore.shared.fetchErrorLogEntries()
            case .unreviewed:
                errors = try DataStore.shared.fetchUnreviewedErrors()
            default:
                if let type = selectedFilter.errorType {
                    errors = try DataStore.shared.fetchErrors(type: type)
                } else {
                    errors = try DataStore.shared.fetchErrorLogEntries()
                }
            }

            // Load questions for display
            let questionIDs = Set(errors.map { $0.questionID })
            for id in questionIDs {
                if let question = try? DataStore.shared.fetchQuestion(id: id) {
                    questions[id] = question
                }
            }

            // Load stats
            stats = try DataStore.shared.calculateErrorStats()
        } catch {
            print("Failed to load errors: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    ErrorLogView()
}
