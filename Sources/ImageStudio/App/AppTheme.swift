import SwiftUI

/// Centralised design tokens used across all views.
enum AppTheme {
    // MARK: - Colours

    /// Primary teal/blue accent — matches the app tint.
    static let accent: Color = Color(red: 0.18, green: 0.47, blue: 0.91)

    /// Warm amber/orange used for warnings, missing-state indicators.
    static let warmAccent: Color = Color(red: 0.96, green: 0.55, blue: 0.22)

    /// Success green used for "installed" and "saved" states.
    static let success: Color = Color(red: 0.25, green: 0.78, blue: 0.46)

    /// Primary text colour.
    static let ink: Color = .primary

    /// Secondary / muted text colour.
    static let secondaryInk: Color = .secondary

    /// Default page / list background.
    static let pageBackground: Color = Color(.systemGroupedBackground)

    /// Surface background for cards and panels.
    static let panelBackground: Color = Color(.secondarySystemBackground)

    // MARK: - Shape
    static let cornerRadius: CGFloat = 12

    // MARK: - Layout
    static let controlHeight: CGFloat = 48
}
