// MARK: - View Modifiers

/// Padding modifier
public struct PaddingModifier: ViewModifier {
    public let insets: EdgeInsets
    public func apply(to node: LayoutNode) {
        node.padding = EdgeInsets(
            top: node.padding.top + insets.top,
            leading: node.padding.leading + insets.leading,
            bottom: node.padding.bottom + insets.bottom,
            trailing: node.padding.trailing + insets.trailing
        )
    }
}

/// Background color modifier
public struct BackgroundModifier: ViewModifier {
    public let color: Color
    public func apply(to node: LayoutNode) {
        node.backgroundColor = color
    }
}

/// Foreground color modifier
public struct ForegroundModifier: ViewModifier {
    public let color: Color
    public func apply(to node: LayoutNode) {
        node.foregroundColor = color
    }
}

/// Fixed frame modifier
public struct FrameModifier: ViewModifier {
    public let width: Float?
    public let height: Float?
    public func apply(to node: LayoutNode) {
        if let w = width { node.fixedWidth = w }
        if let h = height { node.fixedHeight = h }
    }
}

/// Corner radius modifier
public struct CornerRadiusModifier: ViewModifier {
    public let radius: Float
    public func apply(to node: LayoutNode) {
        node.cornerRadius = radius
    }
}

/// Baseline alignment modifier for HStack
public struct BaselineAlignmentModifier: ViewModifier {
    public func apply(to node: LayoutNode) {
        node.alignToBaseline = true
    }
}

/// Font size modifier
public struct FontSizeModifier: ViewModifier {
    public let size: Float
    public func apply(to node: LayoutNode) {
        node.fontSize = size
    }
}

/// Opacity modifier
public struct OpacityModifier: ViewModifier {
    public let opacity: Float
    public func apply(to node: LayoutNode) {
        node.opacity = opacity
    }
}

/// Border modifier
public struct BorderModifier: ViewModifier {
    public let color: Color
    public let width: Float
    public func apply(to node: LayoutNode) {
        node.borderColor = color
        node.borderWidth = width
    }
}

/// Hidden modifier
public struct HiddenModifier: ViewModifier {
    public func apply(to node: LayoutNode) {
        node.isHidden = true
    }
}

// MARK: - Accessibility Modifiers

public struct AccessibilityLabelModifier: ViewModifier {
    public let label: String
    public func apply(to node: LayoutNode) {
        node.accessibilityLabel = label
    }
}

public struct AccessibilityValueModifier: ViewModifier {
    public let value: String
    public func apply(to node: LayoutNode) {
        node.accessibilityValue = value
    }
}

public struct AccessibilityHiddenModifier: ViewModifier {
    public let hidden: Bool
    public func apply(to node: LayoutNode) {
        node.isAccessibilityHidden = hidden
    }
}

public struct AccessibilityRoleModifier: ViewModifier {
    public let role: AccessibilityRole
    public func apply(to node: LayoutNode) {
        node.accessibilityRole = role
    }
}

/// Text wrap width modifier — sets a maximum width for text word wrapping
public struct TextWrapModifier: ViewModifier {
    public let maxWidth: Float
    public func apply(to node: LayoutNode) {
        node.maxTextWidth = maxWidth
    }
}

/// Disabled modifier — prevents interaction
public struct DisabledModifier: ViewModifier {
    public let isDisabled: Bool
    public func apply(to node: LayoutNode) {
        node.isDisabled = isDisabled
        if isDisabled {
            node.opacity = min(node.opacity, 0.5)
        }
    }
}

/// Shadow modifier — adds a shadow quad behind the node
public struct ShadowModifier: ViewModifier {
    public let color: Color
    public let radius: Float
    public let x: Float
    public let y: Float
    public func apply(to node: LayoutNode) {
        node.shadowColor = color
        node.shadowRadius = radius
        node.shadowOffsetX = x
        node.shadowOffsetY = y
    }
}

/// Tap gesture modifier — adds a tap handler
public struct OnTapGestureModifier: ViewModifier {
    public let action: @Sendable () -> Void
    public func apply(to node: LayoutNode) {
        node.onTap = action
    }
}

/// onAppear modifier — fires when the view first appears in the tree
public struct OnAppearModifier: ViewModifier {
    public let action: @Sendable () -> Void
    public func apply(to node: LayoutNode) {
        node.onAppear = action
    }
}

/// onDisappear modifier — fires when the view is removed from the tree
public struct OnDisappearModifier: ViewModifier {
    public let action: @Sendable () -> Void
    public func apply(to node: LayoutNode) {
        node.onDisappear = action
    }
}

// MARK: - View Extension Methods

extension View {
    /// Add padding around the view.
    public func padding(_ value: Float) -> ModifiedView<Self, PaddingModifier> {
        ModifiedView(content: self, modifier: PaddingModifier(insets: EdgeInsets(value)))
    }

    /// Add padding with specific edge insets.
    public func padding(_ insets: EdgeInsets) -> ModifiedView<Self, PaddingModifier> {
        ModifiedView(content: self, modifier: PaddingModifier(insets: insets))
    }

    /// Add padding on specific edges.
    public func padding(top: Float = 0, leading: Float = 0, bottom: Float = 0, trailing: Float = 0) -> ModifiedView<Self, PaddingModifier> {
        ModifiedView(content: self, modifier: PaddingModifier(
            insets: EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
        ))
    }

    /// Set the background color.
    public func background(_ color: Color) -> ModifiedView<Self, BackgroundModifier> {
        ModifiedView(content: self, modifier: BackgroundModifier(color: color))
    }

    /// Set the foreground (text) color.
    public func foreground(_ color: Color) -> ModifiedView<Self, ForegroundModifier> {
        ModifiedView(content: self, modifier: ForegroundModifier(color: color))
    }

    /// Set a fixed frame size.
    public func frame(width: Float? = nil, height: Float? = nil) -> ModifiedView<Self, FrameModifier> {
        ModifiedView(content: self, modifier: FrameModifier(width: width, height: height))
    }

    /// Set the corner radius.
    public func cornerRadius(_ radius: Float) -> ModifiedView<Self, CornerRadiusModifier> {
        ModifiedView(content: self, modifier: CornerRadiusModifier(radius: radius))
    }
    
    /// Align children in an HStack to their text baselines.
    public func alignToBaseline() -> ModifiedView<Self, BaselineAlignmentModifier> {
        ModifiedView(content: self, modifier: BaselineAlignmentModifier())
    }

    /// Set the font size.
    public func font(size: Float) -> ModifiedView<Self, FontSizeModifier> {
        ModifiedView(content: self, modifier: FontSizeModifier(size: size))
    }

    /// Set the opacity (0.0 = transparent, 1.0 = opaque).
    public func opacity(_ opacity: Float) -> ModifiedView<Self, OpacityModifier> {
        ModifiedView(content: self, modifier: OpacityModifier(opacity: opacity))
    }

    /// Add a border with color and width.
    public func border(_ color: Color, width: Float = 1) -> ModifiedView<Self, BorderModifier> {
        ModifiedView(content: self, modifier: BorderModifier(color: color, width: width))
    }

    /// Hide the view.
    public func hidden() -> ModifiedView<Self, HiddenModifier> {
        ModifiedView(content: self, modifier: HiddenModifier())
    }

    /// Set maximum text width for word wrapping.
    public func textWrap(maxWidth: Float) -> ModifiedView<Self, TextWrapModifier> {
        ModifiedView(content: self, modifier: TextWrapModifier(maxWidth: maxWidth))
    }

    /// Disable interaction on this view.
    public func disabled(_ isDisabled: Bool = true) -> ModifiedView<Self, DisabledModifier> {
        ModifiedView(content: self, modifier: DisabledModifier(isDisabled: isDisabled))
    }

    /// Add a shadow to the view.
    public func shadow(color: Color = Color(0, 0, 0, 0.3), radius: Float = 4, x: Float = 0, y: Float = 2) -> ModifiedView<Self, ShadowModifier> {
        ModifiedView(content: self, modifier: ShadowModifier(color: color, radius: radius, x: x, y: y))
    }

    /// Add a tap gesture handler.
    public func onTapGesture(_ action: @escaping @Sendable () -> Void) -> ModifiedView<Self, OnTapGestureModifier> {
        ModifiedView(content: self, modifier: OnTapGestureModifier(action: action))
    }

    /// Run an action when the view first appears.
    public func onAppear(_ action: @escaping @Sendable () -> Void) -> ModifiedView<Self, OnAppearModifier> {
        ModifiedView(content: self, modifier: OnAppearModifier(action: action))
    }

    /// Run an action when the view is removed.
    public func onDisappear(_ action: @escaping @Sendable () -> Void) -> ModifiedView<Self, OnDisappearModifier> {
        ModifiedView(content: self, modifier: OnDisappearModifier(action: action))
    }

    // MARK: - Accessibility Extensions

    public func accessibilityLabel(_ label: String) -> ModifiedView<Self, AccessibilityLabelModifier> {
        ModifiedView(content: self, modifier: AccessibilityLabelModifier(label: label))
    }

    public func accessibilityValue(_ value: String) -> ModifiedView<Self, AccessibilityValueModifier> {
        ModifiedView(content: self, modifier: AccessibilityValueModifier(value: value))
    }

    public func accessibilityHidden(_ hidden: Bool = true) -> ModifiedView<Self, AccessibilityHiddenModifier> {
        ModifiedView(content: self, modifier: AccessibilityHiddenModifier(hidden: hidden))
    }

    public func accessibilityRole(_ role: AccessibilityRole) -> ModifiedView<Self, AccessibilityRoleModifier> {
        ModifiedView(content: self, modifier: AccessibilityRoleModifier(role: role))
    }
}
