// MARK: - Theme System

/// A centralized design token system for Raven applications.
/// Defines colors, typography, spacing scales, and shape radii.
/// Supports light and dark mode with seamless switching.
///
/// Usage:
/// ```swift
/// // Use the default dark theme:
/// let theme = Theme.dark
///
/// // Create a custom theme:
/// var myTheme = Theme.dark
/// myTheme.colors.primary = Color(0.90, 0.30, 0.30) // Red primary
/// myTheme.typography.defaultFontSize = 18
///
/// // Apply globally:
/// Theme.current = myTheme
/// ```
public struct Theme: Sendable {
    /// The active global theme. Defaults to `.dark`.
    public nonisolated(unsafe) static var current = Theme.dark

    // MARK: - Color Palette

    /// The color palette for this theme.
    public var colors: ThemeColors

    // MARK: - Typography

    /// Typography configuration.
    public var typography: ThemeTypography

    // MARK: - Spacing

    /// Spacing scale (used for padding, margins, gaps).
    public var spacing: ThemeSpacing

    // MARK: - Shapes

    /// Shape configuration (corner radii).
    public var shapes: ThemeShapes

    // MARK: - Presets

    /// The default dark theme — dark backgrounds, light text.
    public static let dark = Theme(
        colors: ThemeColors(
            primary: Color(0.35, 0.55, 0.95),
            secondary: Color(0.55, 0.55, 0.60),
            accent: Color(0.40, 0.72, 0.40),
            background: Color(0.08, 0.10, 0.14),
            surface: Color(0.14, 0.16, 0.20),
            surfaceLight: Color(0.20, 0.22, 0.28),
            text: Color(0.92, 0.92, 0.94),
            textSecondary: Color(0.60, 0.62, 0.66),
            buttonText: Color(1.0, 1.0, 1.0),
            error: Color(0.92, 0.26, 0.21),
            success: Color(0.18, 0.80, 0.44),
            warning: Color(0.96, 0.76, 0.18),
            trackBackground: Color(0.22, 0.24, 0.28),
            thumbColor: Color(0.92, 0.92, 0.94),
            divider: Color(0.25, 0.27, 0.32)
        ),
        typography: ThemeTypography(
            defaultFontSize: 16,
            titleFontSize: 24,
            headlineFontSize: 20,
            captionFontSize: 12,
            monospaceFontSize: 14
        ),
        spacing: ThemeSpacing(
            xxs: 2,
            xs: 4,
            sm: 8,
            md: 12,
            lg: 16,
            xl: 24,
            xxl: 32
        ),
        shapes: ThemeShapes(
            sm: 4,
            md: 8,
            lg: 12,
            xl: 16,
            full: 9999  // Capsule / pill shape
        )
    )

    /// A light theme variant — light backgrounds, dark text.
    public static let light = Theme(
        colors: ThemeColors(
            primary: Color(0.25, 0.45, 0.85),
            secondary: Color(0.45, 0.45, 0.50),
            accent: Color(0.30, 0.65, 0.30),
            background: Color(0.96, 0.96, 0.98),
            surface: Color(1.0, 1.0, 1.0),
            surfaceLight: Color(0.94, 0.94, 0.96),
            text: Color(0.10, 0.10, 0.12),
            textSecondary: Color(0.40, 0.42, 0.46),
            buttonText: Color(1.0, 1.0, 1.0),
            error: Color(0.85, 0.20, 0.15),
            success: Color(0.15, 0.70, 0.40),
            warning: Color(0.90, 0.70, 0.10),
            trackBackground: Color(0.82, 0.84, 0.88),
            thumbColor: Color(1.0, 1.0, 1.0),
            divider: Color(0.85, 0.87, 0.92)
        ),
        typography: ThemeTypography(
            defaultFontSize: 16,
            titleFontSize: 24,
            headlineFontSize: 20,
            captionFontSize: 12,
            monospaceFontSize: 14
        ),
        spacing: ThemeSpacing(
            xxs: 2,
            xs: 4,
            sm: 8,
            md: 12,
            lg: 16,
            xl: 24,
            xxl: 32
        ),
        shapes: ThemeShapes(
            sm: 4,
            md: 8,
            lg: 12,
            xl: 16,
            full: 9999
        )
    )
}

// MARK: - Theme Sub-Types

/// Color palette for a theme.
public struct ThemeColors: Sendable {
    public var primary: Color
    public var secondary: Color
    public var accent: Color
    public var background: Color
    public var surface: Color
    public var surfaceLight: Color
    public var text: Color
    public var textSecondary: Color
    public var buttonText: Color
    public var error: Color
    public var success: Color
    public var warning: Color
    public var trackBackground: Color
    public var thumbColor: Color
    public var divider: Color
}

/// Typography configuration.
public struct ThemeTypography: Sendable {
    public var defaultFontSize: Float
    public var titleFontSize: Float
    public var headlineFontSize: Float
    public var captionFontSize: Float
    public var monospaceFontSize: Float
}

/// Spacing scale.
public struct ThemeSpacing: Sendable {
    public var xxs: Float
    public var xs: Float
    public var sm: Float
    public var md: Float
    public var lg: Float
    public var xl: Float
    public var xxl: Float
}

/// Shape / corner radius tokens.
public struct ThemeShapes: Sendable {
    public var sm: Float
    public var md: Float
    public var lg: Float
    public var xl: Float
    public var full: Float
}
