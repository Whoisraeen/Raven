// MARK: - Color

/// A simple RGBA color type.
public struct Color: Sendable {
    public let r: Float
    public let g: Float
    public let b: Float
    public let a: Float

    public init(_ r: Float, _ g: Float, _ b: Float, _ a: Float = 1.0) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    // Standard colors
    public static let clear = Color(0, 0, 0, 0)
    public static let black = Color(0, 0, 0)
    public static let white = Color(1, 1, 1)
    public static let red = Color(0.92, 0.26, 0.21)
    public static let green = Color(0.18, 0.80, 0.44)
    public static let blue = Color(0.20, 0.40, 0.92)
    public static let yellow = Color(0.96, 0.76, 0.18)
    public static let orange = Color(0.96, 0.52, 0.10)
    public static let purple = Color(0.61, 0.32, 0.88)
    public static let gray = Color(0.55, 0.55, 0.55)
    public static let darkGray = Color(0.25, 0.25, 0.28)

    // Raven theme colors
    public static let primary = Color(0.35, 0.55, 0.95)
    public static let secondary = Color(0.55, 0.55, 0.60)
    public static let background = Color(0.08, 0.10, 0.14)
    public static let surface = Color(0.14, 0.16, 0.20)
    public static let surfaceLight = Color(0.20, 0.22, 0.28)
    public static let text = Color(0.92, 0.92, 0.94)
    public static let textSecondary = Color(0.60, 0.62, 0.66)
    public static let buttonText = Color(1.0, 1.0, 1.0)
    public static let accent = Color(0.40, 0.72, 0.40)
    public static let trackBackground = Color(0.22, 0.24, 0.28)
    public static let thumbColor = Color(0.92, 0.92, 0.94)
}

// MARK: - Picker Style

/// The visual style for a Picker component.
public enum PickerStyle: Sendable {
    /// Inline horizontal segmented control.
    case segmented
    /// Dropdown menu that expands on click.
    case menu
}

// MARK: - Edge & Alignment

public struct EdgeInsets: Sendable {
    public var top: Float
    public var leading: Float
    public var bottom: Float
    public var trailing: Float

    public init(top: Float = 0, leading: Float = 0, bottom: Float = 0, trailing: Float = 0) {
        self.top = top; self.leading = leading; self.bottom = bottom; self.trailing = trailing
    }

    public init(_ all: Float) {
        self.top = all; self.leading = all; self.bottom = all; self.trailing = all
    }
}

public enum HorizontalAlignment: Sendable {
    case leading, center, trailing
}

public enum VerticalAlignment: Sendable {
    case top, center, bottom
}
