// IGA/Shared/Components/TimerView.swift

import SwiftUI

// MARK: - Timer View

/// Displays a countdown timer for timed practice sessions
struct TimerView: View {
    let totalSeconds: Int
    @Binding var remainingSeconds: Int
    let onTimeUp: () -> Void

    @State private var isRunning = false
    @State private var timer: Timer?

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    private var timeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var isLowTime: Bool {
        remainingSeconds <= 10
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Timer circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isLowTime ? Theme.Colors.error : Theme.Colors.primaryFallback,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(Theme.Animation.quick, value: progress)
            }
            .frame(width: 24, height: 24)

            // Time text
            Text(timeString)
                .font(Theme.Typography.mono)
                .foregroundColor(isLowTime ? Theme.Colors.error : .primary)
                .monospacedDigit()
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        guard !isRunning else { return }
        isRunning = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                stopTimer()
                onTimeUp()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
}

// MARK: - Compact Timer

/// A more compact timer for inline display
struct CompactTimerView: View {
    let remainingSeconds: Int

    private var timeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var isLowTime: Bool {
        remainingSeconds <= 10
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.caption)

            Text(timeString)
                .font(Theme.Typography.monoSmall)
                .monospacedDigit()
        }
        .foregroundColor(isLowTime ? Theme.Colors.error : .secondary)
    }
}

// MARK: - Stopwatch View

/// Displays elapsed time (counting up)
struct StopwatchView: View {
    @Binding var elapsedSeconds: Int
    @State private var timer: Timer?

    private var timeString: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "stopwatch")
                .font(.caption)

            Text(timeString)
                .font(Theme.Typography.monoSmall)
                .monospacedDigit()
        }
        .foregroundColor(.secondary)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TimerView(
            totalSeconds: 90,
            remainingSeconds: .constant(45),
            onTimeUp: {}
        )

        CompactTimerView(remainingSeconds: 45)

        StopwatchView(elapsedSeconds: .constant(120))
    }
    .padding()
}
