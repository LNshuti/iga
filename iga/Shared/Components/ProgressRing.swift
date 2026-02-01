// IGA/Shared/Components/ProgressRing.swift

import SwiftUI

// MARK: - Progress Ring

/// Circular progress indicator with customizable appearance
struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let lineWidth: CGFloat
    let color: Color
    let backgroundColor: Color

    init(
        progress: Double,
        lineWidth: CGFloat = 8,
        color: Color = Theme.Colors.primaryFallback,
        backgroundColor: Color = Color.gray.opacity(0.2)
    ) {
        self.progress = min(max(progress, 0), 1)
        self.lineWidth = lineWidth
        self.color = color
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(Theme.Animation.standard, value: progress)
        }
    }
}

// MARK: - Progress Ring with Label

/// Progress ring with a centered label
struct LabeledProgressRing: View {
    let progress: Double
    let label: String
    let sublabel: String?
    let size: CGFloat
    let color: Color

    init(
        progress: Double,
        label: String,
        sublabel: String? = nil,
        size: CGFloat = 100,
        color: Color = Theme.Colors.primaryFallback
    ) {
        self.progress = progress
        self.label = label
        self.sublabel = sublabel
        self.size = size
        self.color = color
    }

    var body: some View {
        ZStack {
            ProgressRing(
                progress: progress,
                lineWidth: size / 10,
                color: color
            )
            .frame(width: size, height: size)

            VStack(spacing: 2) {
                Text(label)
                    .font(size > 80 ? Theme.Typography.title : Theme.Typography.bodyBold)
                    .fontWeight(.bold)

                if let sublabel {
                    Text(sublabel)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Accuracy Ring

/// Progress ring specifically for showing accuracy percentage
struct AccuracyRing: View {
    let correct: Int
    let total: Int
    let size: CGFloat

    private var accuracy: Double {
        guard total > 0 else { return 0 }
        return Double(correct) / Double(total)
    }

    private var percentageString: String {
        "\(Int(accuracy * 100))%"
    }

    private var color: Color {
        switch accuracy {
        case 0.8...1.0: return Theme.Colors.success
        case 0.6..<0.8: return Theme.Colors.primaryFallback
        case 0.4..<0.6: return Theme.Colors.warning
        default: return Theme.Colors.error
        }
    }

    var body: some View {
        LabeledProgressRing(
            progress: accuracy,
            label: percentageString,
            sublabel: "\(correct)/\(total)",
            size: size,
            color: color
        )
    }
}

// MARK: - Mini Progress Ring

/// Small progress ring for inline use
struct MiniProgressRing: View {
    let progress: Double
    let color: Color

    init(progress: Double, color: Color = Theme.Colors.primaryFallback) {
        self.progress = progress
        self.color = color
    }

    var body: some View {
        ProgressRing(progress: progress, lineWidth: 3, color: color)
            .frame(width: 20, height: 20)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        ProgressRing(progress: 0.7)
            .frame(width: 100, height: 100)

        LabeledProgressRing(
            progress: 0.75,
            label: "75%",
            sublabel: "Complete",
            size: 120
        )

        AccuracyRing(correct: 8, total: 10, size: 100)

        HStack(spacing: 20) {
            MiniProgressRing(progress: 0.3)
            MiniProgressRing(progress: 0.6)
            MiniProgressRing(progress: 0.9)
        }
    }
    .padding()
}
