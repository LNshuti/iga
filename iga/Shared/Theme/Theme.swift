// IGA/Shared/Theme/Theme.swift

import SwiftUI
import UIKit

// MARK: - App Theme

/// Centralized theme configuration for the app
enum Theme {

    // MARK: - Colors

    enum Colors {
        // Primary brand colors
        static let primary = Color("PrimaryColor", bundle: .main)
        static let secondary = Color("SecondaryColor", bundle: .main)

        // Fallback colors if asset catalog colors not available
        static var primaryFallback: Color { Color(red: 0.29, green: 0.47, blue: 0.82) }
        static var secondaryFallback: Color { Color(red: 0.54, green: 0.36, blue: 0.76) }

        // Semantic colors
        static let success = Color.green
        static let error = Color.red
        static let warning = Color.orange
        static let info = Color.blue

        // Section colors
        static let quant = Color(red: 0.29, green: 0.56, blue: 0.89)
        static let verbal = Color(red: 0.67, green: 0.43, blue: 0.80)
        static let awa = Color(red: 0.95, green: 0.61, blue: 0.29)

        // Answer state colors
        static let correct = Color(red: 0.22, green: 0.71, blue: 0.29)
        static let incorrect = Color(red: 0.91, green: 0.30, blue: 0.24)
        static let selected = Color(red: 0.29, green: 0.47, blue: 0.82)
        static let unselected = Color(UIColor.secondarySystemBackground)

        // Chat colors
        static let userBubble = Color(red: 0.29, green: 0.47, blue: 0.82)
        static let assistantBubble = Color(UIColor.secondarySystemBackground)

        // Background colors
        static let background = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
        static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)

        /// Get color for a question section
        static func sectionColor(_ section: QuestionSection) -> Color {
            switch section {
            case .quant: return quant
            case .verbal: return verbal
            case .awa: return awa
            }
        }
    }

    // MARK: - Typography

    enum Typography {
        // Headings
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)

        // Body
        static let body = Font.body
        static let bodyBold = Font.body.weight(.semibold)
        static let callout = Font.callout
        static let caption = Font.caption
        static let caption2 = Font.caption2

        // Monospace (for math/code)
        static let mono = Font.system(.body, design: .monospaced)
        static let monoSmall = Font.system(.caption, design: .monospaced)

        // Question stem
        static let questionStem = Font.title3
        static let choiceText = Font.body
        static let explanationText = Font.body

        // Chat
        static let messageText = Font.body
        static let timestamp = Font.caption2
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48

        // Component-specific
        static let cardPadding: CGFloat = 16
        static let listItemSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 24
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xl: CGFloat = 16
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows

    enum Shadows {
        static let small = Shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        static let large = Shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 8)
    }

    // MARK: - Animation

    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.7)
    }
}

// MARK: - Shadow Helper

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func themeShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.bodyBold)
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(isEnabled ? Theme.Colors.primaryFallback : Color.gray)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.Animation.quick, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.bodyBold)
            .foregroundColor(Theme.Colors.primaryFallback)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.primaryFallback, lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct ChoiceButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isCorrect: Bool?
    let showResult: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.choiceText)
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.Animation.quick, value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        if showResult {
            if isCorrect == true {
                return Theme.Colors.correct.opacity(0.15)
            } else if isSelected {
                return Theme.Colors.incorrect.opacity(0.15)
            }
        }
        return isSelected ? Theme.Colors.selected.opacity(0.1) : Theme.Colors.unselected
    }

    private var foregroundColor: Color {
        Color(UIColor.label)
    }

    private var borderColor: Color {
        if showResult {
            if isCorrect == true {
                return Theme.Colors.correct
            } else if isSelected {
                return Theme.Colors.incorrect
            }
        }
        return isSelected ? Theme.Colors.selected : Color.gray.opacity(0.3)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .padding(Theme.Spacing.cardPadding)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .themeShadow(Theme.Shadows.small)
    }

    func sectionHeader() -> some View {
        self
            .font(Theme.Typography.title3)
            .foregroundColor(.secondary)
    }
}
