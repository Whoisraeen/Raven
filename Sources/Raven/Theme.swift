// MARK: - Theme System

/// A complete theme definition containing all semantic colors and styling tokens.
/// Themes are propagated through the Environment system.
///
/// Usage:
/// ```swift
/// struct MyView: View {
///     @Environment(\.theme) var theme
///
///     var body: some View {
///         VStack {
///             Text("Title").foreground(theme.text)
///             Text("Subtitle").foreground(theme.textSecondary)
///         }
///         .background(theme.background)
///     }
/// }
/// ```
public struct Theme: Sendable {
    // MARK: - Surface Colors
    public var background: Color
    public var surface: Color
    public var surfaceLight: Color

    // MARK: - Text Colors
    public var text: Color
    public var textSecondary: Color

    // MARK: - Accent Colors
    public var primary: Color
    public var secondary: Color
    public var accent: Color

    // MARK: - Semantic Colors
    public var success: Color
    public var warning: Color
    public var error: Color
    public var info: Color

    // MARK: - Component Colors
    public var buttonBackground: Color
    public var buttonText: Color
    public var inputBackground: Color
    public var inputBorder: Color
    public var divider: Color

    // MARK: - Sidebar / Navigation
    public var sidebarBackground: Color
    public var sidebarText: Color
    public var sidebarSelection: Color

    public init(
        background: Color,
        surface: Color,
        surfaceLight: Color,
        text: Color,
        textSecondary: Color,
        primary: Color,
        secondary: Color,
        accent: Color,
        success: Color,
        warning: Color,
        error: Color,
        info: Color,
        buttonBackground: Color,
        buttonText: Color,
        inputBackground: Color,
        inputBorder: Color,
        divider: Color,
        sidebarBackground: Color,
        sidebarText: Color,
        sidebarSelection: Color
    ) {
        self.background = background
        self.surface = surface
        self.surfaceLight = surfaceLight
        self.text = text
        self.textSecondary = textSecondary
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.success = success
        self.warning = warning
        self.error = error
        self.info = info
        self.buttonBackground = buttonBackground
        self.buttonText = buttonText
        self.inputBackground = inputBackground
        self.inputBorder = inputBorder
        self.divider = divider
        self.sidebarBackground = sidebarBackground
        self.sidebarText = sidebarText
        self.sidebarSelection = sidebarSelection
    }
}

// MARK: - Built-in Themes

extension Theme {
    /// The default dark theme — matches the existing Raven color palette.
    public static let dark = Theme(
        background:        Color(0.08, 0.10, 0.14),
        surface:           Color(0.14, 0.16, 0.20),
        surfaceLight:      Color(0.20, 0.22, 0.28),
        text:              Color(0.92, 0.92, 0.94),
        textSecondary:     Color(0.60, 0.62, 0.66),
        primary:           Color(0.35, 0.55, 0.95),
        secondary:         Color(0.55, 0.55, 0.60),
        accent:            Color(0.45, 0.75, 0.95),
        success:           Color(0.18, 0.80, 0.44),
        warning:           Color(0.96, 0.76, 0.18),
        error:             Color(0.92, 0.26, 0.21),
        info:              Color(0.35, 0.55, 0.95),
        buttonBackground:  Color(0.35, 0.55, 0.95),
        buttonText:        Color(1.0, 1.0, 1.0),
        inputBackground:   Color(0.14, 0.16, 0.20),
        inputBorder:       Color(0.25, 0.27, 0.32),
        divider:           Color(0.20, 0.22, 0.26),
        sidebarBackground: Color(0.10, 0.12, 0.16),
        sidebarText:       Color(0.80, 0.80, 0.82),
        sidebarSelection:  Color(0.20, 0.35, 0.65)
    )

    /// A light theme for bright environments.
    public static let light = Theme(
        background:        Color(0.96, 0.96, 0.98),
        surface:           Color(1.0, 1.0, 1.0),
        surfaceLight:      Color(0.94, 0.94, 0.96),
        text:              Color(0.10, 0.10, 0.12),
        textSecondary:     Color(0.45, 0.45, 0.50),
        primary:           Color(0.22, 0.42, 0.88),
        secondary:         Color(0.50, 0.50, 0.55),
        accent:            Color(0.15, 0.55, 0.85),
        success:           Color(0.15, 0.68, 0.38),
        warning:           Color(0.88, 0.65, 0.08),
        error:             Color(0.85, 0.20, 0.18),
        info:              Color(0.22, 0.42, 0.88),
        buttonBackground:  Color(0.22, 0.42, 0.88),
        buttonText:        Color(1.0, 1.0, 1.0),
        inputBackground:   Color(1.0, 1.0, 1.0),
        inputBorder:       Color(0.82, 0.82, 0.85),
        divider:           Color(0.88, 0.88, 0.90),
        sidebarBackground: Color(0.92, 0.92, 0.94),
        sidebarText:       Color(0.20, 0.20, 0.25),
        sidebarSelection:  Color(0.22, 0.42, 0.88, 0.15)
    )

    /// Returns the appropriate theme for a given color scheme.
    public static func forScheme(_ scheme: ColorScheme) -> Theme {
        switch scheme {
        case .dark: return .dark
        case .light: return .light
        }
    }
}

// MARK: - Theme Environment Key

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .dark
}

extension EnvironmentValues {
    /// The current theme. Access via `@Environment(\.theme)`.
    public var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Convenience: Color from Theme

extension Color {
    /// The button text color (kept for backward compatibility).
    public static let buttonText = Color(1.0, 1.0, 1.0)
}
