// IGA/Shared/Components/LoadingView.swift

import SwiftUI

// MARK: - Loading View

/// Full-screen loading indicator
struct LoadingView: View {
    let message: String?

    init(message: String? = nil) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)

            if let message {
                Text(message)
                    .font(Theme.Typography.callout)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
    }
}

// MARK: - Inline Loading

/// Inline loading indicator for buttons or small areas
struct InlineLoadingView: View {
    var body: some View {
        ProgressView()
            .scaleEffect(0.8)
    }
}

// MARK: - Streaming Indicator

/// Animated dots indicating streaming response
struct StreamingIndicator: View {
    @State private var animatingDot = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.Colors.primaryFallback)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animatingDot == index ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: animatingDot
                    )
            }
        }
        .onAppear {
            animatingDot = 1
        }
    }
}

// MARK: - Skeleton Loading

/// Skeleton placeholder for loading content
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat

    @State private var isAnimating = false

    init(width: CGFloat? = nil, height: CGFloat = 20) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.2)
                    ]),
                    startPoint: isAnimating ? .trailing : .leading,
                    endPoint: isAnimating ? .leading : .trailing
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Loading Button

/// A button that shows loading state
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }

                Text(isLoading ? "Loading..." : title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        LoadingView(message: "Loading questions...")
            .frame(height: 150)

        StreamingIndicator()

        VStack(alignment: .leading, spacing: 8) {
            SkeletonView(height: 24)
            SkeletonView(width: 200, height: 16)
            SkeletonView(width: 150, height: 16)
        }
        .padding()

        LoadingButton(title: "Submit", isLoading: true, action: {})
            .padding()
    }
}
