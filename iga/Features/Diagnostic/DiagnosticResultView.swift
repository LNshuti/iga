// IGA/Features/Diagnostic/DiagnosticResultView.swift

import SwiftUI

// MARK: - Diagnostic Result View

/// Displays the results of a completed diagnostic assessment
struct DiagnosticResultView: View {
    let result: DiagnosticResult
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                // Header
                headerSection

                // Score Overview
                scoreOverviewSection

                // Subskill Breakdown
                subskillBreakdownSection

                // Recommendations
                recommendationsSection

                // Action Button
                Button("Continue to Practice") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Your Results")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.success)

            Text("Assessment Complete!")
                .font(Theme.Typography.title)

            Text("Completed in \(result.formattedDuration)")
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Score Overview Section

    private var scoreOverviewSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Estimated GRE Scores")
                .font(Theme.Typography.title3)

            HStack(spacing: Theme.Spacing.xl) {
                scoreCard(
                    title: "Quantitative",
                    score: result.estimatedQuantScore,
                    theta: result.overallQuantTheta,
                    color: Theme.Colors.quant
                )

                scoreCard(
                    title: "Verbal",
                    score: result.estimatedVerbalScore,
                    theta: result.overallVerbalTheta,
                    color: Theme.Colors.verbal
                )
            }

            // Combined score
            VStack(spacing: Theme.Spacing.xs) {
                Text("Combined: \(result.estimatedTotalScore)")
                    .font(Theme.Typography.title2)

                Text("Range: 260-340")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.medium)
        }
        .padding()
        .background(Theme.Colors.tertiaryBackground)
        .cornerRadius(Theme.CornerRadius.large)
    }

    private func scoreCard(title: String, score: Int, theta: Double, color: Color) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)

            Text("\(score)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            // Confidence indicator
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    Rectangle()
                        .fill(i < confidenceLevel(theta: theta) ? color : color.opacity(0.2))
                        .frame(width: 8, height: 4)
                        .cornerRadius(2)
                }
            }

            Text("130-170")
                .font(Theme.Typography.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func confidenceLevel(theta: Double) -> Int {
        // Map theta to confidence level (1-5)
        // Higher absolute theta = more confident (further from average)
        let absTheta = abs(theta)
        switch absTheta {
        case 0..<0.5: return 2
        case 0.5..<1.0: return 3
        case 1.0..<1.5: return 4
        default: return 5
        }
    }

    // MARK: - Subskill Breakdown Section

    private var subskillBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Subskill Breakdown")
                .font(Theme.Typography.title3)

            // Quantitative subskills
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Quantitative")
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(Theme.Colors.quant)

                ForEach(Subskill.quantSubskills, id: \.rawValue) { subskill in
                    if let estimate = result.subskillEstimates[subskill.rawValue] {
                        subskillRow(subskill: subskill, estimate: estimate)
                    }
                }
            }
            .padding()
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.medium)

            // Verbal subskills
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Verbal")
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(Theme.Colors.verbal)

                ForEach(Subskill.verbalSubskills, id: \.rawValue) { subskill in
                    if let estimate = result.subskillEstimates[subskill.rawValue] {
                        subskillRow(subskill: subskill, estimate: estimate)
                    }
                }
            }
            .padding()
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.medium)
        }
    }

    private func subskillRow(subskill: Subskill, estimate: SubskillEstimate) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(subskill.shortName)
                    .font(Theme.Typography.body)

                Text("\(Int(estimate.accuracy * 100))% accuracy")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mastery level badge
            Text(estimate.estimatedMasteryLevel.name)
                .font(Theme.Typography.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(masteryColor(estimate.estimatedMasteryLevel).opacity(0.2))
                .foregroundStyle(masteryColor(estimate.estimatedMasteryLevel))
                .cornerRadius(Theme.CornerRadius.small)
        }
    }

    private func masteryColor(_ level: MasteryLevel) -> Color {
        switch level {
        case .novice: return Theme.Colors.error
        case .developing: return Theme.Colors.warning
        case .proficient: return Theme.Colors.info
        case .mastered: return Theme.Colors.success
        }
    }

    // MARK: - Recommendations Section

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Focus Areas")
                .font(Theme.Typography.title3)

            Text("Based on your results, we recommend focusing on these areas:")
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(result.recommendedFocusAreas, id: \.self) { subskillID in
                    if let subskill = Subskill(rawValue: subskillID) {
                        focusAreaRow(subskill: subskill)
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.warning.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.large)
    }

    private func focusAreaRow(subskill: Subskill) -> some View {
        HStack {
            Image(systemName: subskill.icon)
                .foregroundStyle(Theme.Colors.warning)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(subskill.name)
                    .font(Theme.Typography.body)

                Text(subskill.section.displayName)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DiagnosticResultView(result: .preview) {
            print("Dismissed")
        }
    }
}
