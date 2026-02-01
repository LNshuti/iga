// IGA/Shared/Components/ErrorBanner.swift

import SwiftUI

// MARK: - Error Banner

/// Displays an error message with optional retry action
struct ErrorBanner: View {
    let message: String
    let retryAction: (() -> Void)?
    let dismissAction: (() -> Void)?

    init(
        message: String,
        retryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.message = message
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Theme.Colors.error)

            Text(message)
                .font(Theme.Typography.callout)
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()

            if let retry = retryAction {
                Button("Retry", action: retry)
                    .font(Theme.Typography.bodyBold)
                    .foregroundColor(Theme.Colors.primaryFallback)
            }

            if let dismiss = dismissAction {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.error.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.error.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Warning Banner

/// Displays a warning message
struct WarningBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Theme.Colors.warning)

            Text(message)
                .font(Theme.Typography.callout)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.warning.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.medium)
    }
}

// MARK: - Info Banner

/// Displays an informational message
struct InfoBanner: View {
    let message: String
    let icon: String

    init(message: String, icon: String = "info.circle.fill") {
        self.message = message
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.info)

            Text(message)
                .font(Theme.Typography.callout)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.info.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.medium)
    }
}

// MARK: - Offline Banner

/// Displays when the device is offline
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.secondary)

            Text("You're offline. AI features are unavailable.")
                .font(Theme.Typography.callout)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ErrorBanner(
            message: "Failed to load questions",
            retryAction: {},
            dismissAction: {}
        )

        WarningBanner(message: "Your session will expire soon")

        InfoBanner(message: "New questions available!")

        OfflineBanner()
    }
    .padding()
}
